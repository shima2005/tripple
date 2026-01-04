// lib/models/ios_live_activity_state.dart

class IosLiveActivityState {
  final String pattern;      // 'stay', 'move_detail', 'move_simple', 'wait'
  final String title;        // MainBody (例: 清水寺, 東京駅 -> 大阪駅)
  final String subTitle;     // SubInfo (例: 13:00-15:00, のぞみ12号)
  final String bottomInfo;   // Bottom (例: Next: ホテル, 10:00 - 10:45)
  final String iconName;     // SF Symbols名 (bed.double.fill, bus.fill 等)
  final double progress;     // 0.0 ~ 1.0 (プログレスバー用)
  final int endTimeEpoch;    // 終了時刻 (Dynamic Islandのカウントダウン用)
  final String statusLabel;  // 'On Time', 'Moving' 等のラベル

  IosLiveActivityState({
    required this.pattern,
    required this.title,
    required this.subTitle,
    required this.bottomInfo,
    required this.iconName,
    required this.progress,
    required this.endTimeEpoch,
    required this.statusLabel,
  });

  Map<String, dynamic> toMap() {
    return {
      'pattern': pattern,
      'title': title,
      'subTitle': subTitle,
      'bottomInfo': bottomInfo,
      'iconName': iconName,
      'progress': progress,
      'endTimeEpoch': endTimeEpoch,
      'statusLabel': statusLabel,
    };
  }
}