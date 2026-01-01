import 'package:flutter/material.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';

/// 統一されたヘッダー (タイトル + 任意のアクション)
class CustomHeader extends StatelessWidget {
  final String title;
  final bool isCenter;

  const CustomHeader({
    super.key,
    required this.title,
    this.isCenter = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(0, 0, 8, 16),
      child: Text(
        title,
        style: AppTextStyles.h1.copyWith(
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          height: 1.2,
        ),
        textAlign: isCenter ? TextAlign.center : TextAlign.left,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ) ;
  }
}
