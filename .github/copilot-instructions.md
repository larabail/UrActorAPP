The working agreement for this repository lives in [AGENTS.md](../AGENTS.md).
Read it before making any change.

The parts that get changes rejected most often:

- Never commit to `master`; branch and open a pull request.
- Never add a `Co-authored-by` trailer to a commit.
- New behaviour needs a test; a bug fix needs a test that failed before it.
- A new user-visible string goes in **both** `lib/l10n/app_en.arb` and
  `lib/l10n/app_es.arb`, followed by `flutter gen-l10n`, with the generated
  files committed.
- Commits and pull request titles are `kind(scope): imperative summary`, and
  the body explains why, not what.
