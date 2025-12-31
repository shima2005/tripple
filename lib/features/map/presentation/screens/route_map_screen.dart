// lib/features/map/presentation/screens/route_map_screen.dart

import 'dart:async'; // Stream用
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';
import 'package:new_tripple/models/trip.dart';
import 'package:new_tripple/models/schedule_item.dart';
import 'package:new_tripple/models/route_item.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
// 👇 位置情報パッケージ
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:geolocator/geolocator.dart';

class RouteMapScreen extends StatefulWidget {
  final Trip trip;
  final List<ScheduledItem> scheduleItems;
  final List<RouteItem> routeItems;
  final VoidCallback onBackTap;
  final LatLng? initialFocus;

  const RouteMapScreen({
    super.key,
    required this.trip,
    required this.scheduleItems,
    required this.routeItems,
    required this.onBackTap,
    this.initialFocus
  });

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  final MapController _mapController = MapController();
  
  // フィルタリング用
  int? _selectedDayIndex;

  // 👇 現在地追従の管理変数
  late AlignOnUpdate _alignPositionOnUpdate;

  @override
  void initState() {
    super.initState();
    // 初期値は「追従しない (手動操作モード)」
    _alignPositionOnUpdate = AlignOnUpdate.never;
    
    _checkPermission(); // 位置情報の許可を確認
  }

  Future<void> _checkPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
  }

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
    _mapController.move(point, 15.0);
  }

  void _fitBounds() {
    final visiblePoints = widget.scheduleItems
        .where((item) {
           final isDayMatch = _selectedDayIndex == null || item.dayIndex == _selectedDayIndex;
           return item.latitude != null && item.longitude != null && isDayMatch;
        })
        .map((item) => LatLng(item.latitude!, item.longitude!))
        .toList();

    if (visiblePoints.isEmpty) return;

    final bounds = LatLngBounds.fromPoints(visiblePoints);
    
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50),
      ),
    );
    // ズームしたら追従モードは解除
    if (mounted) setState(() => _alignPositionOnUpdate = AlignOnUpdate.never);
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = widget.scheduleItems.where((item) {
      final hasLocation = item.latitude != null && item.longitude != null;
      final isDayMatch = _selectedDayIndex == null || item.dayIndex == _selectedDayIndex;
      return hasLocation && isDayMatch;
    }).toList();

    final visibleRoutes = widget.routeItems.where((route) {
      final hasPolyline = route.polyline != null && route.polyline!.isNotEmpty;
      final isDayMatch = _selectedDayIndex == null || route.dayIndex == _selectedDayIndex;
      return hasPolyline && isDayMatch;
    }).toList();

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
              initialCenter: widget.initialFocus ?? const LatLng(35.6812, 139.7671),
              initialZoom: widget.initialFocus != null ? 15.0 : 5.0,
              onMapReady: _onMapReady,
              // 手動で動かしたら追従解除
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture) {
                  setState(() => _alignPositionOnUpdate = AlignOnUpdate.never);
                }
              },
            ),
            
            children: [
              // A. Mapboxタイル (元のコード)
              TileLayer(
                urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token={accessToken}',
                additionalOptions: const {
                  'accessToken': 'pk.eyJ1Ijoic2hpbWEyMDA1IiwiYSI6ImNtaW96bzBqaDAwZHYzZnB3anY1b2p5cGMifQ.7u4lEuhFpc_GhqaiBrUmTQ', 
                },
                userAgentPackageName: 'com.example.new_tripple',
                tileProvider: CancellableNetworkTileProvider(),
              ),

              // B. ルート線
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

              // C. ピン
              MarkerLayer(
                markers: visibleItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final color = getDayColor(item.dayIndex);

                  return Marker(
                    point: LatLng(item.latitude!, item.longitude!),
                    width: 40,
                    height: 40,
                    child: _buildPin(index + 1, color),
                  );
                }).toList(),
              ),

              // 👇 D. 現在地表示レイヤー (修正版)
              CurrentLocationLayer(
                alignPositionOnUpdate: _alignPositionOnUpdate,
                alignDirectionOnUpdate: AlignOnUpdate.never, // 方角追従はしない
                
                // ★重要: 方角ストリームを無効化してエラーを防ぐ
                headingStream: Stream.value(null),

                style: const LocationMarkerStyle(
                  marker: DefaultLocationMarker(
                    color: AppColors.primary,
                    child: Icon(Icons.navigation, color: Colors.white, size: 16),
                  ),
                  markerSize: Size(40, 40),
                  accuracyCircleColor: Color.fromRGBO(33, 150, 243, 0.2),
                  showHeadingSector: false, // セクター表示もOFF
                ),
              ),
            ],
          ),

          // -------------------------------------------------------
          // 2. 戻るボタン
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
          // 3. 凡例 & フィルタ
          // -------------------------------------------------------
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Day Filter", style: AppTextStyles.label),
                    const SizedBox(height: 8),
                    _buildLegendItem(
                      label: "All Days",
                      color: Colors.black,
                      isSelected: _selectedDayIndex == null,
                      onTap: () {
                        setState(() => _selectedDayIndex = null);
                        _fitBounds();
                      },
                    ),
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
                            _fitBounds();
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // -------------------------------------------------------
          // 4. マップ操作ボタン (現在地ボタン追加)
          // -------------------------------------------------------
          Positioned(
            bottom: 30,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 👇 現在地へ移動ボタン
                FloatingActionButton(
                  heroTag: 'gps_btn',
                  backgroundColor: _alignPositionOnUpdate == AlignOnUpdate.always 
                      ? AppColors.primary 
                      : Colors.white,
                  onPressed: () {
                    setState(() {
                      // 追従モードON
                      _alignPositionOnUpdate = AlignOnUpdate.always;
                    });
                  },
                  child: Icon(
                    Icons.my_location,
                    color: _alignPositionOnUpdate == AlignOnUpdate.always 
                        ? Colors.white 
                        : Colors.black54,
                  ),
                ),
                const SizedBox(height: 16),
                
                // 全体表示ボタン
                FloatingActionButton(
                  heroTag: 'fit_bounds_btn',
                  backgroundColor: Colors.white,
                  onPressed: () {
                    _fitBounds();
                  },
                  child: const Icon(Icons.crop_free, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets (変更なし) ---
  
  Widget _buildPin(int number, Color color) {
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