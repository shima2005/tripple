import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:new_tripple/features/settings/domain/settings_cubit.dart';
import 'package:new_tripple/features/settings/domain/settings_state.dart';
import 'package:new_tripple/services/notification_service.dart';
import 'package:scroll_to_index/scroll_to_index.dart'; // 👈 追加
import 'package:visibility_detector/visibility_detector.dart'; // 👈 追加
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';
import 'package:new_tripple/features/trip/domain/trip_cubit.dart';
import 'package:new_tripple/features/trip/domain/trip_state.dart';
import 'package:new_tripple/features/trip/presentation/screens/trip_edit_modal.dart';
import 'package:new_tripple/features/trip/presentation/widgets/smart_ticket.dart';
import 'package:new_tripple/features/trip/presentation/widgets/timeline_item.dart';
import 'package:new_tripple/models/trip.dart';
import 'package:new_tripple/models/schedule_item.dart';
import 'package:new_tripple/models/route_item.dart';
import 'package:new_tripple/features/trip/presentation/screens/schedule_edit_modal.dart';
import 'package:new_tripple/features/trip/presentation/screens/route_edit_modal.dart';
import 'package:latlong2/latlong.dart';
import 'package:new_tripple/shared/widgets/tripple_empty_state.dart';
import 'package:new_tripple/features/trip/presentation/screens/expense_stats_screen.dart';
import 'package:new_tripple/services/pdf_service.dart';

class TimelineView extends StatefulWidget {
  final Trip trip;
  final VoidCallback onBack;
  final Function(LatLng?) onGoToMap;

  const TimelineView({
    super.key,
    required this.trip,
    required this.onBack,
    required this.onGoToMap,
  });

  

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> {
  // スクロール制御用コントローラー
  
  late AutoScrollController _scrollController;
  
  // 現在選択されているDayインデックス (0始まり)
  int _selectedDayIndex = 0;
  
  // タップによるスクロール中かどうかのフラグ (連動ロジックとの干渉防止)
  bool _isTabScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = AutoScrollController(
      viewportBoundaryGetter: () => Rect.fromLTRB(0, 0, 0, MediaQuery.of(context).padding.bottom),
    );
    context.read<TripCubit>().selectTrip(widget.trip.id);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 👇 ここを BlocBuilder から MultiBlocListener + BlocBuilder にアップグレード
    return MultiBlocListener(
      listeners: [
        // Listener 1: Tripデータが読み込まれたら通知を同期
        BlocListener<TripCubit, TripState>(
          listenWhen: (previous, current) => 
             previous.status != TripStatus.loaded && current.status == TripStatus.loaded,
          listener: (context, tripState) {
            // トリップデータがロード完了したら、現在の設定を使って通知を予約
            final settings = context.read<SettingsCubit>().state;
            context.read<TripCubit>().syncNotifications(settings);
          },
        ),
        // Listener 2: 設定が変更されたら通知を再同期
        BlocListener<SettingsCubit, SettingsState>(
          listener: (context, settingsState) {
            // 設定（通知ON/OFFや時間）が変わったら即反映
            context.read<TripCubit>().syncNotifications(settingsState);
          },
        ),
      ],
      child: BlocBuilder<TripCubit, TripState>(
        builder: (context, state){
          final currentTrip = state.selectedTrip ?? widget.trip;
          final daysCount = currentTrip.endDate.difference(currentTrip.startDate).inDays + 1;

          
          
          // 👇 2. 設定からHomeTownを取得
          final homeTown = context.watch<SettingsCubit>().state.homeTown;
          final homeCountryCode = context.watch<SettingsCubit>().state.homeCountryCode;
          // 👇 目的地 (Destinationsがあれば最初の場所、なければタイトル)
          String destinationName = currentTrip.title;
          String? destinationCountryCode;

          if (currentTrip.destinations.isNotEmpty) {
            // 滞在日数が一番長い場所を探す
            // reduceを使って比較: (curr, next) => currの方が長ければcurr、そうでなければnext
            final mainDest = currentTrip.destinations.reduce((curr, next) {
              final currDays = curr.stayDays ?? 0;
              final nextDays = next.stayDays ?? 0;
              return currDays >= nextDays ? curr : next;
            });
            
            destinationName = mainDest.name;
            destinationCountryCode = mainDest.countryCode; // 国コードも取得
          }

          return Scaffold(
            backgroundColor: AppColors.background,
            body: Stack(
              children: [
                CustomScrollView(
                  controller: _scrollController, 
                  slivers: [
                    // 1. ヘッダーエリア
                    SliverToBoxAdapter(
                      child: Stack(
                        children: [
                          // A. 背景画像
                          Positioned(
                            top: 0, left: 0, right: 0, height: 280,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _buildHeaderImage(currentTrip),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withOpacity(0.3),
                                        Colors.transparent,
                                        AppColors.background,
                                      ],
                                      stops: const [0.0, 0.6, 1.0],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // B. コンテンツ
                          Column(
                            children: [
                              const SizedBox(height: 60),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Column(
                                  children: [
                                    Text(
                                      currentTrip.title,
                                      style: AppTextStyles.h2.copyWith(
                                        color: Colors.white,
                                        fontSize: 24,
                                        shadows: [const Shadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 2))],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.25),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                                      ),
                                      child: Text(
                                        '${DateFormat('yyyy/MM/dd').format(currentTrip.startDate)} - ${DateFormat('MM/dd').format(currentTrip.endDate)}',
                                        style: AppTextStyles.label.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: SmartTicket(
                                  trip: currentTrip, 
                                  mode: TicketMode.summary,
                                  fromLocation: homeTown,    // 設定したホームタウン
                                  fromCountryCode: homeCountryCode,
                                  toLocation: destinationName,
                                  toCountryCode: destinationCountryCode,   // 旅行先
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // 2. 吸い付くDayタブ (機能強化！)
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _DayTabsDelegate(
                        daysCount: daysCount,
                        startDate: currentTrip.startDate,
                        selectedIndex: _selectedDayIndex, // 👈 現在の選択状態を渡す
                        onTabTap: (dayIndex) {
                          _scrollToDay(dayIndex); // 👈 タップ時のジャンプ処理
                        },
                      ),
                    ),

                    // 3. タイムライン
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                      sliver: BlocBuilder<TripCubit, TripState>(
                        builder: (context, state) {
                          if (state.status == TripStatus.loading) {
                            return const SliverToBoxAdapter(
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          if (state.scheduleItems.isEmpty) {
                            // 👇 SliverToBoxAdapter だと上に寄っちゃうので、SliverFillRemainingに変更
                            return const SliverFillRemaining(
                              hasScrollBody: false, // スクロール不要
                              child: Center(
                                child: TrippleEmptyState(
                                  title: 'Start Planning',
                                  message: 'Tap the "+" button to add spots manually, or ask AI to suggest a plan!',
                                  icon: Icons.map_rounded,
                                  accentColor: AppColors.accent,
                                ),
                              ),
                            );
                          }

                          // 「各Dayがリストの何番目から始まるか」を計算するマップを作成
                          // key: dayIndex, value: listIndex
                          final dayStartIndexMap = <int, int>{};
                          for (int i = 0; i < state.scheduleItems.length; i++) {
                            final item = state.scheduleItems[i];
                            int dayIndex = 0;
                            if (item is ScheduledItem) dayIndex = item.dayIndex;
                            else if (item is RouteItem) dayIndex = item.dayIndex;
                            
                            // そのDayがまだマップになければ、今のindexが開始位置
                            if (!dayStartIndexMap.containsKey(dayIndex)) {
                              dayStartIndexMap[dayIndex] = i;
                            }
                          }
                          // コントローラーにマップを保存できないので、State内で管理するか、
                          // ここで _scrollToDay 用に保持しておく必要があるが、
                          // 今回は _scrollToDay 内で再検索する簡易実装にするためマップは不要。
                          // むしろここでは「各日の先頭アイテム」にタグ付けをすることに集中する。

                          return SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final item = state.scheduleItems[index];
                                final isLast = index == state.scheduleItems.length - 1;
                                
                                int itemDayIndex = 0;
                                if (item is ScheduledItem) itemDayIndex = item.dayIndex;
                                else if (item is RouteItem) itemDayIndex = item.dayIndex;

                                // アイテムウィジェット
                                Widget child = TimelineItemWidget(
                                  item: item,
                                  isLast: isLast,
                                  // 👇 引数で item を受け取るように変更
                                  onTap: (tappedItem) {
                                    if (tappedItem is ScheduledItem) {
                                      // 滞在の編集
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (context) => ScheduleEditModal(
                                          trip: currentTrip,
                                          item: tappedItem,
                                        ),
                                      );
                                    } else if (tappedItem is RouteItem) {
                                      // 移動の編集 (新しく作ったModal！)
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (context) => RouteEditModal(
                                          tripId: currentTrip.id,
                                          route: tappedItem,
                                          mainTransport: currentTrip.mainTransport,
                                        ),
                                      );
                                    }
                                  },
                                  onMapTap: (scheduledItem) {
                                    // 緯度経度があれば渡す
                                    if (scheduledItem.latitude != null && scheduledItem.longitude != null) {
                                      widget.onGoToMap(
                                        LatLng(scheduledItem.latitude!, scheduledItem.longitude!)
                                      );
                                    } else {
                                      // なければ null (全体表示になる)
                                      widget.onGoToMap(null);
                                    }
                                  },
                                );

                                // ★重要: AutoScrollTag と VisibilityDetector でラップ
                                return AutoScrollTag(
                                  key: ValueKey(index),
                                  controller: _scrollController,
                                  index: index,
                                  child: VisibilityDetector(
                                    key: Key('item-$index'),
                                    onVisibilityChanged: (info) {
                                      // タブタップによるスクロール中は更新しない
                                      if (_isTabScrolling) return;

                                      // アイテムが50%以上見えていて、かつその日の先頭アイテムならタブを更新
                                      if (info.visibleFraction > 0.5) {
                                        // 前のアイテムとDayが違う、または最初のアイテムの場合のみ更新
                                        // (簡易的に、今のアイテムのdayIndexを採用する)
                                        if (_selectedDayIndex != itemDayIndex) {
                                          setState(() {
                                            _selectedDayIndex = itemDayIndex;
                                          });
                                        }
                                      }
                                    },
                                    child: child,
                                  ),
                                );
                              },
                              childCount: state.scheduleItems.length,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),

                // 4. 戻るボタン & メニュー
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22, shadows: [Shadow(color: Colors.black38, blurRadius: 4)]),
                            onPressed: widget.onBack,
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.playlist_add_check, color: Colors.blue),
                                onPressed: () async {
                                  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
                                  
                                  // 予約中の通知を取得
                                  final pendingNotifications = await flutterLocalNotificationsPlugin.pendingNotificationRequests();
                                  
                                  print('=== 予約中の通知一覧 (${pendingNotifications.length}件) ===');
                                  for (var notification in pendingNotifications) {
                                    print('ID: ${notification.id}, Title: ${notification.title}, Body: ${notification.body}');
                                    // ※残念ながら時間は取れませんが、件数があれば「予約自体は成功」しています
                                  }
                                  
                                  if (pendingNotifications.isEmpty) {
                                    print('❌ 予約されている通知はありません。予約処理でエラーが起きているか、時間が過去判定されています。');
                                    print('現在時刻: ${DateTime.now()}');
                                  } else {
                                    print('✅ OSへの予約は成功しています！これで鳴らないなら省電力設定が怪しいです。');
                                  }
                                },
                                ),
                              IconButton(
                                icon: const Icon(
                                  Icons.attach_money,
                                  color: Colors.white,
                                  size: 24,
                                  shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                                ),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (context) => ExpenseStatsScreen(trip: currentTrip))
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.print_rounded,
                                  color: Colors.white,
                                  size: 24,
                                  shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                                ),
                                onPressed: () async {
                                  final trip = state.selectedTrip!;
                                  final items = state.scheduleItems; // Cubitが持ってるソート済みリスト
                                  
                                  // 処理中はローディング出すなどしてもいいけど、PrintingパッケージがUI出してくれるので直呼びでOK
                                  await PdfService().printTripPdf(trip, items);
                                }
                              ),
                              IconButton(
                                icon: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 28, shadows: [Shadow(color: Colors.black38, blurRadius: 4)]),
                                onPressed: () async {
                                  final result = await showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) => TripEditModal(trip: currentTrip),
                                  );
                                  if (result == true) widget.onBack();
                                },
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      )
    );
  }

  Widget _buildHeaderImage(Trip trip) {
    if (trip.coverImageUrl != null && trip.coverImageUrl!.isNotEmpty) {
      // 👇 ここを書き換え！
      return CachedNetworkImage(
        imageUrl: trip.coverImageUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: Colors.grey[200]),
        errorWidget: (context, url, error) => _buildDefaultHeaderGradient(), // グラデーションメソッドを呼ぶ
      );
    }
    return _buildDefaultHeaderGradient();
  }
  
  // (補足) グラデーション部分をメソッドに切り出しておくと便利
  Widget _buildDefaultHeaderGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF89f7fe), Color(0xFF66a6ff)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  // --- タブタップ時のジャンプ処理 ---
  Future<void> _scrollToDay(int dayIndex) async {
    // 1. 目的のDayがリストの何番目かを探す
    final state = context.read<TripCubit>().state;
    final listIndex = state.scheduleItems.indexWhere((item) {
      if (item is ScheduledItem) return item.dayIndex == dayIndex;
      if (item is RouteItem) return item.dayIndex == dayIndex;
      return false;
    });

    if (listIndex != -1) {
      setState(() {
        _selectedDayIndex = dayIndex; // タブ選択状態を即更新
        _isTabScrolling = true; // ロック開始
      });

      // 2. スクロール実行 (preferPosition: begin でリストの上端に合わせる)
      await _scrollController.scrollToIndex(
        listIndex,
        preferPosition: AutoScrollPosition.begin,
        duration: const Duration(milliseconds: 500),
      );

      setState(() {
        _isTabScrolling = false; // ロック解除
      });
    }
  }
}

// ----------------------------------------------------------------
// DayTabsDelegate (選択状態を受け取れるように更新)
// ----------------------------------------------------------------
class _DayTabsDelegate extends SliverPersistentHeaderDelegate {
  final int daysCount;
  final DateTime startDate;
  final int selectedIndex; // 👈 追加
  final Function(int) onTabTap; // 👈 追加

  _DayTabsDelegate({
    required this.daysCount,
    required this.startDate,
    required this.selectedIndex,
    required this.onTabTap,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // 選択されたタブが見えるように自動スクロールさせたい場合は、
    // ここでScrollablePositionedListなどを使うか、簡易的にanimateToを使う。
    // 今回は標準のListViewなので、selectedIndexが変わっても自動追従はしないが、
    // タップ操作には反応する。

    return Container(
      color: AppColors.background.withOpacity(0.95),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: daysCount,
        itemBuilder: (context, index) {
          final currentDate = startDate.add(Duration(days: index));
          final dateText = DateFormat('MM/dd').format(currentDate);
          final weekDay = DateFormat('E').format(currentDate);
          final isSelected = index == selectedIndex; // 👈 Stateから判定

          return GestureDetector(
            onTap: () => onTabTap(index), // 👈 コールバック
            child: AnimatedContainer( // アニメーションで色替え
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.shade300),
                boxShadow: isSelected ? [
                  BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
                ] : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Day ${index + 1}',
                    style: AppTextStyles.label.copyWith(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$dateText ($weekDay)',
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected ? Colors.white70 : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  double get maxExtent => 80;
  @override
  double get minExtent => 80;
  @override
  bool shouldRebuild(covariant _DayTabsDelegate oldDelegate) {
    // 選択状態が変わったらリビルドが必要
    return oldDelegate.selectedIndex != selectedIndex || oldDelegate.daysCount != daysCount;
  }
}