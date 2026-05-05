import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/api/api_client.dart';
import 'package:flutter_app/core/auth/auth_models.dart';
import 'package:flutter_app/core/auth/auth_service.dart';
import 'package:flutter_app/core/auth/auth_storage.dart';
import 'package:flutter_app/features/auth/screens/login_screen.dart';
import 'package:flutter_app/features/auth/screens/signup_screen.dart';
import 'package:flutter_app/features/auth/screens/welcome_screen.dart';

/// Fake AuthService used by widget tests so screens drive auth state
/// transitions without a real HTTP round-trip (which flutter_test's
/// fake clock pauses indefinitely).
class _FakeAuthService extends AuthService {
  _FakeAuthService(ApiClient api, AuthStorage storage)
      : super(apiClient: api, storage: storage);

  AuthSession? signupResult;
  AuthException? signupError;
  AuthSession? loginResult;
  AuthException? loginError;
  int signupCalls = 0;
  int loginCalls = 0;

  @override
  Future<AuthSession> signup({
    required String email,
    required String password,
    required String displayName,
  }) async {
    signupCalls++;
    if (signupError != null) throw signupError!;
    final s = signupResult ??
        AuthSession.fromJson({
          'user': {
            'id': 'u', 'email': email, 'email_verified': false,
            'display_name': displayName, 'role': 'learner',
            'pro_tier': 'free', 'grace_attempts_left': 3,
          },
          'session_token': 'tok',
          'expires_at': DateTime.now().toIso8601String(),
        });
    adoptUser(s.user);
    return s;
  }

  @override
  Future<AuthSession> login({required String email, required String password}) async {
    loginCalls++;
    if (loginError != null) throw loginError!;
    final s = loginResult ??
        AuthSession.fromJson({
          'user': {
            'id': 'u', 'email': email, 'email_verified': true,
            'display_name': 'X', 'role': 'learner',
            'pro_tier': 'free', 'grace_attempts_left': 999,
          },
          'session_token': 'tok',
          'expires_at': DateTime.now().toIso8601String(),
        });
    adoptUser(s.user);
    return s;
  }
}

Future<_FakeAuthService> _newFake() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final storage = await AuthStorage.create();
  return _FakeAuthService(ApiClient(baseUrl: 'http://127.0.0.1:1'), storage);
}

void main() {
  testWidgets('WelcomeScreen renders both CTAs', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
    expect(find.text('Đăng ký miễn phí'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsOneWidget);
    expect(find.text('Czech Go'), findsOneWidget);
  });

  testWidgets('SignupScreen submit disabled until form valid', (tester) async {
    final svc = await _newFake();
    await tester.pumpWidget(MaterialApp(home: SignupScreen(authServiceOverride: svc)));
    final submit = find.widgetWithText(FilledButton, 'Tạo tài khoản');
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.enterText(find.widgetWithText(TextField, 'Họ tên'), 'Anh');
    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'anh@x.com');
    await tester.enterText(find.widgetWithText(TextField, 'Mật khẩu'), 'Strong1Password!');
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
  });

  testWidgets('SignupScreen happy path adopts user', (tester) async {
    final svc = await _newFake();
    await tester.pumpWidget(MaterialApp(home: SignupScreen(authServiceOverride: svc)));

    await tester.enterText(find.widgetWithText(TextField, 'Họ tên'), 'Anh');
    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'anh@x.com');
    await tester.enterText(find.widgetWithText(TextField, 'Mật khẩu'), 'Strong1Password!');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Tạo tài khoản'));
    await tester.pumpAndSettle();
    expect(svc.signupCalls, 1);
    expect(svc.currentUser?.email, 'anh@x.com');
  });

  testWidgets('SignupScreen surfaces email_taken with localized text', (tester) async {
    final svc = await _newFake();
    svc.signupError = AuthException(statusCode: 409, code: 'email_taken', message: 'taken');

    await tester.pumpWidget(MaterialApp(home: SignupScreen(authServiceOverride: svc)));
    await tester.enterText(find.widgetWithText(TextField, 'Họ tên'), 'A');
    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'a@x.com');
    await tester.enterText(find.widgetWithText(TextField, 'Mật khẩu'), 'Strong1Password!');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Tạo tài khoản'));
    await tester.pumpAndSettle();
    expect(find.textContaining('đã được đăng ký'), findsOneWidget);
  });

  testWidgets('LoginScreen submit disabled until both fields filled', (tester) async {
    final svc = await _newFake();
    await tester.pumpWidget(MaterialApp(home: LoginScreen(authServiceOverride: svc)));
    final submit = find.widgetWithText(FilledButton, 'Đăng nhập');
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'a@x.com');
    await tester.enterText(find.widgetWithText(TextField, 'Mật khẩu'), 'pwd');
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
  });

  testWidgets('LoginScreen surfaces invalid_credentials', (tester) async {
    final svc = await _newFake();
    svc.loginError = AuthException(statusCode: 401, code: 'invalid_credentials', message: 'wrong');

    await tester.pumpWidget(MaterialApp(home: LoginScreen(authServiceOverride: svc)));
    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'a@x.com');
    await tester.enterText(find.widgetWithText(TextField, 'Mật khẩu'), 'wrong');
    await tester.pump(); // flush controller listener -> _canSubmit
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pumpAndSettle();
    expect(find.textContaining('không đúng'), findsOneWidget);
  });

  testWidgets('PasswordField hides input by default', (tester) async {
    final svc = await _newFake();
    await tester.pumpWidget(MaterialApp(home: LoginScreen(authServiceOverride: svc)));
    final pwdField = tester.widget<TextField>(find.widgetWithText(TextField, 'Mật khẩu'));
    expect(pwdField.obscureText, isTrue);

    await tester.tap(find.byTooltip('Hiện mật khẩu'));
    await tester.pump();
    final after = tester.widget<TextField>(find.widgetWithText(TextField, 'Mật khẩu'));
    expect(after.obscureText, isFalse);
  });
}
