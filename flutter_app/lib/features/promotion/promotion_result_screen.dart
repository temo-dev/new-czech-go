import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_app/core/level_utils.dart';
import 'package:flutter_app/core/theme/app_colors.dart';
import 'package:flutter_app/core/theme/app_spacing.dart';

/// PromotionResultScreen renders the V21 post-exam outcome — pass or
/// fail. The two paths share scaffolding but diverge on body content:
///
///   PASS: success surface + animated badge + dual CTAs ("Khám phá X"
///   primary, "Về trang chủ" ghost). Reduced-motion users see a static
///   badge with no animation controller spun up.
///
///   FAIL: neutral surface + per-skill diagnostic table (sorted weakest
///   first), live cooldown timer (server-provided cooldownUntil), and a
///   weakest-skill deep-link CTA. Mastery is **not** reset — backend
///   B8 hook does not write mastery on fail.
class PromotionResultScreen extends StatefulWidget {
  const PromotionResultScreen({
    super.key,
    required this.passed,
    required this.targetLevel,
    required this.scorePct,
    required this.perSkillPct,
    required this.cooldownUntil,
    required this.thresholdPct,
    required this.onExplore,
    required this.onHome,
    required this.onPracticeWeakSkill,
    DateTime Function()? clock,
  }) : _clock = clock;

  final bool passed;
  final CefrLevel targetLevel;
  final double scorePct;
  final Map<String, double> perSkillPct;
  final DateTime? cooldownUntil;
  final double thresholdPct;
  final VoidCallback onExplore;
  final VoidCallback onHome;
  final void Function(String skillKind) onPracticeWeakSkill;
  final DateTime Function()? _clock;

  DateTime _now() => _clock?.call() ?? DateTime.now().toUtc();

  @override
  State<PromotionResultScreen> createState() => _PromotionResultScreenState();
}

class _PromotionResultScreenState extends State<PromotionResultScreen>
    with SingleTickerProviderStateMixin {
  AnimationController? _spring;
  Timer? _cooldownTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    if (widget.passed && !reducedMotion && _spring == null) {
      _spring = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 450),
      )..forward();
    }
  }

  @override
  void initState() {
    super.initState();
    if (!widget.passed && widget.cooldownUntil != null) {
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _spring?.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          widget.passed ? AppColors.successContainer : AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x6,
            vertical: AppSpacing.x6,
          ),
          child: widget.passed ? _buildPassBody() : _buildFailBody(),
        ),
      ),
    );
  }

  Widget _buildPassBody() {
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    Widget badge = _Badge(level: widget.targetLevel, success: true);
    if (!reducedMotion && _spring != null) {
      final scale = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _spring!, curve: Curves.easeOutBack),
      );
      badge = ScaleTransition(
        key: const Key('promotion_result_badge_spring'),
        scale: scale,
        child: badge,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Center(child: badge),
        const SizedBox(height: AppSpacing.x4),
        Text(
          'Bạn đã lên ${cefrLevelLabel(widget.targetLevel)}!',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.x2),
        Text(
          'Điểm thi: ${widget.scorePct.toStringAsFixed(0)}%',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        ElevatedButton(
          key: const Key('promotion_result_pass_explore_cta'),
          onPressed: widget.onExplore,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.x3)),
          ),
          child: Text(
            'Khám phá ${cefrLevelLabel(widget.targetLevel)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: AppSpacing.x2),
        TextButton(
          key: const Key('promotion_result_pass_home_cta'),
          onPressed: widget.onHome,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.onSurfaceVariant,
            minimumSize: const Size.fromHeight(48),
          ),
          child: const Text(
            'Về trang chủ',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildFailBody() {
    final entries = widget.perSkillPct.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final weakest = entries.isEmpty ? null : entries.first.key;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Chưa đạt — luyện thêm nhé',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.x2),
        Text(
          'Điểm thi: ${widget.scorePct.toStringAsFixed(0)}%. '
          'Mastery của bạn không bị giảm.',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.x4),
        _DiagnosticTable(
          key: const Key('promotion_result_fail_table'),
          entries: entries,
          thresholdPct: widget.thresholdPct,
        ),
        const SizedBox(height: AppSpacing.x3),
        if (widget.cooldownUntil != null) _CooldownCaption(
          cooldownUntil: widget.cooldownUntil!,
          now: widget._now(),
        ),
        const Spacer(),
        if (weakest != null)
          ElevatedButton(
            key: const Key('promotion_result_practice_weak_cta'),
            onPressed: () => widget.onPracticeWeakSkill(weakest),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.x3)),
            ),
            child: const Text(
              'Luyện skill yếu nhất',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        const SizedBox(height: AppSpacing.x2),
        TextButton(
          onPressed: widget.onHome,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.onSurfaceVariant,
            minimumSize: const Size.fromHeight(48),
          ),
          child: const Text(
            'Về trang chủ',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.level, required this.success});

  final CefrLevel level;
  final bool success;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: success ? AppColors.success : AppColors.surfaceContainerHigh,
        shape: BoxShape.circle,
        border: Border.all(
          color: success ? AppColors.success : AppColors.outlineVariant,
          width: 4,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        cefrLevelLabel(level),
        style: TextStyle(
          fontSize: 56,
          fontWeight: FontWeight.w900,
          color: success ? AppColors.onSuccess : AppColors.onSurface,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class _DiagnosticTable extends StatelessWidget {
  const _DiagnosticTable({
    super.key,
    required this.entries,
    required this.thresholdPct,
  });

  final List<MapEntry<String, double>> entries;
  final double thresholdPct;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    e.key,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: (e.value / 100).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: AppColors.surfaceContainerHigh,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        e.value >= thresholdPct
                            ? AppColors.success
                            : AppColors.scorePoor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.x2),
                SizedBox(
                  width: 60,
                  child: Text(
                    '${e.value.toStringAsFixed(0)}%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CooldownCaption extends StatelessWidget {
  const _CooldownCaption({required this.cooldownUntil, required this.now});

  final DateTime cooldownUntil;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final remaining = cooldownUntil.difference(now);
    if (remaining.isNegative) {
      return const SizedBox.shrink();
    }
    final h = remaining.inHours;
    final m = remaining.inMinutes.remainder(60);
    final s = remaining.inSeconds.remainder(60);
    final hms = '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
    return Container(
      key: const Key('promotion_result_cooldown_timer'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Text(
        'Có thể thi lại sau $hms',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.onSurfaceVariant,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
