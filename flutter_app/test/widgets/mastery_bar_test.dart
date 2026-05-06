import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_app/core/theme/app_colors.dart';
import 'package:flutter_app/features/progress/widgets/mastery_bar.dart';
import 'package:flutter_app/features/progress/widgets/skill_mastery_row.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool disableAnimations = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

Color _fillColorFor(WidgetTester tester) {
  final box = tester.widget<ColoredBox>(
    find.byKey(MasteryBar.fillKey),
  );
  return box.color;
}

void main() {
  group('MasteryBar fill colour by band', () {
    testWidgets('needs_work → scorePoor', (tester) async {
      await tester.pumpWidget(_wrap(
        const MasteryBar(mastery: 0.20, band: 'needs_work'),
      ));
      await tester.pumpAndSettle();
      expect(_fillColorFor(tester), AppColors.scorePoor);
    });

    testWidgets('learning → scoreFair', (tester) async {
      await tester.pumpWidget(_wrap(
        const MasteryBar(mastery: 0.55, band: 'learning'),
      ));
      await tester.pumpAndSettle();
      expect(_fillColorFor(tester), AppColors.scoreFair);
    });

    testWidgets('solid → scoreGood', (tester) async {
      await tester.pumpWidget(_wrap(
        const MasteryBar(mastery: 0.75, band: 'solid'),
      ));
      await tester.pumpAndSettle();
      expect(_fillColorFor(tester), AppColors.scoreGood);
    });

    testWidgets('ready → scoreExcellent', (tester) async {
      await tester.pumpWidget(_wrap(
        const MasteryBar(mastery: 0.92, band: 'ready'),
      ));
      await tester.pumpAndSettle();
      expect(_fillColorFor(tester), AppColors.scoreExcellent);
    });

    testWidgets('unknown band falls back to needs_work colour', (tester) async {
      await tester.pumpWidget(_wrap(
        const MasteryBar(mastery: 0.10, band: 'wat'),
      ));
      await tester.pumpAndSettle();
      expect(_fillColorFor(tester), AppColors.scorePoor);
    });
  });

  testWidgets('MasteryBar clamps mastery to [0,1]', (tester) async {
    await tester.pumpWidget(_wrap(
      const MasteryBar(mastery: 1.5, band: 'ready'),
    ));
    await tester.pumpAndSettle();
    final bar = tester.widget<FractionallySizedBox>(
      find.byKey(MasteryBar.fractionKey),
    );
    expect(bar.widthFactor, 1.0);
  });

  testWidgets('MasteryBar exposes Semantics label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(
      const MasteryBar(
        mastery: 0.50,
        band: 'learning',
        semanticsLabel: 'Tiến độ Nói 50%',
      ),
    ));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Tiến độ Nói 50%'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('MasteryBar reduced-motion paints final value immediately',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const MasteryBar(mastery: 0.80, band: 'solid'),
      disableAnimations: true,
    ));
    // Without pumpAndSettle: with disableAnimations the duration is zero so
    // the fill should already be at its final widthFactor on the first frame.
    final bar = tester.widget<FractionallySizedBox>(
      find.byKey(MasteryBar.fractionKey),
    );
    expect(bar.widthFactor, closeTo(0.80, 1e-6));
  });

  group('SkillMasteryRow', () {
    testWidgets('renders label, percent text, and 56dp min height',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const SkillMasteryRow(
          label: 'Nói',
          mastery: 0.62,
          band: 'learning',
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Nói'), findsOneWidget);
      expect(find.text('62%'), findsOneWidget);
      final box = tester.widget<ConstrainedBox>(
        find.byKey(SkillMasteryRow.constraintsKey),
      );
      expect(box.constraints.minHeight, 56);
    });

    testWidgets('tap triggers onTap callback', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(
        SkillMasteryRow(
          label: 'Nghe',
          mastery: 0.30,
          band: 'needs_work',
          onTap: () => taps++,
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SkillMasteryRow));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('merges semantics into a single tappable node',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(
        SkillMasteryRow(
          label: 'Đọc',
          mastery: 0.91,
          band: 'ready',
          semanticsLabel: 'Đọc, sẵn sàng, 91 phần trăm',
          onTap: () {},
        ),
      ));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Đọc, sẵn sàng, 91 phần trăm'),
        findsOneWidget,
      );
      final semNode = tester.getSemantics(
        find.bySemanticsLabel('Đọc, sẵn sàng, 91 phần trăm'),
      );
      expect(semNode.hasFlag(SemanticsFlag.isButton), isTrue);
      handle.dispose();
    });

    testWidgets('percent text uses tabular figures', (tester) async {
      await tester.pumpWidget(_wrap(
        const SkillMasteryRow(
          label: 'Viết',
          mastery: 0.45,
          band: 'learning',
        ),
      ));
      await tester.pumpAndSettle();
      final txt = tester.widget<Text>(find.text('45%'));
      final features = txt.style?.fontFeatures ?? const <FontFeature>[];
      expect(
        features.any((f) => f.feature == 'tnum'),
        isTrue,
        reason: 'percent text must enable tabular figures',
      );
    });
  });
}
