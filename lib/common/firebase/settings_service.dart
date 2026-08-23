import '../../main.dart';
import 'firestore_core.dart';

/// Whether logging an episode also records every episode before it.
///
/// Stored rather than assumed because both answers are right for someone: a
/// viewer working through a show from the start means "and everything before
/// this", while one who joined a long-running series at its current run does
/// not, and filling in seasons they never watched invents a history for them.
/// Absent for every account created before the setting existed, so it reads as
/// on — which is the behaviour those accounts already had.
const String settingFillEpisodesBefore = 'fillEpisodesBefore';

/// Reads and writes the signed-in user's Settings document.
class SettingsService {
  /// Stores [value] under [key] and merges it into the settings document.
  /// @param key The setting name.
  /// @param value The new value.
  static Future<void> update(String key, dynamic value) async {
    currentUser.settings[key] = value;
    final userDoc =
        FirestoreCore.db.collection(currentUser.uid).doc("Settings");
    await FirestoreCore.mergeInto(userDoc, {key: value});
  }

  /// Reads [key], returning [fallback] when it has never been set.
  /// @param key The setting name.
  /// @param fallback The value to use when absent.
  /// @return The stored value, or [fallback].
  static T read<T>(String key, T fallback) {
    final value = currentUser.settings[key];
    return value is T ? value : fallback;
  }
}
