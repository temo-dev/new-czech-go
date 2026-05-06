import 'package:flutter/material.dart';
import 'package:flutter_app/features/progress/widgets/progress_empty_state.dart';
import 'package:flutter_app/features/progress/widgets/progress_error_state.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('ProgressEmptyState', () {
    testWidgets('renders title, body, and CTA button', (tester) async {
      await tester.pumpWidget(_wrap(
        ProgressEmptyState(
          title: 'Chưa có tiến độ',
          message: 'Hoàn thành 1 bài để xem điểm mạnh/yếu',
          ctaLabel: 'Bắt đầu học',
          onCta: () {},
        ),
      ));
      expect(find.text('Chưa có tiến độ'), findsOneWidget);
      expect(
        find.text('Hoàn thành 1 bài để xem điểm mạnh/yếu'),
        findsOneWidget,
      );
      expect(find.text('Bắt đầu học'), findsOneWidget);
    });

    testWidgets('CTA tap fires callback', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(
        ProgressEmptyState(
          title: 't',
          message: 'm',
          ctaLabel: 'Go',
          onCta: () => taps++,
        ),
      ));
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('renders without CTA when onCta is null', (tester) async {
      await tester.pumpWidget(_wrap(
        const ProgressEmptyState(
          title: 't',
          message: 'm',
        ),
      ));
      expect(find.byType(FilledButton), findsNothing);
    });
  });

  group('ProgressErrorState', () {
    testWidgets('renders title, message, and retry button', (tester) async {
      await tester.pumpWidget(_wrap(
        ProgressErrorState(
          title: 'Không tải được tiến độ',
          message: 'Kiểm tra mạng và thử lại',
          retryLabel: 'Thử lại',
          onRetry: () {},
        ),
      ));
      expect(find.text('Không tải được tiến độ'), findsOneWidget);
      expect(find.text('Kiểm tra mạng và thử lại'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    });

    testWidgets('retry tap fires callback', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(
        ProgressErrorState(
          title: 't',
          retryLabel: 'Retry',
          onRetry: () => taps++,
        ),
      ));
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('renders without retry when onRetry is null', (tester) async {
      await tester.pumpWidget(_wrap(
        const ProgressErrorState(title: 'oops'),
      ));
      expect(find.byType(OutlinedButton), findsNothing);
    });
  });
}
