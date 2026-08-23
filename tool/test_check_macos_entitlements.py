#!/usr/bin/env python3
"""Tests for the macOS entitlements check.

Run with: python -m unittest discover -s tool -p "test_*.py"

`SHIPPED_3_18_9` and `PROFILE_3_18_9` are the real thing, read off the published
`UrActor-3.18.9-macos.dmg` with `codesign --display --entitlements` and
`security cms -D`. That release is the reason this check exists: it was signed,
notarised, stapled and accepted by Gatekeeper, and every copy of it refused to
start. Keeping it here as data means the one build known to be broken keeps
testing the checker after the workflow that produced it has been fixed.

`XCODE_3_18_9` is what the same build looks like when Xcode's own entitlements
are used instead of the template -- verified by re-signing the shipped bundle
with them, which produced an app that launches.
"""

import unittest

from check_macos_entitlements import (
    DEBUG_ONLY,
    granted_by,
    is_restricted,
    problems,
    unexpanded,
    values_of,
)

TEAM = "Q8XY8276AC"
BUNDLE_ID = "com.uractor.uractormacos"

# What the released 3.18.9 app was actually signed with. Note the keychain
# group: `codesign` was handed macos/Runner/Release.entitlements and copied the
# build setting through verbatim.
SHIPPED_3_18_9 = {
    "com.apple.security.app-sandbox": True,
    "com.apple.security.files.user-selected.read-only": True,
    "com.apple.security.network.client": True,
    "keychain-access-groups": [f"$(AppIdentifierPrefix){BUNDLE_ID}"],
}

# What "UrActor macOS Developer ID" grants.
PROFILE_3_18_9 = {
    "keychain-access-groups": [f"{TEAM}.*"],
    "com.apple.application-identifier": f"{TEAM}.{BUNDLE_ID}",
    "com.apple.developer.team-identifier": TEAM,
}

# What Xcode expands the same template into, and what the app has to be signed
# with for the kernel to let it start.
XCODE_3_18_9 = {
    "com.apple.security.app-sandbox": True,
    "com.apple.security.files.user-selected.read-only": True,
    "com.apple.security.network.client": True,
    "keychain-access-groups": [f"{TEAM}.{BUNDLE_ID}"],
    "com.apple.application-identifier": f"{TEAM}.{BUNDLE_ID}",
    "com.apple.developer.team-identifier": TEAM,
}

# What `flutter build macos --release` actually leaves in the bundle, read off a
# real build. It is XCODE_3_18_9 plus the debugging entitlement Xcode injects --
# which notarisation refuses, and which the old template-signing bug used to
# throw away by accident.
AS_BUILT_BY_XCODE = dict(XCODE_3_18_9, **{DEBUG_ONLY: True})


class TheDebuggingEntitlement(unittest.TestCase):
    """The trap that fixing the template bug opens up."""

    def test_an_unmodified_xcode_build_is_refused(self):
        # Preserving Xcode's entitlements is the fix for the launch failure,
        # and doing it naively swaps a broken release for a rejected one.
        reported = problems(AS_BUILT_BY_XCODE, PROFILE_3_18_9)
        self.assertEqual(len(reported), 1)
        self.assertIn("get-task-allow", reported[0])
        self.assertIn("Notarisation", reported[0])

    def test_stripping_it_is_enough(self):
        stripped = {k: v for k, v in AS_BUILT_BY_XCODE.items() if k != DEBUG_ONLY}
        self.assertEqual(problems(stripped, PROFILE_3_18_9), [])

    def test_it_is_not_treated_as_profile_granted(self):
        # It lives under `com.apple.security.`, so the profile has no say in
        # it. The complaint has to be that it is present at all, not that the
        # profile fails to grant it.
        self.assertFalse(is_restricted(DEBUG_ONLY))
        reported = problems({DEBUG_ONLY: True}, PROFILE_3_18_9)
        self.assertEqual(len(reported), 1)
        self.assertNotIn("does not grant", reported[0])


class TheIncident(unittest.TestCase):
    """The 3.18.9 release, which is what this file is for."""

    def test_the_shipped_build_is_refused(self):
        # If this ever passes, the check has stopped catching the only failure
        # it was written for.
        self.assertTrue(problems(SHIPPED_3_18_9, PROFILE_3_18_9))

    def test_it_says_the_build_setting_was_never_expanded(self):
        reported = " ".join(problems(SHIPPED_3_18_9, PROFILE_3_18_9))
        self.assertIn("keychain-access-groups", reported)
        self.assertIn("AppIdentifierPrefix", reported)
        self.assertIn("build setting", reported)

    def test_the_fixed_build_is_allowed(self):
        self.assertEqual(problems(XCODE_3_18_9, PROFILE_3_18_9), [])

    def test_the_unexpanded_group_is_reported_once(self):
        # It is both an unexpanded setting and a group the profile does not
        # grant. Saying so twice would push the sentence naming the cause off
        # the end of a workflow log.
        reported = problems(SHIPPED_3_18_9, PROFILE_3_18_9)
        self.assertEqual(len(reported), 1)


class WhatCountsAsRestricted(unittest.TestCase):
    def test_sandbox_entitlements_are_not_profile_granted(self):
        # These are in every sandboxed app and in no profile. Requiring them
        # would fail every build, including correct ones.
        self.assertFalse(is_restricted("com.apple.security.app-sandbox"))
        self.assertFalse(is_restricted("com.apple.security.network.client"))
        self.assertFalse(is_restricted("com.apple.security.cs.allow-jit"))

    def test_keychain_and_developer_entitlements_are(self):
        self.assertTrue(is_restricted("keychain-access-groups"))
        self.assertTrue(is_restricted("com.apple.application-identifier"))
        self.assertTrue(is_restricted("com.apple.developer.team-identifier"))

    def test_a_sandbox_entitlement_absent_from_the_profile_is_fine(self):
        self.assertEqual(
            problems(
                {"com.apple.security.network.client": True},
                {"com.apple.application-identifier": f"{TEAM}.{BUNDLE_ID}"},
            ),
            [],
        )


class Wildcards(unittest.TestCase):
    def test_a_team_wildcard_covers_a_bundle_id(self):
        self.assertTrue(granted_by([f"{TEAM}.*"], f"{TEAM}.{BUNDLE_ID}"))

    def test_a_wildcard_does_not_cover_another_team(self):
        self.assertFalse(granted_by([f"{TEAM}.*"], f"AAAAAAAAAA.{BUNDLE_ID}"))

    def test_an_exact_value_matches(self):
        self.assertTrue(granted_by([f"{TEAM}.{BUNDLE_ID}"], f"{TEAM}.{BUNDLE_ID}"))

    def test_an_exact_value_does_not_match_a_sibling(self):
        self.assertFalse(
            granted_by([f"{TEAM}.{BUNDLE_ID}"], f"{TEAM}.{BUNDLE_ID}.helper")
        )

    def test_a_literal_dollar_group_is_not_covered_by_the_team_wildcard(self):
        # The heart of the incident, stated on its own.
        self.assertFalse(
            granted_by([f"{TEAM}.*"], f"$(AppIdentifierPrefix){BUNDLE_ID}")
        )

    def test_a_non_string_pattern_is_ignored_rather_than_crashing(self):
        self.assertFalse(granted_by([None, 7], f"{TEAM}.{BUNDLE_ID}"))


class SpottingBuildSettings(unittest.TestCase):
    def test_the_parenthesised_form(self):
        self.assertTrue(unexpanded("$(AppIdentifierPrefix)com.example"))

    def test_the_braced_form(self):
        # Not what Xcode's template uses, but accepted by the same expansion
        # and broken in the same way, so it is not worth catching only one.
        self.assertTrue(unexpanded("${AppIdentifierPrefix}com.example"))

    def test_an_expanded_value_is_clean(self):
        self.assertFalse(unexpanded(f"{TEAM}.{BUNDLE_ID}"))

    def test_a_dollar_without_a_bracket_is_not_a_build_setting(self):
        self.assertFalse(unexpanded("price$"))


class ReadingValues(unittest.TestCase):
    def test_a_bare_string_is_one_value(self):
        self.assertEqual(values_of(f"{TEAM}.{BUNDLE_ID}"), [f"{TEAM}.{BUNDLE_ID}"])

    def test_an_array_is_its_strings(self):
        self.assertEqual(values_of(["a", "b"]), ["a", "b"])

    def test_a_boolean_has_no_values(self):
        # A capability entitlement is granted by being in the profile at all,
        # so there is nothing to compare and `problems` checks presence.
        self.assertEqual(values_of(True), [])

    def test_non_strings_inside_an_array_are_dropped(self):
        self.assertEqual(values_of(["a", None, 3]), ["a"])


class MissingGrants(unittest.TestCase):
    def test_a_restricted_entitlement_absent_from_the_profile_is_refused(self):
        reported = problems(
            {"com.apple.developer.aps-environment": "production"},
            PROFILE_3_18_9,
        )
        self.assertEqual(len(reported), 1)
        self.assertIn("aps-environment", reported[0])
        self.assertIn("does not grant it", reported[0])

    def test_a_boolean_capability_in_the_profile_is_allowed(self):
        self.assertEqual(
            problems(
                {"com.apple.developer.associated-domains": True},
                {"com.apple.developer.associated-domains": True},
            ),
            [],
        )


class BadInput(unittest.TestCase):
    def test_a_profile_with_no_entitlements_is_refused_not_ignored(self):
        # `read_profile_entitlements` returns {} for a profile with no
        # Entitlements key. Treating that as "nothing to check" would make the
        # checker pass precisely when it can see least.
        self.assertTrue(problems(SHIPPED_3_18_9, {}))

    def test_entitlements_that_are_not_a_dictionary_are_refused(self):
        self.assertTrue(problems([], PROFILE_3_18_9))
        self.assertTrue(problems(SHIPPED_3_18_9, []))


if __name__ == "__main__":
    unittest.main()
