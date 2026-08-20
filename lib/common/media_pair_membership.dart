bool mediaPairMatches(dynamic first, dynamic second) {
  if (first is! List || second is! List || first.length < 2 || second.length < 2) {
    return false;
  }

  return first[0] == second[0] && first[1].toString() == second[1].toString();
}

bool containsMediaPair(Iterable<dynamic> pairs, dynamic target) {
  return pairs.any((pair) => mediaPairMatches(pair, target));
}

bool shouldShowFavoriteBadge({
  required bool showFavoriteBadge,
  required Iterable<dynamic> favoriteItems,
  required dynamic item,
}) {
  return showFavoriteBadge && containsMediaPair(favoriteItems, item);
}
