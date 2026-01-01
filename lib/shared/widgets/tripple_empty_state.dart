import 'package:flutter/material.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';

class TrippleEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color? accentColor;

  const TrippleEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.primary;

    return Center( // 親でExpandedされてることが多いのでCenterで囲む
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.1)),
          // 👇 ほんのり影をつけても可愛いかも（お好みで）
          boxShadow: [
             BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // 中身に合わせて高さを縮める
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 16),
            Text(title, style: AppTextStyles.h3, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}