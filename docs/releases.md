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

The `version:` line in `pubspec.yaml` still supplies the user-facing name
(`3.5.4`); only the `+build` half is ignored in CI.

## Restricting production to you

The `production` job targets a GitHub Environment named `production`. Set it up
once:

1. Repository **Settings → Environments → New environment**, named
   `production`.
2. Tick **Required reviewers** and add yourself, alone.
3. Optionally limit deployment branches to `master`.

The job then pauses for your approval before it touches Play. This is stronger
than checking who started the run: even someone with write access who triggers
the workflow cannot proceed without you approving it.

> Repository secrets are readable by any workflow that runs. Environment
> protection controls *deployment*, not secret access, so treat write access to
> this repo as equivalent to holding the signing key.

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

`release_notes.json` maps a language to its text. Notes for a language with no
store listing are dropped with a warning rather than failing the release, since
Play rejects them outright. Only `en-US` exists today; the Spanish text is
already written and will start being used as soon as an `es-ES` listing is
added.

Play limits notes to 500 characters per language.

## Running it by hand

`tool/play.py` is the same script CI uses:

```bash
export PLAY_SERVICE_ACCOUNT_JSON="$(cat service-account.json)"

python tool/play.py next-code
python tool/play.py upload --aab build/app/outputs/bundle/release/app-release.aab --track internal
python tool/play.py promote --source internal --target production --rollout 0.1
```

`next-code` is read-only and a good way to confirm credentials work.
