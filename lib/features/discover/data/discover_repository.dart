import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:new_tripple/models/post.dart';

class DiscoverRepository {
  final FirebaseFirestore _firestore;

  DiscoverRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ♻️ 共通処理: 投稿リストに「いいね/ブックマーク済みか」の情報を付与する
  Future<List<Post>> _attachUserStatus(List<Post> posts, String? userId) async {
    // ログインしていない、または投稿がない場合はそのまま返す
    if (userId == null || posts.isEmpty) return posts;

    // 並列処理で各投稿のステータスを確認
    return await Future.wait(posts.map((post) async {
      // いいねチェック
      final likeDoc = await _firestore
          .collection('posts')
          .doc(post.id)
          .collection('likes')
          .doc(userId)
          .get();

      // ブックマークチェック
      final bookmarkDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('bookmarks')
          .doc(post.id)
          .get();

      return post.copyWith(
        isLiked: likeDoc.exists,
        isBookmarked: bookmarkDoc.exists,
      );
    }));
  }

  // 1. タイムライン取得
  Future<List<Post>> fetchRecentPosts({String? currentUserId, int limit = 20}) async {
    final snapshot = await _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    final posts = snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();

    // 👇 共通化したメソッドを使う
    return _attachUserStatus(posts, currentUserId);
  }

  // 2. 投稿作成
  Future<void> createPost(Post post) async {
    await _firestore.collection('posts').add(post.toMap());
  }

  // 3. いいね切り替え
  Future<void> toggleLike(String postId, String userId, bool isLiked) async {
    final postRef = _firestore.collection('posts').doc(postId);
    final likeRef = postRef.collection('likes').doc(userId);

    await _firestore.runTransaction((transaction) async {
      final postSnap = await transaction.get(postRef);
      if (!postSnap.exists) return;

      if (isLiked) {
         // 解除
         transaction.delete(likeRef);
         transaction.update(postRef, {'likesCount': FieldValue.increment(-1)});
      } else {
         // 登録
         transaction.set(likeRef, {'createdAt': FieldValue.serverTimestamp()});
         transaction.update(postRef, {'likesCount': FieldValue.increment(1)});
      }
    });
  }

  // 4. ブックマーク切り替え
  Future<void> toggleBookmark(String postId, String userId, bool isBookmarked) async {
    final postRef = _firestore.collection('posts').doc(postId);
    final userBookmarkRef = _firestore.collection('users').doc(userId).collection('bookmarks').doc(postId);

    await _firestore.runTransaction((transaction) async {
      final postSnap = await transaction.get(postRef);
      if (!postSnap.exists) return;

      if (isBookmarked) {
        // 解除
        transaction.delete(userBookmarkRef);
        transaction.update(postRef, {'bookmarksCount': FieldValue.increment(-1)});
      } else {
        // 登録
        transaction.set(userBookmarkRef, {
          'postId': postId,
          'createdAt': FieldValue.serverTimestamp()
        });
        transaction.update(postRef, {'bookmarksCount': FieldValue.increment(1)});
      }
    });
  }
  
  // いいね状態の確認 (個別チェック用)
  Future<bool> hasLiked(String postId, String userId) async {
    final doc = await _firestore.collection('posts').doc(postId).collection('likes').doc(userId).get();
    return doc.exists;
  }

  // 5. 検索機能 (アプリ内フィルタリング)
  // 💡 DiscoverCubit側で currentUserId を渡すように修正が必要です（後述）
  Future<List<Post>> searchPosts(String query, {String? currentUserId}) async {
    final lowerQuery = query.toLowerCase().trim();
    
    // 空なら通常のタイムライン取得へ
    if (lowerQuery.isEmpty) return fetchRecentPosts(currentUserId: currentUserId);

    // 1. 直近の投稿を取得 (コスト削減のため10件に制限)
    final snapshot = await _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(20) // 👈 100から10に変更！
        .get();
        
    final allPosts = snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();

    // 2. アプリ内でキーワード絞り込み (タイトル、場所、タグ)
    final filteredPosts = allPosts.where((post) {
      final titleMatch = post.title.toLowerCase().contains(lowerQuery);
      final locationMatch = post.locationName.toLowerCase().contains(lowerQuery);
      final tagMatch = post.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
      
      return titleMatch || locationMatch || tagMatch;
    }).toList();
    
    // 3. 最後にユーザーステータス(いいね等)を付与して返す
    return _attachUserStatus(filteredPosts, currentUserId);
  }

  // 6. 特定ユーザーの投稿を取得
  Future<List<Post>> fetchPostsByUserId(String uid) async {
    final snapshot = await _firestore
        .collection('posts')
        .where('authorId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
  }
}