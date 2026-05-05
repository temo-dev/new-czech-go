import 'package:flutter/material.dart';

import '../../../core/auth/auth_models.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/auth_text_field.dart';
import 'signup_screen.dart' show AuthServiceProvider;

/// "Quên mật khẩu" form. Server always returns 200 (no leak), so the
/// success copy intentionally says "if the email is on file" rather
/// than confirming the address exists.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.apiCallOverride});

  /// Tests inject this to bypass the AuthService -> ApiClient chain.
  /// Production reaches the live ApiClient via AuthServiceProvider.
  final Future<void> Function(String email)? apiCallOverride;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final value = _email.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.apiCallOverride != null) {
        await widget.apiCallOverride!(value);
      } else {
        // The AuthService does not own forgot-password (it does not
        // require authentication and does not change auth state); reach
        // the ApiClient directly via the provider's notifier.
        // ignore: invalid_use_of_visible_for_testing_member
        final svc = AuthServiceProvider.of(context);
        // svc has no public api for forgot — call the underlying client
        // through a small helper exposed for this screen's needs.
        await _ForgotPasswordBackdoor.send(svc, value);
      }
      if (!mounted) return;
      setState(() => _sent = true);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Có lỗi xảy ra. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('Quên mật khẩu'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: _sent ? _buildSent() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildSent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        const Icon(Icons.mark_email_read_outlined, size: 64, color: AppColors.secondary),
        const SizedBox(height: 16),
        const Text(
          'Đã gửi link đặt lại mật khẩu',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.secondary),
        ),
        const SizedBox(height: 12),
        const Text(
          'Nếu email được đăng ký, bạn sẽ nhận được email với link đặt lại trong vài phút. Hãy kiểm tra cả thư mục spam.',
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Quay lại đăng nhập', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Nhập email tài khoản. Chúng tôi sẽ gửi link đặt lại mật khẩu.',
          style: TextStyle(color: AppColors.onSurfaceVariant, height: 1.5),
        ),
        const SizedBox(height: 24),
        AuthTextField(
          controller: _email,
          label: 'Email',
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 16),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(_error!, style: const TextStyle(color: AppColors.error)),
          ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                )
              : const Text('Gửi link đặt lại', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

/// Tiny helper that gives ForgotPasswordScreen access to the underlying
/// ApiClient via the AuthService instance. Keeps the main AuthService
/// API focused on state-changing operations while still avoiding a
/// global ApiClient singleton.
class _ForgotPasswordBackdoor {
  static Future<void> send(AuthService svc, String email) async {
    // Use Dart reflection on the private field would be ugly; instead,
    // AuthService exposes `apiClient` for screens that need read-only
    // access. For V17 we reach through a static helper that reads the
    // ApiClient via a public accessor.
    await svc.apiClientForScreens.forgotPasswordV17(email);
  }
}
