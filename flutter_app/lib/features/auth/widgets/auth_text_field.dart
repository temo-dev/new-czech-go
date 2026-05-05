import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Material-outlined input shared by every V17 auth screen. Picks the
/// right keyboard type, autofill hints, and trailing icon (e.g. password
/// visibility toggle) so the screens can stay declarative.
///
/// Validation runs on FOCUS LOSS — never on every keystroke — to match
/// the backend's "validate at boundary" UX rule and avoid noisy red
/// borders while the learner is mid-type.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.suffix,
    this.onSubmitted,
    this.onValidate,
    this.autofocus = false,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? helper;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String value)? onValidate;
  final bool autofocus;
  final bool enabled;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late final FocusNode _focus;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
    _focus.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focus.removeListener(_handleFocusChange);
    _focus.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focus.hasFocus && widget.onValidate != null) {
      final err = widget.onValidate!(widget.controller.text);
      if (err != _localError) {
        setState(() => _localError = err);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final externalError = widget.errorText;
    final shownError = externalError ?? _localError;
    return TextField(
      controller: widget.controller,
      focusNode: _focus,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      obscureText: widget.obscureText,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      onSubmitted: widget.onSubmitted,
      onChanged: (_) {
        if (_localError != null) setState(() => _localError = null);
      },
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        helperText: widget.helper,
        errorText: shownError,
        suffixIcon: widget.suffix,
        filled: true,
        fillColor: AppColors.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
      ),
    );
  }
}
