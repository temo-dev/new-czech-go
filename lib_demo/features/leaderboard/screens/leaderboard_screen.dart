import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_czech/core/router/app_routes.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_radius.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/features/leaderboard/providers/leaderboard_provider.dart';
import 'package:app_czech/features/leaderboard/widgets/leaderboard_user_sheet.dart';
import 'package:app_czech/shared/widgets/loading_shimmer.dart';
import 'package:app_czech/shared/widgets/error_state.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(leaderboardProvider);

    return Scaffold(
      primary: false,
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          // _AppBar(),
          Expanded(
            child: async.when(
              loading: () => const ShimmerCardList(count: 5),
              error: (e, _) => ErrorState(
                message: 'Không tải được bảng xếp hạng.',
                onRetry: () => ref.refresh(leaderboardProvider),
              ),
              data: (data) => _LeaderboardBody(data: data),
            ),
          ),
        ],
      ),
    );
  }
}

// ── App Bar ───────────────────────────────────────────────────────────────────

class _AppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: SizedBox(
        height: 64,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  debugPrint('canPop: ${context.canPop()}');
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(AppRoutes.dashboard);
                  }
                },
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Global Leaderboard',
                style: AppTypography.headlineSmall.copyWith(fontSize: 22),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.timer_rounded,
                      color: AppColors.primary,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'RESETS IN 2D 14H',
                      style: AppTypography.labelUppercase.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _LeaderboardBody extends StatelessWidget {
  const _LeaderboardBody({required this.data});
  final LeaderboardData data;

  @override
  Widget build(BuildContext context) {
    final entries = data.weekly;
    final ownEntry = entries.where((e) => e.isCurrentUser).firstOrNull;
    final ownRank = data.ownWeeklyRank;

    final podium = entries.take(3).toList();
    final rest = entries.skip(3).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero card
          _HeroCard(ownRank: ownRank, ownXp: ownEntry?.xp),
          const SizedBox(height: 16),

          // CTA card
          _CtaCard(),
          const SizedBox(height: 32),

          // Podium
          if (podium.isNotEmpty) ...[
            _Podium(entries: podium),
            const SizedBox(height: 32),
          ],

          // Competitors list
          Row(
            children: [
              Text('Competitors',
                  style: AppTypography.headlineSmall.copyWith(fontSize: 20)),
              const Spacer(),
              Text(
                'TOP 50 RANKING',
                style: AppTypography.labelUppercase
                    .copyWith(color: AppColors.outline, fontSize: 9),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ...rest.map((e) => _EntryTile(entry: e)),
        ],
      ),
    );
  }
}

// ── Hero Card ─────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({this.ownRank, this.ownXp});
  final int? ownRank;
  final int? ownXp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Decorative blur circle
          Positioned(
            top: -32,
            right: -32,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR WEEKLY STATUS',
                      style: AppTypography.labelUppercase.copyWith(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 9,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ownRank != null ? 'Rank #$ownRank' : 'Chưa xếp hạng',
                      style: AppTypography.headlineLarge.copyWith(
                        color: Colors.white,
                        fontSize: 36,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'TOTAL POINTS',
                    style: AppTypography.labelUppercase.copyWith(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 9,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ownXp != null
                        ? _formatPts(ownXp!)
                        : '—',
                    style: AppTypography.headlineSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatPts(int xp) {
    if (xp >= 1000) {
      return '${(xp / 1000).toStringAsFixed(xp % 1000 == 0 ? 0 : 1)}k';
    }
    return '$xp';
  }
}

// ── CTA Card ──────────────────────────────────────────────────────────────────

class _CtaCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
            color: AppColors.outlineVariant.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keep the momentum',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Học thêm để thăng hạng',
                  style: AppTypography.headlineSmall.copyWith(fontSize: 18),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                'Bắt đầu',
                style: AppTypography.labelSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Podium ────────────────────────────────────────────────────────────────────

class _Podium extends StatelessWidget {
  const _Podium({required this.entries});
  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    final first = entries.isNotEmpty ? entries[0] : null;
    final second = entries.length > 1 ? entries[1] : null;
    final third = entries.length > 2 ? entries[2] : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Rank 2 (left)
        Expanded(
          child: second != null
              ? _PodiumSlot(entry: second, rankBadgeColor: AppColors.onSurfaceVariant)
              : const SizedBox(),
        ),
        // Rank 1 (center, taller)
        Expanded(
          flex: 1,
          child: first != null
              ? _PodiumSlot(
                  entry: first,
                  rankBadgeColor: AppColors.primary,
                  isFirst: true,
                )
              : const SizedBox(),
        ),
        // Rank 3 (right)
        Expanded(
          child: third != null
              ? _PodiumSlot(entry: third, rankBadgeColor: AppColors.tertiary)
              : const SizedBox(),
        ),
      ],
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  const _PodiumSlot({
    required this.entry,
    required this.rankBadgeColor,
    this.isFirst = false,
  });

  final LeaderboardEntry entry;
  final Color rankBadgeColor;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final avatarSize = isFirst ? 48.0 : 32.0;

    return GestureDetector(
      onTap: () => LeaderboardUserSheet.show(context, entry),
      child: Column(
      children: [
        if (isFirst)
          const Icon(Icons.workspace_premium_rounded,
              color: AppColors.primary, size: 28),
        if (isFirst) const SizedBox(height: 8),

        // Avatar with rank badge
        Stack(
          clipBehavior: Clip.none,
          children: [
            _Avatar(entry: entry, radius: avatarSize / 2 + 4),
            Positioned(
              bottom: -4,
              right: -4,
              child: Container(
                width: isFirst ? 32 : 24,
                height: isFirst ? 32 : 24,
                decoration: BoxDecoration(
                  color: rankBadgeColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.surface, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${entry.rank}',
                  style: TextStyle(
                    fontFamily: 'EBGaramond',
                    fontSize: isFirst ? 13 : 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          entry.displayName.split(' ').first,
          style: AppTypography.labelSmall.copyWith(
            fontWeight: isFirst ? FontWeight.w800 : FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          '${_fmt(entry.xp)} pts',
          style: AppTypography.bodySmall.copyWith(
            fontFamily: 'EBGaramond',
            color: isFirst ? AppColors.primary : AppColors.onSurfaceVariant,
            fontWeight: isFirst ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ],
    ),
    );
  }

  String _fmt(int xp) {
    if (xp >= 1000) {
      return '${(xp / 1000).toStringAsFixed(xp % 1000 == 0 ? 0 : 1)}k';
    }
    return '$xp';
  }
}

// ── Entry Tile (rank 4+) ─────────────────────────────────────────────────────

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});
  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final isYou = entry.isCurrentUser;

    return GestureDetector(
      onTap: isYou ? null : () => LeaderboardUserSheet.show(context, entry),
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isYou ? AppColors.primary.withOpacity(0.05) : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isYou
              ? AppColors.primary.withOpacity(0.2)
              : AppColors.outlineVariant.withOpacity(0.2),
          width: isYou ? 2 : 1,
        ),
      ),
      child: Stack(
        children: [
          // Left accent bar for current user
          if (isYou)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.lg),
                    bottomLeft: Radius.circular(AppRadius.lg),
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(isYou ? 16 : 16, 16, 16, 16),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '${entry.rank}',
                    style: AppTypography.bodyMedium.copyWith(
                      fontFamily: 'EBGaramond',
                      color: isYou ? AppColors.primary : AppColors.onSurfaceVariant,
                      fontWeight: isYou ? FontWeight.w900 : FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                isYou
                    ? Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primaryFixed,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'YOU',
                          style: AppTypography.labelUppercase.copyWith(
                            color: AppColors.primary,
                            fontSize: 8,
                          ),
                        ),
                      )
                    : _Avatar(entry: entry, radius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          isYou ? 'Current You' : entry.displayName,
                          style: AppTypography.labelSmall.copyWith(
                            fontWeight: isYou
                                ? FontWeight.w800
                                : FontWeight.w700,
                            color: isYou
                                ? AppColors.onBackground
                                : AppColors.onBackground,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Fire or bolt indicator for ranks 4-5
                      if (entry.rank == 4) ...[
                        const Icon(Icons.local_fire_department,
                            color: AppColors.error, size: 14),
                        Text(
                          '12',
                          style: AppTypography.bodySmall.copyWith(
                            fontSize: 10,
                            color: AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ] else if (entry.rank == 5) ...[
                        const Icon(Icons.bolt_rounded,
                            color: AppColors.primary, size: 14),
                      ] else if (isYou) ...[
                        const Icon(Icons.local_fire_department,
                            color: AppColors.error, size: 14),
                        Text(
                          '4',
                          style: AppTypography.bodySmall.copyWith(
                            fontSize: 10,
                            color: AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  '${entry.xp}',
                  style: AppTypography.bodyMedium.copyWith(
                    fontFamily: 'EBGaramond',
                    fontWeight: isYou ? FontWeight.w900 : FontWeight.w700,
                    color: isYou ? AppColors.primary : AppColors.onBackground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({required this.entry, required this.radius});
  final LeaderboardEntry entry;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryFixed,
      backgroundImage: entry.avatarUrl != null
          ? NetworkImage(entry.avatarUrl!)
          : null,
      child: entry.avatarUrl == null
          ? Text(
              entry.displayName.isNotEmpty
                  ? entry.displayName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontSize: radius * 0.6,
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );
  }
}
