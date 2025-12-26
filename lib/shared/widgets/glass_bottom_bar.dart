import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:new_tripple/core/theme/app_colors.dart';

class GlassBottomBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const GlassBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 下の余白を少し減らして、コンテンツとの一体感を出す
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Container(
        height: 64, // 少しスリムに
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          // 影を強化して「浮いてる感」を出す！
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.15), // 影の色を濃く
              blurRadius: 20, // ぼかしを強く
              offset: const Offset(0, 10), // 下に落とす
            ),
          ],
        ),
        // ClipRRectですりガラスを角丸に切り抜く
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: AppColors.surface.withValues(alpha: 0.7), // 透明度調整
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly, // 均等配置に変更
                children: [
                  _buildNavItem(Icons.home_rounded, 0),
                  _buildNavItem(Icons.search_rounded, 1),

                  // 真ん中のFAB用スペース (FABを小さくするからここも狭める)
                  const SizedBox(width: 48),

                  _buildNavItem(Icons.map_rounded, 3),
                  _buildNavItem(Icons.settings_rounded, 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    final isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 48, // タップエリア調整
        height: double.infinity,
        child: Icon(
          icon,
          size: 26, // アイコンサイズ微調整
          color: isSelected ? AppColors.primary : AppColors.textSecondary.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}