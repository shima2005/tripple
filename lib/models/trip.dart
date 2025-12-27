import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:new_tripple/models/enums.dart';
import 'package:new_tripple/models/expense_item.dart';
// 👇 新しいクラス: 旅行の行き先 (複数登録対応)
class TripDestination {
  final String name;
  final String? country;
  final String? countryCode;
  final String? state;
  final double latitude;
  final double longitude;
  final int? stayDays;

  const TripDestination({
    required this.name,
    this.country,
    this.countryCode,
    this.state,
    required this.latitude,
    required this.longitude,
    this.stayDays,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'country': country,
      'countryCode': countryCode,
      'state': state,
      'latitude': latitude,
      'longitude': longitude,
      'stayDays': stayDays,
    };
  }

  factory TripDestination.fromMap(Map<String, dynamic> map) {
    return TripDestination(
      name: map['name'] as String,
      country: map['country'] as String?,
      countryCode: map['countryCode'] as String?, 
      state: map['state'] as String?,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      stayDays: map['stayDays'] as int?,
    );
  }

}

class ChecklistItem {
  final String name;
  final bool isChecked;

  const ChecklistItem({
    required this.name,
    this.isChecked = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'isChecked': isChecked,
    };
  }

  factory ChecklistItem.fromMap(Map<String, dynamic> map) {
    return ChecklistItem(
      name: map['name'] as String,
      isChecked: map['isChecked'] as bool? ?? false,
    );
  }
}

class Trip {
  final String id;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final String ownerId;
  final DateTime createdAt;
  
  // 👇 フィールド追加！
  final List<TripDestination> destinations; 

  final List<String>? memberIds; 
  final List<ChecklistItem> checklist; 
  final List<String>? tags; 
  final String? coverImageUrl;

  final TransportType mainTransport;

  final List<TripGuest> guests;
  


  const Trip({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.ownerId,
    required this.createdAt,
    this.destinations = const [], // 👈 デフォルトは空リスト
    this.memberIds,      
    this.checklist = const [],      
    this.tags,           
    this.coverImageUrl,
    this.mainTransport = TransportType.transit,
    this.guests = const [],
  });

  Trip copyWith({
    String? id,
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    String? ownerId,
    DateTime? createdAt,
    List<TripDestination>? destinations,
    List<String>? memberIds,
    List<String>? tags,
    String? coverImageUrl,
    List<ChecklistItem>? checklist,
    TransportType? mainTransport,
    List<TripGuest>? guests,
  }) {
    return Trip(
      id: id ?? this.id,
      title: title ?? this.title,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      destinations: destinations ?? this.destinations,
      memberIds: memberIds ?? this.memberIds,
      tags: tags ?? this.tags,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      checklist: checklist ?? this.checklist,
      mainTransport: mainTransport ?? this.mainTransport,
      guests: guests ?? this.guests, 
    );
  }

  
  factory Trip.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot, SnapshotOptions? options) {
    final data = snapshot.data();
    if (data == null) {
      throw Exception("Document ${snapshot.id} is empty");
    }
    return Trip(
      id: snapshot.id,
      title: data['title'] as String,
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      ownerId: data['ownerId'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      destinations: (data['destinations'] as List?)?.map((e) {
        return TripDestination.fromMap(Map<String, dynamic>.from(e as Map));
      }).toList() ?? [],
      memberIds: (data['memberIds'] as List?)?.cast<String>(),
      checklist: (data['checklist'] as List?)
          ?.map((e) => ChecklistItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList() ?? [],
      tags: (data['tags'] as List?)?.cast<String>(),
      coverImageUrl: data['coverImageUrl'] as String?,
      mainTransport: data['mainTransport'] != null
          ? TransportType.values.byName(data['mainTransport'])
          : TransportType.transit,
      guests: (data['guests'] as List?)?.map((e) {
        return TripGuest.fromMap(Map<String, dynamic>.from(e as Map));
      }).toList() ?? [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'ownerId': ownerId,
      'createdAt': Timestamp.fromDate(createdAt),
      'memberIds': memberIds,
      'checklist': checklist.map((c) => c.toMap()).toList(),
      'tags': tags,
      'coverImageUrl': coverImageUrl,
      'destinations': destinations.map((d) => d.toMap()).toList(),
      'mainTransport': mainTransport.name,
      'guests': guests.map((d) => d.toMap()).toList(),
    };
  } 

}