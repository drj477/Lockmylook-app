import 'package:flutter/material.dart';

/// ============================================================
/// LockMyLook Shadows
/// ============================================================
/// Standard shadows used throughout the application.
/// Never create BoxShadow directly inside widgets.
/// ============================================================
abstract final class AppShadows {
  const AppShadows._();

  /// ----------------------------------------------------------
  /// Cards
  /// ----------------------------------------------------------
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  /// ----------------------------------------------------------
  /// Elevated Cards
  /// ----------------------------------------------------------
  static const List<BoxShadow> elevatedCard = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 20, offset: Offset(0, 8)),
  ];

  /// ----------------------------------------------------------
  /// Dialogs
  /// ----------------------------------------------------------
  static const List<BoxShadow> dialog = [
    BoxShadow(color: Color(0x29000000), blurRadius: 28, offset: Offset(0, 12)),
  ];

  /// ----------------------------------------------------------
  /// Floating Buttons
  /// ----------------------------------------------------------
  static const List<BoxShadow> floating = [
    BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 10)),
  ];

  /// ----------------------------------------------------------
  /// Bottom Sheets
  /// ----------------------------------------------------------
  static const List<BoxShadow> bottomSheet = [
    BoxShadow(color: Color(0x22000000), blurRadius: 30, offset: Offset(0, -6)),
  ];

  /// ----------------------------------------------------------
  /// No Shadow
  /// ----------------------------------------------------------
  static const List<BoxShadow> none = [];
}
