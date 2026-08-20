import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/firebase/playlist_service.dart';

void main() {
  group('PlaylistService.memberUidsFrom', () {
    test('collects every uid held in the single-key maps', () {
      final users = [
        {'owner': 'Owner'},
        {'guest': 'Approved'},
      ];
      expect(PlaylistService.memberUidsFrom(users), ['guest', 'owner']);
    });

    test('sorts, so the result matches what the Cloud Function writes', () {
      // The trigger compares its computed list against the stored one to
      // decide whether to write. Different ordering would cause a pointless
      // write on every client update.
      final users = [
        {'b': 'Owner'},
        {'a': 'Approved'},
      ];
      expect(PlaylistService.memberUidsFrom(users), ['a', 'b']);
    });

    test('drops duplicates', () {
      final users = [
        {'same': 'Owner'},
        {'same': 'Approved'},
      ];
      expect(PlaylistService.memberUidsFrom(users), ['same']);
    });

    test('handles a map carrying more than one uid', () {
      expect(
        PlaylistService.memberUidsFrom([
          {'a': 'Owner', 'b': 'Approved'}
        ]),
        ['a', 'b'],
      );
    });

    test('returns empty for a playlist with no Users field', () {
      expect(PlaylistService.memberUidsFrom(null), isEmpty);
      expect(PlaylistService.memberUidsFrom([]), isEmpty);
    });

    test('skips entries that are not maps', () {
      // Documents written by older builds are not guaranteed to be well
      // formed, and this runs on every playlist the user can see.
      expect(
        PlaylistService.memberUidsFrom(['text', 42, null, []]),
        isEmpty,
      );
    });

    test('ignores an empty uid', () {
      expect(
        PlaylistService.memberUidsFrom([
          {'': 'Owner'},
          {'real': 'Approved'}
        ]),
        ['real'],
      );
    });
  });
}
