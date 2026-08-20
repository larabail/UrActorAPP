#!/usr/bin/env python3
"""Write the build number that actually shipped into pubspec.yaml.

The version code is decided by Play at release time, not by the repository:
Play permanently burns a code once it is uploaded, so the workflow asks for the
highest code ever used and adds one. That number only existed inside a workflow
run, which is why the committed `+BUILD` suffix sat at 47 for months while Play
was serving builds in the fifties. Anyone reading the repository, or building a
release locally, saw a number with no relationship to reality.

This is run after a successful upload to put the real number back, so the
suffix becomes a record of the last build that shipped.

Only the `+BUILD` half is touched. The name before the `+` is a human decision
governed by AGENTS.md and enforced on pull requests by check_version_bump.py;
CI overwriting it would take that decision away. Everything else in the file,
including comments, spacing and line endings, is left byte-for-byte alone,
because this runs unattended and the diff it produces has to be trivially
reviewable.

Usage:
    python tool/set_build_number.py 48
    python tool/set_build_number.py 48 --pubspec path/to/pubspec.yaml

Prints what it did and exits 0, whether or not the file needed changing. A
non-zero exit means the file could not be understood and nothing was written.
"""

from __future__ import annotations

import argparse
import re
import sys

# Anchored at column zero, because a project's version is top level while a
# dependency constraint is indented. `[ \t]` rather than `\s`: with MULTILINE,
# `\s` also matches the newline and would happily read the following line as
# the version. `\r` is allowed at the end because MULTILINE's `$` matches
# before the `\n` of a CRLF file, leaving the `\r` on the line.
VERSION_LINE = re.compile(r"^version:[ \t]*(?P<version>\S+)[ \t\r]*$", re.MULTILINE)

VERSION = re.compile(r"(?P<name>\d+\.\d+\.\d+)\+(?P<build>\d+)")

BUILD = re.compile(r"\d+")


class PubspecError(ValueError):
    """A pubspec this script will not edit, or a build number it will not write."""


def parse_build_number(value) -> int:
    """The build number as an integer, or a refusal.

    Digits only. `int()` alone would accept `+48`, `48_0` and a leading minus,
    and a version code that Flutter reads differently from this script is worse
    than no write-back at all.
    """
    text = str(value).strip()
    if not BUILD.fullmatch(text):
        raise PubspecError(f"{value!r} is not a build number, for example 48")
    number = int(text)
    if number < 1:
        raise PubspecError("a build number starts at 1; Play has no code 0")
    return number


def replace_build_number(text: str, build) -> str:
    """`text` with the `+BUILD` suffix replaced, and nothing else changed.

    Splices the new version over the old one rather than rebuilding the line,
    so indentation, a trailing comment or a CRLF ending all survive untouched.
    """
    build = parse_build_number(build)

    matches = list(VERSION_LINE.finditer(text))
    if not matches:
        # Also what a version line carrying a trailing comment lands on. That
        # is deliberate: check_version_bump.py reads the line just as strictly,
        # so a pubspec this cannot parse is one the pull request check cannot
        # parse either, and guessing here would only hide that.
        raise PubspecError(
            "no top-level `version: MAJOR.MINOR.PATCH+BUILD` line to edit"
        )
    if len(matches) > 1:
        # Two top-level version keys is not valid YAML, and picking one of them
        # would be a guess about which one Flutter reads.
        raise PubspecError(
            f"pubspec.yaml has {len(matches)} version: lines; refusing to guess "
            "which one is the project version"
        )

    match = matches[0]
    raw = match.group("version")
    parsed = VERSION.fullmatch(raw)
    if not parsed:
        raise PubspecError(
            f"{raw!r} is not MAJOR.MINOR.PATCH+BUILD, for example 3.5.4+47"
        )

    replacement = f"{parsed.group('name')}+{build}"
    return text[: match.start("version")] + replacement + text[match.end("version") :]


def read(path: str) -> str:
    # newline="" on both halves of the round trip: without it Python rewrites
    # every line ending on the platform's terms, and a whole-file diff would
    # bury the one line that changed.
    with open(path, encoding="utf-8", newline="") as handle:
        return handle.read()


def write(path: str, text: str) -> None:
    with open(path, "w", encoding="utf-8", newline="") as handle:
        handle.write(text)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("build_number", help="the version code that was uploaded")
    parser.add_argument(
        "--pubspec", default="pubspec.yaml", help="pubspec to edit (default: %(default)s)"
    )
    args = parser.parse_args(argv)

    try:
        before = read(args.pubspec)
        after = replace_build_number(before, args.build_number)
    except PubspecError as error:
        print(f"{args.pubspec}: {error}", file=sys.stderr)
        return 1
    except OSError as error:
        print(f"could not read {args.pubspec}: {error}", file=sys.stderr)
        return 1

    old = VERSION_LINE.search(before).group("version")
    new = VERSION_LINE.search(after).group("version")

    if after == before:
        print(f"{args.pubspec} already records {new}; nothing to write")
        return 0

    try:
        write(args.pubspec, after)
    except OSError as error:
        print(f"could not write {args.pubspec}: {error}", file=sys.stderr)
        return 1

    print(f"{args.pubspec}: {old} -> {new}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
