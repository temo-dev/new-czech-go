import 'package:flutter/material.dart';
import 'package:flutter_app/core/api/api_client.dart';
import 'package:flutter_app/features/mock_exam/screens/mock_test_intro_screen.dart';
import 'package:flutter_app/l10n/generated/app_localizations.dart';
import 'package:flutter_app/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

const _mt = MockTest(
  id: 'mt-1',
  title: 'A2 Mock 1',
  description: 'Sample',
  estimatedDurationMinutes: 90,
  status: 'published',
  passThresholdPercent: 60,
  sections: [
    MockTestSection(
      sequenceNo: 1,
      skillKind: 'doc',
      exerciseId: 'ex-1',
      exerciseType: 'cteni_1',
      maxPoints: 5,
    ),
    MockTestSection(
      sequenceNo: 2,
      skillKind: 'noi',
      exerciseId: 'ex-2',
      exerciseType: 'uloha_1_topic_answers',
      maxPoints: 8,
    ),
  ],
);

void main() {
  testWidgets(
    'MockTestIntroScreen shows V39 no-pause timer warning banner',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MockTestIntroScreen(client: ApiClient(), test: _mt),
        ),
      );
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(
        find.textContaining('Timer KHÔNG dừng khi rời app'),
        findsOneWidget,
      );
    },
  );
}
