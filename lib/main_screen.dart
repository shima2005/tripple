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
  
  // 👇 PageControllerを追加
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
    });
  }

  void _openRecordPastTripModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PastTripLogModal(),
    );
  }

  // 👇 ページ切り替え処理
  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    // アニメーションでページ移動
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // 👇 マップなどからタブを強制移動する場合の処理
  void _jumpToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
    // 長距離移動でも自然に見えるようjumpではなくanimate推奨ですが、
    // 即座に切り替えたい場合は jumpToPage を使ってもOKです
    _pageController.jumpToPage(index); 
  }

  @override
  Widget build(BuildContext context) {
    final bool showFab = _currentIndex != 4;
    final bool isMapMode = _currentIndex == 3 && _selectedTrip == null;
    final bool showNotification = (_currentIndex == 0 || _currentIndex == 1 || _currentIndex == 4) && _selectedTrip == null;

    if (!showFab && _isMenuOpen) {
      _toggleMenu();
    }

    // --- FAB Menu Logic (省略せず維持) ---
    List<SpeedDialItem> speedDialItems = [];
    if(_currentIndex == 1){
      speedDialItems = [
        SpeedDialItem(label: '旅行記を投稿', icon: Icons.article_rounded, color: AppColors.primary, onTap: () { 
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CreatePostScreen(), fullscreenDialog: true)).then((_) { if (_isMenuOpen) _toggleMenu(); });
        }),
      ];
    } else if (!isMapMode && _selectedTrip == null) {
      speedDialItems = [
        SpeedDialItem(label: 'AIに提案してもらう', icon: Icons.auto_awesome, color: AppColors.primary, onTap: () {_toggleMenu(); showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => AITripPlanModal(onTripCreated: (trip) { setState(() { _selectedTrip = trip; _jumpToTab(0); }); },),); },),
        SpeedDialItem(label: '手動で作成', icon: Icons.edit_rounded, onTap: () { _toggleMenu(); showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => const TripEditModal(),); },),
        SpeedDialItem(label: 'コードで参加', icon: Icons.qr_code_rounded, onTap: () { _toggleMenu(); showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => const JoinTripModal(),); },),
      ];
    } else if (!isMapMode && _selectedTrip != null) {
      speedDialItems = [
        SpeedDialItem(label: '次の予定をAI提案', icon: Icons.auto_awesome, color: AppColors.accent, onTap: () { _toggleMenu(); showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => AISuggestSpotModal(trip: _selectedTrip!),); },),
        SpeedDialItem(label: 'AIで日程を最適化', icon: Icons.auto_awesome, color: AppColors.accent, onTap: () { _toggleMenu(); showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => AIOptimizeModal(trip: _selectedTrip!),); },),
        SpeedDialItem(label: 'スポット手動追加', icon: Icons.place_rounded, onTap: () { _toggleMenu(); showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => ScheduleEditModal(trip: _selectedTrip!, initialDateTime: _calculateNextScheduleTime(),)); },),
      ];
    }

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // 👇 ここをPageViewに変更！
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(), // スワイプでの切り替えを禁止（タブ操作のみ）
            children: [
              // Index 0
              _selectedTrip == null
                  ? TravelHomeScreen(
                      onTripSelected: (trip) {
                        setState(() { _selectedTrip = trip; });
                      },
                    )
                  : TimelineView(
                      trip: _selectedTrip!,
                      onBack: () {
                        setState(() { _selectedTrip = null; });
                      },
                      onGoToMap: (location) {
                        setState(() { _mapInitialFocus = location; });
                        _jumpToTab(3); // マップタブへジャンプ
                      },
                    ),
              
              // Index 1
              const DiscoverScreen(),

              // Index 2 (Placeholder for FAB)
              const SizedBox(),

              // Index 3
              _selectedTrip == null
                  ? GlobalMapScreen(
                      onTripSelected: (trip) {
                        setState(() { _selectedTrip = trip; });
                        _jumpToTab(0); // ホームタブへジャンプ
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
                            _jumpToTab(0); // ホームタブへジャンプ
                          },
                        );
                      },
                    ),
              
              // Index 4
              const SettingsScreen(),
            ],
          ),

          if (_isMenuOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleMenu,
                child: Container(color: Colors.black.withValues(alpha: 0.2)),
              ),
            ),
          
          // ボトムバー
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: GlassBottomBar(
              currentIndex: _currentIndex,
              onTap: _onTabTapped, // 👇 ここでアニメーション付き移動を呼び出す
            ),
          ),

          // FAB
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

          // 通知オーバーレイ
          if (_showNotifications)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showNotifications = false),
                behavior: HitTestBehavior.opaque,
                child: Container(color: Colors.transparent),
              ),
            ),

          if (_showNotifications)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              right: 20,
              child: NotificationPopup(
                onClose: () => setState(() => _showNotifications = false),
              ),
            ),

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

  // (以下、_buildNotificationButton, _calculateNextScheduleTime は元のまま)
  Widget _buildNotificationButton() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder(
      stream: userId != null ? context.read<UserRepository>().getNotifications(userId) : const Stream.empty(),
      builder: (context, snapshot) {
        final count = (snapshot.data as List?)?.length ?? 0;
        return GestureDetector(
          onTap: () => setState(() => _showNotifications = !_showNotifications),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))]),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(_showNotifications ? Icons.notifications_active_rounded : Icons.notifications_rounded, color: _showNotifications ? AppColors.accent : Colors.grey, size: 24),
                if (count > 0)
                  Positioned(top: -2, right: -2, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), constraints: const BoxConstraints(minWidth: 16, minHeight: 16), child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center))),
              ],
            ),
          ),
        );
      }
    );
  }

  DateTime _calculateNextScheduleTime() {
    final trip = _selectedTrip;
    if (trip == null) return DateTime.now();
    final state = context.read<TripCubit>().state;
    if (state.scheduleItems.isEmpty) return DateTime(trip.startDate.year, trip.startDate.month, trip.startDate.day, 10, 0);
    final lastItem = state.scheduleItems.last;
    DateTime lastTime;
    int duration = 60; 
    if (lastItem is ScheduledItem) { lastTime = lastItem.time; duration = lastItem.durationMinutes ?? 60; } else if (lastItem is RouteItem) { lastTime = lastItem.time; duration = lastItem.durationMinutes; } else { lastTime = trip.startDate; }
    return lastTime.add(Duration(minutes: duration + 30));
  }
}