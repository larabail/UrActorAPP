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
  app-id          Print the numeric App Store Connect id for the bundle id.
  next-build      Print the next unused build number.
  status          Print the versions Apple holds and the state of each.
  check           Say whether an action would be allowed, without doing it.
  ensure-version  Create the version record if missing, and set its notes.
  submit          Attach a build to a version and send it to Apple for review.
  release         Publish a version Apple has approved and is holding.

A version record used to be made by hand, on the grounds that a submission
fails without screenshots and a description. Measured rather than assumed, that
turns out to be false for every version after the first: a version created
through this API arrives already holding the previous one's description,
keywords, support URL and every screenshot set, exactly as the web UI does.
`whatsNew` is the only field that comes back empty, and that is the one field
that should be different every release. `ensure-version` fills it from the same
notes Play gets.

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

# Apple reports a version's state twice, under an old name and a new one, and
# the two vocabularies disagree: a released version is READY_FOR_SALE in the
# first and READY_FOR_DISTRIBUTION in the second. Both are accepted everywhere
# below rather than picking one, because which arrives is Apple's choice.

# States where the version is still ours to change. Anything else is either
# with Apple or already published, and editing it is either refused by the API
# or — worse — quietly withdraws it from review.
SUBMITTABLE_STATES = frozenset({
    "PREPARE_FOR_SUBMISSION",
    "DEVELOPER_REJECTED",
    "REJECTED",
    "METADATA_REJECTED",
    "INVALID_BINARY",
})

# Approved, and waiting for someone to decide it goes live. This is the state a
# MANUAL release type produces, and the only one a release request applies to.
RELEASABLE_STATES = frozenset({"PENDING_DEVELOPER_RELEASE"})

# Apple rejects a token minted for longer than twenty minutes. Ten is plenty
# for a handful of requests and leaves room for a slow runner clock.
TOKEN_LIFETIME = datetime.timedelta(minutes=10)

# A stop against paging forever if the API keeps handing back a next link.
# An app with more than twenty thousand builds is a bug, not a release.
MAX_PAGES = 100

# Apple's ceiling on the "what's new in this version" text. Play's is 500,
# which is why release_notes.py trims to that by default; nothing needs the
# extra room here, but refusing a release over it would be absurd.
WHATS_NEW_LIMIT = 4000


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


def state_of(version: dict) -> str:
    """The state of one appStoreVersions record, under either vocabulary."""
    attributes = version.get("attributes") or {}
    return (
        attributes.get("appVersionState")
        or attributes.get("appStoreState")
        or "UNKNOWN"
    )


def select_version(payload: dict, version_string: str) -> dict:
    """The version record for a marketing version, or a refusal.

    Matched here rather than with `filter[versionString]` so the caller can
    report what does exist when the requested one does not. A release stopped
    by a typo should say which versions Apple actually holds.
    """
    for version in payload.get("data") or []:
        if (version.get("attributes") or {}).get("versionString") == version_string:
            return version
    known = ", ".join(
        (v.get("attributes") or {}).get("versionString", "?")
        for v in (payload.get("data") or [])[:8]
    )
    raise AppStoreError(
        f"no App Store version {version_string!r}. "
        f"Apple holds: {known or 'nothing'}. "
        "Create the version in App Store Connect first — this promotes an "
        "existing version record, it does not invent one."
    )


def select_build_id(payload: dict, build_number: str) -> str:
    """The id of one build, by the build number Apple shows.

    Compared as text after stripping, because the caller has usually just read
    the number off a workflow summary or typed it into a dispatch form.
    """
    wanted = str(build_number).strip()
    for build in payload.get("data") or []:
        if str((build.get("attributes") or {}).get("version", "")).strip() == wanted:
            return build["id"]
    raise AppStoreError(
        f"no build {wanted!r} for this app. It has to be uploaded and finished "
        "processing before a version can be promoted with it."
    )


def check_submittable(state: str, version_string: str) -> None:
    """Refuse to touch a version that is not ours to change.

    The dangerous case is not a rejected write. It is a version already with
    Apple: editing one in review can withdraw it, so a promotion run started
    against the wrong version number would cancel a submission that was on its
    way to being approved.
    """
    if state in SUBMITTABLE_STATES:
        return
    raise AppStoreError(
        f"version {version_string} is {state}, which is not a state this can "
        "submit from. Submitting is only safe from "
        f"{', '.join(sorted(SUBMITTABLE_STATES))}. A version already with "
        "Apple has to be withdrawn in App Store Connect first, deliberately."
    )


def check_releasable(state: str, version_string: str) -> None:
    if state in RELEASABLE_STATES:
        return
    raise AppStoreError(
        f"version {version_string} is {state}, not "
        f"{', '.join(sorted(RELEASABLE_STATES))}. Only a version Apple has "
        "approved and is holding for manual release can be released. If it is "
        "still WAITING_FOR_REVIEW or IN_REVIEW, Apple has not finished yet."
    )


# The two actions a release run can ask for, and the guard each answers to.
# `skip` is absent deliberately: a caller that has decided to skip iOS should
# not be asking whether iOS would work.
ACTION_CHECKS = {
    "submit": check_submittable,
    "release": check_releasable,
}


def check_for_action(state: str, version_string: str, action: str) -> None:
    """Whether `action` could act on a version in `state`.

    The same guards `submit` and `release` apply to themselves, reachable
    without doing anything. It exists so the pipeline can ask the question
    before it asks a human to approve a release: a version already with Apple
    is a four second answer that used to arrive at the end of a run rather
    than the start of one.
    """
    check = ACTION_CHECKS.get(action)
    if check is None:
        raise AppStoreError(
            f"unknown action {action!r}. Expected one of "
            f"{', '.join(sorted(ACTION_CHECKS))}."
        )
    check(state, version_string)


def find_version(payload: dict, version_string: str) -> dict | None:
    """The version record for a marketing version, or None.

    `select_version` refuses when there is no match, which is right for
    `release`: you cannot publish a version that does not exist. Planning a
    submission needs the softer answer, because a missing version is now
    something to create rather than something to fail on.
    """
    for version in payload.get("data") or []:
        if (version.get("attributes") or {}).get("versionString") == version_string:
            return version
    return None


def editable_version(payload: dict) -> dict | None:
    """The one version still open for editing, if there is one.

    Apple allows a single editable version per platform at a time. That is the
    constraint behind every "you cannot create a new version of the App in the
    current state" refusal, and knowing which version is holding the slot is
    the difference between an error someone can act on and one they cannot.
    """
    for version in payload.get("data") or []:
        if state_of(version) in SUBMITTABLE_STATES:
            return version
    return None


def plan_version(payload: dict, version_string: str) -> tuple[str, str]:
    """Decide how to get to an editable version record for `version_string`.

    Returns one of:
      use     the version exists and is ours to edit
      create  it does not exist and nothing is holding the editable slot
      adopt   a different editable version holds the slot and would have to be
              renamed to become this one
      refuse  the version exists but is with Apple or already published

    Pure, and separated from the requests that feed it, because this is the
    whole decision. Every interesting case — a resumed release, an abandoned
    one left at the wrong number, a version already in review — is decided
    here, and none of them are comfortable to reproduce against a live store.
    """
    existing = find_version(payload, version_string)
    if existing is not None:
        state = state_of(existing)
        if state in SUBMITTABLE_STATES:
            return "use", f"{version_string} exists and is {state}"
        return (
            "refuse",
            f"{version_string} is {state}, which is not a state a submission "
            "can be prepared from. A version already with Apple has to be "
            "withdrawn in App Store Connect first, deliberately.",
        )

    holder = editable_version(payload)
    if holder is None:
        return "create", f"no {version_string} yet, and nothing else is editable"

    held = (holder.get("attributes") or {}).get("versionString")
    return (
        "adopt",
        f"{version_string} does not exist and {held} is already editable. "
        "Apple allows one editable version at a time, so this one has to be "
        f"renamed to {version_string} or finished first.",
    )


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


def send(method: str, path: str, payload: dict | None = None) -> dict:
    """One writing request against the API.

    Kept separate from `get` because these change something at Apple's end and
    are not safe to retry blindly. Apple answers a rejected write with a JSON
    body naming the field it disliked, which is printed rather than swallowed.
    """
    bearer = token()

    try:
        import requests  # noqa: PLC0415 - see the module docstring
    except ImportError:
        sys.exit("requests is needed to reach App Store Connect: pip install requests")

    response = requests.request(
        method,
        f"{API}{path}",
        json=payload,
        headers={
            "Authorization": f"Bearer {bearer}",
            "Content-Type": "application/json",
        },
        timeout=60,
    )
    # 200 returns a body, 201 created one, 204 says it worked and said nothing.
    if response.status_code not in (200, 201, 204):
        print(f"{method} {path} failed: HTTP {response.status_code}", file=sys.stderr)
        print(response.text[:1500], file=sys.stderr)
        raise SystemExit(1)
    if response.status_code == 204 or not response.content:
        return {}
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


def app_versions(app: str) -> dict:
    return get(
        f"/apps/{app}/appStoreVersions",
        {
            "limit": 20,
            "fields[appStoreVersions]":
                "versionString,appStoreState,appVersionState,releaseType,platform",
        },
    )


def find_build(app: str, build_number: str) -> str:
    payload = get(
        f"/apps/{app}/builds",
        {"limit": 200, "fields[builds]": "version,processingState"},
    )
    return select_build_id(payload, build_number)


def cmd_status(args) -> None:
    """Report what Apple currently holds. Read only, and safe to run anytime."""
    app = args.app_id or app_id()
    payload = app_versions(app)
    rows = (payload.get("data") or [])[:8]
    if not rows:
        print("no App Store versions")
        return
    for version in rows:
        attributes = version.get("attributes") or {}
        print(
            f"{attributes.get('versionString'):<10} "
            f"{state_of(version):<28} "
            f"releaseType={attributes.get('releaseType')}"
        )


def cmd_check(args) -> None:
    """Answer whether an action would be allowed, and write nothing.

    Run before the approval gate, so the whole class of failures that depend
    only on what Apple already holds costs seconds rather than arriving after
    a reviewer has approved the release and the other stores have been written
    to.

    A missing version is not a failure for `submit`, because `ensure-version`
    creates it after the gate. It is still a failure for `release`: publishing
    something that does not exist is not a thing to invent a way to do.
    """
    app = args.app_id or app_id()
    payload = app_versions(app)

    if args.action == "submit":
        action, reason = plan_version(payload, args.version)
        if action == "refuse":
            raise AppStoreError(reason)
        if action == "adopt":
            raise AppStoreError(
                reason + " Rename or finish it in App Store Connect, then run "
                "this again."
            )
        print(f"{action}: {reason}")
    else:
        version = select_version(payload, args.version)
        check_for_action(state_of(version), args.version, args.action)
        print(f"version {args.version} is {state_of(version)}")

    # Only when the caller typed one. Left blank, the workflow attaches the
    # newest build Apple holds, which by definition exists.
    if args.build:
        find_build(app, args.build)
        print(f"build {args.build} is there")

    print(f"'{args.action}' would be allowed for {args.version}")


def create_version(app: str, version_string: str) -> str:
    """Create the version record and return its id."""
    payload = send(
        "POST",
        "/appStoreVersions",
        {
            "data": {
                "type": "appStoreVersions",
                "attributes": {
                    "platform": "IOS",
                    "versionString": version_string,
                },
                "relationships": {
                    "app": {"data": {"type": "apps", "id": app}},
                },
            }
        },
    )
    return payload["data"]["id"]


def rename_version(version_id: str, version_string: str) -> None:
    """Point an existing editable version at a different marketing version."""
    send(
        "PATCH",
        f"/appStoreVersions/{version_id}",
        {
            "data": {
                "type": "appStoreVersions",
                "id": version_id,
                "attributes": {"versionString": version_string},
            }
        },
    )


def version_localizations(version_id: str) -> list[dict]:
    payload = get(
        f"/appStoreVersions/{version_id}/appStoreVersionLocalizations",
        {"limit": 50},
    )
    return payload.get("data") or []


def set_whats_new(localization_id: str, text: str) -> None:
    send(
        "PATCH",
        f"/appStoreVersionLocalizations/{localization_id}",
        {
            "data": {
                "type": "appStoreVersionLocalizations",
                "id": localization_id,
                "attributes": {"whatsNew": text},
            }
        },
    )


def cmd_ensure_version(args) -> None:
    """Make sure an editable version record exists, with release notes on it.

    This is the step that used to be done by hand, and the reason it can be
    automated at all is that Apple carries the expensive metadata forward. A
    version created through the API arrives holding the previous version's
    description, keywords, support URL and every screenshot set — measured,
    not assumed. The one field that comes back empty is `whatsNew`, which is
    precisely the field that should change every release and precisely what
    release_notes.py already writes for Play.

    What is *not* automated is the first version of an app, or a listing whose
    description needs to change: both still want a person in App Store Connect.
    This only removes the copying-forward that Apple was doing anyway.
    """
    app = args.app_id or app_id()
    action, reason = plan_version(app_versions(app), args.version)
    print(f"{action}: {reason}")

    if action == "refuse":
        raise AppStoreError(reason)

    if action == "adopt" and not args.adopt_editable:
        raise AppStoreError(
            reason + " Pass --adopt-editable to rename it, or finish it in App "
            "Store Connect. Renaming is not the default because that version "
            "may be someone's deliberate work in progress."
        )

    notes = read_notes(args)

    if args.dry_run:
        print(f"dry run: would {action} {args.version}")
        if notes:
            print(f"dry run: would set whatsNew ({len(notes)} chars)")
        return

    if action == "create":
        version_id = create_version(app, args.version)
        print(f"created {args.version} id={version_id}")
    elif action == "adopt":
        holder = editable_version(app_versions(app))
        version_id = holder["id"]
        held = (holder.get("attributes") or {}).get("versionString")
        rename_version(version_id, args.version)
        print(f"renamed {held} to {args.version} id={version_id}")
    else:
        version_id = find_version(app_versions(app), args.version)["id"]
        print(f"using existing {args.version} id={version_id}")

    if not notes:
        print("no release notes given; leaving whatsNew alone")
        return

    localizations = version_localizations(version_id)
    if not localizations:
        # Apple has always populated at least en-US in practice. If that ever
        # changes, say so rather than reporting success on a version whose
        # release notes are empty.
        print(
            "warning: Apple created no localizations for this version, so "
            "there is nothing to write release notes to. The listing will "
            "need attention in App Store Connect.",
            file=sys.stderr,
        )
        return

    for localization in localizations:
        locale = (localization.get("attributes") or {}).get("locale")
        set_whats_new(localization["id"], notes)
        print(f"whatsNew set for {locale} ({len(notes)} chars)")


def read_notes(args) -> str:
    """The release notes text, from a file or an argument.

    A file, normally: release notes are multi-line and shell quoting them
    through a workflow is a way to lose the newlines.
    """
    if getattr(args, "whats_new_file", None):
        with open(args.whats_new_file, encoding="utf-8") as handle:
            text = handle.read()
    else:
        text = getattr(args, "whats_new", "") or ""

    text = text.strip()
    if len(text) > WHATS_NEW_LIMIT:
        # Trimmed rather than refused. Apple rejects an over-long value, and
        # failing a release over the length of its changelog would be a silly
        # place to stop -- the notes are a description of the release, not the
        # release itself.
        print(
            f"release notes are {len(text)} characters; trimming to "
            f"{WHATS_NEW_LIMIT}",
            file=sys.stderr,
        )
        text = text[:WHATS_NEW_LIMIT]
    return text


def cmd_submit(args) -> None:
    """Attach a build to a version and send it to Apple for review.

    Set to MANUAL release, so approval leaves it waiting rather than putting it
    in front of users. `release` is the separate, deliberate second step.
    """
    app = args.app_id or app_id()
    version = select_version(app_versions(app), args.version)
    version_id = version["id"]
    state = state_of(version)

    # Before anything is written. The whole point is to be refused loudly
    # rather than to half-modify a version that was already with Apple.
    check_submittable(state, args.version)

    build_id = find_build(app, args.build)
    print(f"version {args.version} ({state}) id={version_id}")
    print(f"build {args.build} id={build_id}")

    if args.dry_run:
        print("dry run: nothing was sent to Apple")
        return

    send(
        "PATCH",
        f"/appStoreVersions/{version_id}",
        {
            "data": {
                "type": "appStoreVersions",
                "id": version_id,
                "attributes": {"releaseType": "MANUAL"},
            }
        },
    )
    print("release type set to MANUAL")

    send(
        "PATCH",
        f"/appStoreVersions/{version_id}/relationships/build",
        {"data": {"type": "builds", "id": build_id}},
    )
    print(f"build {args.build} attached")

    submission = send(
        "POST",
        "/reviewSubmissions",
        {
            "data": {
                "type": "reviewSubmissions",
                "attributes": {"platform": "IOS"},
                "relationships": {
                    "app": {"data": {"type": "apps", "id": app}}
                },
            }
        },
    )
    submission_id = submission["data"]["id"]

    send(
        "POST",
        "/reviewSubmissionItems",
        {
            "data": {
                "type": "reviewSubmissionItems",
                "relationships": {
                    "reviewSubmission": {
                        "data": {"type": "reviewSubmissions", "id": submission_id}
                    },
                    "appStoreVersion": {
                        "data": {"type": "appStoreVersions", "id": version_id}
                    },
                },
            }
        },
    )

    # Creating the submission and adding to it changes nothing on Apple's side
    # until this flips it. Up to here the run is still abandonable.
    send(
        "PATCH",
        f"/reviewSubmissions/{submission_id}",
        {
            "data": {
                "type": "reviewSubmissions",
                "id": submission_id,
                "attributes": {"submitted": True},
            }
        },
    )
    print(f"submitted for review (submission {submission_id})")


def cmd_release(args) -> None:
    """Release a version Apple has approved and is holding."""
    app = args.app_id or app_id()
    version = select_version(app_versions(app), args.version)
    version_id = version["id"]
    state = state_of(version)

    check_releasable(state, args.version)
    print(f"version {args.version} ({state}) id={version_id}")

    if args.dry_run:
        print("dry run: nothing was sent to Apple")
        return

    send(
        "POST",
        "/appStoreVersionReleaseRequests",
        {
            "data": {
                "type": "appStoreVersionReleaseRequests",
                "relationships": {
                    "appStoreVersion": {
                        "data": {"type": "appStoreVersions", "id": version_id}
                    }
                },
            }
        },
    )
    print(f"{args.version} released to the App Store")


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

    st = sub.add_parser("status", help="show the App Store versions and their states")
    st.add_argument("--app-id")
    st.set_defaults(func=cmd_status)

    ck = sub.add_parser(
        "check",
        help="say whether submit or release would be allowed, without doing it",
    )
    ck.add_argument("--version", required=True, help="marketing version, e.g. 3.14.2")
    ck.add_argument(
        "--action",
        required=True,
        choices=sorted(ACTION_CHECKS),
        help="the action to test",
    )
    ck.add_argument(
        "--build",
        default="",
        help="also confirm this build number exists; blank checks the version only",
    )
    ck.add_argument("--app-id")
    ck.set_defaults(func=cmd_check)

    ev = sub.add_parser(
        "ensure-version",
        help="create the version record if it is missing, and set its notes",
    )
    ev.add_argument("--version", required=True, help="marketing version, e.g. 3.14.2")
    ev.add_argument("--whats-new-file", help="file holding the release notes")
    ev.add_argument("--whats-new", default="", help="release notes as a string")
    ev.add_argument(
        "--adopt-editable",
        action="store_true",
        help="rename an existing editable version rather than refusing",
    )
    ev.add_argument("--app-id")
    ev.add_argument(
        "--dry-run",
        action="store_true",
        help="decide everything, then stop before writing",
    )
    ev.set_defaults(func=cmd_ensure_version)

    sb = sub.add_parser(
        "submit", help="attach a build to a version and submit it for review"
    )
    sb.add_argument("--version", required=True, help="marketing version, e.g. 3.14.2")
    sb.add_argument("--build", required=True, help="build number to attach")
    sb.add_argument("--app-id")
    sb.add_argument(
        "--dry-run",
        action="store_true",
        help="resolve and check everything, then stop before writing",
    )
    sb.set_defaults(func=cmd_submit)

    rl = sub.add_parser("release", help="release a version Apple has approved")
    rl.add_argument("--version", required=True, help="marketing version, e.g. 3.14.2")
    rl.add_argument("--app-id")
    rl.add_argument(
        "--dry-run",
        action="store_true",
        help="resolve and check everything, then stop before writing",
    )
    rl.set_defaults(func=cmd_release)

    args = parser.parse_args()
    try:
        args.func(args)
    except AppStoreError as exc:
        sys.exit(str(exc))


if __name__ == "__main__":
    main()
