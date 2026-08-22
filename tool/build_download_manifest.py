#!/usr/bin/env python3
"""Write the manifest a running copy of the app polls for updates.

The desktop builds are not delivered by a store, so nothing tells an install
that a newer version exists. It asks, by fetching
`downloads.uractor.com/version.json` and comparing what that advertises
against the version it is running. This writes that file at release time.

It used to generate the downloads page as well, from a template beside it.
That is gone: the page now reads the GitHub releases API in the browser, so it
describes whatever is actually downloadable instead of whatever was true
during the last successful release run, and it can list older versions without
this script knowing they exist. What is left here is the one thing a browser
cannot work out on its own -- a same-origin file the app can rely on even when
the API is rate limited, which is the fallback the page uses too.

The installers themselves are not hosted here. They go to GitHub Releases,
which serves large files over a CDN for free and does not bill for bandwidth;
this site only links to them. Hosting 150MB installers on Firebase Hosting
would bill per gigabyte after the free tier, which about sixty downloads a
month would exhaust.

Usage:
    python tool/build_download_manifest.py --version 3.16.0
    python tool/build_download_manifest.py --version 3.16.0 --notes "..." \
        --date 2026-08-21 --out web/downloads
"""

from __future__ import annotations

import argparse
import datetime
import json
import os

REPO = "larabail/UrActorAPP"

# Where a release's assets live. The tag is `v` + the version, which is the
# convention the release workflow uses and the only place it is written down.
RELEASE_BASE = "https://github.com/{repo}/releases/download/v{version}"

DOWNLOADS_URL = "https://downloads.uractor.com/"

MACOS_ASSET = "UrActor-{version}-macos.dmg"
WINDOWS_ASSET = "UrActor-{version}-windows-setup.exe"


def asset_urls(version: str, repo: str = REPO) -> dict[str, str]:
    """The download URLs for [version]'s installers.

    Constructed rather than read back from the release, because this runs in
    the same job that has just uploaded them and their names are fixed by the
    workflow that built them.
    """
    base = RELEASE_BASE.format(repo=repo, version=version)
    return {
        "macos": f"{base}/{MACOS_ASSET.format(version=version)}",
        "windows": f"{base}/{WINDOWS_ASSET.format(version=version)}",
    }


def build_manifest(version: str, notes: str | None, date: str,
                   repo: str = REPO) -> dict:
    """The `version.json` the app polls.

    `downloadUrl` points at the page rather than at a file, deliberately. On
    Windows the installer is unsigned and produces a SmartScreen warning, and
    the page is where that is explained; sending someone straight to the file
    means they meet the warning with no context.

    `assets` is not read by the app. It is there for the page, which falls
    back to this file when the GitHub API cannot be reached and then needs
    real installer links to offer, rather than another link to the release.
    """
    manifest = {
        "version": version,
        "downloadUrl": DOWNLOADS_URL,
        "published": date,
        "assets": asset_urls(version, repo),
    }
    if notes:
        manifest["notes"] = notes
    return manifest


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--version", required=True,
                   help="the version being released, without a leading v")
    p.add_argument("--notes", default=None,
                   help="a short description of what changed")
    p.add_argument("--date", default=None,
                   help="release date, YYYY-MM-DD (default: today, UTC)")
    p.add_argument("--out", default="web/downloads",
                   help="directory to write version.json into")
    p.add_argument("--repo", default=REPO)
    args = p.parse_args()

    version = args.version.lstrip("vV")
    date = args.date or datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")

    os.makedirs(args.out, exist_ok=True)

    manifest = build_manifest(version, args.notes, date, args.repo)
    path = os.path.join(args.out, "version.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)
        f.write("\n")

    print(f"Wrote {path} for {version}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
