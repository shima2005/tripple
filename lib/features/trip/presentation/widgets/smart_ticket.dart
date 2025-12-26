import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';
import 'package:new_tripple/core/utils/country_converter.dart';
import 'package:new_tripple/models/trip.dart';
import 'package:new_tripple/core/constants/city_codes.dart';

enum TicketMode { summary, stay, move }

class SmartTicket extends StatelessWidget {
  final Trip trip;
  final VoidCallback? onTap;
  final TicketMode mode;
  
  // 👇 追加: 親から受け取る出発地と目的地
  final String? fromLocation;
  final String? fromCountryCode;
  final String? toLocation;
  final String? toCountryCode;

  const SmartTicket({
    super.key,
    required this.trip,
    this.onTap,
    this.mode = TicketMode.summary,
    this.fromLocation, // 👈 追加
    this.fromCountryCode,
    this.toLocation,   // 👈 追加
    this.toCountryCode,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = _getModeColor();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // 0. 背景の透かしアイコン
              Positioned(
                right: -20,
                bottom: -20,
                child: Icon(
                  _getModeIcon(),
                  size: 140,
                  color: themeColor.withValues(alpha: 0.05),
                ),
              ),

              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. カラーストリップ
                  Container(
                    height: 16, 
                    width: double.infinity,
                    color: themeColor,
                  ),

                  // 2. メインコンテンツ
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: _buildMainContent(themeColor),
                  ),

                  // 3. ミシン目
                  _buildDivider(),

                  // 4. サブコンテンツ
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: _buildSubContent(themeColor),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getModeColor() {
    switch (mode) {
      case TicketMode.stay: return AppColors.third;
      case TicketMode.move: return AppColors.accent;
      default: return AppColors.primary;
    }
  }

  IconData _getModeIcon() {
    switch (mode) {
      case TicketMode.stay: return Icons.hotel_rounded;
      case TicketMode.move: return Icons.directions_transit_rounded;
      default: return Icons.flight_takeoff_rounded;
    }
  }

  // --- メインコンテンツ ---
  Widget _buildMainContent(Color color) {
    switch (mode) {
      case TicketMode.stay:
        return _buildStayMain(color);
      case TicketMode.move:
        return _buildMoveMain(color);
      case TicketMode.summary:
      default:
        return _buildSummaryMain(color);
    }
  }

  Widget _buildSummaryMain(Color color) {
    // データがない場合のデフォルト値
    final from = fromLocation ?? 'Home'; 
    final to = toLocation ?? trip.title;

    String toCode(String name, {String? countryCode}) {
      if (name.isEmpty) return '???';
      
      final lowerName = name.toLowerCase();

      // 1. 都市コード辞書
      if (cityCodes.containsKey(lowerName)) {
        return cityCodes[lowerName]!;
      }
      for (final key in cityCodes.keys) {
        if (lowerName.contains(key)) {
          return cityCodes[key]!;
        }
      }

      // 2. 国コードフォールバック (Alpha-2 -> Alpha-3 変換！)
      if (countryCode != null && countryCode.isNotEmpty) {
        final alpha3 = CountryConverter.toAlpha3(countryCode);
        // 変換できれば3文字、できなければ元の2文字を表示
        return (alpha3 ?? countryCode).toUpperCase(); 
      }

      // 3. 先頭3文字
      final sanitized = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ''); 
      if (sanitized.length >= 3) {
        return sanitized.substring(0, 3).toUpperCase();
      }
      
      return 'DST'; 
    }

    final fromCodeStr = toCode(from, countryCode: fromCountryCode);
    // 👇 目的地の場合は countryCode も渡してあげる
    final toCodeStr = toCode(to, countryCode: toCountryCode);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildCode(fromCodeStr, from), // 左: 出発地
        
        // 中央: アイコン
        Column(
          children: [
            Icon(Icons.flight_takeoff_rounded, color: color, size: 28),
            // ここに「旅行日数」などを入れてもいいかも
            Text(
              '${trip.endDate.difference(trip.startDate).inDays + 1} Days', 
              style: AppTextStyles.label.copyWith(fontSize: 10, color: AppColors.textSecondary)
            ),
          ],
        ),
        
        _buildCode(toCodeStr, to), // 右: 目的地
      ],
    );
  }

  // ... ( _buildStayMain, _buildMoveMain は変更なし ) ...
  Widget _buildStayMain(Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.hotel_rounded, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CHECKING IN',
                style: AppTextStyles.label.copyWith(
                  color: color, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.2
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Kiyomizu-dera', // ※ここも本来はScheduledItemから取るべきですが今回はSummaryの改修なので据え置き
                style: AppTextStyles.h3.copyWith(fontSize: 18),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMoveMain(Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.directions_train_rounded, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MOVING',
                style: AppTextStyles.label.copyWith(
                  color: color, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.2
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text('Kyoto', style: AppTextStyles.h3.copyWith(fontSize: 16)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.grey),
                  ),
                  Text('Gion', style: AppTextStyles.h3.copyWith(fontSize: 16)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ... ( _buildSubContent, _buildSummarySub, _buildProgress, _buildDivider, _buildNotch, _buildBarcode は変更なし ) ...
  Widget _buildSubContent(Color color) {
    switch (mode) {
      case TicketMode.stay:
      case TicketMode.move:
        return _buildProgress(color);
      case TicketMode.summary:
      default:
        return _buildSummarySub();
    }
  }

  Widget _buildSummarySub() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildLabelValue('DATE', DateFormat('MM/dd').format(trip.startDate)),
        _buildLabelValue('GATE', 'E4'), // ダミー
        _buildLabelValue('SEAT', '12A'), // ダミー
        
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: _buildBarcode(),
        ),
      ],
    );
  }

  Widget _buildProgress(Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('10:00', style: AppTextStyles.label.copyWith(fontSize: 12)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                mode == TicketMode.stay ? 'On Stay' : 'On Time',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            Text('12:00', style: AppTextStyles.label.copyWith(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: 0.6,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  Widget _buildCode(String code, String city) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(code, style: AppTextStyles.ticketCode.copyWith(fontSize: 28)),
        Text(
          city.length > 10 ? '${city.substring(0, 10)}...' : city, // 長すぎる場合は省略
          style: AppTextStyles.label.copyWith(fontSize: 10)
        ), 
      ],
    );
  }

  Widget _buildLabelValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label.copyWith(fontSize: 9, color: Colors.grey)),
        Text(value, style: AppTextStyles.h3.copyWith(fontSize: 14)),
      ],
    );
  }
  
  // ... _buildDivider, _buildNotch, _buildBarcode
  Widget _buildDivider() {
    return SizedBox(
      height: 16,
      child: Stack(
        children: [
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Flex(
                  direction: Axis.horizontal,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    (constraints.constrainWidth() / 8).floor(),
                    (index) => SizedBox(
                      width: 4, height: 1,
                      child: DecoratedBox(decoration: BoxDecoration(color: Colors.grey[300])),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(left: -8, top: 0, bottom: 0, child: _buildNotch()),
          Positioned(right: -8, top: 0, bottom: 0, child: _buildNotch()),
        ],
      ),
    );
  }

  Widget _buildNotch() {
    return Container(
      width: 16,
      decoration: BoxDecoration(
        color: AppColors.background,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildBarcode() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(12, (index) {
        final width = (index % 4 == 0) ? 3.0 : (index % 3 == 0 ? 1.0 : 2.0);
        return Container(
          margin: const EdgeInsets.only(right: 2),
          width: width,
          height: 28,
          color: AppColors.textPrimary.withValues(alpha: 0.2),
        );
      }),
    );
  }
}