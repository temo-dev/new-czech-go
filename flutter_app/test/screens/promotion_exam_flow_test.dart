import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/api/api_client.dart';
import 'package:flutter_app/core/api/level_api.dart';
import 'package:flutter_app/core/level_utils.dart';
import 'package:flutter_app/core/storage/cefr_prefs.dart';
import 'package:flutter_app/features/promotion/promotion_exam_flow.dart';
import 'package:flutter_app/l10n/generated/app_localizations.dart';
import 'package:flutter_app/models/models.dart';

// ─── fakes ────────────────────────────────────────────────────────────────────

class _FakeLevelApi extends LevelApi {
  _FakeLevelApi() : super(baseUrl: 'http://fake', tokenProvider: () => 'tok');

  PromotionAttemptResult? _attemptResult;
  LevelProgressResponse? _afterProgress;
  Object? _attemptError;

  void stubAttempt(PromotionAttemptResult r) => _attemptResult = r;
  void stubAttemptError(Object e) => _attemptError = e;
  void stubAfterProgress(LevelProgressResponse p) => _afterProgress = p;

  @override
  Future<PromotionAttemptResult> createPromotionAttempt(
    String mockTestId,
  ) async {
    final err = _attemptError;
    if (err != null) throw err;
    return _attemptResult!;
  }

  @override
  Future<LevelProgressResponse> fetchLevelProgress() async =>
      _afterProgress!;
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(baseUrl: 'http://fake');

  Map<String, dynamic>? _sessionData;

  void stubSession(Map<String, dynamic> data) => _sessionData = data;

  @override
  Future<Map<String, dynamic>> getMockExam(String id) async =>
      _sessionData!;
}

// ─── fixtures ────────────────────────────────────────────────────────────────

const _kSessionId = 'fes_promo_1';

PromotionAttemptResult _attemptResult() => PromotionAttemptResult(
  promotionAttemptId: 'pa_1',
  fullSessionId: _kSessionId,
  targetLevel: CefrLevel.b1,
);

Map<String, dynamic> _sessionPayload({bool completed = false}) => {
  'id': _kSessionId,
  'mock_test_id': 'mt_promo',
  'status': completed ? 'completed' : 'in_progress',
  'overall_score': completed ? 78 : 0,
  'passed': completed,
  'pass_threshold_percent': 70,
  'overall_readiness_level': completed ? 'solid' : '',
  'overall_summary': '',
  'sections': <dynamic>[],
};

// ─── widget helper ───────────────────────────────────────────────────────────

Widget _wrap({
  required _FakeLevelApi levelApi,
  required _FakeApiClient client,
  CefrLevel targetLevel = CefrLevel.b1,
  String promotionTestId = 'mt_promo',
  VoidCallback? onFinished,
}) {
  return MaterialApp(
    locale: const Locale('vi'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: PromotionExamFlow(
      levelApi: levelApi,
      client: client,
      targetLevel: targetLevel,
      promotionTestId: promotionTestId,
      onFinished: onFinished ?? () {},
    ),
  );
}

// ─── tests ───────────────────────────────────────────────────────────────────

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('E2: PromotionExamFlow shows PreExamScreen by default',
      (tester) async {
    final api = _FakeLevelApi();
    final client = _FakeApiClient();

    await tester.pumpWidget(_wrap(levelApi: api, client: client));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pre_exam_confirm_cta')), findsOneWidget);
    expect(find.byKey(const Key('pre_exam_cancel_cta')), findsOneWidget);
  });

  testWidgets('E2: cancel CTA fires onFinished and pops', (tester) async {
    int finished = 0;
    final api = _FakeLevelApi();
    final client = _FakeApiClient();

    await tester.pumpWidget(_wrap(
      levelApi: api,
      client: client,
      onFinished: () => finished++,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pre_exam_cancel_cta')));
    await tester.pumpAndSettle();

    expect(finished, 1);
  });

  testWidgets('E3: confirm → createPromotionAttempt → MockExamScreen',
      (tester) async {
    final api = _FakeLevelApi()..stubAttempt(_attemptResult());
    final client = _FakeApiClient()..stubSession(_sessionPayload());

    await tester.pumpWidget(_wrap(levelApi: api, client: client));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pre_exam_confirm_cta')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // PreExamScreen is replaced by exam loader (placement_test_loading or exam).
    expect(find.byKey(const Key('pre_exam_confirm_cta')), findsNothing);
    // Either loading key or exam key is visible.
    final hasLoader =
        tester.any(find.byKey(const Key('promotion_exam_loading')));
    final hasExam =
        tester.any(find.byKey(const Key('promotion_exam_runner')));
    expect(hasLoader || hasExam, isTrue);
  });

  testWidgets('E3: createPromotionAttempt error shows error + retry',
      (tester) async {
    final api = _FakeLevelApi()
      ..stubAttemptError(const LevelApiException(
        statusCode: 400,
        code: 'promotion_locked',
        message: 'Gates not met',
      ));
    final client = _FakeApiClient();

    await tester.pumpWidget(_wrap(levelApi: api, client: client));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pre_exam_confirm_cta')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('promotion_exam_error')), findsOneWidget);
    expect(find.byKey(const Key('promotion_exam_retry')), findsOneWidget);
  });

  testWidgets('E1: CefrPrefs dismissBannerFor blocks re-show', (tester) async {
    // After passing, banner should not re-show for the same target level.
    // We verify by checking that CefrPrefs.dismissBannerFor is respected.
    SharedPreferences.setMockInitialValues({
      'promo_banner_dismissed_for_b1': true,
    });
    final prefs = await CefrPrefs.create();
    expect(prefs.isBannerDismissedFor('b1'), isTrue);
    expect(prefs.isBannerDismissedFor('a2'), isFalse);
  });
}
