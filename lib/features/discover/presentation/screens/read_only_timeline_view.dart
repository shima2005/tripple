import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';
import 'package:new_tripple/features/trip/data/trip_repository.dart';
import 'package:new_tripple/models/trip.dart';
import 'package:new_tripple/models/schedule_item.dart';
import 'package:new_tripple/models/route_item.dart';
import 'package:new_tripple/features/trip/presentation/widgets/timeline_item.dart';
import 'package:new_tripple/shared/widgets/tripple_empty_state.dart';

class ReadOnlyTimelineScreen extends StatefulWidget {
  final String tripId;
  final String? tripTitle;

  const ReadOnlyTimelineScreen({
    super.key,
    required this.tripId,
    this.tripTitle,
  });

  @override
  State<ReadOnlyTimelineScreen> createState() => _ReadOnlyTimelineScreenState();
}

class _ReadOnlyTimelineScreenState extends State<ReadOnlyTimelineScreen> {
  Trip? _trip;
  // リスト表示用にデータを加工したリスト (Stringヘッダー or ScheduleItem/RouteItem)
  List<dynamic> _displayItems = []; 
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final repo = context.read<TripRepository>();
      
      final results = await Future.wait([
        repo.getTripById(widget.tripId), 
        repo.fetchFullSchedule(widget.tripId),
      ]);

      if (!mounted) return;

      final trip = results[0] as Trip?;
      final rawItems = results[1] as List<dynamic>;

      if (trip == null) {
        setState(() {
          _errorMessage = "Trip not found";
          _isLoading = false;
        });
        return;
      }

      // データを日ごとに整理してリスト化
      final processedItems = _processScheduleItems(trip, rawItems);

      setState(() {
        _trip = trip;
        _displayItems = processedItems;
        _isLoading = false;
      });

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // 生データを「日付ヘッダー」と「アイテム」のフラットなリストに変換
  List<dynamic> _processScheduleItems(Trip trip, List<dynamic> items) {
    final List<dynamic> result = [];
    final int totalDays = trip.endDate.difference(trip.startDate).inDays + 1;

    // 日付ごとにフィルタリング
    for (int day = 0; day < totalDays; day++) {
      final dayDate = trip.startDate.add(Duration(days: day));
      
      // この日のアイテムを抽出
      final dayItems = items.where((item) {
        if (item is ScheduledItem) return item.dayIndex == day;
        if (item is RouteItem) return item.dayIndex == day;
        return false;
      }).toList();

      // 時間順にソート (RouteItemはtimeを持っているので比較可能と仮定)
      dayItems.sort((a, b) {
        DateTime timeA = (a is ScheduledItem) ? a.time : (a as RouteItem).time;
        DateTime timeB = (b is ScheduledItem) ? b.time : (b as RouteItem).time;
        return timeA.compareTo(timeB);
      });

      // アイテムがある日だけ表示、もしくはアイテムがなくても日付ヘッダーは出す仕様ならここを調整
      if (dayItems.isNotEmpty) {
        // ヘッダーオブジェクトを追加 (独自クラスでもMapでもOK)
        result.add({
          'type': 'header', 
          'day': day + 1, 
          'date': dayDate,
          'weekday': DateFormat('E').format(dayDate)
        });
        result.addAll(dayItems);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null || _trip == null) {
      return Scaffold(
        appBar: AppBar(elevation: 0, backgroundColor: Colors.white, iconTheme: const IconThemeData(color: Colors.black)),
        body: const Center(
          child: TrippleEmptyState(
            title: 'Trip Not Found',
            message: 'Could not load trip details.\nIt might have been deleted.',
            icon: Icons.error_outline_rounded,
            accentColor: Colors.grey,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // 1. ヘッダー (画像 + タイトル)
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.black),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: false,
              // 修正1: 戻るボタンと被らないように左パディングを増やす (60.0)
              titlePadding: const EdgeInsets.only(left: 60, bottom: 16, right: 16),
              title: Text(
                _trip!.title,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  shadows: [Shadow(color: Colors.white, blurRadius: 10)],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (_trip!.coverImageUrl != null)
                    CachedNetworkImage(
                      imageUrl: _trip!.coverImageUrl!,
                      fit: BoxFit.cover,
                    )
                  else
                    Container(
                      color: AppColors.primary.withOpacity(0.1),
                      child: const Icon(Icons.flight_takeoff, size: 64, color: AppColors.primary),
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.white70],
                        stops: [0.6, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. 情報カード
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    '${DateFormat('yyyy/MM/dd').format(_trip!.startDate)} - ${DateFormat('MM/dd').format(_trip!.endDate)}',
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (_trip!.tags != null)
                    ..._trip!.tags!.take(2).map((t) => Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Chip(label: Text(t, style: const TextStyle(fontSize: 10)), visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                    )),
                ],
              ),
            ),
          ),

          // 3. タイムライン
          if (_displayItems.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: TrippleEmptyState(
                  title: 'No Schedule',
                  message: 'This trip has no plans yet.',
                  icon: Icons.map_outlined,
                  accentColor: Colors.grey,
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = _displayItems[index];

                  // A. 日付ヘッダーの場合
                  if (item is Map && item['type'] == 'header') {
                    // 修正3: 何日目かわかるヘッダーを表示
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Day ${item['day']}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${DateFormat('MM/dd').format(item['date'])} (${item['weekday']})',
                            style: AppTextStyles.h3.copyWith(fontSize: 16, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    );
                  }

                  // B. スケジュールアイテムの場合
                  // 次のアイテムがヘッダーか、もしくはリストの最後なら「その日の最後」とみなす
                  final isLastItemOfDay = (index == _displayItems.length - 1) || 
                                          (_displayItems[index + 1] is Map && _displayItems[index + 1]['type'] == 'header');

                  // 修正4: paddingを外して線を繋げる
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16), // 横は空けるが、縦は密着
                    child: TimelineItemWidget(
                      item: item,
                      // 修正4: 日の最後だけ線を止める
                      isLast: isLastItemOfDay, 
                      isReadOnly: true,
                    ),
                  );
                },
                childCount: _displayItems.length,
              ),
            ),
            
          // 修正2: メニューバーや最下部の余白を考慮してパディングを追加
          SliverPadding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 60),
          ),
        ],
      ),
    );
  }
}