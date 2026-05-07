import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/level_utils.dart';
import 'package:flutter_app/features/home/widgets/level_progress_ring.dart';
import 'package:flutter_app/models/models.dart';

Widget _wrap(Widget child, {bool disableAnimations = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

Map<String, SkillMasteryInfo> _mastery({double pct = 80}) {
  final map = <String, SkillMasteryInfo>{};
  for (final k in const ['noi', 'viet', 'nghe', 'doc', 'tu_vung', 'ngu_phap']) {
    map[k] = SkillMasteryInfo(pct: pct, thresholdPct: 70, passes: pct >= 70);
  }
  return map;
}

void main() {
  testWidgets('LevelProgressRing renders ladder arrow + readiness percent', (tester) async {
    await tester.pumpWidget(_wrap(LevelProgressRing(
      currentLevel: CefrLevel.a2,
      nextLevel: CefrLevel.b1,
      skillMastery: _mastery(pct: 73),
      coveragePct: 73,
      coverageThresholdPct: 80,
      promotionUnlocked: false,
    )));
    expect(find.textContaining('A2'), findsWidgets);
    expect(find.textContaining('B1'), findsWidgets);
    expect(find.textContaining('73%'), findsOneWidget);
  });

  testWidgets('LevelProgressRing top of ladder hides the next-level arrow', (tester) async {
    await tester.pumpWidget(_wrap(LevelProgressRing(
      currentLevel: CefrLevel.b1,
      nextLevel: null,
      skillMastery: _mastery(pct: 90),
      coveragePct: 100,
      coverageThresholdPct: 80,
      promotionUnlocked: false,
    )));
    expect(find.text('→'), findsNothing);
    expect(find.text('B1'), findsWidgets);
  });

  testWidgets('LevelProgressRing pulses (ScaleTransition) when unlocked + motion enabled', (tester) async {
    await tester.pumpWidget(_wrap(LevelProgressRing(
      currentLevel: CefrLevel.a2,
      nextLevel: CefrLevel.b1,
      skillMastery: _mastery(pct: 85),
      coveragePct: 90,
      coverageThresholdPct: 80,
      promotionUnlocked: true,
    )));
    // Pulse rendered as a ScaleTransition driven by an AnimationController.
    expect(find.byKey(const Key('level_progress_ring_pulse')), findsOneWidget);
    // No "Sẵn sàng" pill — unlocked branding lives in the pulse itself.
    expect(find.byKey(const Key('level_progress_ring_ready_pill')), findsNothing);
    // Allow ticker to run a couple of frames to confirm no crash on animation.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    // Stop animation to let the test finish cleanly.
    await tester.pumpWidget(_wrap(const SizedBox.shrink()));
  });

  testWidgets('LevelProgressRing reduced motion shows static Sẵn sàng pill', (tester) async {
    await tester.pumpWidget(_wrap(
      LevelProgressRing(
        currentLevel: CefrLevel.a2,
        nextLevel: CefrLevel.b1,
        skillMastery: _mastery(pct: 85),
        coveragePct: 90,
        coverageThresholdPct: 80,
        promotionUnlocked: true,
      ),
      disableAnimations: true,
    ));
    expect(find.byKey(const Key('level_progress_ring_ready_pill')), findsOneWidget);
    expect(find.byKey(const Key('level_progress_ring_pulse')), findsNothing);
  });
}
