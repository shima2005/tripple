import 'package:flutter/material.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';

class TrippleModalHeader extends StatelessWidget {
  final String title;
  final IconData? icon; // アイコンを入れたい場合のみ指定
  final VoidCallback? onClose; // 指定しなければ Navigator.pop
  final List<Widget>? actions; // スキャンボタンなどを入れたい場合

  const TrippleModalHeader({
    super.key,
    required this.title,
    this.icon,
    this.onClose,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 1. アイコン (あれば)
        if (icon != null) ...[
          Icon(icon, size: 28, color: Colors.black87), // 色は適宜調整
          const SizedBox(width: 12),
        ],

        // 2. タイトル (長すぎても省略してレイアウト崩れを防ぐ)
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.h2.copyWith(fontSize: 22),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // 3. アクションエリア (スキャンボタン + 閉じるボタン)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (actions != null) ...[
              ...actions!.map((action) => Padding(
                padding: const EdgeInsets.only(right: 12),
                child: action,
              )),
            ],

            // 閉じるボタン (統一デザイン)
            InkWell(
              onTap: onClose ?? () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
              ),
            ),
          ],
        ),
      ],
    );
  }
}