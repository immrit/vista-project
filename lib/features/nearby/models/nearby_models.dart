// Models for the "اطراف من" (Nearby / dating) feature.

class NearbyCandidate {
  final String userId;
  final String username;
  final String fullName;
  final String avatarUrl;
  final String bio;
  final String gender;
  final String maritalStatus;
  final int age; // 0 = hidden/unknown
  final String locationText;
  final bool isVerified;
  final String verificationType;
  final double distanceKm;
  final String? lastSeenAt; // ISO 8601, null = unknown
  // Zone fields — populated by backend when available; fallback uses distance.
  final String? zone; // same_city | same_province | other_province
  final String? cityName;
  final String? provinceName;
  final bool isOnlineNow; // true = currently connected socket

  const NearbyCandidate({
    required this.userId,
    required this.username,
    required this.fullName,
    required this.avatarUrl,
    required this.bio,
    required this.gender,
    required this.maritalStatus,
    required this.age,
    required this.locationText,
    required this.isVerified,
    required this.verificationType,
    required this.distanceKm,
    this.lastSeenAt,
    this.zone,
    this.cityName,
    this.provinceName,
    this.isOnlineNow = false,
  });

  factory NearbyCandidate.fromJson(Map<String, dynamic> j) => NearbyCandidate(
        userId: j['user_id'] as String? ?? '',
        username: j['username'] as String? ?? '',
        fullName: j['full_name'] as String? ?? '',
        avatarUrl: j['avatar_url'] as String? ?? '',
        bio: j['bio'] as String? ?? '',
        gender: j['gender'] as String? ?? '',
        maritalStatus: j['marital_status'] as String? ?? '',
        age: (j['age'] as num?)?.toInt() ?? 0,
        locationText: j['location_text'] as String? ?? '',
        isVerified: j['is_verified'] as bool? ?? false,
        verificationType: j['verification_type'] as String? ?? '',
        distanceKm: (j['distance_km'] as num?)?.toDouble() ?? 0,
        lastSeenAt: j['last_seen_at'] as String?,
        zone: j['zone'] as String?,
        cityName: j['city_name'] as String?,
        provinceName: j['province_name'] as String?,
        isOnlineNow: j['is_online_now'] as bool? ?? false,
      );

  /// Zone type: from backend or derived from distance as fallback.
  /// Values: same_city | same_province | other_province
  String get zoneType {
    if (zone != null && zone!.isNotEmpty) return zone!;
    if (distanceKm < 30) return 'same_city';
    if (distanceKm < 200) return 'same_province';
    return 'other_province';
  }

  /// The candidate's city — the single, always-shown place label. Falls back to
  /// province, then empty (caller hides the chip). Never returns vague text.
  String get cityLabel {
    if (cityName != null && cityName!.isNotEmpty) return cityName!;
    if (provinceName != null && provinceName!.isNotEmpty) return provinceName!;
    return '';
  }

  /// Presence label: "آنلاین" / "X دقیقه پیش".
  String get presenceLabel {
    if (isOnlineNow) return 'آنلاین';
    if (lastSeenAt == null) return 'اخیراً آنلاین';
    final t = DateTime.tryParse(lastSeenAt!);
    if (t == null) return 'اخیراً آنلاین';
    final diff = DateTime.now().difference(t.toLocal()).inMinutes;
    if (diff <= 1) return 'همین الان آنلاین بود';
    if (diff < 60) return '$diff دقیقه پیش';
    return 'اخیراً آنلاین';
  }

  /// True if user was online within the last 20 minutes (or lastSeenAt unknown).
  bool get isRecentlyOnline {
    if (isOnlineNow) return true;
    if (lastSeenAt == null) return true;
    final t = DateTime.tryParse(lastSeenAt!);
    if (t == null) return true;
    return DateTime.now().difference(t.toLocal()).inMinutes <= 20;
  }

  /// City + concrete distance, e.g. "تهران • ۳ کیلومتر". City always wins;
  /// distance is dropped when zero/unknown (random-online mode).
  String get locationLine {
    final city = cityLabel;
    final d = distanceLabel;
    if (city.isEmpty) return d;
    if (d.isEmpty) return city;
    return '$city • $d';
  }

  /// Concrete distance only — no vague "همین نزدیکی". Empty when zero/unknown.
  String get distanceLabel {
    if (distanceKm <= 0) return '';
    if (distanceKm < 1) return '${(distanceKm * 1000).round()} متر';
    if (distanceKm < 10) return '${distanceKm.toStringAsFixed(1)} کیلومتر';
    return '${distanceKm.round()} کیلومتر';
  }
}

class NearbyMatch {
  final String matchId;
  final String userId;
  final String username;
  final String fullName;
  final String avatarUrl;
  final bool isVerified;
  final String matchedAt;

  const NearbyMatch({
    required this.matchId,
    required this.userId,
    required this.username,
    required this.fullName,
    required this.avatarUrl,
    required this.isVerified,
    required this.matchedAt,
  });

  factory NearbyMatch.fromJson(Map<String, dynamic> j) => NearbyMatch(
        matchId: j['match_id'] as String? ?? '',
        userId: j['user_id'] as String? ?? '',
        username: j['username'] as String? ?? '',
        fullName: j['full_name'] as String? ?? '',
        avatarUrl: j['avatar_url'] as String? ?? '',
        isVerified: j['is_verified'] as bool? ?? false,
        matchedAt: j['matched_at'] as String? ?? '',
      );
}

class NearbyPreferences {
  final String interestedIn; // male | female | all
  final int minAge;
  final int maxAge;
  final int maxDistanceKm;
  final String maritalPref; // all | single | married
  final bool isEnabled; // currently discoverable
  final bool hasLocation; // a location was ever shared

  const NearbyPreferences({
    required this.interestedIn,
    required this.minAge,
    required this.maxAge,
    required this.maxDistanceKm,
    required this.maritalPref,
    required this.isEnabled,
    required this.hasLocation,
  });

  factory NearbyPreferences.fromJson(Map<String, dynamic> j) =>
      NearbyPreferences(
        interestedIn: j['interested_in'] as String? ?? 'all',
        minAge: (j['min_age'] as num?)?.toInt() ?? 18,
        maxAge: (j['max_age'] as num?)?.toInt() ?? 60,
        maxDistanceKm: (j['max_distance_km'] as num?)?.toInt() ?? 50,
        maritalPref: j['marital_pref'] as String? ?? 'all',
        isEnabled: j['is_enabled'] as bool? ?? false,
        hasLocation: j['has_location'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'interested_in': interestedIn,
        'min_age': minAge,
        'max_age': maxAge,
        'max_distance_km': maxDistanceKm,
        'marital_pref': maritalPref,
      };

  NearbyPreferences copyWith({
    String? interestedIn,
    int? minAge,
    int? maxAge,
    int? maxDistanceKm,
    String? maritalPref,
    bool? isEnabled,
    bool? hasLocation,
  }) =>
      NearbyPreferences(
        interestedIn: interestedIn ?? this.interestedIn,
        minAge: minAge ?? this.minAge,
        maxAge: maxAge ?? this.maxAge,
        maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
        maritalPref: maritalPref ?? this.maritalPref,
        isEnabled: isEnabled ?? this.isEnabled,
        hasLocation: hasLocation ?? this.hasLocation,
      );
}

/// One person who liked the viewer, awaiting a response.
class NearbyReceivedLike {
  final String userId;
  final String username;
  final String fullName;
  final String avatarUrl;
  final bool isVerified;
  final String action; // like | superlike

  const NearbyReceivedLike({
    required this.userId,
    required this.username,
    required this.fullName,
    required this.avatarUrl,
    required this.isVerified,
    required this.action,
  });

  factory NearbyReceivedLike.fromJson(Map<String, dynamic> j) =>
      NearbyReceivedLike(
        userId: j['user_id'] as String? ?? '',
        username: j['username'] as String? ?? '',
        fullName: j['full_name'] as String? ?? '',
        avatarUrl: j['avatar_url'] as String? ?? '',
        isVerified: j['is_verified'] as bool? ?? false,
        action: j['action'] as String? ?? 'like',
      );
}

/// Received-likes list plus its total pending count (for the badge).
class NearbyReceivedLikes {
  final int count;
  final List<NearbyReceivedLike> likes;
  const NearbyReceivedLikes({required this.count, required this.likes});
}

class NearbyLikeResult {
  final bool matched;
  final String matchId;
  final NearbyMatch? match;

  const NearbyLikeResult(
      {required this.matched, required this.matchId, this.match});

  factory NearbyLikeResult.fromJson(Map<String, dynamic> j) => NearbyLikeResult(
        matched: j['matched'] as bool? ?? false,
        matchId: j['match_id'] as String? ?? '',
        match: j['match'] is Map<String, dynamic>
            ? NearbyMatch.fromJson(j['match'] as Map<String, dynamic>)
            : null,
      );
}
