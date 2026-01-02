import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:new_tripple/models/expense_item.dart';
import 'package:new_tripple/models/trip.dart';
import 'package:new_tripple/models/schedule_item.dart';
import 'package:new_tripple/models/route_item.dart';

class TripRepository {
  final FirebaseFirestore _firestore;

  TripRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // 1. Tripコレクション (withConverter)
  CollectionReference<Trip> get _tripsRef {
    return _firestore.collection('trips').withConverter<Trip>(
      fromFirestore: Trip.fromFirestore,
      toFirestore: (trip, _) => trip.toFirestore(),
    );
  }

  // 2. スケジュールコレクション (動的判定)
  CollectionReference<Object> _scheduleRef(String tripId) {
    return _firestore
        .collection('trips')
        .doc(tripId)
        .collection('schedule_items')
        .withConverter<Object>(
      fromFirestore: (snapshot, options) {
        final data = snapshot.data()!;
        // transportTypeがあればRoute、なければScheduledとみなす
        if (data.containsKey('transportType')) {
          return RouteItem.fromFirestore(snapshot, options);
        } else {
          return ScheduledItem.fromFirestore(snapshot, options);
        }
      },
      toFirestore: (item, _) {
        if (item is ScheduledItem) return item.toFirestore();
        if (item is RouteItem) return item.toFirestore();
        throw Exception('Unknown item type');
      },
    );
  }

  // ----------------------------------------------------------------
  // 2. データ操作メソッド
  // ----------------------------------------------------------------

  Future<Trip?> getTripById(String tripId) async {
    // _tripsRef は既に withConverter が適用されているので、
    // get() すると DocumentSnapshot<Trip> が返ってきます。
    final docSnap = await _tripsRef.doc(tripId).get();
    
    // データが存在すれば Trip オブジェクトを、なければ null を返します
    return docSnap.data();
  }

  /// ユーザーに関連するTrip一覧を取得
  Future<List<Trip>> fetchTrips(String userId) async {
    // memberIds配列にuserIdが含まれているか、またはownerIdがuserIdのものを検索
    // Note: Firestoreの制約でOR検索が複雑な場合があるため、ここではシンプルに「自分が含まれる」検索を優先
    final snapshot = await _tripsRef
        .where('memberIds', arrayContains: userId)
        .orderBy('startDate', descending: true) // 新しい旅行順
        .get();
        
    // ownerIdでの検索も必要なら別途クエリして結合する処理が必要だが、
    // 作成時に必ずmemberIdsに自分を入れるルールにすれば上記のクエリ1発で済む（推奨）
    
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// 新しいTripを追加
  Future<void> addTrip(Trip trip) async {
    // IDは自動生成させるか、指定させるか。今回はモデルにIDがあるが、新規作成時はFirestoreに採番させることが多い。
    // ここでは指定されたID（空文字なら自動生成）を使う実装例。
    if (trip.id.isEmpty) {
      await _tripsRef.add(trip);
    } else {
      await _tripsRef.doc(trip.id).set(trip);
    }
  }

  /// 旅程詳細（ScheduledItem + RouteItem）を全取得
  Future<List<Object>> fetchFullSchedule(String tripId) async {
    final snapshot = await _scheduleRef(tripId)
        .orderBy('time') // 時刻順で取得
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// RouteItemを追加・更新
  Future<void> addRouteItem(String tripId, RouteItem item) async {
    if (item.id.isEmpty) {
      // 新規作成 (基本はCubitの自動生成でやるのであまり使わないかも)
      await _scheduleRef(tripId).add(item);
    } else {
      // 更新 (今回使うのはこっち！)
      await _scheduleRef(tripId).doc(item.id).set(item, SetOptions(merge: true));
    }
  }

  /// Tripを削除
  Future<void> deleteTrip(String tripId) async {
    await _tripsRef.doc(tripId).delete();
    // サブコレクション（schedule_items）も消すのが本来の筋だけど、
    // クライアント側では面倒なので、まずは親ドキュメント削除だけでOK
    // (本格運用時はCloud Functionsで連動削除させるのが定石)
  }

  

  // ----------------------------------------------------------------
  // 3. ヘルパー (詳細ステップ変換)
  // ----------------------------------------------------------------

  /// 複数の処理をまとめて実行する (バッチ処理)
  /// 滞在の追加・更新・削除と、それに伴う経路の自動調整を一度に行うため
  Future<void> batchUpdateSchedule({
    required String tripId,
    List<ScheduledItem>? itemsToAddOrUpdate,
    List<String>? itemIdsToDelete,
    List<RouteItem>? routesToAddOrUpdate,
    List<String>? routeIdsToDelete,
  }) async {
    final batch = _firestore.batch();
    final scheduleRef = _scheduleRef(tripId); // コレクション参照 (withConverter付き)

    // 1. ScheduledItem の追加/更新
    if (itemsToAddOrUpdate != null) {
      for (var item in itemsToAddOrUpdate) {
        if (item.id.isEmpty) {
          // 新規作成: IDを自動生成し、モデルにもセットしてから保存
          final docRef = scheduleRef.doc(); 
          final newItem = item.copyWith(id: docRef.id);
          batch.set(docRef, newItem); 
        } else {
          // 更新
          batch.set(scheduleRef.doc(item.id), item, SetOptions(merge: true));
        }
      }
    }

    // 2. ScheduledItem の削除
    if (itemIdsToDelete != null) {
      for (var id in itemIdsToDelete) {
        batch.delete(scheduleRef.doc(id));
      }
    }

    // 3. RouteItem の追加/更新
    if (routesToAddOrUpdate != null) {
      for (var route in routesToAddOrUpdate) {
        if (route.id.isEmpty) {
          // 新規作成
          final docRef = scheduleRef.doc();
          final newRoute = route.copyWith(id: docRef.id);
          batch.set(docRef, newRoute);
        } else {
          // 更新
          batch.set(scheduleRef.doc(route.id), route, SetOptions(merge: true));
        }
      }
    }

    // 4. RouteItem の削除
    if (routeIdsToDelete != null) {
      for (var id in routeIdsToDelete) {
        batch.delete(scheduleRef.doc(id));
      }
    }

    // コミット！ (これら全ての変更を一括反映)
    await batch.commit();
  }

  Future<void> batchAddAIPlan({
    required String tripId,
    required List<ScheduledItem> spots, // 時系列順
    required List<RouteItem?> routes,   // 時系列順 (null許容: 移動がない区間用)
  }) async {
    final batch = _firestore.batch();
    final scheduleRef = _scheduleRef(tripId);

    // 1. ScheduledItemのIDを先に確定させて保存
    final List<String> spotIds = [];
    
    for (var spot in spots) {
      final docRef = scheduleRef.doc(); // ID生成
      final id = docRef.id;
      spotIds.add(id);
      
      final newSpot = spot.copyWith(id: id);
      batch.set(docRef, newSpot);
    }

    // 2. RouteItemに次のスポットIDを紐付けて保存
    // routes[i] は spots[i] と spots[i+1] の間の移動
    for (int i = 0; i < routes.length; i++) {
      final route = routes[i];
      // ルートが存在し、かつ「次のスポット」が存在する場合のみ保存
      if (route != null && i + 1 < spotIds.length) {
        final nextSpotId = spotIds[i + 1];
        
        final docRef = scheduleRef.doc();
        final newRoute = route.copyWith(
          id: docRef.id,
          destinationItemId: nextSpotId, // 👈 ここで紐付け！
        );
        batch.set(docRef, newRoute);
      }
    }

    // 3. コミット
    await batch.commit();
  }

  Future<void> updateTrip(Trip trip) async {
    // toFirestore() を使って保存
    await _tripsRef.doc(trip.id).set(trip, SetOptions(merge: true));
  }

  // 👇 追加: メンバーに参加 (Join)
  Future<void> joinTrip(String tripId, String userId) async {
    // 存在確認
    final docSnap = await _tripsRef.doc(tripId).get();
    if (!docSnap.exists) {
      throw Exception('Trip not found');
    }

    // 配列に自分を追加 (arrayUnionは重複防止もしてくれる)
    await _tripsRef.doc(tripId).update({
      'memberIds': FieldValue.arrayUnion([userId]),
    });
  }

  CollectionReference<ExpenseItem> _expensesRef(String tripId) {
    return _firestore
        .collection('trips')
        .doc(tripId)
        .collection('expenses')
        .withConverter<ExpenseItem>(
          fromFirestore: ExpenseItem.fromFirestore,
          toFirestore: (item, _) => item.toFirestore(),
        );
  }

  /// 支出一覧を取得
  Future<List<ExpenseItem>> fetchExpenses(String tripId) async {
    final snapshot = await _expensesRef(tripId).orderBy('date', descending: true).get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// 支出を追加・更新
  Future<void> addOrUpdateExpense(String tripId, ExpenseItem expense) async {
    if (expense.id.isEmpty) {
      await _expensesRef(tripId).add(expense);
    } else {
      await _expensesRef(tripId).doc(expense.id).set(expense, SetOptions(merge: true));
    }
  }

  /// 支出を削除
  Future<void> deleteExpense(String tripId, String expenseId) async {
    await _expensesRef(tripId).doc(expenseId).delete();
  }

  /// ゲストメンバーの追加 (Tripドキュメントの更新)
  Future<void> addGuestToTrip(String tripId, TripGuest guest) async {
    await _tripsRef.doc(tripId).update({
      'guests': FieldValue.arrayUnion([guest.toMap()]),
    });
  }
}