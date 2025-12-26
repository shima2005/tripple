import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String customId;
  final String displayName;
  final String? photoUrl;
  final List<String> friendIds;

  // 👇 追加: 設定項目
  final String? homeCountry; // 国コード (例: 'jp')
  final String? homeTown;    // 都市名 (例: 'Kyoto')
  final String? language;    // 言語コード (例: 'ja')
  final String? currency;    // 通貨コード (例: 'jpy')

  final List<String> followingIds; // フォローしている人
  final List<String> followerIds;  // フォロワー

  const UserProfile({
    required this.uid,
    required this.customId,
    required this.displayName,
    this.photoUrl,
    this.friendIds = const [],
    this.homeCountry,
    this.homeTown,
    this.language,
    this.currency,
    this.followerIds = const [],
    this.followingIds = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'customId': customId,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'friendIds': friendIds,
      // 👇 追加
      'homeCountry': homeCountry,
      'homeTown': homeTown,
      'language': language,
      'currency': currency,
      'followerIds': followerIds,
      'followingIds': followingIds,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] as String,
      customId: map['customId'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'No Name',
      photoUrl: map['photoUrl'] as String?,
      friendIds: (map['friendIds'] as List?)?.cast<String>() ?? [],
      // 👇 追加
      homeCountry: map['homeCountry'] as String?,
      homeTown: map['homeTown'] as String?,
      language: map['language'] as String?,
      currency: map['currency'] as String?,
      followerIds: (map['followerIds'] as List?)?.cast<String>() ?? [],
      followingIds: (map['followingIds'] as List?)?.cast<String>() ?? [],
    );
  }
  
  // copyWithも更新しておくと便利です
  UserProfile copyWith({
    String? uid,
    String? customId,
    String? displayName,
    String? photoUrl,
    List<String>? friendIds,
    String? homeCountry,
    String? homeTown,
    String? language,
    String? currency,
    List<String>? followerIds,
    List<String>? followingIds,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      customId: customId ?? this.customId,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      friendIds: friendIds ?? this.friendIds,
      homeCountry: homeCountry ?? this.homeCountry,
      homeTown: homeTown ?? this.homeTown,
      language: language ?? this.language,
      currency: currency ?? this.currency,
      followerIds: followerIds ?? this.followerIds,
      followingIds: followingIds ?? this.followingIds,
    );
  }
}

// 👇 招待・申請のタイプ
enum NotificationType {
  tripInvite,
  friendRequest,
}

// 👇 通知/招待モデル
class AppNotification {
  final String id;
  final NotificationType type;
  final String fromUid;      // 誰から
  final String fromName;     // 誰から(表示名)
  final String? tripId;      // 旅行招待ならTripID
  final String? tripName;    // 旅行招待ならTrip名
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.fromUid,
    required this.fromName,
    this.tripId,
    this.tripName,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'fromUid': fromUid,
      'fromName': fromName,
      'tripId': tripId,
      'tripName': tripName,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      type: NotificationType.values.firstWhere((e) => e.name == data['type']),
      fromUid: data['fromUid'],
      fromName: data['fromName'],
      tripId: data['tripId'],
      tripName: data['tripName'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}