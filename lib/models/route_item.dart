import 'enums.dart';
import 'step_detail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RouteItem {
  final String id;
  final int dayIndex;
  final DateTime time;
  final String destinationItemId;
  final int durationMinutes;
  final TransportType transportType;
  final String? polyline;
  final double? cost;
  final List<StepDetail> detailedSteps;
  final double? startLatitude;
  final double? startLongitude;
  final double? endLatitude;
  final double? endLongitude;
  final String? externalLink;

  const RouteItem({
    required this.id,
    required this.dayIndex,
    required this.time,
    required this.destinationItemId,
    required this.durationMinutes,
    required this.transportType,
    this.polyline,
    this.cost,
    this.startLatitude,
    this.startLongitude,
    this.endLatitude,
    this.endLongitude,
    required this.detailedSteps,
    this.externalLink,
  });

  // 👇 copyWithを追加！
  RouteItem copyWith({
    String? id,
    int? dayIndex,
    DateTime? time,
    String? destinationItemId,
    int? durationMinutes,
    TransportType? transportType,
    String? polyline,
    double? cost,
    double? startLatitude,
    double? startLongitude,
    double? endLatitude,
    double? endLongitude,
    List<StepDetail>? detailedSteps,
  }) {
    return RouteItem(
      id: id ?? this.id,
      dayIndex: dayIndex ?? this.dayIndex,
      time: time ?? this.time,
      destinationItemId: destinationItemId ?? this.destinationItemId,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      transportType: transportType ?? this.transportType,
      polyline: polyline ?? this.polyline,
      cost: cost ?? this.cost,
      startLatitude: startLatitude ?? this.startLatitude,
      startLongitude: startLongitude ?? this.startLongitude,
      endLatitude: endLatitude ?? this.endLatitude,
      endLongitude: endLongitude ?? this.endLongitude,
      detailedSteps: detailedSteps ?? this.detailedSteps,
    );
  }

  factory RouteItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, SnapshotOptions? options) {
    final data = snapshot.data();
    if (data == null) throw Exception("Document ${snapshot.id} is empty");

    return RouteItem(
      id: snapshot.id,
      dayIndex: data['dayIndex'] as int,
      time: (data['time'] as Timestamp).toDate(),
      destinationItemId: data['destinationItemId'] as String,
      durationMinutes: data['durationMinutes'] as int,
      transportType: TransportType.values.firstWhere(
        (e) => e.name == data['transportType'], 
        orElse: () => TransportType.other
      ),
      polyline: data['polyline'] as String?,
      cost: (data['cost'] as num?)?.toDouble(),
      startLatitude: (data['startLatitude'] as num?)?.toDouble(),
      startLongitude: (data['startLongitude'] as num?)?.toDouble(),
      endLatitude: (data['endLatitude'] as num?)?.toDouble(),
      endLongitude: (data['endLongitude'] as num?)?.toDouble(),
      detailedSteps: (data['detailedSteps'] as List?)
          ?.map((e) => StepDetail.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'dayIndex': dayIndex,
      'time': Timestamp.fromDate(time),
      'destinationItemId': destinationItemId,
      'durationMinutes': durationMinutes,
      'transportType': transportType.name,
      'polyline': polyline,
      'cost': cost,
      'startLatitude': startLatitude,
      'startLongitude': startLongitude,
      'endLatitude': endLatitude,
      'endLongitude': endLongitude,
      'detailedSteps': detailedSteps.map((s) => s.toMap()).toList(),
    };
  }
}