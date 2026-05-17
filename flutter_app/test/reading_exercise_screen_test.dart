import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/api/api_client.dart';
import 'package:flutter_app/features/exercise/screens/reading_exercise_screen.dart';
import 'package:flutter_app/l10n/generated/app_localizations.dart';
import 'package:flutter_app/models/models.dart';

class _FailingSubmitApi extends ApiClient {
  _FailingSubmitApi() : super(baseUrl: 'http://fake');

  @override
  Future<Map<String, dynamic>> createAttempt(
    String exerciseId, {
    String? locale,
  }) async {
    return {'id': 'attempt-1'};
  }

  @override
  Future<Map<String, dynamic>> submitAnswers(
    String attemptId,
    Map<String, String> answers,
  ) async {
    throw ApiException(
      statusCode: 422,
      errorCode: 'content_invalid',
      message: 'Exercise is missing correct answers.',
    );
  }
}

void main() {
  testWidgets(
    'ReadingExerciseScreen shows friendly content-invalid submit error',
    (tester) async {
      final detail = ExerciseDetail.fromJson({
        'id': 'ex-cteni-5',
        'title': 'Čtení 5',
        'exercise_type': 'cteni_5',
        'learner_instruction': '',
        'prompt': <String, dynamic>{},
        'assets': <dynamic>[],
        'detail': {
          'text': 'Hledám podnájemníka do pokoje v Praze 4.',
          'questions': [
            {'question_no': 21, 'prompt': 'Kdy je pokoj volný?'},
          ],
        },
      });

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ReadingExerciseScreen(
            client: _FailingSubmitApi(),
            detail: detail,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '1. června');
      await tester.pump();
      await tester.tap(find.text('Nộp đáp án'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Bài này đang thiếu đáp án trong hệ thống. Vui lòng báo admin.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('HttpException'), findsNothing);
    },
  );
}
