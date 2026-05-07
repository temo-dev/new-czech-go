import 'package:flutter/material.dart';

import 'package:flutter_app/core/level_utils.dart';
import 'package:flutter_app/core/theme/app_colors.dart';
import 'package:flutter_app/core/theme/app_spacing.dart';

/// PromotionBanner is the sticky home card that surfaces "Sẵn sàng thi
/// nâng cấp" when the V21 gates are met. Tap routes the caller to the
/// PreExamScreen with the promotion mock test id.
///
/// Visibility rules (server-derived; the widget never re-evaluates gates):
///   - promotionUnlocked must be true
///   - targetLevel must NOT already be in unlockedLevels
///   - promotionTestId must be a non-empty string
/// Any miss collapses to SizedBox.shrink so the surrounding column does
/// not leave an empty gap.
class PromotionBanner extends StatelessWidget {
  const PromotionBanner({
    super.key,
    required this.promotionUnlocked,
    required this.targetLevel,
    required this.unlockedLevels,
    required this.promotionTestId,
    required this.onTap,
  });

  final bool promotionUnlocked;
  final CefrLevel? targetLevel;
  final Set<CefrLevel> unlockedLevels;
  final String promotionTestId;
  final void Function(String mockTestId) onTap;

  bool get _shouldShow {
    if (!promotionUnlocked) return false;
    if (targetLevel == null) return false;
    if (unlockedLevels.contains(targetLevel)) return false;
    if (promotionTestId.isEmpty) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow) return const SizedBox.shrink();
    final levelLabel = cefrLevelLabel(targetLevel!);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x2,
      ),
      child: Material(
        key: const Key('promotion_banner_card'),
        color: AppColors.successContainer,
        borderRadius: BorderRadius.circular(AppSpacing.x3),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.x3),
          onTap: () => onTap(promotionTestId),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x4),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.success,
                  ),
                  child: const Icon(
                    Icons.workspace_premium_outlined,
                    color: AppColors.onSuccess,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Sẵn sàng thi nâng cấp lên $levelLabel',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Hoàn thành đề thi để mở khoá cấp tiếp theo.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
