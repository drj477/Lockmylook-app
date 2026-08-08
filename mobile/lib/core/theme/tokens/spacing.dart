import 'package:flutter/widgets.dart';

/// ============================================================
/// App Spacing
/// ============================================================
/// Standard spacing scale used throughout the application.
/// ============================================================
abstract final class AppSpacing {
  const AppSpacing._();

  static const double xxs = 2.0;

  static const double xs = 4.0;

  static const double sm = 8.0;

  static const double md = 12.0;

  static const double lg = 16.0;

  static const double xl = 20.0;

  static const double xxl = 24.0;

  static const double xxxl = 32.0;

  static const double huge = 40.0;

  static const double massive = 48.0;

  static const double gigantic = 64.0;
}

/// ============================================================
/// Common Padding
/// ============================================================
abstract final class AppPadding {
  const AppPadding._();

  /// Standard page padding
  static const EdgeInsets page = EdgeInsets.all(AppSpacing.xxl);

  /// Horizontal screen padding
  static const EdgeInsets screen = EdgeInsets.symmetric(
    horizontal: AppSpacing.xxl,
  );

  /// Card padding
  static const EdgeInsets card = EdgeInsets.all(AppSpacing.lg);

  /// Dialog padding
  static const EdgeInsets dialog = EdgeInsets.all(AppSpacing.xxl);

  /// List item padding
  static const EdgeInsets listItem = EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
    vertical: AppSpacing.md,
  );

  /// Button padding
  static const EdgeInsets button = EdgeInsets.symmetric(
    horizontal: AppSpacing.xxl,
    vertical: AppSpacing.lg,
  );

  /// TextField content padding
  static const EdgeInsets input = EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
    vertical: AppSpacing.md,
  );
}
