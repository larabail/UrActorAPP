/// Where a person sits in the viewer's favourites.
///
/// The favourite actor, director and writer scores are computed on the server
/// now (`recomputePeopleScores` in `functions/index.js`), which walks the
/// viewer's whole library rather than waiting for someone's page to be opened.
/// Everything here is about *reading* that answer on a person page. It is pure
/// so it can be tested without Firestore or a widget.
library;

/// The 1-based position of [personId] among [scores].
///
/// [scores] is the shape the app keeps in `AppUser.favActors` and its two
/// siblings: a list of `[score, id]` pairs. [localScore] is the score the
/// person page just worked out from the library on this device.
///
/// The local score wins over any stored one for the person being looked at.
/// The two agree almost always -- they apply identical weights -- but the
/// stored value is only as fresh as the last server run, so a film marked seen
/// a minute ago is in the local score and not yet in the stored one. Ranking
/// against the local value means the page never has to tell someone that the
/// film they just logged did not count.
///
/// Ties take the better position: two people on the same score are both
/// "#3" rather than one of them being pushed to #4 by an ordering nobody can
/// see. A person absent from [scores] is ranked the same way as one present in
/// it, so somebody who has never been stored still gets an honest answer.
int rankOf(List<dynamic> scores, String personId, int localScore) {
  var ahead = 0;
  for (final entry in scores) {
    if (entry is! List || entry.length < 2) continue;
    if (entry[1].toString() == personId) continue;
    final score = _asScore(entry[0]);
    if (score > localScore) ahead++;
  }
  return ahead + 1;
}

int _asScore(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}
