import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String authorId;
  final String tripId;
  final String tripTitle;
  
  final String title;        // 👇 追加: ブログのタイトル
  final String content;      // 本文
  final String headerImageUrl; // 👇 追加: 一覧や検索に出るメイン画像
  final List<String> bodyImageUrls; // 本文用のその他の画像
  
  final String locationName;
  final List<String> tags;
  
  final int likesCount;
  final int bookmarksCount;
  final DateTime createdAt;

  // 👇 追加: UI表示用の一時的なフラグ (Firestoreには保存しない)
  final bool isLiked;
  final bool isBookmarked;

  const Post({
    required this.id,
    required this.authorId,
    required this.tripId,
    this.tripTitle = '',
    required this.title,        // Add
    required this.content,
    required this.headerImageUrl, // Add
    this.bodyImageUrls = const [],
    required this.locationName,
    this.tags = const [],
    this.likesCount = 0,
    this.bookmarksCount = 0,
    required this.createdAt,
    this.isLiked = false,
    this.isBookmarked = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'tripId': tripId,
      'tripTitle': tripTitle,
      'title': title,           // Add
      'content': content,
      'headerImageUrl': headerImageUrl, // Add
      'bodyImageUrls': bodyImageUrls,
      'locationName': locationName,
      'tags': tags,
      'likesCount': likesCount,
      'bookmarksCount': bookmarksCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Post.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Post(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      tripId: data['tripId'] ?? '',
      tripTitle: data['tripTitle'] ?? '',
      title: data['title'] ?? '',           // Add
      content: data['content'] ?? '',
      headerImageUrl: data['headerImageUrl'] ?? '', // Add
      bodyImageUrls: (data['bodyImageUrls'] as List?)?.cast<String>() ?? [],
      locationName: data['locationName'] ?? '',
      tags: (data['tags'] as List?)?.cast<String>() ?? [],
      likesCount: data['likesCount'] ?? 0,
      bookmarksCount: data['bookmarksCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  // 👇 copyWithを追加 (Cubitでの更新に必須)
  Post copyWith({
    String? id,
    int? likesCount,
    int? bookmarksCount,
    bool? isLiked,
    bool? isBookmarked,
    // ... 他のフィールドは省略 (必要なら追加)
  }) {
    return Post(
      id: id ?? this.id,
      authorId: authorId, // 変わらないものはそのまま
      tripId: tripId,
      tripTitle: tripTitle,
      title: title,
      content: content,
      headerImageUrl: headerImageUrl,
      bodyImageUrls: bodyImageUrls,
      locationName: locationName,
      tags: tags,
      createdAt: createdAt,
      // 更新対象
      likesCount: likesCount ?? this.likesCount,
      bookmarksCount: bookmarksCount ?? this.bookmarksCount,
      isLiked: isLiked ?? this.isLiked,
      isBookmarked: isBookmarked ?? this.isBookmarked,
    );
  }
}