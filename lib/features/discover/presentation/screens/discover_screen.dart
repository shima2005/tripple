import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';
import 'package:new_tripple/features/discover/domain/discover_cubit.dart';
import 'package:new_tripple/features/discover/domain/discover_state.dart';
import 'package:new_tripple/features/discover/presentation/widgets/post_card.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 画面表示時に最新の投稿を読み込む
    context.read<DiscoverCubit>().loadRecentPosts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // 🔍 ヘッダー & 検索バー
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Discover', style: AppTextStyles.h1),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search tags, places...',
                      prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onSubmitted: (query) {
                      context.read<DiscoverCubit>().searchPosts(query);
                    },
                  ),
                ],
              ),
            ),
            
            // 📱 タイムライン
            Expanded(
              child: BlocBuilder<DiscoverCubit, DiscoverState>(
                builder: (context, state) {
                  if (state.status == DiscoverStatus.loading && state.posts.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (state.posts.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.explore_off_rounded, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          const Text('No posts found yet.', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () => context.read<DiscoverCubit>().loadRecentPosts(),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.posts.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 24),
                      itemBuilder: (context, index) {
                        return PostCard(post: state.posts[index]);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}