import 'package:new_tripple/models/trip.dart';
// ScheduleItemとRouteItemは、リストの型ヒントには使わず、実行時に型を判定する（後述）

class TripState {
  // 1. 状態管理
  final TripStatus status; 

  // 2. メインデータ
  final List<Trip> allTrips; // ユーザーが所有/参加する全旅行のリスト

  // 3. 詳細データ（特定の旅行が選択された時に使用）
  final Trip? selectedTrip;
  // ScheduledItem と RouteItem が混在するため List<Object> としておく。
  // 取得時に時刻順でソート済みである想定。
  final List<Object> scheduleItems; 

  // 4. エラーメッセージ
  final String errorMessage;

  const TripState({
    this.status = TripStatus.initial,
    this.allTrips = const [],
    this.selectedTrip,
    this.scheduleItems = const [],
    this.errorMessage = '',
  });

  // 状態を変更する際は、この copyWith メソッドで新しいインスタンスを生成する
  TripState copyWith({
    TripStatus? status,
    List<Trip>? allTrips,
    Trip? selectedTrip,
    List<Object>? scheduleItems,
    String? errorMessage,
  }) {
    return TripState(
      status: status ?? this.status,
      allTrips: allTrips ?? this.allTrips,
      // selectedTripにnullを明示的に渡したい場合は、null許容型として扱うための特別なロジックが必要になるが、
      // ここではシンプルに ? を使って、nullが渡されなければ既存の値を保持するようにする
      selectedTrip: selectedTrip ?? this.selectedTrip,
      scheduleItems: scheduleItems ?? this.scheduleItems,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}


enum TripStatus {
  /// 初期状態。何もしていない。
  initial, 
  /// データをサーバーから読み込み中。
  loading, 
  /// データの読み込みが完了した。
  loaded,  
  /// データ送信（保存/更新）中。
  submitting, 
  /// エラーが発生した。
  error,   
}