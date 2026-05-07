import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/level_utils.dart';
import 'package:flutter_app/features/home/widgets/promotion_banner.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: Center(child: child)));
}

void main() {
  testWidgets('PromotionBanner hides when promotionUnlocked is false', (tester) async {
    await tester.pumpWidget(_wrap(PromotionBanner(
      promotionUnlocked: false,
      targetLevel: CefrLevel.b1,
      unlockedLevels: const {CefrLevel.a0, CefrLevel.a1, CefrLevel.a2},
      promotionTestId: 'mt_b1_promote',
      onTap: (_) {},
    )));
    expect(find.byType(PromotionBanner), findsOneWidget);
    // No visible content when locked.
    expect(find.byKey(const Key('promotion_banner_card')), findsNothing);
  });

  testWidgets('PromotionBanner hides when target already in unlocked_levels', (tester) async {
    await tester.pumpWidget(_wrap(PromotionBanner(
      promotionUnlocked: true,
      targetLevel: CefrLevel.b1,
      unlockedLevels: const {CefrLevel.a0, CefrLevel.a1, CefrLevel.a2, CefrLevel.b1},
      promotionTestId: 'mt_b1_promote',
      onTap: (_) {},
    )));
    expect(find.byKey(const Key('promotion_banner_card')), findsNothing);
  });

  testWidgets('PromotionBanner shows + tap fires onTap with mock id when conditions met', (tester) async {
    String? tappedId;
    await tester.pumpWidget(_wrap(PromotionBanner(
      promotionUnlocked: true,
      targetLevel: CefrLevel.b1,
      unlockedLevels: const {CefrLevel.a0, CefrLevel.a1, CefrLevel.a2},
      promotionTestId: 'mt_b1_promote',
      onTap: (id) => tappedId = id,
    )));
    expect(find.byKey(const Key('promotion_banner_card')), findsOneWidget);
    expect(find.textContaining('B1'), findsWidgets);
    await tester.tap(find.byKey(const Key('promotion_banner_card')));
    await tester.pumpAndSettle();
    expect(tappedId, 'mt_b1_promote');
  });
}
