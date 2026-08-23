#!/usr/bin/env python3
"""Tests for how the production release gets its `v<version>` tag.

Run with: python -m unittest discover -s tool -p "test_*.py"

These read `.github/workflows/release-production.yml` itself rather than a
fixture, because the thing being protected is what is committed there.

The rule they encode is GitHub's, and it is not the one the workflow was
originally written against. An Actions token may not create a ref -- tag or
branch, by `git push` or through the API -- at a commit whose
`.github/workflows/` differ from the tip of the default branch, and **a ref
already pointing at that commit does not lift the refusal**. `GITHUB_TOKEN`
cannot hold the `workflows` permission that would, so no `permissions:` block
is a fix.

That bit the 3.19.0 promotion. The run began while the promoted commit's
workflows still matched master; a pull request touching a workflow file merged
six minutes before the desktop stage published; the `v3.19.0` tag the release
step then tried to create was refused with `403 Resource not accessible by
integration`, at a commit two tags already pointed at, and Play had already been
written to.

Two properties keep it from happening again, and each is one of these tests:

  * the tag is staked by `reserve` while the release is being approved, rather
    than by the publish step half an hour later, and every stage that writes to
    a store waits for it; and
  * the publish step does not send `target_commitish`. A release named after a
    tag that already exists creates no ref and is allowed at any commit, but
    supplying `target_commitish` is vetted as though a ref were being created
    and is refused anyway -- so passing it undoes the reservation entirely.

Both failed before the fix and neither shows up in a dry run, which publishes
nothing. Without these tests the next report would be another half-shipped
release.
"""

import re
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
WORKFLOW = REPO / ".github/workflows/release-production.yml"

# Jobs are the two-space keys under `jobs:`; their own keys sit at four.
JOB = re.compile(r"^  (?P<name>[A-Za-z_][\w-]*):\s*(?:#.*)?$")
JOB_IF = re.compile(r"^    if:")
NEEDS = re.compile(r"^    needs:\s*(?P<value>.+?)\s*(?:#.*)?$")

# A `with:` entry, not a mention in a comment.
TARGET_COMMITISH = re.compile(r"^\s*target_commitish:")

# The stages that write to a store or to the outside world. Each must wait for
# the tag to be staked, so that a release which cannot be tagged is stopped
# before anything ships rather than after two platforms have.
WRITING_STAGES = ("android", "ios", "desktop_publish")


def jobs(text):
    """Every job in the workflow, as name -> the lines belonging to it."""
    found, name, body = {}, None, []
    for line in text.splitlines():
        match = JOB.match(line)
        if match:
            if name:
                found[name] = body
            name, body = match.group("name"), []
        elif name:
            body.append(line)
    if name:
        found[name] = body
    return found


def needs(body):
    """The job names a job's `needs:` lists, inline or single."""
    for line in body:
        match = NEEDS.match(line)
        if match:
            value = match.group("value").strip()
            if value.startswith("["):
                value = value.strip("[]")
            return [n.strip().strip("'\"") for n in value.split(",") if n.strip()]
    return []


class TheWorkflow(unittest.TestCase):
    def setUp(self):
        self.text = WORKFLOW.read_text(encoding="utf-8")
        self.jobs = jobs(self.text)

    def test_the_workflow_is_where_it_is_expected(self):
        # Everything below is meaningless if the file moved and the reads
        # silently found nothing.
        self.assertTrue(WORKFLOW.is_file(), f"{WORKFLOW} is missing")
        self.assertIn("desktop_publish", self.jobs)


class ReservingTheTag(TheWorkflow):
    def test_a_job_reserves_the_tag(self):
        self.assertIn(
            "reserve",
            self.jobs,
            "the v<version> tag must be staked by its own job while the release "
            "is approved, not left to the publish step half an hour later",
        )

    def test_it_can_write_to_the_repository(self):
        body = "\n".join(self.jobs["reserve"])
        self.assertRegex(
            body,
            r"permissions:\s*\n\s*contents: write",
            "reserve creates a tag, so it needs contents: write",
        )

    def test_it_creates_the_version_tag_at_the_promoted_commit(self):
        body = "\n".join(self.jobs["reserve"])
        self.assertIn("refs/tags/$TAG", body)
        self.assertIn("needs.resolve.outputs.ref", body)

    def test_it_has_no_job_level_condition(self):
        # A skipped job skips everything that needs it, and all three writing
        # stages need this one. A run that is not publishing desktop must still
        # see `reserve` succeed, so the opting out happens on the step.
        self.assertFalse(
            [line for line in self.jobs["reserve"] if JOB_IF.match(line)],
            "reserve must not carry a job-level `if:`, or skipping it would "
            "silently skip Android, iOS and the desktop release with it",
        )

    def test_every_writing_stage_waits_for_it(self):
        for stage in WRITING_STAGES:
            with self.subTest(stage=stage):
                self.assertIn(
                    "reserve",
                    needs(self.jobs[stage]),
                    f"{stage} writes where users can see it, so it must not "
                    "start until the release is known to be taggable",
                )

    def test_it_runs_after_the_approval_gate(self):
        # It is a write to the repository, so it belongs behind the gate.
        self.assertIn("approve", needs(self.jobs["reserve"]))


class PublishingTheRelease(TheWorkflow):
    def test_the_publish_step_sends_no_target_commitish(self):
        offenders = [
            line for line in self.text.splitlines() if TARGET_COMMITISH.match(line)
        ]
        self.assertEqual(
            offenders,
            [],
            "the release is attached to the tag `reserve` already staked. "
            "Sending target_commitish as well is vetted as though a ref were "
            "being created and is refused with 403 once master's workflows "
            "have moved past the promoted commit",
        )

    def test_it_still_names_the_version_tag(self):
        body = "\n".join(self.jobs["desktop_publish"])
        self.assertIn("softprops/action-gh-release", body)
        self.assertRegex(body, r"tag_name: v\$\{\{ env\.VERSION \}\}")


class CheckingTheCommitIsTaggable(TheWorkflow):
    def test_the_check_compares_the_workflow_files(self):
        body = "\n".join(self.jobs["resolve"])
        self.assertRegex(
            body,
            r"git diff --quiet .* \.github/workflows/",
            "the only thing that decides whether a commit can be tagged is "
            "whether its workflow files match the default branch",
        )

    def test_it_does_not_treat_an_existing_ref_as_enough(self):
        # The exemption this test forbids is the one that let 3.19.0 through:
        # `build-96` and `released-96` both pointed at the promoted commit and
        # the tag was refused all the same.
        body = "\n".join(self.jobs["resolve"])
        self.assertNotRegex(
            body,
            r"ls-remote --heads --tags",
            "a ref already pointing at the commit does not make it taggable, "
            "so the check must not pass on finding one",
        )


if __name__ == "__main__":
    unittest.main()
