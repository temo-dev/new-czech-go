import 'package:flutter/material.dart';
import 'package:flutter_app/features/mock_exam/models/exam_section_state.dart';
import 'package:flutter_app/features/mock_exam/widgets/question_status_chip.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('QuestionStatusChip', () {
    testWidgets('renders label for every state', (tester) async {
      for (final state in SectionState.values) {
        await tester.pumpWidget(
          _wrap(QuestionStatusChip(label: '7', state: state)),
        );
        expect(find.text('7'), findsOneWidget);
      }
    });

    testWidgets('done state shows check icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const QuestionStatusChip(label: '1', state: SectionState.done),
        ),
      );
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('skipped state shows block icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const QuestionStatusChip(label: '2', state: SectionState.skipped),
        ),
      );
      expect(find.byIcon(Icons.block_rounded), findsOneWidget);
    });

    testWidgets('empty state has no leading icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const QuestionStatusChip(label: '3', state: SectionState.empty),
        ),
      );
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      expect(find.byIcon(Icons.block_rounded), findsNothing);
    });

    testWidgets('onTap fires when wired', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          QuestionStatusChip(
            label: '4',
            state: SectionState.empty,
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.tap(find.text('4'));
      expect(tapped, isTrue);
    });
  });
}
