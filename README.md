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
- Rate a title and write a review. Movie and TV reviews are stored separately
  (`lib/reviews.dart`, `lib/popups/rating_popup.dart`).
- Log what you watched on a calendar — a single date or a date range
  (`lib/calendar.dart`, `lib/popups/add_to_calendar_pop_up.dart`).

### Lists

- Build custom lists that can hold both movies and TV shows
  (`lib/playlists.dart`, `lib/objects/Playlist.dart`).
- Share a list. Each list carries an access code, and friends join by entering
  it (`lib/popups/list_join_popup.dart`). You can also grant access to specific
  friends directly (`lib/popups/grant_access_dialogue.dart`).

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
- Season and episode guide for TV shows (`lib/season_guide.dart`).
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
| Flutter / Dart | The app itself, all six platform targets |
| `firebase_auth` | Email accounts and session restore |
| `cloud_firestore` | Users, history, lists, reviews, friends, `Oscars` |
| `firebase_storage` | Profile photos and fallback cover/person images |
| Cloud Functions (Node 18) | One Firestore trigger, in `functions/` |
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

`flutter create` scaffolded all six platforms, and `.metadata` still tracks
them: `android`, `ios`, `linux`, `macos`, `web`, `windows`.

Android and iOS are the real targets. The desktop and web directories exist but
carry no app-specific work, and nothing here is built or tested against them.
Treat them as scaffolding, not as supported platforms.

## Getting started

### Prerequisites

- **Flutter 3.35.0 or newer** (Dart 3.9.0+). `pubspec.yaml` declares
  `sdk: ">=3.5.4 <4.0.0"`, but the committed `pubspec.lock` resolves to
  `dart: ">=3.9.0 <4.0.0"` / `flutter: ">=3.35.0"`, so the lockfile is the
  constraint that actually bites.
- A **Firebase project** with Authentication, Firestore, and Storage enabled.
- A **TMDB API key** ([get one here](https://www.themoviedb.org/settings/api)).
- **Node 18** if you intend to deploy the Cloud Functions.

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

The committed native config is incomplete. `android/app/google-services.json`
and `macos/Runner/GoogleService-Info.plist` are present, but there is no
`ios/Runner/GoogleService-Info.plist` — you will need to add one for an iOS
build. The iOS entry in `firebase_options.dart` is also stale: it declares
`iosBundleId: 'com.example.uractor'`, while the Xcode project builds
`com.uractor.uractorios`. Re-running `flutterfire configure` against your own
project fixes both.

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

> **A key was previously committed to this repository and is still reachable in
> git history.** Removing it from the working tree does not remove it from
> history, so it should be revoked and reissued at TMDB.

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
  season_guide.dart          Seasons and episodes
  cast_and_crew.dart         Full credits
  list_result.dart           A single list
  seen.dart  watchlist.dart  favorites.dart  playlists.dart  reviews.dart
  calendar.dart              Watch calendar
  seenTogether.dart          Titles watched with a given friend
  friends.dart  friends_profile.dart  friends_calendar.dart  friends_thoughts.dart
  inbox.dart  notifications.dart
  profile.dart               Profile photo, stats charts

  objects/                   Media, Movie, TVShow, Person, Playlist, User
  common/
    constants.dart           TMDB endpoints; API key read from --dart-define
    utils.dart
    item_container.dart  mediaitembuilder.dart  tabView.dart
    api/apiutils.dart        All TMDB HTTP calls
    navigation/              appbar.dart, bottom_app_bar.dart
    firebase/                One service per domain: calendar, favorites,
                             playlist, recommendation, review, social,
                             watched, watchlist, plus firestore_core and
                             firebaseutils
  popups/                    Dialogs: add to calendar, add friends seen with,
                             rating, share, settings, list add/edit/join,
                             grant access, movie add, tv add, profile sections
  l10n/                      app_en.arb, app_es.arb and their generated output

functions/                   Cloud Functions (Node 18)
tools/sync-oscars/           Firestore Oscars sync job
assets/                      Logos, tab icons, placeholder images, oscars_api.json
test/                        Flutter tests
```

## Cloud Functions

`functions/` holds exactly one function, `sendFriendRequestNotification`
(`functions/index.js`). It is a Firestore `onCreate` trigger on
`{userId}/Friends/FriendRequests/{requestId}`. When a request document is
created it reads the recipient's `fcmToken` from their `Settings` document and
sends an FCM push titled "New Friend Request".

Deploy it with:

```bash
cd functions
npm install
firebase deploy --only functions
```

`firebase.json` configures the `functions` codebase only — there are no
hosting, Firestore rules, or Storage rules blocks in this repo. Rules are
managed outside of it.

> **Note:** the Flutter app does not depend on `firebase_messaging` and never
> writes `fcmToken`, so this function currently finds no token to send to. See
> [Known gaps](#known-gaps).

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

```bash
flutter test
```

Two suites, both pure Dart — they import no Flutter bindings and no Firebase,
so they run without any emulator or credentials:

- `test/utils_test.dart` — the `Utils` list/map membership helpers, including
  two tests that pin down surprising current behaviour (`containsMap` is
  sensitive to key order, and `containsList` only ever matches `"Movies"`).
- `test/constants_test.dart` — the TMDB key guard and endpoint construction,
  including a regression test that fails if a key is ever hardcoded again.

This is deliberately narrow. The screens and Firebase services have no tests at
all, so treat this as a floor to build on rather than as real coverage.

## Repo tooling

- [`tools/sync-oscars`](tools/sync-oscars/README.md) — a standalone Node 18+
  script (no npm dependencies) that populates the Firestore `Oscars`
  collection from the UrActor API, resolving winners to TMDB ids. It has its
  own README covering name resolution, overrides, and known gaps.

## Known gaps

Things that are true today and worth knowing before you start:

| Gap | Detail |
|---|---|
| The old TMDB key is still in git history | The working tree no longer contains it, but history does. Revoke and reissue the key at TMDB. |
| Push notifications are wired only halfway | The Cloud Function reads `fcmToken` from `Settings`, but the app has no `firebase_messaging` dependency and never writes that field, so the function has nothing to send to. Fixing it needs APNs setup and a device to test on. |
| `firebase_options.dart` is committed | Points at `actordb-cf981`. Re-run `flutterfire configure` for your own project. This is normal for FlutterFire — the values are identifiers, not secrets. |
| iOS Firebase config is incomplete | No `ios/Runner/GoogleService-Info.plist`, and `firebase_options.dart` declares `iosBundleId: 'com.example.uractor'` while Xcode builds `com.uractor.uractorios`. Correcting it requires the real values from the Firebase console. |
| Coverage is thin | Two pure-Dart suites only. See [Tests](#tests). |
| Non-mobile platforms are untested | See [Platforms](#platforms). |
| Non-mobile platforms are untested | See [Platforms](#platforms). |
