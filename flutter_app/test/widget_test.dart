import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/main.dart';

void main() {
  testWidgets('app boots into learner shell', (WidgetTester tester) async {
    await tester.pumpWidget(const MluveniSprintApp());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
