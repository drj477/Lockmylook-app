import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ------------------------------------------------------------
/// Font Family
/// ------------------------------------------------------------
abstract final class AppTypography {
  static TextTheme get textTheme => GoogleFonts.interTextTheme();
}

/// ------------------------------------------------------------
/// Font Sizes
/// ------------------------------------------------------------
abstract final class AppFontSize {
  static const double xs = 12.0;
  static const double sm = 14.0;
  static const double md = 16.0;
  static const double lg = 18.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double displaySm = 32.0;
  static const double displayMd = 40.0;
  static const double displayLg = 48.0;
}

/// ------------------------------------------------------------
/// Font Weights
/// ------------------------------------------------------------
abstract final class AppFontWeight {
  static const FontWeight regular = FontWeight.w400;

  static const FontWeight medium = FontWeight.w500;

  static const FontWeight semiBold = FontWeight.w600;

  static const FontWeight bold = FontWeight.w700;

  static const FontWeight extraBold = FontWeight.w800;
}

/// ------------------------------------------------------------
/// Line Heights
/// ------------------------------------------------------------
abstract final class AppLineHeight {
  static const double tight = 1.2;

  static const double normal = 1.4;

  static const double relaxed = 1.6;
}

/// ------------------------------------------------------------
/// Letter Spacing
/// ------------------------------------------------------------
abstract final class AppLetterSpacing {
  static const double tight = -0.5;

  static const double normal = 0.0;

  static const double wide = 0.5;
}
