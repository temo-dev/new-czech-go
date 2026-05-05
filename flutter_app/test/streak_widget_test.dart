import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/streak/streak_models.dart';
import 'package:flutter_app/features/home/widgets/streak_ring_widget.dart';

void main() {
  group('StreakSummary.fromJson', () {
    test('parses canonical payload', () {
      final s = StreakSummary.fromJson({
        'current_days': 12,
        'longest_days': 28,
        'last_completed_day': '2026-05-04',
        'grace_passes_left_this_week': 1,
      });
      expect(s.currentDays, 12);
      expect(s.longestDays, 28);
      expect(s.lastCompletedDay, isNotNull);
      expect(s.gracePassesLeftThisWeek, 1);
    });

    test('absent fields fall back to zero', () {
      final s = StreakSummary.fromJson(const {});
      expect(s.currentDays, 0);
      expect(s.longestDays, 0);
      expect(s.lastCompletedDay, isNull);
      expect(s.gracePassesLeftThisWeek, 0);
    });
  });

  testWidgets('StreakRingWidget renders count + day text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StreakRingWidget(
            summary: StreakSummary(
              currentDays: 12,
              longestDays: 28,
              gracePassesLeftThisWeek: 1,
            ),
          ),
        ),
      ),
    );
    expect(find.text('12'), findsOneWidget);
    expect(find.text('ngày'), findsOneWidget);
    expect(find.textContaining('grace pass'), findsOneWidget);
    expect(find.textContaining('Kỷ lục'), findsOneWidget);
  });

  testWidgets('StreakRingWidget shows zero state without crashing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StreakRingWidget(summary: StreakSummary.empty),
        ),
      ),
    );
    expect(find.text('0'), findsOneWidget);
    expect(find.textContaining('grace'), findsNothing);
    expect(find.textContaining('Kỷ lục'), findsNothing);
  });

  testWidgets('StreakRingWidget tap fires onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreakRingWidget(
            summary: StreakSummary.empty,
            onTap: () => taps++,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(StreakRingWidget));
    expect(taps, 1);
  });

  testWidgets('StreakRingWidget renders without crash when completion list provided',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreakRingWidget(
            summary: const StreakSummary(
              currentDays: 3, longestDays: 3, gracePassesLeftThisWeek: 0,
            ),
            last7DaysCompletion: const [false, false, false, false, true, true, true],
          ),
        ),
      ),
    );
    expect(find.text('3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
