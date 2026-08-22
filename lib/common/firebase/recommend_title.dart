import 'dart:convert';

import 'package:http/http.dart' as http;

/// What happened when the user recommended a title to their friends.
enum RecommendTitleOutcome {
  /// Everyone the user ticked received it.
  sent,

  /// It reached some of them; [RecommendTitleResult.skipped] holds the rest.
  partiallySent,

  /// It reached nobody, but the server answered.
  noneSent,

  invalidInput,
  notSignedIn,
  failed,
}

class RecommendTitleResult {
  const RecommendTitleResult(
    this.outcome, {
    this.delivered = 0,
    this.skipped = const [],
  });

  final RecommendTitleOutcome outcome;

  /// How many friends the recommendation actually reached.
  final int delivered;

  /// The uids it did not reach, which is not the same as an error: the server
  /// drops a target who has not listed the caller as a friend rather than
  /// failing the whole call for the others.
  final List<String> skipped;

  bool get isSuccess => outcome == RecommendTitleOutcome.sent;
}

/// Calls the `recommendTitle` Cloud Function.
///
/// The app used to append to the recipient's `Notifications` document itself,
/// with a `sender` assembled on the sending device. Nothing could check that
/// claim, so a friend could file a recommendation in someone's inbox under a
/// third party's name. The server derives the sender from the caller's token
/// now, and verifies the friendship from the recipient's own friends list.
///
/// It also replaces a read-modify-write of the whole document with a
/// transactional append, so two people recommending at the same moment no
/// longer lose one of the two.
///
/// Like [PlaylistJoiner] and [OmdbLookup] this talks to the callable endpoint
/// over plain HTTPS rather than through the `cloud_functions` plugin: the wire
/// format is small and stable, the dependency list stays as it is, and the
/// whole path can be tested with a fake [http.Client] instead of platform
/// channels.
class TitleRecommender {
  const TitleRecommender({this.region = 'us-central1'});

  final String region;

  Uri endpoint(String projectId) =>
      Uri.parse('https://$region-$projectId.cloudfunctions.net/recommendTitle');

  Future<RecommendTitleResult> recommend({
    required http.Client client,
    required String projectId,
    required String idToken,
    required String id,
    required String type,
    required String title,
    required String coverPhoto,
    required List<String> friends,
  }) async {
    try {
      final response = await client.post(
        endpoint(projectId),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          // No `sender`: it is the server's to decide, and sending one would
          // only suggest to the next reader that it is believed.
          'data': {
            'id': id,
            'type': type,
            'title': title,
            'coverPhoto': coverPhoto,
            'friends': friends,
          },
        }),
      );
      return interpretResponse(response.statusCode, response.body);
    } catch (_) {
      // No network, DNS failure, TLS failure. Nothing here is worth showing
      // the user verbatim.
      return const RecommendTitleResult(RecommendTitleOutcome.failed);
    }
  }

  /// Turns a callable response into an outcome.
  ///
  /// Kept separate and pure so every branch can be tested directly. A callable
  /// wraps success in `result` and failure in `error`, with the failure
  /// carrying the `HttpsError` code as `status`.
  static RecommendTitleResult interpretResponse(int statusCode, String body) {
    Map<String, dynamic>? decoded;
    try {
      final parsed = jsonDecode(body);
      if (parsed is Map<String, dynamic>) decoded = parsed;
    } catch (_) {
      decoded = null;
    }

    if (decoded == null) {
      return const RecommendTitleResult(RecommendTitleOutcome.failed);
    }

    if (statusCode == 200) {
      final result = decoded['result'];
      if (result is! Map) {
        return const RecommendTitleResult(RecommendTitleOutcome.failed);
      }

      final delivered = result['delivered'];
      if (delivered is! int) {
        return const RecommendTitleResult(RecommendTitleOutcome.failed);
      }
      final skipped = result['skipped'];
      final skippedUids = skipped is List
          ? skipped.whereType<String>().toList(growable: false)
          : const <String>[];

      return RecommendTitleResult(
        _outcomeFor(delivered, skippedUids.length),
        delivered: delivered,
        skipped: skippedUids,
      );
    }

    final error = decoded['error'];
    final status = error is Map ? error['status'] : null;
    switch (status) {
      case 'INVALID_ARGUMENT':
        return const RecommendTitleResult(RecommendTitleOutcome.invalidInput);
      case 'UNAUTHENTICATED':
        return const RecommendTitleResult(RecommendTitleOutcome.notSignedIn);
      default:
        return const RecommendTitleResult(RecommendTitleOutcome.failed);
    }
  }

  static RecommendTitleOutcome _outcomeFor(int delivered, int skipped) {
    if (delivered == 0) return RecommendTitleOutcome.noneSent;
    if (skipped > 0) return RecommendTitleOutcome.partiallySent;
    return RecommendTitleOutcome.sent;
  }
}
