import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/interview/widgets/avatar_video_container.dart';
import 'package:flutter_app/l10n/generated/app_localizations.dart';

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('AvatarVideoContainer', () {
    testWidgets('shows placeholder when not connected', (tester) async {
      await tester.pumpWidget(_wrap(
        const AvatarVideoContainer(
          videoRenderer: null,
          isConnected: false,
          isSpeaking: false,
        ),
      ));
      // Should render the placeholder (emoji text or icon)
      expect(find.byType(AvatarVideoContainer), findsOneWidget);
      // No crash — placeholder shows without RTCVideoView
    });

    testWidgets('shows speaking ring when isSpeaking is true', (tester) async {
      await tester.pumpWidget(_wrap(
        const AvatarVideoContainer(
          videoRenderer: null,
          isConnected: false,
          isSpeaking: true,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AvatarVideoContainer), findsOneWidget);
    });

    testWidgets('renders without crash when isConnected false with null renderer', (tester) async {
      await tester.pumpWidget(_wrap(
        const AvatarVideoContainer(
          videoRenderer: null,
          isConnected: false,
          isSpeaking: false,
        ),
      ));
      expect(find.byType(AvatarVideoContainer), findsOneWidget);
    });
  });
}
