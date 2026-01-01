import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/features/discover/presentation/screens/create_post_screen.dart';
import 'package:new_tripple/features/discover/presentation/screens/discover_screen.dart';
import 'package:new_tripple/features/trip/presentation/screens/ai_optimize_modal.dart';
import 'package:new_tripple/features/trip/presentation/screens/ai_suggest_spot_modal.dart';
import 'package:new_tripple/features/trip/presentation/screens/ai_trip_plan_modal.dart';
import 'package:new_tripple/features/trip/presentation/screens/join_trip_modal.dart'; 
import 'package:new_tripple/features/trip/presentation/screens/schedule_edit_modal.dart';
import 'package:new_tripple/features/trip/presentation/screens/travel_home_screen.dart';
import 'package:new_tripple/features/trip/presentation/screens/trip_edit_modal.dart';
import 'package:new_tripple/features/user/presentation/widgets/notification_popup.dart';
import 'package:new_tripple/models/route_item.dart';
import 'package:new_tripple/shared/widgets/glass_bottom_bar.dart';
import 'package:new_tripple/models/trip.dart';
import 'package:new_tripple/features/trip/presentation/screens/timeline_view.dart'; 
import 'package:flutter_bloc/flutter_bloc.dart'; 
import 'package:new_tripple/features/trip/domain/trip_cubit.dart';
import 'package:new_tripple/features/trip/domain/trip_state.dart'; 
import 'package:new_tripple/models/schedule_item.dart';
import 'package:new_tripple/features/map/presentation/screens/route_map_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:new_tripple/features/map/presentation/screens/global_map_screen.dart'; 
import 'package:new_tripple/features/trip/presentation/screens/record_past_trip_modal.dart';
import 'package:new_tripple/features/settings/presentation/screens/settings_screen.dart';
import 'package:new_tripple/shared/widgets/tripple_speed_dial.dart';
import 'package:new_tripple/features/user/data/user_repository.dart';


class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {

  Trip? _selectedTrip;

  int _currentIndex = 0;
  bool _isMenuOpen = false;
  LatLng? _mapInitialFocus;
  bool _showNotifications = false;

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
    });
  }

  // 👇 追加: 過去の旅行を記録するモーダルを開く処理
  void _openRecordPastTripModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PastTripLogModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showFab = _currentIndex != 4;
    // 地図モードかどうか
    final bool isMapMode = _currentIndex == 3 && _selectedTrip == null;

    final bool showNotification = (_currentIndex == 0 || _currentIndex == 1 || _currentIndex == 4) && _selectedTrip == null;

    if (!showFab && _isMenuOpen) {
      _toggleMenu();
    }

    List<SpeedDialItem> speedDialItems = [];

    if(_currentIndex == 1){
      speedDialItems = [
        SpeedDialItem(
          label: '旅行記を投稿',
          icon: Icons.article_rounded,
          color: AppColors.primary,
          onTap: () { // 念のため async に
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const CreatePostScreen(),
                fullscreenDialog: true,
              ),
            ).then((_) {
              // 戻ってきたらメニューを閉じる
              if (_isMenuOpen) _toggleMenu();
            });
          }
        ),
      ];
    } else if (!isMapMode && _selectedTrip == null) {
      // ホーム画面用メニュー
      speedDialItems = [
        SpeedDialItem(
          label: 'AIに提案してもらう',
          icon: Icons.auto_awesome,
          color: AppColors.primary,
          onTap: () {_toggleMenu();
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => AITripPlanModal(
                onTripCreated: (trip) {
                  // 👇 作成されたTripを受け取って、詳細画面へ遷移！
                  setState(() {
                    _selectedTrip = trip;
                    _currentIndex = 0; // Homeタブへ
                  });
                },
              ),
            );
          },
        ),
        SpeedDialItem(
          label: '手動で作成',
          icon: Icons.edit_rounded,
          onTap: () {
            _toggleMenu();
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const TripEditModal(),
            );
          },
        ),
        SpeedDialItem(
          label: 'コードで参加',
          icon: Icons.qr_code_rounded,
          onTap: () {
            _toggleMenu();
            // 👇 JoinModalを開く
            showModalBottomSheet(
              context: context,
              isScrollControlled: true, // 全画面スキャナを使うので必須
              backgroundColor: Colors.transparent,
              builder: (context) => const JoinTripModal(),
            );
          },
        ),
      ];
    } else if (!isMapMode && _selectedTrip != null) {
      // 詳細画面用メニュー
      speedDialItems = [
        SpeedDialItem(
          label: '次の予定をAI提案',
          icon: Icons.auto_awesome,
          color: AppColors.accent,
          onTap: () { 
            _toggleMenu();
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => AISuggestSpotModal(trip: _selectedTrip!),
            );
          },
        ),
        SpeedDialItem(
          label: 'AIで日程を最適化',
          icon: Icons.auto_awesome,
          color: AppColors.accent,
          onTap: () {
            _toggleMenu();
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => AIOptimizeModal(trip: _selectedTrip!),
            );
          },
        ),
        SpeedDialItem(
          label: 'スポット手動追加',
          icon: Icons.place_rounded,
          onTap: () {
            _toggleMenu();
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => ScheduleEditModal(trip: _selectedTrip!, initialDateTime: _calculateNextScheduleTime(),)
            );
          },
        ),
      ];
    }

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              // Index 0
              _selectedTrip == null
                  ? TravelHomeScreen(
                      onTripSelected: (trip) {
                        setState(() {
                          _selectedTrip = trip; 
                        });
                      },
                    )
                  : TimelineView(
                      trip: _selectedTrip!,
                      onBack: () {
                        setState(() {
                          _selectedTrip = null; 
                        });
                      },
                      onGoToMap: (location) {
                        setState(() {
                          _mapInitialFocus = location;
                          _currentIndex = 3; 
                        });
                      },
                    ),
              
              // Index 1,
              const DiscoverScreen(),

              const SizedBox(),

              // Index 3
              _selectedTrip == null
                  ? GlobalMapScreen(
                      onTripSelected: (trip) {
                        setState(() {
                          _selectedTrip = trip;
                          _currentIndex = 0;
                        });
                      },
                    )
                  : BlocBuilder<TripCubit, TripState>(
                      builder: (context, state) {
                        final scheduledItems = state.scheduleItems.whereType<ScheduledItem>().toList();
                        final routeItems = state.scheduleItems.whereType<RouteItem>().toList();
                        return RouteMapScreen(
                          trip: _selectedTrip!,
                          routeItems: routeItems,
                          scheduleItems: scheduledItems,
                          onBackTap: () {
                            setState(() {
                              _currentIndex = 0;
                            });
                          },
                        );
                      },
                    ),
              const SettingsScreen(),
            ],
          ),

          if (_isMenuOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleMenu,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.2),
                ),
              ),
            ),
          

          // ボトムバー
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: GlassBottomBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() => _currentIndex = index);
              },
            ),
          ),

          // 4. メインのFAB
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: TrippleSpeedDial(
                items: speedDialItems,
                isMenuOpen: _isMenuOpen,
                onToggle: _toggleMenu,
                showFab: showFab,
                mainIcon: isMapMode ? Icons.history_edu_rounded : Icons.add,
                onMainIconTap: isMapMode ? _openRecordPastTripModal : null,
              ),
            ),
          ),

          if (_showNotifications)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showNotifications = false),
                behavior: HitTestBehavior.opaque, // 透明でもタッチを検知
                child: Container(color: Colors.transparent),
              ),
            ),

          // 5. 【修正】ポップアップ本体 (レイヤーより「後」に書く＝手前に表示)
          if (_showNotifications)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              right: 20,
              child: NotificationPopup(
                onClose: () => setState(() => _showNotifications = false),
              ),
            ),

          // 6. 通知ボタン (一番手前)
          if (showNotification)
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              right: 24,
              child: _buildNotificationButton(),
            ),
        ],
      ),
    );
  }

  // 通知ボタン (バッジ付き)
  Widget _buildNotificationButton() {
    // ここでStreamBuilderを使って未読数を監視するのがベスト
    // 今回は簡易的にアイコンのみ
    final userId = FirebaseAuth.instance.currentUser?.uid;
    
    return StreamBuilder(
      stream: userId != null ? context.read<UserRepository>().getNotifications(userId) : const Stream.empty(),
      builder: (context, snapshot) {
        final count = (snapshot.data as List?)?.length ?? 0;
        
        return GestureDetector(
          onTap: () => setState(() => _showNotifications = !_showNotifications),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  _showNotifications ? Icons.notifications_active_rounded : Icons.notifications_rounded,
                  color: _showNotifications ? AppColors.accent : Colors.grey,
                  size: 24,
                ),
                if (count > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '$count',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }
    );
  }
  // ヘルパー: 次の予定のデフォルト時間を計算
  DateTime _calculateNextScheduleTime() {
    final trip = _selectedTrip;
    if (trip == null) return DateTime.now();

    // TripCubitの状態から最新のアイテムリストを取得
    final state = context.read<TripCubit>().state;
    
    // スケジュールが空なら、旅行の開始日の朝10時
    if (state.scheduleItems.isEmpty) {
      return DateTime(
        trip.startDate.year, trip.startDate.month, trip.startDate.day, 
        10, 0
      );
    }

    // 最後のアイテムを取得
    final lastItem = state.scheduleItems.last;
    
    // 最後のアイテムの時間を取得
    DateTime lastTime;
    int duration = 60; // デフォルト1時間

    if (lastItem is ScheduledItem) {
      lastTime = lastItem.time;
      duration = lastItem.durationMinutes ?? 60;
    } else if (lastItem is RouteItem) {
      lastTime = lastItem.time;
      duration = lastItem.durationMinutes;
    } else {
      lastTime = trip.startDate;
    }

    // 「最後の予定の開始時間 + 所要時間 + 移動バッファ(30分)」を次の開始時間にする
    // ※もし日付をまたぐ場合は、そのまま次の日の時間になるのでOK
    return lastTime.add(Duration(minutes: duration + 30));
  }
}