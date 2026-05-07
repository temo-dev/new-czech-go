import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/level_utils.dart';
import 'package:flutter_app/features/courses/widgets/locked_course_sheet.dart';
import 'package:flutter_app/features/courses/widgets/locked_course_tile.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('LockedCourseTile renders padlock + delta + ghost demo CTA', (tester) async {
    await tester.pumpWidget(_wrap(LockedCourseTile(
      title: 'Občanství B1',
      level: CefrLevel.b1,
      coveragePct: 73,
      coverageThresholdPct: 80,
      hasDemoExercise: true,
      onTap: () {},
      onTapDemo: () {},
    )));
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.text('B1'), findsOneWidget);
    expect(find.textContaining('73'), findsWidgets);
    expect(find.textContaining('80'), findsWidgets);
    // Ghost demo CTA visible because hasDemoExercise=true.
    expect(find.byKey(const Key('locked_course_tile_demo_cta')), findsOneWidget);
  });

  testWidgets('LockedCourseTile hides demo CTA when no demo configured', (tester) async {
    await tester.pumpWidget(_wrap(LockedCourseTile(
      title: 'Pro B1',
      level: CefrLevel.b1,
      coveragePct: 50,
      coverageThresholdPct: 80,
      hasDemoExercise: false,
      onTap: () {},
      onTapDemo: () {},
    )));
    expect(find.byKey(const Key('locked_course_tile_demo_cta')), findsNothing);
  });

  testWidgets('LockedCourseSheet renders mastery delta + dual CTAs', (tester) async {
    int demoTaps = 0;
    int continueTaps = 0;
    await tester.pumpWidget(_wrap(Builder(
      builder: (context) => ElevatedButton(
        onPressed: () {
          showModalBottomSheet<void>(
            context: context,
            builder: (_) => LockedCourseSheet(
              title: 'Občanství B1',
              level: CefrLevel.b1,
              coveragePct: 73,
              coverageThresholdPct: 80,
              hasDemoExercise: true,
              onTapDemo: () => demoTaps++,
              onTapContinueLowerLevel: () => continueTaps++,
            ),
          );
        },
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('locked_course_sheet_continue_cta')), findsOneWidget);
    expect(find.byKey(const Key('locked_course_sheet_demo_cta')), findsOneWidget);

    await tester.tap(find.byKey(const Key('locked_course_sheet_continue_cta')));
    await tester.pumpAndSettle();
    expect(continueTaps, 1);

    // Re-open sheet after first dismiss.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('locked_course_sheet_demo_cta')));
    await tester.pumpAndSettle();
    expect(demoTaps, 1);
  });
}
