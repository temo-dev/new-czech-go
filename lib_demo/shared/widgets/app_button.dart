import 'package:flutter/material.dart';
import 'package:app_czech/core/theme/app_colors.dart';
import 'package:app_czech/core/theme/app_typography.dart';
import 'package:app_czech/core/theme/app_radius.dart';

/// Primary / secondary / text / destructive button.
/// Matches Stitch HTML: hover:opacity-90, active:scale-[0.98], rounded-xl (12px).
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.variant = AppButtonVariant.primary,
    this.fullWidth = true,
    this.loading = false,
    this.size = AppButtonSize.md,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final AppButtonVariant variant;
  final bool fullWidth;
  final bool loading;
  final AppButtonSize size;

  @override
  State<AppButton> createState() => _AppButtonState();
}

enum AppButtonVariant { primary, secondary, text, destructive }
enum AppButtonSize { sm, md, lg }

class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  bool get _disabled => widget.onPressed == null || widget.loading;

  void _handleTapDown(TapDownDetails _) {
    if (!_disabled) _scaleController.forward();
  }

  void _handleTapUp(TapUpDetails _) {
    _scaleController.reverse();
  }

  void _handleTapCancel() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) => Transform.scale(
        scale: _scale.value,
        child: child,
      ),
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: _buildButton(),
      ),
    );
  }

  Widget _buildButton() {
    final height = switch (widget.size) {
      AppButtonSize.sm => 40.0,
      AppButtonSize.md => 52.0,
      AppButtonSize.lg => 60.0,
    };
    final fontSize = switch (widget.size) {
      AppButtonSize.sm => 13.0,
      AppButtonSize.md => 14.0,
      AppButtonSize.lg => 16.0,
    };
    final iconSize = switch (widget.size) {
      AppButtonSize.sm => 16.0,
      AppButtonSize.md => 18.0,
      AppButtonSize.lg => 20.0,
    };

    return switch (widget.variant) {
      AppButtonVariant.primary => _PrimaryBtn(
          label: widget.label,
          onPressed: _disabled ? null : widget.onPressed,
          icon: widget.icon,
          trailingIcon: widget.trailingIcon,
          fullWidth: widget.fullWidth,
          loading: widget.loading,
          height: height,
          fontSize: fontSize,
          iconSize: iconSize,
        ),
      AppButtonVariant.secondary => _SecondaryBtn(
          label: widget.label,
          onPressed: _disabled ? null : widget.onPressed,
          icon: widget.icon,
          fullWidth: widget.fullWidth,
          loading: widget.loading,
          height: height,
          fontSize: fontSize,
          iconSize: iconSize,
        ),
      AppButtonVariant.text => _TextBtn(
          label: widget.label,
          onPressed: _disabled ? null : widget.onPressed,
          icon: widget.icon,
          loading: widget.loading,
          fontSize: fontSize,
        ),
      AppButtonVariant.destructive => _DestructiveBtn(
          label: widget.label,
          onPressed: _disabled ? null : widget.onPressed,
          icon: widget.icon,
          fullWidth: widget.fullWidth,
          loading: widget.loading,
          height: height,
          fontSize: fontSize,
        ),
    };
  }
}

// ── Primary ────────────────────────────────────────────────────────────────────

class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn({
    required this.label,
    required this.onPressed,
    required this.fullWidth,
    required this.loading,
    required this.height,
    required this.fontSize,
    required this.iconSize,
    this.icon,
    this.trailingIcon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool fullWidth;
  final bool loading;
  final double height;
  final double fontSize;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return AnimatedOpacity(
      opacity: disabled ? 0.5 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: SizedBox(
        width: fullWidth ? double.infinity : null,
        height: height,
        child: Material(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppRadius.md),
            hoverColor: Colors.white.withOpacity(0.1),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize:
                          fullWidth ? MainAxisSize.max : MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: iconSize, color: Colors.white),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          label,
                          style: TextStyle(
                            fontFamily: AppFonts.body,
                            fontSize: fontSize,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.1,
                          ),
                        ),
                        if (trailingIcon != null) ...[
                          const SizedBox(width: 8),
                          Icon(trailingIcon,
                              size: iconSize, color: Colors.white),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Secondary (outlined) ───────────────────────────────────────────────────────

class _SecondaryBtn extends StatelessWidget {
  const _SecondaryBtn({
    required this.label,
    required this.onPressed,
    required this.fullWidth,
    required this.loading,
    required this.height,
    required this.fontSize,
    required this.iconSize,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool fullWidth;
  final bool loading;
  final double height;
  final double fontSize;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return AnimatedOpacity(
      opacity: disabled ? 0.5 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: SizedBox(
        width: fullWidth ? double.infinity : null,
        height: height,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppRadius.md),
            hoverColor: AppColors.primary.withOpacity(0.05),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.outlineVariant,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: loading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : Row(
                        mainAxisSize:
                            fullWidth ? MainAxisSize.max : MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (icon != null) ...[
                            Icon(icon,
                                size: iconSize, color: AppColors.primary),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            label,
                            style: TextStyle(
                              fontFamily: AppFonts.body,
                              fontSize: fontSize,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Text ───────────────────────────────────────────────────────────────────────

class _TextBtn extends StatelessWidget {
  const _TextBtn({
    required this.label,
    required this.onPressed,
    required this.loading,
    required this.fontSize,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.secondary,
        textStyle: TextStyle(
          fontFamily: AppFonts.body,
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16),
                  const SizedBox(width: 6),
                ],
                Text(label),
              ],
            ),
    );
  }
}

// ── Destructive ────────────────────────────────────────────────────────────────

class _DestructiveBtn extends StatelessWidget {
  const _DestructiveBtn({
    required this.label,
    required this.onPressed,
    required this.fullWidth,
    required this.loading,
    required this.height,
    required this.fontSize,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool fullWidth;
  final bool loading;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: BorderSide(
            color: AppColors.error.withOpacity(0.3),
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Inline link button — "Quên mật khẩu?", "Đã có tài khoản?"
class InlineLinkButton extends StatelessWidget {
  const InlineLinkButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color,
  });

  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: AppTypography.bodyMedium.copyWith(
          color: color ?? AppColors.primary,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: (color ?? AppColors.primary).withOpacity(0.3),
        ),
      ),
    );
  }
}
