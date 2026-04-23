import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_typography.dart';

/// Standard inner-screen AppBar.
/// Pass [showBack] = true (default) to render a back chevron.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.showBack = true,
    this.onBack,
    this.bottom,
    this.centerTitle = false,
    this.leadingIcon,
  });

  final String title;
  final List<Widget> actions;
  final bool showBack;
  final VoidCallback? onBack;
  final PreferredSizeWidget? bottom;
  final bool centerTitle;
  final IconData? leadingIcon;

  @override
  Size get preferredSize => Size.fromHeight(
        64 + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 64,
      title: Text(
        title,
        style: AppTypography.titleMedium.copyWith(
          color: AppColors.onBackground,
        ),
      ),
      centerTitle: centerTitle,
      titleSpacing: showBack ? 0 : NavigationToolbar.kMiddleSpacing,
      leading: showBack
          ? IconButton(
              icon: Icon(leadingIcon ?? Icons.arrow_back_rounded),
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            )
          : null,
      automaticallyImplyLeading: false,
      iconTheme: const IconThemeData(color: AppColors.onSurfaceVariant),
      actions: actions,
      shape: const Border(
        bottom: BorderSide(color: AppColors.outlineVariant),
      ),
      bottom: bottom,
    );
  }
}
