import 'dart:async'; // 👈 Timerのために追加
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:new_tripple/features/settings/domain/settings_cubit.dart';
import 'package:new_tripple/features/settings/domain/settings_state.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
// VisibilityDetectorは削除してもOK（Dayタブ連動だけに残してもいいけど、チケットには使わない）
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
  late AutoScrollController _scrollController;
  int _selectedDayIndex = 0;
  
  // 👇 タイマー管理用
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _scrollController = AutoScrollController(
      viewportBoundaryGetter: () => Rect.fromLTRB(0, 0, 0, MediaQuery.of(context).padding.bottom),
    );
    context.read<TripCubit>().selectTrip(widget.trip.id);

    // 👇 1分ごとに画面を更新して、チケット表示を最新時刻に合わせる
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // 👈 忘れずに破棄
    _scrollController.dispose();
    super.dispose();
  }

  // 👇 現在時刻に基づいて「今の予定」または「次の予定」を探すロジック
  ({ScheduledItem? stay, RouteItem? move, String? nextName}) _getCurrentTicketData(List<dynamic> items) {
    if (items.isEmpty) return (stay: null, move: null, nextName: null);

    // 1. 現在進行中の予定を探す
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      DateTime? start;
      DateTime? end;

      if (item is ScheduledItem) {
        start = item.time;
        // 滞在時間が未定ならとりあえず1時間とみなす（または次の予定開始まで）
        final duration = item.durationMinutes ?? 60; 
        end = start.add(Duration(minutes: duration));
        
        // 今がこの滞在期間中ならビンゴ
        if (_now.isAfter(start) && _now.isBefore(end)) {
          return (stay: item, move: null, nextName: null);
        }

      } else if (item is RouteItem) {
        start = item.time;
        final duration = item.durationMinutes;
        end = start.add(Duration(minutes: duration));

        // 今が移動中ならビンゴ
        if (_now.isAfter(start) && _now.isBefore(end)) {
          // 移動中の場合、次の目的地の名前が知りたい
          String? nextName;
          if (i + 1 < items.length) {
            final nextItem = items[i + 1];
            if (nextItem is ScheduledItem) nextName = nextItem.name;
          }
          return (stay: null, move: item, nextName: nextName);
        }
      }
    }

    // 2. 進行中のものがなければ、「次の予定」を探す (Gap Time)
    //    現在時刻より後で、一番近い開始時刻の予定
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      DateTime start;
      if (item is ScheduledItem) start = item.time;
      else if (item is RouteItem) start = item.time;
      else continue;

      if (start.isAfter(_now)) {
        // これが「次の予定」
        if (item is ScheduledItem) {
          return (stay: item, move: null, nextName: null);
        } else if (item is RouteItem) {
           String? nextName;
           if (i + 1 < items.length) {
             final nextItem = items[i + 1];
             if (nextItem is ScheduledItem) nextName = nextItem.name;
           }
           return (stay: null, move: item, nextName: nextName);
        }
      }
    }

    // 3. 全部終わってる、あるいはまだ始まってない（遠い未来）などはSummary表示
    return (stay: null, move: null, nextName: null);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // (Listener部分は変更なし)
        BlocListener<TripCubit, TripState>(
          listenWhen: (previous, current) => 
             previous.status != TripStatus.loaded && current.status == TripStatus.loaded,
          listener: (context, tripState) {
            final settings = context.read<SettingsCubit>().state;
            context.read<TripCubit>().syncNotifications(settings);
          },
        ),
        BlocListener<SettingsCubit, SettingsState>(
          listener: (context, settingsState) {
            context.read<TripCubit>().syncNotifications(settingsState);
          },
        ),
      ],
      child: BlocBuilder<TripCubit, TripState>(
        builder: (context, state){
          final currentTrip = state.selectedTrip ?? widget.trip;
          final daysCount = currentTrip.endDate.difference(currentTrip.startDate).inDays + 1;
          
          final homeTown = context.watch<SettingsCubit>().state.homeTown;
          final homeCountryCode = context.watch<SettingsCubit>().state.homeCountryCode;
          
          String destinationName = currentTrip.title;
          String? destinationCountryCode;
          if (currentTrip.destinations.isNotEmpty) {
            final mainDest = currentTrip.destinations.reduce((curr, next) {
              final currDays = curr.stayDays ?? 0;
              final nextDays = next.stayDays ?? 0;
              return currDays >= nextDays ? curr : next;
            });
            destinationName = mainDest.name;
            destinationCountryCode = mainDest.countryCode;
          }

          // 👇 ここで計算実行！
          final currentTicketData = _getCurrentTicketData(state.scheduleItems);

          return Scaffold(
            backgroundColor: AppColors.background,
            body: Stack(
              children: [
                CustomScrollView(
                  controller: _scrollController, 
                  slivers: [
                    SliverToBoxAdapter(
                      child: Stack(
                        children: [
                          // A. 背景画像 (変更なし)
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
                              // (タイトル部分は省略、変更なし)
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
                                  // mode は指定せず自動判定に任せる
                                  fromLocation: homeTown,
                                  fromCountryCode: homeCountryCode,
                                  toLocation: destinationName,
                                  toCountryCode: destinationCountryCode,
                                  
                                  // 👇 割り出した「今の予定」を渡す
                                  currentStay: currentTicketData.stay,
                                  currentMove: currentTicketData.move,
                                  nextDestinationName: currentTicketData.nextName,
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // (DayTabsDelegate は変更なし)
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _DayTabsDelegate(
                        daysCount: daysCount,
                        startDate: currentTrip.startDate,
                        selectedIndex: _selectedDayIndex,
                        onTabTap: (dayIndex) {
                          _scrollToDay(dayIndex);
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
                            return const SliverFillRemaining(
                              hasScrollBody: false,
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

                          return SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final item = state.scheduleItems[index];
                                final isLast = index == state.scheduleItems.length - 1;
                                
                                Widget child = TimelineItemWidget(
                                  item: item,
                                  isLast: isLast,
                                  onTap: (tappedItem) {
                                      // (タップ処理省略: 変更なし)
                                      if (tappedItem is ScheduledItem) {
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
                                     // (マップ処理省略: 変更なし)
                                     if (scheduledItem.latitude != null && scheduledItem.longitude != null) {
                                      widget.onGoToMap(
                                        LatLng(scheduledItem.latitude!, scheduledItem.longitude!)
                                      );
                                    } else {
                                      widget.onGoToMap(null);
                                    }
                                  },
                                );

                                // AutoScrollTagは残すが、VisibilityDetectorによるTicket制御は削除
                                return AutoScrollTag(
                                  key: ValueKey(index),
                                  controller: _scrollController,
                                  index: index,
                                  child: child, 
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
                // (戻るボタン類は変更なし)
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
                                  final items = state.scheduleItems;
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

  // (以下、_buildHeaderImage, _buildDefaultHeaderGradient, _scrollToDay, _DayTabsDelegate はそのまま)
  Widget _buildHeaderImage(Trip trip) {
    Widget image;
    if (trip.coverImageUrl != null && trip.coverImageUrl!.isNotEmpty) {
      image = CachedNetworkImage(
        imageUrl: trip.coverImageUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: Colors.grey[200]),
        errorWidget: (context, url, error) => _buildDefaultHeaderGradient(),
      );
     }else{
      image = _buildDefaultHeaderGradient();
     } 
     return Hero(
      tag: 'trip-img-${trip.id}',
      child: image);
  }
  
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

  Future<void> _scrollToDay(int dayIndex) async {
    final state = context.read<TripCubit>().state;
    final listIndex = state.scheduleItems.indexWhere((item) {
      if (item is ScheduledItem) return item.dayIndex == dayIndex;
      if (item is RouteItem) return item.dayIndex == dayIndex;
      return false;
    });

    if (listIndex != -1) {
      setState(() {
        _selectedDayIndex = dayIndex;
      });

      await _scrollController.scrollToIndex(
        listIndex,
        preferPosition: AutoScrollPosition.begin,
        duration: const Duration(milliseconds: 500),
      );
    }
  }
}

// (_DayTabsDelegate クラス定義も変更なし)
class _DayTabsDelegate extends SliverPersistentHeaderDelegate {
  final int daysCount;
  final DateTime startDate;
  final int selectedIndex;
  final Function(int) onTabTap;

  _DayTabsDelegate({
    required this.daysCount,
    required this.startDate,
    required this.selectedIndex,
    required this.onTabTap,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
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
          final isSelected = index == selectedIndex;

          return GestureDetector(
            onTap: () => onTabTap(index),
            child: AnimatedContainer(
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
    return oldDelegate.selectedIndex != selectedIndex || oldDelegate.daysCount != daysCount;
  }
}