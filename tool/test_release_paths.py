#!/usr/bin/env python3
"""Tests for the shared reader of the release workflow's path filter.

Run with: python -m unittest discover -s tool -p "test_*.py"

The reader is one file because the answer has to be one answer:
`check_release_gap.py` asks whether a commit should have shipped and
`check_version_bump.py` asks whether a pull request needs a version, and those
are the same question. `TheRealFilter` below is the test that matters most --
it runs the patterns actually committed in the workflow against real paths from
this repository, so a line added to that block is checked here rather than
discovered in a scheduled run at seven in the morning.
"""

import unittest
from pathlib import Path

from release_paths import (
    CannotTell,
    DEFAULT_WORKFLOW,
    is_ignored,
    load_patterns,
    parse_paths_ignore,
    pattern_to_regex,
    reaches_the_app,
)

REPO = Path(__file__).resolve().parent.parent
RELEASE_WORKFLOW = REPO / DEFAULT_WORKFLOW


class ReadingTheFilter(unittest.TestCase):
    def test_reads_the_real_release_workflow(self):
        # The whole design rests on this: the patterns are read from the
        # workflow at run time so nothing can drift apart from it.
        patterns = parse_paths_ignore(RELEASE_WORKFLOW.read_text(encoding="utf-8"))
        self.assertIn("**/*.md", patterns)
        self.assertIn("web/downloads/**", patterns)

    def test_skips_comments_inside_the_block(self):
        patterns = parse_paths_ignore(
            "on:\n"
            "  push:\n"
            "    paths-ignore:\n"
            "      - '**/*.md'\n"
            "      # the downloads site has its own workflow\n"
            "\n"
            "      - 'web/downloads/**'\n"
            "  workflow_dispatch:\n"
        )
        self.assertEqual(patterns, ["**/*.md", "web/downloads/**"])

    def test_stops_at_the_end_of_the_block(self):
        patterns = parse_paths_ignore(
            "    paths-ignore:\n"
            "      - 'docs/**'\n"
            "  workflow_dispatch:\n"
            "    inputs:\n"
            "      - 'not a path'\n"
        )
        self.assertEqual(patterns, ["docs/**"])

    def test_refuses_a_missing_block(self):
        # Not an empty list. An empty list means nothing is ignored, under
        # which every documentation commit reads as a release that failed to
        # happen and the watchdog files an issue every morning until someone
        # switches it off.
        with self.assertRaises(CannotTell):
            parse_paths_ignore("on:\n  push:\n    branches: [master]\n")

    def test_refuses_an_empty_block(self):
        with self.assertRaises(CannotTell):
            parse_paths_ignore("    paths-ignore:\n  workflow_dispatch:\n")

    def test_loads_the_real_workflow_from_disk(self):
        self.assertTrue(load_patterns(RELEASE_WORKFLOW))

    def test_a_missing_file_cannot_tell_rather_than_raising_oserror(self):
        # One exception for a caller to catch and one decision to make about
        # it, whether the file is absent or the block inside it is.
        with self.assertRaises(CannotTell):
            load_patterns(REPO / "no" / "such" / "workflow.yml")


class MatchingPaths(unittest.TestCase):
    PATTERNS = ["**/*.md", "docs/**", ".gitignore", "web/downloads/**"]

    def test_double_star_slash_matches_at_the_root(self):
        # `**/*.md` is meant to cover every Markdown file, and README.md at the
        # repository root is the one that matters most here.
        self.assertTrue(is_ignored("README.md", self.PATTERNS))

    def test_double_star_slash_matches_deeper(self):
        self.assertTrue(is_ignored("docs/releases.md", self.PATTERNS))
        self.assertTrue(is_ignored("android/app/src/notes.md", self.PATTERNS))

    def test_a_trailing_double_star_matches_a_subtree(self):
        self.assertTrue(is_ignored("web/downloads/index.html", self.PATTERNS))
        self.assertTrue(is_ignored("web/downloads/js/app.js", self.PATTERNS))

    def test_an_exact_path_matches_only_itself(self):
        self.assertTrue(is_ignored(".gitignore", self.PATTERNS))
        self.assertFalse(is_ignored("android/.gitignore", self.PATTERNS))

    def test_a_single_star_does_not_cross_a_directory(self):
        self.assertFalse(is_ignored("web/downloads.html", self.PATTERNS))

    def test_a_question_mark_matches_one_character(self):
        self.assertTrue(is_ignored("a.md", ["?.md"]))
        self.assertFalse(is_ignored("ab.md", ["?.md"]))

    def test_source_is_not_ignored(self):
        self.assertFalse(is_ignored("lib/main.dart", self.PATTERNS))

    def test_refuses_a_negation(self):
        # `!pattern` inverts an earlier one. Treating it as a literal would
        # quietly change which commits count, so it is refused instead.
        with self.assertRaises(CannotTell):
            is_ignored("docs/x.md", ["!docs/**"])

    def test_a_pattern_is_anchored_at_both_ends(self):
        regex = pattern_to_regex("docs/**")
        self.assertIsNone(regex.match("mydocs/x.md"))
        self.assertIsNone(regex.match("lib/docs/x.md"))


class TheRealFilter(unittest.TestCase):
    """The committed filter, against paths that actually exist here.

    Every entry in this class is a decision someone made about whether a merge
    puts a build in front of internal testers. Read a failure here as "the
    release policy changed", not as "a test needs updating".
    """

    @classmethod
    def setUpClass(cls):
        cls.patterns = load_patterns(RELEASE_WORKFLOW)

    def assertShips(self, path):
        self.assertTrue(
            reaches_the_app([path], self.patterns),
            f"{path} is filtered out of the release, so a change to it alone "
            "would never reach a tester",
        )

    def assertDoesNotShip(self, path):
        self.assertFalse(
            reaches_the_app([path], self.patterns),
            f"{path} still triggers a release, so changing it alone ships a "
            "build identical to the last one",
        )

    def test_the_app_ships(self):
        for path in ("lib/main.dart", "pubspec.yaml", "pubspec.lock",
                     "assets/logo.png", "analysis_options.yaml", "l10n.yaml",
                     "android/app/build.gradle", "ios/Runner/Info.plist",
                     "macos/Runner/Configs/AppInfo.xcconfig",
                     "windows/runner/main.cpp"):
            with self.subTest(path=path):
                self.assertShips(path)

    def test_the_backend_ships(self):
        # Not because a build differs, but because this workflow is what
        # deploys them. Skipping the run would leave a committed rule or index
        # undeployed and invisible until production broke -- which has
        # happened, and is why the `functions` job exists.
        for path in ("functions/index.js", "firestore.rules",
                     "firestore.indexes.json", "firebase.json"):
            with self.subTest(path=path):
                self.assertShips(path)

    def test_the_flutter_suite_no_longer_ships(self):
        # Reversed deliberately. It was held out of the filter to keep the
        # release's `verify` job running the suite against the merge commit --
        # on the belief that nothing else did. `pr.yml` already did: a bare
        # checkout on a pull_request event resolves to `refs/pull/N/merge`, and
        # that job is a required check. The price of the mistake was build 95,
        # signed and uploaded to every internal tester and then stranded by a
        # tag race, for one Dart test file.
        self.assertDoesNotShip("test/media_sort_test.dart")

    def test_prose_does_not_ship(self):
        for path in ("README.md", "AGENTS.md", "SECURITY.md", "LICENSE",
                     "docs/releases.md", "firestore-tests/README.md"):
            with self.subTest(path=path):
                self.assertDoesNotShip(path)

    def test_repository_and_editor_configuration_does_not_ship(self):
        for path in (".gitignore", ".gitattributes",
                     ".vscode/settings.json", ".githooks/pre-commit"):
            with self.subTest(path=path):
                self.assertDoesNotShip(path)

    def test_ci_does_not_ship(self):
        # The change this file was added for. A workflow decides how a build is
        # made, never what is in one, so a merge that only edits one produces a
        # build byte for byte identical to the last -- under the same version
        # name, because none of these kinds requires a bump.
        for path in (".github/workflows/pr.yml",
                     ".github/workflows/release-internal.yml",
                     ".github/actions/setup-flutter-android/action.yml",
                     ".github/pull_request_template.md"):
            with self.subTest(path=path):
                self.assertDoesNotShip(path)

    def test_tooling_does_not_ship(self):
        for path in ("tool/play.py", "tool/check_version_bump.py",
                     "tool/build_download_manifest.py",
                     "tools/sync-oscars/sync-oscars.js"):
            with self.subTest(path=path):
                self.assertDoesNotShip(path)

    def test_the_rules_suite_does_not_ship_but_the_rules_do(self):
        # The distinction is the point: `firestore.rules` is deployed by this
        # workflow, its tests are deployed by nothing.
        self.assertDoesNotShip("firestore-tests/rules.test.js")
        self.assertShips("firestore.rules")

    def test_the_downloads_site_does_not_ship(self):
        self.assertDoesNotShip("web/downloads/index.html")

    def test_a_lookalike_path_outside_an_ignored_directory_ships(self):
        for path in ("web/downloads.dart", "lib/tool/exporter.dart",
                     "lib/github/client.dart"):
            with self.subTest(path=path):
                self.assertShips(path)


class ReachesTheApp(unittest.TestCase):
    PATTERNS = ["**/*.md", "docs/**", ".github/**", "web/downloads/**"]

    def test_one_file_outside_the_filter_is_enough(self):
        # GitHub skips a run only when EVERY changed path matches, so a
        # documentation commit that also touches source is a release.
        self.assertTrue(
            reaches_the_app(["README.md", "lib/main.dart"], self.PATTERNS)
        )

    def test_everything_inside_the_filter_is_not(self):
        self.assertFalse(
            reaches_the_app(
                ["README.md", "docs/releases.md", ".github/workflows/pr.yml"],
                self.PATTERNS,
            )
        )

    def test_nothing_to_look_at_counts_as_reaching_the_app(self):
        # The loud direction. An empty list means this could not work out what
        # changed, and answering on the strength of a question it failed to
        # answer is how a build silently reaches nobody, or reaches everybody
        # under a name that is already taken.
        self.assertTrue(reaches_the_app([], self.PATTERNS))
        self.assertTrue(reaches_the_app(["   "], self.PATTERNS))
        self.assertTrue(reaches_the_app(None, self.PATTERNS))

    def test_blank_entries_do_not_excuse_a_real_one(self):
        self.assertTrue(reaches_the_app(["", "lib/main.dart"], self.PATTERNS))

    def test_blank_entries_alongside_ignored_ones_stay_exempt(self):
        self.assertFalse(reaches_the_app(["", "README.md"], self.PATTERNS))


if __name__ == "__main__":
    unittest.main()
