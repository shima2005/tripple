import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:new_tripple/features/discover/data/discover_repository.dart';
import 'package:new_tripple/features/discover/domain/discover_state.dart';
import 'package:new_tripple/models/post.dart';

class DiscoverCubit extends Cubit<DiscoverState> {
  final DiscoverRepository _discoverRepository;

  DiscoverCubit({required DiscoverRepository discoverRepository})
      : _discoverRepository = discoverRepository,
        super(const DiscoverState());
        

  // 1. タイムライン読み込み (修正)
  Future<void> loadRecentPosts() async {
    try {
      if (state.status == DiscoverStatus.initial) {
        emit(state.copyWith(status: DiscoverStatus.loading));
      }
      
      // 現在のユーザーIDを取得
      final currentUid = FirebaseAuth.instance.currentUser?.uid;

      // リポジトリに渡す
      final posts = await _discoverRepository.fetchRecentPosts(currentUserId: currentUid);
      
      emit(state.copyWith(status: DiscoverStatus.loaded, posts: posts));
    } catch (e) {
      emit(state.copyWith(status: DiscoverStatus.error, errorMessage: e.toString()));
    }
  }

  // 2. 投稿する
  Future<void> createPost(Post post) async {
    try {
      // 楽観的更新は難しい（IDがないため）ので、ローディングを出して再取得
      emit(state.copyWith(status: DiscoverStatus.loading));
      await _discoverRepository.createPost(post);
      await loadRecentPosts(); // リスト更新
    } catch (e) {
      emit(state.copyWith(status: DiscoverStatus.error, errorMessage: e.toString()));
    }
  }

  // 3. いいね切り替え (更新)
  Future<void> toggleLike(String postId, String userId) async {
    final currentPosts = List<Post>.from(state.posts);
    final index = currentPosts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final post = currentPosts[index];
    final isCurrentlyLiked = post.isLiked; // 現在の状態

    // UIを即座に更新
    currentPosts[index] = post.copyWith(
      isLiked: !isCurrentlyLiked, // 反転
      likesCount: isCurrentlyLiked ? post.likesCount - 1 : post.likesCount + 1,
    );
    emit(state.copyWith(posts: currentPosts));

    // 裏でAPI通信 (引数には「変更前の状態」を渡して、Repo側で処理分岐させるのが一般的ですが
    // ここではRepoの実装に合わせて「解除したいならtrue」として渡します)
    try {
      await _discoverRepository.toggleLike(postId, userId, isCurrentlyLiked);
    } catch (e) {
      // エラーなら元に戻す処理が必要ですが省略
      print('Like error: $e');
    }
  }

  // 👇 追加: ブックマーク切り替え
  Future<void> toggleBookmark(String postId, String userId) async {
    final currentPosts = List<Post>.from(state.posts);
    final index = currentPosts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final post = currentPosts[index];
    final isCurrentlyBookmarked = post.isBookmarked;

    // UI更新
    currentPosts[index] = post.copyWith(
      isBookmarked: !isCurrentlyBookmarked,
      bookmarksCount: isCurrentlyBookmarked ? post.bookmarksCount - 1 : post.bookmarksCount + 1,
    );
    emit(state.copyWith(posts: currentPosts));

    try {
      await _discoverRepository.toggleBookmark(postId, userId, isCurrentlyBookmarked);
    } catch (e) {
      print('Bookmark error: $e');
    }
  }

  // 4. 検索
  Future<void> searchPosts(String query) async {
    try {
      emit(state.copyWith(status: DiscoverStatus.loading));
      // 空なら全件、文字があれば検索
      final posts = query.isEmpty 
          ? await _discoverRepository.fetchRecentPosts()
          : await _discoverRepository.searchPosts(query);
      
      emit(state.copyWith(status: DiscoverStatus.loaded, posts: posts));
    } catch (e) {
      emit(state.copyWith(status: DiscoverStatus.error, errorMessage: e.toString()));
    }
  }

  
}