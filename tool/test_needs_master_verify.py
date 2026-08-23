#!/usr/bin/env python3
"""Tests for the master-side verification decision.

Run with: python -m unittest discover -s tool -p "test_*.py"

The question here is narrow -- "is anything else going to run the tests against
this merge commit" -- but getting it wrong in one direction is silent. A push
wrongly judged to ship is a merge commit nobody analyzed, and nothing reports
that, which is the same shape of hole `check_release_gap.py` exists for. So the
unreadable-filter case is tested as carefully as the ordinary ones.
"""

import io
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

import needs_master_verify
from needs_master_verify import needs_verify
from release_paths import DEFAULT_WORKFLOW, load_patterns

REPO = Path(__file__).resolve().parent.parent
RELEASE_WORKFLOW = REPO / DEFAULT_WORKFLOW


class TheDecision(unittest.TestCase):
    PATTERNS = ["**/*.md", "docs/**", ".github/**", "test/**", "tool/**"]

    def test_a_filtered_push_owes_the_checks(self):
        # Nothing else looks at it, so this is the only run there will be.
        self.assertTrue(needs_verify(["test/media_sort_test.dart"], self.PATTERNS))
        self.assertTrue(needs_verify(["README.md", "tool/play.py"], self.PATTERNS))

    def test_a_shipping_push_does_not(self):
        # release-internal.yml's own verify job is running these already, and
        # paying for the same five minutes twice buys nothing.
        self.assertFalse(needs_verify(["lib/main.dart"], self.PATTERNS))

    def test_one_shipping_file_is_enough_to_stand_down(self):
        # GitHub skips a release only when every path matches, so a push mixing
        # tests and source does build, and its build runs the checks.
        self.assertFalse(
            needs_verify(["test/x_test.dart", "lib/main.dart"], self.PATTERNS)
        )

    def test_nothing_to_look_at_stands_down(self):
        # Mirrors reaches_the_app: an empty list means the diff could not be
        # read, which reads as shipping, and a shipping push is verified by the
        # release. The workflow does not reach here in that case -- it decides
        # on the empty diff itself -- but the library default should not
        # silently invert underneath this.
        self.assertFalse(needs_verify([], self.PATTERNS))


class AgainstTheCommittedFilter(unittest.TestCase):
    """The real block, asked the question this script asks.

    A failure here means the release policy and the verification policy have
    come apart -- read it as that, not as a test needing an update.
    """

    @classmethod
    def setUpClass(cls):
        cls.patterns = load_patterns(RELEASE_WORKFLOW)

    def test_the_flutter_suite_is_verified_here_now(self):
        # The change this script was written for. `test/**` is filtered out of
        # the release, so this job is what keeps a test-only merge checked.
        self.assertTrue(
            needs_verify(["test/pre_commit_hook_test.dart"], self.patterns)
        )

    def test_the_tooling_is_verified_here_too(self):
        self.assertTrue(needs_verify(["tool/check_version_bump.py"], self.patterns))
        self.assertTrue(needs_verify([".github/workflows/pr.yml"], self.patterns))

    def test_source_is_left_to_the_release(self):
        self.assertFalse(needs_verify(["lib/main.dart"], self.patterns))
        self.assertFalse(needs_verify(["pubspec.yaml"], self.patterns))

    def test_the_backend_is_left_to_the_release(self):
        self.assertFalse(needs_verify(["firestore.rules"], self.patterns))
        self.assertFalse(needs_verify(["functions/index.js"], self.patterns))


class TheCommandLine(unittest.TestCase):
    def run_main(self, argv, stdin=None):
        out, err = io.StringIO(), io.StringIO()
        if stdin is not None:
            needs_master_verify.sys.stdin = io.StringIO(stdin)
        with redirect_stdout(out), redirect_stderr(err):
            code = needs_master_verify.main(argv)
        return code, out.getvalue().strip(), err.getvalue()

    def test_prints_a_workflow_ready_boolean(self):
        # The workflow assigns this straight into GITHUB_OUTPUT, so it has to
        # be exactly `true` or `false` with nothing else on stdout.
        code, out, _ = self.run_main(["test/x_test.dart"])
        self.assertEqual((code, out), (0, "true"))

        code, out, _ = self.run_main(["lib/main.dart"])
        self.assertEqual((code, out), (0, "false"))

    def test_reads_paths_from_stdin(self):
        code, out, _ = self.run_main([], stdin="README.md\ndocs/releases.md\n")
        self.assertEqual((code, out), (0, "true"))

    def test_the_reason_goes_to_stderr(self):
        # So a person reading the log learns why, without the caller having to
        # strip it back off stdout.
        _, out, err = self.run_main(["lib/main.dart"])
        self.assertEqual(out, "false")
        self.assertIn("runs analyze and test itself", err)

    def test_an_unreadable_filter_runs_the_checks(self):
        # The inversion that matters, and the reason this script exists rather
        # than a line of shell calling the library directly. `reaches_the_app`
        # answers "ships" when it cannot tell, which here would mean "someone
        # else is checking this" -- and nobody would be.
        code, out, err = self.run_main(
            ["lib/main.dart", "--workflow", str(REPO / "no" / "such.yml")]
        )
        self.assertEqual((code, out), (0, "true"))
        self.assertIn("could not read the release filter", err)

    def test_an_empty_paths_ignore_block_also_runs_the_checks(self):
        import tempfile

        with tempfile.NamedTemporaryFile("w", suffix=".yml", delete=False) as handle:
            handle.write("on:\n  push:\n    branches: [master]\n")
            path = handle.name

        code, out, err = self.run_main(["lib/main.dart", "--workflow", path])
        self.assertEqual((code, out), (0, "true"))
        self.assertIn("could not read the release filter", err)


if __name__ == "__main__":
    unittest.main()
