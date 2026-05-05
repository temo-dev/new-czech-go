import 'package:flutter/material.dart';

import 'auth_text_field.dart';

/// Wraps [AuthTextField] with a show/hide eye toggle. The toggle has an
/// explicit accessibilityLabel because the icon alone is not enough for
/// VoiceOver users.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.helper,
    this.errorText,
    this.autofillHints,
    this.onSubmitted,
    this.onValidate,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String label;
  final String? helper;
  final String? errorText;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String value)? onValidate;
  final TextInputAction? textInputAction;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return AuthTextField(
      controller: widget.controller,
      label: widget.label,
      helper: widget.helper,
      errorText: widget.errorText,
      obscureText: _hidden,
      keyboardType: TextInputType.visiblePassword,
      autofillHints: widget.autofillHints,
      onSubmitted: widget.onSubmitted,
      onValidate: widget.onValidate,
      textInputAction: widget.textInputAction,
      suffix: Semantics(
        label: _hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
        button: true,
        child: IconButton(
          icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _hidden = !_hidden),
          tooltip: _hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
        ),
      ),
    );
  }
}
