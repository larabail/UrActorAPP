#!/usr/bin/env python3
"""Tests for the update manifest written at release time.

Run with: python -m unittest discover -s tool -p "test_*.py"

The manifest has two readers that never meet: a running copy of the app, which
uses it to decide whether to offer an update, and the downloads page, which
falls back to it when the GitHub API cannot be reached. Neither is exercised by
anything else in CI, and a manifest either of them cannot read fails silently
-- the app simply never mentions that a release happened.
"""

import json
import unittest

from build_download_manifest import (
    DOWNLOADS_URL,
    asset_urls,
    build_manifest,
)


class AssetUrlTests(unittest.TestCase):
    def test_urls_point_at_the_tag_for_that_version(self):
        urls = asset_urls("3.16.0")
        self.assertIn("/releases/download/v3.16.0/", urls["macos"])
        self.assertIn("/releases/download/v3.16.0/", urls["windows"])

    def test_the_filenames_carry_the_version(self):
        urls = asset_urls("3.16.0")
        self.assertTrue(urls["macos"].endswith("UrActor-3.16.0-macos.dmg"))
        self.assertTrue(
            urls["windows"].endswith("UrActor-3.16.0-windows-setup.exe"))

    def test_every_url_is_https(self):
        for url in asset_urls("3.16.0").values():
            self.assertTrue(url.startswith("https://"), url)


class ManifestTests(unittest.TestCase):
    def test_carries_the_version_being_released(self):
        manifest = build_manifest("3.16.0", None, "2026-08-21")
        self.assertEqual(manifest["version"], "3.16.0")

    def test_sends_people_to_the_page_not_the_file(self):
        # On Windows the installer is unsigned and warns; the page is where
        # that is explained. Linking the file directly means meeting the
        # warning with no context.
        manifest = build_manifest("3.16.0", None, "2026-08-21")
        self.assertEqual(manifest["downloadUrl"], DOWNLOADS_URL)
        self.assertTrue(manifest["downloadUrl"].startswith("https://"))

    def test_notes_are_omitted_rather_than_empty(self):
        manifest = build_manifest("3.16.0", None, "2026-08-21")
        self.assertNotIn("notes", manifest)

    def test_notes_are_included_when_given(self):
        manifest = build_manifest("3.16.0", "Playlists reorder.", "2026-08-21")
        self.assertEqual(manifest["notes"], "Playlists reorder.")

    def test_is_the_shape_the_app_parses(self):
        # Mirrors UpdateManifest.tryParse in lib/common/update/update_check.dart:
        # a version it can read, and an https downloadUrl.
        manifest = build_manifest("3.16.0", "x", "2026-08-21")
        decoded = json.loads(json.dumps(manifest))
        self.assertIsInstance(decoded["version"], str)
        self.assertEqual(len(decoded["version"].split(".")), 3)
        self.assertTrue(decoded["downloadUrl"].startswith("https://"))

    def test_is_the_shape_the_downloads_page_falls_back_to(self):
        # Mirrors manifestRelease in web/downloads/releases.js. It needs a
        # version, a date, and per-platform installer links -- and it drops
        # any link it cannot classify, which is what would happen if the
        # extensions here ever stopped matching the ones the page knows.
        manifest = build_manifest("3.16.0", None, "2026-08-21")
        self.assertEqual(manifest["published"], "2026-08-21")

        assets = manifest["assets"]
        self.assertEqual(sorted(assets), ["macos", "windows"])
        self.assertTrue(assets["macos"].endswith(".dmg"))
        self.assertTrue(assets["windows"].endswith(".exe"))
        for url in assets.values():
            self.assertTrue(url.startswith("https://"), url)
            # The page reads the filename back off the end of the URL, so a
            # URL ending in a slash would leave the fallback nameless.
            self.assertTrue(url.rsplit("/", 1)[-1])


if __name__ == "__main__":
    unittest.main()
