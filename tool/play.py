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

from google.oauth2 import service_account
from google.auth.transport.requests import AuthorizedSession

PACKAGE = "com.uractor.uractorapp"
API = "https://androidpublisher.googleapis.com/androidpublisher/v3"
UPLOAD = "https://androidpublisher.googleapis.com/upload/androidpublisher/v3"
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]


def session() -> AuthorizedSession:
    raw = os.environ.get("PLAY_SERVICE_ACCOUNT_JSON")
    if not raw:
        sys.exit("PLAY_SERVICE_ACCOUNT_JSON is not set.")
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
            "status": args.status,
            "releaseNotes": load_notes(args.notes, languages),
        }
        if args.status == "inProgress":
            release["userFraction"] = args.rollout

        r = s.put(edit.url(f"/tracks/{args.track}"),
                  json={"track": args.track, "releases": [release]})
        edit.check(r, "tracks.update")
        edit.commit()

    print(f"released version code {code} to '{args.track}' ({args.status})")
    if out := os.environ.get("GITHUB_OUTPUT"):
        with open(out, "a", encoding="utf-8") as fh:
            fh.write(f"version-code={code}\n")


def cmd_promote(args) -> None:
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
            "status": args.status,
            "releaseNotes": load_notes(args.notes, languages),
        }
        if args.status == "inProgress":
            release["userFraction"] = args.rollout

        r = s.put(edit.url(f"/tracks/{args.target}"),
                  json={"track": args.target, "releases": [release]})
        edit.check(r, "tracks.update")
        edit.commit()

    detail = f" at {args.rollout:.0%}" if args.status == "inProgress" else ""
    print(f"promoted {code} to '{args.target}' ({args.status}{detail})")


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
                    help="user fraction for inProgress, e.g. 0.1")
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
    pr.add_argument("--rollout", type=float, default=0.2)
    pr.add_argument("--release-name")
    pr.add_argument("--notes", help="JSON file of {language: text}")
    pr.set_defaults(func=cmd_promote)

    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
