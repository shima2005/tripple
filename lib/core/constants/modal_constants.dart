import 'package:flutter/material.dart';

class TrippleModalSize {
  // インスタンス化させない
  TrippleModalSize._();

  // --- 高さの定義 (画面全体の何割か) ---
  
  /// フルスクリーンに近い編集用 (RouteEdit, ScheduleEditなど入力項目が多いもの)
  /// キーボードが出ても十分なスペースを確保するため 92% くらいがおすすめ
  static const double highRatio = 0.92;

  /// 標準的な編集・選択用 (TripEdit, SearchModalなど)
  static const double mediumRatio = 0.85;

  /// 簡易的なアクション用 (Share, Tag追加など)
  static const double compactRatio = 0.65;

  // --- ヘルパーメソッド ---
  
  /// コンテキストを渡して計算された高さを取得
  static double getHeight(BuildContext context, double ratio) {
    return MediaQuery.of(context).size.height * ratio;
  }
}