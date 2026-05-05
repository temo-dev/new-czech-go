import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';

/// V18 — A horizontal chip row of Czech-specific glyphs (č š ž ě ř ý ...) so
/// learners on a non-Czech IME can insert diacritics without switching
/// keyboards. Each chip taps a single glyph at the [TextEditingController]
/// cursor position, advancing the cursor by one rune.
///
/// Each chip is ≥ 44pt to satisfy the platform touch-target minimum, and
/// announces its inserted character via [Semantics] for screen readers.
class CzechKeyboardChips extends StatelessWidget {
  const CzechKeyboardChips({
    super.key,
    required this.controller,
    this.glyphs = defaultGlyphs,
    this.haptic = true,
  });

  final TextEditingController controller;
  final List<String> glyphs;
  final bool haptic;

  static const List<String> defaultGlyphs = [
    'č', 'š', 'ž', 'ě', 'ř', 'ý', 'á', 'í', 'ú', 'ů', 'ň', 'ť', 'ď',
  ];

  void _insert(BuildContext context, String glyph) {
    final selection = controller.selection;
    final text = controller.text;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final next = text.replaceRange(start, end, glyph);
    final cursor = start + glyph.length;
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: cursor),
    );
    if (haptic) HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 0),
        itemCount: glyphs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final glyph = glyphs[i];
          return Semantics(
            label: 'Chèn ký tự $glyph',
            button: true,
            child: GestureDetector(
              onTap: () => _insert(context, glyph),
              child: Container(
                constraints: const BoxConstraints(minWidth: 44),
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.onSurface.withValues(alpha: 0.12),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  glyph,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
