import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';
import 'package:new_tripple/models/trip.dart';

class TripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback onTap;

  const TripCard({
    super.key,
    required this.trip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 日付フォーマット (例: 2025/11/27)
    final dateStr = DateFormat('yyyy/MM/dd').format(trip.startDate);
    final duration = trip.endDate.difference(trip.startDate).inDays + 1;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24), // カード間の余白
        height: 150, // 高さは固定で見栄え良く
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          // 影をつけて浮遊感を出す
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // 1. 背景画像 (Heroアニメーション対象)
              Positioned.fill(
                child: Hero(
                  tag: 'trip-img-${trip.id}', // 一意なタグをつける
                  child: _buildBackgroundImage(),
                ),
              ),

              // 2. 黒いグラデーション (文字を見やすくするため)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7), // 下の方を暗く
                      ],
                    ),
                  ),
                ),
              ),

              // 3. テキスト情報 (左下)
              Positioned(
                left: 20,
                bottom: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.title,
                      style: AppTextStyles.h2.copyWith(color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, color: Colors.white70, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          '$dateStr ($duration Days)',
                          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 4. 右上のメニューなど (必要なら)
              //TODO ここに「残り日数」などのバッジを置いてもカッコいい
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundImage() {
    if (trip.coverImageUrl != null && trip.coverImageUrl!.isNotEmpty) {
      // 👇 ここを書き換え！
      return CachedNetworkImage(
        imageUrl: trip.coverImageUrl!,
        fit: BoxFit.cover,
        // 画像読み込み中に表示するウィジェット
        placeholder: (context, url) => Container(
          color: Colors.grey[200],
          child: const Center(child: CircularProgressIndicator()),
        ),
        // エラー時に表示するウィジェット (デフォルトグラデーション)
        errorWidget: (context, url, error) => _buildDefaultGradient(),
      );
    } else {
      return _buildDefaultGradient();
    }
  }

  Widget _buildDefaultGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF4facfe), // サンプル: 綺麗な青
            Color(0xFF00f2fe), // サンプル: 水色
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.flight_takeoff, color: Colors.white24, size: 64),
      ),
    );
  }
}