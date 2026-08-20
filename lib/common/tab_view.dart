import 'package:flutter/material.dart';

import 'sorted_media_grid.dart';

class MyTabView extends StatelessWidget {
  final List<dynamic> favItems;

  const MyTabView({super.key, required this.favItems});

  @override
  Widget build(BuildContext context) {
    return SortedMediaGrid(items: favItems);
  }
}
