import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/shared/widgets/app_button.dart';

/// CTA section shown at the bottom of the result screen.
///
/// - Anonymous user → prompt to save results by signing up
/// - Authenticated user → start learning / retake
class ResultCTASection extends StatelessWidget {
  const ResultCTASection({
    super.key,
    required this.isAuthenticated,
    required this.onSignup,
    required this.onLogin,
    required this.onRetake,
    required this.onGoToDashboard,
  });

  final bool isAuthenticated;
  final VoidCallback onSignup;
  final VoidCallback onLogin;
  final VoidCallback onRetake;
  final VoidCallback onGoToDashboard;

  @override
  Widget build(BuildContext context) {
    if (!isAuthenticated) {
      return _AnonymousCTA(
        onSignup: onSignup,
        onLogin: onLogin,
        onRetake: onRetake,
      );
    }
    return _AuthenticatedCTA(
      onGoToDashboard: onGoToDashboard,
      onRetake: onRetake,
    );
  }
}

// ── Anonymous ─────────────────────────────────────────────────────────────────

class _AnonymousCTA extends StatelessWidget {
  const _AnonymousCTA({
    required this.onSignup,
    required this.onLogin,
    required this.onRetake,
  });

  final VoidCallback onSignup;
  final VoidCallback onLogin;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Save result banner
        Container(
          padding: const EdgeInsets.all(AppSpacing.x4),
          decoration: BoxDecoration(
            color: AppColors.primaryFixed,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.bookmark_outline_rounded,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: AppSpacing.x2),
                  Text(
                    'Lưu kết quả của bạn',
                    style: AppTypography.titleSmall
                        .copyWith(color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x2),
              Text(
                'Đăng ký miễn phí để lưu kết quả vĩnh viễn, '
                'theo dõi tiến độ và nhận lộ trình học cá nhân.',
                style: AppTypography.bodySmall
                    .copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.x4),
              AppButton(
                key: const Key('result_signup_button'),
                label: 'Đăng ký miễn phí',
                onPressed: onSignup,
                icon: Icons.person_add_outlined,
              ),
              const SizedBox(height: AppSpacing.x2),
              Center(
                child: TextButton(
                  onPressed: onLogin,
                  child: Text(
                    'Đã có tài khoản? Đăng nhập',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x3),
        OutlinedButton.icon(
          onPressed: onRetake,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Làm lại bài thi'),
        ),
      ],
    );
  }
}

// ── Authenticated ─────────────────────────────────────────────────────────────

class _AuthenticatedCTA extends StatelessWidget {
  const _AuthenticatedCTA({
    required this.onGoToDashboard,
    required this.onRetake,
  });

  final VoidCallback onGoToDashboard;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton(
          label: 'Bắt đầu học ngay',
          onPressed: onGoToDashboard,
          icon: Icons.school_outlined,
        ),
        const SizedBox(height: AppSpacing.x3),
        OutlinedButton.icon(
          onPressed: onRetake,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Làm lại bài thi'),
        ),
      ],
    );
  }
}
