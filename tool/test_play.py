#!/usr/bin/env python3
"""Tests for the Google Play release helper.

Only the rollout arithmetic is tested here, and it is the part worth testing:
everything else in `play.py` is a request to a live store, but deciding what
`status` and `userFraction` to send is a rule, and getting it wrong costs a
release. A rejected `tracks.update` abandons the edit, so the run fails having
published nothing — visible, but only after someone has already approved the
production deployment and gone to look at the Play Console.

`play.py` imports google-auth lazily so this file can import it on a bare
Python, which is what the pull request workflow runs.

Run with: python -m unittest discover -s tool -p "test_*.py"
"""

import unittest

from play import PlayError, describe, rollout_plan


class RolloutPlan(unittest.TestCase):
    def test_a_staged_rollout_keeps_its_fraction(self):
        self.assertEqual(rollout_plan("inProgress", 0.2), ("inProgress", 0.2))

    def test_the_smallest_rollout_is_still_staged(self):
        self.assertEqual(rollout_plan("inProgress", 0.05), ("inProgress", 0.05))

    def test_a_full_rollout_becomes_a_completed_release(self):
        # Play rejects userFraction 1.0 outright: the fraction is what a
        # release is held back to, so "everyone" is the absence of one.
        self.assertEqual(rollout_plan("inProgress", 1.0), ("completed", None))

    def test_a_completed_release_never_carries_a_fraction(self):
        self.assertEqual(rollout_plan("completed", 0.2), ("completed", None))

    def test_a_draft_never_carries_a_fraction(self):
        self.assertEqual(rollout_plan("draft", 0.2), ("draft", None))

    def test_a_halted_rollout_keeps_the_fraction_it_reached(self):
        self.assertEqual(rollout_plan("halted", 0.5), ("halted", 0.5))

    def test_a_halted_rollout_cannot_be_at_everyone(self):
        # Halting stops a rollout short. At 100% there is nothing to stop, and
        # silently completing it would resume the release it was meant to end.
        with self.assertRaises(PlayError) as caught:
            rollout_plan("halted", 1.0)
        self.assertIn("halted", str(caught.exception))

    def test_a_percentage_passed_as_a_fraction_is_refused(self):
        # 20 is not 20%, and reading it as "everyone" would ship a release to
        # the whole install base that was meant for a fifth of it.
        with self.assertRaises(PlayError) as caught:
            rollout_plan("inProgress", 20.0)
        self.assertIn("0.2", str(caught.exception))

    def test_a_negative_rollout_is_refused(self):
        with self.assertRaises(PlayError):
            rollout_plan("inProgress", -0.1)

    def test_zero_is_left_alone(self):
        # Play accepts it, and a rollout to nobody is a legitimate way to
        # stage a release that is live but not yet reaching anyone.
        self.assertEqual(rollout_plan("inProgress", 0.0), ("inProgress", 0.0))


class Describe(unittest.TestCase):
    def test_a_staged_rollout_reads_as_a_percentage(self):
        self.assertEqual(describe("inProgress", 0.2), "inProgress at 20%")

    def test_a_release_with_no_fraction_reads_as_its_status(self):
        self.assertEqual(describe("completed", None), "completed")

    def test_a_full_rollout_is_reported_as_what_play_was_told(self):
        # The operator asked for 100% inProgress; the summary has to say
        # `completed`, or the Play Console will disagree with the run that
        # made it.
        self.assertEqual(describe(*rollout_plan("inProgress", 1.0)), "completed")


if __name__ == "__main__":
    unittest.main()
