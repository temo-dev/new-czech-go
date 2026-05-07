import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/level_utils.dart';
import 'package:flutter_app/features/home/widgets/home_level_header.dart';
import 'package:flutter_app/features/home/widgets/level_badge.dart';
import 'package:flutter_app/features/home/widgets/level_progress_ring.dart';
import 'package:flutter_app/features/home/widgets/promotion_banner.dart';
import 'package:flutter_app/models/models.dart';

Widget _wrap(Widget child, {bool disableAnimations = true}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

LevelProgressResponse _progress({
  CefrLevel current = CefrLevel.a2,
  CefrLevel? next = CefrLevel.b1,
  Set<CefrLevel> unlocked = const {CefrLevel.a0, CefrLevel.a1, CefrLevel.a2},
  bool unlock = false,
  String testId = 'mt_b1',
}) {
  return LevelProgressResponse(
    userID: 'u',
    currentLevel: current,
    unlockedLevels: unlocked,
    nextLevel: next,
    skillMastery: {
      for (final k in const ['noi', 'viet', 'nghe', 'doc', 'tu_vung', 'ngu_phap'])
        k: SkillMasteryInfo(pct: 80, thresholdPct: 70, passes: true),
    },
    coveragePct: 90,
    coverageThresholdPct: 80,
    allSkillsPass: true,
    promotionUnlocked: unlock,
    promotionTestID: testId,
  );
}

void main() {
  testWidgets('HomeLevelHeader composes badge + ring + banner widgets', (tester) async {
    await tester.pumpWidget(_wrap(HomeLevelHeader(
      progress: _progress(unlock: true),
      onTapBadge: () {},
      onTapPromotion: (_) {},
    )));
    expect(find.byType(LevelBadge), findsOneWidget);
    expect(find.byType(LevelProgressRing), findsOneWidget);
    expect(find.byType(PromotionBanner), findsOneWidget);
    // Banner card visible (unlock=true + target not yet in unlockedLevels).
    expect(find.byKey(const Key('promotion_banner_card')), findsOneWidget);
  });

  testWidgets('HomeLevelHeader hides banner when promotion locked', (tester) async {
    await tester.pumpWidget(_wrap(HomeLevelHeader(
      progress: _progress(unlock: false),
      onTapBadge: () {},
      onTapPromotion: (_) {},
    )));
    expect(find.byKey(const Key('promotion_banner_card')), findsNothing);
  });

  testWidgets('HomeLevelHeader passes mock id through to onTapPromotion', (tester) async {
    String? routedId;
    await tester.pumpWidget(_wrap(HomeLevelHeader(
      progress: _progress(unlock: true, testId: 'mt_b1_promote'),
      onTapBadge: () {},
      onTapPromotion: (id) => routedId = id,
    )));
    await tester.tap(find.byKey(const Key('promotion_banner_card')));
    await tester.pumpAndSettle();
    expect(routedId, 'mt_b1_promote');
  });
}
