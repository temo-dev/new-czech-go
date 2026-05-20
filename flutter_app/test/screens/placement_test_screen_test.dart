import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/api/api_client.dart';
import 'package:flutter_app/core/api/level_api.dart';
import 'package:flutter_app/core/level_utils.dart';
import 'package:flutter_app/features/onboarding/placement_test_screen.dart';
import 'package:flutter_app/l10n/generated/app_localizations.dart';

// ─── fakes ────────────────────────────────────────────────────────────────────

class _FakeLevelApi extends LevelApi {
  _FakeLevelApi() : super(baseUrl: 'http://fake', tokenProvider: () => 'tok');

  PlacementStartResult? _startResult;
  Object? _startError;
  PlacementCompleteResult? _completeResult;

  void stubStart(PlacementStartResult result) => _startResult = result;
  void stubStartError(Object error) => _startError = error;
  void stubComplete(PlacementCompleteResult result) => _completeResult = result;

  @override
  Future<PlacementStartResult> startPlacement({bool force = false}) async {
    final err = _startError;
    if (err != null) throw err;
    return _startResult!;
  }

  @override
  Future<PlacementCompleteResult> completePlacement(
    String fullSessionId,
  ) async => _completeResult!;
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(baseUrl: 'http://fake');

  Map<String, dynamic>? _mockExam;
  Map<String, dynamic>? _completedMockExam;
  Object? _mockExamError;

  void stubGetMockExam(Map<String, dynamic> result) => _mockExam = result;
  void stubCompleteMockExam(Map<String, dynamic> result) =>
      _completedMockExam = result;
  void stubGetMockExamError(Object error) => _mockExamError = error;

  @override
  Future<Map<String, dynamic>> getMockExam(String id) async {
    final err = _mockExamError;
    if (err != null) throw err;
    return _mockExam!;
  }

  @override
  Future<Map<String, dynamic>> completeMockExam(String id) async {
    return _completedMockExam ?? _mockExam!;
  }

  @override
  Future<List<dynamic>> getAttempts() async => const [];
}

// ─── shared fixtures ─────────────────────────────────────────────────────────

const _kSessionId = 'fes_placement_1';
const _kMockTestId = 'mt_placement';

PlacementStartResult _startResult() => const PlacementStartResult(
  mockTestId: _kMockTestId,
  fullSessionId: _kSessionId,
);

Map<String, dynamic> _sessionJson({
  bool completed = false,
  int? overallScore,
}) => {
  'id': _kSessionId,
  'mock_test_id': _kMockTestId,
  'status': completed ? 'completed' : 'in_progress',
  'overall_score': overallScore ?? (completed ? 60 : 0),
  'passed': false,
  'pass_threshold_percent': 0,
  'overall_readiness_level': '',
  'overall_summary': '',
  'sections': <dynamic>[],
};

PlacementCompleteResult _completeResult({
  required CefrLevel level,
  required double scorePct,
}) => PlacementCompleteResult(
  assignedLevel: level,
  scorePct: scorePct,
  currentLevel: level,
  unlockedLevels:
      CefrLevel.values
          .where(
            (candidate) => cefrLevelOrder(candidate) <= cefrLevelOrder(level),
          )
          .toSet(),
  placementTakenAt: DateTime(2026, 5, 17, 8, 49),
);

// ─── widget helper ───────────────────────────────────────────────────────────

Widget _wrap({
  required _FakeLevelApi levelApi,
  required _FakeApiClient client,
  VoidCallback? onFinished,
}) {
  return MaterialApp(
    locale: const Locale('vi'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: PlacementTestScreen(
      levelApi: levelApi,
      client: client,
      onFinished: onFinished ?? () {},
    ),
  );
}

// ─── tests ───────────────────────────────────────────────────────────────────

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows loading indicator before session resolves', (
    tester,
  ) async {
    final api = _FakeLevelApi();
    // Never resolve — use a blocking stub
    bool started = false;
    api._startError = null;
    api._startResult = null;

    // Override with an actual delay-based stub inline.
    final blockingApi = _BlockingLevelApi();
    final client = _FakeApiClient()..stubGetMockExam(_sessionJson());

    await tester.pumpWidget(_wrap(levelApi: blockingApi, client: client));
    await tester.pump(); // one frame — future is pending

    expect(find.byKey(const Key('placement_test_loading')), findsOneWidget);
    expect(started, isFalse);

    // Let it settle (the blocking api will never return so we just verify the
    // loading key exists at this snapshot).
    blockingApi.complete(_startResult()); // unblock
    await tester.pumpAndSettle();
    // After unblock, session loads and exam renders.
    expect(find.byKey(const Key('placement_test_exam')), findsOneWidget);
  });

  testWidgets('shows error + retry CTA when startPlacement throws', (
    tester,
  ) async {
    final api =
        _FakeLevelApi()..stubStartError(
          const LevelApiException(
            statusCode: 503,
            code: 'unavailable',
            message: 'Service down',
          ),
        );
    final client = _FakeApiClient();

    await tester.pumpWidget(_wrap(levelApi: api, client: client));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('placement_test_error')), findsOneWidget);
    expect(find.byKey(const Key('placement_test_retry')), findsOneWidget);
  });

  testWidgets('renders MockExamScreen when session is ready', (tester) async {
    final api = _FakeLevelApi()..stubStart(_startResult());
    final client = _FakeApiClient()..stubGetMockExam(_sessionJson());

    await tester.pumpWidget(_wrap(levelApi: api, client: client));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('placement_test_loading')), findsNothing);
    expect(find.byKey(const Key('placement_test_error')), findsNothing);
    expect(find.byKey(const Key('placement_test_exam')), findsOneWidget);
  });

  testWidgets('placement exam surfaces submit action directly', (tester) async {
    final api = _FakeLevelApi()..stubStart(_startResult());
    final client = _FakeApiClient()..stubGetMockExam(_sessionJson());

    await tester.pumpWidget(_wrap(levelApi: api, client: client));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mock_exam_prominent_submit')), findsOneWidget);
    expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
  });

  testWidgets('completed placement result CTA calls onFinished', (
    tester,
  ) async {
    var finishedCalls = 0;
    final api = _FakeLevelApi()..stubStart(_startResult());
    final client =
        _FakeApiClient()..stubGetMockExam(_sessionJson(completed: true));

    await tester.pumpWidget(
      _wrap(
        levelApi: api,
        client: client,
        onFinished: () => finishedCalls += 1,
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Bắt đầu học'), 300);
    await tester.tap(find.text('Bắt đầu học'));
    await tester.pump();

    expect(finishedCalls, 1);
  });

  testWidgets('completed placement result CTA closes placement route', (
    tester,
  ) async {
    var finishedCalls = 0;
    const hostKey = Key('placement_host_screen');
    const openKey = Key('open_placement_test');
    final api = _FakeLevelApi()..stubStart(_startResult());
    final client =
        _FakeApiClient()..stubGetMockExam(_sessionJson(completed: true));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder:
              (context) => Scaffold(
                key: hostKey,
                body: FilledButton(
                  key: openKey,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder:
                            (_) => PlacementTestScreen(
                              levelApi: api,
                              client: client,
                              onFinished: () => finishedCalls += 1,
                            ),
                      ),
                    );
                  },
                  child: const Text('Open placement'),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.byKey(openKey));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('placement_test_exam')), findsOneWidget);
    expect(find.byKey(hostKey), findsNothing);

    await tester.scrollUntilVisible(find.text('Bắt đầu học'), 300);
    await tester.tap(find.text('Bắt đầu học'));
    await tester.pumpAndSettle();

    expect(finishedCalls, 1);
    expect(find.byKey(hostKey), findsOneWidget);
    expect(find.byKey(const Key('placement_test_exam')), findsNothing);
  });

  testWidgets('placement completion shows pass popup with current level', (
    tester,
  ) async {
    final api =
        _FakeLevelApi()
          ..stubStart(_startResult())
          ..stubComplete(_completeResult(level: CefrLevel.a2, scorePct: 60));
    final client =
        _FakeApiClient()
          ..stubGetMockExam(_sessionJson(completed: true, overallScore: 0))
          ..stubCompleteMockExam(
            _sessionJson(completed: true, overallScore: 60),
          );

    await tester.pumpWidget(_wrap(levelApi: api, client: client));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('placement_result_dialog')), findsOneWidget);
    expect(
      find.text('Chúc mừng, bạn đã vượt qua bài kiểm tra đầu vào!'),
      findsOneWidget,
    );
    expect(
      find.text('Cấp độ hiện tại của bạn là A2. Điểm phân loại: 60%.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Xem kết quả bài thi'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('placement_result_dialog')), findsNothing);
  });

  testWidgets('placement completion shows encouragement popup for A0', (
    tester,
  ) async {
    final api =
        _FakeLevelApi()
          ..stubStart(_startResult())
          ..stubComplete(_completeResult(level: CefrLevel.a0, scorePct: 7));
    final client =
        _FakeApiClient()
          ..stubGetMockExam(_sessionJson(completed: true, overallScore: 0))
          ..stubCompleteMockExam(
            _sessionJson(completed: true, overallScore: 7),
          );

    await tester.pumpWidget(_wrap(levelApi: api, client: client));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('placement_result_dialog')), findsOneWidget);
    expect(find.text('Cố gắng thêm một chút nhé'), findsOneWidget);
    expect(
      find.textContaining('Cấp độ hiện tại của bạn là A0. Điểm phân loại: 7%.'),
      findsOneWidget,
    );
  });

  testWidgets('retry CTA re-triggers startPlacement', (tester) async {
    int callCount = 0;
    final api = _CountingLevelApi(
      onCall: () {
        callCount++;
        if (callCount == 1) {
          throw const LevelApiException(
            statusCode: 503,
            code: 'unavailable',
            message: 'down',
          );
        }
        return _startResult();
      },
    );
    final client = _FakeApiClient()..stubGetMockExam(_sessionJson());

    await tester.pumpWidget(_wrap(levelApi: api, client: client));
    await tester.pumpAndSettle();

    // First call failed.
    expect(find.byKey(const Key('placement_test_error')), findsOneWidget);
    expect(callCount, 1);

    await tester.tap(find.byKey(const Key('placement_test_retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('placement_test_exam')), findsOneWidget);
    expect(callCount, 2);
  });
}

// ─── additional fake subclasses for controllable timing ───────────────────────

class _BlockingLevelApi extends _FakeLevelApi {
  final _completer = Completer<PlacementStartResult>();

  void complete(PlacementStartResult r) => _completer.complete(r);

  @override
  Future<PlacementStartResult> startPlacement({bool force = false}) =>
      _completer.future;
}

class _CountingLevelApi extends _FakeLevelApi {
  _CountingLevelApi({required this.onCall});

  final PlacementStartResult Function() onCall;

  @override
  Future<PlacementStartResult> startPlacement({bool force = false}) async =>
      onCall();
}
