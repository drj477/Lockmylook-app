import 'package:flutter/material.dart';

import 'tokens/colors.dart';
import 'tokens/typography.dart';

/// ============================================================
/// LockMyLook Text Theme
/// ============================================================
/// Maps design tokens to Flutter's TextTheme.
/// ============================================================
abstract final class AppTextTheme {
  const AppTextTheme._();

  static TextTheme get light => AppTypography.textTheme.copyWith(
    displayLarge: _displayLarge(LightPalette.textPrimary),
    displayMedium: _displayMedium(LightPalette.textPrimary),
    displaySmall: _displaySmall(LightPalette.textPrimary),

    headlineLarge: _headline(LightPalette.textPrimary),

    titleLarge: _title(LightPalette.textPrimary),

    bodyLarge: _bodyLarge(LightPalette.textPrimary),
    bodyMedium: _body(LightPalette.textPrimary),
    bodySmall: _bodySmall(LightPalette.textSecondary),

    labelLarge: _button(BrandColors.white),
    labelMedium: _label(LightPalette.textPrimary),
    labelSmall: _caption(LightPalette.textSecondary),
  );

  static TextTheme get dark => AppTypography.textTheme.copyWith(
    displayLarge: _displayLarge(DarkPalette.textPrimary),
    displayMedium: _displayMedium(DarkPalette.textPrimary),
    displaySmall: _displaySmall(DarkPalette.textPrimary),

    headlineLarge: _headline(DarkPalette.textPrimary),

    titleLarge: _title(DarkPalette.textPrimary),

    bodyLarge: _bodyLarge(DarkPalette.textPrimary),
    bodyMedium: _body(DarkPalette.textPrimary),
    bodySmall: _bodySmall(DarkPalette.textSecondary),

    labelLarge: _button(BrandColors.white),
    labelMedium: _label(DarkPalette.textPrimary),
    labelSmall: _caption(DarkPalette.textSecondary),
  );

  // ============================================================
  // Private Builders
  // ============================================================

  static TextStyle _displayLarge(Color color) => TextStyle(
    color: color,
    fontSize: AppFontSize.displayLg,
    fontWeight: AppFontWeight.extraBold,
    height: AppLineHeight.tight,
    letterSpacing: AppLetterSpacing.tight,
  );

  static TextStyle _displayMedium(Color color) => TextStyle(
    color: color,
    fontSize: AppFontSize.displayMd,
    fontWeight: AppFontWeight.bold,
    height: AppLineHeight.tight,
  );

  static TextStyle _displaySmall(Color color) => TextStyle(
    color: color,
    fontSize: AppFontSize.displaySm,
    fontWeight: AppFontWeight.bold,
    height: AppLineHeight.tight,
  );

  static TextStyle _headline(Color color) => TextStyle(
    color: color,
    fontSize: AppFontSize.xxl,
    fontWeight: AppFontWeight.bold,
    height: AppLineHeight.normal,
  );

  static TextStyle _title(Color color) => TextStyle(
    color: color,
    fontSize: AppFontSize.xl,
    fontWeight: AppFontWeight.semiBold,
    height: AppLineHeight.normal,
  );

  static TextStyle _bodyLarge(Color color) => TextStyle(
    color: color,
    fontSize: AppFontSize.lg,
    fontWeight: AppFontWeight.regular,
    height: AppLineHeight.relaxed,
  );

  static TextStyle _body(Color color) => TextStyle(
    color: color,
    fontSize: AppFontSize.md,
    fontWeight: AppFontWeight.regular,
    height: AppLineHeight.relaxed,
  );

  static TextStyle _bodySmall(Color color) => TextStyle(
    color: color,
    fontSize: AppFontSize.sm,
    fontWeight: AppFontWeight.regular,
    height: AppLineHeight.normal,
  );

  static TextStyle _button(Color color) => TextStyle(
    color: color,
    fontSize: AppFontSize.md,
    fontWeight: AppFontWeight.semiBold,
    letterSpacing: AppLetterSpacing.wide,
  );

  static TextStyle _label(Color color) => TextStyle(
    color: color,
    fontSize: AppFontSize.sm,
    fontWeight: AppFontWeight.medium,
  );

  static TextStyle _caption(Color color) => TextStyle(
    color: color,
    fontSize: AppFontSize.xs,
    fontWeight: AppFontWeight.regular,
  );
}
