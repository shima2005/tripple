import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart'; // context.read用
import 'package:intl/intl.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';
import 'package:new_tripple/features/discover/domain/discover_cubit.dart';
import 'package:new_tripple/features/discover/presentation/screens/read_only_timeline_view.dart';
import 'package:new_tripple/features/user/presentation/screens/user_profile_screen.dart';
import 'package:new_tripple/models/post.dart';
import 'package:new_tripple/features/user/data/user_repository.dart';
import 'package:new_tripple/models/user_profile.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:new_tripple/shared/widgets/tripple_toast.dart';
import 'package:share_plus/share_plus.dart';

class PostDetailScreen extends StatefulWidget { // 👈 状態を持つのでStatefulに変更
  final Post post;
  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  bool _isFollowing = false; // ローカルで状態管理
  bool _isLoadingFollow = false;

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
  }

  // 👇 追加: シェア処理メソッド
  void _handleShare() {
    final post = widget.post;
    final String text = '''
Check out this trip on Tripple! ✈️

${post.title}
by User ID: ${post.authorId}

-------------------
${post.content.length > 100 ? "${post.content.substring(0, 100)}..." : post.content}
''';

    // シェアシートを表示
    Share.share(text, subject: post.title);
  }

  // 初期状態のチェック
  Future<void> _checkFollowStatus() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    // 自分のプロフィールを取得して、相手をフォローしてるか確認
    final myProfile = await context.read<UserRepository>().getUserProfile(myUid);
    if (myProfile != null && mounted) {
      setState(() {
        _isFollowing = myProfile.followingIds.contains(widget.post.authorId);
      });
    }
  }

  // フォローボタンを押した時の処理
  Future<void> _handleFollow() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) {
      TrippleToast.show(context, 'Login required', isError: true);
      return;
    }
    if (myUid == widget.post.authorId) return; // 自分自身はフォロー不可

    setState(() => _isLoadingFollow = true); // ローディング開始

    try {
      // リポジトリの処理を呼ぶ
      await context.read<UserRepository>().toggleFollow(
        currentUid: myUid, 
        targetUid: widget.post.authorId
      );

      if (mounted) {
        setState(() {
          _isFollowing = !_isFollowing; // 見た目を反転
          _isLoadingFollow = false;
        });
        // リッチなトースト表示✨
        TrippleToast.show(context, _isFollowing ? 'Followed!' : 'Unfollowed');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingFollow = false);
        TrippleToast.show(context, 'Error: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final isMe = myUid == widget.post.authorId;
    final user = FirebaseAuth.instance.currentUser;
    final isGuest = user == null || user.isAnonymous;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // 1. ヘッダー画像 (SliverAppBar)
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: CachedNetworkImage(
                imageUrl: post.headerImageUrl,
                fit: BoxFit.cover,
              ),
            ),
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Colors.white54, shape: BoxShape.circle),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. タイトル & ユーザー & フォローボタン
                  Text(widget.post.title, style: AppTextStyles.h1.copyWith(fontSize: 28)),
                  const SizedBox(height: 16),
                  
                  FutureBuilder<UserProfile?>(
                    future: context.read<UserRepository>().getUserProfile(widget.post.authorId),
                    builder: (context, snapshot) {
                      final user = snapshot.data;
                      return GestureDetector( 
                        onTap: () {
                           final myUid = FirebaseAuth.instance.currentUser?.uid;
                           Navigator.push(
                             context,
                             MaterialPageRoute(
                               builder: (_) => UserProfileScreen(
                                 userId: post.authorId,
                                 isMe: post.authorId == myUid,
                               ),
                             ),
                           );
                        },
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: user?.photoUrl != null ? CachedNetworkImageProvider(user!.photoUrl!) : null,
                              backgroundColor: Colors.grey[200],
                              child: user?.photoUrl == null ? const Icon(Icons.person, color: Colors.grey) : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded( // 名前が長くても大丈夫なように
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user?.displayName ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text(DateFormat('yyyy/MM/dd').format(widget.post.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
 
                          
                          // 👇 ここにフォローボタン配置！
                          if (!isMe) 
                            SizedBox(
                              height: 36,
                              child: _isLoadingFollow
                                ? const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2))
                                : FilledButton.tonal(
                                    onPressed: (){
                                      if(isGuest){
                                        TrippleToast.show(context, 'Login Required.', isError: true);
                                      } else{
                                        _handleFollow;
                                      }
                                    },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _isFollowing ? Colors.grey[200] : AppColors.primary.withValues(alpha: 0.1),
                                      foregroundColor: _isFollowing ? Colors.black : AppColors.primary,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                    ),
                                    child: Text(
                                      _isFollowing ? 'Following' : 'Follow',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ),
                          ],
                        )
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // 3. 本文
                  MarkdownBody(
                    data: post.content,
                    selectable: true, // テキスト選択可能に
                    styleSheet: MarkdownStyleSheet(
                      h1: AppTextStyles.h1.copyWith(fontSize: 24, height: 2.0),
                      h2: AppTextStyles.h2.copyWith(fontSize: 20, height: 1.8),
                      p: AppTextStyles.bodyLarge.copyWith(height: 1.8),
                      strong: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    // 画像の読み込みビルダー (キャッシュ対応)
                    imageBuilder: (uri, title, alt) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CachedNetworkImage(
                          imageUrl: uri.toString(),
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (c, u) => Container(
                            height: 200, 
                            color: Colors.grey[200], 
                            child: const Center(child: CircularProgressIndicator())
                          ),
                        ),
                      );
                    },
                  ),

                  // 5. Trip Link Card (リッチ版)
                  if (post.tripId.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                child: const Icon(Icons.flight_takeoff_rounded, color: AppColors.primary),
                              ),
                              const SizedBox(width: 12),
                              const Text('Included Trip Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(post.tripTitle, style: AppTextStyles.h3),
                          const SizedBox(height: 8),
                          const Text('Check the detailed schedule and map for this trip.', style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () {
                                // 👇 ReadOnlyTimelineScreen へ遷移！
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ReadOnlyTimelineScreen(
                                      tripId: post.tripId,
                                      tripTitle: post.tripTitle,
                                    ),
                                  ),
                                );
                              },
                              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                              child: const Text('View Full Plan'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 40),

                  // Actions Row (詳細画面用)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Like Button
                      _ActionButton(
                        icon: post.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: post.isLiked ? Colors.pink : Colors.grey,
                        label: '${post.likesCount} Likes',
                        onTap: () {
                           // 👇 ゲストガード
                           if (isGuest) {
                            TrippleToast.show(context, 'Login required.');
                            return;
                           }
                           context.read<DiscoverCubit>().toggleLike(post.id, user.uid);
                        },
                      ),
                      
                      // Bookmark Button
                      _ActionButton(
                        icon: post.isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        color: post.isBookmarked ? AppColors.primary : Colors.grey,
                        label: '${post.bookmarksCount} Saves',
                        onTap: () {
                           // 👇 ゲストガード
                           if (isGuest) {
                            TrippleToast.show(context, 'Login required.');
                            return;
                           }
                           context.read<DiscoverCubit>().toggleBookmark(post.id, user.uid);
                        },
                      ),

                      _ActionButton(
                        icon: Icons.share_rounded,
                        color: Colors.grey,
                        label: 'Share',
                        onTap: _handleShare,
                      ),
                    ],
                  ),
                                      
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}