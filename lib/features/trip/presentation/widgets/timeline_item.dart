import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';
import 'package:new_tripple/models/schedule_item.dart';
import 'package:new_tripple/models/route_item.dart';
import 'package:new_tripple/models/step_detail.dart';
import 'package:new_tripple/models/enums.dart';
import 'package:new_tripple/services/routing_service.dart';

class TimelineItemWidget extends StatelessWidget {
  final Object item;
  final bool isLast;
  final bool isReadOnly;
  final Function(Object)? onTap;
  final Function(ScheduledItem)? onMapTap;

  const TimelineItemWidget({
    super.key,
    required this.item,
    this.isLast = false,
    this.onTap,
    this.onMapTap,
    this.isReadOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    if (item is ScheduledItem) {
      return _ScheduledRow(
        item: item as ScheduledItem,
        isReadOnly: isReadOnly,
        isLast: isLast,
        onTap: () => onTap?.call(item), 
        onMapTap: () => onMapTap?.call(item as ScheduledItem),
      );
    } else if (item is RouteItem) {
      return _RouteRow(
        isReadOnly: isReadOnly,
        item: item as RouteItem,
        onEdit: () => onTap?.call(item), 
      );
    }
    return const SizedBox();
  }
}

// ==============================================================================
// 共通レイアウト: 左の時間、中央の線、右のコンテンツ
// ==============================================================================
class _TimelineLayoutHelper extends StatelessWidget {
  final String timeText;
  final Widget centerNode;
  final Widget content;
  final bool isLast;
  final bool isRoute;
  final bool isReadOnly;

  const _TimelineLayoutHelper({
    required this.timeText,
    required this.centerNode,
    required this.content,
    this.isLast = false,
    this.isRoute = false,
    required this.isReadOnly,
  });

  @override
  Widget build(BuildContext context) {
    // 👇 幅を少し詰めてカード領域を確保
    const double timeWidth = 44; 
    const double axisWidth = 24;
    const double leftOffset = timeWidth;

    return Stack(
      children: [
        if (!isLast)
          Positioned(
            left: leftOffset + (axisWidth / 2) - 1,
            top: 0,
            bottom: 0,
            width: 2,
            child: Container(
              color: Colors.grey.shade300,
            ),
          ),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A. 左側: 時間 (左詰め & 幅縮小)
            SizedBox(
              width: timeWidth,
              child: Padding(
                padding: const EdgeInsets.only(top: 24, left: 4),
                child: Text(
                  timeText,
                  style: AppTextStyles.label.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  textAlign: TextAlign.start,
                ),
              ),
            ),

            // B. 中央: ノード (アイコン)
            SizedBox(
              width: axisWidth,
              child: Center(
                heightFactor: 1.0,
                child: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: centerNode,
                ),
              ),
            ),

            // C. 右側: カードなどのコンテンツ
            Expanded(
              child: Padding(
                padding: isRoute 
                    ? const EdgeInsets.fromLTRB(0, 16, 0, 0)
                    : const EdgeInsets.fromLTRB(12, 0, 0, 24),
                child: content,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// -------------------------------------------------------
// 📍 滞在の行 (ScheduledRow)
// -------------------------------------------------------
class _ScheduledRow extends StatelessWidget {
  final ScheduledItem item;
  final bool isLast;
  final VoidCallback? onTap;
  final VoidCallback? onMapTap;
  final bool isReadOnly;

  const _ScheduledRow({required this.item, required this.isLast, this.onTap, required this.onMapTap, required this.isReadOnly,});

  @override
  Widget build(BuildContext context) {
    final startTime = DateFormat('HH:mm').format(item.time);
    String? timeRange;
    if (item.durationMinutes != null) {
      final endTime = item.time.add(Duration(minutes: item.durationMinutes!));
      timeRange = '$startTime - ${DateFormat('HH:mm').format(endTime)}';
    } else {
      timeRange = startTime;
    }

    return _TimelineLayoutHelper(
      isLast: isLast,
      isReadOnly: isReadOnly,
      timeText: startTime,
      centerNode: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary, width: 2),
          boxShadow: [
            BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Icon(
          item.category.icon,
          size: 14,
          color: AppColors.primary,
        ),
      ),
      content: GestureDetector(
        onTap: !isReadOnly ? onTap: null,
        child: _ScheduledCardContent(item: item, timeRange: timeRange, onMapTap: onMapTap,),
      ),
    );
  }
}

// 滞在カード (モバイル最適化版)
class _ScheduledCardContent extends StatelessWidget {
  final ScheduledItem item;
  final String timeRange;
  final VoidCallback? onMapTap;

  const _ScheduledCardContent({required this.item, required this.timeRange, this.onMapTap});
  
  @override
  Widget build(BuildContext context) {
    final hasLocation = item.latitude != null && item.longitude != null;
    final hasMemo = item.notes != null && item.notes!.isNotEmpty;

    return Container(
      // height: 100, // 👈 固定高さを削除
      constraints: const BoxConstraints(minHeight: 70), // メモなし時はコンパクトに
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 6, offset: Offset(0, 3))],
      ),
      // 👇 画像とコンテンツの高さを揃えるためにIntrinsicHeightを使用 (リスト項目数が少ないためパフォーマンス影響は軽微)
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. 画像エリア
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: SizedBox(
                width: 80,
                child: item.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: item.imageUrl!,
                        fit: BoxFit.cover,
                        // heightを指定しないことで、IntrinsicHeightにより親の高さに合わせて伸縮
                        placeholder: (context, url) => Container(color: Colors.grey[100]),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      )
                    : Container(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        child: Center(
                          child: Icon(
                            item.category.icon,
                            color: AppColors.primary.withValues(alpha: 0.5),
                            size: 28,
                          ),
                        ),
                      ),
              ),
            ),
      
            // 2. 情報エリア
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center, // コンテンツが少ないときは中央寄せ
                  children: [
                    // タイトル
                    Text(
                      item.name,
                      style: AppTextStyles.h3.copyWith(fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    
                    // 時間
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            timeRange,
                            style: AppTextStyles.label.copyWith(fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    // コスト (👇 時間とは別の行に表示)
                    if (item.cost != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.attach_money_rounded, size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${item.cost!.toInt()}',
                              style: AppTextStyles.label.copyWith(fontSize: 10),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
      
                    // メモ欄 (👇 存在する場合のみ表示。maxLinesで高さを制限)
                    if (hasMemo) ...[
                      const SizedBox(height: 8), // 少し余白
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start, // アイコンを上揃え
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.sticky_note_2_rounded, size: 10, color: Colors.grey),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                item.notes!,
                                style: AppTextStyles.bodyMedium.copyWith(fontSize: 10, color: Colors.grey[700]),
                                maxLines: 2, // 👈 2行までに制限して高さを抑える
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
      
            // 3. 地図ボタン (右端)
            if (hasLocation)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => onMapTap?.call(),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.map_rounded, size: 18, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------
// 🚃 移動の行 (RouteRow) - モバイル対応版
// -------------------------------------------------------
class _RouteRow extends StatefulWidget {
  final RouteItem item;
  final VoidCallback? onEdit;
  final bool isReadOnly; 
  
  const _RouteRow({required this.item, this.onEdit, required this.isReadOnly,});

  @override
  State<_RouteRow> createState() => _RouteRowState();
}

class _RouteRowState extends State<_RouteRow> {
  bool _isExpanded = false;

  // 👇 アイコンボタンの共通デザイン
  Widget _buildUnifiedIconButton({required Widget child, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30, 
        height: 30, // 👈 サイズを統一
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade200), // 薄いボーダーで統一感
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))
          ],
        ),
        child: Center(child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final startTime = DateFormat('HH:mm').format(widget.item.time);

    final hasCoords = widget.item.startLatitude != null && 
                      widget.item.startLongitude != null &&
                      widget.item.endLatitude != null && 
                      widget.item.endLongitude != null;

    return _TimelineLayoutHelper(
      isReadOnly: widget.isReadOnly,
      isRoute: true,
      timeText: startTime,
      centerNode: Container(
        height: 24, width: 24, 
        decoration: BoxDecoration(
          color: AppColors.background,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.accent, width: 1.5),
        ),
        child: Icon(widget.item.transportType.icon, size: 12, color: AppColors.accent),
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 移動バー
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  // 1. 情報エリア (Wrapで折り返し対応)
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Move: ${widget.item.transportType.displayName}',
                          style: AppTextStyles.label.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                        Text(
                          '(${widget.item.durationMinutes} min)',
                          style: AppTextStyles.label.copyWith(color: AppColors.textSecondary, fontSize: 10),
                        ),
                        if (widget.item.cost != null) ...[
                          Container(width: 1, height: 10, color: Colors.grey.shade300),
                          Icon(Icons.attach_money_rounded, size: 12, color: AppColors.textSecondary),
                          Text(
                            '${widget.item.cost!.toInt()}',
                            style: AppTextStyles.label.copyWith(color: AppColors.textSecondary, fontSize: 10),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // 2. 操作エリア (固定幅)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 16, color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),

                      // Google Maps ボタン
                      if (hasCoords) ...[
                        _buildUnifiedIconButton(
                          onTap: () {
                             String url = widget.item.externalLink ?? '';
                             if (url.isEmpty) {
                               final start = '${widget.item.startLatitude},${widget.item.startLongitude}';
                               final end = '${widget.item.endLatitude},${widget.item.endLongitude}';
                               
                               // モード判定 (簡易版)
                               String mode = 'transit'; // デフォルトは公共交通
                               if (widget.item.transportType == TransportType.walk) mode = 'walking';
                               if (widget.item.transportType == TransportType.car) mode = 'driving';
                               if (widget.item.transportType == TransportType.bicycle) mode = 'bicycling';
                               
                               // Universal Link (アプリ/ブラウザ両対応)
                               url = 'https://www.google.com/maps/dir/?api=1&origin=$start&destination=$end&travelmode=$mode';
                               // 注: 実際の実装ではRoutingServiceに緯度経度を渡して生成するのが一般的ですが
                               // 既存コードのロジックに従い簡易化しています
                             }
                             RoutingService().openExternalMaps(url);
                          },
                          child: Image.asset(
                            'assets/images/google_maps.png', 
                            fit: BoxFit.contain, // アイコン内に収める
                          ),
                        ),
                        const SizedBox(width: 8), 
                      ],

                      // 編集ボタン
                      if(!widget.isReadOnly) _buildUnifiedIconButton(
                        onTap: widget.onEdit ?? () {},
                        child: const Icon(Icons.edit_rounded, size: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 詳細
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _isExpanded
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 24, left: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: widget.item.detailedSteps.map((step) => _buildStepRow(step)).toList(),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow(StepDetail step) {
    // 既存の実装をそのまま維持
    final stepTime = step.departureTime != null ? DateFormat('HH:mm').format(step.departureTime!) : '';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Icon(
                  step.transportType.icon,
                  size: 18,
                  color: Colors.grey,
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.grey.shade200,
                    margin: const EdgeInsets.only(top: 2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (stepTime.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 6, top: 3),
                      child: Text(
                        stepTime,
                        style: AppTextStyles.label.copyWith(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.displayInstruction,
                          style: AppTextStyles.bodyMedium.copyWith(fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (step.lineName != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Text(
                              step.lineName!,
                              style: AppTextStyles.label.copyWith(
                                fontSize: 10,
                                color: AppColors.accent, 
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      '${step.durationMinutes}min',
                      style: AppTextStyles.label.copyWith(fontSize: 9, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}