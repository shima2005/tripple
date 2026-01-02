import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/features/discover/domain/discover_cubit.dart';
import 'package:new_tripple/features/discover/domain/discover_state.dart';
import 'package:new_tripple/features/discover/presentation/widgets/post_card.dart';
import 'package:new_tripple/shared/widgets/custom_header.dart';

// 👇 DiscoverScreenは「Navigatorの入れ物」になります
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> with AutomaticKeepAliveClientMixin {
  // Nested Navigator用のキー
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  // タブを切り替えても状態（スタック）を維持する設定
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // KeepAliveに必須

    // Androidの「戻るボタン」ハンドリング
    // タブ内でスタックが積まれていれば、アプリ終了ではなく「タブ内戻る」を実行
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = _navigatorKey.currentState;
        if (navigator != null && navigator.canPop()) {
          navigator.pop();
        }
      },
      child: Navigator(
        key: _navigatorKey,
        onGenerateRoute: (settings) {
          // 初期ルートとしてフィード画面を表示
          return MaterialPageRoute(
            builder: (context) => const _DiscoverFeed(),
          );
        },
      ),
    );
  }
}

// 👇 元のDiscoverScreenの中身をここに移動
class _DiscoverFeed extends StatefulWidget {
  const _DiscoverFeed();

  @override
  State<_DiscoverFeed> createState() => _DiscoverFeedState();
}

class _DiscoverFeedState extends State<_DiscoverFeed> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 画面表示時に最新の投稿を読み込む
    // Note: KeepAliveが効いているので、タブ切り替えのたびにリロードされることはなくなります👍
    // 明示的にリロードしたい場合はRefreshIndicatorを使ってください
    if (context.read<DiscoverCubit>().state.posts.isEmpty) {
      context.read<DiscoverCubit>().loadRecentPosts();
    }
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
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  const CustomHeader(title: "Discover"),
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
                      // 👇 【重要】ボトムバーに隠れないように下部に余白を追加！
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: state.posts.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 24),
                      itemBuilder: (context, index) {
                        // ここでPostCardがタップされてNavigator.pushしても、
                        // 親のNavigator（今回作ったやつ）の中で遷移するのでボトムバーは残ります！
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