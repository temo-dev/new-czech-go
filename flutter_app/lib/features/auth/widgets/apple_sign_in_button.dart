import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/auth/auth_models.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_notification.dart';

/// V25 — Sign-in-with-Apple CTA. Wraps the package widget with a
/// busy spinner + inline error band so each consumer screen does not
/// re-implement the same try/catch.
///
/// Apple App Store guideline 4.8 mandates equal prominence with the
/// email signup CTA; the parent screen places it directly under the
/// existing FilledButton with an [_OrDivider] separator.
class AppleSignInButton extends StatefulWidget {
  const AppleSignInButton({
    super.key,
    required this.authService,
    this.onSuccess,
  });

  final AuthService authService;

  /// Fired once the AuthService has minted a session and adopted the
  /// user. Screens use this to pop their navigator stack so the user
  /// lands on the main shell.
  final VoidCallback? onSuccess;

  @override
  State<AppleSignInButton> createState() => _AppleSignInButtonState();
}

class _AppleSignInButtonState extends State<AppleSignInButton> {
  bool _busy = false;
  String? _error;

  Future<void> _onPressed() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.authService.signInWithApple();
      if (!mounted) return;
      widget.onSuccess?.call();
    } on AuthException catch (e) {
      if (!mounted) return;
      // Canceled is a normal user action — do not surface it as an error.
      if (e.code == 'sign_in_canceled') {
        setState(() => _busy = false);
        return;
      }
      setState(() {
        _error = _humanize(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = 'Đăng nhập với Apple thất bại. Vui lòng thử lại.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _humanize(AuthException e) {
    switch (e.code) {
      case 'invalid_credential':
        return 'Apple không trả về thông tin hợp lệ. Vui lòng thử lại.';
      case 'invalid_token':
      case 'expired_token':
      case 'invalid_audience':
      case 'issuer_mismatch':
      case 'nonce_mismatch':
        return 'Phiên đăng nhập Apple không hợp lệ. Vui lòng thử lại.';
      case 'apple_disabled':
        return 'Đăng nhập với Apple chưa khả dụng.';
      default:
        return e.message.isNotEmpty
            ? e.message
            : 'Đăng nhập với Apple thất bại.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_busy)
          // While the native Apple sheet is up + the verify roundtrip
          // is in flight, render a disabled black surface that matches
          // the Apple button footprint so layout does not jump.
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          )
        else
          SignInWithAppleButton(
            key: const Key('sign_in_with_apple_button'),
            onPressed: _onPressed,
            style: SignInWithAppleButtonStyle.black,
            height: 52,
            borderRadius: BorderRadius.circular(12),
          ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          AppNotification.error(message: _error!),
        ],
      ],
    );
  }
}

/// "── hoặc ──" separator between the email CTA and the Apple button.
/// Kept in the same widget file so both layouts ship together.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(
            child: Divider(color: AppColors.outlineVariant, thickness: 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'hoặc',
              style: const TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ),
          const Expanded(
            child: Divider(color: AppColors.outlineVariant, thickness: 1),
          ),
        ],
      ),
    );
  }
}
