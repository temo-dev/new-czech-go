import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/features/shell/app_shell.dart';

class SideRailNav extends StatelessWidget {
  const SideRailNav({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTap,
    this.chatUnreadCount = 0,
    this.chatTabIndex = 3,
  });

  final List<ShellTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final int chatUnreadCount;
  final int chatTabIndex;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      extended: false,
      minWidth: 72,
      backgroundColor: AppColors.surfaceContainerLowest,
      selectedIndex: selectedIndex,
      onDestinationSelected: onTap,
      indicatorColor: AppColors.primary.withOpacity(0.10),
      selectedIconTheme: const IconThemeData(color: AppColors.primary),
      unselectedIconTheme:
          const IconThemeData(color: AppColors.onSurfaceVariant),
      labelType: NavigationRailLabelType.all,
      selectedLabelTextStyle: AppTypography.labelSmall.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: AppTypography.labelSmall.copyWith(
        color: AppColors.onSurfaceVariant,
      ),
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryFixed,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
          ],
        ),
      ),
      destinations: tabs.asMap().entries.map((e) {
        final i = e.key;
        final tab = e.value;
        final showBadge = i == chatTabIndex && chatUnreadCount > 0;
        return NavigationRailDestination(
          icon: showBadge
              ? Badge(
                  label: Text(
                    chatUnreadCount > 99 ? '99+' : '$chatUnreadCount',
                  ),
                  child: Icon(tab.icon),
                )
              : Icon(tab.icon),
          selectedIcon: showBadge
              ? Badge(
                  label: Text(
                    chatUnreadCount > 99 ? '99+' : '$chatUnreadCount',
                  ),
                  child: Icon(tab.activeIcon),
                )
              : Icon(tab.activeIcon),
          label: Text(tab.label),
        );
      }).toList(),
    );
  }
}
