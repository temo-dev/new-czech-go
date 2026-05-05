import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/exercise/widgets/dictation_ocr_preview_card.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('DictationOCRPreviewCard', () {
    testWidgets('pre-fills the editable field with OCR text and renders both buttons',
        (tester) async {
      await tester.pumpWidget(_wrap(DictationOCRPreviewCard(
        photoUrl: '',
        ocrText: 'Včera jsem byl v kavárně.',
        onRetake: () {},
        onConfirm: (_) {},
      )));
      // The TextField surfaces the OCR result for the learner to edit.
      expect(find.text('Včera jsem byl v kavárně.'), findsOneWidget);
      expect(find.text('Dùng văn bản này'), findsOneWidget);
      expect(find.text('Chụp lại'), findsOneWidget);
    });

    testWidgets('Confirm button fires onConfirm with the EDITED text', (tester) async {
      String? confirmed;
      await tester.pumpWidget(_wrap(DictationOCRPreviewCard(
        photoUrl: '',
        ocrText: 'kavarny',
        onRetake: () {},
        onConfirm: (text) => confirmed = text,
      )));
      // Clear and re-type with the missing diacritic restored.
      await tester.enterText(find.byType(TextField), 'kavárny');
      await tester.tap(find.text('Dùng văn bản này'));
      await tester.pumpAndSettle();
      expect(confirmed, 'kavárny');
    });

    testWidgets('Retake button fires onRetake', (tester) async {
      var retakes = 0;
      await tester.pumpWidget(_wrap(DictationOCRPreviewCard(
        photoUrl: '',
        ocrText: 'x',
        onRetake: () => retakes++,
        onConfirm: (_) {},
      )));
      await tester.tap(find.text('Chụp lại'));
      await tester.pumpAndSettle();
      expect(retakes, 1);
    });

    testWidgets('Loading state hides buttons and shows uploading hint',
        (tester) async {
      await tester.pumpWidget(_wrap(DictationOCRPreviewCard(
        photoUrl: '',
        ocrText: '',
        isUploading: true,
        uploadingHint: 'Đang nhận diện…',
        onRetake: () {},
        onConfirm: (_) {},
      )));
      // The buttons MUST be gone while the OCR call is in flight so the
      // learner cannot double-tap Confirm.
      expect(find.text('Dùng văn bản này'), findsNothing);
      expect(find.text('Chụp lại'), findsNothing);
      expect(find.text('Đang nhận diện…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('failedBanner is shown only when supplied', (tester) async {
      await tester.pumpWidget(_wrap(DictationOCRPreviewCard(
        photoUrl: '',
        ocrText: '',
        onRetake: () {},
        onConfirm: (_) {},
        failedBanner: 'Không nhận diện được. Hãy chụp lại hoặc gõ tay.',
      )));
      expect(
        find.text('Không nhận diện được. Hãy chụp lại hoặc gõ tay.'),
        findsOneWidget,
      );
    });

    testWidgets('does NOT render failedBanner when null', (tester) async {
      await tester.pumpWidget(_wrap(DictationOCRPreviewCard(
        photoUrl: '',
        ocrText: 'x',
        onRetake: () {},
        onConfirm: (_) {},
      )));
      // Loose assertion: the specific banner copy is absent. The fixture
      // catches accidental "always-on" banners that would penalize good OCR.
      expect(find.textContaining('Không nhận diện được'), findsNothing);
    });
  });
}
