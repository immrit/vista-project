# بهینه‌سازی‌های پیشنهادی برای سیستم امتیازدهی پست‌ها

## 1. بهینه‌سازی‌های دیتابیس

### الف) ایجاد INDEX های مناسب

```sql
-- Index برای بهبود عملکرد JOIN ها
CREATE INDEX IF NOT EXISTS idx_likes_post_id ON likes(post_id);
CREATE INDEX IF NOT EXISTS idx_comments_post_id ON comments(post_id);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON posts(created_at DESC);

-- Index ترکیبی برای بهبود عملکرد
CREATE INDEX IF NOT EXISTS idx_posts_engagement ON posts(created_at DESC) 
INCLUDE (id, content, user_id);
```

### ب) استفاده از Materialized View برای پست‌های پرطرفدار

```sql
-- ایجاد Materialized View برای پست‌های با امتیاز بالا
CREATE MATERIALIZED VIEW popular_posts AS
SELECT 
    p.id,
    p.content,
    p.user_id,
    p.created_at,
    COALESCE(l.like_count, 0) as like_count,
    COALESCE(c.comment_count, 0) as comment_count,
    COALESCE(l.like_count, 0) + COALESCE(c.comment_count, 0) as engagement_score
FROM posts p
LEFT JOIN (
    SELECT post_id, COUNT(*) as like_count
    FROM likes
    GROUP BY post_id
) l ON p.id = l.post_id
LEFT JOIN (
    SELECT post_id, COUNT(*) as comment_count
    FROM comments
    GROUP BY post_id
) c ON p.id = c.post_id
WHERE COALESCE(l.like_count, 0) + COALESCE(c.comment_count, 0) > 10
ORDER BY engagement_score DESC, p.created_at DESC;

-- ایجاد Index برای Materialized View
CREATE INDEX idx_popular_posts_score ON popular_posts(engagement_score DESC, created_at DESC);

-- بروزرسانی خودکار Materialized View (هر 5 دقیقه)
-- این کار را می‌توانید با Cron Job یا Supabase Edge Functions انجام دهید
```

### ج) استفاده از Caching در Supabase

```sql
-- فعال‌سازی Query Result Caching
-- در Supabase Dashboard > Settings > Database > Query Result Caching
```

## 2. بهینه‌سازی‌های Flutter

### الف) استفاده از Pagination هوشمند

```dart
// استفاده از AutoDispose برای مدیریت حافظه
final postsWithEngagementProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, int>((ref, page) async {
  // کد موجود
});
```

### ب) استفاده از Caching محلی

```dart
// استفاده از Hive برای کش کردن پست‌ها
class PostCacheService {
  static const String _boxName = 'posts_cache';
  
  Future<void> cachePosts(List<Map<String, dynamic>> posts) async {
    final box = await Hive.openBox(_boxName);
    await box.put('cached_posts', posts);
    await box.put('cache_timestamp', DateTime.now().millisecondsSinceEpoch);
  }
  
  Future<List<Map<String, dynamic>>?> getCachedPosts() async {
    final box = await Hive.openBox(_boxName);
    final timestamp = box.get('cache_timestamp') as int?;
    
    if (timestamp != null) {
      final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      // کش را فقط برای 5 دقیقه معتبر در نظر می‌گیریم
      if (cacheAge < 5 * 60 * 1000) {
        return List<Map<String, dynamic>>.from(box.get('cached_posts') ?? []);
      }
    }
    return null;
  }
}
```

### ج) استفاده از Lazy Loading برای تصاویر

```dart
// استفاده از CachedNetworkImage برای کش کردن تصاویر
CachedNetworkImage(
  imageUrl: post['image_url'],
  placeholder: (context, url) => const CircularProgressIndicator(),
  errorWidget: (context, url, error) => const Icon(Icons.error),
  memCacheWidth: 300, // محدود کردن اندازه تصویر در حافظه
)
```

## 3. بهینه‌سازی‌های الگوریتمی

### الف) استفاده از امتیازدهی وزنی

```sql
-- امتیازدهی با وزن‌های مختلف برای لایک و کامنت
SELECT 
    p.id,
    p.content,
    p.user_id,
    p.created_at,
    COALESCE(l.like_count, 0) as like_count,
    COALESCE(c.comment_count, 0) as comment_count,
    -- لایک وزن 1 و کامنت وزن 2 دارد
    COALESCE(l.like_count, 0) + (COALESCE(c.comment_count, 0) * 2) as weighted_score
FROM posts p
-- ... rest of the query
```

### ب) در نظر گرفتن زمان در امتیازدهی

```sql
-- امتیازدهی با در نظر گرفتن زمان (پست‌های جدیدتر امتیاز بیشتری می‌گیرند)
SELECT 
    p.id,
    p.content,
    p.user_id,
    p.created_at,
    COALESCE(l.like_count, 0) as like_count,
    COALESCE(c.comment_count, 0) as comment_count,
    -- فرمول Reddit-style scoring
    (COALESCE(l.like_count, 0) + COALESCE(c.comment_count, 0)) * 
    POWER(EXTRACT(EPOCH FROM (NOW() - p.created_at)) / 45000, 1.5) as time_weighted_score
FROM posts p
-- ... rest of the query
ORDER BY time_weighted_score DESC;
```

## 4. بهینه‌سازی‌های عملکرد

### الف) استفاده از Background Processing

```dart
// محاسبه امتیازها در پس‌زمینه
class EngagementCalculator {
  static Future<void> calculateEngagementScores() async {
    // محاسبه امتیازها در پس‌زمینه
    // ذخیره نتایج در جدول جداگانه
  }
}
```

### ب) استفاده از Real-time Updates

```dart
// گوش دادن به تغییرات Real-time
final realtimePostsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final supabase = Supabase.instance.client;
  return supabase
      .from('posts_with_engagement')
      .stream(primaryKey: ['id'])
      .order('engagement_score', ascending: false)
      .limit(20);
});
```

## 5. نکات امنیتی

### الف) Rate Limiting

```dart
// محدود کردن تعداد درخواست‌ها
class RateLimiter {
  static final Map<String, DateTime> _lastRequest = {};
  
  static bool canMakeRequest(String endpoint) {
    final now = DateTime.now();
    final lastRequest = _lastRequest[endpoint];
    
    if (lastRequest == null || 
        now.difference(lastRequest).inSeconds > 1) {
      _lastRequest[endpoint] = now;
      return true;
    }
    return false;
  }
}
```

### ب) Validation داده‌ها

```dart
// اعتبارسنجی داده‌های ورودی
class PostValidator {
  static bool isValidPost(Map<String, dynamic> post) {
    return post['id'] != null && 
           post['content'] != null && 
           post['content'].toString().isNotEmpty;
  }
}
```

## 6. مانیتورینگ و Analytics

### الف) ثبت آمار عملکرد

```dart
class PerformanceMonitor {
  static void logQueryTime(String queryName, Duration duration) {
    print('Query $queryName took ${duration.inMilliseconds}ms');
    // ارسال به سرویس Analytics
  }
}
```

### ب) مانیتورینگ استفاده از حافظه

```dart
// بررسی استفاده از حافظه
void checkMemoryUsage() {
  final memoryInfo = ProcessInfo.currentRss;
  if (memoryInfo > 100 * 1024 * 1024) { // 100MB
    // پاک کردن کش‌ها
    clearCaches();
  }
}
```
