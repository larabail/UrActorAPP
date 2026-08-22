#!/usr/bin/env python3
"""Tests for the downloads site generator.

Run with: python -m unittest discover -s tool -p "test_*.py"

The thing worth pinning down is that the page and the manifest agree. They are
read by different audiences -- a person and a running copy of the app -- and if
they disagree the app either never mentions a release that exists or points at
a file that does not.
"""

import json
import unittest

from build_downloads_site import (
    DOWNLOADS_URL,
    asset_urls,
    build_manifest,
    render_page,
)

TEMPLATE = """<html>
<p>{{VERSION}} on {{DATE}}</p>
<a href="{{MACOS_URL}}">mac</a>
<a href="{{WINDOWS_URL}}">win</a>
<a href="{{CHECKSUMS_URL}}">sums</a>
<p>{{NOTES}}</p>
</html>"""


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


class PageTests(unittest.TestCase):
    def test_fills_every_placeholder(self):
        page = render_page(TEMPLATE, "3.16.0", "Notes here", "2026-08-21")
        self.assertNotIn("{{", page)

    def test_refuses_to_ship_an_unfilled_placeholder(self):
        # A field added to the template that this script does not know about
        # would otherwise appear as literal braces on a public page.
        with self.assertRaises(SystemExit):
            render_page(TEMPLATE + "{{NEW_FIELD}}", "3.16.0", None,
                        "2026-08-21")

    def test_falls_back_to_a_sentence_when_there_are_no_notes(self):
        page = render_page(TEMPLATE, "3.16.0", None, "2026-08-21")
        self.assertIn("release notes", page)

    def test_page_and_manifest_advertise_the_same_version(self):
        version = "3.16.0"
        page = render_page(TEMPLATE, version, None, "2026-08-21")
        manifest = build_manifest(version, None, "2026-08-21")

        self.assertIn(version, page)
        self.assertEqual(manifest["version"], version)
        # And the page links the very files the manifest names.
        for url in manifest["assets"].values():
            self.assertIn(url, page)


if __name__ == "__main__":
    unittest.main()
