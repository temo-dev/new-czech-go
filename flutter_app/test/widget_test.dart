import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/iap/iap_service.dart';
import 'package:flutter_app/core/iap/iap_service_provider.dart';
import 'package:flutter_app/core/locale/locale_provider.dart';
import 'package:flutter_app/main.dart';

void main() {
  testWidgets('app boots into learner shell', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final localeProvider = await LocaleProvider.load();
    await tester.pumpWidget(MluveniSprintApp(localeProvider: localeProvider));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('default app wires IAPServiceProvider with StubIAPService',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final localeProvider = await LocaleProvider.load();
    await tester.pumpWidget(MluveniSprintApp(localeProvider: localeProvider));

    // The provider sits inside MaterialApp.builder so it wraps every
    // navigator route — paywall + upgrade dialog can reach it.
    final providerFinder = find.byType(IAPServiceProvider);
    expect(providerFinder, findsOneWidget);

    final element = tester.element(providerFinder);
    final service = IAPServiceProvider.of(element);
    expect(service, isA<StubIAPService>());
  });
}
