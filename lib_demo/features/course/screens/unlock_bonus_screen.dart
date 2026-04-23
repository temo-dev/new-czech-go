import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/features/course/providers/course_providers.dart';
import 'package:app_czech/shared/providers/auth_provider.dart';
import 'package:app_czech/shared/widgets/responsive_page_container.dart';

/// Unlock bonus practice screen.
/// Loads real XP balance and lesson bonus cost from Supabase.
/// On confirm, calls unlock_lesson_bonus RPC (deducts XP + marks lesson).
class UnlockBonusScreen extends ConsumerStatefulWidget {
  const UnlockBonusScreen({super.key, required this.lessonId});
  final String lessonId;

  @override
  ConsumerState<UnlockBonusScreen> createState() => _UnlockBonusScreenState();
}

class _UnlockBonusScreenState extends ConsumerState<UnlockBonusScreen> {
  bool _isUnlocking = false;
  String? _errorMessage;

  Future<void> _handleUnlock(int cost, int currentXp) async {
    if (currentXp < cost) {
      setState(() {
        _errorMessage =
            'Bạn cần thêm ${cost - currentXp} XP để mở khóa bài này.';
      });
      return;
    }
    setState(() {
      _isUnlocking = true;
      _errorMessage = null;
    });
    try {
      await ref.read(unlockBonusProvider(widget.lessonId).future);
      if (mounted) context.pop(true); // pop with result = unlocked
    } catch (e) {
      setState(() {
        _isUnlocking = false;
        _errorMessage = e.toString().contains('insufficient_xp')
            ? 'XP không đủ để mở khóa.'
            : 'Có lỗi xảy ra. Vui lòng thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lessonAsync = ref.watch(lessonDetailProvider(widget.lessonId));
    final userAsync = ref.watch(currentUserProvider);

    final bonusXpCost = lessonAsync.valueOrNull?.bonusXpCost ?? 500;
    final totalXp = userAsync.valueOrNull?.totalXp ?? 0;
    final afterUnlock = (totalXp - bonusXpCost).clamp(0, totalXp);
    final hasEnoughXp = totalXp >= bonusXpCost;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              bottom: BorderSide(
                color: AppColors.outlineVariant.withOpacity(0.6),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.onBackground.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: AppColors.primary,
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Mở khóa luyện tập',
                    style: AppTypography.headlineSmall.copyWith(fontSize: 22),
                  ),
                  const Spacer(),
                  // XP balance chip — shows real balance from profile
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.stars_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        userAsync.when(
                          data: (user) => Text(
                            '${user?.totalXp ?? 0} XP',
                            style: AppTypography.labelSmall.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          loading: () => const SizedBox(
                            width: 40,
                            height: 12,
                            child: LinearProgressIndicator(),
                          ),
                          error: (_, __) => Text(
                            '– XP',
                            style: AppTypography.labelSmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: ResponsivePageContainer(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Hero
                _HeroSection(
                  lessonTitle: lessonAsync.valueOrNull?.lesson.title,
                ),
                const SizedBox(height: 40),

                // Benefits bento
                const _BenefitsGrid(),
                const SizedBox(height: 48),

                // Transaction card
                _TransactionCard(
                  cost: bonusXpCost,
                  currentXp: totalXp,
                  afterUnlock: afterUnlock,
                  hasEnoughXp: hasEnoughXp,
                  isUnlocking: _isUnlocking,
                  errorMessage: _errorMessage,
                  onUnlock: () => _handleUnlock(bonusXpCost, totalXp),
                  onSkip: () => context.pop(),
                ),
                const SizedBox(height: AppSpacing.x8),

                Text(
                  '"Sự chuẩn bị tốt nhất cho ngày mai là làm hết sức mình trong ngày hôm nay."',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hero Section ─────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  const _HeroSection({this.lessonTitle});
  final String? lessonTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.onBackground.withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: AppColors.primary,
                size: 48,
              ),
            ),
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: AppColors.tertiary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Text(
          lessonTitle != null
              ? 'Bài tập bonus: $lessonTitle'
              : 'Bài tập nâng cao',
          style: AppTypography.headlineLarge.copyWith(
            fontSize: 32,
            height: 1.25,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Mở khóa bài tập nâng cao để luyện tập sâu hơn và cải thiện điểm số.',
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.onSurfaceVariant,
            height: 1.6,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Benefits Grid ─────────────────────────────────────────────────────────────

class _BenefitsGrid extends StatelessWidget {
  const _BenefitsGrid();

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 720;
    final benefits = [
      (
        Icons.menu_book_rounded,
        'Từ vựng nâng cao',
        'Bổ sung 30+ từ vựng chuyên sâu liên quan đến chủ đề bài học.'
      ),
      (
        Icons.verified_user_rounded,
        'Đề thực tế',
        'Bài tập mô phỏng đúng cấu trúc đề thi Trvalý pobyt.'
      ),
      (
        Icons.analytics_rounded,
        'AI chấm điểm',
        'Nhận phản hồi chi tiết từ AI để cải thiện phát âm và văn phong.'
      ),
    ];

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: benefits.asMap().entries.map((entry) {
          final i = entry.key;
          final (icon, title, desc) = entry.value;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: i > 0 ? 12 : 0,
                right: i < benefits.length - 1 ? 12 : 0,
                top: i == 1 ? 16 : 0,
              ),
              child: _BenefitCard(icon: icon, title: title, desc: desc),
            ),
          );
        }).toList(),
      );
    }

    return Column(
      children: benefits.map((b) {
        final (icon, title, desc) = b;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _BenefitCard(icon: icon, title: title, desc: desc),
        );
      }).toList(),
    );
  }
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({
    required this.icon,
    required this.title,
    required this.desc,
  });

  final IconData icon;
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 32),
          const SizedBox(height: 16),
          Text(title,
              style: AppTypography.headlineSmall.copyWith(fontSize: 20)),
          const SizedBox(height: 8),
          Text(
            desc,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Transaction Card ──────────────────────────────────────────────────────────

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.cost,
    required this.currentXp,
    required this.afterUnlock,
    required this.hasEnoughXp,
    required this.isUnlocking,
    required this.onUnlock,
    required this.onSkip,
    this.errorMessage,
  });

  final int cost;
  final int currentXp;
  final int afterUnlock;
  final bool hasEnoughXp;
  final bool isUnlocking;
  final VoidCallback onUnlock;
  final VoidCallback onSkip;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 448),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: AppColors.outlineVariant.withOpacity(0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.onBackground.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.payments_rounded,
              color: AppColors.primary, size: 32),
          const SizedBox(height: 8),
          Text(
            '$cost XP',
            style: AppTypography.headlineLarge.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              'PHÍ MỞ KHÓA',
              style: AppTypography.labelUppercase.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Stats table
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Số dư hiện tại',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.onSurfaceVariant)),
              Text('$currentXp XP',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: hasEnoughXp
                        ? AppColors.onBackground
                        : AppColors.error,
                  )),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.outlineVariant),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sau khi mở khóa',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.onSurfaceVariant)),
              Text('$afterUnlock XP',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),

          if (!hasEnoughXp) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bạn cần thêm ${cost - currentXp} XP. Hãy làm thêm bài tập để tích lũy XP.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              errorMessage!,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 24),

          // Unlock button
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: hasEnoughXp && !isUnlocking ? onUnlock : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 52,
                decoration: BoxDecoration(
                  color: hasEnoughXp && !isUnlocking
                      ? AppColors.primary
                      : AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: hasEnoughXp && !isUnlocking
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: isUnlocking
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_open_rounded,
                            color: hasEnoughXp
                                ? Colors.white
                                : AppColors.onSurfaceVariant,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            hasEnoughXp ? 'Mở khóa ngay' : 'XP không đủ',
                            style: AppTypography.labelMedium.copyWith(
                              color: hasEnoughXp
                                  ? Colors.white
                                  : AppColors.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          TextButton(
            onPressed: onSkip,
            child: Text(
              'Làm sau',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
