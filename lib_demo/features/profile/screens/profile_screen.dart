import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_czech/core/router/app_routes.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/shared/providers/auth_provider.dart';
import 'package:app_czech/shared/widgets/loading_shimmer.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      primary: false,
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          Expanded(
            child: userAsync.when(
              loading: () => const ShimmerCardList(count: 5),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48),
                    const SizedBox(height: 16),
                    Text('Không tải được hồ sơ.',
                        style: AppTypography.bodyMedium),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => ref.refresh(currentUserProvider),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
              data: (user) {
                if (user == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    context.go(AppRoutes.landing);
                  });
                  return const SizedBox.shrink();
                }
                return _ProfileContent(
                  user: user,
                  onSignOut: () async {
                    await ref.read(currentUserProvider.notifier).signOut();
                    if (context.mounted) context.go(AppRoutes.landing);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Profile Content ───────────────────────────────────────────────────────────

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.user, required this.onSignOut});
  final dynamic user; // AppUser
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 448),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _UserHeader(user: user),
            const SizedBox(height: 32),
            _StatsGrid(
              streak: user.currentStreakDays ?? 0,
              xp: user.totalXp ?? 0,
            ),
            const SizedBox(height: 32),
            _ActiveCourseSection(),
            const SizedBox(height: 32),
            _QuickLinksSection(context: context),
            const SizedBox(height: 32),
            _AccountSection(context: context),
            const SizedBox(height: 32),
            _LogoutButton(onSignOut: onSignOut),
            const SizedBox(height: 32),
            Text(
              'TRVALÝ EXAM VERSION 2.4.0',
              style: AppTypography.labelUppercase.copyWith(
                color: AppColors.outline.withOpacity(0.6),
                fontSize: 9,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _UserHeader extends StatelessWidget {
  const _UserHeader({required this.user});
  final dynamic user;

  @override
  Widget build(BuildContext context) {
    final name = (user.displayName as String?) ?? 'Học viên';
    final email = (user.email as String?) ?? '';
    final avatarUrl = user.avatarUrl as String?;

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.2), width: 2),
                color: AppColors.surfaceContainerLow,
              ),
              child: ClipOval(
                child: avatarUrl != null
                    ? Image.network(avatarUrl, fit: BoxFit.cover)
                    : Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: AppTypography.headlineLarge.copyWith(
                            color: AppColors.primary,
                            fontSize: 36,
                          ),
                        ),
                      ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(Icons.edit_rounded,
                    color: Colors.white, size: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          name,
          style: AppTypography.headlineSmall.copyWith(fontSize: 28),
        ),
        const SizedBox(height: 4),
        Text(
          email,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.streak, required this.xp});
  final int streak;
  final int xp;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            iconColor: AppColors.primary,
            iconBgColor: AppColors.primary.withOpacity(0.1),
            icon: Icons.local_fire_department_rounded,
            label: 'CHUỖI NGÀY',
            value: '$streak ngày',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            iconColor: AppColors.tertiary,
            iconBgColor: AppColors.tertiary.withOpacity(0.1),
            icon: Icons.stars_rounded,
            label: 'ĐIỂM TÍCH LŨY',
            value: '$xp XP',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.iconColor,
    required this.iconBgColor,
    required this.icon,
    required this.label,
    required this.value,
  });
  final Color iconColor;
  final Color iconBgColor;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.onBackground.withOpacity(0.04),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTypography.labelUppercase.copyWith(
              color: AppColors.onSurfaceVariant,
              fontSize: 9,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveCourseSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16),
          child: Text('Khóa học hiện tại',
              style: AppTypography.headlineSmall.copyWith(fontSize: 20)),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: -16,
                right: -16,
                child: Icon(
                  Icons.school_rounded,
                  size: 120,
                  color: AppColors.primary.withOpacity(0.08),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.full),
                              ),
                              child: Text(
                                'TIẾNG SÉC',
                                style: AppTypography.labelUppercase.copyWith(
                                  color: Colors.white,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Trvalý Cấp tốc (A2)',
                              style: AppTypography.headlineSmall
                                  .copyWith(fontSize: 22),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '35%',
                        style: AppTypography.headlineSmall.copyWith(
                          color: AppColors.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    child: LinearProgressIndicator(
                      value: 0.35,
                      backgroundColor: AppColors.surfaceContainerHighest,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.primary),
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded,
                          size: 14, color: AppColors.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        'Cập nhật lần cuối: 2 giờ trước',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickLinksSection extends StatelessWidget {
  const _QuickLinksSection({required this.context});
  final BuildContext context;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16),
          child: Text('Lối tắt',
              style: AppTypography.headlineSmall.copyWith(fontSize: 20)),
        ),
        _QuickLink(
          icon: Icons.notifications_active_rounded,
          label: 'Nhắc nhở học tập',
          onTap: () => context.push(AppRoutes.notifications),
        ),
        const SizedBox(height: 12),
        _QuickLink(
          icon: Icons.history_edu_rounded,
          label: 'Lịch sử thi thử',
          onTap: () => context.push(AppRoutes.progress),
        ),
      ],
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.outlineVariant.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.onBackground.withOpacity(0.04),
                    blurRadius: 4,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(label,
                  style: AppTypography.bodyMedium
                      .copyWith(fontWeight: FontWeight.w600)),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.onSurfaceVariant, size: 22),
          ],
        ),
      ),
    );
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({required this.context});
  final BuildContext context;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16),
          child: Text('Tài khoản',
              style: AppTypography.headlineSmall.copyWith(fontSize: 20)),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border:
                Border.all(color: AppColors.outlineVariant.withOpacity(0.4)),
          ),
          child: Column(
            children: [
              _AccountRow(
                icon: Icons.manage_accounts_rounded,
                label: 'Cài đặt tài khoản',
                onTap: () => context.push(AppRoutes.settings),
                isFirst: true,
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: !isLast
              ? Border(
                  bottom: BorderSide(
                    color: AppColors.outlineVariant.withOpacity(0.4),
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.onSurfaceVariant, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(label,
                  style: AppTypography.bodyMedium
                      .copyWith(fontWeight: FontWeight.w500)),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.outline, size: 20),
          ],
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onSignOut});
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSignOut,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.error.withOpacity(0.2), width: 2),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
            const SizedBox(width: 8),
            Text(
              'Đăng xuất',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
