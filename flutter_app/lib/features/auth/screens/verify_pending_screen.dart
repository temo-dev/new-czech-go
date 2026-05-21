import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/auth/auth_models.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_notification.dart';
import 'signup_screen.dart' show AuthServiceProvider;

/// Shown after signup (and inside the AppShell as a banner when grace is
/// exhausted). Displays a 60-second resend cooldown that ticks down so
/// the learner can see exactly when the next click is allowed.
class VerifyPendingScreen extends StatefulWidget {
  const VerifyPendingScreen({super.key, this.authServiceOverride});

  final AuthService? authServiceOverride;

  @override
  State<VerifyPendingScreen> createState() => _VerifyPendingScreenState();
}

class _VerifyPendingScreenState extends State<VerifyPendingScreen> {
  static const _cooldownSeconds = 60;

  Timer? _ticker;
  int _remaining = 0;
  bool _busy = false;
  String? _info;
  String? _error;

  AuthService get _service =>
      widget.authServiceOverride ?? AuthServiceProvider.of(context);

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _remaining = _cooldownSeconds;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining = _remaining - 1;
        if (_remaining <= 0) {
          _ticker?.cancel();
          _ticker = null;
        }
      });
    });
  }

  Future<void> _resend() async {
    if (_busy || _remaining > 0) return;
    setState(() {
      _busy = true;
      _info = null;
      _error = null;
    });
    try {
      await _service.apiClientForScreens.resendVerifyV17();
      if (!mounted) return;
      setState(() {
        _info = 'Đã gửi lại email xác minh.';
        _startCooldown();
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            e.code == 'cooldown'
                ? 'Vui lòng chờ ít giây trước khi gửi lại.'
                : e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Có lỗi xảy ra. Thử lại sau.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    await _service.logout();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final email = _service.currentUser?.email ?? 'email của bạn';
    final canResend = !_busy && _remaining <= 0;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              const Center(
                child: Icon(
                  Icons.mark_email_unread_outlined,
                  size: 80,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Xác minh email của bạn',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Đã gửi link xác minh đến\n$email\n\nMở email và click link để mở khóa toàn bộ tính năng.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              if (_info != null) AppNotification.success(message: _info!),
              if (_error != null) AppNotification.error(message: _error!),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: canResend ? _resend : null,
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
                        : Text(
                          _remaining > 0
                              ? 'Gửi lại sau ${_remaining}s'
                              : 'Gửi lại email',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _busy ? null : _logout,
                child: const Text('Đăng xuất và quay lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
