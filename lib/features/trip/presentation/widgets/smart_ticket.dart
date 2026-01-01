import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';
import 'package:new_tripple/core/utils/country_converter.dart';
import 'package:new_tripple/models/trip.dart';
import 'package:new_tripple/core/constants/city_codes.dart';
import 'package:new_tripple/models/schedule_item.dart';
import 'package:new_tripple/models/route_item.dart';
import 'package:new_tripple/models/enums.dart';
import 'package:new_tripple/models/step_detail.dart'; // 👈 StepDetailを使うので確認

enum TicketMode { summary, stay, move }

class SmartTicket extends StatelessWidget {
  final Trip trip;
  final VoidCallback? onTap;
  
  final TicketMode? mode; 
  
  final String? fromLocation;
  final String? fromCountryCode;
  final String? toLocation;
  final String? toCountryCode;

  final ScheduledItem? currentStay;
  final RouteItem? currentMove;
  final String? nextDestinationName;

  const SmartTicket({
    super.key,
    required this.trip,
    this.onTap,
    this.mode,
    this.fromLocation,
    this.fromCountryCode,
    this.toLocation,
    this.toCountryCode,
    this.currentStay,
    this.currentMove,
    this.nextDestinationName,
  });

  TicketMode get _currentMode {
    if (mode != null) return mode!;
    if (currentStay != null) return TicketMode.stay;
    if (currentMove != null) return TicketMode.move;
    return TicketMode.summary;
  }

  @override
  Widget build(BuildContext context) {
    final currentMode = _currentMode;
    final themeColor = _getModeColor(currentMode);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
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
              Positioned(
                right: -20,
                bottom: -20,
                child: Icon(
                  _getModeIcon(currentMode),
                  size: 140,
                  color: themeColor.withValues(alpha: 0.05),
                ),
              ),

              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 16, 
                    width: double.infinity,
                    color: themeColor,
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _buildMainContent(currentMode, themeColor),
                    ),
                  ),

                  _buildDivider(),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: _buildSubContent(currentMode, themeColor),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getModeColor(TicketMode targetMode) {
    switch (targetMode) {
      case TicketMode.stay: return AppColors.third;
      case TicketMode.move: return AppColors.accent;
      default: return AppColors.primary;
    }
  }

  IconData _getModeIcon(TicketMode targetMode) {
    switch (targetMode) {
      case TicketMode.stay: return Icons.hotel_rounded;
      case TicketMode.move: return Icons.directions_transit_rounded;
      default: return Icons.flight_takeoff_rounded;
    }
  }

  Widget _buildMainContent(TicketMode targetMode, Color color) {
    switch (targetMode) {
      case TicketMode.stay:
        return KeyedSubtree(key: const ValueKey('stay'), child: _buildStayMain(color));
      case TicketMode.move:
        return KeyedSubtree(key: const ValueKey('move'), child: _buildMoveMain(color));
      case TicketMode.summary:
      default:
        return KeyedSubtree(key: const ValueKey('summary'), child: _buildSummaryMain(color));
    }
  }

  // ... ( _buildSummaryMain は変更なしのため省略。前のコードを維持してください ) ...
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
    final toCodeStr = toCode(to, countryCode: toCountryCode);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildCode(fromCodeStr, from), 
        Column(
          children: [
            Icon(Icons.flight_takeoff_rounded, color: color, size: 28),
            Text(
              '${trip.endDate.difference(trip.startDate).inDays + 1} Days', 
              style: AppTextStyles.label.copyWith(fontSize: 10, color: AppColors.textSecondary)
            ),
          ],
        ),
        _buildCode(toCodeStr, to), 
      ],
    );
  }


  // ... ( _buildStayMain は変更なし ) ...
  Widget _buildStayMain(Color color) {
    final item = currentStay!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(item.category.icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CURRENT STAY',
                style: AppTextStyles.label.copyWith(
                  color: color, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.2
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.name, 
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
    final item = currentMove!;
    final destination = nextDestinationName ?? 'Destination'; // RouteItemとしての最終目的地

    // 1. 今どのステップにいるか判定 (前回と同じロジック)
    StepDetail? activeStep;
    
    // 現在時刻と経過時間
    final now = DateTime.now();
    final elapsedMinutes = now.difference(item.time).inMinutes;

    if (item.detailedSteps.isNotEmpty && elapsedMinutes >= 0) {
      int cumulative = 0;
      for (final step in item.detailedSteps) {
        cumulative += step.durationMinutes;
        if (elapsedMinutes < cumulative) {
          activeStep = step;
          break;
        }
      }
      activeStep ??= item.detailedSteps.last;
    }

    // 表示する変数
    IconData icon;
    String labelText; // 上の小さい文字 (全体の文脈)
    String mainText;  // 真ん中の大きい文字 (今の乗り物)
    String subText;   // 下の文字 (区間など)
    String? seatInfo; // 座席情報など

    if (activeStep != null) {
      // --- A. StepDetailがある場合 (詳細モード) ---
      icon = activeStep.transportType.icon;
      
      // Label: 全体の目的地を表示して「RouteItemの全貌」を示す
      labelText = 'BOUND FOR ${destination.toUpperCase()}';

      // Main: 路線名があればそれを、なければ手段名
      if (activeStep.lineName != null && activeStep.lineName!.isNotEmpty) {
        mainText = activeStep.lineName!;
      } else {
        mainText = activeStep.transportType.displayName;
      }

      // Sub: 区間情報
      if (activeStep.departureStation != null && activeStep.arrivalStation != null) {
        subText = '${activeStep.departureStation} ➔ ${activeStep.arrivalStation}';
      } else {
        subText = activeStep.displayInstruction;
      }

      // Seat: 座席情報などがあれば取得
      seatInfo = activeStep.bookingDetails; // "Seat 12A" とか "Car 5" とか

    } else {
      // --- B. StepDetailがない場合 (既存のフォールバック) ---
      icon = item.transportType.icon;
      
      labelText = 'MOVING (${item.transportType.displayName.toUpperCase()})';
      mainText = 'To $destination';
      subText = 'On the way'; // あるいはCostとか、空文字でもOK
      seatInfo = null;
    }

    return Row(
      children: [
        // アイコン部分
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        
        // テキスト情報部分
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. ラベル (全体の文脈)
              Text(
                labelText,
                style: AppTextStyles.label.copyWith(
                  color: color, 
                  fontWeight: FontWeight.bold, 
                  fontSize: 9, 
                  letterSpacing: 1.0
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              
              // 2. メイン (今の乗り物 / 目的地)
              Text(
                mainText,
                style: AppTextStyles.h3.copyWith(fontSize: 18),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              
              // 3. サブ情報 (区間 + 座席)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subText,
                      style: AppTextStyles.label,
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 座席情報があればバッジっぽく表示
                  if (seatInfo != null && seatInfo.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.textSecondary.withOpacity(0.2)),
                      ),
                      child: Text(
                        seatInfo,
                        style: AppTextStyles.label.copyWith(
                          fontSize: 10, 
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ),
                  ]
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubContent(TicketMode targetMode, Color color) {
    switch (targetMode) {
      case TicketMode.stay:
      case TicketMode.move:
        return _buildProgress(color, targetMode);
      case TicketMode.summary:
      default:
        return _buildSummarySub();
    }
  }

  // ... ( _buildSummarySub は変更なし ) ...
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

  // 👇 ★ここを改修: Progress Barを動くように変更
  Widget _buildProgress(Color color, TicketMode targetMode) {
    DateTime? start;
    DateTime? end;
    
    if (targetMode == TicketMode.stay && currentStay != null) {
      start = currentStay!.time;
      final duration = currentStay!.durationMinutes ?? 60;
      end = start.add(Duration(minutes: duration));
    } else if (targetMode == TicketMode.move && currentMove != null) {
      start = currentMove!.time;
      final duration = currentMove!.durationMinutes;
      end = start.add(Duration(minutes: duration));
    }

    final startStr = start != null ? DateFormat('HH:mm').format(start) : '--:--';
    final endStr = end != null ? DateFormat('HH:mm').format(end) : '--:--';

    // プログレス計算
    double progressValue = 0.0;
    if (start != null && end != null) {
      final now = DateTime.now();
      final totalSeconds = end.difference(start).inSeconds;
      final elapsedSeconds = now.difference(start).inSeconds;

      if (totalSeconds > 0) {
        progressValue = (elapsedSeconds / totalSeconds).clamp(0.0, 1.0);
      } else if (elapsedSeconds >= 0) {
        progressValue = 1.0; // 期間0で過ぎていれば100%
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(startStr, style: AppTextStyles.label.copyWith(fontSize: 12)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                targetMode == TicketMode.stay ? 'On Stay' : 'On Move',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            Text(endStr, style: AppTextStyles.label.copyWith(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progressValue, // 👈 計算した値をセット
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  // ... ( _buildCode, _buildLabelValue, _buildDivider, _buildNotch, _buildBarcode, ヘルパーメソッドは変更なし ) ...
  // (これらは元のコードをそのまま維持してください)
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