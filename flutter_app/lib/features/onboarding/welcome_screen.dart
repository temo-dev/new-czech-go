import 'package:flutter/material.dart';

import 'package:flutter_app/core/theme/app_colors.dart';
import 'package:flutter_app/core/theme/app_spacing.dart';

/// WelcomeScreen is the first screen a fresh-install learner sees. Two
/// outcomes:
///   - "Bắt đầu kiểm tra"  → routes the learner into the placement test
///                           (caller wires the navigation).
///   - "Bỏ qua"            → skip placement; learner lands on A0 with
///                           the lower bound of the ladder unlocked.
///
/// Pure presentation — Navigator interactions belong to the caller (D9
/// router gate).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.onStart,
    required this.onSkip,
  });

  final VoidCallback onStart;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x6,
            vertical: AppSpacing.x6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Text(
                'Chào mừng đến với\nA2 Mluvení Sprint',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: AppSpacing.x3),
              const Text(
                'Trước khi bắt đầu, bạn có thể làm bài kiểm tra phân loại '
                'để app chọn cấp độ phù hợp (≈12 phút).',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              ElevatedButton(
                key: const Key('onboarding_welcome_start_cta'),
                onPressed: onStart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.x3)),
                ),
                child: const Text(
                  'Bắt đầu kiểm tra phân loại',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: AppSpacing.x2),
              TextButton(
                key: const Key('onboarding_welcome_skip_cta'),
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.onSurfaceVariant,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text(
                  'Bỏ qua — bắt đầu từ A0',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
