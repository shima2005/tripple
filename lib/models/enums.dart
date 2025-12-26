import 'package:flutter/material.dart';

/// 予定（ScheduledItem）のカテゴリ
enum ItemCategory {
  sightseeing,
  food,
  accommodation,
  leisure,
  shopping,
  transport, // 交通拠点（駅や空港自体）
  other;
}

/// カテゴリごとのアイコンなどを拡張
extension ItemCategoryExtension on ItemCategory {
  String get displayName {
    switch (this) {
      case ItemCategory.sightseeing: return '観光';
      case ItemCategory.food: return '食事';
      case ItemCategory.accommodation: return '宿泊';
      case ItemCategory.leisure: return 'アクティビティ';
      case ItemCategory.shopping: return '買い物';
      case ItemCategory.transport: return '移動拠点';
      case ItemCategory.other: return 'その他';
    }
  }

  IconData get icon {
    switch (this) {
      case ItemCategory.sightseeing: return Icons.camera_alt_rounded;
      case ItemCategory.food: return Icons.restaurant_rounded;
      case ItemCategory.accommodation: return Icons.hotel_rounded;
      case ItemCategory.leisure: return Icons.attractions_rounded;
      case ItemCategory.shopping: return Icons.shopping_bag_rounded;
      case ItemCategory.transport: return Icons.connecting_airports_rounded;
      case ItemCategory.other: return Icons.place_rounded;
    }
  }
}

/// 移動（RouteItem）の手段 - 大幅拡充！
enum TransportType {
  walk,
  train,      // 電車
  bus,        // バス
  subway,     // 地下鉄
  shinkansen, // 新幹線・特急
  car,
  taxi,
  plane,
  ferry,      // 船
  bicycle,    // 自転車
  transit,
  other;
}

/// 移動手段ごとのアイコンなどを拡張
extension TransportTypeExtension on TransportType {
  String get displayName {
    switch (this) {
      case TransportType.walk: return '徒歩';
      case TransportType.train: return '電車';
      case TransportType.bus: return 'バス';
      case TransportType.subway: return '地下鉄';
      case TransportType.shinkansen: return '新幹線/特急';
      case TransportType.car: return '車';
      case TransportType.taxi: return 'タクシー';
      case TransportType.plane: return '飛行機';
      case TransportType.ferry: return 'フェリー';
      case TransportType.bicycle: return '自転車';
      case TransportType.transit: return '公共交通機関';
      case TransportType.other: return 'その他';
    }
  }

  IconData get icon {
    switch (this) {
      case TransportType.walk: return Icons.directions_walk_rounded;
      case TransportType.train: return Icons.train_rounded;
      case TransportType.bus: return Icons.directions_bus_rounded;
      case TransportType.subway: return Icons.subway_rounded;
      case TransportType.shinkansen: return Icons.directions_railway_filled_rounded;
      case TransportType.car: return Icons.directions_car_rounded;
      case TransportType.taxi: return Icons.local_taxi_rounded;
      case TransportType.plane: return Icons.flight_rounded;
      case TransportType.ferry: return Icons.directions_boat_rounded;
      case TransportType.bicycle: return Icons.pedal_bike_rounded;
      case TransportType.transit: return Icons.commute_rounded;
      case TransportType.other: return Icons.commute_rounded;
    }
  }
}