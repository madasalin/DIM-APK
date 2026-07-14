import 'package:flutter/material.dart';

/// 데스크톱 DIM.py 의 APP_QSS 색상 팔레트를 그대로 사용한다.
class AppColors {
  static const pass = Color(0xFF1E8449);
  static const fail = Color(0xFFB03A2E);
  static const neutral = Color(0xFF5A6A7A);
  static const accent = Color(0xFF2F6FB0);
  static const bg = Color(0xFFEEF2F6);
  static const cardBorder = Color(0xFFB9C7D6);
  static const titleColor = Color(0xFF16324F);
  static const scanBtnHover = Color(0xFF26608F);
  static const zeroBtn = Color(0xFF5A6A7A);
}

const List<String> chNames = ["R1", "R2", "R3", "R4"];

ThemeData buildAppTheme() {
  return ThemeData(
    scaffoldBackgroundColor: AppColors.bg,
    fontFamily: 'NotoSansKR',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      background: AppColors.bg,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.titleColor,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF22344A),
        side: const BorderSide(color: Color(0xFF9FB3C8)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    ),
  );
}
