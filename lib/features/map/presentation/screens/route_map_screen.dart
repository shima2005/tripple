import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // flutter_map
import 'package:latlong2/latlong.dart' hide Path; // 座標用
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';
import 'package:new_tripple/models/trip.dart';
import 'package:new_tripple/models/schedule_item.dart';
import 'package:new_tripple/models/route_item.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

class RouteMapScreen extends StatefulWidget {
  final Trip trip;
  final List<ScheduledItem> scheduleItems;
  final List<RouteItem> routeItems; // 👈 追加
  final VoidCallback onBackTap;
  final LatLng? initialFocus;

  const RouteMapScreen({
    super.key,
    required this.trip,
    required this.scheduleItems,
    required this.routeItems, // 👈 追加
    required this.onBackTap,
    this.initialFocus
  });

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  final MapController _mapController = MapController();
  
  // フィルタリング用: nullなら全日程表示、数値ならそのDayIndexのみ表示
  int? _selectedDayIndex;

  @override
  void initState() {
    super.initState();
  }

  // 👇 親から新しいフォーカス地点が渡されたら、そこへ移動する処理
  @override
  void didUpdateWidget(RouteMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFocus != oldWidget.initialFocus && widget.initialFocus != null) {
      _moveToFocus(widget.initialFocus!);
    }
  }

  void _onMapReady() {
    if (widget.initialFocus != null) {
      _moveToFocus(widget.initialFocus!);
    } else {
      _fitBounds();
    }
  }

  void _moveToFocus(LatLng point) {
    _mapController.move(point, 15.0); // ズームレベル15で移動
  }

  void _fitBounds() {
    // 1. 座標を持つ「滞在先 (ScheduledItem)」だけを抽出
    // (RouteItemの経由地などは含めない方が、メインの観光エリアにフォーカスしやすい)
    final points = widget.scheduleItems
        .where((item) => item.latitude != null && item.longitude != null)
        .map((item) => LatLng(item.latitude!, item.longitude!))
        .toList();

    if (points.isEmpty) return;

    // 2. 全ての点が収まる範囲 (Bounds) を計算
    final bounds = LatLngBounds.fromPoints(points);
    
    // 3. カメラをその範囲に合わせる (paddingで少し余白を持たせる)
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50), // 上下左右に50pxの余白
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. 表示対象のアイテムをフィルタリング (ScheduledItem)
    final visibleItems = widget.scheduleItems.where((item) {
      final hasLocation = item.latitude != null && item.longitude != null;
      final isDayMatch = _selectedDayIndex == null || item.dayIndex == _selectedDayIndex;
      return hasLocation && isDayMatch;
    }).toList();

    // 2. 表示対象のルートをフィルタリング (RouteItem)
    final visibleRoutes = widget.routeItems.where((route) {
      final hasPolyline = route.polyline != null && route.polyline!.isNotEmpty;
      final isDayMatch = _selectedDayIndex == null || route.dayIndex == _selectedDayIndex;
      return hasPolyline && isDayMatch;
    }).toList();

    // 3. 日付ごとのカラーパレット
    final dayColors = [
      AppColors.primary,
      AppColors.accent,
      Colors.orange,
      Colors.pinkAccent,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
    ];

    Color getDayColor(int dayIndex) {
      return dayColors[dayIndex % dayColors.length];
    }

    return Scaffold(
      body: Stack(
        children: [
          // -------------------------------------------------------
          // 1. マップ本体
          // -------------------------------------------------------
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialFocus?? const LatLng(35.6812, 139.7671), // 初期値は東京
              initialZoom: widget.initialFocus != null ? 15.0 : 5.0,
              onMapReady: _onMapReady
            ),
            
            children: [
              // A. タイルレイヤー (OpenStreetMap)
              TileLayer(
                // Mapboxのスタイル付きタイルURL
                // mapbox/light-v11: シンプルなライトモード
                // @2x: Retinaディスプレイ対応（これがないとボヤけます）
                urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token={accessToken}',
                
                // トークンを渡す
                additionalOptions: const {
                  'accessToken': 'pk.eyJ1Ijoic2hpbWEyMDA1IiwiYSI6ImNtaW96bzBqaDAwZHYzZnB3anY1b2p5cGMifQ.7u4lEuhFpc_GhqaiBrUmTQ', // 👇 RoutingServiceと同じトークンを貼る！
                },
                
                userAgentPackageName: 'com.example.new_tripple',

                tileProvider: CancellableNetworkTileProvider(),
              ),

              // B. ルート線 (PolylineLayer)
              // 保存されたPolyline文字列をデコードして表示
              // B. ルート線 (PolylineLayer)
              PolylineLayer(
                polylines: [
                  for (var route in visibleRoutes)
                    if (route.polyline != null)
                      Polyline(
                        points: PolylinePoints.decodePolyline(route.polyline!)
                            .map((e) => LatLng(e.latitude, e.longitude))
                            .toList(),
                            
                        strokeWidth: 4.0,
                        color: getDayColor(route.dayIndex).withValues(alpha: 0.7),
                      ),
                ],
              ),

              // C. ピン (Marker)
              MarkerLayer(
                markers: visibleItems.asMap().entries.map((entry) {
                  final index = entry.key; // 表示順 (0, 1, 2...)
                  final item = entry.value;
                  final color = getDayColor(item.dayIndex);

                  return Marker(
                    point: LatLng(item.latitude!, item.longitude!),
                    width: 40,
                    height: 40,
                    child: _buildPin(index + 1, color), // ①, ②...
                  );
                }).toList(),
              ),
            ],
          ),

          // -------------------------------------------------------
          // 2. 戻るボタン (左上)
          // -------------------------------------------------------
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                  onPressed: widget.onBackTap,
                ),
              ),
            ),
          ),

          // -------------------------------------------------------
          // 3. 凡例 & フィルタ (右上)
          // -------------------------------------------------------
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9), // 半透明で見やすく
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Day Filter", style: AppTextStyles.label),
                    const SizedBox(height: 8),
                    
                    // "All Days" ボタン
                    _buildLegendItem(
                      label: "All Days",
                      color: Colors.black,
                      isSelected: _selectedDayIndex == null,
                      onTap: () {
                        setState(() => _selectedDayIndex = null);
                        _fitBounds(); // ズーム再調整
                      },
                    ),

                    // 各Dayのボタン
                    ...List.generate(
                      widget.trip.endDate.difference(widget.trip.startDate).inDays + 1,
                      (index) {
                        final dayColor = getDayColor(index);
                        return _buildLegendItem(
                          label: "Day ${index + 1}",
                          color: dayColor,
                          isSelected: _selectedDayIndex == index,
                          onTap: () {
                            setState(() => _selectedDayIndex = index);
                            _fitBounds(); // ズーム再調整
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---
  
  Widget _buildPin(int number, Color color) {
    // ... (変更なし)
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ),
        ClipPath(
          clipper: _TriangleClipper(),
          child: Container(width: 10, height: 8, color: color),
        ),
      ],
    );
  }

  Widget _buildLegendItem({
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    // ... (変更なし)
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Icon(Icons.check_circle_rounded, size: 16, color: color)
            else
              Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}