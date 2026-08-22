import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/api/tmdb_titles.dart';

import '../support/harness.dart';

void main() {
  late HttpStub http;

  setUp(() {
    http = installHttpStub();
    TmdbTitles.clearCache();
    addTearDown(TmdbTitles.clearCache);
  });

  test('names the shows it was asked about', () async {
    http.on('/3/tv/1399', json: {'id': 1399, 'name': 'Severance'});
    http.on('/3/tv/66732', json: {'id': 66732, 'name': 'Stranger Things'});

    final titles = await TmdbTitles.forShows(['1399', '66732']);

    expect(titles, {'1399': 'Severance', '66732': 'Stranger Things'});
  });

  test('leaves out an id TMDB no longer resolves', () async {
    // Absent rather than a placeholder, so a caller can tell "TMDB has no name
    // for this" from "TMDB says it is called this".
    http.on('/3/tv/404', status: 404, body: '');

    final titles = await TmdbTitles.forShows(['404']);

    expect(titles, isEmpty);
  });

  test('leaves out a payload that is not a show', () async {
    http.on('/3/tv/1', body: 'not json at all');

    final titles = await TmdbTitles.forShows(['1']);

    expect(titles, isEmpty);
  });

  test('leaves out a show whose name is blank', () async {
    http.on('/3/tv/1', json: {'id': 1, 'name': '   '});

    final titles = await TmdbTitles.forShows(['1']);

    expect(titles, isEmpty);
  });

  test('leaves out a show with no name field', () async {
    http.on('/3/tv/1', json: {'id': 1});

    final titles = await TmdbTitles.forShows(['1']);

    expect(titles, isEmpty);
  });

  test('asks about a repeated id once', () async {
    http.on('/3/tv/1399', json: {'id': 1399, 'name': 'Severance'});

    await TmdbTitles.forShows(['1399', '1399', '1399']);

    expect(http.countFor('/3/tv/1399'), 1);
  });

  test('remembers an answer across calls', () async {
    // A show's name does not change between two visits to the friends page.
    http.on('/3/tv/1399', json: {'id': 1399, 'name': 'Severance'});

    await TmdbTitles.forShows(['1399']);
    final titles = await TmdbTitles.forShows(['1399']);

    expect(titles, {'1399': 'Severance'});
    expect(http.countFor('/3/tv/1399'), 1);
  });

  test('remembers a failure too, rather than retrying it every build',
      () async {
    http.on('/3/tv/404', status: 404, body: '');

    await TmdbTitles.forShows(['404']);
    final titles = await TmdbTitles.forShows(['404']);

    expect(titles, isEmpty);
    expect(http.countFor('/3/tv/404'), 1);
  });

  test('one unresolvable id does not cost the others their names', () async {
    http.on('/3/tv/1399', json: {'id': 1399, 'name': 'Severance'});
    http.on('/3/tv/404', status: 500, body: '');

    final titles = await TmdbTitles.forShows(['1399', '404']);

    expect(titles, {'1399': 'Severance'});
  });

  test('nothing asked is nothing fetched', () async {
    final titles = await TmdbTitles.forShows(const <String>[]);

    expect(titles, isEmpty);
    expect(http.requests, isEmpty);
  });
}
