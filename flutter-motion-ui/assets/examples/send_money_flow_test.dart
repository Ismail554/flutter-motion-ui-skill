// Widget tests for the example flow — the shape to copy when testing any
// state-driven animated flow. Replace `your_app` with the project's package
// name and adjust the import paths to where the files were copied.
//
// Two things worth noticing:
//  * `settle` pumps fixed time instead of `pumpAndSettle`, which never returns
//    while a looping animation (spinner, caret, pulse) is on screen.
//  * The test asserts on *state outcomes* (text present, row added), not on
//    animation internals, so motion can be retuned without breaking tests.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:your_app/examples/send_money_flow.dart';
import 'package:your_app/motion_kit/motion_kit.dart';

Future<void> settle(WidgetTester t, [int ms = 1500]) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void usePhone(WidgetTester t, [Size size = const Size(390, 844)]) {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  testWidgets('sending money adds the transfer to the list', (t) async {
    usePhone(t);
    await t.pumpWidget(
      const ProviderScope(child: MaterialApp(home: TransfersScreen())),
    );
    await settle(t);
    expect(find.text('Alex Morgan'), findsOneWidget);

    await t.tap(find.byTooltip('Send'));
    await settle(t);

    for (final digit in ['5', '9']) {
      await t.tap(find.bySemanticsLabel(digit));
      await settle(t, 400);
    }

    // Drag the slider thumb across the track.
    final start =
        t.getTopLeft(find.byType(SlideToConfirm)) + const Offset(30, 30);
    final gesture = await t.startGesture(start);
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(20, 0));
      await t.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await settle(t, 3000);
    expect(find.text('Sent to Alex Morgan'), findsOneWidget);

    await t.tap(find.text('Done'));
    await settle(t);
    expect(find.text('\$59'), findsOneWidget);
    expect(find.text('Alex Morgan'), findsNWidgets(2));

    // Long-press removes it again; the row animates out.
    await t.longPress(find.text('\$59'));
    await settle(t);
    expect(find.text('\$59'), findsNothing);
  });

  testWidgets('send screen does not overflow on a small phone', (t) async {
    usePhone(t, const Size(320, 480));
    await t.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SendMoneyScreen(recipient: 'Alex Morgan')),
      ),
    );
    await settle(t);
    expect(t.takeException(), isNull);
    expect(find.text('Slide to send'), findsOneWidget);
  });

  testWidgets('a short slide springs back and does not send', (t) async {
    usePhone(t);
    await t.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SendMoneyScreen(recipient: 'Alex Morgan')),
      ),
    );
    await settle(t);
    await t.tap(find.bySemanticsLabel('5'));
    await settle(t, 400);

    // Let go well before the threshold: exercises the release path, which
    // the happy-path test never reaches.
    await t.drag(find.byType(SlideToConfirm), const Offset(60, 0));
    await settle(t);
    expect(t.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Slide to send'), findsOneWidget);
  });

  testWidgets('list screen survives a narrow phone with large text', (t) async {
    usePhone(t, const Size(320, 568));
    t.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(
      const ProviderScope(child: MaterialApp(home: TransfersScreen())),
    );
    await settle(t);
    expect(t.takeException(), isNull);
  });

  testWidgets('reduced motion still completes the flow', (t) async {
    usePhone(t);
    await t.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: SendMoneyScreen(recipient: 'Alex Morgan'),
          ),
        ),
      ),
    );
    await t.pump();
    await t.tap(find.bySemanticsLabel('7'));
    await t.pump();
    expect(find.bySemanticsLabel('\$7'), findsOneWidget);
  });
}
