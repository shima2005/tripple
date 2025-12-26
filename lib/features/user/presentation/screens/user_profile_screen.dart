import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/features/discover/data/discover_repository.dart';
import 'package:new_tripple/features/discover/presentation/screens/post_detail_screen.dart';
import 'package:new_tripple/features/user/data/user_repository.dart';
import 'package:new_tripple/models/post.dart';
import 'package:new_tripple/models/user_profile.dart';
import 'package:new_tripple/shared/widgets/tripple_toast.dart'; // Toastのパス確認

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final bool isMe;

  const UserProfileScreen({super.key, required this.userId, this.isMe = false});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  UserProfile? _profile;
  List<Post> _allPosts = []; // 取得した全データ
  List<Post> _displayPosts = []; // 表示用（ソート済み）データ
  
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _isFollowLoading = false;
  
  // 👇 並び替え用フラグ (false: 最新順, true: いいね順)
  bool _isPopularSort = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final userRepo = context.read<UserRepository>();
    final discoverRepo = context.read<DiscoverRepository>();
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    try {
      final profile = await userRepo.getUserProfile(widget.userId);
      final posts = await discoverRepo.fetchPostsByUserId(widget.userId);

      bool isFollowing = false;
      if (!widget.isMe && myUid != null && profile != null) {
        final myProfile = await userRepo.getUserProfile(myUid);
        isFollowing = myProfile?.followingIds.contains(widget.userId) ?? false;
      }

      if (mounted) {
        setState(() {
          _profile = profile;
          _allPosts = posts;
          _isFollowing = isFollowing;
          _isLoading = false;
          _sortPosts(); // 初期ソート
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 👇 並び替えロジック (クライアントサイドでサクッとソート)
  void _sortPosts() {
    setState(() {
      if (_isPopularSort) {
        // いいね数 降順
        _displayPosts = List.from(_allPosts)..sort((a, b) => b.likesCount.compareTo(a.likesCount));
      } else {
        // 作成日 降順
        _displayPosts = List.from(_allPosts)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
    });
  }

  Future<void> _toggleFollow() async {
    final user = FirebaseAuth.instance.currentUser;
    // 👇 1. ゲストガード (非ログイン or 匿名ユーザーは弾く)
    if (user == null || user.isAnonymous) {
      TrippleToast.show(context, 'Login required to follow.', isError: true);
      return;
    }
    
    if (_profile == null) return;

    setState(() => _isFollowLoading = true);
    
    final oldIsFollowing = _isFollowing;
    final oldProfile = _profile!;

    try {
      await context.read<UserRepository>().toggleFollow(
        currentUid: user.uid,
        targetUid: widget.userId,
      );
      
      if (mounted) {
        setState(() {
          _isFollowing = !_isFollowing;
          final newFollowerIds = List<String>.from(_profile!.followerIds);
          if (_isFollowing) {
             if (!newFollowerIds.contains(user.uid)) newFollowerIds.add(user.uid);
          } else {
             newFollowerIds.remove(user.uid);
          }
          _profile = _profile!.copyWith(followerIds: newFollowerIds);
          _isFollowLoading = false;
        });
        TrippleToast.show(context, _isFollowing ? 'Followed!' : 'Unfollowed');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFollowing = oldIsFollowing;
          _profile = oldProfile;
          _isFollowLoading = false;
        });
        TrippleToast.show(context, 'Error: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }

    if (_profile == null) {
      return Scaffold(
        appBar: AppBar(elevation: 0, backgroundColor: Colors.white, iconTheme: const IconThemeData(color: Colors.black)),
        body: const Center(child: Text('User not found')),
      );
    }

    final totalLikes = _allPosts.fold(0, (sum, post) => sum + post.likesCount);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        // タイトルはシンプルにIDだけにしてスッキリさせる
        title: Text(
           _profile!.customId.isNotEmpty ? '@${_profile!.customId}' : _profile!.displayName,
           style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (widget.isMe)
            IconButton(
              icon: const Icon(Icons.menu_rounded, color: Colors.black), // 設定など
              onPressed: () {},
            ),
        ],
      ),
      body: DefaultTabController(
        length: 2,
        child: NestedScrollView(
          // 👇 ヘッダー部分をスクロールに合わせて隠すため NestedScrollView を採用
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 2. コンパクトなプロフィールレイアウト (横並び)
                      Row(
                        children: [
                          // アイコン (少し小さく: radius 36)
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: _profile!.photoUrl != null
                                ? CachedNetworkImageProvider(_profile!.photoUrl!)
                                : null,
                            child: _profile!.photoUrl == null
                                ? const Icon(Icons.person, size: 36, color: Colors.grey)
                                : null,
                          ),
                          const SizedBox(width: 24),
                          
                          // スタッツ (右側に配置)
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _StatItem(value: '${_allPosts.length}', label: 'Posts'),
                                _StatItem(value: '${_profile!.followerIds.length}', label: 'Followers'),
                                _StatItem(value: '${_profile!.followingIds.length}', label: 'Following'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // 名前 & 自己紹介 (あれば)
                      Text(_profile!.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      // if (_profile!.bio.isNotEmpty) ...[
                      //   const SizedBox(height: 4),
                      //   Text(_profile!.bio, style: const TextStyle(fontSize: 14)),
                      // ],
                      const SizedBox(height: 4),
                      Text('Total Likes: $totalLikes ❤️', style: TextStyle(color: Colors.grey[600], fontSize: 12)),

                      const SizedBox(height: 16),

                      // アクションボタン (横長)
                      SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: !widget.isMe
                          ? FilledButton(
                              onPressed: _isFollowLoading ? null : _toggleFollow,
                              style: FilledButton.styleFrom(
                                backgroundColor: _isFollowing ? Colors.grey[200] : AppColors.primary,
                                foregroundColor: _isFollowing ? Colors.black : Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: _isFollowLoading
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                  : Text(_isFollowing ? 'Following' : 'Follow', style: const TextStyle(fontWeight: FontWeight.bold)),
                            )
                          : OutlinedButton(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              child: const Text('Edit Profile', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                            ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. 並び替えタブ (SliverPersistentHeader的に使う)
              SliverPersistentHeader(
                delegate: _SliverAppBarDelegate(
                  TabBar(
                    labelColor: Colors.black,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: AppColors.primary,
                    indicatorWeight: 2,
                    onTap: (index) {
                      setState(() {
                        _isPopularSort = (index == 1);
                        _sortPosts();
                      });
                    },
                    tabs: const [
                      Tab(icon: Icon(Icons.grid_on_rounded), text: "Latest"),
                      Tab(icon: Icon(Icons.favorite_border_rounded), text: "Popular"),
                    ],
                  ),
                ),
                pinned: true, // 上に固定される！
              ),
            ];
          },
          body: _displayPosts.isEmpty
              ? const Center(child: Text('No posts yet.', style: TextStyle(color: Colors.grey)))
              : GridView.builder(
                  padding: const EdgeInsets.all(2), // 隙間を詰める
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, // Instagramっぽく3列に
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                    childAspectRatio: 1.0, // 正方形
                  ),
                  itemCount: _displayPosts.length,
                  itemBuilder: (context, index) {
                    final post = _displayPosts[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
                        );
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: post.headerImageUrl,
                            fit: BoxFit.cover,
                            placeholder: (c, u) => Container(color: Colors.grey[200]),
                          ),
                          // 人気順のときはいいね数を右上に表示してあげると親切
                          if (_isPopularSort)
                            Positioned(
                              top: 4, right: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.favorite, size: 10, color: Colors.white),
                                    const SizedBox(width: 2),
                                    Text('${post.likesCount}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

// ヘッダー固定用のDelegateクラス
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white, // 背景白
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}