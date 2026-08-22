#!/usr/bin/env python3
"""Throwaway experiment: what does Apple populate on an API-created version?

DELETE THIS FILE once the question below is answered. It exists to settle one
thing that the documentation does not state and that two searches answered
differently, and it is not part of the release pipeline.

The question
------------
`tool/appstore.py` refuses to create an App Store version record, on the
grounds that a submission fails without screenshots, a description and release
notes, and that store copy is not something to generate unattended. That is
sound for the *first* version of an app. It may be nonsense for the fifteenth:
in the App Store Connect UI, creating a version copies the previous version's
description, keywords and screenshots forward, leaving only "what's new" to
write — and "what's new" is exactly what `release_notes.py` already generates
for Play.

If the API does the same thing, the manual step in the middle of every iOS
release is unnecessary and the pipeline can create the version itself. If it
does not, the manual step is real and should stay.

What this does
--------------
1. Reports what Apple currently holds, so a pre-existing editable version is
   visible before anything is written.
2. Creates the requested version.
3. Reads back its localizations and screenshot sets and reports, per locale,
   which fields arrived populated and which arrived empty.
4. Deletes it again, unless told to keep it.

Creating a version is invisible to users -- it sits in PREPARE_FOR_SUBMISSION
until something submits it -- and an unsubmitted version can be deleted, which
is what makes this safe to run against the live app.

Run it through .github/workflows/probe-appstore.yml, which has the credentials.
"""

from __future__ import annotations

import argparse
import sys

import appstore

# Fields worth knowing about on a version localization. The interesting ones
# are `description` and `keywords`, which are the expensive things to re-enter,
# and `whatsNew`, which is the one that genuinely changes every release.
LOCALIZATION_FIELDS = (
    "locale",
    "description",
    "keywords",
    "whatsNew",
    "promotionalText",
    "marketingUrl",
    "supportUrl",
)


def describe(value) -> str:
    """A field's state, without printing a whole store description."""
    if value is None:
        return "absent (null)"
    text = str(value)
    if not text.strip():
        return "EMPTY"
    collapsed = " ".join(text.split())
    if len(collapsed) > 60:
        return f"{len(text)} chars: {collapsed[:57]}..."
    return f"{len(text)} chars: {collapsed}"


def create_version(app: str, version_string: str) -> str:
    """Create the version record and return its id."""
    payload = appstore.send(
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


def report_localizations(version_id: str) -> int:
    """Print what each localization arrived with. Returns how many there were."""
    payload = appstore.get(
        f"/appStoreVersions/{version_id}/appStoreVersionLocalizations",
        {"limit": 50},
    )
    localizations = payload.get("data") or []

    print()
    print(f"localizations Apple created: {len(localizations)}")
    if not localizations:
        print("  none — nothing was carried forward, so metadata is a manual step")
        return 0

    for localization in localizations:
        attributes = localization.get("attributes") or {}
        print()
        print(f"  locale {attributes.get('locale')} (id {localization['id']})")
        for field in LOCALIZATION_FIELDS:
            if field == "locale":
                continue
            print(f"    {field:<16} {describe(attributes.get(field))}")
        report_screenshots(localization["id"])

    return len(localizations)


def report_screenshots(localization_id: str) -> None:
    """Print the screenshot sets hanging off one localization."""
    payload = appstore.get(
        f"/appStoreVersionLocalizations/{localization_id}/appScreenshotSets",
        {"limit": 50},
    )
    sets = payload.get("data") or []
    if not sets:
        print("    screenshots      NONE — they would have to be uploaded")
        return

    print(f"    screenshots      {len(sets)} set(s):")
    for screenshot_set in sets:
        display_type = (screenshot_set.get("attributes") or {}).get(
            "screenshotDisplayType"
        )
        shots = appstore.get(
            f"/appScreenshotSets/{screenshot_set['id']}/appScreenshots",
            {"limit": 50},
        )
        count = len(shots.get("data") or [])
        print(f"      {display_type:<28} {count} screenshot(s)")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True, help="version to create")
    parser.add_argument(
        "--keep",
        action="store_true",
        help="leave the version behind instead of deleting it",
    )
    args = parser.parse_args()

    app = appstore.app_id()
    print(f"app id {app}")
    print()
    print("before:")
    existing = appstore.app_versions(app)
    for version in (existing.get("data") or [])[:8]:
        attributes = version.get("attributes") or {}
        print(
            f"  {attributes.get('versionString'):<10} "
            f"{appstore.state_of(version):<28} "
            f"releaseType={attributes.get('releaseType')}"
        )

    # Apple allows one editable version at a time. Saying so here turns a raw
    # 409 into something that explains itself.
    editable = [
        (v.get("attributes") or {}).get("versionString")
        for v in (existing.get("data") or [])
        if appstore.state_of(v) in appstore.SUBMITTABLE_STATES
    ]
    if editable:
        print()
        print(
            f"note: {', '.join(editable)} is already editable. Apple permits one "
            "editable version at a time, so the create below will probably be "
            "refused — which is itself an answer: the record already exists."
        )

    print()
    print(f"creating {args.version} ...")
    version_id = create_version(app, args.version)
    print(f"created, id={version_id}")

    try:
        count = report_localizations(version_id)
        print()
        print("=" * 66)
        if count:
            print(
                "VERDICT: Apple populated localizations on an API-created "
                "version.\nCheck above whether description/keywords/screenshots "
                "came with them.\nIf they did, the pipeline can create the "
                "version and set whatsNew itself."
            )
        else:
            print(
                "VERDICT: nothing was carried forward. Creating the version by "
                "API would\nleave the metadata to be filled in anyway, so the "
                "manual step is real."
            )
        print("=" * 66)
    finally:
        if args.keep:
            print()
            print(f"keeping {args.version} (id={version_id}) as asked.")
        else:
            print()
            print(f"deleting {args.version} (id={version_id}) ...")
            appstore.send("DELETE", f"/appStoreVersions/{version_id}")
            print("deleted; the app is back as it was.")


if __name__ == "__main__":
    try:
        main()
    except appstore.AppStoreError as exc:
        sys.exit(str(exc))
