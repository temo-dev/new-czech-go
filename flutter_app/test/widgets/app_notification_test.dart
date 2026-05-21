import 'package:flutter/material.dart';
import 'package:flutter_app/shared/widgets/app_notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppNotification renders warning banner with optional action', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppNotification.warning(
            title: 'Cảnh báo',
            message: 'Timer không dừng khi rời app.',
            actionLabel: 'Thử lại',
            onAction: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.text('Cảnh báo'), findsOneWidget);
    expect(find.text('Timer không dừng khi rời app.'), findsOneWidget);

    await tester.tap(find.text('Thử lại'));
    expect(tapped, isTrue);
  });

  testWidgets('AppNotification error tone keeps the message visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppNotification.error(message: 'Không tải được bài.'),
        ),
      ),
    );

    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(find.text('Không tải được bài.'), findsOneWidget);
  });
}
