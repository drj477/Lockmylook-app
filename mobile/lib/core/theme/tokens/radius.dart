import 'package:flutter/widgets.dart';

/// ============================================================
/// Radius Tokens
/// ============================================================
/// Raw radius values.
/// ============================================================
abstract final class AppRadius {
  const AppRadius._();

  static const double none = 0.0;

  static const double xs = 4.0;

  static const double sm = 8.0;

  static const double md = 12.0;

  static const double lg = 16.0;

  static const double xl = 20.0;

  static const double xxl = 24.0;

  static const double full = 999.0;
}

/// ============================================================
/// Semantic Border Radius
/// ============================================================
/// Use these throughout the application instead of creating
/// BorderRadius.circular() directly.
/// ============================================================
abstract final class AppBorderRadius {
  const AppBorderRadius._();

  /// Small chips & badges
  static const BorderRadius chip = BorderRadius.all(
    Radius.circular(AppRadius.full),
  );

  /// Buttons
  static const BorderRadius button = BorderRadius.all(
    Radius.circular(AppRadius.full),
  );

  /// Text Fields
  static const BorderRadius input = BorderRadius.all(
    Radius.circular(AppRadius.lg),
  );

  /// Cards
  static const BorderRadius card = BorderRadius.all(
    Radius.circular(AppRadius.lg),
  );

  /// Images
  static const BorderRadius image = BorderRadius.all(
    Radius.circular(AppRadius.lg),
  );

  /// Dialogs
  static const BorderRadius dialog = BorderRadius.all(
    Radius.circular(AppRadius.xl),
  );

  /// Bottom Sheets
  static const BorderRadius bottomSheet = BorderRadius.vertical(
    top: Radius.circular(AppRadius.xxl),
  );
}
