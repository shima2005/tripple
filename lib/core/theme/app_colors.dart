import 'package:flutter/material.dart';

class AppColors {
  // メインカラー (Midnight Blue) - 知的で落ち着いた青
  static const Color primary = Color(0xFF1A237E);
  
  // アクセントカラー (Emerald Green) - 旅のワクワク感
  static const Color accent = Color(0xFF00B894);

  static const Color third = Color(0xFFFF9F43);

  // グラデーション用 (Primary -> Accent)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // 背景色
  static const Color background = Color(0xFFF8F9FA); // ほんのりグレーがかった白 (目に優しい)
  static const Color surface = Color(0xFFFFFFFF);    // 完全な白 (カード用)

  // テキスト色
  static const Color textPrimary = Color(0xFF2D3436);   // 濃いグレー (真っ黒ではない)
  static const Color textSecondary = Color(0xFF636E72); // 薄いグレー

  // UI用
  static const Color error = Color(0xFFD63031);
  static const Color shadow = Color(0x1A000000); // 薄ーい影色 (浮遊感用)
}