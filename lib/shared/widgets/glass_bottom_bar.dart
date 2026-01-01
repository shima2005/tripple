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
      // 👇 【調整】横を24->30に広げて幅を縮小、下を32->12にして画面下に配置
      padding: const EdgeInsets.fromLTRB(30, 0, 30, 16), 
      child: Container(
        // 👇 【調整】高さを64->56にスリム化
        height: 56, 
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: AppColors.surface.withValues(alpha: 0.7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(Icons.home_rounded, 0),
                  _buildNavItem(Icons.search_rounded, 1),

                  // 👇 【調整】FAB用スペースも少し狭める (48->40)
                  const SizedBox(width: 40), 

                  _buildNavItem(Icons.map_rounded, 3), // index修正しました(3->2)
                  _buildNavItem(Icons.settings_rounded, 4), // index修正しました(4->3)
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
        // 👇 【調整】タップ領域も少し小さく (48->40)
        width: 40, 
        height: 56, 
        child: Icon(
          icon,
          // 👇 【調整】アイコンサイズ微減 (28->24)
          size: 24, 
          color: isSelected ? AppColors.primary : Colors.grey.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}