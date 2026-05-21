import 'package:flutter/material.dart';

import '../../../core/auth/auth_models.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_notification.dart';
import '../../auth/screens/signup_screen.dart' show AuthServiceProvider;
import '../../auth/widgets/auth_text_field.dart';
import '../../auth/widgets/password_field.dart';

class EmailChangeScreen extends StatefulWidget {
  const EmailChangeScreen({super.key, this.authServiceOverride});

  final AuthService? authServiceOverride;

  @override
  State<EmailChangeScreen> createState() => _EmailChangeScreenState();
}

class _EmailChangeScreenState extends State<EmailChangeScreen> {
  final _newEmail = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _done = false;

  AuthService get _service =>
      widget.authServiceOverride ?? AuthServiceProvider.of(context);

  @override
  void initState() {
    super.initState();
    _newEmail.addListener(_rebuild);
    _password.addListener(_rebuild);
  }

  @override
  void dispose() {
    _newEmail.removeListener(_rebuild);
    _password.removeListener(_rebuild);
    _newEmail.dispose();
    _password.dispose();
    super.dispose();
  }

  void _rebuild() => mounted ? setState(() {}) : null;

  bool get _canSubmit =>
      !_busy && _newEmail.text.contains('@') && _password.text.isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.apiClientForScreens.changeEmailV17(
        newEmail: _newEmail.text.trim(),
        currentPassword: _password.text,
      );
      await _service.refresh();
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
      case 'email_taken':
        return 'Email này đã được dùng cho tài khoản khác.';
      case 'invalid_email':
        return 'Email mới không hợp lệ.';
      case 'invalid_current_password':
        return 'Mật khẩu hiện tại không đúng.';
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
        title: const Text('Đổi email'),
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
        const Icon(
          Icons.mark_email_read_outlined,
          size: 64,
          color: AppColors.secondary,
        ),
        const SizedBox(height: 16),
        const Text(
          'Đã cập nhật email',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Đã gửi link xác minh đến địa chỉ mới. Vui lòng mở email và click link để xác minh.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.onSurfaceVariant, height: 1.5),
        ),
        const SizedBox(height: 32),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Quay lại',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    final user = _service.currentUser;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (user != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Email hiện tại: ${user.email}',
              style: const TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ),
        AuthTextField(
          controller: _newEmail,
          label: 'Email mới',
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
        ),
        const SizedBox(height: 16),
        PasswordField(
          controller: _password,
          label: 'Mật khẩu hiện tại',
          autofillHints: const [AutofillHints.password],
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          AppNotification.error(message: _error!),
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
                    'Đổi email',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
        ),
      ],
    );
  }
}
