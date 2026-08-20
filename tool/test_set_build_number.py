#!/usr/bin/env python3
"""Tests for the build number write-back.

This runs unattended, straight onto master, on a release that has already
shipped, so the interesting cases are the ones where it must refuse rather than
the ones where it succeeds: a version it cannot parse, a number that is not a
number, a file it would otherwise rewrite wholesale.

Run with: python -m unittest discover -s tool -p "test_*.py"
"""

import os
import tempfile
import unittest

from set_build_number import (
    PubspecError,
    main,
    parse_build_number,
    replace_build_number,
)

PUBSPEC = """\
name: uractor
description: An app.
publish_to: 'none'

# Bump the name; CI records the build.
version: 3.13.0+47

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  some_package:
    version: 1.2.3
"""


class ParseBuildNumber(unittest.TestCase):
    def test_reads_digits(self):
        self.assertEqual(parse_build_number("48"), 48)

    def test_accepts_an_integer(self):
        self.assertEqual(parse_build_number(48), 48)

    def test_tolerates_surrounding_whitespace(self):
        # It arrives from `python tool/play.py next-code` through a shell.
        self.assertEqual(parse_build_number(" 48\n"), 48)

    def test_rejects_a_signed_number(self):
        # int() would take "+48" happily and write a suffix Flutter reads as
        # something else.
        with self.assertRaises(PubspecError):
            parse_build_number("+48")

    def test_rejects_a_version_name(self):
        with self.assertRaises(PubspecError):
            parse_build_number("3.13.0")

    def test_rejects_zero(self):
        with self.assertRaises(PubspecError):
            parse_build_number("0")

    def test_rejects_words(self):
        # What an empty capture or a failed Play call looks like by the time it
        # reaches here.
        with self.assertRaises(PubspecError):
            parse_build_number("null")


class ReplaceBuildNumber(unittest.TestCase):
    def test_replaces_the_build_number(self):
        self.assertIn("version: 3.13.0+48", replace_build_number(PUBSPEC, "48"))

    def test_leaves_the_name_alone(self):
        # The name is a human decision under AGENTS.md, enforced on pull
        # requests. CI moving it would take that decision away.
        self.assertNotIn("3.13.0+47", replace_build_number(PUBSPEC, "48"))
        self.assertIn("3.13.0+", replace_build_number(PUBSPEC, "48"))

    def test_changes_nothing_else_in_the_file(self):
        # The diff lands on master unreviewed, so it has to be one line.
        before = PUBSPEC.splitlines()
        after = replace_build_number(PUBSPEC, "48").splitlines()
        self.assertEqual(len(before), len(after))
        differences = [
            (old, new) for old, new in zip(before, after) if old != new
        ]
        self.assertEqual(differences, [("version: 3.13.0+47", "version: 3.13.0+48")])

    def test_ignores_a_version_inside_a_dependency(self):
        # Dependencies are indented and the project version is not; matching
        # "version" anywhere would rewrite a package constraint.
        self.assertIn("    version: 1.2.3", replace_build_number(PUBSPEC, "48"))

    def test_is_a_no_op_when_the_number_already_matches(self):
        # The caller commits only when the text changed, so an unchanged return
        # is what keeps an empty commit off master.
        self.assertEqual(replace_build_number(PUBSPEC, "47"), PUBSPEC)

    def test_preserves_crlf_line_endings(self):
        # A Windows checkout can hand this file over with CRLF. Rewriting every
        # ending would turn a one-line change into a whole-file diff.
        source = PUBSPEC.replace("\n", "\r\n")
        result = replace_build_number(source, "48")
        self.assertIn("version: 3.13.0+48\r\n", result)
        self.assertNotIn("\n", result.replace("\r\n", ""))

    def test_preserves_a_missing_trailing_newline(self):
        source = "name: uractor\nversion: 3.13.0+47"
        self.assertEqual(
            replace_build_number(source, "48"), "name: uractor\nversion: 3.13.0+48"
        )

    def test_raises_when_there_is_no_version_line(self):
        with self.assertRaises(PubspecError):
            replace_build_number("name: uractor\n", "48")

    def test_raises_on_a_version_with_no_build_number(self):
        with self.assertRaises(PubspecError):
            replace_build_number("version: 3.13.0\n", "48")

    def test_raises_on_a_prerelease_version(self):
        with self.assertRaises(PubspecError):
            replace_build_number("version: 3.13.0-beta+47\n", "48")

    def test_raises_on_a_commented_version_line(self):
        # Refused rather than mangled: check_version_bump.py reads the line
        # just as strictly, so this shape is already broken elsewhere.
        with self.assertRaises(PubspecError):
            replace_build_number("version: 3.13.0+47 # build\n", "48")

    def test_raises_on_two_version_lines(self):
        with self.assertRaises(PubspecError):
            replace_build_number("version: 3.13.0+47\nversion: 3.13.0+47\n", "48")

    def test_raises_on_a_bad_build_number_before_touching_anything(self):
        with self.assertRaises(PubspecError):
            replace_build_number(PUBSPEC, "")


class Main(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.path = os.path.join(directory.name, "pubspec.yaml")
        self.write(PUBSPEC)

    def write(self, text):
        with open(self.path, "w", encoding="utf-8", newline="") as handle:
            handle.write(text)

    def read(self):
        with open(self.path, encoding="utf-8", newline="") as handle:
            return handle.read()

    def test_writes_the_number_and_succeeds(self):
        self.assertEqual(main(["48", "--pubspec", self.path]), 0)
        self.assertIn("version: 3.13.0+48", self.read())

    def test_succeeds_without_writing_when_nothing_changes(self):
        # A release that re-runs against the same code must not push an empty
        # commit, and must not report a failure either.
        self.assertEqual(main(["47", "--pubspec", self.path]), 0)
        self.assertEqual(self.read(), PUBSPEC)

    def test_fails_without_writing_when_the_version_cannot_be_read(self):
        self.write("name: uractor\n")
        self.assertEqual(main(["48", "--pubspec", self.path]), 1)
        self.assertEqual(self.read(), "name: uractor\n")

    def test_fails_without_writing_on_a_bad_build_number(self):
        self.assertEqual(main(["nope", "--pubspec", self.path]), 1)
        self.assertEqual(self.read(), PUBSPEC)

    def test_fails_when_the_pubspec_is_missing(self):
        self.assertEqual(main(["48", "--pubspec", self.path + ".absent"]), 1)


if __name__ == "__main__":
    unittest.main()
