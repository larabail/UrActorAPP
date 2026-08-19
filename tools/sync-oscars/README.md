# sync-oscars

Populates the Firestore `Oscars` collection from the UrActor API, so the app's
Oscar badges stay current without anyone editing Firestore by hand.

## Why this exists

The app and the API disagree about shape, and neither can be changed cheaply:

| | API (`api.uractor.com`) | App (`lib/objects/User.dart`) |
|---|---|---|
| Indexed by | ceremony year, then category | `tmdb_id` |
| Identifies people by | name string | TMDB id |
| Contains | nominees *and* winners | winners only |
| Category naming | `Best Achievement in Directing` | `Directing` |

Pointing the app straight at the API would mean matching people by name, which
silently loses badges whenever spelling drifts — the API says
`Ludwig Goransson`, TMDB says `Ludwig Göransson`. This job does the awkward
translation once, in a place where a bad match is visible and fixable, and
leaves the app's fast single-query read alone.

## Running it

```bash
export URACTOR_API_KEY=...      # key from api.uractor.com
export TMDB_API_KEY=...         # same key the app uses
export GCP_ACCESS_TOKEN=$(gcloud auth print-access-token)

node sync-oscars.js --year=2026            # dry run, prints a plan
node sync-oscars.js --year=2026 --commit   # write it
node sync-oscars.js --all --commit         # rebuild every year
```

Dry run is the default; nothing is written without `--commit`.

For a scheduled run, point `GOOGLE_APPLICATION_CREDENTIALS` at a service-account
JSON with Firestore write access instead of using `GCP_ACCESS_TOKEN`. The script
mints its own token, so it needs no npm dependencies — plain Node 18+.

## Name resolution

Each winner is resolved to a `tmdb_id` in this order:

1. `overrides.json`, if the name appears there
2. an existing `Oscars` document with a matching `name`
3. TMDB person search — **exact name match only**

An inexact TMDB hit is reported and **held back**, never written. This is
deliberate: TMDB search always returns *something*, and accepting a near-miss
pins an Oscar on the wrong person's profile in the app. `--accept-fuzzy`
overrides this if you have checked the matches yourself.

### overrides.json

Copy `overrides.example.json` to `overrides.json` and map names to TMDB ids:

```json
{
  "Teddy Park": 1234567,
  "Joong Gyu Kwak": null
}
```

`null` means "skip this person deliberately" — use it for songwriters and crew
who have no TMDB profile at all.

## Known gaps as of the 2026 sync

Six 2026 winners are held back pending a verified TMDB id. Until they are added
to `overrides.json` they simply do not appear in the app:

| Winner | Category | Bad TMDB suggestion |
|---|---|---|
| Teddy Park | Original Song | `Teddy Parker` |
| Joong Gyu Kwak | Original Song | `ZHUN` |
| Yu Han Lee | Original Song | `Lee Yu Han` |
| Hee Dong Nam | Original Song | `NHD` |
| Jeong Hoon Seo | Original Song | `Jeong Seong-hoon` |
| Jordan Samuel | Makeup and Hairstyling | `Samuel Jordan` |

Five of the six are *Golden* songwriters from KPop Demon Hunters.

## Notes

- Only winners are stored, matching the existing collection and the
  `num_oscars` badge count in `person_result.dart`.
- `num_oscars` is recomputed as the total award count across all years. The
  collection already followed this rule for 2,325 of 2,339 documents; the sync
  corrects the handful that had drifted low.
- International Feature Film is skipped — it credits a country and a film, never
  a person, so it has no place in a per-person document.
- Writes are idempotent. Re-running will not duplicate an award already present.
