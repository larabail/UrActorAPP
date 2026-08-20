import 'package:http/http.dart' as http;

/// The single HTTP client every outbound request goes through.
///
/// Calls used to go through the top-level `http.get`, which reaches straight
/// for a real socket. That left no way to exercise the API layer without
/// talking to TMDB and OMDB for real, so the behaviour of these functions was
/// untestable and every run burned quota against a rate limited key.
///
/// Production code keeps using the real client and needs no configuration.
/// Tests assign a stub to [client] and put it back with [reset] afterwards.
class AppHttp {
  static http.Client? _client;

  /// Created on first use rather than eagerly, so a test that swaps the client
  /// in never leaves a real one open behind it.
  static http.Client get client => _client ??= http.Client();

  static set client(http.Client value) {
    _client = value;
  }

  /// Restores the real client. Tests must call this in `tearDown`, otherwise a
  /// stub leaks into whatever runs next and fails it for no visible reason.
  static void reset() {
    _client = null;
  }
}
