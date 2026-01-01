import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 👈 認証用
import 'package:shared_preferences/shared_preferences.dart'; // 👈 設定読み込み用
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import 'package:new_tripple/models/expense_item.dart';
import 'package:new_tripple/models/step_detail.dart';
import 'package:new_tripple/models/trip.dart';
import 'package:new_tripple/models/schedule_item.dart';
import 'package:new_tripple/models/route_item.dart';
import 'package:new_tripple/models/enums.dart';
import 'trip_state.dart'; 
import 'package:new_tripple/features/trip/data/trip_repository.dart'; 
import 'package:new_tripple/services/routing_service.dart';
import 'package:new_tripple/services/gemini_service.dart'; 
import 'package:new_tripple/core/constants/checklist_data.dart'; 
import 'package:new_tripple/features/settings/domain/settings_state.dart';
import 'package:new_tripple/services/notification_service.dart';

class TripCubit extends Cubit<TripState> {
  final TripRepository _tripRepository;
  
  Timer? _ongoingTimer; // 常時通知用タイマー
  StreamSubscription<User?>? _authSubscription; // 🔐 認証監視用

  final _geminiService = GeminiService();
  final _routingService = RoutingService();

  TripCubit({required TripRepository tripRepository})
      : _tripRepository = tripRepository,
        super(const TripState()) {
    
    // 🔥 ここで認証状態を監視！
    // ログインしたら勝手にロード、ログアウトしたらクリア。これでmain.dartでの呼び出しは不要になります。
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        loadMyTrips(); // ユーザーがいればロード開始
      } else {
        // ログアウト時はデータをクリア
        emit(state.copyWith(allTrips: [], selectedTrip: null, scheduleItems: [], expenses: []));
        _stopOngoingTimer();
        NotificationService().cancelOngoingNotification();
      }
    });
  }

  // ----------------------------------------------------------------
  // 1. 旅行リストの管理
  // ----------------------------------------------------------------

  // 👇 引数をなくし、内部でCurrent Userを使う安全設計に変更
  Future<void> loadMyTrips() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // ユーザーがいなければ何もしない

    try {
      emit(state.copyWith(status: TripStatus.loading));
      final trips = await _tripRepository.fetchTrips(user.uid);

      //TODO 必要ならサンプルデータ等
      final samples = await _tripRepository.fetchTrips("sample");
      trips.addAll(samples);

      emit(state.copyWith(status: TripStatus.loaded, allTrips: trips));

      // 🚀 ロード完了後、アクティブな旅行がないかチェックして通知を開始
      await _checkAndSetupActiveTripNotification(trips);

    } catch (e) {
      emit(state.copyWith(status: TripStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> addTrip(Trip newTrip) async {
    try {
      emit(state.copyWith(status: TripStatus.submitting));
      await _tripRepository.addTrip(newTrip);
      
      // 再ロードせずにリスト更新
      final currentTrips = List<Trip>.from(state.allTrips);
      final index = currentTrips.indexWhere((t) => t.id == newTrip.id);

      if (index != -1) {
        currentTrips[index] = newTrip;
        Trip? updatedSelectedTrip = state.selectedTrip;
        if (state.selectedTrip?.id == newTrip.id) updatedSelectedTrip = newTrip;
        emit(state.copyWith(status: TripStatus.loaded, allTrips: currentTrips, selectedTrip: updatedSelectedTrip));
      } else {
        // 新規追加の場合はリスト先頭へ
        currentTrips.insert(0, newTrip);
        emit(state.copyWith(status: TripStatus.loaded, allTrips: currentTrips));
      }
    } catch (e) {
      emit(state.copyWith(status: TripStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> deleteTrip(String tripId) async {
    try {
      await _tripRepository.deleteTrip(tripId);
      final updatedTrips = state.allTrips.where((t) => t.id != tripId).toList();
      emit(state.copyWith(status: TripStatus.loaded, allTrips: updatedTrips));
    } catch (e) {
      emit(state.copyWith(status: TripStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> updateTripBasicInfo({
    required String tripId,
    String? title,
    DateTimeRange? dateRange,
    String? coverImageUrl,
    List<String>? tags,
    List<TripDestination>? destinations,
    TransportType? mainTransport,
  }) async {
    try {
      emit(state.copyWith(status: TripStatus.submitting));
      
      final currentTrip = state.allTrips.firstWhere((t) => t.id == tripId);
      
      final updatedTrip = currentTrip.copyWith(
        title: title,
        startDate: dateRange?.start,
        endDate: dateRange?.end,
        coverImageUrl: coverImageUrl,
        tags: tags,
        destinations: destinations,
        mainTransport: mainTransport,
      );

      await _tripRepository.updateTrip(updatedTrip);

      final currentTrips = List<Trip>.from(state.allTrips);
      final index = currentTrips.indexWhere((t) => t.id == tripId);
      if (index != -1) currentTrips[index] = updatedTrip;
      
      emit(state.copyWith(
        status: TripStatus.loaded,
        allTrips: currentTrips,
        selectedTrip: state.selectedTrip?.id == tripId ? updatedTrip : state.selectedTrip,
      ));

    } catch (e) {
      emit(state.copyWith(status: TripStatus.error, errorMessage: e.toString()));
    }
  }

  // CreateTripも修正: userIdを引数で渡す必要はなく内部取得でもいいが、
  // 呼び出し元で指定しているならそのままでもOK。一応安全策で残します。
  Future<void> createTrip({
    required String userId,
    required String title,
    required DateTimeRange dateRange,
    String? coverImageUrl,
    List<String>? tags,
    List<TripDestination>? destinations,
    TransportType? mainTransport,
  }) async {
    try {
      emit(state.copyWith(status: TripStatus.submitting));

      final tripId = const Uuid().v4();

      final newTrip = Trip(
        id: tripId,
        title: title,
        startDate: dateRange.start,
        endDate: dateRange.end,
        ownerId: userId,
        memberIds: [userId],
        createdAt: DateTime.now(),
        coverImageUrl: coverImageUrl,
        tags: tags,
        destinations: destinations ?? [],
        mainTransport: mainTransport ?? TransportType.transit,
      );

      await _tripRepository.addTrip(newTrip);

      final currentTrips = List<Trip>.from(state.allTrips);
      currentTrips.insert(0, newTrip); 
      
      emit(state.copyWith(status: TripStatus.loaded, allTrips: currentTrips));

    } catch (e) {
      emit(state.copyWith(status: TripStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> toggleCheckItem(String itemName) async {
    final trip = state.selectedTrip;
    if (trip == null) return;

    final currentList = List<ChecklistItem>.from(trip.checklist);
    final index = currentList.indexWhere((i) => i.name == itemName);
    
    if (index != -1) {
      final old = currentList[index];
      currentList[index] = ChecklistItem(name: old.name, isChecked: !old.isChecked);
      final updatedTrip = trip.copyWith(checklist: currentList);
      await _updateTripStateAndSave(updatedTrip);
    }
  }

  Future<void> addCheckItem(String name) async {
    final trip = state.selectedTrip;
    if (trip == null) return;
    if (trip.checklist.any((i) => i.name == name)) return;

    final currentList = List<ChecklistItem>.from(trip.checklist);
    currentList.add(ChecklistItem(name: name));

    final updatedTrip = trip.copyWith(checklist: currentList);
    await _updateTripStateAndSave(updatedTrip);
  }

  Future<void> deleteCheckItem(String name) async {
    final trip = state.selectedTrip;
    if (trip == null) return;

    final currentList = List<ChecklistItem>.from(trip.checklist);
    currentList.removeWhere((i) => i.name == name);

    final updatedTrip = trip.copyWith(checklist: currentList);
    await _updateTripStateAndSave(updatedTrip);
  }

  Future<void> loadChecklistPreset({required bool isInternational}) async {
    final trip = state.selectedTrip;
    if (trip == null) return;

    emit(state.copyWith(status: TripStatus.submitting));

    try {
      final currentList = List<ChecklistItem>.from(trip.checklist);
      final presetItems = isInternational ? ChecklistData.international : ChecklistData.domestic;

      for (var name in presetItems) {
        if (!currentList.any((c) => c.name == name)) {
          currentList.add(ChecklistItem(name: name));
        }
      }

      final updatedTrip = trip.copyWith(checklist: currentList);
      await _updateTripStateAndSave(updatedTrip);      

    } catch (e) {
      emit(state.copyWith(status: TripStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _updateTripStateAndSave(Trip updatedTrip) async {
    try {
      await _tripRepository.updateTrip(updatedTrip);

      final currentTrips = List<Trip>.from(state.allTrips);
      final index = currentTrips.indexWhere((t) => t.id == updatedTrip.id);
      
      if (index != -1) {
        currentTrips[index] = updatedTrip;
      }

      emit(state.copyWith(
        status: TripStatus.loaded,
        selectedTrip: updatedTrip,
        allTrips: currentTrips,
      ));
      
    } catch (e) {
      emit(state.copyWith(status: TripStatus.error, errorMessage: e.toString()));
    }
  }
  
  Future<bool> joinTripByCode(String userId, String tripCode) async {
    try {
      emit(state.copyWith(status: TripStatus.submitting));
      final cleanId = tripCode.trim();
      
      await _tripRepository.joinTrip(cleanId, userId);
      await loadMyTrips(); // userId引数なしで呼べるようになった
      
      return true;
    } catch (e) {
      emit(state.copyWith(status: TripStatus.error, errorMessage: 'Failed to join: ${e.toString()}'));
      return false;
    }
  }

  // ----------------------------------------------------------------
  // 2. 旅程詳細の管理
  // ----------------------------------------------------------------

  Future<void> selectTrip(String tripId) async {
    try {
      emit(state.copyWith(status: TripStatus.loading));
      
      // allTripsから探す
      Trip selectedTrip;
      try {
        selectedTrip = state.allTrips.firstWhere((t) => t.id == tripId);
      } catch (_) {
        // もしリストになければ（ダイレクトリンク等）、個別取得などの対応が必要だが
        // ここではエラーにするか再ロードを試みる
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final trips = await _tripRepository.fetchTrips(user.uid);
          selectedTrip = trips.firstWhere((t) => t.id == tripId);
        } else {
          throw Exception('User not logged in');
        }
      }
      
      final results = await Future.wait([
        _tripRepository.fetchFullSchedule(tripId),
        _tripRepository.fetchExpenses(tripId),
      ]);
      
      final items = results[0] as List<Object>;
      final expenses = results[1] as List<ExpenseItem>;

      emit(state.copyWith(
        status: TripStatus.loaded, 
        selectedTrip: selectedTrip, 
        scheduleItems: items,
        expenses: expenses,
      ));

      // ⚠️ 画面を開いた時にも通知を同期したければ、ここでも呼ぶ。
      // ただし二重予約は上書きされるだけなので問題なし。
      await _syncNotificationsWithoutState();

    } catch (e) {
      emit(state.copyWith(status: TripStatus.error, errorMessage: e.toString()));
    }
  }

  // ... (updateRouteItem, addOrUpdateScheduledItem, deleteScheduledItem は変更なし) ...
  Future<void> updateRouteItem(String tripId, RouteItem updatedRoute) async {
    try {
      emit(state.copyWith(status: TripStatus.submitting));
      final currentItems = List<Object>.from(state.scheduleItems);
      final oldRouteIndex = currentItems.indexWhere((i) => i is RouteItem && i.id == updatedRoute.id);
      
      RouteItem routeToSave = updatedRoute;

      if (oldRouteIndex != -1) {
        final oldRoute = currentItems[oldRouteIndex] as RouteItem;
        final isTypeChanged = oldRoute.transportType != updatedRoute.transportType;
        final hasCoords = updatedRoute.startLatitude != null && updatedRoute.endLatitude != null;
        
        if ((isTypeChanged || updatedRoute.polyline == null) && hasCoords) {
          final newRoute = await _routingService.getRouteInfo(
            start: LatLng(updatedRoute.startLatitude!, updatedRoute.startLongitude!),
            end: LatLng(updatedRoute.endLatitude!, updatedRoute.endLongitude!),
            type: updatedRoute.transportType,
          );
          final newDetail = StepDetail(durationMinutes: newRoute.durationMinutes, transportType: updatedRoute.transportType);
          routeToSave = updatedRoute.copyWith(polyline: newRoute.polyline, detailedSteps: [newDetail]);
        }
      }

      await _tripRepository.addRouteItem(tripId, routeToSave);
      if (oldRouteIndex != -1) currentItems[oldRouteIndex] = routeToSave;
      emit(state.copyWith(status: TripStatus.loaded, scheduleItems: currentItems));
    } catch (e) {
      emit(state.copyWith(status: TripStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> addOrUpdateScheduledItem(String tripId, ScheduledItem newItem) async {
    try {
      emit(state.copyWith(status: TripStatus.submitting));
      final currentScheduledItems = state.scheduleItems.whereType<ScheduledItem>().toList();
      final index = currentScheduledItems.indexWhere((i) => i.id == newItem.id);
      if (index != -1) {
        currentScheduledItems[index] = newItem;
      }else{
        currentScheduledItems.add(newItem);
      }
      await _recalculateAndSave(tripId: tripId, sortedScheduledItems: _sortScheduledItems(currentScheduledItems), itemToSave: newItem);
    } catch (e) {
      emit(state.copyWith(status: TripStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> deleteScheduledItem(String tripId, String itemId) async {
    try {
      emit(state.copyWith(status: TripStatus.submitting));
      final currentScheduledItems = state.scheduleItems.whereType<ScheduledItem>().toList();
      currentScheduledItems.removeWhere((i) => i.id == itemId);
      await _recalculateAndSave(tripId: tripId, sortedScheduledItems: _sortScheduledItems(currentScheduledItems), itemIdToDelete: itemId);
    } catch (e) {
      emit(state.copyWith(status: TripStatus.error, errorMessage: e.toString()));
    }
  }

  // ----------------------------------------------------------------
  // 3. AI機能 (createTripWithAI なども変更なし)
  // ----------------------------------------------------------------
  Future<Trip?> createTripWithAI({
    required String userId, required String title, required String destination,
    required DateTimeRange dateRange, required List<ScheduledItem> mustVisitItems,
    List<String> excludedPlaces = const [], List<DateTime> freeDates = const [],
    String tripStyle = 'Balanced', List<AccommodationRequest> accommodations = const [],
    String? startLocation, String? startTime, String? endLocation, String? endTime,
    TransportType transportType = TransportType.transit, bool autoSuggest = true,
  }) async {
    try {
      emit(state.copyWith(status: TripStatus.submitting));
      final mustVisitNames = mustVisitItems.map((i) => i.name).toList();
      
      final aiItems = await _geminiService.createInitialTripPlan(
        destination: destination, startDate: dateRange.start, endDate: dateRange.end,
        mustVisitPlaces: mustVisitNames, excludedPlaces: excludedPlaces, freeDates: freeDates,
        tripStyle: tripStyle, accommodations: accommodations,
        startLocation: startLocation, startTime: startTime, endLocation: endLocation, endTime: endTime,
        transportType: transportType.name, autoSuggest: autoSuggest,
      );

      final mergedItems = <ScheduledItem>[];
      for (var aiItem in aiItems) {
        final userItem = mustVisitItems.cast<ScheduledItem?>().firstWhere((u) => u!.name == aiItem.name, orElse: () => null);
        mergedItems.add(userItem != null ? aiItem.copyWith(durationMinutes: userItem.durationMinutes, notes: userItem.notes) : aiItem);
      }

      if (startLocation != null && startTime != null) {
        final timeParts = startTime.split(':');
        final startDateTime = DateTime(dateRange.start.year, dateRange.start.month, dateRange.start.day, int.parse(timeParts[0]), int.parse(timeParts[1]));
        mergedItems.removeWhere((i) => i.dayIndex == 0 && i.time.isBefore(startDateTime.add(const Duration(minutes: 15))));
        mergedItems.insert(0, ScheduledItem(id: '', dayIndex: 0, time: startDateTime, name: startLocation, category: ItemCategory.transport, durationMinutes: 0, isTimeFixed: true, notes: 'Start'));
      }
      if (endLocation != null) {
        final lastDayIndex = dateRange.end.difference(dateRange.start).inDays;
        mergedItems.add(ScheduledItem(id: '', dayIndex: lastDayIndex, time: dateRange.end, name: endLocation, category: ItemCategory.transport, durationMinutes: 0, notes: 'Goal'));
      }

      final tripId = const Uuid().v4();
      final newTrip = Trip(
        id: tripId, title: title, startDate: dateRange.start, endDate: dateRange.end,
        ownerId: userId, memberIds: [userId], createdAt: DateTime.now(),
        destinations: [TripDestination(name: destination, latitude: 0, longitude: 0)],
      );

      await _tripRepository.addTrip(newTrip);
      await addAIPlanToTrip(tripId: tripId, aiItems: mergedItems, defaultTransport: transportType);
      
      // ここで再取得してリスト更新
      await loadMyTrips(); 
      await selectTrip(tripId);
      return newTrip;
    } catch (e) {
      emit(state.copyWith(status: TripStatus.error, errorMessage: e.toString()));
      return null;
    }
  }

  // --- AI最適化: シミュレーション (修正) ---
  Future<List<ScheduledItem>> simulateAutoSchedule({
    required int dayIndex, required DateTime date,
    bool allowSuggestions = false, Set<String> lockedItemIds = const {},
  }) async {
    final currentDayItems = _getDayScheduledItems(dayIndex);
    if (currentDayItems.isEmpty) throw Exception('No items to optimize');

    final itemsForAI = currentDayItems.map((item) => lockedItemIds.contains(item.id) ? item.copyWith(isTimeFixed: true) : item).toList();
    final destinationName = state.selectedTrip?.destinations.firstOrNull?.name ?? 'Tourist Spot';

    final optimizedItems = await _geminiService.optimizeDailySchedule(
      currentItems: itemsForAI, date: date, destination: destinationName, allowSuggestions: allowSuggestions, dayIndex: dayIndex
    );

    final fixedItems = optimizedItems.map((i) => i.copyWith(dayIndex: dayIndex)).toList();
    fixedItems.sort((a, b) => a.time.compareTo(b.time));

    for (int i = 0; i < fixedItems.length - 1; i++) {
      final current = fixedItems[i];
      final next = fixedItems[i + 1];
      // ⚠️ 削除: if (current.latitude == null || next.latitude == null) continue;

      final existingRoute = _findExistingRoute(current, next);
      final currentEndTime = current.time.add(Duration(minutes: current.durationMinutes ?? 60));

      final route = await _calculateRouteSegment(
        startItem: current, nextItem: next, startTime: currentEndTime,
        existingRoute: existingRoute, defaultTransport: TransportType.transit,
      );

      if (!next.isTimeFixed) {
        fixedItems[i + 1] = next.copyWith(time: currentEndTime.add(Duration(minutes: route.durationMinutes)));
      }
    }
    return fixedItems;
  }

  // --- AI最適化: 保存 (修正) ---
  Future<void> saveOptimizedSchedule({
    required String tripId, required int dayIndex, required List<ScheduledItem> optimizedItems,
  }) async {
    try {
      emit(state.copyWith(status: TripStatus.submitting));

      final itemsWithIds = optimizedItems.map((i) => i.id.isEmpty ? i.copyWith(id: const Uuid().v4()) : i).toList();
      itemsWithIds.sort((a, b) => a.time.compareTo(b.time));

      final List<RouteItem> newRoutes = [];
      for (int i = 0; i < itemsWithIds.length - 1; i++) {
        final current = itemsWithIds[i];
        final next = itemsWithIds[i + 1];
        // ⚠️ 削除: if (current.latitude == null || next.latitude == null) continue;

        final currentEndTime = current.time.add(Duration(minutes: current.durationMinutes ?? 60));
        
        final route = await _calculateRouteSegment(
          startItem: current, nextItem: next, startTime: currentEndTime,
          defaultTransport: TransportType.transit, newRouteId: const Uuid().v4(),
        );
        newRoutes.add(route);
      }

      final routeIdsToDelete = state.scheduleItems.whereType<RouteItem>().where((r) => r.dayIndex == dayIndex).map((r) => r.id).toList();

      await _tripRepository.batchUpdateSchedule(
        tripId: tripId, itemsToAddOrUpdate: itemsWithIds, routeIdsToDelete: routeIdsToDelete, routesToAddOrUpdate: newRoutes,
      );
      await selectTrip(tripId);
    } catch (e) {
      emit(state.copyWith(status: TripStatus.error, errorMessage: e.toString()));
    }
  }

  // --- AI提案 (fetchSpotSuggestions は変更なし) ---
  Future<List<ScheduledItem>> fetchSpotSuggestions({required int dayIndex, required String userRequest, required int count}) async {
    final trip = state.selectedTrip;
    if (trip == null) throw Exception('No trip');
    
    final dayItems = _getDayScheduledItems(dayIndex);
    
    final lastItem = dayItems.isNotEmpty ? dayItems.last : null;
    return await _geminiService.suggestSpots(lastItem: lastItem, targetDate: trip.startDate.add(Duration(days: dayIndex)), destination: trip.destinations.firstOrNull?.name ?? 'Spot', count: count, userRequest: userRequest);
  }

  // --- addSuggestedSpot (変更なし) ---
  Future<void> addSuggestedSpot({required String tripId, required int dayIndex, required ScheduledItem suggestedItem}) async {
    try {
      emit(state.copyWith(status: TripStatus.submitting));
      final currentDayItems = _getDayScheduledItems(dayIndex);
      ScheduledItem? prevItem;
      ScheduledItem? nextItem;
      if (currentDayItems.isNotEmpty) {
        final last = currentDayItems.last;
        if (last.category == ItemCategory.accommodation && (last.durationMinutes ?? 0) > 360) {
          nextItem = last;
          if (currentDayItems.length > 1) prevItem = currentDayItems[currentDayItems.length - 2];
        } else {
          prevItem = last;
        }
      }
      final newItem = suggestedItem.copyWith(id: const Uuid().v4(), dayIndex: dayIndex);
      final List<ScheduledItem> itemsToSave = [newItem];
      final List<RouteItem> routesToSave = [];

      if (prevItem != null) {
        final prevEndTime = prevItem.time.add(Duration(minutes: prevItem.durationMinutes ?? 60));
        final route = await _calculateRouteSegment(
          startItem: prevItem, nextItem: newItem, startTime: prevEndTime,
          newRouteId: const Uuid().v4(), defaultTransport: TransportType.transit
        );
        itemsToSave[0] = newItem.copyWith(time: prevEndTime.add(Duration(minutes: route.durationMinutes)));
        routesToSave.add(route);
      } else {
        itemsToSave[0] = newItem.copyWith(time: state.selectedTrip!.startDate.add(Duration(days: dayIndex)).add(const Duration(hours: 10)));
      }

      if (nextItem != null) {
        RouteItem? existingRouteToNext;
        try {
          existingRouteToNext = state.scheduleItems.whereType<RouteItem>().firstWhere(
            (r) => r.destinationItemId == nextItem!.id,
          );
        } catch (_) {}

        final newEndTime = itemsToSave[0].time.add(Duration(minutes: newItem.durationMinutes ?? 60));
        final route = await _calculateRouteSegment(
          startItem: newItem, nextItem: nextItem, startTime: newEndTime,
          existingRoute: existingRouteToNext, newRouteId: const Uuid().v4(), defaultTransport: TransportType.transit
        );

        itemsToSave.add(nextItem.copyWith(time: newEndTime.add(Duration(minutes: route.durationMinutes))));
        routesToSave.add(route);
      }

      await _tripRepository.batchUpdateSchedule(
        tripId: tripId, itemsToAddOrUpdate: itemsToSave, routesToAddOrUpdate: routesToSave, routeIdsToDelete: [], 
      );
      await selectTrip(tripId);
    } catch (e) {
      emit(state.copyWith(status: TripStatus.error, errorMessage: e.toString()));
    }
  }

  // ==============================================================================
  // 🔔 通知ロジック (RouteItem & StepDetail 対応版)
  // ==============================================================================

  void syncNotifications(SettingsState settings) {
    if (!settings.isNotificationEnabled || state.selectedTrip == null) {
      _stopOngoingTimer();
      NotificationService().cancelOngoingNotification();
      return;
    }

    // 👇 修正: ScheduledItem だけでなく RouteItem も含める
    // (scheduleItems は Object のリストなので、型チェックして抽出)
    final allItems = <dynamic>[];
    for (var item in state.scheduleItems) {
      if (item is ScheduledItem || item is RouteItem) {
        allItems.add(item);
      }
    }

    // リマインダー予約
    if (settings.isReminderEnabled) {
      _scheduleReminders(allItems, settings.reminderMinutesBefore);
    }

    // 常時通知
    if (settings.isOngoingNotificationEnabled) {
      if (_ongoingTimer == null || !_ongoingTimer!.isActive) {
        _updateOngoingNotification();
        // 1分ごとに更新
        _ongoingTimer = Timer.periodic(const Duration(minutes: 1), (_) {
          _updateOngoingNotification();
        });
      }
    } else {
      _stopOngoingTimer();
      NotificationService().cancelOngoingNotification();
    }
  }

  // 👇 修正: RouteItemも通知対象にする
  Future<void> _scheduleReminders(List<dynamic> items, int minutesBefore) async {
    for (var item in items) {
      // 共通のフィールドを取り出す
      DateTime? time;
      String title = '';
      String body = '';
      int id = 0;

      if (item is ScheduledItem) {
        time = item.time;
        title = 'Soon: ${item.name}';
        body = 'Plan starts in $minutesBefore min';
        id = item.id.hashCode;
      } else if (item is RouteItem) {
        time = item.time;
        // 移動手段のアイコンなどを出す
        final transport = item.transportType.name.toUpperCase();
        title = 'Time to move! ($transport)';
        body = 'Moving starts in $minutesBefore min. Duration: ${item.durationMinutes} min';
        id = item.id.hashCode;
      }

      if (time != null) {
        final scheduledTime = time.subtract(Duration(minutes: minutesBefore));
        if (scheduledTime.isAfter(DateTime.now())) {
          await NotificationService().scheduleNotification(
            id: id,
            title: title,
            body: body,
            scheduledDate: scheduledTime,
          );
        }
      }
    }
  }


  // 👇 移動中は「今のステップ」、滞在中は「次の予定」を出す賢い通知ロジック
  Future<void> _updateOngoingNotification() async {
    final trip = state.selectedTrip;
    
    // ScheduledItem と RouteItem をマージ
    final allItems = <dynamic>[];
    for (var item in state.scheduleItems) {
      if (item is ScheduledItem || item is RouteItem) {
        allItems.add(item);
      }
    }

    if (trip == null || allItems.isEmpty) return;

    final now = DateTime.now();
    // 旅行期間外ならスキップ
    if (now.isBefore(trip.startDate) || now.isAfter(trip.endDate.add(const Duration(days: 1)))) return;

    // 時間順にソート
    allItems.sort((a, b) {
      final timeA = (a is ScheduledItem) ? a.time : (a as RouteItem).time;
      final timeB = (b is ScheduledItem) ? b.time : (b as RouteItem).time;
      return timeA.compareTo(timeB);
    });

    String title = 'Travel Mode Active';
    String body = 'No upcoming plans';
    String plainTitle = 'Travel Mode Active';
    String plainBody = 'No upcoming plans';

    dynamic currentItem;
    dynamic nextItem;

    // ■ 1. 現在地と次の予定を特定
    for (var i = 0; i < allItems.length; i++) {
      final item = allItems[i];
      DateTime startTime;
      int duration = 0;

      if (item is ScheduledItem) {
        startTime = item.time;
        duration = item.durationMinutes ?? 60;
      } else if (item is RouteItem) {
        startTime = item.time;
        duration = item.durationMinutes;
      } else {
        continue;
      }

      final endTime = startTime.add(Duration(minutes: duration));

      // 今が期間内なら Current
      if (now.isAfter(startTime) && now.isBefore(endTime)) {
        currentItem = item;
        if (i + 1 < allItems.length) nextItem = allItems[i + 1];
        break;
      }
      
      // まだ始まっていない直近の予定なら Next
      if (now.isBefore(startTime)) {
        nextItem = item;
        break;
      }
    }

    // ■ 2. 表示内容の生成 (ユーザー要望に合わせて分岐)

    // A. 移動中 (RouteItem) の場合
    if (currentItem is RouteItem) {
      final route = currentItem;
      
      // --- メイン (Title): Move to [目的地] ---
      String destinationName = 'Next Spot';
      try {
        final destItem = state.scheduleItems
            .whereType<ScheduledItem>()
            .firstWhere((item) => item.id == route.destinationItemId);
        destinationName = destItem.name;
      } catch (_) {}

      // アイコン決定
      String mainIcon = route.transportType.stringIcon;

      title = 'Move to <b>$destinationName</b> ($mainIcon)';
      plainTitle = 'Move to $destinationName ($mainIcon)';

      // --- 下のところ (Body): Step Detail (開始 - 終了) ---
      String stepInfo = 'Moving...';
      
      if (route.detailedSteps.isNotEmpty) {
        // 今どのステップにいるか計算
        final timeSinceStart = now.difference(route.time).inMinutes;
        int accumMinutes = 0;
        StepDetail? currentStep;
        int stepStartMin = 0; // そのステップがルート開始から何分後に始まるか

        for (var step in route.detailedSteps) {
          final stepDuration = step.durationMinutes as int;
          if (timeSinceStart < accumMinutes + stepDuration) {
            currentStep = step;
            stepStartMin = accumMinutes;
            break;
          }
          accumMinutes += stepDuration;
        }

        if (currentStep != null) {
          // ステップの開始・終了時刻を計算
          final stepStartTime = route.time.add(Duration(minutes: stepStartMin));
          final stepEndTime = stepStartTime.add(Duration(minutes: currentStep.durationMinutes));
          
          final startStr = "${stepStartTime.hour}:${stepStartTime.minute.toString().padLeft(2,'0')}";
          final endStr = "${stepEndTime.hour}:${stepEndTime.minute.toString().padLeft(2,'0')}";
          
          String stepIcon = currentStep.transportType.stringIcon;
          
          // 表示: "🚃 TRAIN (10:00 - 10:20)"
          stepInfo = '$stepIcon ($startStr - $endStr)';
        } else {
           // 計算誤差でステップ外にはみ出た場合
           stepInfo = 'Arriving soon...';
        }
      } else {
        // 詳細ステップがない場合 (直線移動など)
        final endT = route.time.add(Duration(minutes: route.durationMinutes));
        final endStr = "${endT.hour}:${endT.minute.toString().padLeft(2,'0')}";
        stepInfo = 'Until $endStr';
      }

      body = stepInfo;
      plainBody = stepInfo;
    } 
    // B. 滞在中 (ScheduledItem) の場合
    else if (currentItem is ScheduledItem) {
      // --- メイン (Title): Now at [場所] ---
      title = 'Now at <b>${currentItem.name}</b>';
      plainTitle = 'Now at ${currentItem.name}';

      // --- 下のところ (Body): Next [次の予定] ---
      if (nextItem != null) {
        DateTime nextTime;
        String nextName = '';

        if (nextItem is RouteItem) {
           // 次が移動なら「Move to 〇〇」
           final route = nextItem as RouteItem;
           nextTime = route.time;
           
           String destName = 'Next Spot';
           try {
             final d = state.scheduleItems
                .whereType<ScheduledItem>()
                .firstWhere((i) => i.id == route.destinationItemId);
             destName = d.name;
           } catch (_) {}
           
           String icon = route.transportType.stringIcon;
           nextName = 'Move to $destName ($icon)';
        } else {
           // 次が滞在ならそのまま場所名
           final sch = nextItem as ScheduledItem;
           nextTime = sch.time;
           nextName = sch.name;
        }

        final timeStr = "${nextTime.hour}:${nextTime.minute.toString().padLeft(2,'0')}";
        // 色をつけて強調
        body = 'Next: <b>$nextName</b> ($timeStr)';
        plainBody = 'Next: $nextName ($timeStr)';
      } else {
        body = 'End of the day';
        plainBody = 'End of the day';
      }
    } 
    // C. 予定と予定の隙間 (Free Time)
    else if (nextItem != null) {
      title = 'Free Time / Waiting';
      plainTitle = 'Free Time / Waiting';
      
      // 次の予定を表示
      final nextTime = (nextItem is ScheduledItem) ? nextItem.time : (nextItem as RouteItem).time;
      final timeStr = "${nextTime.hour}:${nextTime.minute.toString().padLeft(2,'0')}";
      String nextName = (nextItem is ScheduledItem) ? nextItem.name : 'Move';
      
      body = 'Next: $nextName ($timeStr)';
      plainBody = 'Next: $nextName ($timeStr)';
    }

    // 通知更新実行
    await NotificationService().showOngoingNotification(
      currentStatus: title,
      nextPlan: body,
      plainStatus: plainTitle,
      plainPlan: plainBody,
    );
  }
  
  
  // 👇 新規追加: Stateなしで設定を直接読んで通知をセットアップ
  Future<void> _syncNotificationsWithoutState() async {
    final prefs = await SharedPreferences.getInstance();
    
    final isNotifyEnabled = prefs.getBool('isNotificationEnabled') ?? false;
    final isOngoingEnabled = prefs.getBool('isOngoingNotificationEnabled') ?? true;
    final isReminderEnabled = prefs.getBool('isReminderEnabled') ?? true;
    final minutes = prefs.getInt('reminderMinutesBefore') ?? 15;

    final dummySettings = SettingsState(
      isNotificationEnabled: isNotifyEnabled,
      isOngoingNotificationEnabled: isOngoingEnabled,
      isReminderEnabled: isReminderEnabled,
      reminderMinutesBefore: minutes,
    );

    syncNotifications(dummySettings);
  }

  // 👇 新規追加: 起動時にアクティブな旅行を探して通知セット
  Future<void> _checkAndSetupActiveTripNotification(List<Trip> trips) async {
    final now = DateTime.now();
    
    Trip? activeTrip;
    try {
      activeTrip = trips.firstWhere((trip) {
        final start = DateTime(trip.startDate.year, trip.startDate.month, trip.startDate.day);
        final end = DateTime(trip.endDate.year, trip.endDate.month, trip.endDate.day, 23, 59, 59);
        return now.isAfter(start) && now.isBefore(end);
      });
    } catch (_) {
      activeTrip = null;
    }

    if (activeTrip != null) {
      print('🚀 Active trip detected: ${activeTrip.title}');
      try {
        final scheduleItems = await _tripRepository.fetchFullSchedule(activeTrip.id);
        
        // 画面データとしてセットしておく (これで次回開いた時に早い)
        emit(state.copyWith(
          selectedTrip: activeTrip,
          scheduleItems: scheduleItems as List<Object>,
        ));

        // 設定を読んで通知セット
        await _syncNotificationsWithoutState();
        
      } catch (e) {
        print('Background schedule fetch error: $e');
      }
    } else {
      NotificationService().cancelOngoingNotification();
    }
  }


  void _stopOngoingTimer() {
    _ongoingTimer?.cancel();
    _ongoingTimer = null;
  }
  
  @override
  Future<void> close() {
    _stopOngoingTimer();
    _authSubscription?.cancel();
    return super.close();
  }

  // ----------------------------------------------------------------
  // 4. Private Helpers: 共通ロジック
  // ----------------------------------------------------------------

  List<ScheduledItem> _getDayScheduledItems(int dayIndex) {
    return state.scheduleItems
        .whereType<ScheduledItem>()
        .where((i) => i.dayIndex == dayIndex)
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
  }

 Future<RouteItem> _calculateRouteSegment({
    required ScheduledItem startItem,
    required ScheduledItem nextItem,
    required DateTime startTime, 
    TransportType defaultTransport = TransportType.transit,
    RouteItem? existingRoute, 
    String? newRouteId, 
  }) async {
    // 1. 座標があるかチェック
    final hasCoords = startItem.latitude != null && startItem.longitude != null &&
                      nextItem.latitude != null && nextItem.longitude != null;

    // 🅰️ 座標がない場合: 「時間の隙間」をそのまま移動時間とする
    if (!hasCoords) {
      // 次の予定の開始時刻との差分 (マイナスなら0)
      int gapMinutes = nextItem.time.difference(startTime).inMinutes;
      if (gapMinutes < 0) gapMinutes = 0;

      // 既存の移動手段があれば引き継ぐ
      final type = existingRoute?.transportType ?? defaultTransport;

      return RouteItem(
        id: existingRoute?.id ?? newRouteId ?? const Uuid().v4(),
        dayIndex: startItem.dayIndex,
        time: startTime,
        destinationItemId: nextItem.id,
        durationMinutes: gapMinutes, // 隙間時間 = 移動時間
        transportType: type,
        polyline: null, // 地図には描けない
        detailedSteps: [], // 詳細なし
        startLatitude: null,
        startLongitude: null,
        endLatitude: null,
        endLongitude: null,
        cost: existingRoute?.cost ?? 0,
        externalLink: null,
      );
    }

    // 🅱️ 座標がある場合: 通常のルート計算 (API利用)
    final distance = const Distance().as(LengthUnit.Meter, 
        LatLng(startItem.latitude!, startItem.longitude!), 
        LatLng(nextItem.latitude!, nextItem.longitude!)
    );
    TransportType type = existingRoute?.transportType ?? (distance < 800 ? TransportType.walk : defaultTransport);

    // 再利用判定
    if (existingRoute != null) {
      final isSameStart = (existingRoute.startLatitude! - startItem.latitude!).abs() < 0.0001 &&
                          (existingRoute.startLongitude! - startItem.longitude!).abs() < 0.0001;
      final isSameEnd   = (existingRoute.endLatitude! - nextItem.latitude!).abs() < 0.0001 &&
                          (existingRoute.endLongitude! - nextItem.longitude!).abs() < 0.0001;
      final isSameType  = existingRoute.transportType == type;
      
      if (isSameStart && isSameEnd && isSameType && existingRoute.polyline != null) {
        return existingRoute.copyWith(
          id: newRouteId ?? const Uuid().v4(),
          dayIndex: startItem.dayIndex,
          time: startTime,
          destinationItemId: nextItem.id,
        );
      }
    }

    // APIコール
    final result = await _routingService.getRouteInfo(
      start: LatLng(startItem.latitude!, startItem.longitude!),
      end: LatLng(nextItem.latitude!, nextItem.longitude!),
      type: type,
    );

    String? polyline = result.polyline;
    int duration = result.durationMinutes;
    List<StepDetail> steps = result.steps;
    String? externalLink = result.externalLink;

    if (existingRoute != null && existingRoute.transportType == type && type == TransportType.transit) {
       duration = existingRoute.durationMinutes;
    }
    if (_routingService.isPublicTransport(type)) {
       if (duration < 20 && duration == result.durationMinutes) duration += 15;
    }
    if (duration < 1) duration = 1;

    return RouteItem(
      id: existingRoute?.id ?? newRouteId ?? const Uuid().v4(),
      dayIndex: startItem.dayIndex,
      time: startTime,
      destinationItemId: nextItem.id,
      durationMinutes: duration,
      transportType: type,
      polyline: polyline,
      detailedSteps: steps,
      startLatitude: startItem.latitude,
      startLongitude: startItem.longitude,
      endLatitude: nextItem.latitude,
      endLongitude: nextItem.longitude,
      cost: existingRoute?.cost ?? 0,
      externalLink: externalLink,
    );
  }

  // 🔥 修正: ループ内の「座標nullならcontinue」を削除
  Future<void> _recalculateAndSave({
    required String tripId,
    required List<ScheduledItem> sortedScheduledItems,
    ScheduledItem? itemToSave,
    String? itemIdToDelete
  }) async {
    final allExistingRoutes = state.scheduleItems.whereType<RouteItem>().toList();
    final routeMap = {for (var r in allExistingRoutes) r.destinationItemId: r};
    final List<RouteItem> routesToSave = [];
    final Set<String> validRouteIds = {};

    for (int i = 0; i < sortedScheduledItems.length - 1; i++) {
      final current = sortedScheduledItems[i];
      final next = sortedScheduledItems[i + 1];
      
      // ⚠️ 削除: if (current.latitude == null || next.latitude == null) continue;
      // これを消すことで、座標なしでも _calculateRouteSegment が呼ばれる

      final prevEndTime = current.time.add(Duration(minutes: current.durationMinutes ?? 60));
      final existing = routeMap[next.id]; 

      final route = await _calculateRouteSegment(
        startItem: current, 
        nextItem: next, 
        startTime: prevEndTime,
        existingRoute: existing, 
      );
      
      routesToSave.add(route);
      validRouteIds.add(route.id);
    }

    final routeIdsToDelete = allExistingRoutes.map((r) => r.id).where((id) => !validRouteIds.contains(id)).toList();

    await _tripRepository.batchUpdateSchedule(
      tripId: tripId, 
      itemsToAddOrUpdate: itemToSave != null ? [itemToSave] : null,
      itemIdsToDelete: itemIdToDelete != null ? [itemIdToDelete] : null,
      routesToAddOrUpdate: routesToSave, 
      routeIdsToDelete: routeIdsToDelete,
    );

    await selectTrip(tripId);
  }

  // --- addAIPlanToTrip (修正) ---
  Future<void> addAIPlanToTrip({required String tripId, required List<ScheduledItem> aiItems, TransportType defaultTransport = TransportType.transit}) async {
    try {
      emit(state.copyWith(status: TripStatus.submitting));
      aiItems.sort((a, b) { final d = a.dayIndex.compareTo(b.dayIndex); return d != 0 ? d : a.time.compareTo(b.time); });
      
      final optimizedItems = List<ScheduledItem>.from(aiItems);
      final List<RouteItem?> routesToAdd = [];
      
      for (int i = 0; i < optimizedItems.length - 1; i++) {
        final current = optimizedItems[i];
        final next = optimizedItems[i + 1];
        
        // 日付またぎ以外はルートを作る (座標チェック削除)
        if (current.dayIndex != next.dayIndex) {
           routesToAdd.add(null); continue; 
        }

        final currentEndTime = current.time.add(Duration(minutes: current.durationMinutes ?? 60));
        
        final route = await _calculateRouteSegment(
          startItem: current, nextItem: next, startTime: currentEndTime,
          defaultTransport: defaultTransport, newRouteId: const Uuid().v4()
        );

        optimizedItems[i + 1] = next.copyWith(time: currentEndTime.add(Duration(minutes: route.durationMinutes))); 
        routesToAdd.add(route);
      }
      await _tripRepository.batchAddAIPlan(tripId: tripId, spots: optimizedItems, routes: routesToAdd);
      
      await loadMyTrips();
      await selectTrip(tripId);
    } catch (e) {
      emit(state.copyWith(status: TripStatus.error, errorMessage: e.toString()));
    }
  }

  List<ScheduledItem> _sortScheduledItems(List<ScheduledItem> items) {
    items.sort((a, b) => a.time.compareTo(b.time));
    return items;
  }
  
  RouteItem? _findExistingRoute(ScheduledItem start, ScheduledItem end) {
    try {
      return state.scheduleItems.whereType<RouteItem>().firstWhere((r) => 
        (r.startLatitude! - start.latitude!).abs() < 0.0001 &&
        (r.startLongitude! - start.longitude!).abs() < 0.0001 &&
        (r.endLatitude! - end.latitude!).abs() < 0.0001 &&
        (r.endLongitude! - end.longitude!).abs() < 0.0001
      );
    } catch (_) { return null; }
  }

  // 💰 支出の追加・更新
  Future<void> addOrUpdateExpense(String tripId, ExpenseItem expense) async {
    try {
      emit(state.copyWith(status: TripStatus.submitting));
      final expenseToSave = expense.id.isEmpty 
          ? ExpenseItem(
              id: const Uuid().v4(), 
              title: expense.title, 
              amount: expense.amount, 
              currency: expense.currency, 
              payerId: expense.payerId, 
              payeeIds: expense.payeeIds, 
              splitMode: expense.splitMode, 
              customAmounts: expense.customAmounts, 
              date: expense.date, 
              category: expense.category, 
              linkedScheduleId: expense.linkedScheduleId
            ) 
          : expense;

      await _tripRepository.addOrUpdateExpense(tripId, expenseToSave);

      final currentExpenses = List<ExpenseItem>.from(state.expenses);
      final index = currentExpenses.indexWhere((e) => e.id == expenseToSave.id);
      if (index != -1) {
        currentExpenses[index] = expenseToSave;
      } else {
        currentExpenses.insert(0, expenseToSave);
        currentExpenses.sort((a, b) => b.date.compareTo(a.date));
      }
      emit(state.copyWith(status: TripStatus.loaded, expenses: currentExpenses));
    } catch (e) {
      emit(state.copyWith(status: TripStatus.error, errorMessage: e.toString()));
    }
  }

  // 💰 支出の削除
  Future<void> deleteExpense(String tripId, String expenseId) async {
    try {
      emit(state.copyWith(status: TripStatus.submitting));
      await _tripRepository.deleteExpense(tripId, expenseId);
      final currentExpenses = List<ExpenseItem>.from(state.expenses);
      currentExpenses.removeWhere((e) => e.id == expenseId);
      emit(state.copyWith(status: TripStatus.loaded, expenses: currentExpenses));
    } catch (e) {
      emit(state.copyWith(status: TripStatus.error, errorMessage: e.toString()));
    }
  } 
}