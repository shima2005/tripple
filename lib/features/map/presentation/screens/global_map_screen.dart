import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:new_tripple/core/theme/app_colors.dart';
import 'package:new_tripple/core/theme/app_text_styles.dart';
import 'package:new_tripple/features/trip/domain/trip_cubit.dart';
import 'package:new_tripple/features/trip/domain/trip_state.dart';
import 'package:new_tripple/models/trip.dart';
import 'package:new_tripple/core/utils/country_converter.dart';
// 👇 追加: 設定（ホームカントリー）を取得するため
import 'package:new_tripple/features/settings/domain/settings_cubit.dart';

class GlobalMapScreen extends StatefulWidget {
  final Function(Trip) onTripSelected;

  const GlobalMapScreen({super.key, required this.onTripSelected});

  @override
  State<GlobalMapScreen> createState() => _GlobalMapScreenState();
}

class _GlobalMapScreenState extends State<GlobalMapScreen> {
  final MapController _mapController = MapController();
  
  List<dynamic>? _geoJsonFeatures;
  List<Polygon> _countryPolygons = [];
  Map<String, _CountryStats> _countryStatsMap = {}; 
  int _totalScore = 0; 

  bool _isLoadingGeoJson = true;
  bool _showPins = true;

  @override
  void initState() {
    super.initState();
    _initGeoJson();
    _countryStatsMap; 
  }

  Future<void> _initGeoJson() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/geo/countries.geo.json');
      final data = json.decode(jsonString);
      setState(() {
        _geoJsonFeatures = data['features'] as List;
      });
      if (mounted) {
        _calculateAndPaint(context.read<TripCubit>().state.allTrips);
      }
    } catch (e) {
      //print('❌ GeoJSON Load Error: $e');
      if (mounted) setState(() => _isLoadingGeoJson = false);
    }
  }

  void _calculateAndPaint(List<Trip> trips) {
    if (_geoJsonFeatures == null) return;

    // 👇 設定からホームカントリーを取得
    final settingsState = context.read<SettingsCubit>().state;
    final homeCountryCode = settingsState.homeCountryCode?.toLowerCase();

    final statsMap = <String, _CountryStats>{};
    int totalUserScore = 0;

    for (var trip in trips) {
      final tripTotalDays = trip.endDate.difference(trip.startDate).inDays + 1;
      final tripCountryDays = <String, int>{};
      final uniqueCodes = <String>{};

      for (var dest in trip.destinations) {
        if (dest.countryCode != null) {
          final code = dest.countryCode!.toLowerCase();
          uniqueCodes.add(code);
          tripCountryDays[code] = (tripCountryDays[code] ?? 0) + (dest.stayDays ?? 0);
        }
      }

      if (uniqueCodes.length == 1) {
        final code = uniqueCodes.first;
        final current = tripCountryDays[code] ?? 0;
        tripCountryDays[code] = tripTotalDays > current ? tripTotalDays : current;
      }

      for (var code in uniqueCodes) {
        // 👇 ホームカントリーならスコア計算から除外
        if (code == homeCountryCode) continue;

        if (!statsMap.containsKey(code)) {
          statsMap[code] = _CountryStats();
        }
        statsMap[code]!.visitCount++;
        statsMap[code]!.stayDays += (tripCountryDays[code] ?? 0);
      }
    }

    statsMap.forEach((key, stats) {
      stats.score = (stats.visitCount * 5) + stats.stayDays;
      totalUserScore += stats.score;
    });

    final polygons = <Polygon>[];
    for (var feature in _geoJsonFeatures!) {
      final geometry = feature['geometry'] as Map<String, dynamic>;
      final type = geometry['type'];
      
      final String? alpha3 = feature['id'] as String?;
      final String? alpha2 = alpha3 != null ? CountryConverter.toAlpha2(alpha3) : null;
      final String? codeKey = alpha2?.toLowerCase();

      final stats = codeKey != null ? statsMap[codeKey] : null;
      
      // 👇 色の決定ロジック
      Color color;
      if (codeKey != null && codeKey == homeCountryCode) {
        // 🏠 ホームカントリー: Primaryカラーの薄い色 (特別扱い)
        color = AppColors.primary.withValues(alpha: 0.3);
      } else {
        // その他: スコアに応じた色
        color = _getScoreColor(stats?.score ?? 0);
      }

      final borderColor = (stats != null || (codeKey != null && codeKey == homeCountryCode))
          ? Colors.white.withValues(alpha: 0.5) 
          : Colors.transparent;

      void addPolygon(List points) {
        polygons.add(
          Polygon(
            points: _parseCoordinates(points),
            color: color,
            borderColor: borderColor,
            borderStrokeWidth: 1.0,
          ),
        );
      }

      if (type == 'Polygon') {
        addPolygon(geometry['coordinates'][0]);
      } else if (type == 'MultiPolygon') {
        final List coordinates = geometry['coordinates'];
        for (var polygonCoords in coordinates) {
          addPolygon(polygonCoords[0]);
        }
      }
    }

    if (mounted) {
      setState(() {
        _countryStatsMap = statsMap;
        _totalScore = totalUserScore;
        _countryPolygons = polygons;
        _isLoadingGeoJson = false;
      });
    }
  }

  Color _getScoreColor(int score) {
    if (score <= 0) return Colors.grey.withValues(alpha: 0.2);
    if (score <= 10) return Colors.cyan.withValues(alpha: 0.6);
    if (score <= 20) return Colors.teal.withValues(alpha: 0.6);
    if (score <= 30) return Colors.amber.withValues(alpha: 0.6);
    if (score <= 50) return Colors.orange.withValues(alpha: 0.6);
    return Colors.deepOrange.withValues(alpha: 0.7);
  }

  List<LatLng> _parseCoordinates(List coords) {
    return coords.map<LatLng>((point) {
      return LatLng((point[1] as num).toDouble(), (point[0] as num).toDouble());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TripCubit, TripState>(
      listener: (context, state) {
        if (state.status == TripStatus.loaded) {
          _calculateAndPaint(state.allTrips);
        }
      },
      builder: (context, state) {
        final markers = _buildMarkers(state.allTrips);
        
        // 訪問国数 (ホームカントリーは除外してカウント)
        final settingsState = context.read<SettingsCubit>().state;
        final homeCountryCode = settingsState.homeCountryCode?.toLowerCase();

        final visitedCount = state.allTrips
            .expand((t) => t.destinations)
            .map((d) => d.countryCode?.toLowerCase())
            .where((c) => c != null && c != homeCountryCode) // 👈 除外
            .toSet()
            .length;

        return Scaffold(
          body: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: const LatLng(20.0, 0.0),
                  initialZoom: 2.5,
                  minZoom: 2.0,
                  maxZoom: 7.0,
                  cameraConstraint: CameraConstraint.contain(
                    bounds: LatLngBounds(
                      const LatLng(-85, -180),
                      const LatLng(85, 180),
                    ),
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/light-v11/tiles/256/{z}/{x}/{y}@2x?access_token={accessToken}',
                    additionalOptions: const {
                      'accessToken': 'pk.eyJ1Ijoic2hpbWEyMDA1IiwiYSI6ImNtaW96bzBqaDAwZHYzZnB3anY1b2p5cGMifQ.7u4lEuhFpc_GhqaiBrUmTQ', 
                    },
                    userAgentPackageName: 'com.example.new_tripple',
                    tileProvider: CancellableNetworkTileProvider(),
                  ),
                  if (!_isLoadingGeoJson)
                    PolygonLayer(polygons: _countryPolygons),
                  
                  if (_showPins)
                    MarkerLayer(markers: markers),
                ],
              ),

              // 1. 左上: タイトル & 統合スタッツ
              Positioned(
                top: 0, left: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('World Map 🌍', style: AppTextStyles.h2.copyWith(fontSize: 28, shadows: [const Shadow(color: Colors.white, blurRadius: 10)])),
                        const SizedBox(height: 12),
                        
                        _buildGlassContainer(
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 130),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 上段: Total Score
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.emoji_events_rounded, color: AppColors.accent, size: 20),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Total Score', style: AppTextStyles.label.copyWith(fontSize: 10)),
                                            Text('$_totalScore pt', style: AppTextStyles.h3.copyWith(fontSize: 18, color: AppColors.primary)),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 16),
                                    GestureDetector(
                                      onTap: _showScoreInfoDialog,
                                      child: const Icon(Icons.info_outline_rounded, size: 18, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // 下段: Visited Countries
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.flag_rounded, color: AppColors.primary, size: 20),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Countries', style: AppTextStyles.label.copyWith(fontSize: 10)),
                                        Text('$visitedCount / 196', style: AppTextStyles.h3.copyWith(fontSize: 16)),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. 右上: ピン切り替え
              Positioned(
                top: 10, right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildGlassContainer(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_showPins ? 'Pins ON' : 'Pins OFF', style: AppTextStyles.label.copyWith(fontSize: 12)),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 40, height: 24,
                            child: CupertinoSwitch(
                              value: _showPins,
                              activeTrackColor: AppColors.accent,
                              onChanged: (value) => setState(() => _showPins = value),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              if (_isLoadingGeoJson)
                const Center(child: CircularProgressIndicator()),
            ],
          ),
        );
      },
    );
  }

  void _showScoreInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Travel Score Logic'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Score is calculated per country:'),
            const SizedBox(height: 8),
            _buildCalcRow('Visit Count', '× 5 pts'),
            _buildCalcRow('Stay Days', '× 1 pt'),
            const Divider(height: 16),
            const Text('Rank Colors:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // 👇 ホームカントリーの凡例追加
            _buildColorRow(AppColors.primary.withValues(alpha: 0.5), 'Home Country (Base)'),
            const SizedBox(height: 4),
            _buildColorRow(Colors.cyan, 'Lv1: (1-10) Start'),
            _buildColorRow(Colors.teal, 'Lv2: (11-20) 2nd Trip'),
            _buildColorRow(Colors.amber, 'Lv3: (21-30) Traveler'),
            _buildColorRow(Colors.orange, 'Lv4: (31-50) Expert'),
            _buildColorRow(Colors.deepOrange, 'Lv5: (51+) Master'),
            const SizedBox(height: 16),
            // 👇 注釈追加
            const Text(
              '※ Your Home Country is excluded from stats.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildGlassContainer({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }

  Widget _buildCalcRow(String label, String point) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(point, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildColorRow(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(width: 16, height: 16, decoration: BoxDecoration(color: color.withValues(alpha: 0.6), shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  List<Marker> _buildMarkers(List<Trip> trips) {
    final markers = <Marker>[];
    for (var trip in trips) {
      if (trip.tags != null) {
        if (trip.tags!.contains('past_trip')) continue;
      }
      if (trip.destinations.isEmpty) continue;
      for (var dest in trip.destinations) {
        if (dest.latitude == 0 && dest.longitude == 0) continue;
        markers.add(
          Marker(
            point: LatLng(dest.latitude, dest.longitude),
            width: 80,
            height: 90,
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: () => widget.onTripSelected(trip),
              child: _buildPhotoPin(trip.coverImageUrl),
            ),
          ),
        );
      }
    }
    return markers;
  }

  Widget _buildPhotoPin(String? imageUrl) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: imageUrl != null && imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.primary,
                      child: const Center(child: Icon(Icons.flight, color: Colors.white, size: 30)),
                    ),
                  )
                : Container(
                    color: AppColors.primary,
                    child: const Center(child: Icon(Icons.flight, color: Colors.white, size: 30)),
                  ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -4), 
          child: ClipPath(
            clipper: _TriangleClipper(),
            child: Container(
              width: 16,
              height: 12,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _CountryStats {
  int visitCount = 0;
  int stayDays = 0;
  int score = 0;
}

class _TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(0, 0);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}