/// Shared test harness.
///
/// Wires the seams in `FirestoreCore` and `AppHttp` to fakes and puts them back
/// afterwards. Every installer registers its own `addTearDown`, because a stub
/// left installed leaks into whatever test runs next and fails it somewhere
/// unrelated, which is painful to trace back.
library;

import 'dart:convert';
import 'dart:ui' show Size;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show NetworkImageLoadException;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uractor/common/api/http_client.dart';
import 'package:uractor/common/firebase/callable_context.dart';
import 'package:uractor/common/firebase/firestore_core.dart';
import 'package:uractor/common/media_metadata_store.dart';
import 'package:uractor/common/media_sort_loader.dart';
import 'package:uractor/main.dart' as app;
import 'package:uractor/objects/user.dart';

/// Points every service at an in-memory Firestore for the current test.
FakeFirebaseFirestore installFakeFirestore() {
  final firestore = FakeFirebaseFirestore();
  FirestoreCore.db = firestore;
  addTearDown(FirestoreCore.resetDb);
  return firestore;
}

/// Installs [currentUser] with empty collections, since almost everything in
/// the app reads that global and it is `late`, so touching it unset throws.
AppUser installTestUser({
  String uid = 'test-uid',
  String userName = 'Tester',
  String country = 'US',
  Map<String, dynamic> settings = const {'language': 'en'},
}) {
  final user = AppUser(uid: uid, userName: userName, country: country);
  user.settings = Map<String, dynamic>.from(settings);
  app.currentUser = user;
  return user;
}

/// Declarative HTTP stub.
///
/// Routes match on a substring of the request URL rather than the whole thing,
/// because the real URLs are built from constants with API keys and language
/// parameters appended, and pinning the exact string would make these tests
/// break on unrelated changes.
class HttpStub {
  final List<_Route> _routes = [];

  /// Every URL requested, in order, so a test can assert on what was called
  /// and how many times without the stub having to predict it.
  final List<Uri> requests = [];
  final List<String> requestBodies = [];

  /// Registers a response for any URL containing [urlContains].
  ///
  /// Later registrations win for the same substring, which lets a test set up
  /// broad defaults and then override one route.
  ///
  /// [delay] holds the response back for that long on the fake clock, which is
  /// how a test gets to look at the app while a request is still in flight --
  /// spinners, disabled buttons, and anything else that only exists between
  /// the tap and the answer.
  void on(
    String urlContains, {
    Object? json,
    String? body,
    int status = 200,
    Duration delay = Duration.zero,
  }) {
    _routes.insert(
      0,
      _Route(
        urlContains,
        status,
        body ?? (json == null ? '' : jsonEncode(json)),
        delay,
      ),
    );
  }

  /// How many requests were made to URLs containing [urlContains]. Used to
  /// prove caching and deduplication actually avoid repeat calls.
  int countFor(String urlContains) =>
      requests.where((uri) => uri.toString().contains(urlContains)).length;

  http.Client build() {
    return MockClient((request) async {
      requests.add(request.url);
      requestBodies.add(request.body);
      final url = request.url.toString();
      for (final route in _routes) {
        if (url.contains(route.urlContains)) {
          if (route.delay > Duration.zero) {
            await Future<void>.delayed(route.delay);
          }
          return http.Response(
            route.body,
            route.status,
            // TMDB responses are UTF-8, and without declaring it here accented
            // titles come back mojibaked and comparisons fail confusingly.
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
      }
      // An unmatched request is a bug in the test, not a 404 to be handled: it
      // means production code called something the test did not expect.
      throw StateError('Unstubbed request: $url');
    });
  }
}

class _Route {
  _Route(this.urlContains, this.status, this.body, this.delay);

  final String urlContains;
  final int status;
  final String body;
  final Duration delay;
}

/// Installs [stub] as the client for the current test.
HttpStub installHttpStub([HttpStub? stub]) {
  final active = stub ?? HttpStub();
  AppHttp.client = active.build();
  addTearDown(AppHttp.reset);
  return active;
}

/// Keeps the media sort metadata cache in memory for the current test.
///
/// The real store writes a file through `path_provider`, which has no platform
/// channel to answer in a unit test. This stands in for it and, unlike the
/// real one, can be inspected: [MemoryMetadataCacheBacking.files] is what
/// would be on disk, which is how a test proves an account's cache is really
/// gone after sign-out rather than merely absent from memory.
///
/// Also clears the loader itself, in memory and in the fake store, because a
/// cache surviving into the next test would answer requests that test expected
/// to make.
MemoryMetadataCacheBacking installMemoryMetadataStore() {
  final backing = MemoryMetadataCacheBacking();
  MediaMetadataStore.backing = backing;
  addTearDown(() async {
    await MediaSortLoader.clearCache();
    MediaMetadataStore.reset();
  });
  return backing;
}

/// An in-memory stand-in for the on-device metadata cache.
class MemoryMetadataCacheBacking implements MetadataCacheBacking {
  /// The stored contents, keyed by uid, standing in for one file each.
  final Map<String, String> files = <String, String>{};

  /// Every read, write and delete, so a test can assert a write happened at
  /// all rather than only that the contents ended up right.
  final List<String> operations = <String>[];

  /// Makes the next operation of each kind fail, for testing that a cache
  /// which cannot be reached degrades to the network instead of breaking.
  bool failReads = false;
  bool failWrites = false;

  @override
  Future<String?> read(String uid) async {
    operations.add('read:$uid');
    if (failReads) throw StateError('read failed');
    return files[uid];
  }

  @override
  Future<void> write(String uid, String contents) async {
    operations.add('write:$uid');
    if (failWrites) throw StateError('write failed');
    files[uid] = contents;
  }

  @override
  Future<void> delete(String uid) async {
    operations.add('delete:$uid');
    files.remove(uid);
  }

  /// How many writes landed for [uid], to prove the debounce coalesces them.
  int writeCountFor(String uid) =>
      operations.where((entry) => entry == 'write:$uid').length;
}

/// Points callable wrappers at a fake Firebase project and signed-in user.
void installFakeCallableContext({
  String projectId = 'test-project',
  String? idToken = 'test-token',
}) {
  CallableContext.projectId = () => projectId;
  CallableContext.idToken = () async => idToken;
  addTearDown(CallableContext.reset);
}

/// Gives the current test a phone-shaped window.
///
/// The default test surface is 800x600 -- wider than it is tall. Several
/// popups size a column from the screen width and then stack it vertically,
/// so on a landscape surface they overflow and the framework reports that as
/// an error before a single assertion runs. A portrait window is both closer
/// to the device the app ships on and tall enough to lay the dialogue out.
void usePhoneSurface(WidgetTester tester, {Size size = const Size(400, 900)}) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Stops a failed network image from failing the current test.
///
/// A widget test has no network: every request is answered with a 400, and
/// `Image.network` reports that as an error. Popups that show a streaming
/// logo or a friend's avatar hit it on every run and it says nothing about
/// the popup, whose text and behaviour are what is under test here.
void ignoreNetworkImageFailures() => _ignoreFlutterErrors(
    (details) => details.exception is NetworkImageLoadException);

/// Drops framework errors [matches] accepts for the rest of the current test.
/// Everything else still reaches the binding and still fails the test.
void _ignoreFlutterErrors(bool Function(FlutterErrorDetails) matches) {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (matches(details)) return;
    previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);
}

/// Seeds a document under a user's collection. The app stores each area of a
/// user's data as a named document inside a collection named after their uid.
Future<void> seedUserDoc(
  FakeFirebaseFirestore firestore,
  String uid,
  String docName,
  Map<String, dynamic> data,
) async {
  await firestore.collection(uid).doc(docName).set(data);
}

/// The documents `AppUser.getFirebaseData` expects to exist. It reads several
/// of them without a null check, so a partial seed throws rather than degrading.
Future<void> seedCompleteUser(
  FakeFirebaseFirestore firestore,
  String uid, {
  Map<String, dynamic>? overrides,
}) async {
  final docs = <String, Map<String, dynamic>>{
    'Country': {'Country': 'US'},
    'Calendar': <String, dynamic>{},
    'FavActors': <String, dynamic>{},
    'FavDirectors': <String, dynamic>{},
    'FavWriters': <String, dynamic>{},
    'Favorites': {'Movies': [], 'TVShows': []},
    'Movies': {'Movies': []},
    'TVShows': {'TVShows': []},
    'Watchlist': {'Movies': [], 'TVShows': []},
    'Seen': {'Movies': [], 'TVShows': []},
    'SeenWith': {'Movies': <String, dynamic>{}, 'TVShows': <String, dynamic>{}},
    'Settings': {'language': 'en', 'dontAskCalendar': false},
    'Reviews': {'Movies': [], 'TVShows': []},
    'Rewatched': <String, dynamic>{},
    'RewatchedTV': <String, dynamic>{},
    'Friends': {'friends': []},
    'Notifications': <String, dynamic>{},
    'Recommendations': {'Movies': [], 'TVShows': []},
    'Progress': {'Movies': <String, dynamic>{}, 'TVShows': <String, dynamic>{}},
  };
  if (overrides != null) {
    overrides.forEach((key, value) {
      docs[key] = Map<String, dynamic>.from(value as Map);
    });
  }
  for (final entry in docs.entries) {
    await seedUserDoc(firestore, uid, entry.key, entry.value);
  }
}
