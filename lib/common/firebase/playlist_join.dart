import 'dart:convert';

import 'package:http/http.dart' as http;

/// What happened when the user tried to join a playlist by access code.
enum JoinPlaylistOutcome {
  joined,
  alreadyMember,
  notFound,
  tooManyAttempts,
  invalidInput,
  notSignedIn,
  failed,
}

class JoinPlaylistResult {
  const JoinPlaylistResult(this.outcome, {this.playlistId});

  final JoinPlaylistOutcome outcome;
  final String? playlistId;

  bool get isSuccess =>
      outcome == JoinPlaylistOutcome.joined ||
      outcome == JoinPlaylistOutcome.alreadyMember;
}

/// Calls the `joinPlaylist` Cloud Function.
///
/// The app used to join a list itself: download every document in Watchlists,
/// compare the access code on the device, then write itself into the list.
/// That handed every access code to every signed-in user. Here the code is
/// only ever sent to the server, which answers yes or no.
///
/// This talks to the callable endpoint over plain HTTPS rather than through
/// the `cloud_functions` plugin. The wire format is small and stable, it keeps
/// the dependency list unchanged, and it means the whole path can be tested
/// with a fake [http.Client] instead of platform channels.
class PlaylistJoiner {
  const PlaylistJoiner({this.region = 'us-central1'});

  final String region;

  Uri endpoint(String projectId) =>
      Uri.parse('https://$region-$projectId.cloudfunctions.net/joinPlaylist');

  Future<JoinPlaylistResult> join({
    required http.Client client,
    required String projectId,
    required String idToken,
    required String name,
    required String accessCode,
  }) async {
    try {
      final response = await client.post(
        endpoint(projectId),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'data': {'name': name, 'accessCode': accessCode},
        }),
      );
      return interpretResponse(response.statusCode, response.body);
    } catch (_) {
      // No network, DNS failure, TLS failure. Nothing here is worth showing
      // the user verbatim.
      return const JoinPlaylistResult(JoinPlaylistOutcome.failed);
    }
  }

  /// Turns a callable response into an outcome.
  ///
  /// Kept separate and pure so every branch can be tested directly. A callable
  /// wraps success in `result` and failure in `error`, with the failure
  /// carrying the `HttpsError` code as `status`.
  static JoinPlaylistResult interpretResponse(int statusCode, String body) {
    Map<String, dynamic>? decoded;
    try {
      final parsed = jsonDecode(body);
      if (parsed is Map<String, dynamic>) decoded = parsed;
    } catch (_) {
      decoded = null;
    }

    if (decoded == null) {
      return const JoinPlaylistResult(JoinPlaylistOutcome.failed);
    }

    if (statusCode == 200) {
      final result = decoded['result'];
      if (result is! Map) {
        return const JoinPlaylistResult(JoinPlaylistOutcome.failed);
      }
      final id = result['id'];
      final already = result['alreadyMember'] == true;
      return JoinPlaylistResult(
        already
            ? JoinPlaylistOutcome.alreadyMember
            : JoinPlaylistOutcome.joined,
        playlistId: id is String ? id : null,
      );
    }

    final error = decoded['error'];
    final status = error is Map ? error['status'] : null;
    switch (status) {
      case 'NOT_FOUND':
        return const JoinPlaylistResult(JoinPlaylistOutcome.notFound);
      case 'RESOURCE_EXHAUSTED':
        return const JoinPlaylistResult(JoinPlaylistOutcome.tooManyAttempts);
      case 'INVALID_ARGUMENT':
        return const JoinPlaylistResult(JoinPlaylistOutcome.invalidInput);
      case 'UNAUTHENTICATED':
        return const JoinPlaylistResult(JoinPlaylistOutcome.notSignedIn);
      default:
        return const JoinPlaylistResult(JoinPlaylistOutcome.failed);
    }
  }
}
