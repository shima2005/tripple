import 'package:flutter/material.dart';
import 'package:new_tripple/core/theme/app_colors.dart';

class TrippleToast {
  static void show(BuildContext context, String message, {bool isError = false}) {
    // 既存のスナックバーを消してから新しいのを出す
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating, // 浮き上がらせる
        backgroundColor: isError ? Colors.redAccent : AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // 丸角
        margin: const EdgeInsets.all(16), // 端の余白
        elevation: 4,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}