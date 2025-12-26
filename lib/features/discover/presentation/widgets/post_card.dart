import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/features/user/data/user_repository.dart';
import 'package:new_tripple/models/post.dart';
import 'package:new_tripple/models/user_profile.dart';
import 'package:new_tripple/features/discover/presentation/screens/post_detail_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:new_tripple/features/discover/domain/discover_cubit.dart';

class PostCard extends StatelessWidget {
  final Post post;
  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isGuest = user == null || user.isAnonymous;

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)));
      },
      child: Container(
        // 👇 高さを抑えるために余計な装飾を減らし、フラットに近いデザインに
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16), // 角丸を少し控えめに
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Image (高さを 220 -> 160 に変更)
            Stack(
              children: [
                SizedBox(
                  height: 160, // 👈 コンパクト化！
                  width: double.infinity,
                  child: CachedNetworkImage(
                    imageUrl: post.headerImageUrl,
                    fit: BoxFit.cover,
                    placeholder: (c, u) => Container(color: Colors.grey[100]),
                  ),
                ),
                // Trip Tag (少し小さく)
                if (post.tripId.isNotEmpty)
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: const [
                          Icon(Icons.map, color: Colors.white, size: 10),
                          SizedBox(width: 4),
                          Text('Trip Plan', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            
            // 2. Info Area (パディングを減らす)
            Padding(
              padding: const EdgeInsets.all(12), // 16 -> 12
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title (フォントサイズ調整)
                  Text(
                    post.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), // 18 -> 16
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis
                  ),
                  const SizedBox(height: 6),
                  
                  // Author & Actions
                  FutureBuilder<UserProfile?>(
                    future: context.read<UserRepository>().getUserProfile(post.authorId),
                    builder: (context, snapshot) {
                      final name = snapshot.data?.displayName ?? 'Unknown';
                      return Row(
                        children: [
                           // アイコンなどをなくしてシンプルに名前だけ
                           Text('by $name', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                           const Spacer(),
                           
                           // 👇 アクションボタン (コンパクト化)
                           _CompactAction(
                             icon: post.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                             color: post.isLiked ? Colors.pink : Colors.grey[400]!,
                             count: post.likesCount,
                             onTap: () {
                               if (isGuest) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login required.')));
                                  return;
                               }
                               context.read<DiscoverCubit>().toggleLike(post.id, user.uid);
                             },
                           ),
                           const SizedBox(width: 12),
                           _CompactAction(
                             icon: post.isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                             color: post.isBookmarked ? AppColors.primary : Colors.grey[400]!,
                             count: post.bookmarksCount,
                             onTap: () {
                               if (isGuest) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login required.')));
                                  return;
                               }
                               context.read<DiscoverCubit>().toggleBookmark(post.id, user.uid);
                             },
                           ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 小さいアクションボタン
class _CompactAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int count;
  final VoidCallback onTap;

  const _CompactAction({required this.icon, required this.color, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque, // タップ判定を広げる
      child: Row(
        children: [
          Icon(icon, size: 18, color: color), // 20 -> 18
          const SizedBox(width: 2),
          Text('$count', style: TextStyle(fontSize: 11, color: Colors.grey[600])), // 12 -> 11
        ],
      ),
    );
  }
}