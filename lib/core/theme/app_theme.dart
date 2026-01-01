import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  // 引数なしのゲッターに変更
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      
      // 🎨 1. 色を直接指定 (AppColorsを使用)
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        // 👇 背景色を明示的に指定
        surface: AppColors.background, 
        surfaceTint: Colors.white, // これが紫がかる原因なので白にする
      ),
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primary,
    

      // 📱 3. AppBar (透明)
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20, 
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),

      // 🃏 4. Card (白背景)
      cardTheme: CardTheme(
        color: Colors.white, // Tintなしの純白
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
    );
  }
}