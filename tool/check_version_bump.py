#!/usr/bin/env python3
"""Fail a pull request that ships user-visible change without bumping the version.

Every merge to master builds and uploads to internal testing, so the version in
pubspec.yaml is what a tester sees next to the build they are reporting against.
When it does not move, two different builds carry the same name and a bug report
cannot be tied to a revision.

The version to bump is the NAME, `MAJOR.MINOR.PATCH`, not the `+BUILD` suffix.
The build number belongs to CI: the release workflow builds with a code derived
from Play, because Play rejects a code it has seen before, and commits that code
back to master once the upload succeeds, so anything written here is replaced.
It still has to be present and well formed: Flutter uses it for the Android
versionCode in local builds.

How much to bump is decided by what the change IS, which the repository already
states in the conventional commit kind:

    breaking (`kind!:` or a `BREAKING CHANGE:` footer)  ->  MAJOR
    feat                                                ->  MINOR
    fix, perf                                           ->  PATCH
    docs, ci, test, chore, refactor, build, style       ->  no bump required

Both the pull request title and the individual commits are read, and the largest
requirement of the two wins. The title matters because pull requests are squash
merged, so the title is the only subject that reaches master; the commits matter
because a feature does not stop being a feature when the title undersells it.

One exception, by path rather than by kind: a pull request that changes nothing
outside `web/downloads/` requires no bump at all. That directory is the
downloads site, which is deployed to Firebase Hosting and never packaged into a
build, so no version of the app differs because of it. The commit is still
honestly a `feat` or a `fix` -- it is a public web page -- but making the app
move a minor version for it ships a rename to every internal tester with
nothing in it they can find.

A larger bump than required always passes. Judgement about what deserves MAJOR
belongs to a person, and this refuses to overrule it.
"""

import argparse
import re
import subprocess
import sys

VERSION_LINE = re.compile(r"^version:\s*(\S+)\s*$", re.MULTILINE)

# kind(optional scope) optionally followed by ! for a breaking change.
SUBJECT = re.compile(r"^\s*(?P<kind>[a-z]+)(?:\([^)]*\))?(?P<bang>!)?:", re.IGNORECASE)

NONE, PATCH, MINOR, MAJOR = 0, 1, 2, 3
LEVEL_NAMES = {NONE: "none", PATCH: "patch", MINOR: "minor", MAJOR: "major"}

# Directories whose contents cannot reach a user's app.
#
# `web/downloads/` is the downloads site: three static files deployed to
# Firebase Hosting, which the Flutter build never reads and no release ever
# packages. A change confined to it is user-visible -- it is a public web page
# -- so the commit kind is honestly `feat` or `fix`, and without this the kind
# alone would demand a version the app has no reason to move to. Bumping to
# 3.17.0 to reword a sentence on a web page then ships a build to every
# internal tester under a new name containing no change they can find.
#
# Deliberately narrow. `tool/build_download_manifest.py` is not on this list
# even though it also serves the site, because it writes the manifest the app
# polls, and a mistake in it does reach an install.
APP_IRRELEVANT_PREFIXES = ("web/downloads/",)

KIND_LEVELS = {
    "feat": MINOR,
    "fix": PATCH,
    "perf": PATCH,
    "revert": PATCH,
    "docs": NONE,
    "ci": NONE,
    "test": NONE,
    "chore": NONE,
    "refactor": NONE,
    "build": NONE,
    "style": NONE,
}


class VersionError(ValueError):
    """A version string that is not `MAJOR.MINOR.PATCH+BUILD`."""


def parse_version(raw):
    """The (major, minor, patch, build) in a pubspec version string.

    Rejects anything that is not four integers in the expected shape. A
    pre-release suffix, a missing build number or a stray space are all refused
    rather than guessed at: a version that Flutter reads differently from this
    script is worse than no check.
    """
    match = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)\+(\d+)", raw.strip())
    if not match:
        raise VersionError(
            f"{raw!r} is not MAJOR.MINOR.PATCH+BUILD, for example 3.5.4+47"
        )
    return tuple(int(part) for part in match.groups())


def version_from_pubspec(text):
    """The version string on the `version:` line of a pubspec."""
    match = VERSION_LINE.search(text)
    if not match:
        raise VersionError("pubspec.yaml has no version: line")
    return match.group(1)


def level_for_subject(subject):
    """How much of a bump a single commit subject demands.

    An unrecognised kind counts as no requirement. The convention is enforced by
    review, and guessing MAJOR from a typo would block a pull request for the
    wrong reason.
    """
    match = SUBJECT.match(subject)
    if not match:
        return NONE
    if match.group("bang"):
        return MAJOR
    return KIND_LEVELS.get(match.group("kind").lower(), NONE)


def required_level(messages):
    """The largest bump demanded by any of these commit messages or titles.

    A `BREAKING CHANGE:` footer counts wherever it appears in a message, since
    that is where Conventional Commits puts it, while the kind and the `!`
    marker are only read on the first line.
    """
    level = NONE
    for message in messages:
        if not message or not message.strip():
            continue
        lines = message.strip().splitlines()
        level = max(level, level_for_subject(lines[0]))
        for line in lines[1:]:
            if line.strip().startswith(("BREAKING CHANGE:", "BREAKING-CHANGE:")):
                level = MAJOR
    return level


def bump_level(base, head):
    """Which component actually moved between two parsed versions.

    Returns None when the version went backwards or sideways, which is always
    wrong: builds are only ever added to Play, so a name can only move forward.
    """
    if head[:3] == base[:3]:
        return NONE
    if head[:3] < base[:3]:
        return None
    if head[0] > base[0]:
        return MAJOR
    if head[1] > base[1]:
        return MINOR
    return PATCH


def reaches_the_app(paths):
    """Whether any of [paths] could change what a user's app does.

    True when there is nothing to look at, which is the safe direction: an
    empty list means this could not work out what changed, and exempting a
    pull request on the strength of a question it failed to answer is how an
    unversioned build reaches testers. Blank entries are dropped before that
    decision rather than after, or a list of nothing but whitespace would
    reach the `any()` below, find no path that counts, and read as exempt.
    """
    real = [path for path in paths or [] if path.strip()]
    if not real:
        return True
    return any(not path.startswith(APP_IRRELEVANT_PREFIXES) for path in real)


def check(base_version, head_version, messages, reaches_app=True):
    """The reasons this pull request's version is wrong, or an empty list.

    Collects every problem rather than stopping at the first, so a pull request
    that is wrong in two ways is not fixed twice.

    [reaches_app] is False when nothing outside the exempt paths changed, which
    drops the requirement to none. The rest of the checking still applies: a
    version that moved backwards, or a minor bump that left the patch number
    behind, is wrong whatever the change touched.
    """
    problems = []

    base = parse_version(base_version)
    head = parse_version(head_version)

    needed = required_level(messages) if reaches_app else NONE
    actual = bump_level(base, head)

    if actual is None:
        return [
            f"the version went backwards, from {base_version} to {head_version}. "
            "Play only ever accepts a higher version, so this cannot be released"
        ]

    if actual < needed:
        problems.append(
            f"this pull request needs a {LEVEL_NAMES[needed]} bump but the version "
            f"{'did not change' if actual == NONE else 'only had a ' + LEVEL_NAMES[actual] + ' bump'} "
            f"({base_version} -> {head_version})"
        )

    # A bump that leaves the lower components behind produces a version that
    # sorts oddly and reads as though the older release came later: 3.6.4 after
    # 3.5.4 suggests four patches that never existed.
    if actual == MAJOR and head[1:3] != (0, 0):
        problems.append(
            f"a major bump resets minor and patch to zero, so {head[0]}.0.0 "
            f"rather than {head_version.split('+')[0]}"
        )
    if actual == MINOR and head[2] != 0:
        problems.append(
            f"a minor bump resets patch to zero, so {head[0]}.{head[1]}.0 "
            f"rather than {head_version.split('+')[0]}"
        )

    return problems


def git(*args):
    """Run a git command and return its output, or fail loudly."""
    result = subprocess.run(
        ["git", *args], capture_output=True, text=True, encoding="utf-8"
    )
    if result.returncode != 0:
        raise SystemExit(f"git {' '.join(args)} failed:\n{result.stderr.strip()}")
    return result.stdout


def messages_between(base_sha, head_sha):
    """Every commit message on head that is not already on base.

    Split on a NUL rather than a newline: commit bodies contain blank lines and
    anything else a person types.
    """
    raw = git("log", "--format=%B%x00", f"{base_sha}..{head_sha}")
    return [chunk for chunk in raw.split("\0") if chunk.strip()]


def files_between(base_sha, head_sha):
    """Every path this pull request adds, changes, renames or deletes."""
    raw = git("diff", "--name-only", base_sha, head_sha)
    return [line for line in raw.splitlines() if line.strip()]


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", required=True, help="SHA of the base commit")
    parser.add_argument("--head", required=True, help="SHA of the pull request head")
    parser.add_argument("--title", default="", help="Pull request title")
    args = parser.parse_args(argv)

    base_pubspec = git("show", f"{args.base}:pubspec.yaml")
    head_pubspec = git("show", f"{args.head}:pubspec.yaml")

    base_version = version_from_pubspec(base_pubspec)
    head_version = version_from_pubspec(head_pubspec)

    messages = messages_between(args.base, args.head)
    if args.title:
        messages.append(args.title)

    paths = files_between(args.base, args.head)
    reaches_app = reaches_the_app(paths)

    needed = required_level(messages) if reaches_app else NONE
    print(f"base version:     {base_version}")
    print(f"this version:     {head_version}")
    print(f"required bump:    {LEVEL_NAMES[needed]}")
    if not reaches_app:
        print(
            "\nNothing outside "
            + ", ".join(APP_IRRELEVANT_PREFIXES)
            + " changed, so no bump is required whatever the commit kind says."
            "\nBumping anyway is still fine."
        )

    problems = check(base_version, head_version, messages, reaches_app)
    if not problems:
        print("\nVersion is fine.")
        return 0

    print("\nVersion check failed:", file=sys.stderr)
    for problem in problems:
        print(f"  - {problem}", file=sys.stderr)
    print(
        "\nBump `version:` in pubspec.yaml. Leave the +BUILD suffix alone; the\n"
        "release workflow builds with a code from Play and commits it back.\n"
        "The rules are in AGENTS.md under Versioning.",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
