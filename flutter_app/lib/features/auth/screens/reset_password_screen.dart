import 'package:flutter/material.dart';

import '../../../core/auth/auth_models.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/password_field.dart';
import 'login_screen.dart';
import 'signup_screen.dart' show AuthServiceProvider;

/// Consumes a one-shot reset token. Production reaches this screen via
/// the deep link `czechgo://reset?token=...` (registered in Info.plist
/// during the V17 cutover); the form also accepts a manually-pasted
/// token for desktop browsers and edge cases.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.initialToken, this.authServiceOverride});

  final String? initialToken;
  final AuthService? authServiceOverride;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  late final TextEditingController _token;
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _done = false;

  AuthService get _service => widget.authServiceOverride ?? AuthServiceProvider.of(context);

  @override
  void initState() {
    super.initState();
    _token = TextEditingController(text: widget.initialToken ?? '');
    _token.addListener(_rebuild);
    _password.addListener(_rebuild);
  }

  @override
  void dispose() {
    _token.removeListener(_rebuild);
    _password.removeListener(_rebuild);
    _token.dispose();
    _password.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  bool get _canSubmit =>
      !_busy && _token.text.trim().isNotEmpty && _password.text.length >= 8;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.apiClientForScreens.resetPasswordV17(
        token: _token.text.trim(),
        newPassword: _password.text,
      );
      if (!mounted) return;
      setState(() => _done = true);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = _humanize(e));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Có lỗi xảy ra. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _humanize(AuthException e) {
    switch (e.code) {
      case 'invalid_token':
        return 'Link đã hết hạn hoặc không còn hiệu lực. Vui lòng yêu cầu link mới.';
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
        title: const Text('Đặt lại mật khẩu'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: _done ? _buildDone() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildDone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        const Icon(Icons.check_circle_outline, size: 64, color: AppColors.success),
        const SizedBox(height: 16),
        const Text(
          'Đã đặt lại mật khẩu',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.secondary),
        ),
        const SizedBox(height: 12),
        const Text(
          'Mật khẩu của bạn đã được cập nhật. Hãy đăng nhập với mật khẩu mới.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.onSurfaceVariant, height: 1.5),
        ),
        const SizedBox(height: 32),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => route.isFirst,
          ),
          child: const Text('Đăng nhập', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Nhập token từ email + mật khẩu mới của bạn.',
          style: TextStyle(color: AppColors.onSurfaceVariant, height: 1.5),
        ),
        const SizedBox(height: 24),
        AuthTextField(
          controller: _token,
          label: 'Token',
          hint: 'Dán token từ email reset',
          autofocus: widget.initialToken == null,
        ),
        const SizedBox(height: 16),
        PasswordField(
          controller: _password,
          label: 'Mật khẩu mới',
          helper: 'Tối thiểu 8 ký tự, gồm ít nhất 1 chữ số hoặc ký tự đặc biệt.',
          autofillHints: const [AutofillHints.newPassword],
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(_error!, style: const TextStyle(color: AppColors.onErrorContainer)),
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
                  width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                )
              : const Text('Đặt lại mật khẩu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
