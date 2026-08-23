#!/usr/bin/env python3
"""Whether a push to master still owes analyze and test.

`release-internal.yml` runs `flutter analyze` and `flutter test` against every
merge commit it builds, and that run is not redundant with the pull request's:
a merge commit is a combination neither branch tested on its own, so it is the
first moment two independently green branches can be shown to disagree.

Filtering a path out of that workflow therefore removes two different things at
once -- the build, which is the point, and the verification, which is
collateral. For most of the filter that costs nothing: no arrangement of
Markdown, workflow YAML or `tool/` scripts can make `flutter test` fail. For
`test/**` it costs exactly the thing worth keeping, which is why `test/**` was
held out of the filter at first and shipped a build to every internal tester
for a change to a Dart test file.

This is the seam that lets both be had. `verify-master.yml` runs the checks for
the pushes the release skips, so the release can skip more of them.

    ships     -> release-internal.yml is running analyze and test; stay out of
                 its way rather than paying for the same five minutes twice
    no build  -> nothing else will look at this merge commit, so run them here

The paths come from the caller, and the filter is read from the release
workflow through `release_paths`, so this cannot disagree with what GitHub
actually skipped.

One deliberate inversion. `release_paths.reaches_the_app` answers "ships" when
it cannot tell, because its other two callers are asking questions where
silence is the dangerous answer -- a build reaching testers unnamed, or one
failing to reach them unnoticed. Here the dangerous answer is the opposite:
"ships" means "somebody else is checking this", and being wrong about that
leaves a merge commit nobody ran the tests against. So anything unreadable
resolves to running them. The cost of being wrong in this direction is five
minutes of a free Linux runner.
"""

import argparse
import sys

from release_paths import CannotTell, DEFAULT_WORKFLOW, load_patterns, reaches_the_app


def needs_verify(paths, patterns):
    """Whether the master-side checks should run for a push touching [paths].

    True when the release workflow will not, which is the case this exists for.
    """
    return not reaches_the_app(paths, patterns)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="*",
                        help="the paths this push changed; omit to read them "
                             "from standard input, one per line")
    parser.add_argument("--workflow", default=DEFAULT_WORKFLOW,
                        help="the release workflow to read paths-ignore from")
    args = parser.parse_args(argv)

    paths = args.paths if args.paths else sys.stdin.read().split()

    try:
        patterns = load_patterns(args.workflow)
        verify = needs_verify(paths, patterns)
        reason = ("the release workflow skips this push, so nothing else runs "
                  "analyze or test against this merge commit"
                  if verify else
                  "the release workflow builds this push and runs analyze and "
                  "test itself")
    except CannotTell as problem:
        # Deliberately the opposite of the library default. See the module
        # docstring: an unreadable filter must not be able to talk this out of
        # running the checks.
        verify, reason = True, (
            f"could not read the release filter ({problem}), so the checks run "
            "rather than trusting a workflow that may not be looking"
        )

    print("true" if verify else "false")
    print(reason, file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
