import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/shared/widgets/app_button.dart';
import 'package:app_czech/shared/widgets/app_text_field.dart';
import '../providers/auth_notifier.dart';
import 'login_screen.dart' show AuthAppBar;

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends ConsumerState<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isSubmitting = authState.status == AuthFormStatus.submitting;
    final isSuccess = authState.status == AuthFormStatus.success;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AuthAppBar(
        onBack: () => context.canPop() ? context.pop() : null,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.outlineVariant.withOpacity(0.6),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3A302A).withOpacity(0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Icon
                    Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.primaryFixed,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: const Icon(
                          Icons.lock_reset_rounded,
                          color: AppColors.primary,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Quên mật khẩu',
                      style: AppTypography.headlineMedium.copyWith(
                        color: AppColors.onBackground,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nhập email đăng ký của bạn. Chúng tôi sẽ gửi link đặt lại mật khẩu.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    if (isSuccess) ...[
                      // Success state
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4), // green-50
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(
                            color: const Color(0xFF16A34A).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF16A34A),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Email đặt lại mật khẩu đã được gửi. Vui lòng kiểm tra hộp thư.',
                                style: AppTypography.bodySmall.copyWith(
                                  color: const Color(0xFF166534),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: InlineLinkButton(
                          label: 'Quay lại đăng nhập',
                          onTap: () => context.pop(),
                        ),
                      ),
                    ] else ...[
                      // Form state
                      AppTextField(
                        controller: _emailCtrl,
                        label: 'Email',
                        hint: 'ten@email.com',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        prefixIcon: Icons.mail_outline_rounded,
                        onSubmitted: (_) => _submit(),
                      ),

                      if (authState.status == AuthFormStatus.authError ||
                          authState.status == AuthFormStatus.validationError) ...[
                        const SizedBox(height: 12),
                        Text(
                          authState.errorMessage ?? '',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ],

                      const SizedBox(height: 28),

                      AppButton(
                        label: 'Gửi link đặt lại mật khẩu',
                        loading: isSubmitting,
                        onPressed: isSubmitting ? null : _submit,
                        icon: Icons.send_rounded,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    ref
        .read(authNotifierProvider.notifier)
        .sendPasswordReset(_emailCtrl.text);
  }
}
