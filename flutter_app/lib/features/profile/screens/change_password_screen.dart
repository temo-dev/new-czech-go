import 'package:flutter/material.dart';

import '../../../core/auth/auth_models.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_notification.dart';
import '../../auth/screens/signup_screen.dart' show AuthServiceProvider;
import '../../auth/widgets/password_field.dart';

/// Profile -> Đổi mật khẩu. Verifies the current password, then submits
/// the new password through the V17 change-password endpoint. The
/// backend revokes every session (including this device) so on success
/// the AuthService gets a 401 on its next call and routes back to the
/// Welcome stack — the screen does not need to drive that transition
/// itself.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, this.authServiceOverride});

  final AuthService? authServiceOverride;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _done = false;

  AuthService get _service =>
      widget.authServiceOverride ?? AuthServiceProvider.of(context);

  @override
  void initState() {
    super.initState();
    _current.addListener(_rebuild);
    _next.addListener(_rebuild);
  }

  @override
  void dispose() {
    _current.removeListener(_rebuild);
    _next.removeListener(_rebuild);
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  void _rebuild() => mounted ? setState(() {}) : null;

  bool get _canSubmit =>
      !_busy && _current.text.isNotEmpty && _next.text.length >= 8;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.apiClientForScreens.changePasswordV17(
        currentPassword: _current.text,
        newPassword: _next.text,
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
      case 'invalid_current_password':
        return 'Mật khẩu hiện tại không đúng.';
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
        title: const Text('Đổi mật khẩu'),
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
          Icons.check_circle_outline,
          size: 64,
          color: AppColors.success,
        ),
        const SizedBox(height: 16),
        const Text(
          'Đã đổi mật khẩu',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Mọi thiết bị khác đã bị đăng xuất. Bạn cần đăng nhập lại.',
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
          onPressed: () async {
            await _service.logout();
            if (!mounted) return;
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          child: const Text(
            'Đăng nhập lại',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PasswordField(controller: _current, label: 'Mật khẩu hiện tại'),
        const SizedBox(height: 16),
        PasswordField(
          controller: _next,
          label: 'Mật khẩu mới',
          helper:
              'Tối thiểu 8 ký tự, gồm ít nhất 1 chữ số hoặc ký tự đặc biệt.',
          autofillHints: const [AutofillHints.newPassword],
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
                    'Đổi mật khẩu',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
        ),
      ],
    );
  }
}
