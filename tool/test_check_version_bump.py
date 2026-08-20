#!/usr/bin/env python3
"""Tests for the version bump check.

Run with: python -m unittest discover -s tool -p "test_*.py"
"""

import unittest

from check_version_bump import (
    MAJOR,
    MINOR,
    NONE,
    PATCH,
    VersionError,
    bump_level,
    check,
    level_for_subject,
    parse_version,
    required_level,
    version_from_pubspec,
)


class ParseVersion(unittest.TestCase):
    def test_reads_the_four_components(self):
        self.assertEqual(parse_version("3.5.4+47"), (3, 5, 4, 47))

    def test_tolerates_surrounding_whitespace(self):
        self.assertEqual(parse_version("  3.5.4+47 "), (3, 5, 4, 47))

    def test_rejects_a_missing_build_number(self):
        # Flutter derives the Android versionCode from it, so a name-only
        # version builds with a versionCode of 1 and silently stops upgrading.
        with self.assertRaises(VersionError):
            parse_version("3.5.4")

    def test_rejects_a_prerelease_suffix(self):
        # Nothing downstream knows what to do with it: the release workflow
        # cuts the string at the +, and Play has no concept of a prerelease
        # name. Better refused here than shipped under a confusing name.
        with self.assertRaises(VersionError):
            parse_version("3.5.4-beta+47")

    def test_rejects_a_missing_component(self):
        with self.assertRaises(VersionError):
            parse_version("3.5+47")


class VersionFromPubspec(unittest.TestCase):
    def test_finds_the_version_line(self):
        pubspec = "name: uractor\ndescription: an app\nversion: 3.5.4+47\n"
        self.assertEqual(version_from_pubspec(pubspec), "3.5.4+47")

    def test_ignores_a_version_inside_a_dependency(self):
        # Dependencies are indented, the project version is not. Matching the
        # first "version" anywhere would pick up a package constraint.
        pubspec = "dependencies:\n  foo:\n    version: 1.2.3\nversion: 3.5.4+47\n"
        self.assertEqual(version_from_pubspec(pubspec), "3.5.4+47")

    def test_raises_when_there_is_no_version(self):
        with self.assertRaises(VersionError):
            version_from_pubspec("name: uractor\n")


class LevelForSubject(unittest.TestCase):
    def test_feat_needs_a_minor_bump(self):
        self.assertEqual(level_for_subject("feat(playlists): add reordering"), MINOR)

    def test_fix_needs_a_patch_bump(self):
        self.assertEqual(level_for_subject("fix(search): stop losing results"), PATCH)

    def test_chore_needs_nothing(self):
        self.assertEqual(level_for_subject("chore: tidy the tool directory"), NONE)

    def test_a_bang_means_breaking(self):
        self.assertEqual(level_for_subject("feat(auth)!: drop anonymous sign in"), MAJOR)

    def test_a_bang_without_a_scope_still_means_breaking(self):
        self.assertEqual(level_for_subject("refactor!: rename every collection"), MAJOR)

    def test_an_unknown_kind_demands_nothing(self):
        # The convention is enforced by review. Treating a typo as breaking
        # would block a pull request for a reason that has nothing to do with
        # its version.
        self.assertEqual(level_for_subject("wip: something"), NONE)

    def test_a_subject_with_no_kind_demands_nothing(self):
        self.assertEqual(level_for_subject("update stuff"), NONE)


class RequiredLevel(unittest.TestCase):
    def test_takes_the_largest_requirement(self):
        self.assertEqual(
            required_level(
                [
                    "docs: explain the seams",
                    "fix(search): encode the query",
                    "feat(search): rank by relevance",
                ]
            ),
            MINOR,
        )

    def test_a_breaking_change_footer_counts(self):
        # Conventional Commits puts it in the footer, not the subject, so a
        # message whose first line looks harmless can still be breaking.
        message = (
            "refactor(storage): move settings under the user document\n"
            "\n"
            "BREAKING CHANGE: existing installs lose their saved settings.\n"
        )
        self.assertEqual(required_level([message]), MAJOR)

    def test_the_footer_is_only_read_as_a_footer(self):
        # Mentioning the phrase mid-sentence in a body is discussion, not a
        # declaration, and must not silently demand a major release.
        message = (
            "docs: describe the upgrade path\n"
            "\n"
            "Explains what would count as a BREAKING CHANGE: for this project.\n"
        )
        self.assertEqual(required_level([message]), NONE)

    def test_empty_messages_are_ignored(self):
        self.assertEqual(required_level(["", "   ", None]), NONE)

    def test_nothing_required_for_an_empty_list(self):
        self.assertEqual(required_level([]), NONE)


class BumpLevel(unittest.TestCase):
    def test_no_change(self):
        self.assertEqual(bump_level((3, 5, 4, 47), (3, 5, 4, 47)), NONE)

    def test_patch(self):
        self.assertEqual(bump_level((3, 5, 4, 47), (3, 5, 5, 47)), PATCH)

    def test_minor(self):
        self.assertEqual(bump_level((3, 5, 4, 47), (3, 6, 0, 47)), MINOR)

    def test_major(self):
        self.assertEqual(bump_level((3, 5, 4, 47), (4, 0, 0, 47)), MAJOR)

    def test_the_build_number_alone_is_not_a_bump(self):
        # The release workflow rewrites it from Play, so a change to it here
        # says nothing about the release and must not satisfy the check.
        self.assertEqual(bump_level((3, 5, 4, 47), (3, 5, 4, 99)), NONE)

    def test_going_backwards_is_not_a_bump(self):
        self.assertIsNone(bump_level((3, 5, 4, 47), (3, 5, 3, 47)))


class Check(unittest.TestCase):
    def test_a_feature_with_a_minor_bump_passes(self):
        self.assertEqual(check("3.5.4+47", "3.6.0+47", ["feat(x): add a thing"]), [])

    def test_a_feature_without_a_bump_fails(self):
        problems = check("3.5.4+47", "3.5.4+47", ["feat(x): add a thing"])
        self.assertEqual(len(problems), 1)
        self.assertIn("minor", problems[0])

    def test_a_feature_with_only_a_patch_bump_fails(self):
        problems = check("3.5.4+47", "3.5.5+47", ["feat(x): add a thing"])
        self.assertEqual(len(problems), 1)
        self.assertIn("only had a patch bump", problems[0])

    def test_a_larger_bump_than_required_passes(self):
        # Whether something deserves a major release is a judgement call, and
        # the person making it should not be overruled by a script.
        self.assertEqual(check("3.5.4+47", "4.0.0+47", ["fix(x): fix a thing"]), [])

    def test_a_chore_with_no_bump_passes(self):
        self.assertEqual(check("3.5.4+47", "3.5.4+47", ["chore: tidy up"]), [])

    def test_a_chore_may_still_bump(self):
        self.assertEqual(check("3.5.4+47", "3.5.5+47", ["chore: tidy up"]), [])

    def test_a_minor_bump_must_reset_the_patch(self):
        problems = check("3.5.4+47", "3.6.4+47", ["feat(x): add a thing"])
        self.assertEqual(len(problems), 1)
        self.assertIn("3.6.0", problems[0])

    def test_a_major_bump_must_reset_minor_and_patch(self):
        problems = check("3.5.4+47", "4.5.4+47", ["feat(x)!: change a thing"])
        self.assertEqual(len(problems), 1)
        self.assertIn("4.0.0", problems[0])

    def test_going_backwards_fails_on_its_own(self):
        # Reported alone: every other complaint is noise next to a version
        # that cannot be released at all.
        problems = check("3.5.4+47", "3.5.3+47", ["feat(x): add a thing"])
        self.assertEqual(len(problems), 1)
        self.assertIn("backwards", problems[0])

    def test_a_malformed_version_raises(self):
        with self.assertRaises(VersionError):
            check("3.5.4+47", "3.5.5", ["fix(x): fix a thing"])


if __name__ == "__main__":
    unittest.main()
