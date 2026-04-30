import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/models.dart';

/// Matching exercise widget.
///
/// Left column: Czech terms in fixed order (leftId 1,2,3...).
/// Right column: Vietnamese definitions (or images) shuffled once on first build.
/// Learner taps a left chip → highlights it.
/// Then taps a right chip → creates pair (same color).
/// Tap a connected pair to un-pair.
/// answers map: leftId → rightId (e.g. {"1":"A","2":"B"}).
///
/// Image mode: when any pair has [imageAssetId] and [mediaUri] is provided,
/// the right column shows an image card instead of text. Falls back to text on load error.
class MatchingWidget extends StatefulWidget {
  const MatchingWidget({
    super.key,
    required this.pairs,
    required this.answers,
    required this.onChanged,
    this.mediaUri,
    this.authHeaders,
  });

  final List<MatchingPairView> pairs;
  final Map<String, String> answers;
  final void Function(String leftId, String rightId) onChanged;
  final Uri Function(String storageKey)? mediaUri;
  final Map<String, String>? authHeaders;

  @override
  State<MatchingWidget> createState() => _MatchingWidgetState();
}

class _MatchingWidgetState extends State<MatchingWidget> {
  late List<MatchingPairView> _shuffledRight;
  String? _selectedLeftId;

  // Pastel colors for paired items
  static const _pairColors = [
    Color(0xFFFFE5D2), Color(0xFFD9E5E3), Color(0xFFE8D5FF),
    Color(0xFFD0E8FF), Color(0xFFFFF3CC), Color(0xFFFFD5D5),
  ];
  static const _pairBorderColors = [
    Color(0xFFFF6A14), Color(0xFF0F3D3A), Color(0xFF7C3AED),
    Color(0xFF0369A1), Color(0xFFC28012), Color(0xFFC03A28),
  ];

  @override
  void initState() {
    super.initState();
    _shuffledRight = List.of(widget.pairs)..shuffle(Random());
  }

  int _pairIndex(String leftId) {
    // Color index based on the left item's position in pairs list
    return widget.pairs.indexWhere((p) => p.leftId == leftId);
  }

  void _onLeftTap(String leftId) {
    // If already paired, un-pair it
    if (widget.answers.containsKey(leftId)) {
      widget.onChanged(leftId, '');
      setState(() => _selectedLeftId = null);
      return;
    }
    setState(() => _selectedLeftId = leftId);
  }

  void _onRightTap(String rightId) {
    if (_selectedLeftId == null) return;

    // Un-pair any existing left that was using this rightId
    final existingLeft = widget.answers.entries
        .where((e) => e.value == rightId)
        .map((e) => e.key)
        .firstOrNull;
    if (existingLeft != null) {
      widget.onChanged(existingLeft, '');
    }

    widget.onChanged(_selectedLeftId!, rightId);
    setState(() => _selectedLeftId = null);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column (fixed order)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('Czech', style: AppTypography.labelUppercase.copyWith(fontSize: 10, color: AppColors.onSurfaceVariant)),
              ),
              ...widget.pairs.map((pair) {
                final isPaired = widget.answers[pair.leftId]?.isNotEmpty == true;
                final isSelected = _selectedLeftId == pair.leftId;
                final idx = isPaired ? _pairIndex(pair.leftId) : -1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.x2),
                  child: GestureDetector(
                    onTap: () => _onLeftTap(pair.leftId),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isPaired
                            ? _pairColors[idx % _pairColors.length]
                            : isSelected
                                ? AppColors.primaryContainer
                                : AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isPaired
                              ? _pairBorderColors[idx % _pairBorderColors.length]
                              : isSelected
                                  ? AppColors.primary
                                  : AppColors.outlineVariant,
                          width: isSelected || isPaired ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        pair.left,
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: isSelected || isPaired ? FontWeight.w600 : FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(width: AppSpacing.x3),

        // Right column (shuffled)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('Vietnamese', style: AppTypography.labelUppercase.copyWith(fontSize: 10, color: AppColors.onSurfaceVariant)),
              ),
              ..._shuffledRight.map((pair) {
                final pairedLeftId = widget.answers.entries
                    .where((e) => e.value == pair.rightId && e.value.isNotEmpty)
                    .map((e) => e.key)
                    .firstOrNull;
                final isPaired = pairedLeftId != null;
                final idx = isPaired ? _pairIndex(pairedLeftId) : -1;
                final hasImage = pair.imageAssetId.isNotEmpty && widget.mediaUri != null;

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.x2),
                  child: GestureDetector(
                    onTap: () => _onRightTap(pair.rightId),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: isPaired
                            ? _pairColors[idx % _pairColors.length]
                            : AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isPaired
                              ? _pairBorderColors[idx % _pairBorderColors.length]
                              : _selectedLeftId != null
                                  ? AppColors.primary.withAlpha(80)
                                  : AppColors.outlineVariant,
                          width: isPaired ? 1.5 : 1,
                        ),
                      ),
                      child: hasImage
                          ? _MatchImageCard(
                              imageUrl: widget.mediaUri!(pair.imageAssetId).toString(),
                              authHeaders: widget.authHeaders ?? const {},
                              label: pair.right,
                              isPaired: isPaired,
                            )
                          : Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Text(
                                pair.right,
                                style: AppTypography.bodySmall.copyWith(
                                  fontWeight: isPaired ? FontWeight.w600 : FontWeight.w400,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

class _MatchImageCard extends StatelessWidget {
  const _MatchImageCard({
    required this.imageUrl,
    required this.authHeaders,
    required this.label,
    required this.isPaired,
  });
  final String imageUrl;
  final Map<String, String> authHeaders;
  final String label;
  final bool isPaired;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Image.network(
              imageUrl,
              headers: authHeaders,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFFF5F0EA),
                child: Center(child: Text(label, style: AppTypography.bodySmall, textAlign: TextAlign.center)),
              ),
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : Container(color: const Color(0xFFF5F0EA)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                fontSize: 10,
                fontWeight: isPaired ? FontWeight.w600 : FontWeight.w400,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
