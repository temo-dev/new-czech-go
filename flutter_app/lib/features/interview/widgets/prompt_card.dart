import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/generated/app_localizations.dart';

/// V16: learner-facing prompt card shown over the avatar during an interview
/// session. Mounts expanded so the learner can read the task, then collapses
/// to a mini pill after [autoCollapseAfter] to free vertical space.
///
/// The parent should call [InterviewPromptCardState.onAgentResponseComplete]
/// each time the examiner finishes a turn so the card pulses to flag a new
/// question. The first call after mount is intentionally a no-op (the card
/// is already drawing attention because it just appeared).
class InterviewPromptCard extends StatefulWidget {
  const InterviewPromptCard({
    super.key,
    required this.body,
    this.choiceTitle,
    this.choiceContent,
    this.tips = const [],
    this.autoCollapseAfter = const Duration(seconds: 8),
    this.maxExpandedHeight,
  });

  /// Learner-facing task description (derived from system_prompt server-side).
  /// When empty, the card refuses to mount visible content.
  final String body;

  /// Choice variant: "B — Y tá" — option key + label of the chosen option.
  final String? choiceTitle;

  /// Choice variant: option content shown in the card body when an option
  /// has been selected. Replaces [body] when present.
  final String? choiceContent;

  /// Learner-facing hints shown with the task while the card is expanded.
  final List<String> tips;

  final Duration autoCollapseAfter;

  /// Caps the expanded card on compact interview screens. Overflow content
  /// scrolls inside the card so the mic controls keep their own space.
  final double? maxExpandedHeight;

  @override
  State<InterviewPromptCard> createState() => InterviewPromptCardState();
}

class InterviewPromptCardState extends State<InterviewPromptCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = true;
  Timer? _autoCollapseTimer;
  late final AnimationController _pulseController;
  bool _firstAgentResponseSeen = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scheduleAutoCollapse();
  }

  @override
  void dispose() {
    _autoCollapseTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _scheduleAutoCollapse() {
    _autoCollapseTimer?.cancel();
    if (!_expanded) return;
    _autoCollapseTimer = Timer(widget.autoCollapseAfter, () {
      if (!mounted) return;
      setState(() => _expanded = false);
    });
  }

  void _toggle() {
    if (!mounted) return;
    setState(() => _expanded = !_expanded);
    _scheduleAutoCollapse();
  }

  /// Public hook fired by the session screen each time the examiner finishes
  /// a turn. The first call is ignored (mount itself draws attention).
  void onAgentResponseComplete() {
    if (!mounted) return;
    if (!_firstAgentResponseSeen) {
      _firstAgentResponseSeen = true;
      return;
    }
    if (_reducedMotion(context)) return;
    _pulseController.forward(from: 0);
  }

  bool _reducedMotion(BuildContext context) =>
      MediaQuery.of(context).disableAnimations;

  @override
  Widget build(BuildContext context) {
    final body =
        widget.choiceContent?.trim().isNotEmpty == true
            ? widget.choiceContent!.trim()
            : widget.body.trim();
    final tips =
        widget.tips
            .map((tip) => tip.trim())
            .where((tip) => tip.isNotEmpty)
            .take(5)
            .toList();
    if (body.isEmpty && tips.isEmpty) return const SizedBox.shrink();

    final reducedMotion = _reducedMotion(context);
    final card =
        _expanded
            ? _ExpandedCard(
              body: body,
              tips: tips,
              choiceTitle: widget.choiceTitle,
              maxHeight: widget.maxExpandedHeight,
              onTap: _toggle,
            )
            : _MiniPill(onTap: _toggle);

    final transitioned = AnimatedSwitcher(
      duration:
          reducedMotion ? Duration.zero : const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder:
          (child, animation) =>
              FadeTransition(opacity: animation, child: child),
      child: KeyedSubtree(key: ValueKey<bool>(_expanded), child: card),
    );

    if (reducedMotion) return transitioned;

    return AnimatedBuilder(
      animation: _pulseController,
      child: transitioned,
      builder: (context, child) {
        // 1.0 → 1.04 → 1.0 over the controller's full sweep.
        final t = _pulseController.value;
        final scale =
            t < 0.5 ? 1.0 + (t * 2 * 0.04) : 1.04 - ((t - 0.5) * 2 * 0.04);
        return Transform.scale(scale: scale, child: child);
      },
    );
  }
}

class _ExpandedCard extends StatelessWidget {
  const _ExpandedCard({
    required this.body,
    required this.tips,
    required this.onTap,
    this.choiceTitle,
    this.maxHeight,
  });

  final String body;
  final List<String> tips;
  final String? choiceTitle;
  final double? maxHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l.interviewPromptLabel.toUpperCase(),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: AppColors.secondary.withValues(alpha: 0.6),
              ),
            ],
          ),
          if (choiceTitle != null && choiceTitle!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              choiceTitle!.trim(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.secondary,
              ),
            ),
          ],
          if (body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              body,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.onSurface,
              ),
            ),
          ],
          if (tips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.interviewTipsHint,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final tip in tips)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '• ',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              tip,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    final cardBody =
        maxHeight == null
            ? content
            : ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight!),
              child: SingleChildScrollView(child: content),
            );

    return Material(
      color: Colors.white.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(18),
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: cardBody,
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Semantics(
        button: true,
        label: l.interviewTapToView,
        child: Material(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(999),
          elevation: 4,
          shadowColor: Colors.black.withValues(alpha: 0.3),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l.interviewTapToView,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
