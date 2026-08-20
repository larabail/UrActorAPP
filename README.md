# UrActor

A Flutter app for keeping track of the movies **and TV shows** you watch — what
you've seen, when you saw it, who you saw it with, and what you thought of it.

Titles and artwork come from [TMDB](https://www.themoviedb.org/). Accounts,
your history, your lists, and your friends live in Firebase. The app is built
for Android and iOS; the other Flutter platforms are scaffolded but not a
target (see [Platforms](#platforms)).

## Features

### Tracking

- Mark movies and TV shows as seen, and count rewatches (`lib/seen.dart`,
  `lib/common/firebase/watched_service.dart`).
- Keep a watchlist of things you mean to get to (`lib/watchlist.dart`).
- Keep favorites separately from the watchlist (`lib/favorites.dart`).
- Every media tile carries badges for the lists it is already on — a heart for
  a favorite, a bookmark for the watchlist — so search results, filmographies,
  playlists, the calendar and friends' profiles all say what you have already
  saved. The Favorites page drops the heart and the Watchlist page drops the
  bookmark, since there every tile would carry one
  (`lib/common/item_container.dart`, `lib/common/media_pair_membership.dart`).
- Rate a title and write a review. Movie and TV reviews are stored separately
  (`lib/reviews.dart`, `lib/popups/rating_popup.dart`).
- Log what you watched on a calendar — a single date or a date range. A show
  entry can also record which season and episode it was, which is optional and
  shown on both your own calendar and a friend's (`lib/calendar.dart`,
  `lib/friends_calendar.dart`, `lib/popups/add_to_calendar_pop_up.dart`,
  `lib/common/calendar_episode.dart`).
- Track what you are part way through. A movie or show is not started, being
  watched, or finished, and the control for moving between those states sits in
  the icon row on each detail page (`lib/common/watch_progress_widgets.dart`,
  `lib/common/firebase/progress_service.dart`). A finished show can be picked
  up again; a finished movie cannot, since rewatches are counted separately.
- Tick episodes and whole seasons off in the season guide. Watching the last
  episode finishes the show on its own (`lib/season_guide.dart`,
  `lib/common/watch_progress_controller.dart`). Specials (season 0) are not
  counted towards completion and offer no tick.
- Pick up where you left off. The home page carries a Continue watching row of
  everything started but not finished, most recent activity first, naming the
  next unwatched episode under each show. It is absent rather than empty when
  there is nothing to resume (`lib/continue_watching_section.dart`,
  `lib/common/continue_watching.dart`,
  `lib/common/firebase/progress_service.dart`).

### Lists

- Build custom lists that can hold both movies and TV shows
  (`lib/playlists.dart`, `lib/objects/Playlist.dart`).
- Share a list. Each list carries an access code, but new clients send the
  list name and code to the `joinPlaylist` Cloud Function so the code is
  checked server-side instead of exposing every playlist to the device
  (`lib/popups/list_join_popup.dart`, `functions/index.js`). You can also
  grant access to specific friends directly (`lib/popups/grant_access_dialogue.dart`).

### Friends

- Send and receive friend requests, with an inbox and notifications
  (`lib/friends.dart`, `lib/inbox.dart`, `lib/notifications.dart`).
- Look at a friend's profile, their calendar, and their thoughts on a title
  (`lib/friends_profile.dart`, `lib/friends_calendar.dart`,
  `lib/friends_thoughts.dart`).
- Record who you watched something with, and see which of your friends have
  already seen a title (`lib/seenTogether.dart`,
  `lib/popups/add_friends_seen_with_popup.dart`,
  `SocialService.friendsWhoHaveSeen`).

### Browsing

- One search box across movies, TV shows, and people, using TMDB's multi-search
  (`lib/search.dart`).
- Detail pages for movies, TV shows, and people (`lib/movie_result.dart`,
  `lib/tvshow_result.dart`, `lib/person_result.dart`).
- Full cast and crew (`lib/cast_and_crew.dart`).
- Season and episode guide for TV shows, with per-episode and per-season watch
  ticks (`lib/season_guide.dart`).
- Trailers play inline (`lib/common/mediaitembuilder.dart`).
- Streaming availability, via TMDB's watch providers endpoint.
- Oscar badges on person pages — a win count for the person and a marker on
  their award-winning titles. Data comes from the Firestore `Oscars`
  collection, which is populated by [`tools/sync-oscars`](tools/sync-oscars/README.md).
- Per-user recommendations for movies and TV
  (`lib/common/firebase/recommendation_service.dart`).

### Profile and settings

- Set a profile photo — pick from the device, crop it, upload to Firebase
  Storage (`lib/profile.dart`).
- Viewing stats rendered as charts (`fl_chart`, in `lib/profile.dart`).
- English and Spanish, switchable at runtime from settings
  (`lib/popups/settings_pop_up.dart`).

## Tech stack

| Piece | What it's used for |
|---|---|
| Flutter / Dart | The Android and iOS app |
| `firebase_auth` | Email accounts and session restore |
| `cloud_firestore` | Users, history, lists, reviews, friends, playlists, `Oscars` |
| `firebase_storage` | Profile photos and fallback cover/person images |
| Cloud Functions (Node 22) | Server-verified playlist joins and playlist membership sync |
| [TMDB API v3](https://developer.themoviedb.org/docs) | Movie, TV, person, search, credits, videos, watch providers, genres |
| `table_calendar` | The watch calendar |
| `fl_chart` | Profile stats |
| `youtube_player_flutter` | Trailer playback |
| `image_picker` + `image_cropper` | Profile photo capture |
| `cached_network_image` | Poster and backdrop caching |
| `flutter_localizations` + `intl` | EN/ES localization |

State is handled with plain `StatefulWidget`, `setState`, and
`FutureBuilder`/`StreamBuilder`. There is no state-management package.

## Platforms

**Android and iOS only.**

The desktop and web directories that `flutter create` scaffolds have been
removed: they carried no app-specific work and nothing was ever built or
tested against them. `flutter build` for `linux`, `macos`, `windows`, or `web`
will fail on a fresh clone, and that is intentional.

`lib/firebase_options.dart` still declares `web` and `macos` entries because it
is generated by `flutterfire configure`; it is left as generated rather than
hand-edited, so re-running the tool does not produce a spurious diff.

## Getting started

### Prerequisites

- **Flutter 3.47.1**. CI installs that exact SDK in
  `.github/actions/setup-flutter-android/action.yml`, so match it locally:
  verifying against a different SDK is not verifying what CI builds.
  `pubspec.yaml` still declares the wider Dart constraint
  `sdk: ">=3.5.4 <4.0.0"`, but the checked-in toolchain pin is the one to
  match for local verification.
- A **Firebase project** with Authentication, Firestore, and Storage enabled.
- A **TMDB API key** ([get one here](https://www.themoviedb.org/settings/api)).
- **Node 22** if you intend to deploy the Cloud Functions.

### Run it

```bash
flutter pub get
flutter gen-l10n
flutter run --dart-define=TMDB_API_KEY=your_key_here
```

The `--dart-define` is required — see [Configuration](#configuration).

### Firebase setup

`lib/firebase_options.dart` is committed, and it points at the original
project (`actordb-cf981`). A fresh clone cannot write to that project, so
point the app at your own:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

That regenerates `lib/firebase_options.dart` and the native config files. Also
update `.firebaserc` if you plan to deploy functions.

Committing this file is normal for FlutterFire: the values are project and app
identifiers, not secrets. Access is controlled by `firestore.rules`, not by
keeping them private.

The committed native config is incomplete. `android/app/google-services.json`
is present, but there is no `ios/Runner/GoogleService-Info.plist` — you will
need to add one for an iOS build. The iOS entry in `firebase_options.dart` is
also stale: it declares `iosBundleId: 'com.example.uractor'`, while the Xcode
project builds `com.uractor.uractorios`. Re-running `flutterfire configure`
against your own project fixes both.

The app expects each user to have a document tree keyed by their Firebase Auth
UID, including a `Settings` document. `lib/objects/User.dart` is the clearest
description of the shape it reads.

## Configuration

### TMDB API key

The key is **not** committed. It is read at build time from a `--dart-define`,
in `lib/common/constants.dart`:

```dart
// lib/common/constants.dart
const String TMDB_API_KEY = String.fromEnvironment('TMDB_API_KEY');
const String API_KEY = "?api_key=$TMDB_API_KEY";
```

Pass it on every run or build:

```bash
flutter run   --dart-define=TMDB_API_KEY=your_key_here
flutter build apk --dart-define=TMDB_API_KEY=your_key_here
```

If the define is missing, `assertTmdbApiKey()` throws at startup with a message
naming the flag. That is deliberate — without it, every TMDB request comes back
401 and the app just looks empty.

`test/constants_test.dart` asserts that no endpoint hardcodes a key, so a
regression fails the test suite rather than reaching a release.

> A key was previously committed to this repository and is still reachable in
> git history. **That key has since been revoked and reissued at TMDB**, so the
> one in history is dead. Keep passing the live key by define — never commit
> it, because removing it from the working tree does not remove it from history.

### OpenAI API key

The recommendation feature reads its key the same way:

```dart
const String OPENAI_API_KEY = String.fromEnvironment('OPENAI_API_KEY');
```

```bash
flutter run --dart-define=TMDB_API_KEY=... --dart-define=OPENAI_API_KEY=...
```

Unlike the TMDB key this one is optional: with no define, the recommendation
call is skipped rather than failing startup, since the rest of the app does not
depend on it.

> An OpenAI key was also committed and remains in git history. **It has since
> been revoked at <https://platform.openai.com/api-keys>**, so the one in
> history no longer works. Supply the current key by define only.

### Storing the keys locally

Rather than retyping the defines on every command, keep them in a file:

```bash
cp dart_defines.example.json dart_defines.json
```

Fill in the real values, then:

```bash
flutter run --dart-define-from-file=dart_defines.json
flutter build apk --dart-define-from-file=dart_defines.json
```

`dart_defines.json` is gitignored; `dart_defines.example.json` is committed as
the template and holds only placeholders. The VS Code launch configurations in
`.vscode/launch.json` already pass the flag, so **Run and Debug** works with no
extra setup.

Prefer this over exporting shell variables: `String.fromEnvironment` reads
compile-time defines, not the process environment, so an exported variable has
no effect.


## Project structure

```
lib/
  main.dart                  Firebase init, MaterialApp, locale switching, auth gate
  firebase_options.dart      Generated by `flutterfire configure`
  login.dart  signup.dart    Auth screens
  search.dart                Multi-search across movies, TV, people
  movie_result.dart          Movie detail
  tvshow_result.dart         TV detail
  person_result.dart         Person detail, Oscar badges
  season_guide.dart          Seasons and episodes, with watch ticks
  cast_and_crew.dart         Full credits
  list_result.dart           A single list
  seen.dart  watchlist.dart  favorites.dart  playlists.dart  reviews.dart
  continue_watching_section.dart  Home page "Continue watching" row
  calendar.dart              Watch calendar
  seenTogether.dart          Titles watched with a given friend
  friends.dart  friends_profile.dart  friends_calendar.dart  friends_thoughts.dart
  inbox.dart  notifications.dart
  profile.dart               Profile photo, stats charts

  objects/                   Media, Movie, TVShow, Person, Playlist, User
  common/
    constants.dart           TMDB endpoints; API key read from --dart-define
    utils.dart
    continue_watching.dart   Continue watching ordering and TMDB derivations
    item_container.dart  mediaitembuilder.dart  tabView.dart
    watch_progress_view.dart        Pure watch-progress rules
    watch_progress_controller.dart  Per-show episode tick state
    watch_progress_widgets.dart     The season, episode and detail controls
    api/apiutils.dart        All TMDB HTTP calls
    navigation/              appbar.dart, bottom_app_bar.dart
    firebase/                One service per domain: calendar, favorites,
                             playlist, progress, recommendation, review,
                             social, watched, watchlist, plus firestore_core
                             and firebaseutils
  popups/                    Dialogs: add to calendar, add friends seen with,
                             rating, share, settings, list add/edit/join,
                             grant access, movie add, tv add, profile sections
  l10n/                      app_en.arb, app_es.arb and their generated output

functions/                   Cloud Functions (Node 22): playlist join,
                             member sync, join-attempt cleanup
firestore-tests/              Firestore rules tests against the local emulator
tools/sync-oscars/           Firestore Oscars sync job
assets/                      Logos, tab icons, placeholder images, oscars_api.json
test/                        Flutter tests
```

## Cloud Functions

`functions/` holds three gen 2 Cloud Functions for project `actordb-cf981`, all
running on Node 22 in `us-central1`:

- `joinPlaylist` is a callable function. It requires auth, normalizes the list
  name and access code, throttles repeated misses in `JoinAttempts`, queries
  `Watchlists` by `Name`, compares the submitted code on the server, and adds
  the caller as `Approved` when it matches. The device no longer has to read
  every playlist just to test an access code.
- `syncPlaylistMembers` is a Firestore `onDocumentWritten` trigger on
  `Watchlists/{listId}`. It derives a flat `memberUids` array from the legacy
  `Users` role maps so clients can query their own playlists, and it exits when
  the projection is already current to avoid recursion.
- `cleanupJoinAttempts` is a scheduled function that runs every 24 hours and
  deletes stale join-throttle documents.

Deploy from `functions/` with the Firebase CLI after authenticating to the
Firebase project:

```bash
npm install
npm test
npm run deploy
```

Push notifications are not implemented. The old friend-request notification
trigger was removed because the app never registers an FCM token and the legacy
FCM send API it used was decommissioned.

## Localization

English and Spanish. Configured in `l10n.yaml`:

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: l10n.dart
output-class: S
```

Generated output lands in `lib/l10n/` and is committed, so run `flutter gen-l10n`
after touching any `.arb` file and commit the result.

The chosen language is stored in the user's Firestore `Settings` document,
applied on load in `main.dart`, and changed from `lib/popups/settings_pop_up.dart`.
An unsupported locale falls back to `en`. The same language code is passed to
TMDB as `&language=`, so titles, overviews, and trailers come back localized
too.

To add a language:

1. Copy `lib/l10n/app_en.arb` to `lib/l10n/app_<code>.arb` and translate the
   values. Keep the keys identical.
2. Set `"@@locale": "<code>"` at the top.
3. Run `flutter gen-l10n`.
4. Add a label for it in the language picker in
   `lib/popups/settings_pop_up.dart`, which currently hardcodes the choice
   between English and Español.

## Tests

The repo has three local suites:

```bash
flutter test

cd functions
npm install
npm test

cd ../firestore-tests
npm install
npm test
```

`flutter test` currently runs 555 tests with no emulator, credentials or
network access. Firestore and HTTP are reached through two seams —
`FirestoreCore.db` and `AppHttp.client` — which default to the real
implementations and are pointed at fakes by the tests.
`test/support/harness.dart` installs those fakes and restores them afterwards.
The Flutter suite covers pure logic, TMDB/OMDB request parsing with a stubbed
HTTP client, auth/session helpers, search and playlist ordering, playlist join
handling, settings, inbox, calendar/list services, calendar episode detail,
in-memory Firestore service behaviour, watch-progress rules and controls, the
media and person data objects, every popup under `lib/popups` except the
profile section editor, and the reviews and Continue watching screens.

`npm test` in `functions/` runs the Node 22 unit tests for the playlist
membership and join-throttle helpers. It currently reports 21 passing tests.

`npm test` in `firestore-tests/` starts the Firestore emulator with
`firebase emulators:exec` and runs the rules suite. It currently reports 76
passing tests. If port 8080 is already held by an emulator you started
separately, run `npx mocha rules.test.js --timeout 20000` from
`firestore-tests/` instead.

For coverage:

```bash
flutter test --coverage
python tool/coverage_summary.py
```

Coverage of `lib/common` and `lib/objects` is enforced at a floor of 68% in CI,
set in both `.github/workflows/pr.yml` and
`.github/workflows/release-internal.yml`. Move the two together, or a pull
request and a release will disagree about what passes. The floor deliberately
covers the tested layers rather than every screen in `lib/`, so a useful
regression signal is not diluted by UI code that still lacks widget tests.

## CI and releases

Pull requests to `master` run `.github/workflows/pr.yml` unless the change is
only Markdown, docs, or `.gitignore`. The workflow has three jobs:

- **Analyze, test and build** installs Flutter 3.47.1 plus the pinned Android
  NDK through `.github/actions/setup-flutter-android`, then runs
  `flutter analyze`, `flutter test --coverage`, the coverage floor, and a
  release app bundle build using `TMDB_API_KEY` and `OPENAI_API_KEY` from
  GitHub Actions secrets. Pull request bundles use debug signing and are
  checked to ensure no release signing material is present.
- **Functions** installs Node 22 dependencies in `functions/`, runs `npm test`,
  and confirms `index.js` loads.
- **Version** runs the unit tests under `tool/` and then enforces the version
  policy from [AGENTS.md](AGENTS.md#versioning) against the pull request title
  and commits. Do not edit the `+BUILD` suffix: the release workflow builds
  with a code derived from Play and writes that code back to `master` itself.

Every merge to `master` that is not docs-only runs
`.github/workflows/release-internal.yml`. It deploys Cloud Functions to
`actordb-cf981` first, then analyzes, tests with coverage, builds a signed app
bundle with a Play-derived version code, generates release notes, uploads to
Play internal testing, and keeps the bundle and coverage report as artifacts.
Internal builds are not tagged; the run summary records the version code and
the commit, which is what a production promotion is given. Production promotion
is separate and manual.

Once the upload succeeds, a last job commits the version code that shipped into
`pubspec.yaml` on `master`, so the `+BUILD` suffix in the repository matches the
newest build on the internal track. It pushes with the built-in `GITHUB_TOKEN`,
which GitHub does not let trigger further workflow runs — that is what stops a
release from releasing itself. If the push cannot be made, the run says so in
its summary and still passes: the app is already on Play by then, and failing
would report a shipped release as a broken one.

## Repo tooling

- [`tool/play.py`](tool/play.py) — Google Play release helper used by the
  release workflows and runnable by hand. See [Releasing](docs/releases.md).
- [`tools/sync-oscars`](tools/sync-oscars/README.md) — a standalone Node 18+
  script (no npm dependencies) that populates the Firestore `Oscars`
  collection from the UrActor API, resolving winners to TMDB ids. It has its
  own README covering name resolution, overrides, and known gaps.
- [`firestore.rules`](firestore.rules) — the checked-in Firestore security
  rules. They constrain both who may write and, for friend writes, the shape of
  what may be written. Read the rules' own KNOWN GAPS section before treating
  them as complete. The matching tests live in
  [`firestore-tests/`](firestore-tests/README.md) and run against the local
  emulator.
- [`.githooks/pre-commit`](.githooks/pre-commit) — runs analyze and the tests
  before a commit. Enable it with `git config core.hooksPath .githooks`.

## Contributing

[AGENTS.md](AGENTS.md) is the working agreement: no commits on `master`, tests
with new code, both `.arb` files when strings change, and the commit and pull
request conventions. Read it before opening a pull request.

## Known gaps

Things that are true today and worth knowing before you start:

| Gap | Detail |
|---|---|
| Push notifications are not implemented | The old notification function was removed because the app never registered FCM tokens and its legacy FCM API would no longer send. A future implementation needs `firebase_messaging`, token persistence, current FCM sends, APNs setup, and device testing. |
| iOS Firebase config is incomplete | No `ios/Runner/GoogleService-Info.plist`, and `firebase_options.dart` declares `iosBundleId: 'com.example.uractor'` while Xcode builds `com.uractor.uractorios`. Correcting it requires the real values from the Firebase console. |
| Coverage is uneven | The API layer, the data objects and the popups are covered; the full screens under `lib/` still have very few widget tests. See [Tests](#tests). |
