import 'enums.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StepDetail {
  final String? customInstruction;
  final int durationMinutes;
  final TransportType transportType;
  
  final String? lineName;
  final String? departureStation;
  final String? arrivalStation;
  final DateTime? departureTime;
  final DateTime? arrivalTime;
  final String? bookingDetails;
  final double? cost;

  const StepDetail({
    this.customInstruction,
    required this.durationMinutes,
    required this.transportType,
    this.lineName,
    this.departureStation,
    this.arrivalStation,
    this.departureTime,
    this.arrivalTime,
    this.bookingDetails,
    this.cost,
  });

  // ✨ 自動生成ロジック (路線名はここでは含めない！)
  String get displayInstruction {
    if (customInstruction != null && customInstruction!.isNotEmpty) {
      return customInstruction!;
    }

    switch (transportType) {
      case TransportType.walk:
        if (arrivalStation != null) return '$arrivalStationまで徒歩';
        return '徒歩で移動';
        
      case TransportType.train:
      case TransportType.subway:
      case TransportType.shinkansen:
      case TransportType.bus:
      case TransportType.ferry:
        // 路線名はUI側でリッチに表示するので、ここでは結合しない
        if (departureStation != null && arrivalStation != null) {
          return '$departureStation → $arrivalStation';
        }
        if (arrivalStation != null) return '$arrivalStationまで乗車';
        return '${transportType.displayName}で移動';

      case TransportType.car:
      case TransportType.taxi:
        if (arrivalStation != null) return '$arrivalStationまで${transportType.displayName}';
        return '${transportType.displayName}で移動';

      case TransportType.plane:
        if (departureStation != null && arrivalStation != null) {
          return '$departureStation ✈ $arrivalStation';
        }
        return 'フライト';

      case TransportType.waiting:
        if (departureStation !=null){
          return '{$departureStation}で待機';
        }
        return "待機";



      default:
        return '移動';
    }
  }

  factory StepDetail.fromMap(Map<String, dynamic> map) {
    return StepDetail(
      customInstruction: map['instruction'] as String?,
      durationMinutes: map['durationMinutes'] as int,
      transportType: TransportType.values.firstWhere(
        (e) => e.name == map['transportType'], 
        orElse: () => TransportType.other
      ),
      lineName: map['lineName'] as String?,
      departureStation: map['departureStation'] as String?,
      arrivalStation: map['arrivalStation'] as String?,
      departureTime: (map['departureTime'] as Timestamp?)?.toDate(),
      arrivalTime: (map['arrivalTime'] as Timestamp?)?.toDate(),
      bookingDetails: map['bookingDetails'] as String?,
      cost: (map['cost'] as num?)?.toDouble(),
    );
  }

  // 👇 追加: Mapへの変換
  Map<String, dynamic> toMap() {
    return {
      'instruction': customInstruction,
      'durationMinutes': durationMinutes,
      'transportType': transportType.name,
      'lineName': lineName,
      'departureStation': departureStation,
      'arrivalStation': arrivalStation,
      'departureTime': departureTime != null ? Timestamp.fromDate(departureTime!) : null,
      'arrivalTime': arrivalTime != null ? Timestamp.fromDate(arrivalTime!) : null,
      'bookingDetails': bookingDetails,
      'cost': cost,
    };
  }
}