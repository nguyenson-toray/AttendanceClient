import 'package:flutter/material.dart';

/// Design tokens for "Indigo Soft" light theme.
class AppColors {
  AppColors._();

  // ── Brand / Primary ──
  static const primary = Color(0xFF5566EB);
  static const primaryPressed = Color(0xFF3D4ECF);
  static const primaryTint = Color(0xFFECEDFE);
  static const onPrimary = Color(0xFFFFFFFF);

  // ── Background & Surface ──
  static const bgPage = Color(0xFFF5F6FB);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFFAFBFE);

  // ── Text ──
  static const textPrimary = Color(0xFF1E2433);
  static const textSecondary = Color(0xFF6B7280);
  static const textTertiary = Color(0xFF9CA3B4);

  // ── Border / Divider ──
  static const border = Color(0xFFE6E8F0);
  static const borderStrong = Color(0xFFD5D8E5);

  // ── Semantic: Success ──
  static const success = Color(0xFF2FB97A);
  static const successTint = Color(0xFFE4F6EE);
  static const successText = Color(0xFF1F7A52);

  // ── Semantic: Warning ──
  static const warning = Color(0xFFF4A93C);
  static const warningTint = Color(0xFFFDF0DC);
  static const warningText = Color(0xFF8A5A12);

  // ── Semantic: Danger / Error ──
  static const danger = Color(0xFFEF5F5F);
  static const dangerTint = Color(0xFFFCE9E9);
  static const dangerText = Color(0xFFA8302F);

  // ── Semantic: Info ──
  static const info = Color(0xFF3B9EED);
  static const infoTint = Color(0xFFE6F3FD);
  static const infoText = Color(0xFF1C6CA8);
}
