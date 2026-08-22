#!/usr/bin/env python3
"""Build the downloads site for a desktop release.

The site is two files: a page a person reads, and a `version.json` a running
copy of the app reads to find out it is out of date. Both are generated from
the same inputs here so they cannot disagree -- a page advertising 3.16.0
beside a manifest still saying 3.15.0 would leave every existing install
unaware of a release that visibly exists.

The installers themselves are not hosted here. They go to GitHub Releases,
which serves large files over a CDN for free and does not bill for bandwidth;
this site only links to them. Hosting 150MB installers on Firebase Hosting
would bill per gigabyte after the free tier, which about sixty downloads a
month would exhaust.

Usage:
    python tool/build_downloads_site.py --version 3.16.0 --out web/downloads
    python tool/build_downloads_site.py --version 3.16.0 --notes "..." --date 2026-08-21
"""

from __future__ import annotations

import argparse
import datetime
import json
import os
import sys

REPO = "larabail/UrActorAPP"

# Where a release's assets live. The tag is `v` + the version, which is the
# convention the release workflow uses and the only place it is written down.
RELEASE_BASE = "https://github.com/{repo}/releases/download/v{version}"
RELEASE_PAGE = "https://github.com/{repo}/releases/tag/v{version}"

DOWNLOADS_URL = "https://downloads.uractor.com/"

MACOS_ASSET = "UrActor-{version}-macos.dmg"
WINDOWS_ASSET = "UrActor-{version}-windows-setup.exe"


def asset_urls(version: str, repo: str = REPO) -> dict[str, str]:
    """The download URLs for [version]'s installers."""
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


def render_page(template: str, version: str, notes: str | None, date: str,
                repo: str = REPO) -> str:
    """Fills the page template for [version]."""
    urls = asset_urls(version, repo)
    replacements = {
        "{{VERSION}}": version,
        "{{DATE}}": date,
        "{{MACOS_URL}}": urls["macos"],
        "{{WINDOWS_URL}}": urls["windows"],
        "{{CHECKSUMS_URL}}": RELEASE_PAGE.format(repo=repo, version=version),
        "{{NOTES}}": notes or "See the release notes on GitHub.",
    }
    for token, value in replacements.items():
        template = template.replace(token, value)

    # A placeholder left in the output means the template grew a field this
    # script does not know how to fill, which would ship as literal braces on
    # a public page.
    if "{{" in template:
        leftover = template[template.index("{{"):template.index("{{") + 40]
        raise SystemExit(f"unfilled placeholder in template: {leftover!r}")

    return template


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
                   help="directory to write index.html and version.json into")
    p.add_argument("--repo", default=REPO)
    args = p.parse_args()

    version = args.version.lstrip("vV")
    date = args.date or datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")

    template_path = os.path.join(args.out, "index.template.html")
    if not os.path.exists(template_path):
        print(f"No template at {template_path}", file=sys.stderr)
        return 1
    with open(template_path, encoding="utf-8") as f:
        template = f.read()

    os.makedirs(args.out, exist_ok=True)

    page = render_page(template, version, args.notes, date, args.repo)
    with open(os.path.join(args.out, "index.html"), "w", encoding="utf-8") as f:
        f.write(page)

    manifest = build_manifest(version, args.notes, date, args.repo)
    with open(os.path.join(args.out, "version.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)
        f.write("\n")

    print(f"Built downloads site for {version} in {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
