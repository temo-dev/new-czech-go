import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/api/api_client.dart';
import 'package:flutter_app/core/auth/auth_service.dart';
import 'package:flutter_app/core/auth/auth_storage.dart';
import 'package:flutter_app/core/auth/deep_link_parser.dart';
import 'package:flutter_app/features/auth/screens/reset_password_screen.dart';
import 'package:flutter_app/features/auth/screens/verify_pending_screen.dart';

Future<AuthService> _newService() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final storage = await AuthStorage.create();
  return AuthService(apiClient: ApiClient(baseUrl: 'http://127.0.0.1:1'), storage: storage);
}

void main() {
  group('parseDeepLink', () {
    test('verified', () {
      final r = parseDeepLink(Uri.parse('czechgo://verified'));
      expect(r.kind, DeepLinkKind.verified);
    });

    test('reset with token', () {
      final r = parseDeepLink(Uri.parse('czechgo://reset?token=abc123'));
      expect(r.kind, DeepLinkKind.resetPassword);
      expect(r.token, 'abc123');
    });

    test('reset missing token -> unknown', () {
      final r = parseDeepLink(Uri.parse('czechgo://reset'));
      expect(r.kind, DeepLinkKind.unknown);
    });

    test('foreign scheme -> unknown', () {
      final r = parseDeepLink(Uri.parse('https://example.com/verified'));
      expect(r.kind, DeepLinkKind.unknown);
    });

    test('null uri -> unknown', () {
      expect(parseDeepLink(null).kind, DeepLinkKind.unknown);
    });
  });

  testWidgets('VerifyPendingScreen renders title + email + resend CTA', (tester) async {
    final svc = await _newService();
    await tester.pumpWidget(MaterialApp(home: VerifyPendingScreen(authServiceOverride: svc)));
    expect(find.textContaining('Xác minh email'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Gửi lại email'), findsOneWidget);
  });

  testWidgets('ResetPasswordScreen submit disabled until token + password',
      (tester) async {
    final svc = await _newService();
    await tester.pumpWidget(
      MaterialApp(home: ResetPasswordScreen(authServiceOverride: svc)),
    );
    final submit = find.widgetWithText(FilledButton, 'Đặt lại mật khẩu');
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.enterText(find.widgetWithText(TextField, 'Token'), 'abc-token');
    await tester.enterText(find.widgetWithText(TextField, 'Mật khẩu mới'), 'Strong1Password!');
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
  });

  testWidgets('ResetPasswordScreen prefilled token via initialToken arg',
      (tester) async {
    final svc = await _newService();
    await tester.pumpWidget(
      MaterialApp(
        home: ResetPasswordScreen(initialToken: 'deeplink-token', authServiceOverride: svc),
      ),
    );
    expect(find.text('deeplink-token'), findsOneWidget);
  });
}
