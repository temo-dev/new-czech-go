import 'package:flutter/material.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/apple_sign_in_button.dart';
import 'login_screen.dart';
import 'signup_screen.dart' show AuthServiceProvider, SignupScreen;

/// First-impression screen. Two CTAs (Đăng ký + Đăng nhập) and a brand
/// statement. Renders edge-to-edge on the brand cream surface so the
/// learner immediately sees the product personality before any form
/// asks for input.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, this.authServiceOverride});

  /// Tests pass this directly; production wires AuthService via the
  /// AppShell -> AuthServiceProvider widget.
  final AuthService? authServiceOverride;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                'Czech Go',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Luyện tiếng Czech A2 — đậu kỳ thi trvalý pobyt',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
              ),
              const Spacer(flex: 2),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SignupScreen()),
                ),
                child: const Text('Đăng ký miễn phí'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.secondary,
                  minimumSize: const Size.fromHeight(52),
                  side: const BorderSide(color: AppColors.outlineVariant),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                child: const Text('Đăng nhập'),
              ),
              const OrDivider(),
              AppleSignInButton(
                authService:
                    authServiceOverride ?? AuthServiceProvider.of(context),
                onSuccess: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
