import 'package:flutter/material.dart';

/// Reusable text field. Optional fill color, hint, and trailing icon (e.g. password visibility).
class CustomTextField extends StatelessWidget {
  const CustomTextField({
    required this.label,
    this.controller,
    this.obscureText = false,
    this.hintText,
    this.fillColor,
    this.suffixIcon,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final bool obscureText;
  /// If null, [label] is used as hint.
  final String? hintText;
  /// Light grey fill when set (e.g. login screen).
  final Color? fillColor;
  /// Trailing widget (e.g. eye icon for password).
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          // When filled style, show hint only (no floating label) to match design
          labelText: fillColor != null ? null : label,
          hintText: hintText ?? label,
          filled: fillColor != null,
          fillColor: fillColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}
