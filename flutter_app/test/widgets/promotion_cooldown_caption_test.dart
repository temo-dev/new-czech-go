import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/promotion/promotion_result_screen.dart';

// S4 — the 1-second timer that drives the cooldown countdown used to live
// on PromotionResultScreen's State, so every tick rebuilt the heavy
// _DiagnosticTable. The caption is now self-rebuilding: it owns its own
// Timer.periodic and updates only its own subtree.

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('PromotionCooldownCaption updates without external rebuilds (S4)', (tester) async {
    var current = DateTime.utc(2026, 5, 7, 12);
    final cooldownUntil = current.add(const Duration(minutes: 1));

    await tester.pumpWidget(_wrap(PromotionCooldownCaption(
      cooldownUntil: cooldownUntil,
      clock: () => current,
    )));
    expect(find.textContaining('00:01:00'), findsOneWidget);

    // Advance the clock by 1s and pump a frame WITHOUT rebuilding the
    // outer widget tree. If the caption owns its own ticker the visible
    // remaining time updates; if it relied on parent setState the text
    // stays stuck on 00:01:00.
    current = current.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('00:00:59'), findsOneWidget);

    current = current.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('00:00:58'), findsOneWidget);
  });

  testWidgets('PromotionCooldownCaption renders nothing once cooldown has elapsed (S4)', (tester) async {
    final past = DateTime.utc(2026, 5, 7, 10);
    await tester.pumpWidget(_wrap(PromotionCooldownCaption(
      cooldownUntil: past,
      clock: () => DateTime.utc(2026, 5, 7, 12),
    )));
    expect(find.textContaining('00:'), findsNothing);
  });
}
