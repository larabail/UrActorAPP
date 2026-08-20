#!/usr/bin/env python3
"""Summarise an lcov report and optionally enforce a floor.

`flutter test --coverage` writes coverage/lcov.info, which is unreadable on its
own and says nothing in CI unless something parses it. This prints a per-area
breakdown and can fail the build if the tested areas regress.

The floor deliberately applies to selected paths rather than the whole project.
Most of lib/ is widget code with no widget tests, so a project-wide percentage
would be dominated by untested UI and would have to be set so low that it could
never catch a real regression.

Usage:
    python tool/coverage_summary.py
    python tool/coverage_summary.py --min 70 --paths lib/common lib/objects
"""

from __future__ import annotations

import argparse
import collections
import os
import sys

DEFAULT_LCOV = os.path.join("coverage", "lcov.info")

# The layers the test suite actually targets. Widget code is excluded on
# purpose: see the module docstring.
DEFAULT_ENFORCED_PATHS = ["lib/common", "lib/objects"]


def parse_lcov(path):
    """Return {source_file: (lines_hit, lines_found)} from an lcov report."""
    records = {}
    current = None
    hit = found = 0
    with open(path, "r", encoding="utf-8") as handle:
        for raw in handle:
            line = raw.strip()
            if line.startswith("SF:"):
                current = line[3:].replace("\\", "/")
                hit = found = 0
            elif line.startswith("DA:"):
                # DA:<line number>,<execution count>
                _, _, payload = line.partition(":")
                _, _, count = payload.partition(",")
                found += 1
                if int(count) > 0:
                    hit += 1
            elif line == "end_of_record" and current is not None:
                previous_hit, previous_found = records.get(current, (0, 0))
                records[current] = (previous_hit + hit, previous_found + found)
                current = None
    return records


def percentage(hit, found):
    # A file with no executable lines is fully covered by definition; reporting
    # 0% for it would drag the total down for no reason.
    return 100.0 if found == 0 else hit / found * 100.0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lcov", default=DEFAULT_LCOV)
    parser.add_argument(
        "--min",
        type=float,
        default=None,
        help="fail if coverage of the enforced paths falls below this percent",
    )
    parser.add_argument(
        "--paths",
        nargs="*",
        default=DEFAULT_ENFORCED_PATHS,
        help="path prefixes the minimum applies to",
    )
    args = parser.parse_args(argv)

    if not os.path.exists(args.lcov):
        print("No coverage report at %s. Run: flutter test --coverage"
              % args.lcov, file=sys.stderr)
        return 1

    records = parse_lcov(args.lcov)
    if not records:
        print("Coverage report %s contained no records" % args.lcov,
              file=sys.stderr)
        return 1

    by_directory = collections.defaultdict(lambda: [0, 0])
    for source, (hit, found) in records.items():
        directory = os.path.dirname(source) or source
        by_directory[directory][0] += hit
        by_directory[directory][1] += found

    print("%-45s %8s %8s %7s" % ("Directory", "Covered", "Lines", "%"))
    print("-" * 71)
    for directory in sorted(by_directory):
        hit, found = by_directory[directory]
        print("%-45s %8d %8d %6.1f%%"
              % (directory, hit, found, percentage(hit, found)))

    total_hit = sum(hit for hit, _ in records.values())
    total_found = sum(found for _, found in records.values())
    print("-" * 71)
    print("%-45s %8d %8d %6.1f%%"
          % ("TOTAL", total_hit, total_found,
             percentage(total_hit, total_found)))

    enforced_hit = enforced_found = 0
    for source, (hit, found) in records.items():
        if any(source.startswith(prefix) for prefix in args.paths):
            enforced_hit += hit
            enforced_found += found
    enforced = percentage(enforced_hit, enforced_found)
    print("\n%-45s %8d %8d %6.1f%%"
          % ("Enforced (%s)" % ", ".join(args.paths),
             enforced_hit, enforced_found, enforced))

    if args.min is not None and enforced < args.min:
        print("\nCoverage of the enforced paths is %.1f%%, below the required "
              "%.1f%%" % (enforced, args.min), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
