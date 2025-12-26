import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class GeocodingService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org/search';

  /// 場所名から候補を検索する
  Future<List<PlaceSearchResult>> searchPlaces(String query) async {
    if (query.isEmpty) return [];

    // addressdetails=1 で詳細な住所情報（国名など）が取れる
    final url = Uri.parse(
      '$_baseUrl?q=$query&format=json&addressdetails=1&limit=5',
    );

    try {
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'TrippleApp/1.0', 
        },
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((item) => PlaceSearchResult.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load places');
      }
    } catch (e) {
      print('Geocoding Error: $e');
      return [];
    }
  }

  Future<PlaceSearchResult?> searchPlace({required String query}) async {
    // 既存の searchPlaces (複数取得) を呼んで、先頭を返すだけ
    final results = await searchPlaces(query);
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }
}

/// 検索結果モデル (国名に対応！)
class PlaceSearchResult {
  final String name;
  final String address;
  final String? country;
  final String? countryCode; // 👈 追加: マッチングの要！(ISO alpha-2: jp, us, fr...)
  final String? state;
  final LatLng location;

  PlaceSearchResult({
    required this.name,
    required this.address,
    this.country,
    this.countryCode,
    this.state,
    required this.location,
  });

  factory PlaceSearchResult.fromJson(Map<String, dynamic> json) {
    final displayName = json['display_name'] as String;
    final parts = displayName.split(',');
    String name = parts.first.trim();
    String address = parts.length > 1 ? parts.sublist(1).join(',').trim() : "";

    final addressInfo = json['address'] as Map<String, dynamic>?;
    
    return PlaceSearchResult(
      name: name,
      address: address,
      country: addressInfo?['country'] as String?,
      countryCode: addressInfo?['country_code'] as String?,
      state: addressInfo?['state'] as String? ?? addressInfo?['province'] as String?,
      location: LatLng(
        double.parse(json['lat']),
        double.parse(json['lon']),
      ),
    );
  }
  
}