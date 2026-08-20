/// Shared test harness.
///
/// Wires the seams in `FirestoreCore` and `AppHttp` to fakes and puts them back
/// afterwards. Every installer registers its own `addTearDown`, because a stub
/// left installed leaks into whatever test runs next and fails it somewhere
/// unrelated, which is painful to trace back.
library;

import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uractor/common/api/http_client.dart';
import 'package:uractor/common/firebase/firestore_core.dart';
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

  /// Registers a response for any URL containing [urlContains].
  ///
  /// Later registrations win for the same substring, which lets a test set up
  /// broad defaults and then override one route.
  void on(
    String urlContains, {
    Object? json,
    String? body,
    int status = 200,
  }) {
    _routes.insert(
      0,
      _Route(
        urlContains,
        status,
        body ?? (json == null ? '' : jsonEncode(json)),
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
      final url = request.url.toString();
      for (final route in _routes) {
        if (url.contains(route.urlContains)) {
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
  _Route(this.urlContains, this.status, this.body);

  final String urlContains;
  final int status;
  final String body;
}

/// Installs [stub] as the client for the current test.
HttpStub installHttpStub([HttpStub? stub]) {
  final active = stub ?? HttpStub();
  AppHttp.client = active.build();
  addTearDown(AppHttp.reset);
  return active;
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
