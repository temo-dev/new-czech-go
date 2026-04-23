import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_czech/core/router/app_routes.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/shared/widgets/app_button.dart';
import 'package:app_czech/shared/widgets/app_text_field.dart';
import '../providers/auth_notifier.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isSubmitting = authState.status == AuthFormStatus.submitting;

    // Navigation is handled by _RouterNotifier in app_router.dart which listens
    // to onAuthStateChange and redirects /auth/** → /app/dashboard automatically.
    // Calling context.go here too causes a redirect chain on iOS where the session
    // getter briefly returns null during the first GoRouter redirect evaluation.

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AuthAppBar(
        onBack: () =>
            context.canPop() ? context.pop() : context.go(AppRoutes.landing),
      ),
      body: Stack(
        children: [
          // Decorative blobs
          Positioned(
            bottom: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryContainer.withOpacity(0.05),
                ),
              ),
            ),
          ),
          Positioned(
            top: 80,
            left: -100,
            child: IgnorePointer(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.tertiaryFixed.withOpacity(0.08),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    children: [
                      // Login card
                      Container(
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
                            // Headline
                            Text(
                              'Chào mừng trở lại',
                              style: AppTypography.headlineLarge.copyWith(
                                color: AppColors.onBackground,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Đăng nhập để xem lại các bài thi thử đã làm.',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 40),

                            // Email field
                            AppTextField(
                              fieldKey: const Key('email_field'),
                              controller: _emailCtrl,
                              label: 'Email',
                              hint: 'example@email.com',
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 24),

                            // Password with "Quên mật khẩu?" inline in label row
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'MẬT KHẨU',
                                      style:
                                          AppTypography.labelUppercase.copyWith(
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                    InlineLinkButton(
                                      label: 'Quên mật khẩu?',
                                      onTap: () => context
                                          .push(AppRoutes.forgotPassword),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  key: const Key('password_field'),
                                  controller: _passwordCtrl,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.onBackground,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '••••••••',
                                    filled: true,
                                    fillColor: AppColors.surfaceContainerLowest,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                    border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.sm),
                                      borderSide: const BorderSide(
                                          color: AppColors.outlineVariant),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.sm),
                                      borderSide: const BorderSide(
                                          color: AppColors.outlineVariant),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.sm),
                                      borderSide: const BorderSide(
                                          color: AppColors.primary, width: 1.5),
                                    ),
                                    hintStyle:
                                        AppTypography.bodyMedium.copyWith(
                                      color: AppColors.onSurfaceVariant
                                          .withOpacity(0.5),
                                    ),
                                    suffixIcon: GestureDetector(
                                      onTap: () => setState(() =>
                                          _obscurePassword = !_obscurePassword),
                                      child: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        size: 20,
                                        color: AppColors.onSurfaceVariant
                                            .withOpacity(0.5),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Error message
                            if (authState.status == AuthFormStatus.authError ||
                                authState.status ==
                                    AuthFormStatus.validationError) ...[
                              const SizedBox(height: 12),
                              Text(
                                authState.errorMessage ?? '',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.error,
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),

                            // Submit button
                            AppButton(
                              key: const Key('login_button'),
                              label: 'Đăng nhập',
                              loading: isSubmitting,
                              onPressed: isSubmitting ? null : _submit,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Sign up link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Chưa có tài khoản? ',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          InlineLinkButton(
                            label: 'Đăng ký',
                            onTap: () => context.push(AppRoutes.signup),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    ref.read(authNotifierProvider.notifier).signIn(
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
        );
  }
}

class AuthAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AuthAppBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60 + MediaQuery.paddingOf(context).top,
      color: AppColors.surface,
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 56,
              height: 60,
              alignment: Alignment.center,
              child: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.primary,
                size: 24,
              ),
            ),
          ),
          // Brand center
          Expanded(
            child: Center(
              child: Text(
                'Sahara',
                style: AppTypography.headlineSmall.copyWith(
                  color: AppColors.primary,
                  fontSize: 24,
                ),
              ),
            ),
          ),
          // Spacer for symmetry
          const SizedBox(width: 56),
        ],
      ),
    );
  }
}
