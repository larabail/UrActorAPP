#!/usr/bin/env python3
"""Report when master has moved without reaching internal testers.

A merge to master that changes anything a build can contain is supposed to build
and ship, and the version policy in AGENTS.md rests on that. There is more than
one way it silently does not, and the failure looks identical from outside every
time: the merge succeeds, no run is ever created -- not queued, not failed, not
cancelled -- nothing goes red, nobody is notified, and the next release quietly
carries two changes under one build.

Two causes are known:

  * A commit message that mentions a skip-ci marker ANYWHERE, including in a
    body explaining what the marker does. This is what actually happened to
    `7347803`, the merge in issue #58: its body contains the sentence saying
    the marker in the subject is a second line of defence, and that sentence
    was itself enough to stop every workflow. AGENTS.md warns about this, in a
    paragraph that same commit added.
  * A push that modifies workflow files made with an integration token, which
    is what issue #58 diagnosed. Whether it applies to an ordinary merge is not
    settled here.

Which is why this deliberately does not care WHY. It checks the symptom -- a
commit on master that should have produced a release and did not -- so it keeps
working when the cause turns out to be something nobody has thought of yet.

The signal is the existence of a `release-internal.yml` run for the commit,
which is the same evidence the bug was diagnosed with -- `total_count=0` for the
merge that vanished against `1` for the merge two minutes before it.

The `+BUILD` suffix in pubspec.yaml is deliberately NOT the signal, even though
it records the last build that reached testers. It only moves when a person
merges the pull request the `record` job opens, and that pull request's checks
do not start on their own (see docs/releases.md), so it routinely sits unmerged
while releases ship perfectly well. A watchdog built on it would cry wolf in the
ordinary case and could not name the commit that failed to ship.

The shape of the answer:

    1. Collect the head SHAs of recent release-internal runs on master.
    2. Walk master back from its tip to the first commit that has one. Those
       are the commits testers have not seen.
    3. A commit in that range is a GAP unless it deliberately asked for no run
       or changed nothing that ships. See `classify` for what "deliberately"
       means, because the difference between a marker in a subject and the same
       marker in a body is the difference between the machinery working as
       designed and the incident this was written for.

Step 2 is why this asks about a range rather than about the tip. A push of
several commits produces one run, at the tip of the push, so the commits under
it never had a run of their own and their absence means nothing.

The ignore patterns are read out of `.github/workflows/release-internal.yml`
rather than copied here, through `tool/release_paths.py`, so the two cannot
drift apart -- and so this and `check_version_bump.py` cannot disagree about
what reaches an app. When they cannot be read this refuses to answer instead of
assuming everything is releasable, because the one thing worse than a silent
hole is an alarm that fires every morning.

Network access lives in the workflow, not here: the run SHAs arrive as a file so
that all of this is testable without touching GitHub.
"""

import argparse
import json
import subprocess
import sys

from release_paths import (
    CannotTell,
    DEFAULT_WORKFLOW,
    load_patterns,
    reaches_the_app,
)

# Re-exported under the name this file has always used for it. "Would a run
# have been created for this commit" and "can this change reach an app" are the
# same question asked from two directions, and answering both with one function
# is what keeps the watchdog honest about the trigger it measures against.
would_release = reaches_the_app

# GitHub honours these anywhere in a commit message, not merely in the subject,
# which is the reason AGENTS.md forbids writing one even while explaining it. A
# commit carrying one produced no run on purpose and is not a gap.
#
# Written as fragments joined at import time so that this file does not contain
# the literal strings. Quoting them in a file is harmless -- only commit
# messages are scanned -- but this file is about them, so it is the one file
# most likely to be pasted into a commit message by accident.
SKIP_MARKERS = tuple(
    f"[{phrase}]"
    for phrase in ("skip " + "ci", "ci " + "skip", "no " + "ci",
                   "skip " + "actions", "actions " + "skip")
)

# How far back to look for a commit that shipped before giving up. The run list
# handed in covers recent history only, so a tip far beyond it means this is
# being asked a question it cannot answer -- a renamed workflow, a force push, a
# repository that sat idle past the API's window. Reporting fifty gaps in that
# case would be confidently wrong; saying so is not.
DEFAULT_MAX_WALK = 50


def carries_skip_marker(text):
    """Whether some commit text tells GitHub not to run anything."""
    lowered = (text or "").lower()
    return any(marker in lowered for marker in SKIP_MARKERS)


def classify(commits, patterns):
    """Each unshipped commit, and whether it is a gap.

    [commits] are dicts of sha, subject, message and paths, newest first.

    The order of the questions is the whole design, and the middle one is here
    because of what replaying the incident actually found:

    1. A marker in the SUBJECT is deliberate. The `record` job puts one there
       every release so that merging its write-back does not ship a second
       build, and that is the machinery working.
    2. A commit that changed nothing outside `paths-ignore` was never going to
       produce a run, marker or not.
    3. A marker that appears ONLY in the body is an accident, and a gap. GitHub
       scans the whole message, so a commit that merely explains the marker
       silently runs nothing -- which is exactly what AGENTS.md warns about and
       exactly what happened to `7347803`. Excusing it because a marker is
       present would make this watchdog blind to the one confirmed instance of
       the failure it was built for.
    """
    classified = []
    for commit in commits:
        subject = commit["subject"]
        if carries_skip_marker(subject):
            gap, reason = False, "asked for no run"
        elif not would_release(commit["paths"], patterns):
            gap, reason = False, "changed nothing that ships"
        elif carries_skip_marker(commit["message"]):
            gap, reason = True, "its body mentions the skip-ci marker"
        else:
            gap, reason = True, "should have shipped"
        classified.append({
            "sha": commit["sha"],
            "subject": subject,
            "gap": gap,
            "reason": reason,
        })
    return classified


def verdict(commits, patterns):
    """The whole answer, as the workflow and a person both need it."""
    unshipped = classify(commits, patterns)
    gaps = [commit for commit in unshipped if commit["gap"]]
    return {
        "verdict": "gap" if gaps else "shipped",
        "unshipped": unshipped,
        "gaps": gaps,
        # The oldest gap: the point where master and the internal track parted
        # company, which is the commit a person wants named.
        "oldest_gap": gaps[-1]["sha"] if gaps else None,
    }


def git(*args):
    """Run a git command and return its output, or fail loudly."""
    result = subprocess.run(
        ["git", *args], capture_output=True, text=True, encoding="utf-8"
    )
    if result.returncode != 0:
        raise SystemExit(f"git {' '.join(args)} failed:\n{result.stderr.strip()}")
    return result.stdout


def paths_in(sha):
    """Every path a commit changed, against its first parent.

    `--first-parent` so that a merge commit reports what it brought to master
    rather than nothing, which is what the default does for merges and would
    make every merge look like an empty commit.
    """
    raw = git(
        "diff-tree", "--no-commit-id", "--name-only", "-r", "-m",
        "--first-parent", sha,
    )
    return [line for line in raw.splitlines() if line.strip()]


def unshipped_commits(tip, shipped, max_walk=DEFAULT_MAX_WALK):
    """The commits from [tip] back to the first one that has a run.

    Walks rather than diffing two points because the newest run is not
    necessarily on the newest commit, and a commit in the middle having shipped
    is what ends the search.
    """
    shipped = {sha.strip().lower() for sha in shipped if sha.strip()}
    if not shipped:
        raise CannotTell(
            "no release runs were found for master, so there is nothing to "
            "measure against"
        )

    walked = git("rev-list", f"--max-count={max_walk + 1}", tip).split()

    commits = []
    for sha in walked:
        if sha.lower() in shipped:
            return commits
        if len(commits) >= max_walk:
            raise CannotTell(
                f"walked back {max_walk} commits from {tip[:7]} without finding "
                "one that has a release run. The run history handed to this "
                "check does not reach far enough to tell what shipped"
            )
        message = git("log", "-1", "--format=%B", sha)
        commits.append({
            "sha": sha,
            "subject": message.strip().splitlines()[0] if message.strip() else "",
            "message": message,
            "paths": paths_in(sha),
        })

    # The whole reachable history is unshipped, which on a repository with
    # releases behind it means the run list is about something else.
    raise CannotTell(
        f"none of the {len(walked)} commits reachable from {tip[:7]} has a "
        "release run"
    )


def as_markdown(answer, tip):
    """The report, for a run summary or the body of the tracking issue."""
    lines = []
    if answer["verdict"] == "gap":
        oldest = answer["gaps"][-1]
        lines += [
            f"`master` is at `{tip[:7]}`, and **{len(answer['gaps'])} commit"
            f"{'' if len(answer['gaps']) == 1 else 's'} that should have shipped "
            "never produced a release run.**",
            "",
            f"The internal track was last built from a commit older than "
            f"`{oldest['sha'][:7]}` — {oldest['subject']}",
            "",
            "| Commit | Subject | Shipped |",
            "| --- | --- | --- |",
        ]
        for item in answer["unshipped"]:
            mark = ":x: no run" if item["gap"] else f":heavy_minus_sign: {item['reason']}"
            subject = item["subject"].replace("|", "\\|")
            lines.append(f"| `{item['sha'][:7]}` | {subject} | {mark} |")

        mentioned = [item for item in answer["gaps"]
                     if item["reason"] == "its body mentions the skip-ci marker"]
        lines += ["", "**Why this probably happened.**"]
        if mentioned:
            lines += [
                "",
                "At least one of these commits mentions a skip-ci marker in its "
                "message body — see "
                + ", ".join(f"`{item['sha'][:7]}`" for item in mentioned)
                + ". GitHub scans the whole message, not just the subject, so a "
                "commit that merely explains the marker suppresses every "
                "workflow. This is the trap AGENTS.md warns about under "
                "\"Things that will waste your time\".",
            ]
        else:
            lines += [
                "",
                "No commit here asked to be skipped, so the trigger itself did "
                "not fire. One known cause is a push that modifies workflow "
                "files made with an integration token, which creates no run at "
                "all.",
            ]
        lines += [
            "",
            "**To fix it:** run **Release to internal testing** from the "
            "Actions tab on `master`. This issue closes itself once a release "
            "has run for the tip of `master`.",
        ]
    else:
        lines += [
            f"`master` is at `{tip[:7]}` and everything on it has either "
            "shipped or was never meant to.",
        ]
        if answer["unshipped"]:
            lines += ["", "| Commit | Subject | Why no run |", "| --- | --- | --- |"]
            for item in answer["unshipped"]:
                subject = item["subject"].replace("|", "\\|")
                lines.append(f"| `{item['sha'][:7]}` | {subject} | {item['reason']} |")
    return "\n".join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tip", default="HEAD",
                        help="the commit master is at (default: HEAD)")
    parser.add_argument("--runs-file", required=True,
                        help="file of release run head SHAs, one per line, "
                             "or - for standard input")
    parser.add_argument("--workflow", default=DEFAULT_WORKFLOW,
                        help="the release workflow to read paths-ignore from")
    parser.add_argument("--format", choices=("json", "markdown"), default="json")
    parser.add_argument("--max-walk", type=int, default=DEFAULT_MAX_WALK,
                        help="how many commits back to look for a shipped one")
    parser.add_argument("--fail-on-gap", action="store_true",
                        help="exit non-zero when master is ahead of testers")
    args = parser.parse_args(argv)

    try:
        patterns = load_patterns(args.workflow)

        if args.runs_file == "-":
            shipped = sys.stdin.read().split()
        else:
            with open(args.runs_file, encoding="utf-8") as handle:
                shipped = handle.read().split()

        tip = git("rev-parse", args.tip).strip()
        answer = verdict(unshipped_commits(tip, shipped, args.max_walk), patterns)
    except CannotTell as problem:
        answer = {"verdict": "unknown", "reason": str(problem),
                  "unshipped": [], "gaps": [], "oldest_gap": None}
        tip = args.tip

    answer["tip"] = tip

    if args.format == "json":
        print(json.dumps(answer, indent=2))
    elif answer["verdict"] == "unknown":
        print(f"This check could not tell whether `master` has shipped: "
              f"{answer['reason']}.")
    else:
        print(as_markdown(answer, tip))

    if args.fail_on_gap and answer["verdict"] != "shipped":
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
