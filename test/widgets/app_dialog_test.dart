/// Tests for the shared dialogue shell.
///
/// The shell exists because twelve popups each grew their own layout and each
/// got it differently wrong. What is worth pinning is the part that stopped
/// that: the panel takes the width it is offered instead of the framework's
/// 280pt minimum, the action row stacks rather than clipping when the labels
/// grow, and a long body scrolls underneath a title and above buttons that
/// stay where the user last saw them.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uractor/common/widgets/app_dialog.dart';

import '../support/harness.dart';

void main() {
  /// Opens [dialog] over a window of [size], with the dialogue inset installed
  /// the way `main.dart` installs it.
  Future<void> open(
    WidgetTester tester,
    AppDialog dialog, {
    Size size = const Size(360, 800),
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    usePhoneSurface(tester, size: size);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          dialogTheme: const DialogThemeData(insetPadding: kAppDialogInset),
        ),
        // Text scale has to be injected above the Navigator: a dialogue is a
        // route beside the home widget rather than a widget inside it, so
        // wrapping the home Scaffold never reaches it.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  showDialog<void>(context: context, builder: (_) => dialog),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// The panel -- the Material the [Dialog] paints, whose edges are what the
  /// user actually sees.
  Size panelSize(WidgetTester tester) => tester.getSize(
        find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(Material),
            )
            .first,
      );

  group('how wide the panel gets', () {
    testWidgets('fills the window it is offered rather than the 280pt minimum',
        (tester) async {
      // A popup that never asked for a width sat at Dialog's own minimum and
      // discarded everything past it. On a 360pt phone that was 280 of the
      // 328 it was allowed.
      await open(
        tester,
        const AppDialog(title: 'Settings', child: Text('body')),
      );

      expect(panelSize(tester).width, 328.0);
    });

    testWidgets('is unaffected by how little its content needs',
        (tester) async {
      // The width has to come from the room available, not from the widest
      // child, or a dialogue of two short words falls back to the minimum.
      await open(
        tester,
        const AppDialog(title: 'Hi', child: Text('ok')),
      );

      expect(panelSize(tester).width, 328.0);
    });

    testWidgets('stops growing once the window is wide enough', (tester) async {
      // Taking everything on offer is right on a phone and wrong on a tablet:
      // a column of text fields 1100pt wide reads worse than one that stops.
      await open(
        tester,
        const AppDialog(title: 'Settings', child: Text('body')),
        size: const Size(1200, 900),
      );

      expect(panelSize(tester).width, 560.0);
    });
  });

  group('the action row', () {
    List<AppDialogAction> twoActions({VoidCallback? onConfirm}) => [
          AppDialogAction(
            label: 'Cancel',
            icon: Icons.cancel,
            tone: AppDialogTone.cancel,
            onPressed: () {},
          ),
          AppDialogAction(
            label: 'Accept',
            icon: Icons.check,
            tone: AppDialogTone.confirm,
            onPressed: onConfirm,
          ),
        ];

    testWidgets('sits on one line while the labels fit', (tester) async {
      // Short labels deliberately. The test font paints every glyph one em
      // wide, so "Cancel" measures 84pt here against roughly 45 in Roboto,
      // and a pair of realistic labels wraps in a test long before it would
      // on a device. Two letters each is the only way to be sure this is
      // measuring the layout rather than the font.
      await open(
        tester,
        AppDialog(
          title: 'Settings',
          actions: [
            AppDialogAction(label: 'No', onPressed: () {}),
            AppDialogAction(label: 'Ok', onPressed: () {}),
          ],
          child: const Text('body'),
        ),
      );

      expect(
        tester.getTopLeft(find.text('No')).dy,
        tester.getTopLeft(find.text('Ok')).dy,
      );
    });

    testWidgets('stacks instead of clipping when the labels outgrow the row',
        (tester) async {
      // This is the structural fix. The rows this replaces were plain Rows, so
      // a large text scale -- or a language whose words are longer -- pushed a
      // label off the edge, and a release build cut it off in silence.
      await open(
        tester,
        AppDialog(
          title: 'Settings',
          actions: twoActions(onConfirm: () {}),
          child: const Text('body'),
        ),
        textScaler: const TextScaler.linear(2.5),
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getTopLeft(find.text('Accept')).dy,
        greaterThan(tester.getTopLeft(find.text('Cancel')).dy),
        reason: 'the row should have wrapped rather than run off the side',
      );
      expect(
        tester.getBottomRight(find.text('Accept')).dx,
        lessThanOrEqualTo(panelSize(tester).width + 16.0),
        reason: 'nothing should be sticking out past the panel',
      );
    });

    testWidgets('runs the handler of the button that was pressed',
        (tester) async {
      var accepted = false;
      await open(
        tester,
        AppDialog(
          title: 'Settings',
          actions: twoActions(onConfirm: () => accepted = true),
          child: const Text('body'),
        ),
      );

      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();

      expect(accepted, isTrue);
    });

    testWidgets('a null handler leaves the button dead', (tester) async {
      // How a dialogue that is mid-submit refuses a second tap.
      await open(
        tester,
        AppDialog(
          title: 'Settings',
          actions: twoActions(),
          child: const Text('body'),
        ),
      );

      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Accept'))
            .onPressed,
        isNull,
      );
    });

    testWidgets('is left out entirely when a popup has no buttons',
        (tester) async {
      await open(
        tester,
        const AppDialog(title: 'Settings', child: Text('body')),
      );

      expect(find.byType(OverflowBar), findsNothing);
    });
  });

  group('what scrolls and what does not', () {
    AppDialog tall() => AppDialog(
          title: 'Settings',
          actions: [
            AppDialogAction(
              label: 'Accept',
              icon: Icons.check,
              tone: AppDialogTone.confirm,
              onPressed: () {},
            ),
          ],
          child: Column(
            children: [
              for (var i = 0; i < 40; i++)
                SizedBox(height: 40, child: Text('row $i')),
            ],
          ),
        );

    testWidgets('the title and the buttons hold still while the body moves',
        (tester) async {
      await open(tester, tall());

      final titleBefore = tester.getTopLeft(find.text('Settings'));
      final buttonBefore = tester.getTopLeft(find.text('Accept'));
      final rowBefore = tester.getTopLeft(find.text('row 0'));

      await tester.drag(find.text('row 1'), const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(find.text('Settings')), titleBefore);
      expect(tester.getTopLeft(find.text('Accept')), buttonBefore);
      expect(
        tester.getTopLeft(find.text('row 0')).dy,
        lessThan(rowBefore.dy),
        reason: 'the body is the only part that should have moved',
      );
    });

    testWidgets('a long body does not push the buttons off the screen',
        (tester) async {
      await open(tester, tall());

      // 800 tall window, 24pt inset top and bottom.
      expect(tester.getBottomLeft(find.text('Accept')).dy, lessThan(776.0));
    });

    testWidgets('a body that fits leaves the panel no taller than it needs',
        (tester) async {
      await open(
        tester,
        const AppDialog(title: 'Settings', child: Text('body')),
      );

      expect(panelSize(tester).height, lessThan(200.0));
    });
  });

  testWidgets('a list tile has a Material underneath it to splash on',
      (tester) async {
    // The panel used to be a Container painted over the Dialog's own Material,
    // which left the nearest Material above the tiles rather than below them.
    // The framework said so on every frame, and the test harness carried a
    // helper whose only job was to swallow it.
    await open(
      tester,
      AppDialog(
        title: 'Pick',
        child: CheckboxListTile(
          title: const Text('Ana'),
          value: false,
          onChanged: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('Ana'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
