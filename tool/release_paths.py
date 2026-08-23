#!/usr/bin/env python3
"""Which paths can reach an installed app, read from the release workflow.

Two checks ask the same question and must not answer it differently:

  * `check_release_gap.py` asks whether a commit on master should have produced
    a release run, so that a merge which quietly shipped nothing gets noticed.
  * `check_version_bump.py` asks whether a pull request needs a version bump. A
    bump exists so a tester can tie a bug report to a revision, so a change that
    never reaches a tester has nothing to name.

The two answers are the same answer. If they ever disagree, one of them is
wrong: either a pull request is made to bump a version for a build nobody will
receive, or a build reaches testers under a name it already used. Both are
quiet failures that nothing else would report.

So the list lives in exactly one place -- the `paths-ignore:` block of
`.github/workflows/release-internal.yml` -- because that block is not a copy of
the rule, it *is* the rule: GitHub reads it to decide whether the release runs
at all. Everything here reads that block rather than restating it.

When the block cannot be read, callers are expected to fail loudly rather than
assume nothing is ignored, or assume everything is. Which direction is loud
depends on the caller, so this raises `CannotTell` and lets them choose.
"""

import re

# The workflow whose `paths-ignore:` block decides what ships. Relative, because
# both callers run from the repository root.
DEFAULT_WORKFLOW = ".github/workflows/release-internal.yml"

# `paths-ignore:` followed by its `- pattern` entries, comments and blank lines
# allowed between them.
PATHS_IGNORE = re.compile(r"^(\s*)paths-ignore:\s*(?:#.*)?$")
LIST_ENTRY = re.compile(r"^\s*-\s*(?P<quote>['\"]?)(?P<pattern>.*?)(?P=quote)\s*(?:#.*)?$")


class CannotTell(Exception):
    """The ignore list could not be established, and will not be guessed at."""


def parse_paths_ignore(text):
    """The `paths-ignore` patterns in a workflow file.

    Deliberately a small reader rather than a YAML parse: PyYAML is not a
    dependency of this repository and adding one to checks that exist to be
    boringly reliable is a poor trade. The block it has to cope with is a flat
    list of quoted strings with comments in it.

    Raises rather than returning an empty list when the block is missing or
    empty. An empty list would mean "nothing is ignored", under which every
    documentation commit looks like a release that failed to happen, and the
    watchdog would open an issue every day until someone turned it off.
    """
    lines = text.splitlines()
    for index, line in enumerate(lines):
        match = PATHS_IGNORE.match(line)
        if not match:
            continue

        indent = len(match.group(1))
        patterns = []
        for following in lines[index + 1:]:
            if not following.strip() or following.lstrip().startswith("#"):
                continue
            # A line no deeper than `paths-ignore:` itself has left the block.
            if len(following) - len(following.lstrip()) <= indent:
                break
            entry = LIST_ENTRY.match(following)
            if not entry:
                break
            pattern = entry.group("pattern").strip()
            if pattern:
                patterns.append(pattern)

        if not patterns:
            raise CannotTell(
                "the paths-ignore block in the release workflow is empty; "
                "refusing to treat every commit as releasable"
            )
        return patterns

    raise CannotTell(
        "no paths-ignore block found in the release workflow. If the filter was "
        "removed on purpose, these checks need updating to match"
    )


def load_patterns(workflow=DEFAULT_WORKFLOW):
    """The ignore patterns of a workflow file on disk.

    A missing or unreadable file raises `CannotTell` rather than an OSError, so
    a caller has one thing to catch and one decision to make about it.
    """
    try:
        with open(workflow, encoding="utf-8") as handle:
            return parse_paths_ignore(handle.read())
    except OSError as problem:
        raise CannotTell(f"could not read {workflow}: {problem}") from problem


def pattern_to_regex(pattern):
    """A GitHub filter pattern as a compiled regular expression.

    Supports the subset the release workflow uses, and refuses the rest. `**`
    crosses directory separators, `*` and `?` do not, and a leading `**/` also
    matches nothing at all so that `**/*.md` covers a Markdown file at the root.

    Negations are refused rather than approximated. A `!pattern` entry inverts
    an earlier one, and quietly treating it as a literal would silently change
    which commits count.
    """
    if pattern.startswith("!"):
        raise CannotTell(
            f"the pattern {pattern!r} is a negation, which this cannot evaluate"
        )

    out = []
    index = 0
    while index < len(pattern):
        char = pattern[index]
        if pattern.startswith("**/", index):
            out.append("(?:.*/)?")
            index += 3
        elif pattern.startswith("**", index):
            out.append(".*")
            index += 2
        elif char == "*":
            out.append("[^/]*")
            index += 1
        elif char == "?":
            out.append("[^/]")
            index += 1
        else:
            out.append(re.escape(char))
            index += 1
    return re.compile("".join(out) + r"\Z")


def is_ignored(path, patterns):
    """Whether one changed path is covered by the ignore list."""
    return any(pattern_to_regex(pattern).match(path) for pattern in patterns)


def reaches_the_app(paths, patterns):
    """Whether a change touching [paths] can alter what an installed app does.

    GitHub skips a release only when EVERY changed path matches the ignore
    list, so a single file outside it is enough. This mirrors that exactly,
    because a check that disagreed with the trigger would be describing a
    pipeline that does not exist.

    True when there is nothing to look at, which is the safe direction for both
    callers: an empty list means this could not work out what changed, and
    answering on the strength of a question it failed to answer is how an
    unversioned build reaches testers, or how one silently reaches nobody.
    Blank entries are dropped before that decision rather than after, or a list
    of nothing but whitespace would reach the `any()` below, find no path that
    counts, and read as exempt.
    """
    real = [path for path in paths or [] if path.strip()]
    if not real:
        return True
    return any(not is_ignored(path, patterns) for path in real)
