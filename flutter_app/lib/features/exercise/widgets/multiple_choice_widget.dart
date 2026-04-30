import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/models.dart';

/// Renders A-D (or A-G) multiple-choice options for a single question.
///
/// Layout switches to a 2×2 image grid when ALL options have [imageAssetId]
/// and a [mediaUri] builder is provided. Falls back to text list otherwise.
class MultipleChoiceWidget extends StatelessWidget {
  const MultipleChoiceWidget({
    super.key,
    required this.questionNo,
    required this.options,
    required this.selected,
    required this.onSelect,
    this.mediaUri,
    this.authHeaders,
  });

  final int questionNo;
  final List<PoslechOptionView> options;
  final String? selected;
  final ValueChanged<String> onSelect;

  /// Optional: builds a URL for a given storage key. Required for image grid.
  final Uri Function(String storageKey)? mediaUri;
  final Map<String, String>? authHeaders;

  bool get _allHaveImages =>
      mediaUri != null &&
      options.isNotEmpty &&
      options.every((o) => o.imageAssetId.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$questionNo.', style: AppTypography.labelLarge),
        const SizedBox(height: 6),
        _allHaveImages ? _buildImageGrid() : _buildTextList(),
      ],
    );
  }

  Widget _buildTextList() {
    return Column(
      children: options.map((opt) {
        final isSelected = selected == opt.key;
        return GestureDetector(
          onTap: () => onSelect(opt.key),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.white,
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.outlineVariant,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(
                  opt.key,
                  style: AppTypography.labelLarge.copyWith(
                    color: isSelected ? AppColors.primary : AppColors.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    opt.text.isNotEmpty
                        ? opt.text
                        : opt.label.isNotEmpty
                            ? opt.label
                            : opt.assetId,
                    style: AppTypography.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildImageGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 4 / 5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: options.map((opt) => _ImageOptionCell(
        option: opt,
        isSelected: selected == opt.key,
        onTap: () => onSelect(opt.key),
        imageUrl: mediaUri!(opt.imageAssetId).toString(),
        authHeaders: authHeaders ?? const {},
      )).toList(),
    );
  }
}

class _ImageOptionCell extends StatelessWidget {
  const _ImageOptionCell({
    required this.option,
    required this.isSelected,
    required this.onTap,
    required this.imageUrl,
    required this.authHeaders,
  });

  final PoslechOptionView option;
  final bool isSelected;
  final VoidCallback onTap;
  final String imageUrl;
  final Map<String, String> authHeaders;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outlineVariant,
            width: isSelected ? 2.5 : 1.5,
          ),
          color: isSelected ? AppColors.primary.withValues(alpha: 0.06) : Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                child: Image.network(
                  imageUrl,
                  headers: authHeaders,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _LetterPlaceholder(letter: option.key),
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : Container(
                          color: const Color(0xFFF5F0EA),
                          child: Center(
                            child: Text(option.key, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFBCB2A6))),
                          ),
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  if (isSelected)
                    Container(
                      width: 18, height: 18,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.check, size: 12, color: Colors.white),
                    ),
                  Expanded(
                    child: Text(
                      '${option.key}${option.text.isNotEmpty ? " — ${option.text}" : ""}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? AppColors.primary : AppColors.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

class _LetterPlaceholder extends StatelessWidget {
  const _LetterPlaceholder({required this.letter});
  final String letter;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F0EA),
      child: Center(
        child: Text(letter, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFBCB2A6))),
      ),
    );
  }
}
