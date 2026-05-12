import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/exercise/widgets/quizcard_widget.dart';
import 'package:flutter_app/l10n/generated/app_localizations.dart';

// V37 — QuizcardWidget gains an optional audioUrl. The mic button renders
// only when the URL is non-empty, so existing flashcards (no Polly TTS
// generated yet) don't grow a dead control.

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('vi'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('QuizcardWidget hides the audio button when audioUrl is null (V37)', (tester) async {
    await tester.pumpWidget(_wrap(QuizcardWidget(
      front: 'počasí',
      back: 'thời tiết',
      submitting: false,
      onChoice: (_) {},
    )));
    expect(find.byKey(const Key('quizcard_audio_button')), findsNothing);
  });

  testWidgets('QuizcardWidget hides the audio button when audioUrl is empty (V37)', (tester) async {
    await tester.pumpWidget(_wrap(QuizcardWidget(
      front: 'počasí',
      back: 'thời tiết',
      audioUrl: '',
      submitting: false,
      onChoice: (_) {},
    )));
    expect(find.byKey(const Key('quizcard_audio_button')), findsNothing);
  });

  testWidgets('QuizcardWidget renders the audio button when audioUrl is set (V37)', (tester) async {
    await tester.pumpWidget(_wrap(QuizcardWidget(
      front: 'počasí',
      back: 'thời tiết',
      audioUrl: 'https://example.test/audio.mp3',
      submitting: false,
      onChoice: (_) {},
    )));
    expect(find.byKey(const Key('quizcard_audio_button')), findsOneWidget);
  });
}
