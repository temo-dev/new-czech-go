import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';

/// Tappable field that opens the system time picker.
/// Returns selected hour (0–23) via [onChanged].
class TimePickerField extends StatelessWidget {
  const TimePickerField({
    super.key,
    required this.hour,
    required this.onChanged,
    this.label = 'Thời gian nhắc nhở',
  });

  final int hour;
  final ValueChanged<int> onChanged;
  final String label;

  String _formatHour(int h) {
    final period = h < 12 ? 'SA' : 'CH';
    final displayHour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$displayHour:00 $period';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: hour, minute: 0),
        );
        if (picked != null) onChanged(picked.hour);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x4, vertical: AppSpacing.x3),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTypography.labelSmall
                          .copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(_formatHour(hour),
                      style: AppTypography.bodyMedium),
                ],
              ),
            ),
            Icon(Icons.schedule_rounded,
                color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
