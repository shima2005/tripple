import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:new_tripple/models/enums.dart';
import 'package:new_tripple/models/step_detail.dart';
import 'package:url_launcher/url_launcher.dart'; // url_launcherを追加

class RouteResult {
  final String? polyline;
  final int durationMinutes;
  final double distanceMeters;
  final List<StepDetail> steps;
  final String? externalLink; // 👇 追加

  RouteResult({
    this.polyline,
    required this.durationMinutes,
    required this.distanceMeters,
    this.steps = const [],
    this.externalLink, // 👇 追加
  });
}

class RoutingService {
  final String _accessToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
  static const String _baseUrl = 'https://api.mapbox.com/directions/v5/mapbox';

  final Map<String, RouteResult> _cache = {};

  Future<RouteResult> getRouteInfo({
    required LatLng start,
    required LatLng end,
    required TransportType type,
  }) async {
    final cacheKey = '${start.latitude},${start.longitude}_${end.latitude},${end.longitude}_${type.name}';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;
    
    // 公共交通などはMapbox非対応 -> フォールバック(概算) + GoogleMapリンク
    if (isPublicTransport(type)) {
      final result = _getFallbackRoute(start, end, type);
      _cache[cacheKey] = result;
      return result;
    }

    // Mapbox対応タイプ
    String profile = 'driving';
    if (type == TransportType.walk) profile = 'walking';
    else if (type == TransportType.bicycle) profile = 'cycling';
    
    final url = Uri.parse(
      '$_baseUrl/$profile/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=polyline&overview=full&steps=true&access_token=$_accessToken'
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry'] as String;
          final durationSeconds = (route['duration'] as num).toDouble();
          final distanceMeters = (route['distance'] as num).toDouble();
          
          final steps = [
            StepDetail(
              customInstruction: '${type.displayName}で移動',
              durationMinutes: (durationSeconds / 60).ceil(),
              transportType: type,
            )
          ];

          final result = RouteResult(
            polyline: geometry,
            durationMinutes: (durationSeconds / 60).ceil(),
            distanceMeters: distanceMeters,
            steps: steps,
            // 徒歩や車でもGoogleMapで見たい場合のためにリンク生成
            externalLink: _generateGoogleMapsUrl(start, end, type),
          );
          
          _cache[cacheKey] = result;
          return result;
        }
      }
    } catch (e) {
      print('Routing Error: $e');
    }
    
    // 失敗時はフォールバック
    return _getFallbackRoute(start, end, type);
  }

  bool isPublicTransport(TransportType type) {
    return type == TransportType.train || 
           type == TransportType.bus || 
           type == TransportType.plane || 
           type == TransportType.subway || 
           type == TransportType.shinkansen || 
           type == TransportType.ferry || 
           type == TransportType.transit ||
           type == TransportType.other;
  }

  RouteResult _getFallbackRoute(LatLng start, LatLng end, TransportType type) {
    final distance = const Distance().as(LengthUnit.Meter, start, end);
    double speedKmh = 30.0;
    if (type == TransportType.walk) speedKmh = 4.0;
    if (type == TransportType.bicycle) speedKmh = 15.0;
    if (type == TransportType.plane) speedKmh = 800.0;
    if (type == TransportType.shinkansen) speedKmh = 200.0;

    final durationHours = (distance / 1000) / speedKmh;
    final durationMinutes = (durationHours * 60).ceil();

    return RouteResult(
      polyline: _encodePolyline([start, end]),
      durationMinutes: durationMinutes < 1 ? 1 : durationMinutes,
      distanceMeters: distance,
      steps: [
        StepDetail(
          customInstruction: '${type.displayName}で移動 (概算)',
          durationMinutes: durationMinutes < 1 ? 1 : durationMinutes,
          transportType: type,
        )
      ],
      // 👇 フォールバック時もしっかりGoogleMapリンクを生成
      externalLink: _generateGoogleMapsUrl(start, end, type),
    );
  }

  // 👇 Google Maps URL生成メソッド
  String _generateGoogleMapsUrl(LatLng start, LatLng end, TransportType type) {
    String travelMode = 'driving';
    if (type == TransportType.walk) travelMode = 'walking';
    if (type == TransportType.bicycle) travelMode = 'bicycling';
    // 公共交通系はすべて transit
    if (isPublicTransport(type)) {
      travelMode = 'transit';
    }

    return 'https://www.google.com/maps/dir/?api=1'
           '&origin=${start.latitude},${start.longitude}'
           '&destination=${end.latitude},${end.longitude}'
           '&travelmode=$travelMode';
  }

  // 外部ブラウザで開くヘルパー
  Future<void> openExternalMaps(String? url) async {
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _encodePolyline(List<LatLng> points) {
    var result = StringBuffer();
    int lastLat = 0;
    int lastLng = 0;
    for (final point in points) {
      int lat = (point.latitude * 1e5).round();
      int lng = (point.longitude * 1e5).round();
      _encode(lat - lastLat, result);
      _encode(lng - lastLng, result);
      lastLat = lat;
      lastLng = lng;
    }
    return result.toString();
  }

  void _encode(int value, StringBuffer result) {
    value = value < 0 ? ~(value << 1) : (value << 1);
    while (value >= 0x20) {
      result.writeCharCode((0x20 | (value & 0x1f)) + 63);
      value >>= 5;
    }
    result.writeCharCode(value + 63);
  }
}