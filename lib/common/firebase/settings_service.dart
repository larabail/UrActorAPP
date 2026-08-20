
import '../../main.dart';
import 'firestore_core.dart';

/// Reads and writes the signed-in user's Settings document.
///
/// The settings document is written as a whole rather than patched, matching
/// how the settings dialog has always saved it, so the in-memory copy on
/// [currentUser] is kept in step before every write.
class SettingsService {
  /// Stores [value] under [key] and persists the settings document.
  /// @param key The setting name.
  /// @param value The new value.
  static Future<void> update(String key, dynamic value) async {
    currentUser.settings[key] = value;
    await FirestoreCore.db
        .collection(currentUser.uid)
        .doc("Settings")
        .set(Map<String, dynamic>.from(currentUser.settings));
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
