import 'dart:convert';

import 'package:flutter/material.dart';

/// Shows the user's profile photo: [imageRef] may be empty (default asset), an http(s) URL,
/// a data URI (`data:image/...;base64,...`), or raw base64 bytes as a string.
class ProfileAvatarImage extends StatelessWidget {
  const ProfileAvatarImage({
    super.key,
    required this.imageRef,
    this.size = 52,
    this.fit = BoxFit.cover,
  });

  /// Mongo/API `image` value, or empty for bundled default portrait.
  final String? imageRef;
  final double size;
  final BoxFit fit;

  /// Bundled placeholder when [imageRef] is empty or invalid.
  static const String defaultAsset =
      'depositphotos_745925384-stock-photo-businessman-portrait-outdoor-smiling-mature.webp';

  Widget _fallback() {
    return ColoredBox(
      color: Colors.grey.shade300,
      child: Icon(Icons.person, size: size * 0.45, color: Colors.grey.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ref = (imageRef ?? '').trim();
    if (ref.isEmpty) {
      return Image.asset(
        defaultAsset,
        width: size,
        height: size,
        fit: fit,
        errorBuilder: (_, __, ___) => SizedBox(width: size, height: size, child: _fallback()),
      );
    }
    if (ref.startsWith('data:image')) {
      try {
        final comma = ref.indexOf(',');
        if (comma == -1) {
          return SizedBox(width: size, height: size, child: _fallback());
        }
        final bytes = base64Decode(ref.substring(comma + 1).trim());
        return Image.memory(
          bytes,
          width: size,
          height: size,
          fit: fit,
          errorBuilder: (_, __, ___) => SizedBox(width: size, height: size, child: _fallback()),
        );
      } catch (_) {
        return SizedBox(width: size, height: size, child: _fallback());
      }
    }
    final lower = ref.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return Image.network(
        ref,
        width: size,
        height: size,
        fit: fit,
        errorBuilder: (_, __, ___) => SizedBox(width: size, height: size, child: _fallback()),
      );
    }
    try {
      final bytes = base64Decode(ref);
      return Image.memory(
        bytes,
        width: size,
        height: size,
        fit: fit,
        errorBuilder: (_, __, ___) => SizedBox(width: size, height: size, child: _fallback()),
      );
    } catch (_) {
      return Image.asset(
        defaultAsset,
        width: size,
        height: size,
        fit: fit,
        errorBuilder: (_, __, ___) => SizedBox(width: size, height: size, child: _fallback()),
      );
    }
  }
}
