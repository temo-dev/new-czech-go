import 'package:flutter/material.dart';

import '../../../core/auth/auth_models.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_notification.dart';
import '../widgets/apple_sign_in_button.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/password_field.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.authServiceOverride});

  final AuthService? authServiceOverride;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    _email.addListener(_rebuild);
    _password.addListener(_rebuild);
  }

  @override
  void dispose() {
    _email.removeListener(_rebuild);
    _password.removeListener(_rebuild);
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  AuthService get _service =>
      widget.authServiceOverride ?? AuthServiceProvider.of(context);

  bool get _canSubmit =>
      !_busy && _email.text.trim().isNotEmpty && _password.text.isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _busy = true;
      _serverError = null;
    });
    try {
      await _service.login(email: _email.text.trim(), password: _password.text);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _serverError = _humanize(e));
    } catch (_) {
      if (!mounted) return;
      setState(() => _serverError = 'Đăng nhập thất bại. Thử lại.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _humanize(AuthException e) {
    switch (e.code) {
      case 'invalid_credentials':
        return 'Email hoặc mật khẩu không đúng.';
      case 'too_many_attempts':
        return 'Quá nhiều lần thử. Vui lòng đợi 15 phút.';
      default:
        return e.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('Đăng nhập'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  controller: _email,
                  label: 'Email',
                  hint: 'ban@example.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [
                    AutofillHints.username,
                    AutofillHints.email,
                  ],
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _password,
                  label: 'Mật khẩu',
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed:
                        _busy
                            ? null
                            : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen(),
                              ),
                            ),
                    child: const Text('Quên mật khẩu?'),
                  ),
                ),
                const SizedBox(height: 8),
                if (_serverError != null) ...[
                  AppNotification.error(message: _serverError!),
                  const SizedBox(height: 16),
                ],
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _canSubmit ? _submit : null,
                  child:
                      _busy
                          ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onPrimary,
                            ),
                          )
                          : const Text(
                            'Đăng nhập',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                ),
                const OrDivider(),
                AppleSignInButton(
                  authService: _service,
                  onSuccess:
                      () => Navigator.of(context).popUntil((r) => r.isFirst),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed:
                      _busy
                          ? null
                          : () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const SignupScreen(),
                            ),
                          ),
                  child: const Text('Chưa có tài khoản? Đăng ký miễn phí'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
