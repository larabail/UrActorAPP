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
  and every episode up to that point is ticked off. A show you have already
  finished gets those ticks too but keeps its finished status, so the season
  guide reflects the entry without the title leaving the Seen list. An entry
  that names no season still means the whole title was watched, which is what
  every entry meant before episodes were recordable (`lib/calendar.dart`,
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
- See when you watched something. A **show's** viewing history is headed with
  the range it covers: the first day recorded through to the day it was
  finished, or through to the present while it is still being watched. The
  dates come from the calendar, so an account that predates watch progress
  keeps the history it always had. A film has no such heading — it is watched
  in one sitting, so a range would either repeat one day or draw two separate
  rewatches as a single viewing years long; the days themselves are still
  listed (`lib/common/viewing_history_range.dart`,
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
- Keep track of the series you are part way through together. Each friend on the
  friends list carries a scrolling line of the shows that are started,
  unfinished, and recorded as watched with them, and their profile shows the
  same thing as a row of posters naming the next unwatched episode. Films are
  left out, and a friend with nothing running gets no line
  (`lib/friends.dart`, `lib/watching_together_section.dart`,
  `lib/common/watching_together.dart`).

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
- Favourite actors, directors and writers, worked out from what you have
  watched, favourited and rewatched rather than from whose page you happened
  to open. A scheduled Cloud Function walks your library whenever it changes
  and rewrites the three lists, so someone you have never looked up still
  ranks (`functions/people_scores.js`, `lib/profile.dart`).
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
| macOS, Windows | Built by CI on every merge; downloadable from [downloads.uractor.com](https://downloads.uractor.com) once released |
| Linux | Not a target — see below |
| Web | Not a target |

The desktop apps go through the same two pipelines as the mobile ones, but with
no store in the middle: an internal build is an installer attached to the CI run,
and a production release publishes it and updates the downloads site. They tell
users about new versions themselves, because there is no store to do it for
them. See [Releasing the desktop apps](docs/releases.md#releasing-the-desktop-apps).

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

### The downloads site

[downloads.uractor.com](https://downloads.uractor.com) is the whole of
`web/downloads/`, deployed to Firebase Hosting. Three files, no build step:
`index.html` is served exactly as it is committed, `releases.js` decides what
to offer and `page.js` puts it on the page.

It asks the GitHub releases API for the answer when someone opens it, rather
than being generated during a release. A generated page can only describe the
version that was current the last time the release workflow ran, and only that
one: re-tagging a build, deleting a bad release or publishing a hotfix by hand
all left it advertising something untrue with no way to correct it short of
running another release. Reading the API means the page shows what is actually
downloadable, and every earlier version comes along in the same response, so it
can offer those too.

The installers are not hosted here. They are GitHub release assets, because
Firebase Hosting bills per gigabyte past its free tier and these files are over
a hundred megabytes each.

Three things it does that are worth knowing before changing it:

- It leads with the platform the visitor is on, and with neither on a phone —
  an iPhone's user agent says "like Mac OS X", so a careless match offers a
  150MB disk image to a device that cannot open it.
- Each platform falls back to the newest release that actually carries its
  installer. macOS and Windows are built by separate jobs on separate runners,
  so a release can exist with only one of them attached.
- When the API cannot be read — it allows sixty requests an hour per address,
  shared by everyone behind it — the page falls back to `version.json`, which
  is written at release time by
  [`tool/build_download_manifest.py`](tool/build_download_manifest.py) and
  served from the same origin. That covers the current version only, and the
  page says so rather than pretending the older ones do not exist. With both
  gone, every button still leads to the GitHub releases page.

The page is English only, unlike the app. That is a real gap rather than an
oversight: it is a single page of prose with no localization machinery behind
it, and wiring up `.arb` files for a static page is a larger change than adding
Spanish text to it.

Because nothing generates it, it does not need a release to be correct.
`.github/workflows/deploy-downloads.yml` publishes it on any push to `master`
that touches `web/downloads/` or `firebase.json`, and can be run by hand from
the Actions tab. That workflow rebuilds `version.json` before deploying — a
Hosting deploy replaces the whole site, and the manifest is not in the
repository, so deploying a page change without it would delete the file every
running desktop copy polls for updates.

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

### Building macOS needs the Apple Developer team

Unlike Android and Windows, a macOS build is signed with a real identity
rather than ad hoc, and the machine building it has to be registered for a Mac
development profile in team `Q8XY8276AC`.

This is not incidental. Firebase Auth keeps the signed in session in the
keychain, and a sandboxed macOS app is refused the keychain unless it declares
a [`keychain-access-groups`
entitlement](https://firebase.google.com/docs/ios/troubleshooting-faq#macos-keychain-sharing).
That entitlement can only be granted by a real signing identity, so without it
the app builds and runs but **nobody can sign in** — every attempt fails with
`firebase_auth/keychain-error` regardless of the password.

The first build on a new machine fails with "Device … isn't registered in your
developer account". Open `macos/Runner.xcworkspace`, select the Runner target,
go to **Signing & Capabilities** and click **Register Device**.

If you are changing this, three things that look like fixes are not: turning
the sandbox off, signing ad hoc with a team set, and matching the bundle
identifier to the one in `FirebaseOptions`. All three were tried; the keychain
access group is the actual requirement.

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
- **A grid that caps a tile's width still needs a minimum column count.** Use
  `gridColumnsForMaxTileWidth`, which is `gridColumnsFor`'s counterpart for a
  ceiling rather than a target, and never Flutter's
  `SliverGridDelegateWithMaxCrossAxisExtent` on its own. That delegate cannot
  be given a floor, and a ceiling with no floor becomes a *target* on a narrow
  window — one column is always enough to keep every tile under the limit. A
  360pt cap on the home page's playlist cards did exactly that on any phone
  390pt or narrower, turning a two column grid into one column of cards at
  twice the height.
- **Count columns from the box, not from a `LayoutScope` you did not create.**
  Wrap the grid in a `ResponsiveRegion`, which measures the space it is
  actually given, and read the width inside its builder. `LayoutScope.widthOf`
  walks *up* the tree, so calling it from a screen's own `context` misses the
  scope the two pane layout publishes further down and silently falls back to
  the whole window. The playlist grid did this and counted four columns for a
  1210pt iPad while being drawn into a 565pt pane, so every card overflowed.
  The two failures above are the same mistake twice: deciding from a number
  that is not the width of the box.
- **Never size a panel as a fraction of the window's height either.** The rule
  above is usually said about width, but height is where it bites hardest,
  because the app bar and the navigation rail have already taken their share
  before the body sees any of the window. A month grid is as tall as its
  header, its day-of-week strip and however many week rows the month has; a
  row of cards is as tall as a card. Let the content say so — inside a scroll
  view a widget with an intrinsic height needs no box at all, and a
  horizontally scrolling row that has to have one takes it from
  `posterRowHeight`, not from `MediaQuery`. The calendar gave its grid 57% of
  the window and the sheet a day opens 37.5%; the first clipped any month
  needing six week rows, and the second clipped its cards on a short window
  and left a band of empty sheet under them on a tall one.
- **Open detail pages with `openDetail`, not `Navigator.push`.** It puts the
  page in the detail pane when there is one and over the whole window when
  there is not, so a call site does not have to know which layout it is in. A
  plain push still covers the window, which is right for a dialogue and wrong
  for anything a list points at.

`LayoutScope` publishes the width of a *region* rather than the window, so a
list occupying half a wide window sizes its contents to the half it has.
Inside a pane, read the size class from `context.sizeClass`, never from
`MediaQuery`.

### Dialogues

Every popup is an `AppDialog` (`lib/common/widgets/app_dialog.dart`). It owns
the inset, the panel, the scrolling and the action row, so a popup supplies a
title, a body and a list of `AppDialogAction`s and nothing else. Do not build
a `Dialog` or an `AlertDialog` by hand: twelve popups each did, and each
re-derived the same layout slightly differently wrong.

What the shell settles once, so no popup has to:

- **The panel takes the width it is offered**, up to a 560pt ceiling. A
  dialogue whose content never asks for a width sits at the framework's 280pt
  minimum instead, which on a phone throws away a third of the screen.
- **Only the body scrolls.** The title and the buttons are pinned, so a long
  form moves under a heading that stays put and the buttons cannot scroll off.
- **The action row is an `OverflowBar`**, so it stacks when the labels grow
  rather than clipping. That is what makes it safe at a large text scale and
  in a language whose words are longer than English's.
- **The panel is the `Dialog`'s own `Material`.** Painting it with a
  `Container` instead puts the `Material` above the list tiles, and their ink
  splashes have nothing to land on.
- **A busy action spins and stops answering.** Set `busy` on the
  `AppDialogAction` that is running and the shell swaps its icon for a spinner
  and drops its handler, whether or not the caller also nulled it.

**A save that leaves the dialogue open has to say it is running.** Logging a
title is a dozen round trips — the user's calendar, every tagged friend's
calendar, both seen lists, the rewatch counter, the seen-with record, progress
— each waiting on the last. A dialogue that looks untouched for that long reads
as a tap that missed, and the second tap wrote the entry again. Mix
`SingleSubmission` (`lib/common/single_submission.dart`) into the state, call
`submit` instead of `runVisibleAsyncAction`, and drive `busy` and
`dismissible: !submitting` from it. The mixin ignores a call that arrives while
one is already running, so the guard does not depend on the buttons alone;
`dismissible` closes the two ways out that never touch them, the back gesture
and the barrier.

The same rule as tiles applies inside one: **never give a list a fixed
height.** A vertical list should shrink-wrap and let the dialogue scroll —
`FriendPicker` (`lib/common/widgets/friend_picker.dart`) is the shared one, and
it is what the four hardcoded 125pt friend lists became. Only a horizontal
strip needs to be told how tall it is.

`ScrollingLine` (`lib/common/widgets/scrolling_line.dart`) is a one-line label
that scrolls itself when it does not fit and sits still when it does. Use it
where a subtitle has to say more than its width allows and a second row would
push the thing above it around. Note that a scrolling line never stops
animating, so a widget test on a screen containing one must pump fixed
durations rather than call `pumpAndSettle`.

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

CI covers this on macOS runners. The **Build and launch on a simulator** job in
`.github/workflows/pr.yml` builds the app and launches it on a simulator for
every pull request, and the iOS stage of
`.github/workflows/release-internal.yml` ships to TestFlight. Both run on
`macos-26`, because Apple refuses uploads built with an SDK older than iOS 26
and the older image defaults to Xcode 16. The pull request workflow carries no
path filter at all: a check skipped by one is left pending rather than reported,
and a required check that never reports would block the pull request forever.
The iOS job is not required to merge yet, and not filtering it is what makes it
requirable. See [docs/releases.md](docs/releases.md).

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

The same key is also needed **server side**, as a Firebase secret, because
`recomputePeopleScores` fetches credits without a device involved:

```bash
firebase functions:secrets:set TMDB_API_KEY
```

Unlike OMDB this one is genuinely both: the app cannot route every TMDB request
through a function, so the build define stays. Without the secret the function
logs that it is not configured and returns, and the favourite people lists stop
updating while the rest of the app carries on.

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
from OMDB, which needs its own key. Unlike the TMDB and OpenAI keys, this key is
not a Flutter build input and is never compiled into the app. It lives only in
the Cloud Functions environment:

```bash
firebase functions:secrets:set OMDB_API_KEY
```

The app calls the authenticated `omdbLookup` Cloud Function with an IMDb id, and
the function returns only the rating and year the UI consumes. If the user is
signed out or the function cannot reach OMDB, ratings degrade to `0.0` and the
year to `None` rather than blocking the screen.

> This key was committed as a hardcoded `defaultValue` in the source and
> therefore reached every build shipped to Play.
> **A key compiled into an app is extractable by anyone who downloads it**, and
> it remains in git history regardless of the working tree. The replacement key
> must stay in the Firebase secret, not in Dart source or CI build defines.

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
  watching_together_section.dart  "Watching together" row on a friend's profile
  friends.dart  friends_profile.dart  friends_calendar.dart  friends_thoughts.dart
  inbox.dart  notifications.dart
  profile.dart               Profile photo, stats charts

  objects/                   Media, Movie, TVShow, Person, Playlist, User
  common/
    constants.dart           TMDB endpoints; the TMDB key is read from
                             --dart-define
    utils.dart
    continue_watching.dart   Continue watching ordering and TMDB derivations
    watching_together.dart   Which shared shows are still in progress, and how
                             they group under each friend
    item_container.dart  mediaitembuilder.dart  tabView.dart
    watch_progress_view.dart        Pure watch-progress rules
    watch_progress_controller.dart  Per-show episode tick state
    watch_progress_widgets.dart     The season, episode and detail controls
    calendar_progress.dart          What a calendar entry means for tracking
    viewing_history_range.dart      When a title was started and finished
    viewing_history_widgets.dart    The range shown above a show's history
    playlist_grid.dart              The home page's playlist grid, and how many
                                    columns it fits into the space it is given
    api/apiutils.dart        All TMDB HTTP calls; a show's credits come from
                             aggregate_credits and are flattened to the shape
                             /credits returns
    api/tmdb_titles.dart     Cached show-name lookups, for surfaces that want a
                             title and nothing else
    navigation/              appbar.dart, app_scaffold.dart, destinations.dart
    layout/                  breakpoints.dart (pure window-size rules),
                             responsive.dart (LayoutScope, poster helpers),
                             two_pane.dart (list-and-detail, openDetail)
    platform/capabilities.dart  What each platform's plugins can do
    firebase/                One service per domain: calendar, favorites,
                             OMDB lookup, playlist, progress,
                             recommendation, review, social, watched,
                             watchlist, plus firestore_core and firebaseutils
  popups/                    Dialogs: add to calendar, add friends seen with,
                             rating, share, settings, list add/edit/join,
                             grant access, movie add, tv add, profile sections
  l10n/                      app_en.arb, app_es.arb and their generated output

functions/                   Cloud Functions (Node 22): OMDB lookup,
                             playlist join, member sync, join-attempt cleanup
firestore-tests/              Firestore rules tests against the local emulator
tools/sync-oscars/           Firestore Oscars sync job
web/downloads/               downloads.uractor.com: a static page that lists
                             the macOS and Windows installers by reading the
                             GitHub releases API in the browser
assets/                      Logos, tab icons, the cover and person
                             placeholders, oscars_api.json
test/                        Flutter tests
```

## Cloud Functions

`functions/` holds six gen 2 Cloud Functions for project `actordb-cf981`, all
running on Node 22 in `us-central1`:

- `omdbLookup` is a callable function. It requires auth, accepts only a narrow
  IMDb id (`tt` plus digits), calls OMDB with the `OMDB_API_KEY` Firebase
  secret, and returns only `imdbRating`, `Year` and `Response`.
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
- `markPeopleScoresDirty` is a Firestore `onDocumentWritten` trigger on
  `{uid}/{docId}`. Every user owns a top-level collection named after their
  uid, so it has to watch the whole database and filter; a write to one of the
  six library documents sets a flag in `PeopleScoreJobs/{uid}` and everything
  else returns without touching Firestore.
- `recomputePeopleScores` is a scheduled function that runs every five minutes
  and rebuilds `FavActors`, `FavDirectors` and `FavWriters` for the users
  flagged since the last run. See
  [Favourite actors, directors and writers](#favourite-actors-directors-and-writers).

Deploy from `functions/` with the Firebase CLI after authenticating to the
Firebase project:

```bash
npm install
firebase functions:secrets:set OMDB_API_KEY
firebase functions:secrets:set TMDB_API_KEY
npm test
npm run deploy
```

### Favourite actors, directors and writers

The three lists on your profile used to be written by the person page: opening
someone's profile fetched their filmography, intersected it with your library
and saved the score. That made the ranking a record of whose page you had
opened rather than of what you had watched. An actor you never tapped never
appeared however many of their films you had seen, a score you did have stayed
frozen at the moment of that visit, and unfavouriting a film never took the
points back.

`recomputePeopleScores` runs it the other way round, over your own library, so
every person who could rank is reached whether or not anyone ever looked them
up:

1. `markPeopleScoresDirty` flags you when `Movies`, `TVShows`, `Favorites`,
   `Watchlist`, `Rewatched` or `RewatchedTV` changes — including when a friend
   marks something seen for you.
2. Every five minutes the worker takes the oldest flagged users and reads each
   library in one round trip. The flag is cleared only once the scores are
   stored, and only when nothing re-flagged the user in the meantime — so a
   run killed by its timeout leaves the user queued rather than marked done,
   and a write that lands mid-run is picked up next time rather than lost.
3. Each title's cast and crew is resolved through `Credits/{type}_{id}`, a
   cache shared by every user: a title is fetched from TMDB once, ever. Shows
   use `/aggregate_credits`, since `/tv/{id}/credits` only answers for the
   newest season. An id TMDB does not recognise is cached as missing so it is
   not asked about again, and one that keeps failing for some other reason is
   written off on its fifth attempt, in the same run that then scores its
   owner — nothing is stored until every title resolves, so a single broken id
   would otherwise hold a whole library back forever. A rejected key is the one failure never blamed on a title: it
   stops the run and is logged as an error, because it would otherwise write
   off every title in the database.
4. Every title scores as it always did — 2 for having seen it, or the rewatch
   count when higher, 3 more when it is a favourite, 1 when it is only on the
   watchlist — and those points go to everyone the title credits.
5. The three documents are written whole, not merged, so someone who has
   dropped out of your library loses their score instead of keeping the one
   they last had.

A library too large to resolve in one run is not written at all: the run banks
the credits it fetched, leaves you flagged, and the next run finishes from a
warmer cache. A ranking computed from half a library would be wrong rather than
incomplete.

The person page still computes its own score locally, because that is the only
value that accounts for a film marked seen since the worker last ran, and ranks
against the stored lists (`lib/common/people_ranking.dart`). It no longer
writes anything.

Accounts that predate all this have scores from the old person page and no job
record, so `PeopleScoresService` asks for one rebuild the first time such an
account loads (`lib/common/firebase/people_scores_service.dart`). The job
record's existence is the marker, so it happens exactly once per account.

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

The repo has four local suites:

```bash
flutter test

cd functions
npm install
npm test

cd ../firestore-tests
npm install
npm test

cd ..
node --test web/downloads/*.test.js
```

`flutter test` currently runs 847 tests with no emulator, credentials or
network access. Firestore and HTTP are reached through two seams —
`FirestoreCore.db` and `AppHttp.client` — and callable context through
`CallableContext`. They default to the real implementations and are pointed at
fakes by the tests.
`test/support/harness.dart` installs those fakes and restores them afterwards.
The Flutter suite covers pure logic, TMDB/OMDB request parsing with a stubbed
HTTP client, auth/session helpers, search and playlist ordering, playlist join
handling, settings, inbox, calendar/list services, calendar episode detail,
what a calendar entry does to watch progress, viewing history ranges,
in-memory Firestore service behaviour, watch-progress rules and controls, the
media and person data objects, every popup under `lib/popups` except the
profile section editor, the reviews and Continue watching screens, and the
pre-commit hook itself.

`npm test` in `functions/` runs the Node 22 unit tests for the playlist, OMDB
and people-score helper modules. `npm run test:emulator` additionally runs the
end-to-end suite against the Firestore, Functions and Pub/Sub emulators, which
needs a JDK on the PATH. That run stands a stub in front of TMDB and points the
functions at it with `TMDB_API_BASE_URL`, so nothing in CI touches the real,
rate-limited API.

`npm test` in `firestore-tests/` starts the Firestore emulator with
`firebase emulators:exec` and runs the rules suite. It currently reports 84
passing tests. If port 8080 is already held by an emulator you started
separately, run `npx mocha rules.test.js --timeout 20000` from
`firestore-tests/` instead.

`node --test web/downloads/*.test.js` runs the downloads page's release logic — which
installer belongs to which platform, which of two versions is newer, and what
the page falls back to when the GitHub API cannot be reached. No dependencies
and no browser: it uses Node's own test runner against the same module the
page loads.

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

Every pull request to `master` runs `.github/workflows/pr.yml`, which has six
jobs — one to work out what the change touches, and one per thing that can
break:

- **Scope** works out whether anything outside `web/downloads/` changed, and
  the jobs below skip their real work when nothing did. See
  [what a downloads-only change skips](#what-a-downloads-only-change-skips).
- **Analyze, test and build** installs Flutter 3.47.1 plus the pinned Android
  NDK through `.github/actions/setup-flutter-android`, then runs
  `flutter analyze`, `flutter test --coverage`, the coverage floor, and a
  release app bundle build using `TMDB_API_KEY` and `OPENAI_API_KEY` from
  GitHub Actions secrets. Pull request bundles use debug signing and are
  checked to ensure no release signing material is present.
- **Functions** installs Node 22 dependencies in `functions/`, runs `npm test`,
  and confirms `index.js` loads.
- **Downloads site** runs `node --test web/downloads/*.test.js`. The page at
  `downloads.uractor.com` is served exactly as it is committed, so nothing else
  in CI would notice its script breaking.
- **Version** runs the unit tests under `tool/` and then enforces the version
  policy from [AGENTS.md](AGENTS.md#versioning) against the pull request title
  and commits. Do not edit the `+BUILD` suffix: the release pipeline builds
  with a code derived from Play and opens a pull request recording it.
- **Build and launch on a simulator** builds for the iOS simulator on a macOS
  runner, then installs and launches the app and checks it is still running
  fifteen seconds later — because the iOS failure that matters most, Firebase
  failing to configure, happens at launch rather than at compile time. No
  signing: a pull request must never hold the distribution certificate, and the
  branch may come from a fork.

The iOS job used to be a separate workflow, because a macOS build takes around
twenty-five minutes against roughly five on Linux and path filters apply to a
workflow rather than to a job. It runs alongside the Linux jobs now, and the
workflow has **no path filter at all**. A required check skipped by a path
filter is left pending forever rather than reported as passing, so filtering out
Markdown and `docs/` did not save five minutes on a documentation-only pull
request — it made one unmergeable. The iOS check had already dropped its filter
for that reason; the Linux jobs have now followed.

Three of them are **required to merge**: branch protection on `master` waits for
`Analyze, test and build`, `Functions` and `Version`, and nothing else. It
matches them by name, so renaming one silently stops it being required — which
is why none of the names changed when the two workflows were merged.

The iOS job is **not** required yet. Running on every pull request is what makes
it requirable; adding it to the required list is a separate, deliberate step,
and it would make a macOS build the slowest gate on every pull request.

There is no XCTest job. `ios/RunnerTests` still contains only the empty
`testExample` stub that `flutter create` generates, and the app has no native
code beyond an `AppDelegate` that registers plugins, so running it would spend
macOS minutes asserting nothing. If real Swift is ever added to `ios/Runner`,
that is the point to wire `xcodebuild test` into the iOS job.

Xcode Cloud used to archive the app as well, reporting as
`uractorapp | Default | Archive - iOS`, and was removed. It never gated
anything — it was not a required check — and it told us strictly less than the
workflow above: no analyze, no tests, and no launch check, which is the iOS
failure that matters most. On `master` it rebuilt what
`release-testflight.yml` already builds and then discarded the archive, because
its distribution was set to None. Every failure it ever reported was about its
own configuration rather than the app.

If it is ever reconnected, note that it runs `xcodebuild` on a bare clone and
knows nothing about Flutter, so it needs a `ios/ci_scripts/ci_post_clone.sh` to
install the SDK, write `ios/Flutter/Generated.xcconfig` and install the pods —
none of which are committed. There was one; `git log -- ios/ci_scripts` has it.
Two things that cost a day the first time: the workflow must point at
`Runner.xcworkspace` and not `Runner.xcodeproj`, or the pods never enter the
build graph and every plugin module comes back not found, and CocoaPods has to
be installed before `flutter build --config-only`, which runs `pod install`
itself.

Every merge to `master` that is not docs-only runs
`.github/workflows/release-internal.yml`, the one pipeline that puts a build in
front of testers on all three platforms. It analyzes and tests once, on Linux,
then deploys Cloud Functions to `actordb-cf981`, and only then starts the three
platform stages:

1. **Android** builds a signed app bundle with a Play-derived version code,
   generates release notes and uploads to Play internal testing.
2. **iOS** builds a signed IPA on a macOS runner and uploads it to TestFlight.
   Its build number comes from App Store Connect through `tool/appstore.py`, the
   counterpart to `tool/play.py`, and is deliberately **not** written back to
   `pubspec.yaml`: the `+BUILD` suffix there records Play's version code, and the
   two stores count independently.
3. **Desktop** builds the macOS and Windows installers, signing and notarising
   the macOS one, and attaches them to the run. Nothing is published and
   `downloads.uractor.com` is untouched — desktop has no test track, so "not
   published" is what internal testing means for it.

The numbering is the order they are reported in, not the order they run in: all
three start together, so a release costs roughly twenty-five minutes rather than
the fifty-five they would add up to. A stage whose secrets are missing is
skipped rather than failed, and the run summary states which platforms shipped.

Internal builds are not tagged; that summary records the version code and the
commit, which is what a production promotion is given. Production is a separate,
manual pipeline. See [docs/releases.md](docs/releases.md).

`.github/workflows/deploy-downloads.yml` publishes
[the downloads site](#the-downloads-site) on any push to `master` touching
`web/downloads/` or `firebase.json`, and can be run by hand from the Actions
tab. It is separate from the release pipelines because the page is static and
has nothing to do with a release, and because it was previously deployable only
by running a full production release — which also tags, publishes a GitHub
release and ships to both stores. It creates the Hosting site if it is missing,
and rebuilds `version.json` before deploying, since a Hosting deploy replaces
the whole site and that file is not in the repository.

Once the Android upload succeeds, a last job records the version code that
shipped in `pubspec.yaml`, so the `+BUILD` suffix in the repository matches the
newest build on the internal track. It arrives as a pull request from
`github-actions[bot]` rather than as a direct commit: `master` requires a pull
request, and the GitHub Actions identity cannot be granted an exception to that
on a user-owned repository. Approve and merge it like any other — it is one
line, there is at most one open at a time, and each release rewrites it. Its
checks do not start on their own, because GitHub does not trigger workflow runs
for a pull request opened with the built-in `GITHUB_TOKEN`; close and reopen it,
or use the administrator override. If the pull request cannot be opened at all,
the run says so in its summary and still passes: the app is already on Play by
then, and failing would report a shipped release as a broken one. See
[docs/releases.md](docs/releases.md#version-codes).

### What a downloads-only change skips

`web/downloads/` is a static site served by Firebase Hosting. No Flutter build
reads it and no release packages it, so a change confined to it cannot alter
what any app does. Four things follow, and each is arranged differently for a
reason worth knowing before changing any of them.

| | On a downloads-only change |
| --- | --- |
| `pr.yml` — Analyze, test and build | runs, skips its steps, reports |
| `pr.yml` — Functions | runs, skips its steps, reports |
| `pr.yml` — Build and launch on a simulator | skipped whole |
| `release-internal.yml` | does not run: no build reaches testers |
| `tool/check_version_bump.py` | requires no version bump |

The two required jobs are gated **step by step** rather than by a path filter
on the workflow. This is not fussiness. A workflow skipped by `paths-ignore`
reports nothing at all, and a required check that never reports leaves the
pull request permanently unmergeable — the same trap that took the path filter
off the iOS workflow. Gated by step, the job still runs and still reports; it
just has nothing to do. The iOS job is skipped whole instead, by a condition on
the job rather than on the workflow, because a skipped job does report a
conclusion and because starting a macOS runner to skip everything on it wastes
the scarcest runner there is.

`release-internal.yml` is the one place a plain path filter is safe: it runs
after the merge and is nobody's required check. Without it, editing a sentence
on a web page would put a build in front of every internal tester under a new
version number containing nothing they could find.

The version exemption is by path, not by kind. A change to a public web page is
honestly a `feat` or a `fix`, so the kind alone would demand a minor bump the
app has no reason to make. `tool/check_version_bump.py` therefore drops the
requirement when nothing outside `web/downloads/` changed. Bumping anyway is
still allowed; a version that moves backwards, or a minor bump that leaves the
patch number behind, is still refused.

## Repo tooling

- [`tool/play.py`](tool/play.py) — Google Play release helper used by the
  release workflows and runnable by hand. See [Releasing](docs/releases.md).
- [`tool/generate_desktop_icons.py`](tool/generate_desktop_icons.py) — derives
  the macOS and Windows app icons from the iOS one. `flutter create` writes a
  Flutter logo into `macos/` and `windows/` and nothing replaces it, so both
  desktop builds shipped with the toolchain placeholder until this existed. Run
  it after changing the iOS icon; it needs `pip3 install --user Pillow` and is
  deliberately not wired into CI, because the icons it produces are committed.
- [`tool/build_download_manifest.py`](tool/build_download_manifest.py) — writes
  `web/downloads/version.json` during a production release. That file is what a
  running desktop copy polls to discover it is out of date, and what the
  downloads page falls back to when the GitHub API is rate limited. It does not
  generate the page; see [the downloads site](#the-downloads-site).
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
  before a commit. Enable it with `git config core.hooksPath .githooks`. It
  clears git's own environment variables before invoking flutter, for the
  reason [`test/pre_commit_hook_test.dart`](test/pre_commit_hook_test.dart)
  spells out.

## Licence

UrActor is **source-available, not open source**. The code is published so it
can be read and audited; reading it grants no right to ship it. Reuse beyond
quoting and evaluation needs written permission. See [LICENSE](LICENSE).

Security reports go through [SECURITY.md](SECURITY.md), privately — not through
a public issue.

## Contributing

[AGENTS.md](AGENTS.md) is the working agreement: no commits on `master`, tests
with new code, both `.arb` files when strings change, and the commit and pull
request conventions. Read it before opening a pull request.

Outside pull requests are not being taken. The repository is public to be read,
and every change still goes through review by the owner.

## Known gaps

Things that are true today and worth knowing before you start:

| Gap | Detail |
|---|---|
| Push notifications are not implemented | The old notification function was removed because the app never registered FCM tokens and its legacy FCM API would no longer send. A future implementation needs `firebase_messaging`, token persistence, current FCM sends, APNs setup, and device testing. |
| iOS Firebase config is partial | There is no `ios/Runner/GoogleService-Info.plist`, and `firebase_options.dart` declares `iosBundleId: 'com.example.uractor'` while Xcode builds `com.uractor.uractorios`. Neither stops an iOS build or a sign in, because Firebase is configured from Dart, but APNs, `firebase_messaging` and App Check would all need the plist. |
| iOS is not released to the App Store automatically | Stage 2 of `.github/workflows/release-production.yml` submits a version for review and, as a second deliberate run, releases it once Apple approves. Neither happens on merge: Apple reviews every version by hand, so there is no equivalent of Play's promote-and-it-is-live. The version record is created by the pipeline and its release notes written from the commits, but a changed description, new screenshots or an app's first release still want a person in App Store Connect. |
| Coverage is uneven | The API layer, the data objects and the popups are covered; the full screens under `lib/` still have very few widget tests. See [Tests](#tests). |
| A friend's watch progress cannot be set from your device | Tagging a friend on a calendar entry writes to their calendar and seen-with records, but `firestore.rules` lets a client write its own `Progress` document and nobody else's. So an entry naming an episode no longer marks the show fully seen for them — which would be a lie — but it cannot record them as part way through it either, and the show reads as not started on their side until they log it themselves. Closing this needs the write to move behind a Cloud Function. |
