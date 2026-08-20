# Releasing

Two workflows, split by risk. Internal testing is automatic; production is not.

| | Internal testing | Production |
|---|---|---|
| Trigger | every merge to `master` | manual only |
| Builds? | yes | no, promotes an existing build |
| Who can run it | anyone merging | you, via environment approval |
| Rollout | all testers | your choice, 5–100% |

## How the split works

Merging to `master` builds a signed bundle and ships it to internal testers.
Production takes the bundle testers already installed and moves it across
without rebuilding, so the artifact that goes live is byte-for-byte the one
that was verified. Rebuilding for production would discard that evidence.

Every release runs inside a Play *edit transaction*: open, change, commit.
Nothing is visible on Play until the commit succeeds, so a failed run cannot
leave a half-applied release behind.

## Version codes

Version codes come from Play, not from `pubspec.yaml`.

Play permanently burns a version code once it is uploaded, **even if the
upload is abandoned and never assigned to a track**. A committed build number
therefore drifts out of date and collides — which is exactly what happened to
build 45. The workflow asks Play for the highest code ever used and adds one.

The `version:` line in `pubspec.yaml` supplies the user-facing name (`3.5.4`);
the `+build` half is not read when building a release. It is written, though:
after a successful upload the workflow commits the code it just shipped back
onto `master`, so the file records the last build testers received rather than
drifting for months. Nobody edits it by hand.

That write-back is a separate job in `release-internal.yml`, and the only place
in either release workflow that a token can write to the repository:

- **It pushes with the built-in `GITHUB_TOKEN`.** GitHub does not start new
  workflow runs from pushes made with that token, and that is the only reason
  a workflow triggered by `master` can commit to `master` without releasing
  forever. A personal access token, a deploy key or a GitHub App token would
  all remove that protection. The `[skip ci]` in the commit subject is a
  second guard, not the mechanism.
- **A rejected push is retried.** An ordinary merge can land between the
  checkout and the push. The job fetches `master` again, re-applies the number
  and retries, three times, then gives up.
- **It never fails the run.** The bundle is already on Play before this job
  starts. A write-back that cannot be made is reported loudly in the run
  summary and left for a person, rather than turning a release that shipped
  into a red run.

## Restricting production to you

Deployment protection rules — the **Required reviewers** setting — are not
available for private repositories on the Free plan, so that section does not
appear under **Settings → Environments → production**.

Authorisation is enforced in the workflow instead. A first job checks the login
that started the run against the `RELEASE_MANAGERS` repository variable,
defaulting to `larabail`, and fails before anything reaches Play. Set the
variable under **Settings → Secrets and variables → Actions → Variables** to
change who may release.

Be clear about how strong this is: anyone with write access could edit the
workflow to remove the check. It stops mistakes and casual runs, not someone
determined who already has write access. The controls that actually matter are
keeping write access limited and protecting `master`.

The job still targets a `production` environment, so deployments are recorded
and required reviewers apply automatically if this repository ever moves to a
plan that offers them, with no change to the workflow.

> Repository secrets are readable by any workflow that runs. Treat write access
> to this repo as equivalent to holding the signing key.

## Secrets

Set these under **Settings → Secrets and variables → Actions**.

| Secret | What it is |
|---|---|
| `PLAY_SERVICE_ACCOUNT_JSON` | The service account key, pasted whole |
| `ANDROID_KEYSTORE_BASE64` | The upload keystore, base64 encoded |
| `ANDROID_KEYSTORE_PASSWORD` | `storePassword` from `key.properties` |
| `ANDROID_KEY_PASSWORD` | `keyPassword` |
| `ANDROID_KEY_ALIAS` | `keyAlias` |
| `TMDB_API_KEY` | TMDB key |
| `OPENAI_API_KEY` | OpenAI key |

Encode the keystore with:

```bash
base64 -w0 android/app/upload-keystore.jks        # Linux
```

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("android\app\upload-keystore.jks"))
```

The workflow writes both the keystore and `key.properties` at build time and
deletes them in an `always()` step, so they never persist on the runner.

## Releasing to production

**Actions → Release to production → Run workflow.**

| Input | Meaning |
|---|---|
| Version code | Blank promotes the latest internal build |
| Rollout | Share of users; start small |
| Status | `inProgress` goes live, `draft` stages it in Play for review |

Approve the deployment when prompted. To widen or halt a rollout afterwards,
use the Play Console — a halted rollout stops new users receiving the update,
but does not remove it from anyone who already has it.

The promotion refuses to go backwards. If production already serves a higher
version code than internal, the run fails with an explanation rather than
being rejected by Play. That happens when a build is uploaded to production by
hand, which leaves production ahead of the track it is supposed to be promoted
from; the fix is to build a newer version rather than to promote an older one.

## Release notes

Notes are generated from commit subjects, so there is nothing to write by hand.

Only user-facing types are used. `feat` becomes **New**, `fix` becomes
**Fixed**, `perf` becomes **Improved** and `security` becomes **Security**.
Everything else — `chore`, `ci`, `refactor`, `test`, `docs`, `build`, `style` —
is dropped, along with any subject that is not a conventional commit, since a
dependency bump means nothing to someone reading a store listing.

Internal builds cover commits since the previous `build-*` tag. Production
covers commits since the last `released-*` tag, so a user who skipped several
test builds still sees everything that changed for them, and the range ends at
the promoted build's tag rather than at `HEAD`, so the notes never describe
code that is not in the artifact being shipped.

### Overriding a note

A commit subject is written for other developers and sometimes describes
internals that should not be advertised. Any commit can override its own entry:

```
fix(auth): stop storing the password in a global

Release-Note: Fixed a rare sign-in failure.
```

Use `Release-Note: skip` to leave a commit out entirely.

Without the trailer, that example would have published *"stop storing the
password in a global"* to the store, which is both confusing and an
advertisement of a weakness.

### Length

Play rejects notes over 500 characters per language. The generator drops
whole entries from the least important section until the note fits, rather
than truncating mid-sentence. If nothing user-facing is found it falls back to
"Bug fixes and performance improvements."

Preview what would be published:

```bash
python tool/release_notes.py --stdout
python tool/release_notes.py --since released-47 --until build-52 --stdout
```

Only `en-US` is generated, because that is the only store listing that exists.

## Running it by hand

`tool/play.py` is the same script CI uses:

```bash
export PLAY_SERVICE_ACCOUNT_JSON="$(cat service-account.json)"

python tool/play.py next-code
python tool/release_notes.py --output build/release_notes.json
python tool/play.py upload --aab build/app/outputs/bundle/release/app-release.aab --track internal --notes build/release_notes.json
python tool/play.py promote --source internal --target production --rollout 0.1
```

`next-code` is read-only and a good way to confirm credentials work.
