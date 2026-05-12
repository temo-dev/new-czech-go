import 'package:flutter/material.dart';
import 'package:flutter_app/features/mock_exam/widgets/rerecord_confirm_dialog.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _trigger(void Function(bool) onResult) {
  return MaterialApp(
    home: Builder(
      builder: (ctx) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              final ok = await RerecordConfirmDialog.show(ctx);
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
  group('RerecordConfirmDialog', () {
    testWidgets('renders title + body + both action buttons', (tester) async {
      await tester.pumpWidget(_trigger((_) {}));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Ghi đè recording cũ?'), findsOneWidget);
      expect(find.textContaining('không thể hoàn tác'), findsOneWidget);
      expect(find.text('Huỷ'), findsOneWidget);
      expect(find.text('Ghi đè'), findsOneWidget);
    });

    testWidgets('confirm action returns true', (tester) async {
      bool? result;
      await tester.pumpWidget(_trigger((v) => result = v));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ghi đè'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('cancel action returns false', (tester) async {
      bool? result;
      await tester.pumpWidget(_trigger((v) => result = v));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Huỷ'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('barrier dismiss returns false (no choice = no overwrite)', (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(_trigger((v) => result = v));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      // Tap the modal barrier outside the dialog.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });
  });
}
