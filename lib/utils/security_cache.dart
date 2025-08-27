// ============================================================================
// SECURITY CACHE SERVICE
// ============================================================================

class SecurityCache {
  static final Map<String, dynamic> _cache = {};
  static const Duration _defaultTTL = Duration(minutes: 6);

  static void store(String key, dynamic value, {Duration? ttl}) {
    final expiry = DateTime.now().add(ttl ?? _defaultTTL);
    _cache[key] = {
      'value': value,
      'expires_at': expiry,
    };
  }

  static T? retrieve<T>(String key) {
    final item = _cache[key];
    if (item == null) return null;

    final expiresAt = item['expires_at'] as DateTime;
    if (DateTime.now().isAfter(expiresAt)) {
      _cache.remove(key);
      return null;
    }

    return item['value'] as T?;
  }

  static void clear() {
    _cache.clear();
  }

  static void remove(String key) {
    _cache.remove(key);
  }

  static bool has(String key) {
    return _cache.containsKey(key) && !_isExpired(key);
  }

  static bool _isExpired(String key) {
    final item = _cache[key];
    if (item == null) return true;

    final expiresAt = item['expires_at'] as DateTime;
    return DateTime.now().isAfter(expiresAt);
  }

  static Map<String, dynamic> getStats() {
    return {
      'size': _cache.length,
      'keys': _cache.keys.toList(),
    };
  }
}

