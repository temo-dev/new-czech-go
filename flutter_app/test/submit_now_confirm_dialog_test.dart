import 'package:flutter/material.dart';
import 'package:flutter_app/features/mock_exam/widgets/submit_now_confirm_dialog.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _trigger({
  required int unansweredCount,
  required int totalCount,
  required void Function(bool) onResult,
}) {
  return MaterialApp(
    home: Builder(
      builder: (ctx) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              final ok = await SubmitNowConfirmDialog.show(
                ctx,
                unansweredCount: unansweredCount,
                totalCount: totalCount,
              );
              onResult(ok);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('SubmitNowConfirmDialog', () {
    testWidgets('shows pending count + actions', (tester) async {
      await tester.pumpWidget(
        _trigger(unansweredCount: 5, totalCount: 24, onResult: (_) {}),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Nộp bài ngay?'), findsOneWidget);
      expect(find.textContaining('5/24 câu chưa làm'), findsOneWidget);
      expect(find.text('Quay lại'), findsOneWidget);
      expect(find.text('Nộp bài'), findsOneWidget);
    });

    testWidgets('confirm action returns true', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _trigger(
          unansweredCount: 3,
          totalCount: 24,
          onResult: (v) => result = v,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nộp bài'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('Quay lại returns false', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _trigger(
          unansweredCount: 3,
          totalCount: 24,
          onResult: (v) => result = v,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quay lại'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });
  });
}
