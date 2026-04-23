import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'app_button.dart';

/// Persistent bottom CTA bar — sits above system nav.
/// Use as [Scaffold.bottomNavigationBar] or as the last widget in a Stack.
class StickyBottomCta extends StatelessWidget {
  const StickyBottomCta({
    super.key,
    required this.label,
    required this.onTap,
    this.isLoading = false,
    this.enabled = true,
    this.secondaryLabel,
    this.onSecondaryTap,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool enabled;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: const Border(
          top: BorderSide(
            color: AppColors.outlineVariant,
            width: 1,
          ),
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton(
            label: label,
            onPressed: enabled ? onTap : null,
            loading: isLoading,
            icon: icon,
          ),
          if (secondaryLabel != null && onSecondaryTap != null) ...[
            const SizedBox(height: 8),
            AppButton(
              label: secondaryLabel!,
              onPressed: onSecondaryTap,
              variant: AppButtonVariant.secondary,
            ),
          ],
        ],
      ),
    );
  }
}
