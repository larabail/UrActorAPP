#!/usr/bin/env python3
"""Refuse a macOS build whose entitlements the provisioning profile will not honour.

This exists because of the 3.18.9 desktop release, which was signed, notarised,
stapled, accepted by Gatekeeper, published, downloaded -- and then could not be
started. Double-clicking it produced "The application "UrActor" can't be
opened." with no reason attached, and `open` from a terminal gave only
`RBSRequestErrorDomain Code=5` with `NSPOSIXErrorDomain Code=163, Launchd job
spawn failed`. Nothing in that names entitlements.

What had happened: the release workflow re-signed the app to add the hardened
runtime and passed `macos/Runner/Release.entitlements` to `codesign`. That file
is an Xcode *template*. It asks for the keychain group as

    $(AppIdentifierPrefix)com.uractor.uractormacos

and `$(AppIdentifierPrefix)` is an Xcode build setting, expanded to the team
prefix while Xcode builds. `codesign` substitutes nothing -- it reads the plist
literally -- so the shipped signature claimed a keychain group whose name began
with a dollar sign and an open bracket. The embedded provisioning profile grants
`Q8XY8276AC.*`. A literal `$(AppIdentifierPrefix)...` is not within that, so AMFI
refused the process at spawn.

The reason it reached users is that nothing upstream looks at this:

  * `codesign --verify --strict` checks the signature is intact and matches the
    sealed resources. The entitlements are part of what is sealed, so a wrong
    one verifies perfectly.
  * Notarisation checks for malware, the hardened runtime and a valid Developer
    ID. It does not check the entitlements against the profile.
  * `spctl -a -t exec` reports "accepted, source=Notarized Developer ID", which
    is the truth and is not the question.

Every signal a release workflow normally trusts was green. The first thing that
disagrees is the kernel, on the user's machine, after the download. So the check
has to be made deliberately, and this is it.

The rule being enforced is the one AMFI applies: an entitlement that is granted
by a provisioning profile must appear in that profile, and the profile's values
may be wildcards. Sandbox and hardened-runtime entitlements -- everything under
`com.apple.security.` -- are not profile-granted and are deliberately ignored;
they are checked by the sandbox at run time, not by AMFI at spawn.

One entitlement under that prefix is checked anyway, and it is here because
fixing the bug above uncovered it. See `DEBUG_ONLY`.

Unexpanded build settings are reported separately from ordinary mismatches even
though the profile would reject them anyway. `$(AppIdentifierPrefix)` left in a
signature is never a policy disagreement to think about, it is always the
template having been handed to `codesign` by mistake, and saying so names the
fix instead of leaving the reader to work back to it.

The parsing and comparison here are pure, so the incident is a fixture in the
tests rather than something that needs a Mac, a certificate and a build to
reproduce. Reading the signature and the profile off a real bundle needs
`codesign` and `security`, and lives in `read_app` at the bottom.
"""

from __future__ import annotations

import argparse
import plistlib
import subprocess
import sys

# Entitlements the provisioning profile has no say in. The sandbox reads these
# itself once the process exists; AMFI does not look for them in a profile, and
# demanding that a profile list `com.apple.security.network.client` would fail
# every correctly signed sandboxed app.
UNRESTRICTED_PREFIX = "com.apple.security."

# Lets a debugger attach to the process. Xcode injects it into the built app --
# it is in `flutter build macos --release` output, signed with Developer ID and
# everything -- and notarisation refuses any submission that asks for it:
#
#     The executable requests the com.apple.security.get-task-allow entitlement.
#
# The old template-signing bug hid this, because signing with
# macos/Runner/Release.entitlements happened to drop it along with everything
# else Xcode had added. Anything that starts preserving Xcode's entitlements --
# which is the fix for that bug -- has to strip this one deliberately, so it is
# checked here rather than left to fail at the notarisation step.
DEBUG_ONLY = "com.apple.security.get-task-allow"


def is_restricted(key: str) -> bool:
    """True when [key] is an entitlement a provisioning profile must grant."""
    return not key.startswith(UNRESTRICTED_PREFIX)


def unexpanded(value: str) -> bool:
    """True when [value] still contains an Xcode build setting.

    Both spellings count. `$(FOO)` is what Xcode's entitlements templates use
    and is therefore what actually goes wrong, but `${FOO}` is accepted by the
    same substitution and would fail in exactly the same way, so it is not
    worth being right about only one of them.
    """
    return "$(" in value or "${" in value


def granted_by(patterns, claimed: str) -> bool:
    """True when a profile offering [patterns] permits [claimed].

    Profile values are wildcards: a team is issued `Q8XY8276AC.*` for keychain
    groups rather than one entry per bundle id. The wildcard is a trailing `*`
    on a prefix, which is the only form Apple issues, so this deliberately does
    not implement glob matching -- a `*` in the middle would be a profile this
    has never seen and guessing at it is worse than saying no.
    """
    for pattern in patterns:
        if not isinstance(pattern, str):
            continue
        if pattern == claimed:
            return True
        if pattern.endswith("*") and claimed.startswith(pattern[:-1]):
            return True
    return False


def values_of(entitlement) -> list[str]:
    """The string values in [entitlement], whether it is one or a list.

    `keychain-access-groups` is an array and `com.apple.application-identifier`
    is a bare string, and both have to be compared against the profile the same
    way. Booleans come back as no values at all: `com.apple.developer.foo=true`
    is a capability that is either in the profile or not, which `problems`
    handles by presence rather than by value.
    """
    if isinstance(entitlement, str):
        return [entitlement]
    if isinstance(entitlement, list):
        return [v for v in entitlement if isinstance(v, str)]
    return []


def problems(signed: dict, profile: dict) -> list[str]:
    """Every reason [signed] will be refused at spawn under [profile].

    Returns the empty list when the app will start. Each entry is a sentence
    naming the entitlement and what is wrong with it, because this is read in a
    workflow log by someone who has just been told a build failed and has no
    other context.
    """
    found: list[str] = []
    if not isinstance(signed, dict):
        return ["The signed entitlements are not a plist dictionary."]
    if not isinstance(profile, dict):
        return ["The provisioning profile carries no entitlements dictionary."]

    for key in sorted(signed):
        claimed = signed[key]

        if key == DEBUG_ONLY and claimed:
            found.append(
                f"{key} is signed into the app. Notarisation refuses this: it "
                "is a debugging entitlement Xcode injects into the build, and "
                "it has to be stripped from the entitlements before the "
                "distribution signature."
            )
            continue

        # Checked ahead of the profile comparison and for every entitlement,
        # restricted or not. A build setting surviving into a signature is a
        # packaging mistake wherever it lands, and naming it as one is more
        # use than reporting that the profile does not grant a group nobody
        # meant to ask for.
        for value in values_of(claimed):
            if unexpanded(value):
                found.append(
                    f"{key} is signed as {value!r}, which still contains an "
                    "Xcode build setting. codesign does not expand these: the "
                    "template in macos/Runner/ was signed with instead of the "
                    "entitlements Xcode produced."
                )

        if not is_restricted(key):
            continue

        if key not in profile:
            found.append(
                f"{key} is signed into the app but the provisioning profile "
                "does not grant it."
            )
            continue

        allowed = values_of(profile[key])
        for value in values_of(claimed):
            if unexpanded(value):
                # Already reported above, and reporting the same value again
                # as an ungranted one would bury the sentence that explains it.
                continue
            if not granted_by(allowed, value):
                found.append(
                    f"{key} claims {value!r}, which the provisioning profile "
                    f"does not grant. It allows {allowed}."
                )
    return found


def read_signed_entitlements(app: str) -> dict:
    """The entitlements actually sealed into [app].

    Read back off the bundle rather than from any file on disk, because the
    file on disk is exactly what cannot be trusted here.
    """
    raw = subprocess.run(
        ["codesign", "--display", "--entitlements", "-", "--xml", app],
        capture_output=True,
        check=True,
    ).stdout
    # Older codesign prefixes the plist with an 8-byte blob header even when
    # asked for the raw form. Seeking to the declaration costs nothing and
    # means this does not depend on which Xcode the runner image has.
    start = raw.find(b"<?xml")
    if start > 0:
        raw = raw[start:]
    return plistlib.loads(raw)


def read_profile_entitlements(app: str) -> dict:
    """The entitlements granted by the profile embedded in [app]."""
    profile = f"{app}/Contents/embedded.provisionprofile"
    # The profile is CMS-signed, so it has to be unwrapped before it is a plist.
    decoded = subprocess.run(
        ["security", "cms", "-D", "-i", profile],
        capture_output=True,
        check=True,
    ).stdout
    return plistlib.loads(decoded).get("Entitlements", {})


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="Check a signed macOS app will be allowed to launch.",
    )
    parser.add_argument("--app", required=True, help="Path to the .app bundle")
    args = parser.parse_args(argv)

    try:
        signed = read_signed_entitlements(args.app)
        profile = read_profile_entitlements(args.app)
    except subprocess.CalledProcessError as error:
        stderr = (error.stderr or b"").decode("utf-8", "replace").strip()
        print(f"Could not read {args.app}: {stderr}", file=sys.stderr)
        return 2
    except (plistlib.InvalidFileException, ValueError) as error:
        print(f"Could not parse the entitlements of {args.app}: {error}",
              file=sys.stderr)
        return 2

    found = problems(signed, profile)
    if not found:
        print(f"{args.app}: entitlements agree with the provisioning profile.")
        return 0

    print(f"{args.app} will not ship:", file=sys.stderr)
    for problem in found:
        print(f"  - {problem}", file=sys.stderr)
    print(
        "\nSign with the entitlements read back off Xcode's build "
        "(codesign --display --entitlements - --xml) with the debugging "
        "entitlement "
        "removed, not with the template in macos/Runner/. See "
        "docs/releases.md.",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
