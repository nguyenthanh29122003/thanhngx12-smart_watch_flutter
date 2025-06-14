// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Lớp chứa các mã màu đã thống nhất để dễ dàng quản lý và tái sử dụng.
class AppColors {
  static const Color lightestBlue = Color(0xFFDCF2F1); // Nền sáng
  static const Color skyBlue = Color(0xFF7FC7D9); // Màu nhấn, màu chính (tối)
  static const Color deepIndigo = Color(0xFF365486); // Màu chính (sáng)
  static const Color navyBlue = Color(0xFF0F1035); // Nền tối, chữ (sáng)
}

class AppTheme {
  // --- THEME CHO CHẾ ĐỘ SÁNG (LIGHT MODE) ---
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.deepIndigo,
      scaffoldBackgroundColor: AppColors.lightestBlue,

      // Định nghĩa bảng màu chi tiết cho các thành phần Material 3
      colorScheme: const ColorScheme.light(
        primary: AppColors.deepIndigo, // Màu chính cho AppBar, nút chính...
        onPrimary: Colors.white, // Chữ/icon trên nền màu chính
        secondary: AppColors.skyBlue, // Màu nhấn cho FAB, switch...
        onSecondary: AppColors.navyBlue, // Chữ/icon trên nền màu nhấn
        background: AppColors.lightestBlue, // Nền chính của ứng dụng
        onBackground: AppColors.navyBlue, // Chữ chính trên nền
        surface: Colors.white, // Nền của Card, Dialog, BottomSheet
        onSurface: AppColors.navyBlue, // Chữ trên nền Card
        error: Color(0xFFB00020),
        onError: Colors.white,
      ),

      // Định nghĩa font chữ
      textTheme: GoogleFonts.quicksandTextTheme(
        ThemeData.light().textTheme,
      ).copyWith(
        // Font cho các tiêu đề lớn
        headlineSmall: GoogleFonts.quicksand(
            fontWeight: FontWeight.bold, color: AppColors.navyBlue),
        // Font cho các tiêu đề vừa
        titleLarge: GoogleFonts.quicksand(
            fontWeight: FontWeight.w600, color: AppColors.navyBlue),
        titleMedium: GoogleFonts.quicksand(
            fontWeight: FontWeight.w500, color: AppColors.deepIndigo),
        // Font cho các nội dung chính
        bodyMedium: const TextStyle(color: AppColors.navyBlue),
        // Font cho các nội dung phụ, chú thích
        bodySmall: TextStyle(color: AppColors.deepIndigo.withOpacity(0.8)),
      ),

      // Tùy chỉnh theme cho các widget cụ thể
      cardTheme: CardTheme(
        elevation: 2,
        color: Colors.white,
        shadowColor: AppColors.deepIndigo.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent, // Nền AppBar trong suốt
        elevation: 0,
        foregroundColor: AppColors.deepIndigo, // Màu chữ và icon trên AppBar
        centerTitle: false, // Tiêu đề căn trái
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.deepIndigo,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: GoogleFonts.quicksand(fontWeight: FontWeight.w600),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.skyBlue,
        foregroundColor: AppColors.navyBlue,
      ),
    );
  }

  // --- THEME CHO CHẾ ĐỘ TỐI (DARK MODE) ---
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.skyBlue,
      scaffoldBackgroundColor: AppColors.navyBlue,

      // Bảng màu cho chế độ tối
      colorScheme: const ColorScheme.dark(
        primary: AppColors.skyBlue,
        onPrimary: AppColors.navyBlue,
        secondary: AppColors.skyBlue,
        onSecondary: AppColors.navyBlue,
        background: AppColors.navyBlue,
        onBackground: AppColors.lightestBlue,
        surface: Color(0xFF1E293B), // Màu nền Card, đậm hơn nền chính
        onSurface: AppColors.lightestBlue,
        error: Colors.red,
        onError: Colors.white,
      ),

      // Font chữ cho chế độ tối
      textTheme: GoogleFonts.manropeTextTheme(
        ThemeData.dark().textTheme,
      ).copyWith(
        headlineSmall: GoogleFonts.quicksand(
            fontWeight: FontWeight.bold, color: AppColors.lightestBlue),
        titleLarge: GoogleFonts.quicksand(
            fontWeight: FontWeight.w600, color: AppColors.lightestBlue),
        titleMedium: GoogleFonts.quicksand(
            fontWeight: FontWeight.w500, color: AppColors.skyBlue),
        bodyMedium: TextStyle(color: AppColors.lightestBlue.withOpacity(0.9)),
        bodySmall: TextStyle(color: AppColors.skyBlue.withOpacity(0.8)),
      ),

      // Tùy chỉnh widget cho chế độ tối
      cardTheme: CardTheme(
        elevation: 1,
        color: const Color(0xFF1E293B), // Nền card
        shadowColor: Colors.black.withOpacity(0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.skyBlue,
        centerTitle: false,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.skyBlue,
          foregroundColor: AppColors.navyBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: GoogleFonts.quicksand(fontWeight: FontWeight.w600),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.skyBlue,
        foregroundColor: AppColors.navyBlue,
      ),
    );
  }
}
