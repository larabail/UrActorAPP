<!--
Title this pull request like a commit: kind(scope): imperative summary
e.g. feat(playlists): let playlists be arranged and drive the home page
-->

## What this changes

<!-- What was wrong or missing before, and what this does about it. -->

## Why this way

<!--
The reasoning, and what you rejected. If you weighed two approaches, say which
and why the other lost. If you deliberately left something undone, say so here
rather than leaving it to be discovered.
-->

## How it was tested

<!--
The tests you added, and anything you checked by hand that a test cannot cover
— on a device, against the emulator, in a particular locale.
-->

## Checklist

- [ ] Branched off `master`; no commits made directly on `master`
- [ ] `version:` in `pubspec.yaml` bumped to match what this changes — MINOR for
      a `feat`, PATCH for a `fix`, MAJOR for a breaking change, none for
      docs/ci/chore. See [Versioning](../AGENTS.md#versioning)
- [ ] `flutter analyze` is clean
- [ ] `flutter test` passes, and new behaviour has tests covering it
- [ ] Any new user-visible string was added to **both** `app_en.arb` and
      `app_es.arb`, `flutter gen-l10n` was run, and the generated files are
      committed
- [ ] Security rule changes come with matching tests in `firestore-tests/`
- [ ] No commit carries a `Co-authored-by` trailer
- [ ] Commit messages follow the convention in [AGENTS.md](../AGENTS.md)
