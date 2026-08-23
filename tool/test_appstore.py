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

import os
import tempfile
import unittest

from appstore import (
    AppStoreError,
    WHATS_NEW_LIMIT,
    check_for_action,
    check_releasable,
    check_submittable,
    editable_version,
    find_version,
    missing_credentials,
    needs_encryption_declaration,
    next_build_number,
    plan_version,
    read_notes,
    select_app_id,
    select_build,
    select_build_id,
    select_version,
    state_of,
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


class StateOf(unittest.TestCase):
    def test_prefers_the_current_vocabulary(self):
        # Apple reports both, and they disagree: a released version is
        # READY_FOR_SALE under the old name and READY_FOR_DISTRIBUTION under
        # the new one.
        version = {"attributes": {
            "appVersionState": "READY_FOR_DISTRIBUTION",
            "appStoreState": "READY_FOR_SALE",
        }}
        self.assertEqual(state_of(version), "READY_FOR_DISTRIBUTION")

    def test_falls_back_to_the_old_vocabulary(self):
        self.assertEqual(
            state_of({"attributes": {"appStoreState": "READY_FOR_SALE"}}),
            "READY_FOR_SALE",
        )

    def test_never_returns_none(self):
        # A state of None would compare unequal to every guarded state and read
        # as "not submittable", which is safe, but "UNKNOWN" says why.
        self.assertEqual(state_of({}), "UNKNOWN")


class CheckSubmittable(unittest.TestCase):
    def test_allows_a_version_being_prepared(self):
        check_submittable("PREPARE_FOR_SUBMISSION", "3.14.2")

    def test_allows_resubmitting_after_a_rejection(self):
        check_submittable("REJECTED", "3.14.2")
        check_submittable("DEVELOPER_REJECTED", "3.14.2")

    def test_refuses_a_version_already_waiting_for_review(self):
        # The case that matters. Editing a version that is with Apple can
        # withdraw it, so a run started against the wrong version number would
        # cancel a submission on its way to approval.
        with self.assertRaises(AppStoreError) as caught:
            check_submittable("WAITING_FOR_REVIEW", "3.14.0")
        self.assertIn("WAITING_FOR_REVIEW", str(caught.exception))
        self.assertIn("3.14.0", str(caught.exception))

    def test_refuses_a_version_in_review(self):
        with self.assertRaises(AppStoreError):
            check_submittable("IN_REVIEW", "3.14.0")

    def test_refuses_a_version_already_live(self):
        with self.assertRaises(AppStoreError):
            check_submittable("READY_FOR_DISTRIBUTION", "3.5.1")

    def test_refuses_an_unknown_state(self):
        # A state this code has never seen is not a licence to write.
        with self.assertRaises(AppStoreError):
            check_submittable("UNKNOWN", "3.14.2")


class CheckReleasable(unittest.TestCase):
    def test_allows_an_approved_version_being_held(self):
        check_releasable("PENDING_DEVELOPER_RELEASE", "3.14.2")

    def test_refuses_a_version_apple_has_not_finished_with(self):
        for state in ("WAITING_FOR_REVIEW", "IN_REVIEW"):
            with self.subTest(state=state):
                with self.assertRaises(AppStoreError):
                    check_releasable(state, "3.14.2")

    def test_refuses_a_version_already_live(self):
        with self.assertRaises(AppStoreError):
            check_releasable("READY_FOR_DISTRIBUTION", "3.5.1")


class CheckForAction(unittest.TestCase):
    """The guard the pre-flight runs before anyone is asked to approve."""

    def test_defers_to_the_submit_guard(self):
        check_for_action("PREPARE_FOR_SUBMISSION", "3.14.2", "submit")
        with self.assertRaises(AppStoreError):
            check_for_action("IN_REVIEW", "3.14.2", "submit")

    def test_defers_to_the_release_guard(self):
        check_for_action("PENDING_DEVELOPER_RELEASE", "3.14.2", "release")
        with self.assertRaises(AppStoreError):
            check_for_action("PREPARE_FOR_SUBMISSION", "3.14.2", "release")

    def test_the_two_actions_disagree_about_the_same_state(self):
        # Not a quirk to work around: a version being prepared is exactly the
        # one to submit and exactly the one that cannot be released. The
        # pre-flight has to ask about the action actually requested, not about
        # whether the version looks generally healthy.
        check_for_action("PREPARE_FOR_SUBMISSION", "3.14.2", "submit")
        with self.assertRaises(AppStoreError):
            check_for_action("PREPARE_FOR_SUBMISSION", "3.14.2", "release")

    def test_refuses_an_action_it_does_not_know(self):
        # `skip` reaching here means the workflow asked about a platform it had
        # been told to leave alone. Answering "fine" would be a lie.
        with self.assertRaises(AppStoreError) as caught:
            check_for_action("PREPARE_FOR_SUBMISSION", "3.14.2", "skip")
        message = str(caught.exception)
        self.assertIn("skip", message)
        self.assertIn("submit", message)
        self.assertIn("release", message)


class FindVersion(unittest.TestCase):
    PAYLOAD = {"data": [
        {"id": "aaa", "attributes": {"versionString": "3.14.0"}},
    ]}

    def test_returns_the_match(self):
        self.assertEqual(find_version(self.PAYLOAD, "3.14.0")["id"], "aaa")

    def test_returns_none_rather_than_raising(self):
        # The difference from select_version, and the reason both exist: a
        # missing version is now something to create, not something to fail on.
        self.assertIsNone(find_version(self.PAYLOAD, "9.9.9"))

    def test_handles_an_empty_payload(self):
        self.assertIsNone(find_version({"data": []}, "3.14.0"))


class EditableVersion(unittest.TestCase):
    def test_finds_the_one_holding_the_slot(self):
        payload = {"data": [
            {"id": "live", "attributes": {
                "versionString": "3.14.0",
                "appVersionState": "READY_FOR_DISTRIBUTION",
            }},
            {"id": "draft", "attributes": {
                "versionString": "3.18.0",
                "appVersionState": "PREPARE_FOR_SUBMISSION",
            }},
        ]}
        self.assertEqual(editable_version(payload)["id"], "draft")

    def test_returns_none_when_everything_is_with_apple(self):
        payload = {"data": [
            {"id": "live", "attributes": {
                "versionString": "3.14.0",
                "appVersionState": "READY_FOR_DISTRIBUTION",
            }},
        ]}
        self.assertIsNone(editable_version(payload))

    def test_counts_a_rejected_version_as_editable(self):
        # A rejected version still holds Apple's one editable slot, so it is
        # just as much in the way as one being prepared.
        payload = {"data": [
            {"id": "bad", "attributes": {
                "versionString": "3.17.0",
                "appVersionState": "DEVELOPER_REJECTED",
            }},
        ]}
        self.assertEqual(editable_version(payload)["id"], "bad")


class PlanVersion(unittest.TestCase):
    """The whole decision behind ensure-version."""

    LIVE = {"id": "live", "attributes": {
        "versionString": "3.14.0",
        "appVersionState": "READY_FOR_DISTRIBUTION",
    }}

    def test_uses_a_version_that_exists_and_is_editable(self):
        # Re-running a release that was interrupted has to be safe, so an
        # existing editable record is adopted rather than duplicated.
        payload = {"data": [self.LIVE, {"id": "draft", "attributes": {
            "versionString": "3.18.0",
            "appVersionState": "PREPARE_FOR_SUBMISSION",
        }}]}
        action, reason = plan_version(payload, "3.18.0")
        self.assertEqual(action, "use")
        self.assertIn("3.18.0", reason)

    def test_creates_when_nothing_holds_the_editable_slot(self):
        action, reason = plan_version({"data": [self.LIVE]}, "3.19.0")
        self.assertEqual(action, "create")

    def test_adopts_when_a_different_version_holds_the_slot(self):
        # Apple permits one editable version at a time. This is the case that
        # produced "You cannot create a new version of the App in the current
        # state", which says nothing about which version is in the way.
        payload = {"data": [self.LIVE, {"id": "draft", "attributes": {
            "versionString": "3.18.0",
            "appVersionState": "PREPARE_FOR_SUBMISSION",
        }}]}
        action, reason = plan_version(payload, "3.19.0")
        self.assertEqual(action, "adopt")
        self.assertIn("3.18.0", reason)
        self.assertIn("3.19.0", reason)

    def test_refuses_a_version_already_in_review(self):
        # The dangerous one. Editing a version with Apple can withdraw it, so
        # this must never come back as "use".
        payload = {"data": [{"id": "x", "attributes": {
            "versionString": "3.18.0",
            "appVersionState": "IN_REVIEW",
        }}]}
        action, reason = plan_version(payload, "3.18.0")
        self.assertEqual(action, "refuse")
        self.assertIn("IN_REVIEW", reason)

    def test_refuses_a_version_already_published(self):
        action, _ = plan_version({"data": [self.LIVE]}, "3.14.0")
        self.assertEqual(action, "refuse")

    def test_creates_for_an_app_apple_holds_nothing_for(self):
        action, _ = plan_version({"data": []}, "1.0.0")
        self.assertEqual(action, "create")

    def test_prefers_the_exact_version_over_the_editable_slot(self):
        # If the requested version IS the editable one, that is a "use" and
        # never an "adopt" — renaming a version to its own name would be a
        # pointless write against a live store.
        payload = {"data": [{"id": "draft", "attributes": {
            "versionString": "3.18.0",
            "appVersionState": "PREPARE_FOR_SUBMISSION",
        }}]}
        action, _ = plan_version(payload, "3.18.0")
        self.assertEqual(action, "use")


class SelectVersion(unittest.TestCase):
    PAYLOAD = {"data": [
        {"id": "aaa", "attributes": {"versionString": "3.14.0"}},
        {"id": "bbb", "attributes": {"versionString": "3.5.1"}},
    ]}

    def test_finds_the_requested_version(self):
        self.assertEqual(select_version(self.PAYLOAD, "3.5.1")["id"], "bbb")

    def test_lists_what_exists_when_the_version_does_not(self):
        # A promotion stopped by a typo should say what Apple actually holds.
        with self.assertRaises(AppStoreError) as caught:
            select_version(self.PAYLOAD, "9.9.9")
        message = str(caught.exception)
        self.assertIn("9.9.9", message)
        self.assertIn("3.14.0", message)

    def test_does_not_match_on_a_prefix(self):
        # "3.14" must not silently promote "3.14.0".
        with self.assertRaises(AppStoreError):
            select_version(self.PAYLOAD, "3.14")

    def test_handles_an_empty_payload(self):
        with self.assertRaises(AppStoreError):
            select_version({"data": []}, "3.14.2")


class SelectBuildId(unittest.TestCase):
    PAYLOAD = {"data": [
        {"id": "b41", "attributes": {"version": "41"}},
        {"id": "b40", "attributes": {"version": "40"}},
    ]}

    def test_finds_the_build(self):
        self.assertEqual(select_build_id(self.PAYLOAD, "41"), "b41")

    def test_accepts_an_integer(self):
        self.assertEqual(select_build_id(self.PAYLOAD, 40), "b40")

    def test_tolerates_whitespace_from_a_dispatch_form(self):
        self.assertEqual(select_build_id(self.PAYLOAD, " 41 "), "b41")

    def test_refuses_a_build_that_is_not_there(self):
        with self.assertRaises(AppStoreError):
            select_build_id(self.PAYLOAD, "99")

    def test_select_build_hands_back_the_whole_record(self):
        # The id alone is not enough to know whether the build can be
        # submitted, which is why the record is what the lookup returns now.
        build = select_build(self.PAYLOAD, "41")
        self.assertEqual(build["id"], "b41")
        self.assertEqual(build["attributes"]["version"], "41")


class NeedsEncryptionDeclaration(unittest.TestCase):
    """The export compliance answer Apple refuses a submission without.

    A build uploaded without `ITSAppUsesNonExemptEncryption` in Info.plist
    arrives with the attribute unset, and the submission fails at the last
    step with a 409 naming the build rather than the version.
    """

    def test_an_unanswered_build_needs_one(self):
        self.assertTrue(
            needs_encryption_declaration({"id": "b1", "attributes": {"version": "67"}})
        )

    def test_an_explicit_null_is_unanswered_too(self):
        self.assertTrue(
            needs_encryption_declaration(
                {"attributes": {"usesNonExemptEncryption": None}}
            )
        )

    def test_a_build_with_no_attributes_at_all_needs_one(self):
        self.assertTrue(needs_encryption_declaration({"id": "b1"}))

    def test_a_null_attributes_key_is_not_a_crash(self):
        self.assertTrue(needs_encryption_declaration({"attributes": None}))

    def test_an_answered_build_is_left_alone(self):
        self.assertFalse(
            needs_encryption_declaration(
                {"attributes": {"usesNonExemptEncryption": False}}
            )
        )

    def test_a_deliberate_yes_is_never_overwritten(self):
        # The expensive direction. Flipping someone's `true` to `false` would
        # be a false legal statement made by a script.
        self.assertFalse(
            needs_encryption_declaration(
                {"attributes": {"usesNonExemptEncryption": True}}
            )
        )


class InfoPlistDeclaresEncryption(unittest.TestCase):
    """The durable half of the fix, checked where it cannot rot unnoticed.

    Declaring it in the plist is what stops a build needing the answer at all:
    Apple reads the key at upload and TestFlight stops asking too. The API
    patch in `submit` only rescues builds uploaded before it was there.
    """

    PLIST = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "ios", "Runner", "Info.plist",
    )

    def test_the_key_is_present_and_false(self):
        with open(self.PLIST, encoding="utf-8") as handle:
            text = handle.read()
        self.assertIn("<key>ITSAppUsesNonExemptEncryption</key>", text)
        after = text.split("<key>ITSAppUsesNonExemptEncryption</key>", 1)[1]
        self.assertTrue(
            after.lstrip().startswith("<false/>"),
            "the key must be followed by <false/>; this app uses only the "
            "system's TLS, which Apple exempts",
        )


class ReadNotes(unittest.TestCase):
    """Release notes on their way to Apple's whatsNew field."""

    class Args:
        def __init__(self, **kwargs):
            self.whats_new = kwargs.get("whats_new", "")
            self.whats_new_file = kwargs.get("whats_new_file")

    def test_takes_a_string(self):
        self.assertEqual(read_notes(self.Args(whats_new="New: a thing")),
                         "New: a thing")

    def test_strips_surrounding_whitespace(self):
        self.assertEqual(read_notes(self.Args(whats_new="\n  hello \n")), "hello")

    def test_reads_a_file_in_preference_to_a_string(self):
        # The workflow passes a file, because release notes are multi-line and
        # shell quoting them is how the newlines get lost.
        with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False,
                                         encoding="utf-8") as handle:
            handle.write("New:\n- from a file\n")
            path = handle.name
        self.addCleanup(os.unlink, path)
        notes = read_notes(self.Args(whats_new="ignored", whats_new_file=path))
        self.assertEqual(notes, "New:\n- from a file")

    def test_keeps_newlines(self):
        self.assertEqual(read_notes(self.Args(whats_new="a\nb")), "a\nb")

    def test_trims_rather_than_refusing_an_over_long_note(self):
        # Failing a release because its changelog was long would be a silly
        # place to stop: the notes describe the release, they are not it.
        notes = read_notes(self.Args(whats_new="x" * (WHATS_NEW_LIMIT + 500)))
        self.assertEqual(len(notes), WHATS_NEW_LIMIT)

    def test_leaves_a_note_at_exactly_the_limit_alone(self):
        notes = read_notes(self.Args(whats_new="x" * WHATS_NEW_LIMIT))
        self.assertEqual(len(notes), WHATS_NEW_LIMIT)

    def test_empty_input_gives_empty_output(self):
        # Which ensure-version reads as "leave whatsNew alone" rather than as
        # "blank the release notes".
        self.assertEqual(read_notes(self.Args()), "")


if __name__ == "__main__":
    unittest.main()
