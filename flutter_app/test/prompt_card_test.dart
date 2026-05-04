import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/interview/widgets/prompt_card.dart';
import 'package:flutter_app/l10n/generated/app_localizations.dart';

Widget _wrap(Widget child, {bool reduceMotion = false}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: MaterialApp(
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('InterviewPromptCard', () {
    testWidgets('mounts expanded with body text visible', (tester) async {
      await tester.pumpWidget(_wrap(const InterviewPromptCard(
        body: 'Mô tả công việc bạn muốn làm.',
      )));
      await tester.pump();

      expect(find.text('Mô tả công việc bạn muốn làm.'), findsOneWidget);
      expect(find.textContaining('ĐỀ BÀI'), findsOneWidget);
    });

    testWidgets('hides when body is empty', (tester) async {
      await tester.pumpWidget(_wrap(const InterviewPromptCard(body: '')));
      await tester.pump();

      expect(find.textContaining('ĐỀ BÀI'), findsNothing);
      expect(find.byType(Material), findsOneWidget); // Scaffold material
    });

    testWidgets('auto-collapses to mini pill after autoCollapseAfter', (tester) async {
      await tester.pumpWidget(_wrap(const InterviewPromptCard(
        body: 'Task body',
        autoCollapseAfter: Duration(milliseconds: 100),
      )));
      await tester.pump();
      expect(find.text('Task body'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 250)); // animation
      expect(find.text('Task body'), findsNothing);
      expect(find.text('Tap để xem đề bài'), findsOneWidget);
    });

    testWidgets('tap mini pill restores expanded state', (tester) async {
      await tester.pumpWidget(_wrap(const InterviewPromptCard(
        body: 'Task body',
        autoCollapseAfter: Duration(milliseconds: 50),
      )));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pump(const Duration(milliseconds: 250));

      await tester.tap(find.text('Tap để xem đề bài'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Task body'), findsOneWidget);
    });

    testWidgets('shows choiceTitle and choiceContent when provided', (tester) async {
      await tester.pumpWidget(_wrap(const InterviewPromptCard(
        body: 'Generic body should not appear',
        choiceTitle: 'B — Y tá',
        choiceContent: 'Mô tả công việc y tá ở Séc.',
      )));
      await tester.pump();

      expect(find.text('B — Y tá'), findsOneWidget);
      expect(find.text('Mô tả công việc y tá ở Séc.'), findsOneWidget);
      expect(find.text('Generic body should not appear'), findsNothing);
    });

    testWidgets('first onAgentResponseComplete is silent (no pulse)', (tester) async {
      final key = GlobalKey<InterviewPromptCardState>();
      await tester.pumpWidget(_wrap(InterviewPromptCard(
        key: key,
        body: 'Task',
      )));
      await tester.pump();

      key.currentState!.onAgentResponseComplete();
      await tester.pump();

      // Pulse controller still at 0 — no animation triggered.
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('second onAgentResponseComplete triggers pulse animation', (tester) async {
      final key = GlobalKey<InterviewPromptCardState>();
      await tester.pumpWidget(_wrap(InterviewPromptCard(
        key: key,
        body: 'Task',
      )));
      await tester.pump();

      key.currentState!.onAgentResponseComplete(); // skipped
      key.currentState!.onAgentResponseComplete(); // pulse
      await tester.pump();

      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('reduced motion disables pulse and switcher animation', (tester) async {
      final key = GlobalKey<InterviewPromptCardState>();
      await tester.pumpWidget(_wrap(
        InterviewPromptCard(key: key, body: 'Task'),
        reduceMotion: true,
      ));
      await tester.pump();

      key.currentState!.onAgentResponseComplete();
      key.currentState!.onAgentResponseComplete();
      await tester.pump();

      // No running animation despite second call (reduced motion path).
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
