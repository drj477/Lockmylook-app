import 'package:flutter/material.dart';

/// ============================================================
/// Brand Colors
/// ============================================================
/// Core brand identity colors.
/// These should rarely change.
/// ============================================================
abstract final class BrandColors {
  const BrandColors._();

  static const Color coral = Color(0xFFFF8D8E);
  static const Color coralDark = Color(0xFFFF7A7C);

  static const Color navy = Color(0xFF1E1A3A);
  static const Color navyLight = Color(0xFF2A254D);

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
}

/// ============================================================
/// Semantic Colors
/// ============================================================
/// Used for communicating status and feedback.
/// ============================================================
abstract final class SemanticColors {
  const SemanticColors._();

  static const Color success = Color(0xFF22C55E);

  static const Color warning = Color(0xFFF59E0B);

  static const Color error = Color(0xFFEF4444);

  static const Color info = Color(0xFF3B82F6);
}

/// ============================================================
/// Light Theme Palette
/// ============================================================
abstract final class LightPalette {
  const LightPalette._();

  static const Color background = Color(0xFFFFF8F8);

  static const Color surface = Color(0xFFFFFFFF);

  static const Color card = Color(0xFFFFFFFF);

  static const Color border = Color(0xFFE5E7EB);

  static const Color divider = Color(0xFFF1F5F9);

  static const Color textPrimary = Color(0xFF1E1A3A);

  static const Color textSecondary = Color(0xFF6B7280);

  static const Color icon = Color(0xFF374151);

  static const Color disabled = Color(0xFFD1D5DB);
}

/// ============================================================
/// Dark Theme Palette
/// ============================================================
abstract final class DarkPalette {
  const DarkPalette._();

  static const Color background = Color(0xFF050816);

  static const Color surface = Color(0xFF11172A);

  static const Color card = Color(0xFF1A2036);

  static const Color border = Color(0xFF2D3653);

  static const Color divider = Color(0xFF30384F);

  static const Color textPrimary = Color(0xFFFFFFFF);

  static const Color textSecondary = Color(0xFFB3BDD1);

  static const Color icon = Color(0xFFE2E8F0);

  static const Color disabled = Color(0xFF64748B);
}
