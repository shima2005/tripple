import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:new_tripple/models/expense_item.dart';
import 'package:new_tripple/models/step_detail.dart';
import 'package:new_tripple/models/trip.dart';
import 'package:new_tripple/models/schedule_item.dart';
import 'package:new_tripple/models/route_item.dart';
import 'trip_state.dart'; 
import 'package:new_tripple/features/trip/data/trip_repository.dart'; 
import 'package:new_tripple/models/enums.dart';
import 'package:new_tripple/services/routing_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:new_tripple/services/gemini_service.dart'; 
import 'package:uuid/uuid.dart';
import 'package:new_tripple/core/constants/checklist_data.dart'; 
import 'package:new_tripple/features/settings/domain/settings_state.dart';
import 'package:new_tripple/services/notification_service.dart';

class TripCubit extends Cubit<TripState> {
  final TripRepository _tripRepository;
  
  Timer? _ongoingTimer;//常時通知用タイマー

  final _geminiService = GeminiService();
  final _routingService = RoutingService();

  TripCubit({required TripRepository tripRepository})
      : _tripRepository = tripRepository,
        super(const TripState());

  // ----------------------------------------------------------------
  // 1. 旅行リストの管理
  // ----------------------------------------------------------------

  Future<void> loadMyTrips(String userId) async {
    try {
      emit(state.copyWith(status: TripStatus.loading));
      final trips = await _tripRepository.fetchTrips(userId);

      final samples = await _tripRepository.fetchTrips("sample");
      trips.addAll(samples);

      emit(state.copyWith(status: TripStatus.loaded, allTrips: trips));
    } catch (e) {
      emit(state.copyWith(status: TripStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> addTrip(Trip newTrip) async {
    try {
      emit(state.copyWith(status: TripStatus.submitting));
      await _tripRepository.addTrip(newTrip);
      
      final currentTrips = List<Trip>.from(state.allTrips);
      final index = currentTrips.indexWhere((t) => t.id == newTrip.id);

      if (index != -1) {
        currentTrips[index] = newTrip;
        Trip? updatedSelectedTrip = state.selectedTrip;
        if (state.selectedTrip?.id == newTrip.id) updatedSelectedTrip = newTrip;
        emit(state.copyWith(status: TripStatus.loaded, allTrips: currentTrips, selectedTrip: updatedSelectedTrip));
      } else {
        await loadMyTrips(newTrip.ownerId);
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
      
      // 現在のTripを取得 (state.selectedTrip または allTrips から検索)
      final currentTrip = state.allTrips.firstWhere((t) => t.id == tripId);
      
      // copyWithで更新
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

      // State更新
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

      // ID生成 (UUID)
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
        destinations: destinations ?? [], // nullなら空リスト
        mainTransport: mainTransport ?? TransportType.transit,
      );

      // 保存
      await _tripRepository.addTrip(newTrip);

      // リスト更新
      final currentTrips = List<Trip>.from(state.allTrips);
      currentTrips.insert(0, newTrip); // 先頭に追加
      
      // 作成したTripを選択状態にするかどうかはUX次第（今回はしない）
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
      
      // 👇 修正: 共通メソッドで state 全体を正しく更新
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
      // 既存リストとマージ (重複しないものだけ追加)
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
      // 1. まずFirestoreに保存
      await _tripRepository.updateTrip(updatedTrip);

      // 2. allTrips の中の該当Tripも差し替える
      final currentTrips = List<Trip>.from(state.allTrips);
      final index = currentTrips.indexWhere((t) => t.id == updatedTrip.id);
      
      if (index != -1) {
        currentTrips[index] = updatedTrip;
      }

      // 3. selectedTrip と allTrips 両方を更新して emit
      // これで画面が確実にリビルドされる
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
      
      // トリムして余計なスペース削除
      final cleanId = tripCode.trim();
      
      await _tripRepository.joinTrip(cleanId, userId);
      
      // 成功したらリストを更新して表示
      await loadMyTrips(userId);
      
      return true; // 成功
    } catch (e) {
      emit(state.copyWith(status: TripStatus.error, errorMessage: 'Failed to join: ${e.toString()}'));
      return false; // 失敗
    }
  }

  // ----------------------------------------------------------------
  // 2. 旅程詳細の管理
  // ----------------------------------------------------------------

  Future<void> selectTrip(String tripId) async {
    try {
      emit(state.copyWith(status: TripStatus.loading));
      
      final selectedTrip = state.allTrips.firstWhere((t) => t.id == tripId);
      
      // 並行してスケジュールと支出を取得
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
        expenses: expenses, // 👈 Stateにセット
      ));
    } catch (e) {
      emit(state.copyWith(status: TripStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> updateRouteItem(String tripId, RouteItem updatedRoute) async {
    try {
      emit(state.copyWith(status: TripStatus.submitting));
      // RouteItem単体の更新は手動操作用なので、共通ロジックは使わず直接APIを叩くか判断する
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
  // 3. AI機能
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
      
      final allTrips = await _tripRepository.fetchTrips(userId);
      emit(state.copyWith(status: TripStatus.loaded, allTrips: allTrips));
      await selectTrip(tripId);
      return newTrip;
    } catch (e) {
      emit(state.copyWith(status: TripStatus.error, errorMessage: e.toString()));
      return null;
    }
  }

  // --- AI最適化: シミュレーション ---
  Future<List<ScheduledItem>> simulateAutoSchedule({
    required int dayIndex, required DateTime date,
    bool allowSuggestions = false, Set<String> lockedItemIds = const {},
  }) async {
    // ♻️ Helper利用
    final currentDayItems = _getDayScheduledItems(dayIndex);
    if (currentDayItems.isEmpty) throw Exception('No items to optimize');

    final itemsForAI = currentDayItems.map((item) => lockedItemIds.contains(item.id) ? item.copyWith(isTimeFixed: true) : item).toList();
    final destinationName = state.selectedTrip?.destinations.firstOrNull?.name ?? 'Tourist Spot';

    final optimizedItems = await _geminiService.optimizeDailySchedule(
      currentItems: itemsForAI, date: date, destination: destinationName, allowSuggestions: allowSuggestions, dayIndex: dayIndex
    );

    final fixedItems = optimizedItems.map((i) => i.copyWith(dayIndex: dayIndex)).toList();
    fixedItems.sort((a, b) => a.time.compareTo(b.time));

    // ★共通メソッドを使用
    for (int i = 0; i < fixedItems.length - 1; i++) {
      final current = fixedItems[i];
      final next = fixedItems[i + 1];
      if (current.latitude == null || next.latitude == null) continue;

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

  // --- AI最適化: 保存 ---
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
        if (current.latitude == null || next.latitude == null) continue;

        // ★共通メソッドを使用
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

  // --- AI提案: 取得 & 追加 ---
  Future<List<ScheduledItem>> fetchSpotSuggestions({required int dayIndex, required String userRequest, required int count}) async {
    final trip = state.selectedTrip;
    if (trip == null) throw Exception('No trip');
    
    // ♻️ Helper利用
    final dayItems = _getDayScheduledItems(dayIndex);
    
    final lastItem = dayItems.isNotEmpty ? dayItems.last : null;
    return await _geminiService.suggestSpots(lastItem: lastItem, targetDate: trip.startDate.add(Duration(days: dayIndex)), destination: trip.destinations.firstOrNull?.name ?? 'Spot', count: count, userRequest: userRequest);
  }

  Future<void> addSuggestedSpot({required String tripId, required int dayIndex, required ScheduledItem suggestedItem}) async {
    try {
      emit(state.copyWith(status: TripStatus.submitting));
      
      final currentDayItems = _getDayScheduledItems(dayIndex);
      
      ScheduledItem? prevItem;
      ScheduledItem? nextItem;
      
      if (currentDayItems.isNotEmpty) {
        final last = currentDayItems.last;
        // 最後のアイテムが長時間滞在(宿泊など)の場合の挿入位置調整ロジック（既存のまま）
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
      // final List<String> routeIdsToDelete = []; // 🗑️ 削除リストは不要になるので削除！

      // A. 前との接続 (Prev -> New)
      // これは常に新しい区間なので、新規IDで作成してOK
      if (prevItem != null) {
        final prevEndTime = prevItem.time.add(Duration(minutes: prevItem.durationMinutes ?? 60));
        
        final route = await _calculateRouteSegment(
          startItem: prevItem, nextItem: newItem, startTime: prevEndTime,
          newRouteId: const Uuid().v4(), defaultTransport: TransportType.transit
        );
        
        itemsToSave[0] = newItem.copyWith(time: prevEndTime.add(Duration(minutes: route.durationMinutes)));
        routesToSave.add(route);
      } else {
        // 先頭に追加される場合
        itemsToSave[0] = newItem.copyWith(time: state.selectedTrip!.startDate.add(Duration(days: dayIndex)).add(const Duration(hours: 10)));
      }

      // B. 後ろとの接続 (New -> Next)
      // ⚠️ ここが修正ポイント！
      if (nextItem != null) {
        // 1. 既存のルート (Prev -> Next だったもの) を探す
        RouteItem? existingRouteToNext;
        try {
          existingRouteToNext = state.scheduleItems.whereType<RouteItem>().firstWhere(
            (r) => r.destinationItemId == nextItem!.id,
          );
        } catch (_) {
          // 見つからない場合（先頭挿入時など）はnullのまま
        }

        final newEndTime = itemsToSave[0].time.add(Duration(minutes: newItem.durationMinutes ?? 60));
        
        // 2. calculateRouteSegment に existingRoute を渡す！
        // これにより、IDが再利用され、Firestore上では「削除＆新規」ではなく「更新」として扱われる
        final route = await _calculateRouteSegment(
          startItem: newItem, 
          nextItem: nextItem, 
          startTime: newEndTime,
          existingRoute: existingRouteToNext, // 👈 重要：IDを引き継ぐ
          newRouteId: const Uuid().v4(),      // 引き継げない場合のみ新規ID
          defaultTransport: TransportType.transit
        );

        itemsToSave.add(nextItem.copyWith(time: newEndTime.add(Duration(minutes: route.durationMinutes))));
        routesToSave.add(route);

        // 3. 以前の「古いルート削除」処理は削除する
        // routeIdsToDelete.add(...) ← これを消す
      }

      // batchUpdateSchedule の呼び出し（routeIdsToDelete は空でOK）
      await _tripRepository.batchUpdateSchedule(
        tripId: tripId, 
        itemsToAddOrUpdate: itemsToSave, 
        routesToAddOrUpdate: routesToSave, 
        routeIdsToDelete: [], // 空リストを渡す
      );
      
      await selectTrip(tripId);
    } catch (e) {
      emit(state.copyWith(status: TripStatus.error, errorMessage: e.toString()));
    }
  }

  // ==============================================================================
  // 🔔 通知ロジック (ここから追加！)
  // ==============================================================================

  /// 設定とスケジュールを元に通知を同期する
  void syncNotifications(SettingsState settings) {
    // 1. マスター権限がない、またはトリップ未選択なら全キャンセルして終了
    if (!settings.isNotificationEnabled || state.selectedTrip == null) {
      _stopOngoingTimer();
      NotificationService().cancelOngoingNotification();
      // 本当は cancelAllReminders() もしたいが、今回は上書き予約で対応
      return;
    }

    final items = state.scheduleItems.whereType<ScheduledItem>().toList();

    // 2. リマインダー予約
    if (settings.isReminderEnabled) {
      _scheduleReminders(items, settings.reminderMinutesBefore);
    }

    // 3. 常時通知 (トラベルモード)
    if (settings.isOngoingNotificationEnabled) {
      // タイマーが動いてなければ開始
      if (_ongoingTimer == null || !_ongoingTimer!.isActive) {
        // 即時実行
        _updateOngoingNotification();
        // 以降、1分ごとに更新 (現在地や状況が変わるため)
        _ongoingTimer = Timer.periodic(const Duration(minutes: 1), (_) {
          _updateOngoingNotification();
        });
      }
    } else {
      _stopOngoingTimer();
      NotificationService().cancelOngoingNotification();
    }
  }

  /// 全てのスケジュールに対してリマインダーをセット
  Future<void> _scheduleReminders(List<ScheduledItem> items, int minutesBefore) async {
    for (var item in items) {
      // ID生成 (UUIDのハッシュコードを使う簡易実装)
      final notificationId = item.id.hashCode;
      
      // 通知時刻の計算
      final scheduledTime = item.time.subtract(Duration(minutes: minutesBefore));

      // 過去の時間は無視 (NotificationService側でも弾いているが念のため)
      if (scheduledTime.isAfter(DateTime.now())) {
        await NotificationService().scheduleNotification(
          id: notificationId,
          title: 'Soon: ${item.name}',
          body: 'Plan starts in $minutesBefore min at ${item.time.hour}:${item.time.minute.toString().padLeft(2,'0')}',
          scheduledDate: scheduledTime,
        );
      }
    }
  }

  /// 現在時刻に基づいて常時通知の内容を更新
  Future<void> _updateOngoingNotification() async {
    final trip = state.selectedTrip;
    final items = state.scheduleItems.whereType<ScheduledItem>().toList();
    if (trip == null || items.isEmpty) return;

    final now = DateTime.now();

    // 旅行期間外なら表示しない (または "Trip Finished" と出す)
    if (now.isBefore(trip.startDate) || now.isAfter(trip.endDate.add(const Duration(days: 1)))) {
       // 旅行前/後の処理... 今回はスキップ
       return;
    }

    // A. 現在進行中の予定を探す (開始時間 ~ +1時間以内 と仮定)
    ScheduledItem? currentItem;
    ScheduledItem? nextItem;

    // ソート (念のため)
    items.sort((a, b) => a.time.compareTo(b.time));

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final diff = now.difference(item.time).inMinutes;

      // 開始済みで、開始から60分以内なら「今ここにいる」とみなす簡易ロジック
      // (本来は item.duration を持つべきだが、今回は簡易実装)
      if (diff >= 0 && diff < 60) {
        currentItem = item;
        // 次の予定
        if (i + 1 < items.length) nextItem = items[i + 1];
        break;
      }
      
      // まだ始まっていない最初の予定 = 次の予定
      if (diff < 0) {
        nextItem = item;
        break;
      }
    }

    // 文言の生成
    String currentStatus = 'Travel Mode Active';
    String nextPlanStr = 'No upcoming plans';
    String plainStatus = 'Travel Mode Active';
    String plainPlan = 'No upcoming plans';

    // パターン1: 何か実行中
    if (currentItem != null) {
      // Android用 (HTML)
      currentStatus = 'Now at <b>${currentItem.name}</b>';
      // iOS用
      plainStatus = 'Now at ${currentItem.name}';

      if (nextItem != null) {
        final timeStr = "${nextItem.time.hour}:${nextItem.time.minute.toString().padLeft(2,'0')}";
        nextPlanStr = 'Next: <font color="#FF9800"><b>${nextItem.name}</b></font> ($timeStr)';
        plainPlan = 'Next: ${nextItem.name} ($timeStr)';
      } else {
        nextPlanStr = 'End of the day';
        plainPlan = 'End of the day';
      }
    } 
    // パターン2: 移動中 (今の予定はないが、次の予定がある)
    else if (nextItem != null) {
      final timeStr = "${nextItem.time.hour}:${nextItem.time.minute.toString().padLeft(2,'0')}";
      
      currentStatus = '<b>Moving</b> to next spot';
      plainStatus = 'Moving to next spot';

      nextPlanStr = 'Next: <font color="#2196F3"><b>${nextItem.name}</b></font> ($timeStr)';
      plainPlan = 'Next: ${nextItem.name} ($timeStr)';
    }

    // 通知更新
    await NotificationService().showOngoingNotification(
      currentStatus: currentStatus,
      nextPlan: nextPlanStr,
      plainStatus: plainStatus,
      plainPlan: plainPlan,
    );
  }

  void _stopOngoingTimer() {
    _ongoingTimer?.cancel();
    _ongoingTimer = null;
  }
  
  @override
  Future<void> close() {
    _stopOngoingTimer();
    return super.close();
  }

  // ----------------------------------------------------------------
  // 4. Private Helpers: 共通ロジック
  // ----------------------------------------------------------------

  // ♻️ 追加: その日のScheduledItemを取得・ソートする共通ヘルパー
  List<ScheduledItem> _getDayScheduledItems(int dayIndex) {
    return state.scheduleItems
        .whereType<ScheduledItem>()
        .where((i) => i.dayIndex == dayIndex)
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
  }

  /// 🔥 最重要リファクタリング: ルート計算の共通化
  Future<RouteItem> _calculateRouteSegment({
    required ScheduledItem startItem,
    required ScheduledItem nextItem,
    required DateTime startTime, 
    TransportType defaultTransport = TransportType.transit,
    RouteItem? existingRoute, 
    String? newRouteId, 
  }) async {
    // 1. 移動手段の決定
    // 既存ルートがあればその手段を、なければ距離で判定
    final distance = const Distance().as(LengthUnit.Meter, 
        LatLng(startItem.latitude!, startItem.longitude!), 
        LatLng(nextItem.latitude!, nextItem.longitude!)
    );
    
    TransportType type = existingRoute?.transportType ?? (distance < 800 ? TransportType.walk : defaultTransport);

    // 2. 再利用判定：API呼び出しをスキップするかチェック
    if (existingRoute != null) {
      // 座標がほぼ同じかチェック (浮動小数点なので許容誤差を持たせる)
      final isSameStart = (existingRoute.startLatitude! - startItem.latitude!).abs() < 0.0001 &&
                          (existingRoute.startLongitude! - startItem.longitude!).abs() < 0.0001;
      final isSameEnd   = (existingRoute.endLatitude! - nextItem.latitude!).abs() < 0.0001 &&
                          (existingRoute.endLongitude! - nextItem.longitude!).abs() < 0.0001;
      final isSameType  = existingRoute.transportType == type;
      
      // 条件: 場所も移動手段も同じで、かつPolyline等のデータが既に取得済みの場合
      if (isSameStart && isSameEnd && isSameType && existingRoute.polyline != null) {
        // APIを呼ばずに既存データをコピーして返す（IDだけ新しくするならする）
        return existingRoute.copyWith(
          id: newRouteId ?? const Uuid().v4(), // 必要なら新しいID
          dayIndex: startItem.dayIndex,
          time: startTime,
          destinationItemId: nextItem.id,
        );
      }
    }

    // 3. APIコール (条件が変わった場合のみここに来る)
    final result = await _routingService.getRouteInfo(
      start: LatLng(startItem.latitude!, startItem.longitude!),
      end: LatLng(nextItem.latitude!, nextItem.longitude!),
      type: type,
    );

    // 4. 値の決定 (AI優先ロジック含む)
    String? polyline = result.polyline;
    int duration = result.durationMinutes;
    List<StepDetail> steps = result.steps;
    String? externalLink = result.externalLink;

    // AIが設定した時間を維持したい場合 (条件が変わっても、AIの意思(時間設定)を残したい場合)
    // ただし場所が変わったなら再計算すべきなので、ここは「移動手段が公共交通で、既存がある場合」くらいの弱い維持にする
    if (existingRoute != null && existingRoute.transportType == type && type == TransportType.transit) {
       // 時間だけは既存維持 (AIの推論を優先)
       duration = existingRoute.durationMinutes;
    }

    // 安全策
    if (_routingService.isPublicTransport(type)) {
       if (duration < 20 && duration == result.durationMinutes) duration += 15;
    }
    if (duration < 1) duration = 1;

    // 5. 新しいRouteItem生成
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

  Future<void> _recalculateAndSave({
    required String tripId,
    required List<ScheduledItem> sortedScheduledItems,
    ScheduledItem? itemToSave,
    String? itemIdToDelete
  }) async {
    // ---------------------------------------------------
    // 1. 現状把握
    // ---------------------------------------------------
    // 現在Stateにある全てのルートを取得
    final allExistingRoutes = state.scheduleItems.whereType<RouteItem>().toList();
    
    // 検索用マップ (DestinationID -> RouteItem)
    // 重複がある場合、ここで1つに絞られる（上書きされる）が、
    // 「allExistingRoutes」には全量残っているので、削除漏れは起きない仕組み。
    final routeMap = {for (var r in allExistingRoutes) r.destinationItemId: r};
    
    // ---------------------------------------------------
    // 2. 正解ルートの計算
    // ---------------------------------------------------
    final List<RouteItem> routesToSave = [];
    final Set<String> validRouteIds = {}; // 🟢 今回「使う」と決めたルートIDのリスト

    for (int i = 0; i < sortedScheduledItems.length - 1; i++) {
      final current = sortedScheduledItems[i];
      final next = sortedScheduledItems[i + 1];
      
      // 緯度経度がないアイテムはルート計算できないのでスキップ
      if (current.latitude == null || next.latitude == null) continue;

      final prevEndTime = current.time.add(Duration(minutes: current.durationMinutes ?? 60));
      
      // この区間の既存ルートを探す
      final existing = routeMap[next.id]; 

      // ルート計算 (ID再利用ロジック含む)
      final route = await _calculateRouteSegment(
        startItem: current, 
        nextItem: next, 
        startTime: prevEndTime,
        existingRoute: existing, 
      );
      
      // 保存リストに追加
      routesToSave.add(route);
      
      // ★重要: このルートIDは「有効（削除してはいけない）」としてマーク
      validRouteIds.add(route.id);
    }

    // ---------------------------------------------------
    // 3. 削除対象の決定 (Clean Sweep)
    // ---------------------------------------------------
    // 全ての既存ルートIDのうち、「有効リスト (validRouteIds)」に入っていないものは全て削除！
    // これにより、重複ルート、孤立ルート、不要になったルートが根こそぎ消える。
    final routeIdsToDelete = allExistingRoutes
        .map((r) => r.id)
        .where((id) => !validRouteIds.contains(id))
        .toList();

    // ---------------------------------------------------
    // 4. Firestoreへ保存
    // ---------------------------------------------------
    await _tripRepository.batchUpdateSchedule(
      tripId: tripId, 
      itemsToAddOrUpdate: itemToSave != null ? [itemToSave] : null,
      itemIdsToDelete: itemIdToDelete != null ? [itemIdToDelete] : null,
      routesToAddOrUpdate: routesToSave, 
      routeIdsToDelete: routeIdsToDelete,
    );

    // 最後に最新データを再取得してStateを更新
    await selectTrip(tripId);
  }

  Future<void> addAIPlanToTrip({required String tripId, required List<ScheduledItem> aiItems, TransportType defaultTransport = TransportType.transit}) async {
    try {
      emit(state.copyWith(status: TripStatus.submitting));
      aiItems.sort((a, b) { final d = a.dayIndex.compareTo(b.dayIndex); return d != 0 ? d : a.time.compareTo(b.time); });
      
      final optimizedItems = List<ScheduledItem>.from(aiItems);
      final List<RouteItem?> routesToAdd = [];
      
      for (int i = 0; i < optimizedItems.length - 1; i++) {
        final current = optimizedItems[i];
        final next = optimizedItems[i + 1];
        if (current.dayIndex != next.dayIndex || current.latitude == null || next.latitude == null) {
           routesToAdd.add(null); continue; 
        }

        final currentEndTime = current.time.add(Duration(minutes: current.durationMinutes ?? 60));
        
        // ★共通メソッドを使用
        final route = await _calculateRouteSegment(
          startItem: current, nextItem: next, startTime: currentEndTime,
          defaultTransport: defaultTransport, newRouteId: const Uuid().v4()
        );

        optimizedItems[i + 1] = next.copyWith(time: currentEndTime.add(Duration(minutes: route.durationMinutes))); 
        routesToAdd.add(route);
      }
      await _tripRepository.batchAddAIPlan(tripId: tripId, spots: optimizedItems, routes: routesToAdd);
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

      // IDがない場合はクライアント側で生成 (State即時反映のため)
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

      // Firestoreへ保存
      await _tripRepository.addOrUpdateExpense(tripId, expenseToSave);

      // ローカルStateを更新
      final currentExpenses = List<ExpenseItem>.from(state.expenses);
      final index = currentExpenses.indexWhere((e) => e.id == expenseToSave.id);
      
      if (index != -1) {
        currentExpenses[index] = expenseToSave;
      } else {
        currentExpenses.insert(0, expenseToSave);
        // 日付順ソート (新しい順)
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
      
      // Repositoryにdeleteメソッドがある前提
      await _tripRepository.deleteExpense(tripId, expenseId);
      
      final currentExpenses = List<ExpenseItem>.from(state.expenses);
      currentExpenses.removeWhere((e) => e.id == expenseId);
      
      emit(state.copyWith(status: TripStatus.loaded, expenses: currentExpenses));
    } catch (e) {
      emit(state.copyWith(status: TripStatus.error, errorMessage: e.toString()));
    }
  } 
}