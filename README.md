# UrActor

A Flutter app for keeping track of the movies **and TV shows** you watch — what
you've seen, when you saw it, who you saw it with, and what you thought of it.

Titles and artwork come from [TMDB](https://www.themoviedb.org/). Accounts,
your history, your lists, and your friends live in Firebase. The app runs on
Android, iOS, macOS and Windows, laying itself out from the width of the
window rather than the device it is on (see [Platforms](#platforms) and
[Layout](#layout)).

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
  entry can also record the last episode you finished that day, which drives
  tracking rather than just being written down: the show moves into progress
  and every episode up to that point is ticked off. An entry that names no
  season still means the whole title was watched, which is what every entry
  meant before episodes were recordable (`lib/calendar.dart`,
  `lib/friends_calendar.dart`, `lib/popups/add_to_calendar_pop_up.dart`,
  `lib/common/calendar_episode.dart`, `lib/common/calendar_progress.dart`).
- Track what you are part way through. A movie or show is not started, being
  watched, or finished, and the control for moving between those states sits in
  the icon row on each detail page (`lib/common/watch_progress_widgets.dart`,
  `lib/common/firebase/progress_service.dart`). A finished show can be picked
  up again; a finished movie cannot, since rewatches are counted separately.
  A movie is set to being watched from that control and nowhere else — a
  calendar entry records a day you watched something, which for a film is a
  completed act, so the calendar always means finished there.
- See when you watched something. A title's viewing history is headed with the
  range it covers: the first day recorded through to the day it was finished,
  or through to the present while it is still being watched. The dates come
  from the calendar, so an account that predates watch progress keeps the
  history it always had (`lib/common/viewing_history_range.dart`,
  `lib/common/viewing_history_widgets.dart`).
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
| `firebase_storage` | Profile photos |
| Cloud Functions (Node 22) | Server-verified playlist joins and playlist membership sync |
| [TMDB API v3](https://developer.themoviedb.org/docs) | Movie, TV, person, search, credits (a show's aggregated across every season), videos, watch providers, genres |
| `table_calendar` | The watch calendar |
| `fl_chart` | Profile stats |
| `youtube_player_flutter` | Trailer playback |
| `image_picker` + `image_cropper` | Profile photo capture |
| `cached_network_image` | Poster and backdrop caching |
| `flutter_localizations` + `intl` | EN/ES localization |

State is handled with plain `StatefulWidget`, `setState`, and
`FutureBuilder`/`StreamBuilder`. There is no state-management package.

## Platforms

**Android, iOS, macOS and Windows.**

| Platform | Status |
| --- | --- |
| Android, iOS | Shipped to testers by CI on every merge to `master` |
| macOS, Windows | Buildable and supported; not part of the release workflow |
| Linux | Not a target — see below |
| Web | Not a target; no `web/` directory |

### Why not Linux

Firebase is where the account, lists, history and friends live, and there is
no part of the app that works without it. `firebase_core`, `firebase_auth`,
`cloud_firestore` and `firebase_storage` all declare `android`, `ios`,
`macos`, `web` and `windows`, and none of them declares `linux`. A Linux build
would compile and then fail at the first read, so it is left out deliberately
rather than shipped broken. `DefaultFirebaseOptions` says so if you try.

If FlutterFire ships Linux support, adding it is `flutter create
--platforms=linux .` plus whatever the capability checks below turn out to
need.

### What is missing on desktop

Two plugins have no desktop implementation. Neither is hidden everywhere to
suit them; each is handled where it is used, and the decision lives in
`lib/common/platform/capabilities.dart` as a pure function of the platform so
that the answer for Windows can be tested from a machine that is not Windows.

| Feature | Gap | What happens instead |
| --- | --- | --- |
| Cropping a profile photo | `image_cropper` is Android, iOS and web only | The picked photo is uploaded uncropped |
| Playing a trailer inline | the player is a webview, and there is none on Windows | A link out to YouTube |

### Notes on the desktop builds

- macOS builds through CocoaPods, as iOS does. This is pinned in
  `pubspec.yaml` under `flutter: config:` rather than left to whatever
  `flutter config` says on a given machine, so a fresh clone and CI agree.
- The macOS sandbox denies outgoing connections unless asked. Every screen
  here is network backed, so `com.apple.security.network.client` is set in
  both `macos/Runner/Release.entitlements` and `DebugProfile.entitlements`.
  Without it the app launches to a permanently empty window.
- `lib/firebase_options.dart` points Windows at the same registration the web
  app uses, which is what the desktop SDK reads. Re-running `flutterfire
  configure` and choosing Windows will replace that with a generated entry.

## Layout

The app lays itself out from the width of the window rather than from the
device, so a desktop window dragged narrow gets the phone layout and a tablet
in landscape gets the desktop one. The rules are in
`lib/common/layout/breakpoints.dart`, which has no widget or network
dependency so the arithmetic is unit tested directly.

| Class | Width | Navigation | Panes |
| --- | --- | --- | --- |
| compact | < 600 | bottom bar | one |
| medium | 600–1024 | rail | one |
| expanded | 1024–1440 | rail | list and detail |
| large | ≥ 1440 | rail with labels | list and detail |

Two things follow from this that are worth knowing before changing a screen:

- **Never size a tile as a fraction of the window.** Doing so ties the tile's
  proportions to the window's, which is only ever right on a phone held
  upright. Posters are a fixed 2:3 and take a width in logical pixels from
  `posterWidthFor`; episode stills are 16:9. Grids count how many columns fit
  with `gridColumnsFor` instead of hard coding a number.
- **Open detail pages with `openDetail`, not `Navigator.push`.** It puts the
  page in the detail pane when there is one and over the whole window when
  there is not, so a call site does not have to know which layout it is in. A
  plain push still covers the window, which is right for a dialogue and wrong
  for anything a list points at.

`LayoutScope` publishes the width of a *region* rather than the window, so a
list occupying half a wide window sizes its contents to the half it has.
Inside a pane, read the size class from `context.sizeClass`, never from
`MediaQuery`.

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
- For an iOS build, **Xcode 16 or newer** and **CocoaPods**. Firebase 12
  requires both that and an iOS 15 deployment target. See
  [Building for iOS](#building-for-ios).

### Run it

```bash
flutter pub get
flutter gen-l10n
flutter run --dart-define=TMDB_API_KEY=your_key_here
```

The `--dart-define` is required — see [Configuration](#configuration).

To run it as a desktop app, name the device:

```bash
flutter run -d macos   --dart-define=TMDB_API_KEY=your_key_here
flutter run -d windows --dart-define=TMDB_API_KEY=your_key_here
```

Both open wide enough to start on the two pane layout. Drag the window
narrow to check the phone layout without a simulator — the app follows the
window, so every breakpoint is reachable by resizing.

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

The committed native config is partial. `android/app/google-services.json` is
present; there is no `ios/Runner/GoogleService-Info.plist`. That file is not
required to build or run the app today, because `main.dart` passes
`DefaultFirebaseOptions.currentPlatform` to `Firebase.initializeApp`, so iOS
configures itself from Dart rather than from a bundled plist. Anything that
reads the native config directly — APNs, `firebase_messaging`, App Check —
would need it added.

The iOS entry in `firebase_options.dart` is stale in one respect: it declares
`iosBundleId: 'com.example.uractor'` while the Xcode project builds
`com.uractor.uractorios`. Auth, Firestore and Storage key off the API key and
the app id, so the mismatch stops neither a build nor a sign in, but re-running
`flutterfire configure` against your own project corrects it along with the
rest.

The app expects each user to have a document tree keyed by their Firebase Auth
UID, including a `Settings` document. `lib/objects/User.dart` is the clearest
description of the shape it reads.

### Building for iOS and macOS

Apple dependencies are managed with **CocoaPods** on both platforms;
`ios/Podfile`, `ios/Podfile.lock` and `macos/Podfile` are committed. Flutter
reaches for Swift Package Manager first, which this project is not set up for
and which fails while resolving. That is now turned off for the project rather
than per machine, in `pubspec.yaml`:

```yaml
flutter:
  config:
    enable-swift-package-manager: false
```

So there is nothing to configure locally — `flutter config
--no-enable-swift-package-manager` is no longer needed, and a fresh clone and
CI build the same way. Build as usual:

```bash
flutter build ios --simulator --debug --dart-define-from-file=dart_defines.json
flutter build macos --debug --dart-define-from-file=dart_defines.json
```

The first build resolves Firebase 12 and compiles gRPC and Firestore from
source. Budget around ten minutes and several gigabytes of free disk. A full
disk surfaces late and misleadingly here, as an rsync failure copying
`grpc.framework` into `Runner.app` rather than as an out-of-space message from
the compiler. If CocoaPods cannot find a pod version the plugins ask for, its
local index is behind: refresh it with `pod repo update`.

A simulator build needs no code signing. A device or release build does: the
project sets `DEVELOPMENT_TEAM = Q8XY8276AC`, so that Apple Developer account
has to be signed in to Xcode.

CI covers this on macOS runners. `.github/workflows/ios.yml` builds the app
and launches it on a simulator for pull requests that touch `ios/` or either
pubspec file, and `.github/workflows/release-testflight.yml` ships to
TestFlight. Both run on `macos-26`, because Apple refuses uploads built with
an SDK older than iOS 26 and the older image defaults to Xcode 16. The pull
request check is filtered to those paths on purpose: macOS runners bill at ten
times the Linux rate on a private repository, and a Dart-only change cannot
break the native build without also changing pubspec. See
[docs/releases.md](docs/releases.md).

**Run `flutter clean` after any change to `ios/Podfile.lock`.** `flutter
build` will not do it for you, and a stale `build/` directory holding the
previous version of a plugin produces a compiler error about "different
definitions in different modules" that names neither the stale file nor the
pod that changed.

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

### OMDB API key

The IMDb rating shown on a title, and the "sort by IMDb rating" option, come
from OMDB, which needs its own key:

```dart
const String OMDB_API_KEY = String.fromEnvironment('OMDB_API_KEY');
```

```bash
flutter run --dart-define=OMDB_API_KEY=... --dart-define=TMDB_API_KEY=...
```

Like the TMDB key and unlike the OpenAI one, this is **required**: startup calls
`assertOmdbApiKey()` and fails loudly without it. That is deliberate. There is no
skip path around OMDB the way there is around the recommendation call, so a
missing key does not disable a feature — it makes every rating read `0.0`, which
looks like data rather than a misconfiguration.

> This key was committed as a hardcoded `defaultValue` in the source and
> therefore reached every build shipped to Play.
> **A key compiled into an app is extractable by anyone who downloads it**, and
> it remains in git history regardless of the working tree. Revoke and reissue it
> at <https://www.omdbapi.com/apikey.aspx>, then supply the new one by define.

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
    constants.dart           TMDB and OMDB endpoints; both keys read from
                             --dart-define
    utils.dart
    continue_watching.dart   Continue watching ordering and TMDB derivations
    item_container.dart  mediaitembuilder.dart  tabView.dart
    watch_progress_view.dart        Pure watch-progress rules
    watch_progress_controller.dart  Per-show episode tick state
    watch_progress_widgets.dart     The season, episode and detail controls
    calendar_progress.dart          What a calendar entry means for tracking
    viewing_history_range.dart      When a title was started and finished
    viewing_history_widgets.dart    The range shown above a viewing history
    api/apiutils.dart        All TMDB HTTP calls; a show's credits come from
                             aggregate_credits and are flattened to the shape
                             /credits returns
    navigation/              appbar.dart, app_scaffold.dart, destinations.dart
    layout/                  breakpoints.dart (pure window-size rules),
                             responsive.dart (LayoutScope, poster helpers),
                             two_pane.dart (list-and-detail, openDetail)
    platform/capabilities.dart  What each platform's plugins can do
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
assets/                      Logos, tab icons, the cover and person
                             placeholders, oscars_api.json
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

`flutter test` currently runs 658 tests with no emulator, credentials or
network access. Firestore and HTTP are reached through two seams —
`FirestoreCore.db` and `AppHttp.client` — which default to the real
implementations and are pointed at fakes by the tests.
`test/support/harness.dart` installs those fakes and restores them afterwards.
The Flutter suite covers pure logic, TMDB/OMDB request parsing with a stubbed
HTTP client, auth/session helpers, search and playlist ordering, playlist join
handling, settings, inbox, calendar/list services, calendar episode detail,
what a calendar entry does to watch progress, viewing history ranges,
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
  release app bundle build using `TMDB_API_KEY`, `OPENAI_API_KEY` and
  `OMDB_API_KEY` from
  GitHub Actions secrets. Pull request bundles use debug signing and are
  checked to ensure no release signing material is present.
- **Functions** installs Node 22 dependencies in `functions/`, runs `npm test`,
  and confirms `index.js` loads.
- **Version** runs the unit tests under `tool/` and then enforces the version
  policy from [AGENTS.md](AGENTS.md#versioning) against the pull request title
  and commits. Do not edit the `+BUILD` suffix: the release workflow builds
  with a code derived from Play and writes that code back to `master` itself.

The iOS check lives in its own workflow, `.github/workflows/ios.yml`, because
it needs a macOS runner and those bill at ten times the Linux rate on a private
repository. It runs only for pull requests touching `ios/`, `pubspec.yaml` or
`pubspec.lock` — a Dart-only change is already covered on Linux and cannot
break the native build without also changing pubspec. It builds for the
simulator with `--no-codesign`, then installs and launches the app and checks
it is still running fifteen seconds later, because the iOS failure that
matters most, Firebase failing to configure, happens at launch rather than at
compile time.

There is no XCTest job. `ios/RunnerTests` still contains only the empty
`testExample` stub that `flutter create` generates, and the app has no native
code beyond an `AppDelegate` that registers plugins, so running it would spend
macOS minutes asserting nothing. If real Swift is ever added to `ios/Runner`,
that is the point to wire `xcodebuild test` into the iOS workflow.

Xcode Cloud archives the app as well, and reports on pull requests as
`uractorapp | Default | Archive - iOS`. It is configured in App Store Connect
rather than in this repository, and it runs `xcodebuild` against
`ios/Runner.xcworkspace` on a bare clone, knowing nothing about Flutter. What
makes that work is
[`ios/ci_scripts/ci_post_clone.sh`](ios/ci_scripts/ci_post_clone.sh), which
Xcode Cloud runs after cloning: it installs the pinned Flutter SDK, resolves
packages, writes `ios/Flutter/Generated.xcconfig` through
`flutter build ios --config-only`, and installs the pods. None of those are
committed, so without the script the archive fails on the missing files rather
than on anything in the change. The directory and file names are fixed by Xcode
Cloud, and the file has to stay executable in git; renamed, moved, or
non-executable, it is skipped with no explanation and the build fails exactly
as it did before. Its Flutter version is pinned to the same one as
`.github/actions/setup-flutter-ios`, and the two are meant to move together.

The three API keys reach that build as Xcode Cloud environment variables set on
the workflow in App Store Connect, not as GitHub Actions secrets. The script
warns instead of failing when one is missing, because an archive built without
them is still a valid archive — it is the app that throws at startup, and
failing the build there would report an unset workflow variable as broken code.

Every merge to `master` that is not docs-only runs
`.github/workflows/release-internal.yml`. It deploys Cloud Functions to
`actordb-cf981` first, then analyzes, tests with coverage, builds a signed app
bundle with a Play-derived version code, generates release notes, uploads to
Play internal testing, and keeps the bundle and coverage report as artifacts.
Internal builds are not tagged; the run summary records the version code and
the commit, which is what a production promotion is given. Production promotion
is separate and manual.

The same merge also runs `.github/workflows/release-testflight.yml`, which
builds a signed IPA on a macOS runner and uploads it to TestFlight. Its build
number comes from App Store Connect through `tool/appstore.py`, the counterpart
to `tool/play.py`, and is deliberately **not** written back to `pubspec.yaml`:
the `+BUILD` suffix there records Play's version code, and the two stores count
independently. The workflow stays inert until its six App Store secrets exist —
a `preflight` job reports which are missing and skips the expensive job — so it
does not fail every merge before the credentials are in place.

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
| iOS Firebase config is partial | There is no `ios/Runner/GoogleService-Info.plist`, and `firebase_options.dart` declares `iosBundleId: 'com.example.uractor'` while Xcode builds `com.uractor.uractorios`. Neither stops an iOS build or a sign in, because Firebase is configured from Dart, but APNs, `firebase_messaging` and App Check would all need the plist. |
| iOS is not released to the App Store automatically | `.github/workflows/release-appstore.yml` submits a version for review and, as a second deliberate run, releases it once Apple approves. Neither happens on merge: Apple reviews every version by hand, so there is no equivalent of Play's promote-and-it-is-live. The version record and its store metadata are still created in App Store Connect. |
| Coverage is uneven | The API layer, the data objects and the popups are covered; the full screens under `lib/` still have very few widget tests. See [Tests](#tests). |
| A friend's watch progress cannot be set from your device | Tagging a friend on a calendar entry writes to their calendar and seen-with records, but `firestore.rules` lets a client write its own `Progress` document and nobody else's. So an entry naming an episode no longer marks the show fully seen for them — which would be a lie — but it cannot record them as part way through it either, and the show reads as not started on their side until they log it themselves. Closing this needs the write to move behind a Cloud Function. |
