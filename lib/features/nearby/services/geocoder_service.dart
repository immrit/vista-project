import 'package:dio/dio.dart';

/// City + province resolved for a location. [source] records how it was found
/// ("gps" via Nominatim, "ip" via IP geolocation) for diagnostics.
class GeocoderResult {
  final String cityName;
  final String provinceName;
  final String source;
  const GeocoderResult({
    required this.cityName,
    required this.provinceName,
    this.source = 'gps',
  });

  bool get hasCity => cityName.isNotEmpty;
}

/// Resolves a coordinate to city + province, with a two-tier strategy:
///
///  1. **GPS → Nominatim** (OpenStreetMap reverse geocoding). Free, Persian
///     names, most accurate when GPS is good.
///  2. **IP geolocation fallback** (ipwho.is, HTTPS, no key) when Nominatim
///     yields no city — so a user whose city couldn't be reverse-geocoded still
///     gets a city from their IP.
///
/// Both tiers are non-throwing; the caller treats null as "send coords only".
/// Results cache in memory keyed by coordinate rounded to 1 decimal (~11 km).
class GeocoderService {
  GeocoderService._();

  static final _nominatim = Dio(BaseOptions(
    baseUrl: 'https://nominatim.openstreetmap.org',
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    headers: {
      // Nominatim requires a descriptive User-Agent.
      'User-Agent': 'VistaApp/1.0 (contact@vistaapp.ir)',
      'Accept-Language': 'fa,en',
    },
  ));

  static final _ip = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 6),
    receiveTimeout: const Duration(seconds: 6),
  ));

  // In-memory cache — keyed by "lat1_lng1" (1 decimal = ~11 km precision).
  // City/province boundaries don't change, so a process-lifetime cache is fine.
  static final Map<String, GeocoderResult> _cache = {};

  static String _key(double lat, double lng) =>
      '${lat.toStringAsFixed(1)}_${lng.toStringAsFixed(1)}';

  /// Returns city + province for [lat]/[lng], or null when every tier fails.
  static Future<GeocoderResult?> lookup(double lat, double lng) async {
    final key = _key(lat, lng);
    final cached = _cache[key];
    if (cached != null) return cached;

    // Tier 1 — GPS reverse geocoding (preferred, Persian).
    final viaGps = await _nominatimLookup(lat, lng);
    if (viaGps != null && viaGps.hasCity) {
      _cache[key] = viaGps;
      return viaGps;
    }

    // Tier 2 — IP geolocation fallback (city couldn't be reverse-geocoded).
    final viaIp = await _ipLookup();
    if (viaIp != null && viaIp.hasCity) {
      _cache[key] = viaIp;
      return viaIp;
    }

    // Whatever partial GPS data we got (e.g. province only), else null.
    if (viaGps != null) _cache[key] = viaGps;
    return viaGps;
  }

  static Future<GeocoderResult?> _nominatimLookup(double lat, double lng) async {
    try {
      final resp = await _nominatim.get('/reverse', queryParameters: {
        'lat': lat,
        'lon': lng,
        'format': 'jsonv2',
        'zoom': 10, // city level (10 = city, 12 = suburb, 8 = county)
        'addressdetails': 1,
      });

      final data = resp.data;
      if (data is! Map) return null;
      final address = data['address'] as Map<String, dynamic>?;
      if (address == null) return null;

      // Nominatim uses different keys per country/region type.
      final city = _firstNonEmpty(address, const [
        'city',
        'town',
        'village',
        'municipality',
        'county',
        'district',
      ]);
      final province = _firstNonEmpty(address, const [
        'state',
        'province',
        'region',
      ]);

      return GeocoderResult(
        cityName: city,
        provinceName: province,
        source: 'gps',
      );
    } catch (_) {
      return null;
    }
  }

  /// IP-based city lookup via ipwho.is (HTTPS, free, no key). Returns the city
  /// of the caller's public IP — a coarse but useful fallback.
  static Future<GeocoderResult?> _ipLookup() async {
    try {
      final resp = await _ip.get('https://ipwho.is/');
      final data = resp.data;
      if (data is! Map) return null;
      if (data['success'] == false) return null;

      final city = (data['city'] as String?)?.trim() ?? '';
      // ipwho.is returns the province in `region` (e.g. "Tehran Province").
      final province = (data['region'] as String?)?.trim() ?? '';
      if (city.isEmpty && province.isEmpty) return null;

      return GeocoderResult(
        cityName: city,
        provinceName: province,
        source: 'ip',
      );
    } catch (_) {
      return null;
    }
  }

  static String _firstNonEmpty(
    Map<String, dynamic> address,
    List<String> keys,
  ) {
    for (final k in keys) {
      final v = address[k];
      if (v is String && v.isNotEmpty) return v;
    }
    return '';
  }
}
