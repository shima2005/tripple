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
  
  // 親から受け取る出発地と目的地
  final String? fromLocation;
  final String? fromCountryCode;
  final String? toLocation;
  final String? toCountryCode;

  const SmartTicket({
    super.key,
    required this.trip,
    this.onTap,
    this.mode = TicketMode.summary,
    this.fromLocation,
    this.fromCountryCode,
    this.toLocation,
    this.toCountryCode,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = _getModeColor();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        // 横幅のマージン。ここを広げるとチケット自体の横幅が狭くなりますが、
        // 一般的には縦長感を消すならマージンはいじらず(あるいは狭め)、中身の高さを減らすのが正解です。
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.15), // 影を少し調整
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // 0. 背景の透かしアイコン (サイズと位置を調整して圧迫感を減らす)
              Positioned(
                right: -15,
                bottom: -15,
                child: Icon(
                  _getModeIcon(),
                  size: 110, // 140 -> 110
                  color: themeColor.withValues(alpha: 0.04),
                ),
              ),

              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. カラーストリップ (スリム化)
                  Container(
                    height: 10, // 16 -> 10
                    width: double.infinity,
                    color: themeColor,
                  ),

                  // 2. メインコンテンツ (パディングを詰める)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 10), // 上下を少し削減
                    child: _buildMainContent(themeColor),
                  ),

                  // 3. ミシン目
                  _buildDivider(),

                  // 4. サブコンテンツ (パディングを詰める)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 14), // 上下を削減
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
    final from = fromLocation ?? 'Home'; 
    final to = toLocation ?? trip.title;

    // ロジックはそのまま維持
    String toCode(String name, {String? countryCode}) {
      if (name.isEmpty) return '???';
      final lowerName = name.toLowerCase();

      if (cityCodes.containsKey(lowerName)) {
        return cityCodes[lowerName]!;
      }
      for (final key in cityCodes.keys) {
        if (lowerName.contains(key)) {
          return cityCodes[key]!;
        }
      }

      if (countryCode != null && countryCode.isNotEmpty) {
        final alpha3 = CountryConverter.toAlpha3(countryCode);
        return (alpha3 ?? countryCode).toUpperCase(); 
      }

      final sanitized = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ''); 
      if (sanitized.length >= 3) {
        return sanitized.substring(0, 3).toUpperCase();
      }
      return 'DST'; 
    }

    final fromCodeStr = toCode(from, countryCode: fromCountryCode);
    final toCodeStr = toCode(to, countryCode: toCountryCode);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: _buildCode(fromCodeStr, from, CrossAxisAlignment.start)), // 左
        
        // 中央: アイコンと日数
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              Icon(Icons.flight_takeoff_rounded, color: color, size: 24), // 28 -> 24
              const SizedBox(height: 2),
              Text(
                '${trip.endDate.difference(trip.startDate).inDays + 1} Days', 
                style: AppTextStyles.label.copyWith(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)
              ),
            ],
          ),
        ),
        
        Expanded(child: _buildCode(toCodeStr, to, CrossAxisAlignment.end)), // 右
      ],
    );
  }

  Widget _buildStayMain(Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8), // 10 -> 8
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.hotel_rounded, color: color, size: 22), // 24 -> 22
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CHECKING IN',
                style: AppTextStyles.label.copyWith(
                  color: color, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.0
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'Destination Hotel', // データ連携時はここを修正
                style: AppTextStyles.h3.copyWith(fontSize: 16), // 18 -> 16
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
          padding: const EdgeInsets.all(8), // 10 -> 8
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.directions_train_rounded, color: color, size: 22), // 24 -> 22
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MOVING',
                style: AppTextStyles.label.copyWith(
                  color: color, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.0
                ),
              ),
              const SizedBox(height: 1),
              Row(
                children: [
                  Flexible(child: Text('Kyoto', style: AppTextStyles.h3.copyWith(fontSize: 15), overflow: TextOverflow.ellipsis)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.grey),
                  ),
                  Flexible(child: Text('Gion', style: AppTextStyles.h3.copyWith(fontSize: 15), overflow: TextOverflow.ellipsis)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- サブコンテンツ ---
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
    // 縦長解消のため、ラベルと値の隙間などを詰める
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildLabelValue('DATE', DateFormat('MM/dd').format(trip.startDate)),
        _buildLabelValue('GATE', 'E4'),
        _buildLabelValue('SEAT', '12A'),
        
        Padding(
          padding: const EdgeInsets.only(bottom: 1), // 2 -> 1
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
            Text('10:00', style: AppTextStyles.label.copyWith(fontSize: 11)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                mode == TicketMode.stay ? 'On Stay' : 'On Time',
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
            Text('12:00', style: AppTextStyles.label.copyWith(fontSize: 11)),
          ],
        ),
        const SizedBox(height: 6), // 8 -> 6
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

  // 配置(Alignment)を指定できるように変更
  Widget _buildCode(String code, String city, CrossAxisAlignment align) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          code, 
          style: AppTextStyles.ticketCode.copyWith(
            fontSize: 24, // 28 -> 24: 少し小さくして圧迫感を減らす
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            height: 1.0,
          )
        ),
        const SizedBox(height: 2),
        Text(
          city.length > 12 ? '${city.substring(0, 12)}...' : city,
          style: AppTextStyles.label.copyWith(fontSize: 10, color: Colors.grey[700]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ), 
      ],
    );
  }

  Widget _buildLabelValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label.copyWith(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 1),
        Text(value, style: AppTextStyles.h3.copyWith(fontSize: 13)), // 14 -> 13
      ],
    );
  }
  
  Widget _buildDivider() {
    return SizedBox(
      height: 14, // 16 -> 14
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
          Positioned(left: -7, top: 0, bottom: 0, child: _buildNotch()), // 調整
          Positioned(right: -7, top: 0, bottom: 0, child: _buildNotch()),
        ],
      ),
    );
  }

  Widget _buildNotch() {
    return Container(
      width: 14, // 16 -> 14
      decoration: BoxDecoration(
        color: AppColors.background, // 背景色と同じにする必要があります
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildBarcode() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(12, (index) {
        final width = (index % 4 == 0) ? 3.0 : (index % 3 == 0 ? 1.0 : 2.0);
        return Container(
          margin: const EdgeInsets.only(right: 2),
          width: width,
          height: 24, // 28 -> 24
          color: AppColors.textPrimary.withValues(alpha: 0.2),
        );
      }),
    );
  }
}