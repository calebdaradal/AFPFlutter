import 'package:flutter/material.dart';

/// Reusable full-width button. Optional custom colors (e.g. blue for primary actions).
class CustomButton extends StatelessWidget {
  const CustomButton({
    required this.label,
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  /// When set, button uses this background (e.g. brand blue).
  final Color? backgroundColor;
  /// When set, text uses this color (e.g. white).
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: (backgroundColor != null || foregroundColor != null)
            ? ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: backgroundColor,
                foregroundColor: foregroundColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              )
            : null,
        child: Text(label, style: const TextStyle(fontSize: 17)),
      ),
    );
  }
}
