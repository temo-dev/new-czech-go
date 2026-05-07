import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/api/api_client.dart';
import 'package:flutter_app/core/api/level_api.dart';
import 'package:flutter_app/core/level_utils.dart';
import 'package:flutter_app/features/courses/widgets/locked_course_tile.dart';
import 'package:flutter_app/features/home/screens/course_list_screen.dart';
import 'package:flutter_app/features/home/widgets/home_level_header.dart';
import 'package:flutter_app/l10n/generated/app_localizations.dart';
import 'package:flutter_app/models/models.dart';

// ─── fakes ────────────────────────────────────────────────────────────────────

class _FakeLevelApi extends LevelApi {
  _FakeLevelApi() : super(baseUrl: 'http://fake', tokenProvider: () => 'tok');

  LevelProgressResponse? _progress;
  void stubProgress(LevelProgressResponse p) => _progress = p;

  @override
  Future<LevelProgressResponse> fetchLevelProgress() async => _progress!;
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(baseUrl: 'http://fake');
  List<Map<String, dynamic>> _courses = [];

  void stubCourses(List<Map<String, dynamic>> courses) =>
      _courses = courses;

  @override
  Future<List<dynamic>> listCourses() async => _courses;

  @override
  Future<List<dynamic>> getAttempts() async => [];

  @override
  Future<Map<String, dynamic>> getProgress() async => {
    'overall_progress': 0.0,
    'overall_band': 'needs_work',
    'skills': <dynamic>[],
  };
}

// ─── fixtures ────────────────────────────────────────────────────────────────

LevelProgressResponse _progress({
  CefrLevel current = CefrLevel.a2,
  double coverage = 60,
  double threshold = 80,
}) {
  return LevelProgressResponse(
    userID: 'u1',
    currentLevel: current,
    unlockedLevels: {CefrLevel.a0, CefrLevel.a1, current},
    nextLevel: CefrLevel.b1,
    placementTakenAt: DateTime(2026, 5, 7),
    skillMastery: const {},
    coveragePct: coverage,
    coverageThresholdPct: threshold,
    allSkillsPass: false,
    promotionUnlocked: false,
  );
}

Map<String, dynamic> _course({
  String id = 'c1',
  String title = 'A2 Giao tiếp',
  String level = 'a2',
  String unlockState = 'unlocked',
  String demoExerciseId = '',
}) => {
  'id': id,
  'slug': id,
  'title': title,
  'description': '',
  'status': 'published',
  'sequence_no': 1,
  'level': level,
  'unlock_state': unlockState,
  'demo_exercise_id': demoExerciseId,
};

// ─── widget helper ───────────────────────────────────────────────────────────

Widget _wrap({
  required _FakeApiClient client,
  _FakeLevelApi? levelApi,
}) {
  return MaterialApp(
    locale: const Locale('vi'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      // Disable animations so LevelProgressRing's repeat() controller
      // and CircularProgressIndicator don't block pumpAndSettle.
      data: const MediaQueryData(disableAnimations: true),
      child: CourseListScreen(client: client, levelApi: levelApi),
    ),
  );
}

// Helper: pump enough for async to complete without waiting for infinite
// animations to settle (CourseListScreen has CircularProgressIndicator +
// LevelProgressRing repeat() which never settle in pumpAndSettle).
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(); // trigger initState / first frame
  await tester.pump(const Duration(milliseconds: 100)); // futures resolve
  await tester.pump(const Duration(milliseconds: 100)); // second async chain
}

// ─── tests ───────────────────────────────────────────────────────────────────

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('D1: HomeLevelHeader absent when levelApi is null', (tester) async {
    final client = _FakeApiClient()..stubCourses([_course()]);

    await tester.pumpWidget(_wrap(client: client));
    await _settle(tester);

    expect(find.byType(HomeLevelHeader), findsNothing);
  });

  testWidgets('D1: HomeLevelHeader shown when levelApi provided', (tester) async {
    final api = _FakeLevelApi()..stubProgress(_progress());
    final client = _FakeApiClient()..stubCourses([_course()]);

    await tester.pumpWidget(_wrap(client: client, levelApi: api));
    await _settle(tester);

    expect(find.byType(HomeLevelHeader), findsOneWidget);
  });

  testWidgets('D2: locked course renders LockedCourseTile (lock icon)', (tester) async {
    final api = _FakeLevelApi()..stubProgress(_progress());
    // Single locked course so it's in viewport without scrolling.
    final client = _FakeApiClient()
      ..stubCourses([
        _course(id: 'c2', title: 'B1 Tiếng Czech nâng cao', level: 'b1', unlockState: 'locked'),
      ]);

    await tester.pumpWidget(_wrap(client: client, levelApi: api));
    await _settle(tester);

    expect(find.text('B1 Tiếng Czech nâng cao'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    // No regular card (no onTap button without lock icon).
    expect(find.byType(LockedCourseTile), findsOneWidget);
  });

  testWidgets('D3: tap locked tile opens LockedCourseSheet', (tester) async {
    final api = _FakeLevelApi()..stubProgress(_progress());
    final client = _FakeApiClient()
      ..stubCourses([
        _course(id: 'c2', title: 'B1 Locked', level: 'b1', unlockState: 'locked'),
      ]);

    await tester.pumpWidget(_wrap(client: client, levelApi: api));
    await _settle(tester);

    // Scroll the lock icon into view before tapping.
    final lockFinder = find.byIcon(Icons.lock_outline);
    await tester.ensureVisible(lockFinder);
    await tester.pump();
    await tester.tap(lockFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('locked_course_sheet_continue_cta')), findsOneWidget);
  });

  testWidgets('D2: course with unlockState==unknown renders regular card', (tester) async {
    final api = _FakeLevelApi()..stubProgress(_progress());
    final client = _FakeApiClient()
      ..stubCourses([
        _course(id: 'c1', title: 'Unknown state course', unlockState: 'unknown'),
      ]);

    await tester.pumpWidget(_wrap(client: client, levelApi: api));
    await _settle(tester);

    expect(find.byIcon(Icons.lock_outline), findsNothing);
    expect(find.text('Unknown state course'), findsOneWidget);
  });

  testWidgets('D3: demo CTA visible on locked tile when demoExerciseId set', (tester) async {
    final api = _FakeLevelApi()..stubProgress(_progress());
    final client = _FakeApiClient()
      ..stubCourses([
        _course(
          id: 'c2',
          title: 'B1 With Demo',
          level: 'b1',
          unlockState: 'locked',
          demoExerciseId: 'ex_demo_1',
        ),
      ]);

    await tester.pumpWidget(_wrap(client: client, levelApi: api));
    await _settle(tester);

    expect(find.byKey(const Key('locked_course_tile_demo_cta')), findsOneWidget);
  });
}
