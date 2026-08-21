import 'dart:convert';

import 'package:http/http.dart' as http;

enum OmdbLookupOutcome {
  found,
  notFound,
  invalidInput,
  notSignedIn,
  unavailable,
  failed,
}

class OmdbLookupResult {
  const OmdbLookupResult(this.outcome, {this.data = const {}});

  final OmdbLookupOutcome outcome;
  final Map<String, dynamic> data;

  bool get isSuccess => outcome == OmdbLookupOutcome.found;
}

/// Calls the `omdbLookup` Cloud Function.
///
/// The app used to call OMDB directly with a build-time API key, which put that
/// key in every shipped app binary. The callable keeps the key server-side and
/// returns only the rating and year the app reads.
///
/// This uses the callable HTTPS endpoint directly rather than the
/// `cloud_functions` plugin. The wire format is small and stable, keeps the
/// dependency list unchanged, and lets tests cover the full path with a fake
/// [http.Client] instead of platform channels.
class OmdbLookup {
  const OmdbLookup({this.region = 'us-central1'});

  final String region;

  Uri endpoint(String projectId) =>
      Uri.parse('https://$region-$projectId.cloudfunctions.net/omdbLookup');

  Future<OmdbLookupResult> lookup({
    required http.Client client,
    required String projectId,
    required String idToken,
    required String imdbId,
  }) async {
    try {
      final response = await client.post(
        endpoint(projectId),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'data': {'imdbId': imdbId},
        }),
      );
      return interpretResponse(response.statusCode, response.body);
    } catch (_) {
      return const OmdbLookupResult(OmdbLookupOutcome.failed);
    }
  }

  /// Turns a callable response into an outcome.
  ///
  /// Kept pure so the client-side handling of callable success and error
  /// envelopes can be tested without Firebase or the network.
  static OmdbLookupResult interpretResponse(int statusCode, String body) {
    Map<String, dynamic>? decoded;
    try {
      final parsed = jsonDecode(body);
      if (parsed is Map<String, dynamic>) decoded = parsed;
    } catch (_) {
      decoded = null;
    }

    if (decoded == null) {
      return const OmdbLookupResult(OmdbLookupOutcome.failed);
    }

    if (statusCode == 200) {
      final result = decoded['result'];
      if (result is! Map) {
        return const OmdbLookupResult(OmdbLookupOutcome.failed);
      }
      if (result['Response'] == 'False') {
        return const OmdbLookupResult(OmdbLookupOutcome.notFound);
      }
      return OmdbLookupResult(
        OmdbLookupOutcome.found,
        data: Map<String, dynamic>.from(result),
      );
    }

    final error = decoded['error'];
    final status = error is Map ? error['status'] : null;
    switch (status) {
      case 'NOT_FOUND':
        return const OmdbLookupResult(OmdbLookupOutcome.notFound);
      case 'INVALID_ARGUMENT':
        return const OmdbLookupResult(OmdbLookupOutcome.invalidInput);
      case 'UNAUTHENTICATED':
        return const OmdbLookupResult(OmdbLookupOutcome.notSignedIn);
      case 'UNAVAILABLE':
        return const OmdbLookupResult(OmdbLookupOutcome.unavailable);
      default:
        return const OmdbLookupResult(OmdbLookupOutcome.failed);
    }
  }
}
