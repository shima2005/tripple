import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:new_tripple/models/user_profile.dart';

class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // 1. プロフィール取得
  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      // ⚠️ ここで .doc(uid) を使っているか確認！
      final doc = await _firestore.collection('users').doc(uid).get();
      
      if (doc.exists) {
        // ここでモデル変換のエラーが出ていないか？
        return UserProfile.fromMap(doc.data()!); 
        // または UserProfile.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('❌ getUserProfile Error: $e'); // エラーログが出るか確認
      return null;
    }
  }

  // 2. プロフィール作成/更新 (CustomIDの重複チェック付き)
  Future<void> saveUserProfile(UserProfile profile) async {
    // 本当はTransactionでcustomIdのユニークチェックが必要だが、簡易実装
    await _firestore.collection('users').doc(profile.uid).set(profile.toMap(), SetOptions(merge: true));
  }

  // 3. Custom IDでユーザー検索
  Future<UserProfile?> searchUserByCustomId(String customId) async {
    final snapshot = await _firestore
        .collection('users')
        .where('customId', isEqualTo: customId)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return UserProfile.fromMap(snapshot.docs.first.data());
    }
    return null;
  }

  // 4. 旅行への招待を送る
  Future<void> sendTripInvitation({
    required String toUid,
    required String fromUid,
    required String fromName,
    required String tripId,
    required String tripName,
  }) async {
    final notification = AppNotification(
      id: '', // 自動生成
      type: NotificationType.tripInvite,
      fromUid: fromUid,
      fromName: fromName,
      tripId: tripId,
      tripName: tripName,
      createdAt: DateTime.now(),
    );

    // 相手のサブコレクション 'notifications' に追加
    await _firestore.collection('users').doc(toUid).collection('notifications').add(notification.toMap());
  }

  // 5. フレンド申請を送る
  Future<void> sendFriendRequest({
    required String toUid,
    required String fromUid,
    required String fromName,
  }) async {
    final notification = AppNotification(
      id: '',
      type: NotificationType.friendRequest,
      fromUid: fromUid,
      fromName: fromName,
      createdAt: DateTime.now(),
    );
    await _firestore.collection('users').doc(toUid).collection('notifications').add(notification.toMap());
  }

  // 6. 自分への通知を取得 (Stream)
  Stream<List<AppNotification>> getNotifications(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => AppNotification.fromFirestore(doc)).toList());
  }

  // 7. 通知を削除 (承諾/拒否後)
  Future<void> deleteNotification(String uid, String notificationId) async {
    await _firestore.collection('users').doc(uid).collection('notifications').doc(notificationId).delete();
  }

  // 8. フレンドになる (双方のfriendIdsに追加)
  Future<void> acceptFriendRequest(String uid1, String uid2) async {
    final batch = _firestore.batch();
    
    // update だとドキュメントがない場合にクラッシュするので、
    // set(..., SetOptions(merge: true)) を使うのが安全です。
    
    final user1Ref = _firestore.collection('users').doc(uid1);
    batch.set(user1Ref, {
      'friendIds': FieldValue.arrayUnion([uid2])
    }, SetOptions(merge: true));

    final user2Ref = _firestore.collection('users').doc(uid2);
    batch.set(user2Ref, {
      'friendIds': FieldValue.arrayUnion([uid1])
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<List<UserProfile>> getUsersByIds(List<String> uids) async {
    if (uids.isEmpty) return [];
    
    final List<UserProfile> users = [];
    
    // FirestoreのwhereInは一度に10件までなので、チャンクに分ける
    for (var i = 0; i < uids.length; i += 10) {
      final end = (i + 10 < uids.length) ? i + 10 : uids.length;
      final chunk = uids.sublist(i, end);
      
      final snapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
          
      users.addAll(snapshot.docs.map((d) => UserProfile.fromMap(d.data())).toList());
    }
    
    return users;
  }

  // 👇 追加: フォロー/フォロー解除の切り替え
  Future<void> toggleFollow({required String currentUid, required String targetUid}) async {
    final userRef = _firestore.collection('users').doc(currentUid);
    final targetRef = _firestore.collection('users').doc(targetUid);

    await _firestore.runTransaction((transaction) async {
      final userSnap = await transaction.get(userRef);
      if (!userSnap.exists) return;

      final followingIds = List<String>.from(userSnap.data()?['followingIds'] ?? []);
      final isFollowing = followingIds.contains(targetUid);

      if (isFollowing) {
        // フォロー解除 (Unfollow)
        transaction.update(userRef, {
          'followingIds': FieldValue.arrayRemove([targetUid])
        });
        transaction.update(targetRef, {
          'followerIds': FieldValue.arrayRemove([currentUid])
        });
      } else {
        // フォローする (Follow)
        transaction.update(userRef, {
          'followingIds': FieldValue.arrayUnion([targetUid])
        });
        transaction.update(targetRef, {
          'followerIds': FieldValue.arrayUnion([currentUid])
        });
      }
    });
  }
}