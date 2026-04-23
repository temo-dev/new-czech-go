import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/locale/locale_provider.dart';
import 'package:flutter_app/main.dart';

void main() {
  testWidgets('app boots into learner shell', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final localeProvider = await LocaleProvider.load();
    await tester.pumpWidget(MluveniSprintApp(localeProvider: localeProvider));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
