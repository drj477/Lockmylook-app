import 'package:flutter/material.dart';

import 'app_text_theme.dart';
import 'tokens/colors.dart';
import 'tokens/radius.dart';

import 'tokens/spacing.dart';

abstract final class AppTheme {
  const AppTheme._();

  // ==========================================================
  // LIGHT THEME
  // ==========================================================

  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      primary: BrandColors.coral,
      secondary: BrandColors.navy,
      surface: LightPalette.surface,
      error: SemanticColors.error,
      onPrimary: BrandColors.white,
      onSecondary: BrandColors.white,
      onSurface: LightPalette.textPrimary,
      onError: BrandColors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      colorScheme: colorScheme,

      scaffoldBackgroundColor: LightPalette.background,

      textTheme: AppTextTheme.light,

      dividerColor: LightPalette.divider,

      cardColor: LightPalette.card,

      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: LightPalette.textPrimary,
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: LightPalette.card,
        shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.card),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: LightPalette.surface,

        contentPadding: AppPadding.input,

        border: OutlineInputBorder(
          borderRadius: AppBorderRadius.input,
          borderSide: const BorderSide(color: LightPalette.border),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: AppBorderRadius.input,
          borderSide: const BorderSide(color: LightPalette.border),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: AppBorderRadius.input,
          borderSide: const BorderSide(color: BrandColors.coral, width: 2),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,

          backgroundColor: BrandColors.coral,

          foregroundColor: BrandColors.white,

          padding: AppPadding.button,

          shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.button),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: AppPadding.button,

          shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.button),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: AppPadding.button,

          shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.button),
        ),
      ),

      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: LightPalette.surface,

        indicatorColor: BrandColors.coral,
      ),

      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.dialog),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: AppBorderRadius.bottomSheet,
        ),

        backgroundColor: LightPalette.surface,
      ),
    );
  }

  // ==========================================================
  // DARK THEME
  // ==========================================================

  static ThemeData get dark {
    const colorScheme = ColorScheme.dark(
      primary: BrandColors.coral,
      secondary: BrandColors.navy,
      surface: DarkPalette.surface,
      error: SemanticColors.error,
      onPrimary: BrandColors.white,
      onSecondary: BrandColors.white,
      onSurface: DarkPalette.textPrimary,
      onError: BrandColors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      colorScheme: colorScheme,

      scaffoldBackgroundColor: DarkPalette.background,

      textTheme: AppTextTheme.dark,

      dividerColor: DarkPalette.divider,

      cardColor: DarkPalette.card,

      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: DarkPalette.textPrimary,
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: DarkPalette.card,
        shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.card),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DarkPalette.surface,

        contentPadding: AppPadding.input,

        border: OutlineInputBorder(
          borderRadius: AppBorderRadius.input,
          borderSide: const BorderSide(color: DarkPalette.border),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: AppBorderRadius.input,
          borderSide: const BorderSide(color: DarkPalette.border),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: AppBorderRadius.input,
          borderSide: const BorderSide(color: BrandColors.coral, width: 2),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,

          backgroundColor: BrandColors.coral,

          foregroundColor: BrandColors.white,

          padding: AppPadding.button,

          shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.button),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: AppPadding.button,

          shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.button),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: AppPadding.button,

          shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.button),
        ),
      ),

      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: DarkPalette.surface,

        indicatorColor: BrandColors.coral,
      ),

      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppBorderRadius.dialog),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: AppBorderRadius.bottomSheet,
        ),

        backgroundColor: DarkPalette.surface,
      ),
    );
  }
}
