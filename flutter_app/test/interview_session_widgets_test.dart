import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/interview/widgets/session_status_pill.dart';
import 'package:flutter_app/features/interview/widgets/mic_waveform_widget.dart';
import 'package:flutter_app/l10n/generated/app_localizations.dart';

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('SessionStatusPill', () {
    testWidgets('connecting state shows amber dot and connecting text', (tester) async {
      await tester.pumpWidget(_wrap(
        const SessionStatusPill(state: InterviewSessionState.connecting),
      ));
      expect(find.byType(SessionStatusPill), findsOneWidget);
      // "Đang kết nối" should appear in text
      expect(find.textContaining('kết nối'), findsOneWidget);
    });

    testWidgets('speaking state shows orange dot and speaking text', (tester) async {
      await tester.pumpWidget(_wrap(
        const SessionStatusPill(state: InterviewSessionState.speaking),
      ));
      expect(find.textContaining('đang nói'), findsOneWidget);
    });

    testWidgets('listening state shows green dot and listening text', (tester) async {
      await tester.pumpWidget(_wrap(
        const SessionStatusPill(state: InterviewSessionState.listening),
      ));
      expect(find.textContaining('lắng nghe'), findsOneWidget);
    });

    testWidgets('ready state shows ready text', (tester) async {
      await tester.pumpWidget(_wrap(
        const SessionStatusPill(state: InterviewSessionState.ready),
      ));
      expect(find.textContaining('ẵn sàng'), findsOneWidget);
    });
  });

  group('MicWaveformWidget', () {
    testWidgets('renders without crash in active state', (tester) async {
      await tester.pumpWidget(_wrap(
        const MicWaveformWidget(isActive: true),
      ));
      expect(find.byType(MicWaveformWidget), findsOneWidget);
    });

    testWidgets('renders without crash in idle state', (tester) async {
      await tester.pumpWidget(_wrap(
        const MicWaveformWidget(isActive: false),
      ));
      expect(find.byType(MicWaveformWidget), findsOneWidget);
    });
  });
}
