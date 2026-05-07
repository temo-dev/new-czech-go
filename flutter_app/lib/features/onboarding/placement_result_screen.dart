import 'package:flutter/material.dart';

import 'package:flutter_app/core/level_utils.dart';
import 'package:flutter_app/core/theme/app_colors.dart';
import 'package:flutter_app/core/theme/app_spacing.dart';

/// PlacementResultScreen reveals the assigned CEFR level after the
/// learner submits the placement test. The level chip animates in
/// (scale + fade) so the moment feels deliberate; reduced-motion users
/// see a static reveal so the level is readable without waiting for the
/// animation.
class PlacementResultScreen extends StatefulWidget {
  const PlacementResultScreen({
    super.key,
    required this.assignedLevel,
    required this.scorePct,
    required this.onContinue,
  });

  final CefrLevel assignedLevel;
  final double scorePct;
  final VoidCallback onContinue;

  @override
  State<PlacementResultScreen> createState() => _PlacementResultScreenState();
}

class _PlacementResultScreenState extends State<PlacementResultScreen>
    with SingleTickerProviderStateMixin {
  AnimationController? _reveal;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    if (!reducedMotion && _reveal == null) {
      _reveal = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 450),
      )..forward();
    }
  }

  @override
  void dispose() {
    _reveal?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final levelLabel = cefrLevelLabel(widget.assignedLevel);

    Widget badge = _LevelRevealBadge(level: widget.assignedLevel);
    if (!reducedMotion && _reveal != null) {
      final scale = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _reveal!, curve: Curves.easeOutBack),
      );
      final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _reveal!, curve: Curves.easeIn),
      );
      badge = ScaleTransition(
        key: const Key('placement_result_reveal_animation'),
        scale: scale,
        child: FadeTransition(opacity: fade, child: badge),
      );
    }

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
                'Bạn đang ở cấp độ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.x4),
              Center(child: badge),
              const SizedBox(height: AppSpacing.x4),
              Text(
                'Điểm phân loại: ${widget.scorePct.toStringAsFixed(0)}%',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.x3),
              Text(
                'Khoá học $levelLabel đã được mở. Bạn có thể bắt đầu '
                'luyện ngay từ bài đầu tiên.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              ElevatedButton(
                key: const Key('placement_result_continue_cta'),
                onPressed: widget.onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.x3)),
                ),
                child: const Text(
                  'Bắt đầu học',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelRevealBadge extends StatelessWidget {
  const _LevelRevealBadge({required this.level});

  final CefrLevel level;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 4),
      ),
      alignment: Alignment.center,
      child: Text(
        cefrLevelLabel(level),
        style: const TextStyle(
          fontSize: 56,
          fontWeight: FontWeight.w900,
          color: AppColors.onPrimaryContainer,
          letterSpacing: 2,
        ),
      ),
    );
  }
}
