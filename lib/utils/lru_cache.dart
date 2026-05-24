import 'dart:collection';

/// ✅ LRU Cache - مثل ویستا
/// یک cache با الگوریتم Least Recently Used برای مدیریت حافظه
class LRUCache<K, V> {
  final int _maxSize;
  final LinkedHashMap<K, V> _cache = LinkedHashMap();

  LRUCache(this._maxSize);

  /// دریافت مقدار از cache
  /// اگر key موجود باشد، آن را به انتهای لیست منتقل می‌کند (most recently used)
  V? get(K key) {
    if (!_cache.containsKey(key)) return null;

    // Move to end (most recently used)
    final value = _cache.remove(key) as V;
    _cache[key] = value;
    return value;
  }

  /// اضافه کردن یا به‌روزرسانی مقدار در cache
  /// اگر cache پر باشد، قدیمی‌ترین item حذف می‌شود
  void put(K key, V value) {
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    } else if (_cache.length >= _maxSize) {
      // Remove least recently used (first item)
      _cache.remove(_cache.keys.first);
    }

    _cache[key] = value;
  }

  /// حذف یک key از cache
  void remove(K key) {
    _cache.remove(key);
  }

  /// پاک کردن تمام cache
  void clear() {
    _cache.clear();
  }

  /// تعداد item های موجود در cache
  int get length => _cache.length;

  /// بررسی وجود key در cache
  bool containsKey(K key) => _cache.containsKey(key);

  /// دریافت تمام keys
  Iterable<K> get keys => _cache.keys;

  /// دریافت تمام values
  Iterable<V> get values => _cache.values;
}
