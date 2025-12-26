import 'enums.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduledItem {
  final String id;
  final int dayIndex;
  final DateTime time;
  final String name;
  final String? locationAddress;
  final double? latitude;
  final double? longitude;
  final ItemCategory category;
  final String? notes;
  final double? cost;
  final int? durationMinutes;
  final String? imageUrl;
  final bool isTimeFixed;

  const ScheduledItem({
    required this.id,
    required this.dayIndex,
    required this.time,
    required this.name,
    this.locationAddress,
    this.latitude,
    this.longitude,
    required this.category,
    this.notes,
    this.cost,
    this.durationMinutes,
    this.imageUrl,
    this.isTimeFixed = false,
  });

  // 👇 copyWithを追加！
  ScheduledItem copyWith({
    String? id,
    int? dayIndex,
    DateTime? time,
    String? name,
    String? locationAddress,
    double? latitude,
    double? longitude,
    ItemCategory? category,
    String? notes,
    double? cost,
    int? durationMinutes,
    String? imageUrl,
    bool? isTimeFixed,
  }) {
    return ScheduledItem(
      id: id ?? this.id,
      dayIndex: dayIndex ?? this.dayIndex,
      time: time ?? this.time,
      name: name ?? this.name,
      locationAddress: locationAddress ?? this.locationAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      cost: cost ?? this.cost,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      imageUrl: imageUrl ?? this.imageUrl,
      isTimeFixed: isTimeFixed ?? this.isTimeFixed,
    );
  }

  factory ScheduledItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, SnapshotOptions? options) {
    final data = snapshot.data();
    if (data == null) throw Exception("Document ${snapshot.id} is empty");
    
    return ScheduledItem(
      id: snapshot.id,
      dayIndex: data['dayIndex'] as int,
      time: (data['time'] as Timestamp).toDate(),
      name: data['name'] as String,
      locationAddress: data['locationAddress'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      category: ItemCategory.values.firstWhere(
        (e) => e.name == data['category'], 
        orElse: () => ItemCategory.other
      ),
      notes: data['notes'] as String?,
      cost: (data['cost'] as num?)?.toDouble(),
      durationMinutes: data['durationMinutes'] as int?,
      imageUrl: data['imageUrl'] as String?,
      isTimeFixed: data['isTimeFixed'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'dayIndex': dayIndex,
      'time': Timestamp.fromDate(time),
      'name': name,
      'locationAddress': locationAddress,
      'latitude': latitude,
      'longitude': longitude,
      'category': category.name,
      'notes': notes,
      'cost': cost,
      'durationMinutes': durationMinutes,
      'imageUrl': imageUrl,
      'isTimeFixed': isTimeFixed,
    };
  }
}