import 'package:flutter/material.dart';

import 'sorted_media_grid.dart';

class MyTabView extends StatelessWidget {
  final List<dynamic> favItems;
  final bool showFavoriteBadge;
  final List<dynamic> Function()? favoriteItemsProvider;

  const MyTabView({
    super.key,
    required this.favItems,
    this.showFavoriteBadge = false,
    this.favoriteItemsProvider,
  });

  @override
  Widget build(BuildContext context) {
    return SortedMediaGrid(
      items: favItems,
      showFavoriteBadge: showFavoriteBadge,
      favoriteItemsProvider: favoriteItemsProvider,
    );
  }
}
