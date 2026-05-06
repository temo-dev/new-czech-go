import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/core/api/progress_api.dart';
import 'package:flutter_app/core/api/progress_models.dart';
import 'package:flutter_app/features/progress/widgets/home_progress_card.dart';
import 'package:flutter_app/features/progress/widgets/progress_empty_state.dart';
import 'package:flutter_app/features/progress/widgets/progress_error_state.dart';
import 'package:flutter_app/features/progress/widgets/skill_mastery_row.dart';
import 'package:flutter_test/flutter_test.dart';

ProgressFetchResult _resultFromShape({
  required bool fromCache,
  required bool isStale,
  required Map<String, dynamic> shape,
}) {
  return ProgressFetchResult(
    progress: UserProgress.fromApiJson(shape),
    fromCache: fromCache,
    isStale: isStale,
    fetchedAt: DateTime.utc(2026, 5, 6),
  );
}

const Map<String, dynamic> _populatedShape = {
  'overall_progress': 0.55,
  'overall_band': 'learning',
  'skills': [
    {
      'skill_kind': 'noi',
      'mastery': 0.55,
      'band': 'learning',
      'attempts_count': 3,
      'modules': [],
    },
    {
      'skill_kind': 'viet',
      'mastery': 0.20,
      'band': 'needs_work',
      'attempts_count': 1,
      'modules': [],
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

HomeProgressCardLabels _labels({String offlineLabel = 'Đang offline'}) {
  return HomeProgressCardLabels(
    cardTitle: 'Tiến độ',
    overallLabel: 'Tổng',
    emptyTitle: 'Chưa có tiến độ',
    emptyMessage: 'Hoàn thành 1 bài để xem',
    emptyCtaLabel: 'Bắt đầu học',
    errorTitle: 'Không tải được',
    errorMessage: 'Kiểm tra mạng',
    retryLabel: 'Thử lại',
    offlineLabel: offlineLabel,
    skillLabelFor: (kind) => switch (kind) {
      'noi' => 'Nói',
      'viet' => 'Viết',
      _ => kind,
    },
  );
}

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('HomeProgressCard shows loading then populated rows',
      (tester) async {
    final completer = Completer<ProgressFetchResult>();
    await tester.pumpWidget(_wrap(HomeProgressCard(
      fetcher: ({bool forceRefresh = false}) => completer.future,
      labels: _labels(),
      onSkillTap: (_) {},
    )));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(_resultFromShape(
      fromCache: false,
      isStale: false,
      shape: _populatedShape,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Tiến độ'), findsOneWidget);
    expect(find.text('Nói'), findsOneWidget);
    expect(find.text('Viết'), findsOneWidget);
    expect(find.text('20%'), findsOneWidget);
    expect(find.byType(SkillMasteryRow), findsNWidgets(2));
  });

  testWidgets('HomeProgressCard renders empty state when no skills',
      (tester) async {
    var ctaTaps = 0;
    await tester.pumpWidget(_wrap(HomeProgressCard(
      fetcher: ({bool forceRefresh = false}) async => _resultFromShape(
        fromCache: false,
        isStale: false,
        shape: _emptyShape,
      ),
      labels: _labels(),
      onEmptyCta: () => ctaTaps++,
    )));
    await tester.pumpAndSettle();
    expect(find.byType(ProgressEmptyState), findsOneWidget);
    expect(find.text('Chưa có tiến độ'), findsOneWidget);
    await tester.tap(find.text('Bắt đầu học'));
    await tester.pumpAndSettle();
    expect(ctaTaps, 1);
  });

  testWidgets('HomeProgressCard renders error state on fetch failure',
      (tester) async {
    var fetchCalls = 0;
    await tester.pumpWidget(_wrap(HomeProgressCard(
      fetcher: ({bool forceRefresh = false}) {
        fetchCalls++;
        if (fetchCalls == 1) throw Exception('boom');
        return Future.value(_resultFromShape(
          fromCache: false,
          isStale: false,
          shape: _populatedShape,
        ));
      },
      labels: _labels(),
    )));
    await tester.pumpAndSettle();
    expect(find.byType(ProgressErrorState), findsOneWidget);
    expect(find.text('Không tải được'), findsOneWidget);

    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(fetchCalls, 2);
    expect(find.byType(SkillMasteryRow), findsNWidgets(2));
  });

  testWidgets('HomeProgressCard surfaces offline chip when stale',
      (tester) async {
    await tester.pumpWidget(_wrap(HomeProgressCard(
      fetcher: ({bool forceRefresh = false}) async => _resultFromShape(
        fromCache: true,
        isStale: true,
        shape: _populatedShape,
      ),
      labels: _labels(),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Đang offline'), findsOneWidget);
  });

  testWidgets('HomeProgressCard tap on skill row fires onSkillTap',
      (tester) async {
    String? tappedKind;
    await tester.pumpWidget(_wrap(HomeProgressCard(
      fetcher: ({bool forceRefresh = false}) async => _resultFromShape(
        fromCache: false,
        isStale: false,
        shape: _populatedShape,
      ),
      labels: _labels(),
      onSkillTap: (kind) => tappedKind = kind,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nói'));
    await tester.pumpAndSettle();
    expect(tappedKind, 'noi');
  });

  testWidgets('HomeProgressCard.refresh() re-fetches with forceRefresh=true',
      (tester) async {
    final calls = <bool>[];
    final key = GlobalKey<HomeProgressCardState>();
    await tester.pumpWidget(_wrap(HomeProgressCard(
      key: key,
      fetcher: ({bool forceRefresh = false}) async {
        calls.add(forceRefresh);
        return _resultFromShape(
          fromCache: false,
          isStale: false,
          shape: _populatedShape,
        );
      },
      labels: _labels(),
    )));
    await tester.pumpAndSettle();
    expect(calls, [false]);

    await key.currentState!.refresh();
    await tester.pumpAndSettle();
    expect(calls, [false, true]);
  });
}
