/// Tests for the on-device side of the media sort cache.
///
/// The file handling is exercised against a real temporary directory rather
/// than a mock, because the things worth checking here are file things: that a
/// missing file reads as nothing rather than throwing, that a delete really
/// removes it, and above all that two accounts get two files.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/media_metadata_store.dart';

void main() {
  late Directory directory;
  late FileMetadataCacheBacking backing;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('media_sort_cache_test');
    backing = FileMetadataCacheBacking(directory: () async => directory);
    addTearDown(() {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
  });

  group('the file backing', () {
    test('reads back what it wrote', () async {
      await backing.write('user-a', '{"version":1}');

      expect(await backing.read('user-a'), '{"version":1}');
    });

    test('reads nothing for a user who has never had a cache', () async {
      expect(await backing.read('nobody'), isNull);
    });

    test('replaces the previous contents rather than appending', () async {
      await backing.write('user-a', 'first');
      await backing.write('user-a', 'second');

      expect(await backing.read('user-a'), 'second');
    });

    test('gives each account its own file', () async {
      await backing.write('user-a', 'account a data');
      await backing.write('user-b', 'account b data');

      // The reason this matters: even if the delete on sign-out never runs,
      // account B is reading a different path.
      expect(await backing.read('user-a'), 'account a data');
      expect(await backing.read('user-b'), 'account b data');
      expect(
        directory.listSync().map((entry) => entry.uri.pathSegments.last).toSet(),
        {'media_sort_cache_user-a.json', 'media_sort_cache_user-b.json'},
      );
    });

    test('deletes one account\'s file without touching another\'s', () async {
      await backing.write('user-a', 'account a data');
      await backing.write('user-b', 'account b data');

      await backing.delete('user-a');

      expect(await backing.read('user-a'), isNull);
      expect(await backing.read('user-b'), 'account b data');
    });

    test('deleting a cache that was never written is not an error', () async {
      await backing.delete('nobody');

      expect(await backing.read('nobody'), isNull);
    });

    test('creates the directory when it is not there yet', () async {
      final missing = Directory('${directory.path}/not-created-yet');
      final fresh = FileMetadataCacheBacking(directory: () async => missing);

      await fresh.write('user-a', 'data');

      expect(await fresh.read('user-a'), 'data');
    });
  });

  group('the store', () {
    setUp(() {
      MediaMetadataStore.backing = backing;
      addTearDown(MediaMetadataStore.reset);
    });

    test('passes reads and writes through to the backing', () async {
      await MediaMetadataStore.write('user-a', 'data');

      expect(await MediaMetadataStore.read('user-a'), 'data');
    });

    test('does nothing at all when nobody is signed in', () async {
      // An empty uid is the gap between sign-out and the next sign-in. There
      // is no account to name a file after, so there is nothing to write.
      await MediaMetadataStore.write('', 'data');
      await MediaMetadataStore.clear('');

      expect(await MediaMetadataStore.read(''), isNull);
      expect(directory.listSync(), isEmpty);
    });

    test('clears a stored cache', () async {
      await MediaMetadataStore.write('user-a', 'data');

      await MediaMetadataStore.clear('user-a');

      expect(await MediaMetadataStore.read('user-a'), isNull);
    });

    test('treats a backing that throws as an empty cache, not as a failure',
        () async {
      // A read-only filesystem or a full disk must cost speed, never
      // correctness: the app simply fetches as it did before this cache
      // existed.
      MediaMetadataStore.backing = _BrokenBacking();

      await MediaMetadataStore.write('user-a', 'data');
      await MediaMetadataStore.clear('user-a');

      expect(await MediaMetadataStore.read('user-a'), isNull);
    });

    test('keeps nothing at all under flutter test, so running the suite cannot '
        'write to the machine running it', () {
      // path_provider reaches the platform through FFI, which a test binding
      // cannot answer -- it hangs a widget test rather than failing it. The
      // default under test is therefore inert, and a test that wants storage
      // installs one, as the tests above do.
      MediaMetadataStore.reset();

      expect(MediaMetadataStore.backing, isA<InertMetadataCacheBacking>());
    });

    test('an inert store reads as empty and swallows writes', () async {
      MediaMetadataStore.backing = const InertMetadataCacheBacking();

      await MediaMetadataStore.write('user-a', 'data');
      await MediaMetadataStore.clear('user-a');

      expect(await MediaMetadataStore.read('user-a'), isNull);
    });
  });
}

class _BrokenBacking implements MetadataCacheBacking {
  @override
  Future<String?> read(String uid) async => throw const FileSystemException();

  @override
  Future<void> write(String uid, String contents) async =>
      throw const FileSystemException();

  @override
  Future<void> delete(String uid) async => throw const FileSystemException();
}
