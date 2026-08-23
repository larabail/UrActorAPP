#!/usr/bin/env python3
"""Google Play release helper.

Wraps the Play Developer Publishing API so CI never has to speak it directly.
Every mutation runs inside an edit transaction: the edit is opened, changed,
then committed. Nothing reaches Play until the commit succeeds, and any
failure abandons the edit, so a broken run cannot leave a half-applied
release behind.

Credentials come from the PLAY_SERVICE_ACCOUNT_JSON environment variable,
holding the service account key itself rather than a path, so CI can pass it
straight from a secret without writing it to disk.

Subcommands:
  next-code  Print the next unused version code.
  upload     Upload an .aab and assign it to a track.
  promote    Move an existing version code to another track without rebuilding.
"""

from __future__ import annotations

import argparse
import json
import os
import sys

PACKAGE = "com.uractor.uractorapp"
API = "https://androidpublisher.googleapis.com/androidpublisher/v3"
UPLOAD = "https://androidpublisher.googleapis.com/upload/androidpublisher/v3"
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]


def session() -> "AuthorizedSession":
    raw = os.environ.get("PLAY_SERVICE_ACCOUNT_JSON")
    if not raw:
        sys.exit("PLAY_SERVICE_ACCOUNT_JSON is not set.")

    # Imported here rather than at the top so the module can be imported --
    # and its rollout arithmetic tested -- without google-auth installed. The
    # pull request workflow runs those tests on a bare Python, and installing
    # a Play API client to exercise a function that never speaks to Play would
    # be a poor trade. After the credential check, so a run with neither the
    # secret nor the dependency still says which one it wanted first.
    try:
        from google.oauth2 import service_account
        from google.auth.transport.requests import AuthorizedSession
    except ImportError as exc:
        sys.exit(f"{exc}. Install it with: pip install google-auth requests")

    try:
        info = json.loads(raw)
    except json.JSONDecodeError as exc:
        sys.exit(f"PLAY_SERVICE_ACCOUNT_JSON is not valid JSON: {exc}")
    creds = service_account.Credentials.from_service_account_info(
        info, scopes=SCOPES)
    return AuthorizedSession(creds)


class Edit:
    """An edit transaction that abandons itself unless it is committed."""

    def __init__(self, s: AuthorizedSession):
        self.s = s
        self.id: str | None = None
        self.committed = False

    def __enter__(self) -> "Edit":
        r = self.s.post(f"{API}/applications/{PACKAGE}/edits")
        self.check(r, "edits.insert")
        self.id = r.json()["id"]
        return self

    def __exit__(self, exc_type, exc, tb) -> bool:
        if self.id and not self.committed:
            self.s.delete(f"{API}/applications/{PACKAGE}/edits/{self.id}")
            if exc_type is not None:
                print("edit abandoned; nothing was published", file=sys.stderr)
        return False

    def url(self, path: str = "") -> str:
        return f"{API}/applications/{PACKAGE}/edits/{self.id}{path}"

    def check(self, r, step: str) -> None:
        if r.status_code != 200:
            print(f"{step} failed: HTTP {r.status_code}", file=sys.stderr)
            print(r.text[:1500], file=sys.stderr)
            raise SystemExit(1)

    def commit(self) -> None:
        r = self.s.post(f"{API}/applications/{PACKAGE}/edits/{self.id}:commit")
        self.check(r, "edits.commit")
        self.committed = True

    def used_version_codes(self) -> list[int]:
        codes: list[int] = []
        for kind in ("bundles", "apks"):
            r = self.s.get(self.url(f"/{kind}"))
            if r.status_code == 200:
                codes += [x["versionCode"] for x in r.json().get(kind, [])]
        return codes

    def listing_languages(self) -> set[str]:
        r = self.s.get(self.url("/listings"))
        if r.status_code != 200:
            return set()
        return {x["language"] for x in r.json().get("listings", [])}

    def track(self, name: str) -> dict:
        r = self.s.get(self.url(f"/tracks/{name}"))
        self.check(r, f"tracks.get({name})")
        return r.json()


class PlayError(ValueError):
    """A release that Play would refuse, caught before an edit is opened."""


def rollout_plan(status: str, rollout: float) -> tuple[str, float | None]:
    """Reconcile a requested status and rollout into what Play will accept.

    Play has no such thing as a 100% staged rollout. `userFraction` is the
    share a release is *held back* to, so the API takes it only alongside
    `inProgress` or `halted`, and only in [0, 1). Asking for `inProgress` at
    1.0 is not read as "everyone" — it fails the whole edit with

        User fraction must be greater than or equal to 0 and lower than one.

    which abandons the edit and publishes nothing. A rollout that reaches
    everyone is `completed`, carrying no fraction at all, so that is what a
    request for 100% is turned into here.

    Only an exact 1.0 is treated that way. Anything above it is a caller that
    passed a percentage where a fraction belongs, and quietly reading 20 as
    "release to everyone" is the worst possible way to be wrong.
    """
    if status not in ("inProgress", "halted"):
        return status, None

    if not 0.0 <= rollout <= 1.0:
        raise PlayError(
            f"rollout must be a fraction between 0 and 1, not {rollout}. "
            "20% is 0.2."
        )

    if rollout == 1.0:
        if status == "halted":
            # A halted release is one that was stopped part way. At 100% there
            # is nothing left to stop, so this is a request that cannot be
            # honoured rather than one to reinterpret.
            raise PlayError(
                "a halted release cannot be at 100%: halting stops a rollout "
                "short of everyone. Halt at the fraction it reached, or use "
                "--status completed to release to everyone."
            )
        return "completed", None

    return status, rollout


def describe(status: str, fraction: float | None) -> str:
    """How a resolved release reads in a log line or a run summary."""
    if fraction is None:
        return status
    return f"{status} at {fraction:.0%}"


def write_outputs(code: int, rollout: str) -> None:
    """Hand the version code and what it was released as back to the workflow.

    The run summary reports what Play was actually told, not what the operator
    typed into the form, because the two differ whenever a rollout is asked
    for at 100%.
    """
    if out := os.environ.get("GITHUB_OUTPUT"):
        with open(out, "a", encoding="utf-8") as fh:
            fh.write(f"version-code={code}\n")
            fh.write(f"rollout={rollout}\n")


def load_notes(path: str | None, languages: set[str]) -> list[dict]:
    """Read release notes, keeping only languages the listing actually has.

    Play rejects notes for a language with no store listing, which would fail
    the whole release over a translation.
    """
    if not path:
        return []
    with open(path, encoding="utf-8") as fh:
        notes = json.load(fh)

    kept = [{"language": lang, "text": text}
            for lang, text in notes.items() if lang in languages]
    skipped = sorted(lang for lang in notes if lang not in languages)
    if skipped:
        print(f"skipping notes for languages with no listing: {skipped}")
    return kept


def cmd_next_code(args) -> None:
    with Edit(session()) as edit:
        codes = edit.used_version_codes()
    # Play refuses a version code that was ever uploaded, even to an edit that
    # was abandoned and never assigned to a track, so the next code has to
    # clear the highest ever seen rather than the highest currently released.
    nxt = max(codes) + 1 if codes else 1
    print(nxt)


def cmd_upload(args) -> None:
    status, fraction = rollout_plan(args.status, args.rollout)
    s = session()
    with Edit(s) as edit:
        languages = edit.listing_languages()
        with open(args.aab, "rb") as fh:
            data = fh.read()
        print(f"uploading {len(data) / 1024 / 1024:.1f} MB from {args.aab}")
        r = s.post(
            f"{UPLOAD}/applications/{PACKAGE}/edits/{edit.id}/bundles"
            "?uploadType=media",
            data=data,
            headers={"Content-Type": "application/octet-stream"},
        )
        edit.check(r, "bundles.upload")
        code = r.json()["versionCode"]
        print(f"uploaded version code {code}")

        release = {
            "name": args.release_name or str(code),
            "versionCodes": [str(code)],
            "status": status,
            "releaseNotes": load_notes(args.notes, languages),
        }
        if fraction is not None:
            release["userFraction"] = fraction

        r = s.put(edit.url(f"/tracks/{args.track}"),
                  json={"track": args.track, "releases": [release]})
        edit.check(r, "tracks.update")
        edit.commit()

    detail = describe(status, fraction)
    print(f"released version code {code} to '{args.track}' ({detail})")
    write_outputs(code, detail)


def cmd_promote(args) -> None:
    status, fraction = rollout_plan(args.status, args.rollout)
    s = session()
    with Edit(s) as edit:
        code = args.version_code
        if code is None:
            # Promote whatever the source track is serving, so the artifact
            # that shipped to testers is the one that reaches production.
            releases = edit.track(args.source).get("releases", [])
            candidates = [
                int(v)
                for rel in releases
                if rel.get("status") in ("completed", "inProgress")
                for v in (rel.get("versionCodes") or [])
            ]
            if not candidates:
                sys.exit(f"no released version code found on '{args.source}'")
            code = max(candidates)
            print(f"latest on '{args.source}': {code}")

        languages = edit.listing_languages()

        # Play will not accept a production release that goes backwards, and a
        # silent downgrade attempt is a confusing way to find that out. This
        # also catches the case where someone uploaded to the target track by
        # hand, leaving it ahead of the source track.
        live = [
            int(v)
            for rel in edit.track(args.target).get("releases", [])
            if rel.get("status") in ("completed", "inProgress")
            for v in (rel.get("versionCodes") or [])
        ]
        if live and code <= max(live):
            sys.exit(
                f"refusing to promote {code} to '{args.target}': it already "
                f"serves {max(live)}. Version codes must increase. If {max(live)} "
                "was uploaded by hand, build a newer version instead."
            )

        release = {
            "name": args.release_name or str(code),
            "versionCodes": [str(code)],
            "status": status,
            "releaseNotes": load_notes(args.notes, languages),
        }
        if fraction is not None:
            release["userFraction"] = fraction

        r = s.put(edit.url(f"/tracks/{args.target}"),
                  json={"track": args.target, "releases": [release]})
        edit.check(r, "tracks.update")
        edit.commit()

    detail = describe(status, fraction)
    print(f"promoted {code} to '{args.target}' ({detail})")
    write_outputs(code, detail)


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="command", required=True)

    sub.add_parser("next-code", help="print the next unused version code"
                   ).set_defaults(func=cmd_next_code)

    up = sub.add_parser("upload", help="upload an .aab and assign it to a track")
    up.add_argument("--aab", required=True)
    up.add_argument("--track", default="internal")
    up.add_argument("--status", default="completed",
                    choices=["completed", "draft", "inProgress", "halted"])
    up.add_argument("--rollout", type=float, default=1.0,
                    help="user fraction for inProgress, e.g. 0.1. 1.0 means "
                         "everyone, which Play expresses as --status completed")
    up.add_argument("--release-name")
    up.add_argument("--notes", help="JSON file of {language: text}")
    up.set_defaults(func=cmd_upload)

    pr = sub.add_parser("promote", help="move a version code to another track")
    pr.add_argument("--source", default="internal")
    pr.add_argument("--target", default="production")
    pr.add_argument("--version-code", type=int,
                    help="defaults to the latest release on --source")
    pr.add_argument("--status", default="inProgress",
                    choices=["completed", "draft", "inProgress", "halted"])
    pr.add_argument("--rollout", type=float, default=0.2,
                    help="user fraction for inProgress, e.g. 0.2. 1.0 means "
                         "everyone and is sent as a completed release")
    pr.add_argument("--release-name")
    pr.add_argument("--notes", help="JSON file of {language: text}")
    pr.set_defaults(func=cmd_promote)

    args = p.parse_args()
    try:
        args.func(args)
    except PlayError as exc:
        # A release Play would refuse is reported here rather than costing a
        # round trip and an abandoned edit to find out.
        sys.exit(str(exc))


if __name__ == "__main__":
    main()
