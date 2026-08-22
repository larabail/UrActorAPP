#!/usr/bin/env python3
"""Tests for the release gap watchdog.

Run with: python -m unittest discover -s tool -p "test_*.py"

Two of these are fixtures of real states, and they are the point of the file.
`MasterAsItWasWhenThisWasWritten` is a healthy repository that must stay quiet,
and `TheMergeThatShippedNothing` is the incident from issue #58 -- the only
known true positive that exists. Both are recorded as data rather than read
from git or the API, so they keep testing the logic after history moves on.
"""

import unittest
from pathlib import Path

from check_release_gap import (
    CannotTell,
    carries_skip_marker,
    classify,
    is_ignored,
    parse_paths_ignore,
    unshipped_commits,
    verdict,
    would_release,
)

# The release workflow's filter as it stands. Copied here ONLY so the reader can
# be tested against the real file below; the check itself never uses this.
RELEASE_WORKFLOW = (
    Path(__file__).resolve().parent.parent
    / ".github" / "workflows" / "release-internal.yml"
)

IGNORED = ["**/*.md", "docs/**", ".gitignore", "web/downloads/**"]


class ReadingTheFilter(unittest.TestCase):
    def test_reads_the_real_release_workflow(self):
        # The whole design rests on this: the patterns are read from the
        # workflow at run time so the two cannot drift apart. If the block is
        # ever reshaped, this fails here rather than at seven in the morning in
        # a scheduled run nobody is watching.
        patterns = parse_paths_ignore(RELEASE_WORKFLOW.read_text(encoding="utf-8"))
        for expected in IGNORED:
            self.assertIn(expected, patterns)

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


class MatchingPaths(unittest.TestCase):
    def test_double_star_slash_matches_at_the_root(self):
        # `**/*.md` is meant to cover every Markdown file, and README.md at the
        # repository root is the one that matters most here.
        self.assertTrue(is_ignored("README.md", IGNORED))

    def test_double_star_slash_matches_deeper(self):
        self.assertTrue(is_ignored("docs/releases.md", IGNORED))
        self.assertTrue(is_ignored("android/app/src/notes.md", IGNORED))

    def test_a_trailing_double_star_matches_a_subtree(self):
        self.assertTrue(is_ignored("web/downloads/index.html", IGNORED))
        self.assertTrue(is_ignored("web/downloads/js/app.js", IGNORED))

    def test_an_exact_path_matches_only_itself(self):
        self.assertTrue(is_ignored(".gitignore", IGNORED))
        self.assertFalse(is_ignored("android/.gitignore", IGNORED))

    def test_a_single_star_does_not_cross_a_directory(self):
        self.assertFalse(is_ignored("web/downloads.html", IGNORED))

    def test_source_is_not_ignored(self):
        self.assertFalse(is_ignored("lib/main.dart", IGNORED))
        self.assertFalse(is_ignored(".github/workflows/pr.yml", IGNORED))

    def test_refuses_a_negation(self):
        # `!pattern` inverts an earlier one. Treating it as a literal would
        # quietly change which commits count, so it is refused instead.
        with self.assertRaises(CannotTell):
            is_ignored("docs/x.md", ["!docs/**"])


class DecidingWhetherARunWasDue(unittest.TestCase):
    def test_one_file_outside_the_filter_is_enough(self):
        # GitHub skips a run only when EVERY changed path matches, so a
        # documentation commit that also touches a workflow is a release.
        self.assertTrue(would_release(["README.md", ".github/workflows/pr.yml"], IGNORED))

    def test_a_documentation_only_commit_is_not_due_a_run(self):
        self.assertFalse(would_release(["README.md", "docs/releases.md"], IGNORED))

    def test_a_downloads_only_commit_is_not_due_a_run(self):
        self.assertFalse(would_release(["web/downloads/index.html"], IGNORED))

    def test_nothing_to_look_at_counts_as_due(self):
        # The loud direction, matching check_version_bump.py: an empty list
        # means this could not tell what changed, and excusing a commit on the
        # strength of a question it failed to answer is how a build silently
        # reaches nobody.
        self.assertTrue(would_release([], IGNORED))
        self.assertTrue(would_release(["   "], IGNORED))


class RecognisingASuppressedCommit(unittest.TestCase):
    def test_finds_the_marker_the_record_job_writes(self):
        self.assertTrue(
            carries_skip_marker("chore(release): record build 82 as shipped "
                                "[skip " + "ci]")
        )

    def test_finds_the_other_spellings_github_honours(self):
        for marker in ("[ci " + "skip]", "[no " + "ci]",
                       "[skip " + "actions]", "[actions " + "skip]"):
            with self.subTest(marker=marker):
                self.assertTrue(carries_skip_marker(f"chore: something {marker}"))

    def test_an_ordinary_commit_carries_none(self):
        self.assertFalse(carries_skip_marker("feat(search): rank by relevance"))

    def test_a_subject_marker_excuses_a_commit(self):
        commits = [{
            "sha": "aaa",
            "subject": "chore(release): record build 82 as shipped [skip " + "ci]",
            "message": "chore(release): record build 82 as shipped [skip " + "ci]\n",
            "paths": ["pubspec.yaml"],
        }]
        self.assertEqual(verdict(commits, IGNORED)["verdict"], "shipped")

    def test_a_body_marker_does_not(self):
        # GitHub scans the whole message, so this commit ran nothing -- but it
        # never asked to. That is an accident that stopped a release, which is
        # the definition of the gap being looked for.
        commits = [{
            "sha": "aaa",
            "subject": "ci(release): explain the marker",
            "message": "ci(release): explain the marker\n"
                       "\nThe [skip " + "ci] in the subject is a second line of "
                       "defence.\n",
            "paths": [".github/workflows/pr.yml"],
        }]
        answer = verdict(commits, IGNORED)
        self.assertEqual(answer["verdict"], "gap")
        self.assertEqual(answer["gaps"][0]["reason"],
                         "its body mentions the skip-ci marker")

    def test_a_body_marker_on_a_docs_only_commit_is_still_not_a_gap(self):
        # It would not have produced a run either way, so there is nothing to
        # complain about and complaining would be noise.
        commits = [{
            "sha": "aaa",
            "subject": "docs: explain the marker",
            "message": "docs: explain the marker\n\nThe [skip " + "ci] marker.\n",
            "paths": ["AGENTS.md"],
        }]
        self.assertEqual(verdict(commits, IGNORED)["verdict"], "shipped")


class MasterAsItWasWhenThisWasWritten(unittest.TestCase):
    """The healthy state, recorded from master on the day this was added.

    The tip was the write-back the release before it opened, which asks for no
    run and gets none. A watchdog that cannot stay quiet through this is
    useless, because this is what master looks like after most releases.
    """

    TIP = "363ffacc9e500eb523ddbf12666123ce056a30f9"
    NEWEST_RUN = "3031c60cea77b1e04e4fd50a4a1c1f7cf5d0a7b0"

    UNSHIPPED = [{
        "sha": TIP,
        "subject": "chore(release): record build 82 as shipped [skip " + "ci] (#107)",
        "message": "chore(release): record build 82 as shipped [skip " + "ci] (#107)\n"
                   "\nThe version code comes from Play at build time.\n",
        "paths": ["pubspec.yaml"],
    }]

    def test_stays_quiet(self):
        answer = verdict(self.UNSHIPPED, IGNORED)
        self.assertEqual(answer["verdict"], "shipped")
        self.assertEqual(answer["gaps"], [])

    def test_says_why_the_tip_has_no_run(self):
        answer = verdict(self.UNSHIPPED, IGNORED)
        self.assertEqual(answer["unshipped"][0]["reason"], "asked for no run")


class TheMergeThatShippedNothing(unittest.TestCase):
    """The incident from issue #58, recorded as it actually happened.

    `7347803` was merged to master, changed two workflow files among others,
    and produced no run at all -- `GET /actions/runs?head_sha=` returned
    `total_count=0` while the merge two minutes before it returned `1`. It is
    the only confirmed instance of this failure, so it stays here as the proof
    that the check still detects what it was built for.

    The message below is the real one, abridged only in the paragraphs that do
    not matter. The sentence that does matter is kept verbatim: the commit
    explains, in its body, that the marker in a subject is a second line of
    defence -- and that sentence is itself a marker, which is very probably why
    nothing ran. Issue #58 diagnosed an integration token and never looked at
    the message.

    A check that excused this commit because it contains a marker would be
    blind to the only real example of the problem it exists to find, which is
    why `classify` only honours a marker in the subject.
    """

    SHA = "73478034b887a3c4903b3013b6cdd5e34d4265a2"
    SUBJECT = "ci(release): commit the shipped build number back to master"

    UNSHIPPED = [{
        "sha": SHA,
        "subject": SUBJECT,
        "message": SUBJECT + "\n"
                   "\n"
                   "The version code exists only inside the run that asked Play\n"
                   "for it, so the committed +BUILD suffix sat at 47 while Play\n"
                   "was serving codes in the fifties.\n"
                   "\n"
                   "The push uses the built-in GITHUB_TOKEN, and that is\n"
                   "load-bearing rather than incidental. The [skip " + "ci] in the\n"
                   "subject is a second line of defence, not the mechanism, and\n"
                   "the workflow says so where someone would change it.\n",
        "paths": [
            ".github/workflows/pr.yml",
            ".github/workflows/release-internal.yml",
            "AGENTS.md",
            "README.md",
            "docs/releases.md",
            "tool/check_version_bump.py",
            "tool/set_build_number.py",
            "tool/test_set_build_number.py",
        ],
    }]

    def test_reports_a_gap(self):
        answer = verdict(self.UNSHIPPED, IGNORED)
        self.assertEqual(answer["verdict"], "gap")
        self.assertEqual(answer["oldest_gap"], self.SHA)

    def test_names_the_commit_that_never_shipped(self):
        answer = verdict(self.UNSHIPPED, IGNORED)
        self.assertEqual([gap["sha"] for gap in answer["gaps"]], [self.SHA])

    def test_a_marker_in_the_body_does_not_excuse_it(self):
        # The regression this file exists for. The subject carries no marker,
        # so the commit never asked to be skipped; the body mentioning one is
        # an accident, and an accident that stops a release is precisely a gap.
        answer = verdict(self.UNSHIPPED, IGNORED)
        self.assertEqual(answer["gaps"][0]["reason"],
                         "its body mentions the skip-ci marker")

    def test_the_documentation_in_it_does_not_excuse_it_either(self):
        # More than half the paths are Markdown. The workflow and Python
        # changes are what make the run due, and one is enough.
        self.assertTrue(would_release(self.UNSHIPPED[0]["paths"], IGNORED))


class ClassifyingARange(unittest.TestCase):
    def test_reports_the_oldest_gap_not_the_newest(self):
        # Commits arrive newest first, and the commit a person wants named is
        # the point where master and the internal track parted company.
        commits = [
            {"sha": "ccc", "subject": "c", "message": "feat: c", "paths": ["lib/c.dart"]},
            {"sha": "bbb", "subject": "b", "message": "docs: b", "paths": ["README.md"]},
            {"sha": "aaa", "subject": "a", "message": "fix: a", "paths": ["lib/a.dart"]},
        ]
        answer = verdict(commits, IGNORED)
        self.assertEqual(answer["verdict"], "gap")
        self.assertEqual(answer["oldest_gap"], "aaa")
        self.assertEqual(len(answer["gaps"]), 2)

    def test_a_range_of_only_excused_commits_is_not_a_gap(self):
        commits = [
            {"sha": "bbb", "subject": "b", "message": "docs: b", "paths": ["docs/x.md"]},
            {"sha": "aaa", "subject": "chore: a [skip " + "ci]",
             "message": "chore: a [skip " + "ci]", "paths": ["pubspec.yaml"]},
        ]
        self.assertEqual(verdict(commits, IGNORED)["verdict"], "shipped")

    def test_marks_each_commit_with_its_reason(self):
        commits = [
            {"sha": "bbb", "subject": "b", "message": "docs: b", "paths": ["docs/x.md"]},
            {"sha": "aaa", "subject": "a", "message": "fix: a", "paths": ["lib/a.dart"]},
        ]
        reasons = [item["reason"] for item in classify(commits, IGNORED)]
        self.assertEqual(reasons, ["changed nothing that ships", "should have shipped"])


class WalkingBack(unittest.TestCase):
    """The walk stops at the first commit that shipped, or admits defeat."""

    def setUp(self):
        # A fake history, newest first, with the messages and paths each commit
        # would report. Patching the module's `git` keeps this away from a real
        # repository, so the test still means something in a shallow clone.
        import check_release_gap

        self.history = ["fff", "eee", "ddd", "ccc", "bbb", "aaa"]
        self.commits = {sha: ("feat: " + sha, ["lib/" + sha + ".dart"])
                        for sha in self.history}

        def fake_git(*args):
            if args[0] == "rev-list":
                limit = int(args[1].split("=")[1])
                return "\n".join(self.history[:limit])
            if args[0] == "log":
                return self.commits[args[-1]][0]
            if args[0] == "diff-tree":
                return "\n".join(self.commits[args[-1]][1])
            raise AssertionError(f"unexpected git call: {args}")

        self.original = check_release_gap.git
        check_release_gap.git = fake_git
        self.addCleanup(setattr, check_release_gap, "git", self.original)

    def test_stops_at_the_first_shipped_commit(self):
        commits = unshipped_commits("fff", ["ddd"])
        self.assertEqual([commit["sha"] for commit in commits], ["fff", "eee"])

    def test_a_tip_that_shipped_leaves_nothing_unshipped(self):
        self.assertEqual(unshipped_commits("fff", ["fff"]), [])

    def test_matches_a_sha_whatever_its_case(self):
        self.assertEqual(unshipped_commits("fff", ["FFF"]), [])

    def test_refuses_when_the_walk_runs_past_what_was_looked_at(self):
        # The failure the run-query window causes: a quiet period or a page
        # limit means the runs handed in do not reach far enough back, and
        # without this every commit beyond them reads as a fabricated gap on a
        # perfectly healthy repository.
        with self.assertRaises(CannotTell) as caught:
            unshipped_commits("fff", ["zzz"], max_walk=3)
        self.assertIn("does not reach far enough", str(caught.exception))

    def test_refuses_when_there_are_no_runs_at_all(self):
        # An API error, a rate limit or a bad token all arrive looking like an
        # empty list, and none of them is evidence that nothing shipped.
        with self.assertRaises(CannotTell):
            unshipped_commits("fff", [])

    def test_refuses_when_the_whole_history_is_unshipped(self):
        with self.assertRaises(CannotTell):
            unshipped_commits("fff", ["zzz"], max_walk=99)


if __name__ == "__main__":
    unittest.main()
