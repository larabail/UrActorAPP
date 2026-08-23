#!/usr/bin/env python3
"""Fail a pull request whose commits would put forbidden content on master.

Pull requests here are squash merged, and the repository is configured with
`squash_merge_commit_message: COMMIT_MESSAGES`. That setting is what makes this
check necessary: the messages of the commits on a branch are copied verbatim
into the single commit that lands on master, so anything written on a branch is
written on master. A branch is not a scratch space whose wording stops
mattering once it is merged.

Three things must not make that trip.

**A commit author that is not the pull request's own.** GitHub composes a squash
commit from one author plus a `Co-authored-by:` trailer for every other distinct
commit author it finds, and AGENTS.md forbids those trailers outright. The way
this happens by accident is an unconfigured git identity: with `user.name` and
`user.email` unset git invents an author from the account record and the
hostname, commits under it without complaint, and GitHub -- which has never
heard of that address -- treats the real account as the author and the invention
as a collaborator. `.githooks/pre-commit` refuses to create such a commit, but a
hook only runs where somebody ran `git config core.hooksPath .githooks`, so this
is the half that cannot be opted out of.

It is worth knowing what the alternative costs. One of these reached master as
`0ff0cb44`, still the merge commit GitHub reports for `#147`, and the only
remedy available by then was rewriting a branch configured to refuse force
pushes: `3a39c88` is what master holds now, same tree and parent, trailer gone,
while the API still answers with the superseded commit. Nothing about that is
repeatable, which is the argument for failing the pull request instead.

**A `Co-authored-by:` trailer written by hand.** Same rule, arriving directly
rather than through GitHub's composition.

**A `[bl-xxxx]` tag.** `bl close` appends one to its delivery commit and reads
it back to recognise a delivery it has already made, so on the work branch it is
load bearing and stripping it breaks the tracker's retry. It is only wrong once
it reaches master, where it names a task nothing on master can resolve. The
error says so, because the obvious "fix" -- teaching bl not to write it -- would
trade a cosmetic problem for a real one.

Deciding which author a commit ought to have is the only interesting part, and
this deliberately does not ask GitHub. The pull request author is available to
the workflow as a login, but a login is not a git identity: mapping one to the
other needs an API call, the answer depends on which addresses the account has
verified, and a contributor who has not turned on the noreply address has an
email containing no login at all. A check that has to guess there would either
refuse honest commits or excuse the dishonest ones.

The committer is used instead, because it is already in the data and needs
nothing. It is the identity that actually created the commit object -- the
person at the keyboard, or the tool acting for them -- so a commit whose author
and committer disagree is one that was written by one identity and recorded by
another. That is precisely the shape GitHub turns into a trailer, and it is what
the failing deliveries looked like: `bl close` re-committed with the real
configured identity while preserving the stale invented author.

The exception is GitHub itself. A commit whose committer is `noreply@github.com`
was created by GitHub on an account's behalf -- the web editor, the "Update
branch" button, a suggestion applied from a review -- and its author is by
definition an account GitHub recognises, so no trailer follows. Those are
skipped; everything else with a split identity is reported.

What is deliberately NOT checked is whether the commits agree with each other.
"Two different author addresses on one branch" reads like the same defect and is
not, because a person may have several addresses verified on one account and
GitHub resolves all of them to that account before it decides who to credit. The
branch behind `#116` proves it: `ffda6e7` and `7328215` are authored as
`larabailen.lb@gmail.com` while the merge commit between them is authored as
`85242173+larabail@users.noreply.github.com`, two addresses by the count made
here and one person by GitHub's, and the commit it squashed to -- `31e8ca8` --
carries no trailer at all. Refusing that shape would have blocked a correct pull
request over a distinction only the API can draw, which is a worse failure than
the one being prevented.

That choice also keeps the release write-back mergeable, and it is worth saying
why no explicit exemption for bots was added. The `chore(release): record build
N as shipped` pull request is opened by `github-actions[bot]` with a commit the
workflow authors AND commits as that bot, so it is internally consistent and
passes here on the ordinary rule. The `Co-authored-by: github-actions[bot]`
trailers on master come from GitHub crediting the bot when a person merges its
work, which is decided at merge time and is not something the branch could fix.
Refusing it would wedge the release pipeline permanently to no purpose: nothing
the bot could have done differently would clear the complaint.
"""

import argparse
import re
import subprocess
import sys

# `bl close` writes it as the last line of the delivery commit. Matched loosely
# on purpose -- the suffix is an opaque handle and its length is bl's business,
# not this file's.
BL_TAG = re.compile(r"\[bl-[0-9a-z]+\]", re.IGNORECASE)

# Two things keep this off the prose that discusses trailers rather than
# carrying one, and both are load bearing.
#
# The colon is required, which is what excuses `16f5bf4` -- the commit that
# added AGENTS.md, and so the commit whose body contains the phrase "no
# Co-authored-by trailer" while introducing the rule forbidding them. A grep for
# the phrase alone reports five such commits on master; four is the true count.
#
# The match is anchored to the start of a line, for the same sentence written
# with a colon in it. Git only reads a trailer as a trailer at the head of a
# line, and so does GitHub, so a mid-sentence mention is discussion however it
# is punctuated. Without this, the one file most likely to quote the rule --
# the one that states it -- is the one that cannot be committed.
COAUTHOR_TRAILER = re.compile(r"^[ \t]*co-authored-by:", re.IGNORECASE | re.MULTILINE)

# GitHub's own committer identity on a commit it created for an account.
GITHUB_COMMITTER = "noreply@github.com"

RESET_AUTHOR = (
    "Configure the identity first -- `git config user.name` and "
    "`git config user.email`, using the noreply address from "
    "https://github.com/settings/emails -- then rewrite the authorship: "
    "`git commit --amend --reset-author` for the tip alone, or "
    "`git rebase <base> --exec 'git commit --amend --reset-author --no-edit'` "
    "for a branch of them"
)


def identity(name, email):
    """A git identity as a message should print it."""
    return f"{name} <{email}>"


def carries_coauthor_trailer(message):
    """Whether a commit message attributes itself to somebody else."""
    return bool(COAUTHOR_TRAILER.search(message or ""))


def bl_tags(message):
    """Every `[bl-xxxx]` tag in a commit message, in the order they appear."""
    return BL_TAG.findall(message or "")


def split_identity(commit):
    """Whether this commit was authored by one identity and recorded by another.

    Compared on the email, which is what GitHub matches an account by; a name
    retyped with different capitalisation is the same person and a shared
    address is the same account whatever name is attached to it.
    """
    author = (commit["author_email"] or "").strip().lower()
    committer = (commit["committer_email"] or "").strip().lower()
    if author == committer:
        return False
    # GitHub committed it, so the author is an account it already resolved.
    if committer == GITHUB_COMMITTER:
        return False
    return True


def check(commits):
    """Every reason these commits must not be squashed onto master.

    Collects every problem rather than stopping at the first, so a branch that
    is wrong in three ways is not fixed three times over.
    """
    problems = []

    for commit in commits:
        short = commit["sha"][:7]

        if split_identity(commit):
            problems.append(
                f"{short} is authored by "
                f"{identity(commit['author_name'], commit['author_email'])} but "
                f"committed by "
                f"{identity(commit['committer_name'], commit['committer_email'])}. "
                "A squash merge credits the author GitHub does not recognise as "
                "the pull request's own in a Co-authored-by: trailer on master, "
                "and AGENTS.md forbids those. An author like "
                "`you@your-machine.local` means git had no configured identity "
                f"and invented one. {RESET_AUTHOR}"
            )

        if carries_coauthor_trailer(commit["message"]):
            problems.append(
                f"{short} carries a Co-authored-by: trailer, which AGENTS.md "
                "forbids. squash_merge_commit_message is COMMIT_MESSAGES, so "
                "the body of this commit is copied into master's. Reword it out "
                "with `git rebase -i <base>`"
            )

        for tag in bl_tags(commit["message"]):
            problems.append(
                f"{short} carries the balls tag {tag}. The tag is correct here: "
                "`bl close` writes it and reads it back to recognise a delivery "
                "it has already made, so removing it from a branch bl still owns "
                "breaks that retry, and teaching bl not to write it would be "
                "worse than this. It is wrong only once it reaches master, and "
                "it will: squash_merge_commit_message is COMMIT_MESSAGES, which "
                "copies every commit message on this branch verbatim into the "
                "one commit master keeps, where the tag names a task nothing on "
                "master can resolve. Close and deliver the task first, then "
                "reword the tag out of the delivered commit with "
                "`git rebase -i <base>`"
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


def merge_base(base_sha, head_sha):
    """The commit these two branches last had in common.

    `git merge-base` exits non-zero and says nothing at all when there is none,
    which through the helper above would report a git failure with an empty
    explanation under it. There is a real answer to give instead: two histories
    with no common ancestor cannot be compared, and no amount of rewording a
    commit will change that.
    """
    result = subprocess.run(
        ["git", "merge-base", base_sha, head_sha],
        capture_output=True, text=True, encoding="utf-8",
    )
    if result.returncode == 0:
        return result.stdout.strip()

    detail = result.stderr.strip()
    raise SystemExit(
        f"{base_sha} and {head_sha} have no commit in common, so there is no "
        "way to tell which commits this branch adds"
        + (f":\n{detail}" if detail else ". A shallow clone is the usual cause; "
           "this check needs fetch-depth: 0.")
    )


# NUL between the fields and a record separator between the commits, because a
# commit message contains newlines, blank lines and anything else a person
# types, and only bytes git will not emit can delimit it.
FORMAT = "%H%x00%an%x00%ae%x00%cn%x00%ce%x00%B%x1e"


def commits_between(base_sha, head_sha):
    """Every commit head adds that base does not already have."""
    raw = git("log", f"--format={FORMAT}", f"{base_sha}..{head_sha}")

    commits = []
    for record in raw.split("\x1e"):
        record = record.lstrip("\n")
        if not record.strip():
            continue
        sha, author_name, author_email, committer_name, committer_email, message = (
            record.split("\0")
        )
        commits.append({
            "sha": sha,
            "author_name": author_name,
            "author_email": author_email,
            "committer_name": committer_name,
            "committer_email": committer_email,
            "message": message,
        })
    return commits


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", required=True, help="SHA of the base commit")
    parser.add_argument("--head", required=True, help="SHA of the pull request head")
    args = parser.parse_args(argv)

    # Against the merge base rather than the base directly, so this reads what
    # THIS branch adds. Against the tip of master, every commit that landed
    # there since the branch started would be read as part of it and judged by
    # rules its authors never agreed to. Derived here rather than handed in so
    # that running this by hand on a branch needs no ceremony.
    base = merge_base(args.base, args.head)

    commits = commits_between(base, args.head)

    print(f"merge base:       {base[:7]}")
    print(f"commits to check: {len(commits)}")

    problems = check(commits)
    if not problems:
        print("\nCommit hygiene is fine.")
        return 0

    print("\nCommit hygiene check failed:", file=sys.stderr)
    for problem in problems:
        print(f"  - {problem}", file=sys.stderr)
    print(
        "\nEverything a commit on this branch says is copied into the commit\n"
        "that lands on master, because the repository squash merges with\n"
        "squash_merge_commit_message: COMMIT_MESSAGES. The rules are in\n"
        "AGENTS.md under Never add a Co-authored-by trailer and Task tracking\n"
        "with balls.",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
