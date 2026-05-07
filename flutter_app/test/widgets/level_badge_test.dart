import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/level_utils.dart';
import 'package:flutter_app/features/home/widgets/level_badge.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('LevelBadge renders short level code + studying-next label', (tester) async {
    await tester.pumpWidget(_wrap(LevelBadge(
      currentLevel: CefrLevel.a1,
      unlockedLevels: const {CefrLevel.a0, CefrLevel.a1},
    )));

    // Short label (e.g. "A1") shows on the chip.
    expect(find.text('A1'), findsOneWidget);
    // Studying-next caption announces the next rung.
    expect(find.textContaining('A2'), findsWidgets);
  });

  testWidgets('LevelBadge top-of-ladder hides the studying-next caption', (tester) async {
    await tester.pumpWidget(_wrap(LevelBadge(
      currentLevel: CefrLevel.b1,
      unlockedLevels: const {CefrLevel.a0, CefrLevel.a1, CefrLevel.a2, CefrLevel.b1},
    )));
    expect(find.text('B1'), findsOneWidget);
    // No "đang học" caption at top of ladder.
    expect(find.textContaining('học'), findsNothing);
  });

  testWidgets('LevelBadge exposes a Semantics label with current + next', (tester) async {
    await tester.pumpWidget(_wrap(LevelBadge(
      currentLevel: CefrLevel.a2,
      unlockedLevels: const {CefrLevel.a0, CefrLevel.a1, CefrLevel.a2},
    )));
    final semantics = tester.getSemantics(find.byType(LevelBadge));
    expect(semantics.label, contains('A2'));
    expect(semantics.label, contains('B1'));
  });

  testWidgets('LevelBadge tap fires onTap', (tester) async {
    int tapped = 0;
    await tester.pumpWidget(_wrap(LevelBadge(
      currentLevel: CefrLevel.a1,
      unlockedLevels: const {CefrLevel.a0, CefrLevel.a1},
      onTap: () => tapped++,
    )));
    await tester.tap(find.byType(LevelBadge));
    await tester.pumpAndSettle();
    expect(tapped, 1);
  });
}
