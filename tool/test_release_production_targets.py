#!/usr/bin/env python3
"""Tests for the `targets` input on the production release.

Run with: python -m unittest discover -s tool -p "test_*.py"

`targets` picks which half of a release goes out -- `phone` for Android and
iOS, `computer` for the desktop installers, `both` for a normal release. It
exists because the halves fail and recover on different timescales, and because
the alternative was setting two or three per-stage inputs correctly every time
and being ruined by one of them left at its default.

That last sentence is why these read `.github/workflows/release-production.yml`
itself rather than a fixture. The dangerous mistake is not in the shell -- it is
a stage gate that consults `inputs.desktop` instead of the resolved plan, which
looks correct in review, survives every dry run, and ships a platform the
release manager excluded. Only reading the committed file can catch that.

Two things are checked:

  * the resolution itself, by running the plan step's script under bash exactly
    as committed, for every combination that matters; and
  * that no gate anywhere reads the raw form. `targets` only ever subtracts, so
    a gate reading `inputs.*` is not a stricter check that happens to be
    redundant -- it is precisely the one that lets the excluded platform ship.

Like `test_release_production_tagging.py` next door, the file is read with
small regexes rather than parsed. PyYAML is not a dependency of this repository
-- `tool/release_paths.py` explains why -- and a test that exists to be
boringly reliable is the wrong place to make it one.
"""

import re
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
WORKFLOW = REPO / ".github/workflows/release-production.yml"

# The per-stage inputs `targets` narrows. Reading one of these outside the
# single step that resolves them is the bug these tests exist for.
STAGE_INPUTS = ("android", "ios_action", "desktop")

# Jobs are the two-space keys under `jobs:`; a step is a `- ` at any depth.
JOB = re.compile(r"^  (?P<name>[A-Za-z_][\w-]*):\s*(?:#.*)?$")
STEP = re.compile(r"^(?P<indent> +)- ")
JOB_IF = re.compile(r"^    if:\s*(?P<value>.+?)\s*$")
ANY_IF = re.compile(r"^\s*if:\s*(?P<value>.+?)\s*$")

# `workflow_dispatch` inputs are the six-space keys under `inputs:`.
DISPATCH_INPUT = re.compile(r"^      (?P<name>[a-z_]+):\s*$")


def lines():
    return WORKFLOW.read_text(encoding="utf-8").splitlines()


def job_body(name):
    """The lines belonging to one job, excluding its own key line."""
    text = lines()
    start = next(
        i
        for i, line in enumerate(text)
        if JOB.match(line) and JOB.match(line).group("name") == name
    )
    end = next((i for i in range(start + 1, len(text)) if JOB.match(text[i])), len(text))
    return text[start + 1 : end]


def job_condition(name):
    """The job-level `if:` of one job, or None when it has none."""
    for line in job_body(name):
        match = JOB_IF.match(line)
        if match:
            return match.group("value")
    return None


def step_span(marker):
    """The line indices of the step containing a given stripped line."""
    text = lines()
    at = next(i for i, line in enumerate(text) if line.strip() == marker)
    start = next(i for i in range(at, -1, -1) if STEP.match(text[i]))
    indent = STEP.match(text[start]).group("indent")
    end = next(
        (
            i
            for i in range(start + 1, len(text))
            if text[i].startswith(indent + "- ") or JOB.match(text[i])
        ),
        len(text),
    )
    return range(start, end)


def plan_script():
    """The `run:` body of the step in `resolve` that applies `targets`."""
    return step_script("id: plan")


def step_script(marker):
    """The `run:` body of the step containing a given stripped line."""
    text = lines()
    span = step_span(marker)
    at = next(i for i in span if text[i].strip().rstrip("-") == "run: |")
    indent = len(text[at]) - len(text[at].lstrip()) + 2
    body = []
    for i in range(at + 1, span.stop):
        line = text[i]
        if line.strip() and len(line) - len(line.lstrip()) < indent:
            break
        body.append(line[indent:])
    return "\n".join(body) + "\n"


def dispatch_input(name):
    """One `workflow_dispatch` input, as the raw text of its own keys."""
    text = lines()
    start = next(
        i
        for i, line in enumerate(text)
        if DISPATCH_INPUT.match(line)
        and DISPATCH_INPUT.match(line).group("name") == name
    )
    end = next(
        (i for i in range(start + 1, len(text)) if DISPATCH_INPUT.match(text[i])),
        len(text),
    )
    return "\n".join(text[start + 1 : end])


def resolve(targets, android="promote", ios_action="submit", desktop="publish"):
    """Run the committed plan step and return what the gates below would see.

    Raises `subprocess.CalledProcessError` when the step refuses the release.
    """
    with tempfile.NamedTemporaryFile("w+", suffix=".env") as output:
        subprocess.run(
            ["bash", "-c", plan_script()],
            env={
                "TARGETS": targets,
                "ANDROID": android,
                "IOS_ACTION": ios_action,
                "DESKTOP": desktop,
                "GITHUB_OUTPUT": output.name,
            },
            check=True,
            capture_output=True,
            text=True,
        )
        output.seek(0)
        written = dict(
            line.split("=", 1) for line in output.read().splitlines() if "=" in line
        )
    return {key: value for key, value in written.items() if key in STAGE_INPUTS}


class TheInput(unittest.TestCase):
    def setUp(self):
        self.block = dispatch_input("targets")

    def test_it_offers_the_three_choices(self):
        self.assertIn("type: choice", self.block)
        self.assertIn("options: ['both', 'phone', 'computer']", self.block)

    def test_it_defaults_to_releasing_everything(self):
        # A release manager who ignores the field entirely must get the release
        # they got before it existed.
        self.assertIn("default: 'both'", self.block)

    def test_the_per_stage_inputs_are_still_there(self):
        # `targets` narrows them rather than replacing them: an App Store
        # release still needs `ios_action` to say submit or release.
        for name in STAGE_INPUTS:
            with self.subTest(input=name):
                self.assertIn("description:", dispatch_input(name))


class ResolvingTheTargets(unittest.TestCase):
    def test_both_leaves_every_stage_as_asked(self):
        self.assertEqual(
            resolve("both"),
            {"android": "promote", "ios_action": "submit", "desktop": "publish"},
        )

    def test_phone_drops_desktop_and_keeps_the_stores(self):
        self.assertEqual(
            resolve("phone"),
            {"android": "promote", "ios_action": "submit", "desktop": "skip"},
        )

    def test_computer_drops_both_stores(self):
        self.assertEqual(
            resolve("computer"),
            {"android": "skip", "ios_action": "skip", "desktop": "publish"},
        )

    def test_it_only_ever_subtracts(self):
        # `targets: phone` must not resurrect a stage the release manager
        # turned off by hand, or the two inputs argue and the winner depends on
        # which was read last.
        self.assertEqual(
            resolve("phone", android="skip"),
            {"android": "skip", "ios_action": "submit", "desktop": "skip"},
        )
        # In the other direction it does overrule, which is the point of one
        # choice that cannot half-apply.
        self.assertEqual(
            resolve("computer", android="promote", ios_action="release"),
            {"android": "skip", "ios_action": "skip", "desktop": "publish"},
        )

    def test_the_second_run_of_an_app_store_release_needs_one_input(self):
        # The run that releases what Apple approved, days after submitting it.
        # Getting this wrong promotes whatever landed on master in the
        # meantime, which is the case `targets` was added for.
        self.assertEqual(
            resolve("phone", android="skip", ios_action="release"),
            {"android": "skip", "ios_action": "release", "desktop": "skip"},
        )

    def test_a_release_that_would_ship_nothing_is_refused(self):
        # In `resolve`, so it is refused before the approval gate rather than
        # after someone has approved a run with nothing in it.
        with self.assertRaises(subprocess.CalledProcessError) as refused:
            resolve("computer", desktop="skip")
        self.assertIn("would ship nothing", refused.exception.stdout)

    def test_an_unknown_target_is_refused(self):
        # The choice list makes this unreachable from the form, but a
        # workflow_dispatch through the API can send anything, and quietly
        # treating it as `both` would release platforms nobody asked for.
        with self.assertRaises(subprocess.CalledProcessError) as refused:
            resolve("mobile")
        self.assertIn("is not one of", refused.exception.stdout)


class EveryGateReadsTheResolvedPlan(unittest.TestCase):
    def test_the_stage_jobs_gate_on_the_plan(self):
        expected = {
            "android": "needs.resolve.outputs.android == 'promote'",
            "ios": "needs.resolve.outputs.ios_action != 'skip'",
            "desktop_macos": "needs.resolve.outputs.desktop == 'publish'",
            "desktop_windows": "needs.resolve.outputs.desktop == 'publish'",
            "desktop_publish": "needs.resolve.outputs.desktop == 'publish'",
        }
        for job, condition in expected.items():
            with self.subTest(job=job):
                self.assertEqual(job_condition(job), condition)

    def test_the_reserved_tag_follows_the_plan_too(self):
        # The `v<version>` tag is staked only for a desktop release. Left
        # reading `inputs.desktop`, a phone-only run would stake a tag for
        # installers it is never going to publish.
        text = lines()
        body = "\n".join(text[i] for i in step_span("- name: Stake the tag at the promoted commit"))
        self.assertIn("needs.resolve.outputs.desktop == 'publish'", body)

    def test_the_preflight_asks_apple_only_when_ios_is_in_the_release(self):
        # `preflight` has no job-level `if` by design -- see
        # test_release_production_tagging.py for why -- so each step opts out,
        # and each of those has to consult the plan rather than the form.
        conditions = [
            ANY_IF.match(line).group("value")
            for line in job_body("preflight")
            if ANY_IF.match(line)
        ]
        self.assertTrue(conditions, "preflight has no step conditions at all")
        for condition in conditions:
            with self.subTest(condition=condition):
                self.assertIn("needs.resolve.outputs.ios_action", condition)

    def test_nothing_outside_the_plan_step_reads_the_raw_inputs(self):
        # The test that matters. Everything above states the rule for the gates
        # that exist today; this one holds for gates nobody has written yet,
        # which is where the mistake will actually get made.
        reference = re.compile(r"inputs\.(?:%s)\b" % "|".join(STAGE_INPUTS))
        allowed = step_span("id: plan")
        offenders = [
            (number, line.strip())
            for number, line in enumerate(lines())
            if reference.search(line)
            and not line.lstrip().startswith("#")
            and number not in allowed
        ]
        self.assertEqual(
            offenders,
            [],
            "these read the dispatch form directly, so `targets` cannot narrow "
            "them and the platform it excluded ships anyway. Read "
            "needs.resolve.outputs.* instead",
        )


class TaggingOnlyWhenAnyRefIsCreated(unittest.TestCase):
    """`resolve` refuses a commit whose workflows have drifted from master.

    Only two stages create a ref -- Android's `released-<code>` and the
    `v<version>` the desktop release hangs off -- so an iOS-only run has
    nothing to tag. That run is the second half of an App Store release, days
    after the first, by which time master has usually moved; failing it for a
    tag it was never going to create would strand a version Apple has already
    approved, and it is the one run that cannot simply be started again.

    The check is driven by real commands, so rather than reproduce them these
    put a `git` on PATH that always fails. Reaching it at all is then a
    failure, and not reaching it is the guard working.
    """

    def setUp(self):
        self.stubs = tempfile.TemporaryDirectory()
        self.addCleanup(self.stubs.cleanup)
        stub = Path(self.stubs.name) / "git"
        stub.write_text("#!/bin/sh\necho 'stub git refused' >&2\nexit 1\n")
        stub.chmod(0o755)

    def check(self, android, desktop):
        return subprocess.run(
            ["bash", "-c", step_script("- name: Check the promoted commit can be tagged")],
            env={
                "ANDROID": android,
                "DESKTOP": desktop,
                "REF": "0" * 40,
                "VERSION": "3.14.2",
                "DEFAULT_BRANCH": "master",
                "PATH": f"{self.stubs.name}:/usr/bin:/bin",
            },
            capture_output=True,
            text=True,
        )

    def test_a_phone_only_release_without_android_checks_nothing(self):
        done = self.check(android="skip", desktop="skip")
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertIn("creates no tag", done.stdout)

    def test_a_promotion_still_gets_checked(self):
        # The guard must not become a way to skip the check that exists
        # because a half-shipped release already happened once.
        for android, desktop in (("promote", "skip"), ("skip", "publish")):
            with self.subTest(android=android, desktop=desktop):
                done = self.check(android=android, desktop=desktop)
                self.assertNotEqual(
                    done.returncode, 0, "the check did not run: " + done.stdout
                )
                self.assertIn("stub git refused", done.stderr)


if __name__ == "__main__":
    unittest.main()
