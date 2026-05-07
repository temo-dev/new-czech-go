import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/level_utils.dart';
import 'package:flutter_app/features/promotion/pre_exam_screen.dart';
import 'package:flutter_app/features/promotion/promotion_result_screen.dart';
import 'package:flutter_app/models/models.dart';

Widget _wrap(Widget child, {bool disableAnimations = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: child,
    ),
  );
}

void main() {
  testWidgets('PreExamScreen renders rules + dual CTAs', (tester) async {
    int confirms = 0;
    int cancels = 0;
    await tester.pumpWidget(_wrap(PreExamScreen(
      targetLevel: CefrLevel.b1,
      durationMinutes: 90,
      passThresholdPct: 60,
      cooldownHours: 24,
      onConfirm: () => confirms++,
      onCancel: () => cancels++,
    )));
    expect(find.byKey(const Key('pre_exam_confirm_cta')), findsOneWidget);
    expect(find.byKey(const Key('pre_exam_cancel_cta')), findsOneWidget);
    // Body lists time + threshold + cooldown.
    expect(find.textContaining('90'), findsWidgets);
    expect(find.textContaining('60'), findsWidgets);
    expect(find.textContaining('24'), findsWidgets);

    await tester.tap(find.byKey(const Key('pre_exam_confirm_cta')));
    await tester.pumpAndSettle();
    expect(confirms, 1);

    await tester.tap(find.byKey(const Key('pre_exam_cancel_cta')));
    await tester.pumpAndSettle();
    expect(cancels, 1);
  });

  testWidgets('PromotionResultScreen pass renders badge + dual CTAs (no failure table)', (tester) async {
    int explores = 0;
    int homes = 0;
    await tester.pumpWidget(_wrap(
      PromotionResultScreen(
        passed: true,
        targetLevel: CefrLevel.b1,
        scorePct: 78,
        perSkillPct: const {},
        cooldownUntil: null,
        thresholdPct: 70,
        onExplore: () => explores++,
        onHome: () => homes++,
        onPracticeWeakSkill: (_) {},
      ),
      disableAnimations: true,
    ));
    expect(find.byKey(const Key('promotion_result_pass_explore_cta')), findsOneWidget);
    expect(find.byKey(const Key('promotion_result_pass_home_cta')), findsOneWidget);
    expect(find.byKey(const Key('promotion_result_fail_table')), findsNothing);

    await tester.tap(find.byKey(const Key('promotion_result_pass_explore_cta')));
    await tester.pumpAndSettle();
    expect(explores, 1);

    await tester.tap(find.byKey(const Key('promotion_result_pass_home_cta')));
    await tester.pumpAndSettle();
    expect(homes, 1);
  });

  testWidgets('PromotionResultScreen fail renders diagnostic table + cooldown timer', (tester) async {
    final now = DateTime.utc(2026, 5, 7, 12);
    final cooldownUntil = now.add(const Duration(hours: 23, minutes: 42));
    await tester.pumpWidget(_wrap(
      PromotionResultScreen(
        passed: false,
        targetLevel: CefrLevel.b1,
        scorePct: 45,
        perSkillPct: const {
          'noi': 80,
          'viet': 50,
          'nghe': 75,
          'doc': 72,
          'tu_vung': 78,
          'ngu_phap': 65,
        },
        cooldownUntil: cooldownUntil,
        thresholdPct: 70,
        clock: () => now,
        onExplore: () {},
        onHome: () {},
        onPracticeWeakSkill: (_) {},
      ),
      disableAnimations: true,
    ));
    expect(find.byKey(const Key('promotion_result_fail_table')), findsOneWidget);
    // Each skill row renders.
    expect(find.text('viet'), findsWidgets);
    // Live cooldown caption shows hh:mm:ss-style remaining.
    expect(find.byKey(const Key('promotion_result_cooldown_timer')), findsOneWidget);
    expect(find.textContaining('23'), findsWidgets);
  });

  testWidgets('PromotionResultScreen fail weakest-skill deep link fires with skill kind', (tester) async {
    String? routedSkill;
    await tester.pumpWidget(_wrap(
      PromotionResultScreen(
        passed: false,
        targetLevel: CefrLevel.b1,
        scorePct: 45,
        perSkillPct: const {
          'noi': 80,
          'viet': 50, // weakest
          'nghe': 75,
          'doc': 72,
          'tu_vung': 78,
          'ngu_phap': 65,
        },
        cooldownUntil: null,
        thresholdPct: 70,
        onExplore: () {},
        onHome: () {},
        onPracticeWeakSkill: (skill) => routedSkill = skill,
      ),
      disableAnimations: true,
    ));
    await tester.tap(find.byKey(const Key('promotion_result_practice_weak_cta')));
    await tester.pumpAndSettle();
    expect(routedSkill, 'viet');
  });

  testWidgets('PromotionResultScreen pass reduced-motion skips badge spring', (tester) async {
    await tester.pumpWidget(_wrap(
      PromotionResultScreen(
        passed: true,
        targetLevel: CefrLevel.b1,
        scorePct: 80,
        perSkillPct: const {},
        cooldownUntil: null,
        thresholdPct: 70,
        onExplore: () {},
        onHome: () {},
        onPracticeWeakSkill: (_) {},
      ),
      disableAnimations: true,
    ));
    expect(find.byKey(const Key('promotion_result_badge_spring')), findsNothing);
    // Static badge still visible.
    expect(find.text('B1'), findsWidgets);
  });
}

// ignore: unused_element
LevelProgressResponse _dummy() => LevelProgressResponse.fromJson(const {});
