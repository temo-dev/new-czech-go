import 'package:flutter/material.dart';

import '../../../core/auth/auth_models.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/apple_sign_in_button.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/password_field.dart';
import 'login_screen.dart';

/// Signup form. The AuthService instance is fetched from the closest
/// [AuthServiceProvider] in the widget tree so test harnesses can
/// inject a fake service without a network round trip.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, this.authServiceOverride});

  /// Tests pass this directly; production wires AuthService via the
  /// AppShell -> AuthServiceProvider widget.
  final AuthService? authServiceOverride;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _busy = false;
  String? _serverError;

  @override
  void initState() {
    super.initState();
    _email.addListener(_rebuild);
    _password.addListener(_rebuild);
    _name.addListener(_rebuild);
  }

  @override
  void dispose() {
    _email.removeListener(_rebuild);
    _password.removeListener(_rebuild);
    _name.removeListener(_rebuild);
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  AuthService get _service =>
      widget.authServiceOverride ?? AuthServiceProvider.of(context);

  String? _validateEmail(String v) {
    final s = v.trim();
    if (s.isEmpty) return 'Vui lòng nhập email.';
    if (!s.contains('@') || !s.split('@').last.contains('.')) {
      return 'Email không hợp lệ.';
    }
    return null;
  }

  String? _validatePassword(String v) {
    if (v.length < 8) return 'Mật khẩu cần ít nhất 8 ký tự.';
    final hasNonLetter = v.runes.any((r) {
      final c = String.fromCharCode(r);
      return !RegExp(r'[A-Za-zÀ-ÿĀ-žẠ-ỹ]').hasMatch(c);
    });
    if (!hasNonLetter) return 'Cần ít nhất 1 chữ số hoặc ký tự đặc biệt.';
    return null;
  }

  bool get _canSubmit =>
      !_busy &&
      _validateEmail(_email.text) == null &&
      _validatePassword(_password.text) == null &&
      _name.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _busy = true;
      _serverError = null;
    });
    try {
      await _service.signup(
        email: _email.text.trim(),
        password: _password.text,
        displayName: _name.text.trim(),
      );
      if (!mounted) return;
      // AppShell rebuilds on AuthService state change; pop the welcome
      // stack so the back button does not return to the signup form.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _serverError = _humanize(e));
    } catch (e) {
      debugPrint('signup failed: $e');
      if (!mounted) return;
      setState(() => _serverError = 'Đăng ký thất bại: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _humanize(AuthException e) {
    switch (e.code) {
      case 'email_taken':
        return 'Email này đã được đăng ký. Hãy đăng nhập hoặc dùng email khác.';
      case 'invalid_email':
        return 'Email không hợp lệ.';
      case 'weak_password':
        return 'Mật khẩu chưa đủ mạnh. Cần ≥8 ký tự + chữ số/đặc biệt.';
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
        title: const Text('Đăng ký'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  controller: _name,
                  label: 'Họ tên',
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  autofocus: true,
                  onValidate: (v) => v.trim().isEmpty ? 'Vui lòng nhập tên.' : null,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _email,
                  label: 'Email',
                  hint: 'ban@example.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  onValidate: _validateEmail,
                ),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _password,
                  label: 'Mật khẩu',
                  helper: 'Tối thiểu 8 ký tự, gồm ít nhất 1 chữ số hoặc ký tự đặc biệt.',
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  onValidate: _validatePassword,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
                if (_serverError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _serverError!,
                      style: const TextStyle(color: AppColors.onErrorContainer),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _canSubmit ? _submit : null,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                        )
                      : const Text('Tạo tài khoản', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                const OrDivider(),
                AppleSignInButton(
                  authService: _service,
                  onSuccess: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        ),
                  child: const Text('Đã có tài khoản? Đăng nhập'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Inherited widget so screens can pull the live [AuthService] without
/// a global singleton + without route argument plumbing.
class AuthServiceProvider extends InheritedNotifier<AuthService> {
  const AuthServiceProvider({
    super.key,
    required AuthService service,
    required super.child,
  }) : super(notifier: service);

  static AuthService of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<AuthServiceProvider>();
    assert(provider != null, 'AuthServiceProvider missing from widget tree');
    return provider!.notifier!;
  }
}
