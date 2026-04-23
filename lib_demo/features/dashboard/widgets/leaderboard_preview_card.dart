import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app_czech/core/router/app_routes.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/features/dashboard/models/dashboard_models.dart';

/// Shows top 3 leaderboard rows + the user's own rank.
/// Tapping navigates to the full leaderboard screen.
class LeaderboardPreviewCard extends StatelessWidget {
  const LeaderboardPreviewCard({
    super.key,
    required this.rows,
    this.ownRank,
  });

  final List<LeaderboardRow> rows;
  final int? ownRank;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => context.push(AppRoutes.leaderboard),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.x4),
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  size: 18,
                  color: AppColors.xpGold,
                ),
                const SizedBox(width: AppSpacing.x2),
                const Text('Bảng xếp hạng tuần', style: AppTypography.titleSmall),
                const Spacer(),
                Text(
                  'Xem tất cả',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
              ],
            ),
            if (rows.isEmpty) ...[
              const SizedBox(height: AppSpacing.x4),
              Text(
                'Chưa có dữ liệu tuần này.',
                style: AppTypography.bodySmall.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.x2),
            ] else ...[
              const SizedBox(height: AppSpacing.x3),
              ...rows.map((row) => _LeaderboardRowTile(row: row)),
              if (ownRank != null && ownRank! > 3) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.x2),
                  child: Divider(height: 1),
                ),
                _OwnRankRow(rank: ownRank!),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _LeaderboardRowTile extends StatelessWidget {
  const _LeaderboardRowTile({required this.row});
  final LeaderboardRow row;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rankColor = switch (row.rank) {
      1 => const Color(0xFFFFD700), // gold
      2 => const Color(0xFFC0C0C0), // silver
      3 => const Color(0xFFCD7F32), // bronze
      _ => cs.onSurfaceVariant,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x1),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '${row.rank}',
              style: AppTypography.labelMedium.copyWith(
                color: rankColor,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          CircleAvatar(
            radius: 14,
            backgroundColor: cs.primaryContainer,
            backgroundImage:
                row.avatarUrl != null ? NetworkImage(row.avatarUrl!) : null,
            child: row.avatarUrl == null
                ? Text(
                    row.displayName.isNotEmpty
                        ? row.displayName[0].toUpperCase()
                        : '?',
                    style: AppTypography.labelSmall.copyWith(
                      color: cs.onPrimaryContainer,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Text(
              row.displayName,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight:
                    row.isCurrentUser ? FontWeight.w600 : FontWeight.w400,
                color: row.isCurrentUser ? AppColors.primary : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${row.weeklyXp} XP',
            style: AppTypography.labelSmall.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnRankRow extends StatelessWidget {
  const _OwnRankRow({required this.rank});
  final int rank;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        const SizedBox(width: 24),
        const SizedBox(width: AppSpacing.x3),
        Icon(Icons.more_vert_rounded, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: AppSpacing.x2),
        Text(
          'Bạn đang ở hạng $rank',
          style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
