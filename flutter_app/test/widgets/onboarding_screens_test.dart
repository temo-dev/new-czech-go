import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/level_utils.dart';
import 'package:flutter_app/features/onboarding/placement_result_screen.dart';
import 'package:flutter_app/features/onboarding/welcome_screen.dart';

Widget _wrap(Widget child, {bool disableAnimations = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: child,
    ),
  );
}

void main() {
  testWidgets('WelcomeScreen renders both CTAs + intro copy', (tester) async {
    await tester.pumpWidget(_wrap(WelcomeScreen(
      onStart: () {},
      onSkip: () {},
    )));
    expect(find.byKey(const Key('onboarding_welcome_start_cta')), findsOneWidget);
    expect(find.byKey(const Key('onboarding_welcome_skip_cta')), findsOneWidget);
    // VI intro copy mentions placement.
    expect(find.textContaining('phân loại'), findsWidgets);
  });

  testWidgets('WelcomeScreen tap routes via callbacks', (tester) async {
    int starts = 0;
    int skips = 0;
    await tester.pumpWidget(_wrap(WelcomeScreen(
      onStart: () => starts++,
      onSkip: () => skips++,
    )));
    await tester.tap(find.byKey(const Key('onboarding_welcome_start_cta')));
    await tester.pumpAndSettle();
    expect(starts, 1);
    expect(skips, 0);

    await tester.tap(find.byKey(const Key('onboarding_welcome_skip_cta')));
    await tester.pumpAndSettle();
    expect(skips, 1);
  });

  testWidgets('PlacementResultScreen shows assigned level headline + body + CTA', (tester) async {
    int continues = 0;
    await tester.pumpWidget(_wrap(PlacementResultScreen(
      assignedLevel: CefrLevel.a2,
      scorePct: 60,
      onContinue: () => continues++,
    )));
    expect(find.textContaining('A2'), findsWidgets);
    expect(find.textContaining('60'), findsWidgets);
    await tester.tap(find.byKey(const Key('placement_result_continue_cta')));
    await tester.pumpAndSettle();
    expect(continues, 1);
  });

  testWidgets('PlacementResultScreen reduced motion skips reveal animation', (tester) async {
    await tester.pumpWidget(_wrap(
      PlacementResultScreen(
        assignedLevel: CefrLevel.a1,
        scorePct: 40,
        onContinue: () {},
      ),
      disableAnimations: true,
    ));
    // No animated reveal widget should be in the tree.
    expect(find.byKey(const Key('placement_result_reveal_animation')), findsNothing);
    // Static badge with the level still renders.
    expect(find.text('A1'), findsWidgets);
  });
}
