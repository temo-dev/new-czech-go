import 'package:flutter/material.dart';
import 'package:flutter_app/core/api/progress_api.dart';
import 'package:flutter_app/core/api/progress_models.dart';
import 'package:flutter_app/features/progress/screens/progress_detail_screen.dart';
import 'package:flutter_app/features/progress/widgets/progress_empty_state.dart';
import 'package:flutter_app/features/progress/widgets/progress_error_state.dart';
import 'package:flutter_app/features/progress/widgets/skill_mastery_row.dart';
import 'package:flutter_test/flutter_test.dart';

const Map<String, dynamic> _shape = {
  'overall_progress': 0.55,
  'overall_band': 'learning',
  'skills': [
    {
      'skill_kind': 'noi',
      'mastery': 0.55,
      'band': 'learning',
      'attempts_count': 5,
      'modules': [
        {
          'module_id': 'giao-tiep-co-ban',
          'mastery': 0.50,
          'band': 'learning',
          'attempts_count': 3,
        },
        {
          'module_id': 'di-urad',
          'mastery': 0.60,
          'band': 'learning',
          'attempts_count': 2,
        },
      ],
    },
    {
      'skill_kind': 'viet',
      'mastery': 0.20,
      'band': 'needs_work',
      'attempts_count': 1,
      'modules': [
        {
          'module_id': 'giao-tiep-co-ban',
          'mastery': 0.20,
          'band': 'needs_work',
          'attempts_count': 1,
        },
      ],
    },
  ],
  'bands': {'needs_work': 0.40, 'solid': 0.70, 'ready': 0.85},
  'weights': {'noi': 25, 'viet': 20},
};

const Map<String, dynamic> _emptyShape = {
  'overall_progress': 0.0,
  'overall_band': 'needs_work',
  'skills': [],
  'bands': {'needs_work': 0.40, 'solid': 0.70, 'ready': 0.85},
  'weights': <String, int>{},
};

ProgressFetchResult _result(Map<String, dynamic> shape, {bool isStale = false}) {
  return ProgressFetchResult(
    progress: UserProgress.fromApiJson(shape),
    fromCache: false,
    isStale: isStale,
    fetchedAt: DateTime.utc(2026, 5, 6),
  );
}

ProgressDetailLabels _labels() {
  return ProgressDetailLabels(
    titleAll: 'Tiến độ học tập',
    titleForSkill: (kind) => 'Tiến độ ${kind.toUpperCase()}',
    moduleLabelFor: (id) => switch (id) {
      'giao-tiep-co-ban' => 'Giao tiếp cơ bản',
      'di-urad' => 'Đi úřad',
      _ => id,
    },
    skillLabelFor: (kind) => switch (kind) {
      'noi' => 'Nói',
      'viet' => 'Viết',
      _ => kind,
    },
    attemptsCountLabel: (n) => '$n lượt',
    emptyTitle: 'Chưa có tiến độ',
    emptyMessage: 'Hoàn thành 1 bài để xem',
    emptyCtaLabel: 'Bắt đầu học',
    errorTitle: 'Không tải được',
    errorMessage: 'Kiểm tra mạng',
    retryLabel: 'Thử lại',
    offlineLabel: 'Đang offline',
  );
}

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('ProgressDetailScreen renders all skills when skillKind is null',
      (tester) async {
    await tester.pumpWidget(_wrap(ProgressDetailScreen(
      fetcher: ({bool forceRefresh = false}) async => _result(_shape),
      labels: _labels(),
      skillKind: null,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Tiến độ học tập'), findsWidgets);
    expect(find.text('Nói'), findsOneWidget);
    expect(find.text('Viết'), findsOneWidget);
    // 3 module rows: 2 for noi + 1 for viet.
    expect(find.byType(SkillMasteryRow), findsNWidgets(3));
  });

  testWidgets('ProgressDetailScreen filters to one skill when skillKind set',
      (tester) async {
    await tester.pumpWidget(_wrap(ProgressDetailScreen(
      fetcher: ({bool forceRefresh = false}) async => _result(_shape),
      labels: _labels(),
      skillKind: 'noi',
    )));
    await tester.pumpAndSettle();
    expect(find.text('Tiến độ NOI'), findsWidgets);
    expect(find.text('Giao tiếp cơ bản'), findsOneWidget);
    expect(find.text('Đi úřad'), findsOneWidget);
    expect(find.text('Viết'), findsNothing);
    // 2 module rows for noi.
    expect(find.byType(SkillMasteryRow), findsNWidgets(2));
  });

  testWidgets('ProgressDetailScreen renders empty state', (tester) async {
    await tester.pumpWidget(_wrap(ProgressDetailScreen(
      fetcher: ({bool forceRefresh = false}) async => _result(_emptyShape),
      labels: _labels(),
      skillKind: null,
    )));
    await tester.pumpAndSettle();
    expect(find.byType(ProgressEmptyState), findsOneWidget);
  });

  testWidgets('ProgressDetailScreen renders error + retry', (tester) async {
    var calls = 0;
    await tester.pumpWidget(_wrap(ProgressDetailScreen(
      fetcher: ({bool forceRefresh = false}) {
        calls++;
        if (calls == 1) throw Exception('boom');
        return Future.value(_result(_shape));
      },
      labels: _labels(),
      skillKind: null,
    )));
    await tester.pumpAndSettle();
    expect(find.byType(ProgressErrorState), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.byType(SkillMasteryRow), findsWidgets);
  });

  testWidgets('ProgressDetailScreen pull-to-refresh re-fetches with forceRefresh',
      (tester) async {
    final calls = <bool>[];
    await tester.pumpWidget(_wrap(ProgressDetailScreen(
      fetcher: ({bool forceRefresh = false}) async {
        calls.add(forceRefresh);
        return _result(_shape);
      },
      labels: _labels(),
      skillKind: null,
    )));
    await tester.pumpAndSettle();
    expect(calls, [false]);

    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(calls.length, greaterThanOrEqualTo(2));
    expect(calls.last, isTrue);
  });

  testWidgets('ProgressDetailScreen surfaces offline chip when stale',
      (tester) async {
    await tester.pumpWidget(_wrap(ProgressDetailScreen(
      fetcher: ({bool forceRefresh = false}) async =>
          _result(_shape, isStale: true),
      labels: _labels(),
      skillKind: null,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Đang offline'), findsOneWidget);
  });
}
