import 'package:flutter/material.dart';

class AppColors {
  // โทนสดใสแบบการ์ตูน: พื้นครีม + ส้มโคอรัลเป็นสีหลัก + สีสดแยกตามหมวด
  static const navy = Color(0xFF2B2233);
  static const primary = Color(0xFFF4694F);
  static const primaryDark = Color(0xFFD9503A);
  static const teal = Color(0xFF3FB8A0);
  static const background = Color(0xFFFFF6EA);
  static const surface = Colors.white;
  static const text = Color(0xFF2B2233);
  static const textSoft = Color(0xFF8C7E78);
  static const border = Color(0xFFF1E1CC);
  static const success = Color(0xFF2E9E6B);
  static const warning = Color(0xFFF2A33A);
  static const danger = Color(0xFFD6455D);

  static const blue = Color(0xFF3B7DDD);
  static const green = Color(0xFF4FB99A);
  static const purple = Color(0xFF8E7CE0);
  static const pink = Color(0xFFD9507F);
  static const mustard = Color(0xFFF2A33A);
  static const coralLight = Color(0xFFFF8A5B);

  // ธีมฝั่งแอดมิน: โทนฟ้า + พื้นครีมอ่อน (ส้มเป็นสีเน้น)
  static const adminBlue = Color(0xFF3D70C4);
  static const adminBlueDark = Color(0xFF2D569E);
  static const adminBg = Color(0xFFF7F3EB);
  static const adminBorder = Color(0xFFE6DFD1);
  static const teal2 = Color(0xFF2FA4B8);
}

ThemeData buildAppTheme({bool admin = false}) {
  final primary = admin ? AppColors.adminBlue : AppColors.primary;
  final primaryDark = admin ? AppColors.adminBlueDark : AppColors.primaryDark;
  final bg = admin ? AppColors.adminBg : AppColors.background;
  final border = admin ? AppColors.adminBorder : AppColors.border;
  final outline = admin ? const Color(0xFFBFD0EE) : const Color(0xFFF0CDB5);
  final scheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: Brightness.light,
    primary: primary,
    secondary: AppColors.teal,
    surface: AppColors.surface,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    fontFamily: 'Prompt',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.text,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: AppColors.textSoft),
      labelStyle: const TextStyle(color: AppColors.textSoft),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: primary, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(fontFamily: 'Prompt', fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryDark,
        side: BorderSide(color: outline, width: 1.4),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(fontFamily: 'Prompt', fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: border),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: primary.withValues(alpha: 0.12),
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w600,
          color: states.contains(WidgetState.selected) ? primary : AppColors.textSoft,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected) ? primary : AppColors.textSoft,
        );
      }),
    ),
  );
}
