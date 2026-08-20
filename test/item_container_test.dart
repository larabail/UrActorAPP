import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/item_container.dart';

void main() {
  testWidgets('favorite badge renders a heart with a semantics label',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => getItemContainer(
              context,
              {'title': 'Missing poster', 'poster_path': null},
              'media',
              favoriteBadgeSemanticLabel: 'In your favorites',
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('favoriteBadge')), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'In your favorites',
      ),
      findsOneWidget,
    );
  });

  testWidgets('favorite badge is absent without a semantics label',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => getItemContainer(
              context,
              {'title': 'Missing poster', 'poster_path': null},
              'media',
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('favoriteBadge')), findsNothing);
  });
}
