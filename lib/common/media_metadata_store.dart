import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Where a media metadata cache is kept.
///
/// Split out from [MediaMetadataStore] so the store's rules -- which file, when
/// to give up, what a missing file means -- can be tested without touching a
/// real disk. Production uses [FileMetadataCacheBacking]; tests install an
/// in-memory one, the same arrangement `AppHttp.client` and `FirestoreCore.db`
/// already use.
abstract class MetadataCacheBacking {
  /// The stored contents for [uid], or null if nothing is stored.
  Future<String?> read(String uid);

  /// Replaces the stored contents for [uid].
  Future<void> write(String uid, String contents);

  /// Removes anything stored for [uid].
  Future<void> delete(String uid);
}

/// Keeps each user's cache in its own JSON file in the app support directory.
class FileMetadataCacheBacking implements MetadataCacheBacking {
  /// [directory] resolves where the files live, and defaults to the platform's
  /// app support directory. It is injectable so the file handling here -- the
  /// naming, the missing-file case, the delete -- can be exercised against a
  /// temporary directory, rather than being the one part of this that only
  /// runs on a device.
  FileMetadataCacheBacking({Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;

  @override
  Future<String?> read(String uid) async {
    final file = await _fileFor(uid);
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  @override
  Future<void> write(String uid, String contents) async {
    final file = await _fileFor(uid);
    await file.parent.create(recursive: true);
    await file.writeAsString(contents, flush: true);
  }

  @override
  Future<void> delete(String uid) async {
    final file = await _fileFor(uid);
    if (await file.exists()) await file.delete();
  }

  /// One file per user. Sign-out deletes it, but naming it after the account
  /// means a file left behind by a crash or a failed delete still cannot be
  /// read as the next account's.
  Future<File> _fileFor(String uid) async {
    final directory = await _directory();
    return File('${directory.path}/media_sort_cache_$uid.json');
  }
}

/// A store that keeps nothing, used under `flutter test` so that running the
/// suite never writes to the machine running it. Behaves exactly like a device
/// whose cache is empty and whose disk refuses writes, which the app already
/// has to cope with.
class InertMetadataCacheBacking implements MetadataCacheBacking {
  const InertMetadataCacheBacking();

  @override
  Future<String?> read(String uid) async => null;

  @override
  Future<void> write(String uid, String contents) async {}

  @override
  Future<void> delete(String uid) async {}
}

/// Reads and writes the on-device media sort metadata cache.
///
/// Two things are worth knowing about this class.
///
/// **The file is named after the user.** Sign-out deletes it, but naming it per
/// uid means a file left behind by a crash, a kill, or a failed delete still
/// cannot be read by the next account to sign in. Combined with the fact that
/// nothing user-specific is written in the first place -- see
/// `media_metadata_cache.dart` -- there is no path by which one account sees
/// another's data.
///
/// **Every operation fails soft.** An unavailable directory, an unreadable
/// file, a full disk: all of them leave the app working from the network
/// exactly as it did before this cache existed. A cache that cannot be written
/// must never break sorting, which would trade a slow grid for a broken one.
/// It also means a plain unit test, which has no platform channel to answer
/// `getApplicationSupportDirectory`, degrades quietly instead of throwing.
class MediaMetadataStore {
  static MetadataCacheBacking? _backing;

  /// Resolved on first use so a test can install a fake before anything
  /// reaches for a real directory.
  static MetadataCacheBacking get backing => _backing ??= _defaultBacking();

  static set backing(MetadataCacheBacking value) => _backing = value;

  /// Restores the default store. Tests must call this in teardown, or a fake
  /// leaks into whatever runs next.
  static void reset() => _backing = null;

  /// The file store on a device, and nothing at all under `flutter test`.
  ///
  /// `path_provider` reaches the platform through FFI rather than a method
  /// channel, and a test binding cannot answer it: outside a widget test it
  /// throws `Binding has not yet been initialized`, and inside one it hangs
  /// the run instead of failing it, which is a genuinely nasty thing to
  /// inherit. Nothing in the suite should be writing to the machine running it
  /// anyway. A test that wants to exercise storage installs a backing of its
  /// own -- see `installMemoryMetadataStore` in the harness, or construct a
  /// [FileMetadataCacheBacking] against a temporary directory.
  static MetadataCacheBacking _defaultBacking() =>
      Platform.environment.containsKey('FLUTTER_TEST')
          ? const InertMetadataCacheBacking()
          : FileMetadataCacheBacking();

  /// The stored contents for [uid], or null when there is nothing to read or
  /// it could not be read.
  ///
  /// An empty [uid] means nobody is signed in, which happens between sign-out
  /// and the next sign-in; there is no file to name, so nothing is read.
  /// @param uid The signed-in user.
  /// @return The raw stored contents, if any.
  static Future<String?> read(String uid) async {
    if (uid.isEmpty) return null;
    try {
      return await backing.read(uid);
    } catch (_) {
      return null;
    }
  }

  /// Stores [contents] for [uid], doing nothing if it cannot be written.
  /// @param uid The signed-in user.
  /// @param contents The raw contents to store.
  static Future<void> write(String uid, String contents) async {
    if (uid.isEmpty) return;
    try {
      await backing.write(uid, contents);
    } catch (_) {
      // Losing the cache costs speed on the next start and nothing else.
    }
  }

  /// Deletes [uid]'s stored cache. Called when the signed-in user changes.
  /// @param uid The user whose cache should be forgotten.
  static Future<void> clear(String uid) async {
    if (uid.isEmpty) return;
    try {
      await backing.delete(uid);
    } catch (_) {
      // Nothing user-specific is stored and the file is named per uid, so a
      // delete that fails cannot expose one account's data to another.
    }
  }
}
