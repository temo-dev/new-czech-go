import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_typography.dart';

/// Labeled checkbox. Tapping the label also toggles the checkbox.
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;
  final Widget label; // Widget to support rich text (links etc.)

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(value: value, onChanged: onChanged),
          const SizedBox(width: 4),
          Expanded(
            child: DefaultTextStyle(
              style: AppTypography.bodyMedium,
              child: label,
            ),
          ),
        ],
      ),
    );
  }
}
