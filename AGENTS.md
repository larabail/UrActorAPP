# Working in this repository

Instructions for agents and humans working on UrActor. Read this before making
any change.

The app is a Flutter client for Android and iOS backed by Firebase and TMDB.
`README.md` covers what it does, how to run it and how it is laid out; this file
covers how work gets done.

## The rules

These are not style preferences. Breaking one of these means the change gets
sent back.

### Never commit to `master`

`master` is the release branch: a merge to it that changes anything a build can
contain builds and ships to internal testers automatically. All work happens on
a branch and lands through a pull request.

Branch names are `kind/short-description`, using the same kinds as the commit
convention below — `feat/playlist-reordering`, `fix/search-encoding`,
`ci/ndk-install`, `docs/contributing`.

### Never add a `Co-authored-by` trailer

Commits must not carry `Co-authored-by:` lines, and in particular must not
attribute anything to Copilot. If your tooling adds one by default, strip it
before committing. This applies to squash-merge commit bodies too.

The trap is that you can break this rule without typing anything. GitHub writes
the trailer itself when a squash merge finds a commit author it does not
recognise as the pull request's own, and the usual way to produce one of those
is to commit with no `user.name` and `user.email` configured — git invents an
author from your account and hostname rather than refusing. Set them once:

```bash
git config --global user.name 'Your Name'
git config --global user.email 'ID+login@users.noreply.github.com'
```

The address is on <https://github.com/settings/emails>. `.githooks/pre-commit`
refuses a commit made without one, and `tool/check_commit_hygiene.py` refuses
the pull request.

### New code comes with tests

Any new behaviour needs a test, and any bug fix needs a test that fails before
the fix. `flutter analyze` and `flutter test` must both be clean before you open
a pull request.

Put pure logic in its own file so it can be tested without a widget or a
network call. Separating the rule from the fetching — a comparator in one file,
the Firestore call that feeds it in another — is what makes the first half
trivially testable when the second half is not.

Firestore and HTTP are reached through seams — `FirestoreCore.db` and
`AppHttp.client` — that default to the real implementations and are swapped for
fakes in tests. Use them. Never call `FirebaseFirestore.instance` or the
top-level `http.get` directly: it puts the code beyond reach of any test and
makes the suite hit the live, rate-limited APIs. `test/support/harness.dart`
installs the fakes and tears them down again.

The Firestore security rules have their own suite in `firestore-tests/`. Change
`firestore.rules` and you update those tests too.

### Every user-visible string goes in both `.arb` files

Text is localized in English and Spanish. Adding a string means adding the key
to **both** `lib/l10n/app_en.arb` and `lib/l10n/app_es.arb`, then running
`flutter gen-l10n`. The generated files under `lib/l10n/` are committed, so
include them in the same commit.

A key present in only one file is a missing translation at runtime, not a build
error, so nothing will catch this for you.

Never hardcode a display string in a widget. Reach for it with
`S.of(context)!.yourKey`.

### Keep `README.md` current

`README.md` is the first map for a new contributor. If a change alters setup
steps, commands, architecture, CI behaviour, or user-facing features, update
the README in the same pull request. Do not leave the next person to discover
the new truth by reading the diff, a workflow log, or source code.

## Commit convention

Conventional Commits, with a body that explains the reasoning.

```
kind(scope): imperative summary in lower case

Why this change was needed, and what was wrong before.

What the change does about it, and any consequence a reader would not guess.
Note anything deliberately left undone.
```

Kinds in use: `feat`, `fix`, `refactor`, `test`, `docs`, `ci`, `build`, `chore`.
The scope is the area touched — `search`, `media`, `friends`, `playlists`,
`android`, `l10n`. It is optional when a change is genuinely repo-wide.

The summary line stays under about 72 characters, is imperative ("add", not
"added" or "adds"), and has no trailing full stop.

The body is the part that matters. Explain the problem before the solution. A
diff shows what changed; only the message can say why, and why the alternatives
were worse. Record the tradeoffs you made and anything you chose not to do —
that is what saves the next person from repeating your dead ends.

Do not describe the change as a list of edited files. Do not write "as
requested". Do not mention the agent, the model, or the conversation.

## Versioning

`version:` in `pubspec.yaml` is `MAJOR.MINOR.PATCH+BUILD`, for example
`3.5.4+47`. Bump the **name**; leave the `+BUILD` suffix to CI.

The build number is not yours to choose. Play refuses any code it has already
seen, so the release workflow asks Play for the next free one, builds with it,
and — once the upload to internal testing has succeeded — opens a pull request
putting it back into `pubspec.yaml`. The suffix in the file is therefore a
record of the last build that reached testers, not an input to the next one.
Editing it changes nothing about what gets released and will be overwritten by
the next release.

That pull request comes from `github-actions[bot]` and is titled
`chore(release): record build N as shipped [skip ci]`. Approve and merge it like
any other; it is one line of `pubspec.yaml`. There is at most one open at a time,
and each release rewrites it, so merging the newest is always enough — and if a
version name bump has since landed on `master` it will conflict, at which point
closing it costs nothing. It cannot be a direct push because `master` requires a
pull request and the bot cannot be excused from that — see
[docs/releases.md](docs/releases.md#version-codes).

One consequence: a branch that lives a long time can conflict on the `version:`
line when `master` is merged into it, because CI has been moving it. Resolve it
by keeping your own name and `master`'s build number.

How far to bump follows directly from the commit kind:

| The change is | Kind | Bump |
| --- | --- | --- |
| Something users could not do before | `feat` | MINOR — `3.5.4` to `3.6.0` |
| Something that was broken now works | `fix`, `perf` | PATCH — `3.5.4` to `3.5.5` |
| Something users must relearn, redo, or lose | any kind with `!` | MAJOR — `3.5.4` to `4.0.0` |
| Nothing a user would notice | `docs`, `ci`, `test`, `chore`, `refactor`, `build` | none |

A minor bump resets the patch to zero, and a major resets both. `3.6.4` after
`3.5.4` reads as four patches that never happened.

MAJOR is a judgement call, not an arithmetic one. Reserve it for a release
someone would experience as a different app: a redesign they have to relearn, a
migration that makes them sign in again, a feature taken away. Reorganising code
is never major, however large the diff. Mark it by putting `!` before the colon
(`feat(auth)!: drop anonymous sign in`) or with a `BREAKING CHANGE:` footer.

Bumping further than required is always allowed — nothing overrules a person who
decides a release deserves more.

A merge to master that changes anything a build can contain ships to internal
testers, which is why this matters: without a bump, two different builds reach
testers under the same name and a bug report cannot be tied to a revision.

`tool/check_version_bump.py` enforces this on every pull request, reading both
the title and the commits and taking the larger requirement. The title counts
because pull requests are squash merged, so it is the only subject that reaches
master.

One exemption, by path rather than by kind: a pull request that changes nothing
a build can contain needs no bump at all, whatever its title says. Workflows,
composite actions, `tool/`, `tools/`, `.githooks/`, `firestore-tests/`, the
downloads site under `web/downloads/`, prose and checkout configuration are all
on that list. A change to any of them can be honestly a `feat` or a `fix` — the
downloads site is a public web page, and a broken release script is a real bug —
but the app it would rename is byte for byte the app testers already have.

That list is not written down twice. It is the `paths-ignore:` block of
`.github/workflows/release-internal.yml`, which is what GitHub itself consults
when deciding whether the merge ships anything, and both the version check and
the release watchdog read it from there through `tool/release_paths.py`. Add a
path to that block and all three change together. Bumping anyway is always
allowed.

A change of that shape also skips the release entirely; see
[what does not reach a tester](README.md#what-does-not-reach-a-tester).

## Pull requests

### Title

Same shape as a commit summary: `kind(scope): imperative summary`. The title
becomes the squash-merge commit subject, so it has to stand on its own in
`git log`.

```
feat(playlists): let playlists be arranged and drive the home page
fix(search): stop losing results and rank them by relevance
ci: install the pinned Android NDK before building
```

Never open a pull request titled `Update file.dart`, `changes`, or `WIP`.

### Body

Fill in `.github/pull_request_template.md`. The checklist is not decoration:
tests, both `.arb` files, no `Co-authored-by`, analyze and test clean.

### Checks

The pull request workflow in `.github/workflows/` runs analyze, the test suite
with coverage, and a full release build on every pull request. It does not
publish. A red pull request does not get merged; fix it rather than merging
around it.

Coverage of `lib/common` and `lib/objects` is held at a floor. Adding untested
code to those directories can push it under and fail the build.

## Task tracking with balls

Work is tracked with [balls](https://github.com/mudbungie/balls) (`bl`), a
git-native task tracker built for running several agents in parallel. Each task
gets its own worktree, and one agent takes a task the whole way through:
`claim` → work → `close`.

`bl` is self-documenting and its guide is authoritative over this section. Read
it rather than guessing:

```bash
bl --skill              # the full operating guide
bl <command> --skill    # complete usage for one command
```

The shape of a session:

```bash
git switch -c feat/whatever      # bl delivers onto the current branch
bl prime --as YOUR_ID            # start of every session, always
bl list                          # what is ready
bl create "short title"          # file a task, prints its id
bl claim <id> --as YOUR_ID       # prints the worktree path
# ... all edits happen inside that worktree ...
bl close <id> --as YOUR_ID       # runs the pre-commit gate, then delivers
```

Things that catch people out:

- **`bl` delivers to whatever branch HEAD is on**, which it calls the
  integration branch — not to a branch named `main` specifically. Since nothing
  may land on `master`, check out the feature branch for the piece of work
  *first*, then `bl prime` there. Every task closed in that session delivers
  onto that branch, and the branch is what becomes the pull request.
- **Always pass `--as`.** Left to themselves, models pick the same handful of
  names and claim each other's tasks. The identity comes from outside.
- **All edits go in the claimed worktree.** `bl close` delivers that worktree's
  diff; an edit made anywhere else is invisible to it, and the task closes
  clean while your change stays behind.
- **`bl close` is gated by the repo's `pre-commit` hook**, so analyze and the
  test suite have to pass before anything lands — and so does a configured git
  identity, for the reason below.
- **Configure `user.name` and `user.email` before you claim anything.** A bl
  worktree inherits whatever identity the shell that made it had, and with none
  git does not complain: it invents an author from your account's full name and
  the machine's hostname and commits under it. GitHub has never heard of that
  address, so squash merging credits it as a *co-author* of the commit that
  lands on `master` — a `Co-authored-by:` trailer nobody typed, breaking the
  rule above. It has happened twice, both times through bl. The hook now refuses
  such a commit and `tool/check_commit_hygiene.py` refuses the pull request, but
  neither is as cheap as setting it once with `git config --global`.
- **Reword the `[bl-xxxx]` tag out before you open the pull request.** `bl close`
  appends it to the delivery commit and reads it back to recognise a delivery it
  has already made, so it is doing a job on the branch and stripping it while bl
  still owns the task breaks that retry. It is only wrong once it reaches
  `master`, and it does: the repository squash merges with
  `squash_merge_commit_message: COMMIT_MESSAGES`, which copies every branch
  commit message verbatim into master's, where the tag names a task nothing on
  master can resolve. Close and deliver first, then `git rebase -i` the tag out
  of the delivered commit. Two are on `master` already and are staying there;
  rewriting published history to tidy them would cost more than they do.
- **You reconcile, close validates.** If the target branch moved, close refuses
  rather than merging for you. Merge it into your worktree, re-run the tests
  there, then close again.
- **Search before filing.** `bl list <needle> --all` covers closed tasks too,
  and the reasoning behind a past decision is usually still in the task.

Split work into separate tasks when the pieces are genuinely independent, since
that is what lets them run in parallel. When one piece has to land before
another can close, make it a subtask — an epic collects its children on its own
branch and delivers them as a single commit when the epic closes.

## Before you open a pull request

```bash
flutter analyze                  # must be clean
flutter test                     # must be green
flutter gen-l10n                 # if you touched either .arb file
flutter build appbundle --release --dart-define=TMDB_API_KEY=... \
                                 --dart-define=OPENAI_API_KEY=...
```

The build is worth running by hand when you have touched anything under
`android/`, since that is where CI failures are slowest to diagnose.

`.githooks/pre-commit` runs the first two for you, but git does not pick up
hooks from a tracked directory on its own. Enable it once per checkout:

```bash
git config core.hooksPath .githooks
```

It skips documentation-only commits, and `git commit --no-verify` gets past it
when you genuinely need to commit something that does not build.

## Things that will waste your time

- **Never write `[skip ci]` literally in a commit message**, not even in the
  body while explaining it. GitHub scans the whole message, not just the
  subject, so a commit that merely *mentions* the marker silently runs no
  workflows at all — the pull request then sits with no checks reported and
  nothing to say why. Write "the skip-ci marker" in prose instead. Quoting it
  in a file, as here, is harmless; only the commit message is scanned. The
  release workflow uses it deliberately; see
  [docs/releases.md](docs/releases.md#version-codes).

  This has already cost a release. `7347803` is the commit that added this very
  warning, and its body explains that the marker in the write-back's subject is
  a second line of defence — a sentence that is itself a marker. It merged, no
  workflow ran, and nothing reached internal testers. Nobody noticed for
  weeks, because a run that never starts leaves nothing to go red.

  On `master` the consequence is worse than a pull request with no checks: the
  merge ships nothing, and the next release quietly carries two changes under
  one build. **If you merge something that changes what a build contains and no
  release run appears, dispatch "Release to internal testing" by hand from the
  Actions tab.** A merge confined to the release workflow's `paths-ignore` —
  workflows, `tool/`, prose — correctly produces no run and needs nothing doing;
  see [what does not reach a tester](README.md#what-does-not-reach-a-tester).
  `.github/workflows/check-release-gap.yml` also notices within a day and files
  an issue, but it is a backstop, not a substitute for looking. It reads the
  same filter, so it stays quiet about the merges that were never meant to ship.

  Note what the rule is *not*. This is about the commit message, and it can
  happen to any commit touching any file — a feature branch whose author was
  documenting the trap is the likeliest place for it. It is tempting to
  remember it as "changing a workflow file skips the release", because the one
  commit it happened to did both. That reading was already wrong on the
  evidence: the merge that added `check-release-gap.yml` (`5612c18`) added a
  workflow file and produced a release run normally.

  It is now wrong in a second, more confusing way, so hold the two apart. A
  merge whose files are *all* inside `paths-ignore` — which since this was
  written includes `.github/` — produces no release run **by design**, and that
  is not this bug. The tell is what else the merge touched: a merge of workflows
  alone is silent on purpose, while a merge of workflows *and* a line of `lib/`
  must ship, because GitHub skips a run only when every changed path matches.
  A design that skips is fine and the watchdog knows about it; a message that
  suppresses is the bug, and the watchdog reports it.

  That counterexample comes with one qualification, because the difference
  matters. `5612c18` was merged with a personal access token. GitHub's
  documented rule is about *integration* tokens — `GITHUB_TOKEN` and GitHub
  Apps — so it may still hold for the merge button, and nothing here tests
  that. What can be said with evidence: **the marker in a commit message is the
  only confirmed cause**, and if credential-based suppression exists it depends
  on how the push was made, not on what the diff contained.

  There is a live example of the integration-token rule in a neighbouring
  place, and it is worth knowing it is a different rule with a similar smell:
  `GITHUB_TOKEN` cannot push *any* ref whose `.github/workflows/` content
  differs from the default branch's, which is why the production release tags
  through the REST API rather than `git push`. That one fails loudly. The
  suppression above is the one that fails silently.

  And note *where* it bites. A pull request that touches only workflow files
  still gets its checks, and those checks run the edited definitions, because
  `pr.yml` has no path filter and a pull request is evaluated from its own merge
  commit. **Workflow changes are self-verifying at review time.** The hole is
  the push to `master` at merge — either from a message carrying the marker,
  which is confirmed, or from integration-token suppression, which is
  documented in general but is not what the evidence here isolates. Green checks
  on the pull request tell you the workflow is correct; they tell you nothing
  about whether merging it will produce a release — and since a workflow-only
  merge is now meant to produce none, they never will.
- **Git exports `GIT_DIR` into every hook**, and it beats the repository a
  nested tool picks for itself. `flutter` asks git for its own version, so a
  hook that runs it without clearing `GIT_DIR`, `GIT_WORK_TREE` and their
  relatives gets an SDK that calls itself `0.0.0-unknown`, rebuilds its tool on
  every attempt, and fails pub resolution with an error naming a package —
  nothing in it points at the hook. `.githooks/pre-commit` unsets them, after
  reading the staged file list and not before, because that list comes from
  `GIT_INDEX_FILE` and clearing it first breaks the change detection instead.
  Anything else that runs a git-aware tool from a hook needs the same
  treatment.
- The generated files under `lib/l10n/` are committed. Forgetting
  `flutter gen-l10n` leaves them stale and the diff looks unrelated to your
  change.
- `.gitattributes` normalizes line endings to LF. CRLF warnings on commit under
  Windows are expected and harmless.
- Flutter build-time API keys are supplied with `--dart-define` and are compiled
  into the binary, not encrypted. Never commit one, and never assume a shipped
  key is private. Server-only keys, such as OMDB, belong in Firebase secrets.
- Secrets used by CI live in GitHub Actions secrets. See
  [docs/releases.md](docs/releases.md).
