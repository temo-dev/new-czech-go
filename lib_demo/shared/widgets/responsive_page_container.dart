import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_spacing.dart';

/// Centers content with a max-width cap and responsive horizontal padding.
/// Wrap the scrollable body of every screen with this.
class ResponsivePageContainer extends StatelessWidget {
  const ResponsivePageContainer({
    super.key,
    required this.child,
    this.maxWidth = AppSpacing.maxContentWidth,
    this.addHorizontalPadding = true,
    this.verticalPadding,
  });

  final Widget child;
  final double maxWidth;
  final bool addHorizontalPadding;
  final EdgeInsets? verticalPadding;

  @override
  Widget build(BuildContext context) {
    final hPad =
        addHorizontalPadding ? AppSpacing.pagePaddingH(context) : 0.0;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad).add(
            verticalPadding ?? EdgeInsets.zero,
          ),
          child: child,
        ),
      ),
    );
  }
}
