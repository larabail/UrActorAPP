#!/usr/bin/env python3
"""Tests for the commit hygiene check.

Run with: python -m unittest discover -s tool -p "test_*.py"

Two of these are fixtures of things that really happened, and they are the point
of the file. `TheDeliveryThatSynthesizedACoAuthor` is `ab224cc`, the `bl close`
commit whose invented author became a trailer, and `TheDeliveryThatCarriedItsTag`
is `3a39c88`, the commit that put `[bl-2964]` on master. Both are recorded as
data rather than read out of git, so they keep testing the logic once the
history around them has moved on -- and so they still mean something in a
shallow clone, where neither commit exists.

Reading commits out of git is not tested here. It is six lines of `git log` and
a split, and a test of it would be a test of git's `--format`; what is worth
pinning is what the rules do with an answer, which is all of the below.
"""

import unittest

from check_commit_hygiene import (
    bl_tags,
    carries_coauthor_trailer,
    check,
    split_identity,
)

# The identity this repository's owner actually commits under, and the one git
# invents when nothing is configured. Both verbatim from the history.
REAL = ("Lara Bailen Boluda", "85242173+larabail@users.noreply.github.com")
INVENTED = ("Lara Bailen", "larab@Laras-MacBook-Pro.local")
GITHUB = ("GitHub", "noreply@github.com")


def commit(sha="abc1234", message="fix(x): fix a thing", author=REAL, committer=None):
    """One commit in the shape `check` reads.

    The committer defaults to the author, which is what an ordinary commit made
    with a configured identity looks like.
    """
    committer = committer or author
    return {
        "sha": sha,
        "author_name": author[0],
        "author_email": author[1],
        "committer_name": committer[0],
        "committer_email": committer[1],
        "message": message,
    }


class RecognisingASplitIdentity(unittest.TestCase):
    def test_an_ordinary_commit_is_not_split(self):
        self.assertFalse(split_identity(commit()))

    def test_an_author_who_did_not_commit_it_is(self):
        self.assertTrue(split_identity(commit(author=INVENTED, committer=REAL)))

    def test_the_comparison_ignores_case(self):
        # Git preserves whatever was typed; GitHub matches an account by an
        # address it has already lowercased. Two spellings of one address are
        # one person, and complaining about them would be noise.
        shouted = (REAL[0], REAL[1].upper())
        self.assertFalse(split_identity(commit(author=REAL, committer=shouted)))

    def test_a_different_name_on_the_same_address_is_not_split(self):
        # The address is the identity. Somebody who retyped their own name, or
        # a tool that abbreviated it, has not handed the commit to a stranger.
        self.assertFalse(
            split_identity(commit(author=("L. Bailen", REAL[1]), committer=REAL))
        )

    def test_github_as_the_committer_is_not_split(self):
        # The web editor, the "Update branch" button and an applied review
        # suggestion all commit as GitHub on an account's behalf. GitHub
        # resolved the author itself, so no trailer follows and complaining
        # would refuse a perfectly ordinary way of working.
        self.assertFalse(split_identity(commit(author=REAL, committer=GITHUB)))

    def test_github_committing_for_someone_else_is_still_not_split(self):
        # Same reasoning, and worth pinning separately: the exemption is about
        # who recorded the commit, not about the two identities agreeing.
        self.assertFalse(split_identity(commit(author=INVENTED, committer=GITHUB)))


class RecognisingATrailer(unittest.TestCase):
    def test_finds_a_trailer_in_the_footer(self):
        message = (
            "fix(x): fix a thing\n"
            "\n"
            "Why it was wrong.\n"
            "\n"
            "Co-authored-by: Someone <someone@example.com>\n"
        )
        self.assertTrue(carries_coauthor_trailer(message))

    def test_finds_it_whatever_its_capitalisation(self):
        # Git treats a trailer key case-insensitively, and so does GitHub.
        self.assertTrue(carries_coauthor_trailer("x\n\nco-authored-by: A <a@b.c>\n"))
        self.assertTrue(carries_coauthor_trailer("x\n\nCO-AUTHORED-BY: A <a@b.c>\n"))

    def test_finds_an_indented_one(self):
        self.assertTrue(carries_coauthor_trailer("x\n\n  Co-authored-by: A <a@b.c>\n"))

    def test_prose_about_trailers_is_not_a_trailer(self):
        # This repository's own documentation commits explain the rule, and the
        # check must not refuse the commit that writes the rule down. Anchoring
        # to the start of a line is what buys that.
        message = (
            "docs: forbid attribution trailers\n"
            "\n"
            "A commit must not carry a Co-authored-by: line, and in particular\n"
            "must not attribute anything to an agent.\n"
        )
        self.assertFalse(carries_coauthor_trailer(message))

    def test_the_commit_that_wrote_the_rule_down_is_not_refused(self):
        # `16f5bf4`, verbatim and abridged: the commit that added AGENTS.md, and
        # therefore the commit whose body says "no Co-authored-by trailer" while
        # introducing the rule against them.
        #
        # It is the cheapest possible false positive to write and the most
        # embarrassing to ship -- a check that cannot accept the document
        # stating its own rule. A grep for the phrase reports five commits on
        # master; four is the true count, and this is the fifth. The colon is
        # what excuses it here, and the line anchor covers the same sentence
        # written with one.
        message = (
            "docs: write down how work gets done in this repository\n"
            "\n"
            "AGENTS.md states the rules that actually get changes rejected: no\n"
            "commits on master, tests alongside new code, both arb files\n"
            "whenever a string is added, no Co-authored-by trailer, and the\n"
            "conventional-commit format with a body that explains why rather\n"
            "than listing files.\n"
        )
        self.assertFalse(carries_coauthor_trailer(message))
        self.assertEqual(check([commit(sha="16f5bf4", message=message)]), [])

    def test_an_ordinary_message_carries_none(self):
        self.assertFalse(carries_coauthor_trailer("feat(search): rank by relevance"))


class RecognisingABallsTag(unittest.TestCase):
    def test_finds_the_tag_bl_close_writes(self):
        self.assertEqual(bl_tags("fix(x): a thing\n\nWhy.\n\n[bl-2964]\n"), ["[bl-2964]"])

    def test_finds_one_in_a_subject(self):
        # `bl close` puts it at the end of the message, but a squash of several
        # delivered commits ends up with it mid-subject, which is how `c81de79`
        # carried it.
        self.assertEqual(bl_tags("fix(auth): say what is blocked [bl-4e19]"), ["[bl-4e19]"])

    def test_reports_every_occurrence(self):
        # `5677d89` on master carries two, one from each half of the message.
        self.assertEqual(len(bl_tags("a [bl-4e19]\n\nb [bl-4e19]\n")), 2)

    def test_an_ordinary_message_carries_none(self):
        self.assertEqual(bl_tags("feat(search): rank by relevance"), [])

    def test_something_that_merely_looks_like_one_is_not_a_tag(self):
        # A bracketed word is not a task handle. The tracker writes `bl-` and a
        # hexadecimal handle, and matching more loosely would refuse ordinary
        # prose in a commit body.
        self.assertEqual(bl_tags("fix(x): stop [blocking] the queue"), [])
        self.assertEqual(bl_tags("fix(x): see [bl] for context"), [])


class Check(unittest.TestCase):
    def test_a_clean_branch_passes(self):
        commits = [
            commit(sha="aaa", message="ci(hygiene): refuse a synthesized author"),
            commit(sha="bbb", message="docs: explain the trap\n\nWhy it matters.\n"),
        ]
        self.assertEqual(check(commits), [])

    def test_an_empty_branch_passes(self):
        # A pull request whose commits are all already on master adds nothing,
        # and there is nothing to be wrong about.
        self.assertEqual(check([]), [])

    def test_every_problem_is_collected(self):
        # Not stopping at the first, so a branch that is wrong in three ways is
        # not fixed three times over with a new run between each.
        commits = [commit(
            sha="aaa",
            author=INVENTED,
            committer=REAL,
            message="fix(x): a thing\n\n[bl-1234]\n\nCo-authored-by: A <a@b.c>\n",
        )]
        self.assertEqual(len(check(commits)), 3)

    def test_a_split_identity_names_the_remedy(self):
        problems = check([commit(author=INVENTED, committer=REAL)])
        self.assertEqual(len(problems), 1)
        self.assertIn("--reset-author", problems[0])

    def test_a_tag_is_not_reported_as_something_to_delete_from_the_branch(self):
        # The tag is how bl recognises a delivery it has already made, so an
        # error that reads as "remove this" invites somebody to break the
        # tracker's retry. The message has to say the tag is right here and
        # wrong only on master.
        problems = check([commit(message="fix(x): a thing\n\n[bl-2964]\n")])
        self.assertEqual(len(problems), 1)
        self.assertIn("correct here", problems[0])
        self.assertIn("master", problems[0])


class TheDeliveryThatSynthesizedACoAuthor(unittest.TestCase):
    """`ab224cc`, recorded as it actually is.

    A single `bl close` delivery on `larabail-fix-play-user-fraction`, made in a
    worktree where no git identity resolved. Git invented the author from the
    account's full name and the machine's hostname; `bl close` re-committed with
    the configured identity, keeping the invention as the author. GitHub's
    squash of that branch, `0ff0cb44`, ends with

        Co-authored-by: Lara Bailen <larab@Laras-MacBook-Pro.local>

    which is the trailer AGENTS.md forbids, produced by nobody typing it.

    It is one commit, which is the part that matters for the design. There is no
    second author on the branch to disagree with, so a check that only compared
    the commits with each other would have passed this branch and the trailer
    would have reached master anyway. The committer is what makes it visible.

    It did reach master. GitHub still records `0ff0cb44` as the merge commit of
    `#147`, and it is no longer an ancestor of `master`: what master holds is
    `3a39c88`, same tree, same parent, same committer second, trailer gone. The
    only remedy left by then was rewriting a branch configured to refuse force
    pushes, and the API still answers with the superseded commit. That is the
    cost this check exists to avoid, and it is why the rule is enforced on the
    branch rather than reported afterwards.
    """

    SHA = "ab224cc4d1b1e0a37fe1de7c8ecb0d0a5ff1a19c"

    COMMITS = [{
        "sha": SHA,
        "author_name": "Lara Bailen",
        "author_email": "larab@Laras-MacBook-Pro.local",
        "committer_name": "Lara Bailen Boluda",
        "committer_email": "85242173+larabail@users.noreply.github.com",
        "message": "ci(release): send a 100% Android rollout as a completed release\n"
                   "\n"
                   "A 100% rollout sent as inProgress leaves the release in a\n"
                   "state the Play Console shows as still rolling out.\n",
    }]

    def test_is_caught(self):
        self.assertEqual(len(check(self.COMMITS)), 1)

    def test_is_caught_as_a_split_identity(self):
        self.assertTrue(split_identity(self.COMMITS[0]))

    def test_the_commits_alone_would_not_have_caught_it(self):
        # The regression this fixture exists for. One commit means one author,
        # so a check comparing the commits with each other would have found
        # perfect agreement on a branch that was exactly wrong. The committer is
        # the only thing on the branch that disagrees with anything.
        self.assertFalse(
            split_identity(commit(author=INVENTED, committer=INVENTED)),
            "the author alone is indistinguishable from an honest one",
        )
        self.assertTrue(split_identity(self.COMMITS[0]))

    def test_the_message_itself_was_innocent(self):
        # Nothing in what anyone wrote was wrong. The trailer was composed by
        # GitHub out of the authorship, which is why checking messages alone
        # would not have stopped it.
        self.assertFalse(carries_coauthor_trailer(self.COMMITS[0]["message"]))
        self.assertEqual(bl_tags(self.COMMITS[0]["message"]), [])


class TheDeliveryThatCarriedItsTag(unittest.TestCase):
    """`3a39c88`, the commit that put `[bl-2964]` on master.

    The same piece of work as the fixture above, after merging. The tag was
    written on the branch by `bl close`, where it belongs, and reached master
    because `squash_merge_commit_message` is `COMMIT_MESSAGES`: GitHub copies
    the branch's commit messages into the squash commit's body without reading
    them. `5677d89` carries `[bl-4e19]` the same way.

    Neither is being rewritten. `master` refuses force pushes, and rewriting
    published history to tidy a tag would cost more than the tag does. What is
    fixed is the next one.

    The message is the real one, abridged in the paragraphs that do not matter.
    """

    SHA = "3a39c8896fb308817f133f824ebdec6e06159b8b"

    COMMITS = [{
        "sha": SHA,
        "author_name": "Lara Bailen Boluda",
        "author_email": "85242173+larabail@users.noreply.github.com",
        "committer_name": "Lara Bailen Boluda",
        "committer_email": "85242173+larabail@users.noreply.github.com",
        "message": "ci(release): send a 100% Android rollout as a completed release\n"
                   "\n"
                   "A rollout at 100% is not a rollout, and halting stops one\n"
                   "short, so completing it would resume the very release that\n"
                   "was being stopped.\n"
                   "\n"
                   "No version bump: nothing about the shipped app changes, only\n"
                   "the pipeline that promotes it.\n"
                   "\n"
                   "[bl-2964]\n",
    }]

    def test_is_caught(self):
        problems = check(self.COMMITS)
        self.assertEqual(len(problems), 1)
        self.assertIn("[bl-2964]", problems[0])

    def test_its_authorship_was_fine(self):
        # This one was committed with a configured identity. Only the message
        # was wrong, which is why the two rules are separate and neither would
        # have been enough on its own.
        self.assertFalse(split_identity(self.COMMITS[0]))


class TheBranchWithTwoAddresses(unittest.TestCase):
    """`#116`, the pull request that says why authors are not compared.

    `larabail-perf-persist-sort-metadata` carries three commits under two
    different author addresses -- `larabailen.lb@gmail.com` on the work, and the
    noreply address on the merge of master that GitHub's "Update branch" button
    made. By address alone that is two authors on one branch, which is the shape
    a squash merge is supposed to turn into a trailer.

    It did not. `31e8ca8`, the commit it squashed to, carries none, because both
    addresses are verified on one GitHub account and GitHub resolves an author
    to an account before deciding whom to credit. Only the API knows that; from
    a clone the two are indistinguishable from two people.

    So this is the fixture that keeps a plausible rule out. A check that
    compared commit authors with each other would have blocked this pull
    request, and the person told to "fix" it would have had nothing wrong to
    fix.

    The middle commit is the second thing this pins. Authored by the account and
    committed by GitHub, it is a split identity by the letter of the rule, and
    it is exempt because GitHub resolved that author itself. Without the
    exemption, every branch that has ever used the "Update branch" button would
    fail.
    """

    COMMITS = [
        commit(sha="7328215",
               author=("larabail", "larabailen.lb@gmail.com"),
               message="build: take the next free patch after 3.18.2 was claimed"),
        commit(sha="20519de",
               author=REAL,
               committer=GITHUB,
               message="Merge branch 'master' into "
                       "larabail-perf-persist-sort-metadata"),
        commit(sha="ffda6e7",
               author=("larabail", "larabailen.lb@gmail.com"),
               message="perf(media): persist sort metadata across restarts"),
    ]

    def test_stays_mergeable(self):
        self.assertEqual(check(self.COMMITS), [])

    def test_the_update_branch_merge_is_not_a_split_identity(self):
        self.assertFalse(split_identity(self.COMMITS[1]))


class TheReleaseWriteBack(unittest.TestCase):
    """The `chore(release): record build N as shipped` pull request.

    It opens every release, it is merged by a person, and it must stay
    mergeable: a check that refused it would stop the build number ever being
    recorded, and there is nothing the workflow could do differently to satisfy
    one. The commit is authored AND committed as `github-actions[bot]`, because
    the `record` job configures both before committing, so it passes on the
    ordinary rule with no exemption written for it.

    The `Co-authored-by: github-actions[bot]` trailers on master come from
    GitHub crediting the bot when a person merges its work. That is decided at
    merge time out of the pull request's authorship, and no branch can prevent
    it -- which is the argument for not making it a failure here.
    """

    BOT = ("github-actions[bot]",
           "41898282+github-actions[bot]@users.noreply.github.com")

    COMMITS = [commit(
        sha="694cfa5",
        author=BOT,
        committer=BOT,
        # The subject carries a skip-ci marker in reality. It is left out here
        # rather than assembled from fragments, because this file has nothing
        # to say about it and AGENTS.md would rather it were not written down
        # again.
        message="chore(release): record build 88 as shipped\n"
                "\n"
                "The version code comes from Play at build time, so the\n"
                "committed +BUILD suffix never described anything that shipped.\n",
    )]

    def test_stays_mergeable(self):
        self.assertEqual(check(self.COMMITS), [])


if __name__ == "__main__":
    unittest.main()
