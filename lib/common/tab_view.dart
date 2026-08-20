import 'package:flutter/material.dart';

import 'sorted_media_grid.dart';

class MyTabView extends StatelessWidget {
  final List<dynamic> favItems;
  final bool showFavoriteBadge;
  final bool showWatchlistBadge;

  const MyTabView({
    super.key,
    required this.favItems,
    this.showFavoriteBadge = true,
    this.showWatchlistBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    return SortedMediaGrid(
      items: favItems,
      showFavoriteBadge: showFavoriteBadge,
      showWatchlistBadge: showWatchlistBadge,
    );
  }
}
