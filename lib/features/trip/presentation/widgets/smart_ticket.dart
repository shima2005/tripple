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
import 'package:new_tripple/models/step_detail.dart';
import 'dart:math' as math;

enum TicketMode { summary, stay, move }

class SmartTicket extends StatelessWidget {
  final Trip trip;
  final VoidCallback? onTap;
  final TicketMode? mode;

  // Summary / Move 用
  final String? fromLocation; 
  final String? fromCountryCode;
  final String? toLocation;
  final String? toCountryCode;

  // Stay / Move 用
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
    final ticketData = _buildTicketData(currentMode);

    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          // 外側の余白も少し詰める
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: PhysicalShape(
            clipper: TicketClipper(holeRadius: 8, holePositionRatio: 0.65), // 切り欠きも少し小さく
            color: Colors.white,
            elevation: 6, // 影を少し控えめに
            shadowColor: Colors.black.withOpacity(0.25),
            child: SizedBox(
              // 幅いっぱいまで広げるが、高さは中身なり
              width: double.infinity,
              child: Stack(
                children: [
                  // 背景の透かしアイコン
                  Positioned(
                    right: -20,
                    bottom: -25,
                    child: Transform.rotate(
                      angle: -0.2,
                      child: Icon(
                        ticketData.bgIcon,
                        size: 140, // 180 -> 140 に縮小
                        color: themeColor.withOpacity(0.04),
                      ),
                    ),
                  ),

                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // --- 1. Header Band (高さ縮小) ---
                      Container(
                        width: double.infinity,
                        height: 34, // 48 -> 34 に大幅縮小
                        color: themeColor,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Icon(Icons.airplane_ticket, color: Colors.white, size: 12), // 16 -> 12
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  ticketData.headerTitle,
                                  style: AppTextStyles.h3.copyWith(
                                    color: Colors.white,
                                    fontSize: 11, // 14 -> 11
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'TRIPPLE PASS',
                              style: AppTextStyles.label.copyWith(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 9, // 10 -> 9
                                fontWeight: FontWeight.w900,
                                fontStyle: FontStyle.italic,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // --- 2. Main Body (パディング縮小) ---
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 10), // 上下左右を圧縮
                        child: _buildMainBody(ticketData, themeColor),
                      ),

                      // --- 3. Perforation Area (高さ圧縮) ---
                      SizedBox(
                        height: 16, // 24 -> 16
                        child: Center(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Flex(
                                direction: Axis.horizontal,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: List.generate(
                                  (constraints.constrainWidth() / 8).floor(),
                                  (index) => SizedBox(
                                    width: 3, height: 1,
                                    child: DecoratedBox(decoration: BoxDecoration(color: Colors.grey[300])),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // --- 4. Footer & Barcode (パディング圧縮) ---
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 14), // 上下左右を圧縮
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // 左側: 情報カラム
                            Expanded(
                              flex: 3, // 少し領域を広げる
                              child: _buildFooter(ticketData, themeColor),
                            ),
                            // バーコード
                            const SizedBox(width: 12),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                const BarcodeWidget(height: 28, width: 70), // サイズダウン
                                const SizedBox(height: 2),
                                Text(
                                  '*9823-PASS*', 
                                  style: TextStyle(fontSize: 7, color: Colors.grey, fontFamily: 'Courier'),
                                )
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // --- 5. Progress Bar ---
                      if (ticketData.showProgress)
                        _buildBottomProgressBar(ticketData, themeColor),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Layout Widgets ---

  Widget _buildMainBody(_TicketData data, Color color) {
    return Column(
      children: [
        if (data.mainRightText == null && data.mainRightWidget == null)
          // Stay Mode (Left Align)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: data.mainLeftWidget ?? _buildBigText(data.mainLeftText, align: CrossAxisAlignment.start),
                  ),
                ],
              ),
              const SizedBox(height: 6), // 12 -> 6
              _buildSubInfoRow(data),
            ],
          )
        else
          // Move / Summary Mode (3 Columns)
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left
                  Expanded(
                    flex: 3,
                    child: data.mainLeftWidget ?? _buildBigText(data.mainLeftText, align: CrossAxisAlignment.start),
                  ),
                  
                  // Center
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        Icon(data.centerIcon ?? Icons.arrow_forward, color: color, size: 22), // 26 -> 22
                        if (data.centerText != null && data.centerText!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              data.centerText!,
                              style: AppTextStyles.label.copyWith(
                                fontSize: 8, // 9 -> 8
                                color: color,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                  
                  // Right
                  Expanded(
                    flex: 3,
                    child: data.mainRightWidget ?? _buildBigText(data.mainRightText, align: CrossAxisAlignment.end),
                  ),
                ],
              ),
              const SizedBox(height: 10), // 16 -> 10
              _buildSubInfoRow(data),
            ],
          ),
      ],
    );
  }

  Widget _buildSubInfoRow(_TicketData data) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.schedule_rounded, size: 12, color: AppColors.textSecondary), // 14 -> 12
            const SizedBox(width: 4),
            Text(
              data.subInfoText ?? '',
              style: AppTextStyles.label.copyWith(
                color: AppColors.textSecondary, 
                fontSize: 10, // 12 -> 10
                fontWeight: FontWeight.w500
              ),
            ),
          ],
        ),
        if (data.statusChipText != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              data.statusChipText!.toUpperCase(),
              style: AppTextStyles.label.copyWith(fontSize: 8, color: Colors.grey[600], fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }

  Widget _buildFooter(_TicketData data, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildFooterColumn(data.footerLeftLabel, data.footerLeft, color),
        _buildFooterColumn(data.footerCenterLabel, data.footerCenter, color),
        _buildFooterColumn(data.footerRightLabel, data.footerRight, color),
      ],
    );
  }

  Widget _buildFooterColumn(String label, String value, Color color) {
    final isEmpty = value == '--';
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label, 
            style: AppTextStyles.label.copyWith(
              fontSize: 7, // 8 -> 7
              color: Colors.grey[500],
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5
            ),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTextStyles.h3.copyWith(
              fontSize: 13, // 15 -> 13
              color: isEmpty ? Colors.grey[300] : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBigText(String? text, {required CrossAxisAlignment align}) {
    if (text == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          text,
          style: AppTextStyles.h3.copyWith(
            fontSize: 24, // 28 -> 24
            height: 1.0,
            letterSpacing: -0.5,
            fontWeight: FontWeight.w800,
          ),
          maxLines: 1, 
          overflow: TextOverflow.ellipsis,
          textAlign: align == CrossAxisAlignment.end ? TextAlign.end : TextAlign.start,
        ),
      ],
    );
  }

  Widget _buildBottomProgressBar(_TicketData data, Color color) {
    if (data.startTime == null || data.endTime == null) return const SizedBox.shrink();

    double progressValue = 0.0;
    final now = DateTime.now();
    final totalSeconds = data.endTime!.difference(data.startTime!).inSeconds;
    final elapsedSeconds = now.difference(data.startTime!).inSeconds;

    if (totalSeconds > 0) {
      progressValue = (elapsedSeconds / totalSeconds).clamp(0.0, 1.0);
    } else if (elapsedSeconds >= 0) {
      progressValue = 1.0;
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: LinearProgressIndicator(
        value: progressValue,
        backgroundColor: color.withOpacity(0.1),
        valueColor: AlwaysStoppedAnimation<Color>(color),
        minHeight: 4, // 6 -> 4
      ),
    );
  }

  // --- Data Logic (変更なし) ---
  _TicketData _buildTicketData(TicketMode currentMode) {
    switch (currentMode) {
      case TicketMode.stay: return _buildStayData();
      case TicketMode.move: return _buildMoveData();
      default: return _buildSummaryData();
    }
  }

  _TicketData _buildSummaryData() {
    final from = fromLocation ?? 'Home';
    final to = toLocation ?? trip.title;
    final fromCode = _toCode(from, countryCode: fromCountryCode);
    final toCode = _toCode(to, countryCode: toCountryCode);
    final days = trip.endDate.difference(trip.startDate).inDays + 1;
    final dateRange = '${DateFormat('MMM dd').format(trip.startDate)} - ${DateFormat('MMM dd').format(trip.endDate)}';

    return _TicketData(
      headerTitle: 'BOARDING PASS',
      bgIcon: Icons.map_rounded,
      mainLeftText: fromCode,
      centerIcon: Icons.flight_takeoff_rounded,
      centerText: '$days Days',
      mainRightText: toCode,
      subInfoText: dateRange,
      statusChipText: 'Planned',
      footerLeftLabel: 'DURATION', footerLeft: '$days Days',
      footerCenterLabel: 'MEMBERS', footerCenter: 'Any',
      footerRightLabel: 'TOTAL', footerRight: '--',
    );
  }

  _TicketData _buildStayData() {
    final item = currentStay!;
    final category = item.category;

    String header = 'VOUCHER';
    if (category == ItemCategory.accommodation) header = 'HOTEL VOUCHER';
    else if (category == ItemCategory.food) header = 'DINING TICKET';
    else if (category == ItemCategory.sightseeing) header = 'ENTRY TICKET';
    else header = '${category.displayName.toUpperCase()} PASS';

    final startStr = DateFormat('HH:mm').format(item.time);
    final end = item.time.add(Duration(minutes: item.durationMinutes ?? 60));
    final endStr = DateFormat('HH:mm').format(end);

    return _TicketData(
      headerTitle: header,
      bgIcon: category.icon,
      mainLeftWidget: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6), // 8 -> 6
            decoration: BoxDecoration(
              color: AppColors.third.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(category.icon, size: 24, color: AppColors.third), // 28 -> 24
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.name,
              style: AppTextStyles.h3.copyWith(fontSize: 18, height: 1.1), // 22 -> 18
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      mainRightText: null,
      subInfoText: '$startStr - $endStr',
      statusChipText: 'Confirmed',
      footerLeftLabel: 'COST', footerLeft: _formatCost(item.cost),
      footerCenterLabel: 'NOTES', footerCenter: (item.notes?.isNotEmpty ?? false) ? 'Ref Check' : '--',
      footerRightLabel: 'STATUS', footerRight: 'On Stay',
      showProgress: true, startTime: item.time, endTime: end,
    );
  }

  _TicketData _buildMoveData() {
    final item = currentMove!;
    final destination = nextDestinationName ?? 'Dest';
    final transport = item.transportType;
    
    String header = 'TICKET';
    switch (transport) {
      case TransportType.plane: header = 'BOARDING PASS'; break;
      case TransportType.train: header = 'TRAIN TICKET'; break;
      case TransportType.bus: header = 'BUS TICKET'; break;
      case TransportType.waiting: header = 'TRANSIT WAIT'; break;
      default: header = 'TRANSIT TICKET';
    }

    // ★ 修正: Active Step とその正確な開始・終了時刻を計算
    StepDetail? activeStep;
    DateTime stepStartTime = item.time; // デフォルトは全体の開始
    DateTime stepEndTime = item.time.add(Duration(minutes: item.durationMinutes)); // デフォルトは全体の終了

    final now = DateTime.now();

    if (item.detailedSteps.isNotEmpty) {
      DateTime cursorTime = item.time;
      bool found = false;
      
      for (final step in item.detailedSteps) {
        final endCursor = cursorTime.add(Duration(minutes: step.durationMinutes));
        
        // 現在時刻がこのステップの終了前なら、これがActive
        if (now.isBefore(endCursor)) {
          activeStep = step;
          stepStartTime = cursorTime;
          stepEndTime = endCursor;
          found = true;
          break;
        }
        cursorTime = endCursor;
      }
      
      // 全て終わっている場合は最後のステップを表示
      if (!found) {
        activeStep = item.detailedSteps.last;
        stepStartTime = cursorTime.subtract(Duration(minutes: activeStep.durationMinutes));
        stepEndTime = cursorTime;
      }
    }

    // 表示用時刻文字列 (HH:mm - HH:mm)
    final timeRangeStr = '${DateFormat('HH:mm').format(stepStartTime)} - ${DateFormat('HH:mm').format(stepEndTime)}';
    
    // --- Pattern 3: Instruction / Wait ---
    if (activeStep != null && (activeStep.transportType == TransportType.waiting || 
       (activeStep.departureStation == null && activeStep.customInstruction != null))) {
       
       return _TicketData(
          headerTitle: header,
          bgIcon: activeStep.transportType.icon,
          mainLeftWidget: Row(
            children: [
              Icon(activeStep.transportType.icon, size: 28, color: AppColors.textPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  activeStep.customInstruction ?? activeStep.transportType.displayName,
                  style: AppTextStyles.h3.copyWith(fontSize: 18),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          mainRightText: null,
          // ★ 修正: duration ("15 min") ではなく、計算した時間範囲を表示
          subInfoText: timeRangeStr,
          statusChipText: 'Active',
          footerLeftLabel: 'FOR', footerLeft: destination.toUpperCase(),
          footerCenterLabel: 'INFO', footerCenter: '--',
          footerRightLabel: 'COST', footerRight: _formatCost(item.cost),
          showProgress: true, startTime: stepStartTime, endTime: stepEndTime,
        );
    }

    // --- Pattern 1 & 2 ---
    String leftText, rightText;
    IconData centerIcon;
    String centerText;
    String seatInfo = '--';

    if (activeStep != null) {
      // Step詳細あり
      leftText = activeStep.departureStation ?? 'Start';
      rightText = activeStep.arrivalStation ?? 'End';
      centerIcon = activeStep.transportType.icon;
      centerText = activeStep.lineName ?? activeStep.transportType.displayName;
      seatInfo = activeStep.bookingDetails ?? '--';
    } else {
      // Stepなし (全体表示)
      leftText = fromLocation ?? 'Start';
      rightText = toLocation ?? 'End';
      centerIcon = transport.icon;
      centerText = transport.displayName;
    }

    return _TicketData(
      headerTitle: header,
      bgIcon: centerIcon,
      mainLeftText: leftText,
      centerIcon: centerIcon,
      centerText: centerText,
      mainRightText: rightText,
      // ★ 修正: 計算した時間範囲を表示 (Stepがある場合はStepの時間、ない場合は全体の時間)
      subInfoText: timeRangeStr,
      statusChipText: transport.displayName,
      footerLeftLabel: 'FOR', footerLeft: destination.toUpperCase(),
      footerCenterLabel: 'SEAT', footerCenter: seatInfo,
      footerRightLabel: 'COST', footerRight: _formatCost(item.cost),
      showProgress: true, startTime: stepStartTime, endTime: stepEndTime,
    );
  }

  // --- Helpers ---
  Color _getModeColor(TicketMode targetMode) {
    switch (targetMode) {
      case TicketMode.stay: return AppColors.third;
      case TicketMode.move: return AppColors.accent;
      default: return AppColors.primary;
    }
  }

  String _toCode(String name, {String? countryCode}) {
    if (name.isEmpty) return '???';
    final lowerName = name.toLowerCase();
    if (cityCodes.containsKey(lowerName)) return cityCodes[lowerName]!;
    for (final key in cityCodes.keys) {
      if (lowerName.contains(key)) return cityCodes[key]!;
    }
    if (countryCode != null && countryCode.isNotEmpty) {
      return (CountryConverter.toAlpha3(countryCode) ?? countryCode).toUpperCase();
    }
    final sanitized = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (sanitized.length >= 3) return sanitized.substring(0, 3).toUpperCase();
    return 'DST';
  }
  
  String _formatCost(double? cost) {
    if (cost == null) return '--';
    final format = NumberFormat("#,###");
    return '¥${format.format(cost)}';
  }
}

// --- Custom Clipper (調整済み) ---
class TicketClipper extends CustomClipper<Path> {
  final double holeRadius;
  final double holePositionRatio;

  TicketClipper({this.holeRadius = 8, this.holePositionRatio = 0.65});

  @override
  Path getClip(Size size) {
    final path = Path();
    final holeY = size.height * holePositionRatio;

    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, holeY - holeRadius);
    
    path.arcToPoint(
      Offset(size.width, holeY + holeRadius),
      radius: Radius.circular(holeRadius),
      clockwise: false,
    );
    
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.lineTo(0, holeY + holeRadius);

    path.arcToPoint(
      Offset(0, holeY - holeRadius),
      radius: Radius.circular(holeRadius),
      clockwise: false,
    );

    path.close();
    return path;
  }

  @override
  bool shouldReclip(TicketClipper oldClipper) => true;
}

// --- Barcode Widget (CustomPainter版: クッキリ描画) ---
class BarcodeWidget extends StatelessWidget {
  final double height;
  final double width;

  const BarcodeWidget({super.key, required this.height, required this.width});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _BarcodePainter(),
    );
  }
}

class _BarcodePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[800]!
      ..strokeWidth = 1.0;

    final random = math.Random(42); // シード固定で毎回同じ模様にする
    double currentX = 0;

    while (currentX < size.width) {
      // 線の太さをランダムに (1.0 〜 3.0)
      final strokeWidth = random.nextDouble() * 4.0 + 1.0;
      paint.strokeWidth = strokeWidth;

      // 描画するかスキップするか (密度調整: 60%の確率で描画)
      if (random.nextDouble() > 0.1) {
        canvas.drawLine(
          Offset(currentX, 0),
          Offset(currentX, size.height),
          paint,
        );
      }

      // 次の線までの間隔 (1.5 〜 4.0)
      currentX += strokeWidth + random.nextDouble() * 2.5 + 1.5;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TicketData {
  final String headerTitle;
  final IconData bgIcon;
  final String? mainLeftText;
  final Widget? mainLeftWidget;
  final IconData? centerIcon;
  final String? centerText;
  final String? mainRightText;
  final Widget? mainRightWidget;
  final String? subInfoText;
  final String? statusChipText;
  final String footerLeftLabel;
  final String footerLeft;
  final String footerCenterLabel;
  final String footerCenter;
  final String footerRightLabel;
  final String footerRight;
  final bool showProgress;
  final DateTime? startTime;
  final DateTime? endTime;

  _TicketData({
    required this.headerTitle,
    required this.bgIcon,
    this.mainLeftText,
    this.mainLeftWidget,
    this.centerIcon,
    this.centerText,
    this.mainRightText,
    this.mainRightWidget,
    this.subInfoText,
    this.statusChipText,
    required this.footerLeftLabel,
    required this.footerLeft,
    required this.footerCenterLabel,
    required this.footerCenter,
    required this.footerRightLabel,
    required this.footerRight,
    this.showProgress = false,
    this.startTime,
    this.endTime,
  });
}