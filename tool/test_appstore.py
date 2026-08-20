#!/usr/bin/env python3
"""Tests for the App Store Connect helper.

The two functions worth testing are the ones that decide what gets released:
which app the upload is aimed at, and which build number it claims. Both run
unattended against a live store, and both fail in ways that are expensive to
notice later — a duplicate build number is rejected only after the whole
archive has been built and uploaded.

Neither needs the network, which is the point of keeping them separate from the
requests that feed them.

Run with: python -m unittest discover -s tool -p "test_*.py"
"""

import unittest

from appstore import (
    AppStoreError,
    missing_credentials,
    next_build_number,
    select_app_id,
)


class NextBuildNumber(unittest.TestCase):
    def test_starts_at_one_for_an_app_with_no_builds(self):
        # The first release of a new app record: Apple holds nothing yet.
        self.assertEqual(next_build_number([]), 1)

    def test_takes_one_past_the_highest(self):
        self.assertEqual(next_build_number(["1", "2", "3"]), 4)

    def test_does_not_assume_the_input_is_ordered(self):
        # The API returns builds in upload order, which is not build order once
        # anyone has uploaded out of sequence.
        self.assertEqual(next_build_number(["7", "3", "5"]), 8)

    def test_compares_numerically_rather_than_as_text(self):
        # The bug this guards: sorted as strings, "9" beats "10" and the next
        # build number comes back as 10, which Apple has already seen.
        self.assertEqual(next_build_number(["9", "10"]), 11)

    def test_ignores_build_numbers_that_are_not_integers(self):
        # A build uploaded by hand from Xcode can carry a dotted version.
        self.assertEqual(next_build_number(["1", "1.0.2", "4"]), 5)

    def test_ignores_surrounding_whitespace(self):
        self.assertEqual(next_build_number([" 12 "]), 13)

    def test_survives_an_app_whose_builds_are_all_unparseable(self):
        # Refusing here would block a release over the shape of an old build.
        self.assertEqual(next_build_number(["1.0", "beta"]), 1)

    def test_accepts_integers_as_well_as_strings(self):
        self.assertEqual(next_build_number([3, "4"]), 5)


class SelectAppId(unittest.TestCase):
    def test_reads_the_id(self):
        payload = {"data": [{"id": "6444444444", "type": "apps"}]}
        self.assertEqual(select_app_id(payload), "6444444444")

    def test_explains_an_empty_result(self):
        # The likeliest first-run failure: the bundle id builds locally but has
        # no App Store Connect record, so the error has to name the fix rather
        # than raise IndexError from inside a list.
        with self.assertRaises(AppStoreError) as caught:
            select_app_id({"data": []}, bundle_id="com.example.nope")
        self.assertIn("com.example.nope", str(caught.exception))

    def test_treats_a_missing_data_key_as_empty(self):
        # An error body has no `data` at all, and reaching into it would raise
        # something that hides the real response.
        with self.assertRaises(AppStoreError):
            select_app_id({})

    def test_treats_a_null_data_key_as_empty(self):
        with self.assertRaises(AppStoreError):
            select_app_id({"data": None})


class MissingCredentials(unittest.TestCase):
    COMPLETE = {
        "APP_STORE_CONNECT_KEY_ID": "ABC123",
        "APP_STORE_CONNECT_ISSUER_ID": "99999999-1111-2222-3333-444444444444",
        "APP_STORE_CONNECT_PRIVATE_KEY": "-----BEGIN PRIVATE KEY-----\n...",
    }

    def test_says_nothing_when_all_are_set(self):
        self.assertEqual(missing_credentials(self.COMPLETE), [])

    def test_names_an_absent_variable(self):
        env = dict(self.COMPLETE)
        del env["APP_STORE_CONNECT_ISSUER_ID"]
        self.assertEqual(missing_credentials(env), ["APP_STORE_CONNECT_ISSUER_ID"])

    def test_treats_an_empty_value_as_missing(self):
        # An unset GitHub secret interpolates to the empty string rather than
        # being absent, so this is what a misconfigured workflow actually
        # passes, and the reason the check is not a plain `in env`.
        env = dict(self.COMPLETE, APP_STORE_CONNECT_KEY_ID="")
        self.assertEqual(missing_credentials(env), ["APP_STORE_CONNECT_KEY_ID"])

    def test_treats_whitespace_as_missing(self):
        env = dict(self.COMPLETE, APP_STORE_CONNECT_KEY_ID="   \n")
        self.assertEqual(missing_credentials(env), ["APP_STORE_CONNECT_KEY_ID"])

    def test_reports_every_missing_variable_at_once(self):
        # One run should be enough to learn everything that has to be set,
        # rather than fixing them one failed release at a time.
        self.assertEqual(missing_credentials({}), [
            "APP_STORE_CONNECT_KEY_ID",
            "APP_STORE_CONNECT_ISSUER_ID",
            "APP_STORE_CONNECT_PRIVATE_KEY",
        ])


if __name__ == "__main__":
    unittest.main()
