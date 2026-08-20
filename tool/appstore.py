#!/usr/bin/env python3
"""App Store Connect release helper.

The iOS counterpart to tool/play.py, and deliberately smaller than it. The App
Store Connect API has no endpoint that accepts a binary, so the upload itself
is done by `xcrun altool --upload-package` in the workflow. What is left for
this script is the metadata the uploader needs and cannot work out for itself:
the numeric app id, and a build number Apple has not already seen.

Credentials come from the environment rather than from files, so CI can pass
them straight from secrets without writing a private key to disk:

    APP_STORE_CONNECT_KEY_ID          the key's ten character id
    APP_STORE_CONNECT_ISSUER_ID       the issuer UUID, shared by all your keys
    APP_STORE_CONNECT_PRIVATE_KEY     the contents of the .p8, not a path

Subcommands:
  app-id      Print the numeric App Store Connect id for the bundle id.
  next-build  Print the next unused build number.

`jwt` and `requests` are imported inside the functions that need them, not at
module scope. The pull request workflow runs the tests in this directory with
nothing installed beyond the standard library, and a module-level import would
fail that job on a machine that never intends to reach Apple.
"""

from __future__ import annotations

import argparse
import datetime
import os
import sys
from typing import Iterable, Mapping

BUNDLE_ID = "com.uractor.uractorios"
API = "https://api.appstoreconnect.apple.com/v1"
AUDIENCE = "appstoreconnect-v1"

CREDENTIAL_VARS = (
    "APP_STORE_CONNECT_KEY_ID",
    "APP_STORE_CONNECT_ISSUER_ID",
    "APP_STORE_CONNECT_PRIVATE_KEY",
)

# Apple rejects a token minted for longer than twenty minutes. Ten is plenty
# for a handful of requests and leaves room for a slow runner clock.
TOKEN_LIFETIME = datetime.timedelta(minutes=10)

# A stop against paging forever if the API keeps handing back a next link.
# An app with more than twenty thousand builds is a bug, not a release.
MAX_PAGES = 100


class AppStoreError(RuntimeError):
    """A response that cannot be used to decide what to build."""


def next_build_number(versions: Iterable[str]) -> int:
    """One higher than the highest build number Apple has recorded.

    App Store Connect only requires a build number to be unique within a
    marketing version, so a lower number is legal again once the version before
    the `+` changes. Going strictly upwards across the whole app is legal too,
    and is what Play already does, so the two stores stay easy to reason about
    together: the number always moves forwards and never has to be interpreted
    relative to a version string.

    Anything that is not a plain integer is skipped rather than rejected. A
    build uploaded by hand from Xcode can carry something like `1.0.2`, and
    refusing to release because of an old hand-made build would be a strange
    place to fail.
    """
    highest = 0
    for version in versions:
        text = str(version).strip()
        if not text.isdigit():
            continue
        highest = max(highest, int(text))
    return highest + 1


def select_app_id(payload: dict, bundle_id: str = BUNDLE_ID) -> str:
    """The numeric app id from an /v1/apps response.

    `filter[bundleId]` is a prefix-free exact filter on Apple's side, but the
    response is still a list, and an empty one is the normal answer for a
    bundle id that has no App Store Connect record yet. That is the single most
    likely first-run failure, so it gets an error that says what to do rather
    than an IndexError.
    """
    data = payload.get("data") or []
    if not data:
        raise AppStoreError(
            f"no app in App Store Connect with bundle id {bundle_id!r}. "
            "Create the app record first: the API can describe an app, but it "
            "cannot bring one into existence."
        )
    return data[0]["id"]


def missing_credentials(env: Mapping[str, str]) -> list[str]:
    """Which credential variables are absent or blank.

    Pure, because the failure everyone meets first is running this with no
    secrets set, and that message should be reachable without a JWT library
    installed or a network to reach Apple over.
    """
    return [name for name in CREDENTIAL_VARS if not (env.get(name) or "").strip()]


def token() -> str:
    """A short-lived ES256 JWT for the App Store Connect API."""
    # Checked before the import below, so that a run with no secrets says which
    # secret is missing rather than which library is.
    if missing := missing_credentials(os.environ):
        sys.exit(f"not set: {', '.join(missing)}")

    try:
        import jwt  # noqa: PLC0415 - see the module docstring
    except ImportError:
        sys.exit(
            "PyJWT and its cryptography extra are needed to sign an App Store "
            "Connect token: pip install 'pyjwt[crypto]'"
        )

    now = datetime.datetime.now(datetime.timezone.utc)
    return jwt.encode(
        {
            "iss": os.environ["APP_STORE_CONNECT_ISSUER_ID"],
            "iat": int(now.timestamp()),
            "exp": int((now + TOKEN_LIFETIME).timestamp()),
            "aud": AUDIENCE,
        },
        os.environ["APP_STORE_CONNECT_PRIVATE_KEY"],
        algorithm="ES256",
        headers={"kid": os.environ["APP_STORE_CONNECT_KEY_ID"], "typ": "JWT"},
    )


def get(path: str, params: dict | None = None) -> dict:
    """One GET against the API, with failures reported in full.

    Apple answers a bad request with a JSON body naming the field it disliked.
    That body is far more useful than the status code, so it is printed rather
    than swallowed.
    """
    # Resolved first, so that the common misconfiguration — no secrets — is
    # reported as such even on a machine that also lacks the HTTP library.
    bearer = token()

    try:
        import requests  # noqa: PLC0415 - see the module docstring
    except ImportError:
        sys.exit("requests is needed to reach App Store Connect: pip install requests")

    url = path if path.startswith("http") else f"{API}{path}"
    response = requests.get(
        url,
        params=params,
        headers={"Authorization": f"Bearer {bearer}"},
        timeout=60,
    )
    if response.status_code != 200:
        print(f"GET {url} failed: HTTP {response.status_code}", file=sys.stderr)
        print(response.text[:1500], file=sys.stderr)
        raise SystemExit(1)
    return response.json()


def app_id() -> str:
    return select_app_id(get("/apps", {"filter[bundleId]": BUNDLE_ID}))


def build_versions(app: str) -> list[str]:
    """Every build number Apple holds for the app, across all pages.

    The maximum is computed here rather than asked for with `sort=-version`,
    because that sort is lexicographic: it would rank build 9 above build 10
    and quietly hand back a number that has already been used.
    """
    versions: list[str] = []
    payload = get(f"/apps/{app}/builds", {"limit": 200, "fields[builds]": "version"})
    for _ in range(MAX_PAGES):
        versions += [
            item["attributes"]["version"]
            for item in payload.get("data", [])
            if item.get("attributes", {}).get("version") is not None
        ]
        nxt = (payload.get("links") or {}).get("next")
        if not nxt:
            break
        payload = get(nxt)
    return versions


def cmd_app_id(args) -> None:
    # Printed rather than written to GITHUB_OUTPUT, matching `play.py
    # next-code`: these are queries, and the caller decides what to do with the
    # answer. The workflow captures stdout and names the output itself.
    print(app_id())


def cmd_next_build(args) -> None:
    app = args.app_id or app_id()
    print(next_build_number(build_versions(app)))


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser(
        "app-id", help="print the numeric App Store Connect id"
    ).set_defaults(func=cmd_app_id)

    nb = sub.add_parser("next-build", help="print the next unused build number")
    nb.add_argument(
        "--app-id",
        help="skip the lookup when the caller already resolved it",
    )
    nb.set_defaults(func=cmd_next_build)

    args = parser.parse_args()
    try:
        args.func(args)
    except AppStoreError as exc:
        sys.exit(str(exc))


if __name__ == "__main__":
    main()
