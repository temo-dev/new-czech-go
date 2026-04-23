import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_spacing.dart';
import 'package:app_czech/core/theme/app_typography.dart';

class Crumb {
  const Crumb({required this.label, this.route});
  final String label;
  final String? route; // null = current (non-tappable)
}

/// Web-only breadcrumb trail. Renders nothing on narrow (< 600px) screens.
class BreadcrumbBar extends StatelessWidget {
  const BreadcrumbBar({super.key, required this.crumbs});

  final List<Crumb> crumbs;

  @override
  Widget build(BuildContext context) {
    // Hide on mobile — breadcrumbs are a web navigation aid only
    if (MediaQuery.sizeOf(context).width < 600) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.x2, horizontal: AppSpacing.x4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (var i = 0; i < crumbs.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.x2),
                child: Icon(Icons.chevron_right_rounded,
                    size: 16, color: AppColors.onSurfaceMutedLight),
              ),
            _CrumbLabel(crumb: crumbs[i]),
          ],
        ],
      ),
    );
  }
}

class _CrumbLabel extends StatelessWidget {
  const _CrumbLabel({required this.crumb});
  final Crumb crumb;

  @override
  Widget build(BuildContext context) {
    final isCurrent = crumb.route == null;
    final cs = Theme.of(context).colorScheme;

    if (isCurrent) {
      return Text(
        crumb.label,
        style: AppTypography.labelSmall.copyWith(color: cs.onSurface),
      );
    }
    return InkWell(
      onTap: () => context.push(crumb.route!),
      borderRadius: BorderRadius.circular(4),
      child: Text(
        crumb.label,
        style: AppTypography.labelSmall.copyWith(
          color: AppColors.primary,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.primary,
        ),
      ),
    );
  }
}
