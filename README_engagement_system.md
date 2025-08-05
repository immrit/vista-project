# سیستم امتیازدهی پست‌ها بر اساس تعامل

این سیستم پست‌ها را بر اساس مجموع لایک‌ها و کامنت‌ها (امتیاز تعامل) مرتب می‌کند.

## 🚀 نصب و راه‌اندازی

### 1. اجرای کوئریهای SQL

ابتدا فایل `sql_engagement_setup.sql` را در Supabase SQL Editor اجرا کنید:

```sql
-- این کوئریها را در Supabase SQL Editor اجرا کنید
-- فایل: sql_engagement_setup.sql
```

### 2. اضافه کردن فایل‌های پروایدر

فایل `lib/provider/engagement_posts_provider.dart` را به پروژه اضافه کنید.

### 3. بروزرسانی فایل publicPosts.dart

در فایل `lib/view/screen/PublicPosts/publicPosts.dart` تغییرات زیر را اعمال کنید:

```dart
// اضافه کردن import
import '../../../provider/engagement_posts_provider.dart';

// تغییر در کلاس _AllPostsPaginatedTab
final postsAsync = ref.watch(engagementPostsProvider);
final notifier = ref.watch(engagementPostsProvider.notifier);
```

## 📊 نحوه کارکرد

### الگوریتم امتیازدهی

```dart
// امتیاز تعامل = تعداد لایک‌ها + تعداد کامنت‌ها
final engagementScore = likeCount + commentCount;
```

### مرتب‌سازی

پست‌ها بر اساس:

1. **امتیاز تعامل** (نزولی) - پست‌های با تعامل بیشتر اول
2. **تاریخ ایجاد** (نزولی) - پست‌های جدیدتر اول

## 🔧 تنظیمات

### تغییر وزن‌ها

برای تغییر وزن لایک و کامنت، در فایل `engagement_posts_provider.dart`:

```dart
// در متد getPostsWithEngagementComplex
postsWithEngagement.sort((a, b) {
  // لایک وزن 1، کامنت وزن 2
  final scoreA = a.likeCount + (a.commentCount * 2);
  final scoreB = b.likeCount + (b.commentCount * 2);
  return scoreB.compareTo(scoreA);
});
```

### تغییر تعداد پست‌ها در هر صفحه

```dart
// در کلاس EngagementPostsNotifier
final int _limit = 15; // تغییر این مقدار
```

## 📈 بهینه‌سازی‌ها

### 1. INDEX های دیتابیس

```sql
-- INDEX های ضروری برای عملکرد بهتر
CREATE INDEX IF NOT EXISTS idx_likes_post_id ON likes(post_id);
CREATE INDEX IF NOT EXISTS idx_comments_post_id ON comments(post_id);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON posts(created_at DESC);
```

### 2. Materialized View

برای پست‌های با امتیاز بالا (> 5):

```sql
-- بروزرسانی خودکار هر 5 دقیقه
SELECT refresh_popular_posts();
```

### 3. Caching

```dart
// استفاده از کش محلی
final engagementCachedPostsProvider = StateNotifierProvider<...>
```

## 🎯 ویژگی‌ها

### ✅ پیاده‌سازی شده

- [x] مرتب‌سازی بر اساس امتیاز تعامل
- [x] Pagination با infinite scroll
- [x] Pull-to-refresh
- [x] Loading states
- [x] Error handling
- [x] Optimistic updates برای لایک
- [x] Caching محلی

### 🔄 Real-time Updates

```dart
// گوش دادن به تغییرات real-time
final realtimePostsProvider = StreamProvider<List<PublicPostModel>>((ref) {
  return supabase
      .from('posts_with_engagement')
      .stream(primaryKey: ['id'])
      .order('engagement_score', ascending: false);
});
```

## 🐛 عیب‌یابی

### مشکل: پست‌ها مرتب نمی‌شوند

1. بررسی کنید که VIEW `posts_with_engagement` ایجاد شده باشد
2. کوئری زیر را اجرا کنید:

```sql
SELECT * FROM posts_with_engagement LIMIT 10;
```

### مشکل: عملکرد کند

1. INDEX ها را بررسی کنید:

```sql
SELECT indexname, tablename FROM pg_indexes 
WHERE tablename IN ('posts', 'likes', 'comments');
```

2. از Materialized View استفاده کنید:

```sql
SELECT * FROM popular_posts LIMIT 10;
```

### مشکل: خطای Provider

```dart
// بررسی import ها
import '../../../provider/engagement_posts_provider.dart';

// بررسی provider
final postsAsync = ref.watch(engagementPostsProvider);
```

## 📱 استفاده در UI

### نمایش امتیاز تعامل

```dart
Widget _buildEngagementScore(PublicPostModel post) {
  final score = post.likeCount + post.commentCount;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.green,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      'امتیاز: $score',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
```

### فیلتر بر اساس امتیاز

```dart
// فیلتر پست‌های با امتیاز بالا
final highEngagementPosts = posts.where((post) {
  final score = post.likeCount + post.commentCount;
  return score > 10;
}).toList();
```

## 🔮 آینده

### ویژگی‌های پیشنهادی

- [ ] امتیازدهی وزنی (لایک = 1، کامنت = 2)
- [ ] در نظر گرفتن زمان (پست‌های جدیدتر امتیاز بیشتر)
- [ ] فیلتر بر اساس بازه زمانی
- [ ] آمار تعامل کاربران
- [ ] پیشنهاد پست‌های مشابه

### بهینه‌سازی‌های آینده

- [ ] Background processing برای محاسبه امتیازها
- [ ] Machine learning برای پیش‌بینی تعامل
- [ ] A/B testing برای الگوریتم‌های مختلف
- [ ] Analytics dashboard

## 📞 پشتیبانی

برای سوالات و مشکلات:

1. بررسی کنید که تمام کوئریهای SQL اجرا شده باشند
2. Log های کنسول را بررسی کنید
3. Provider ها را refresh کنید
4. اپلیکیشن را restart کنید

## 📝 تغییرات اخیر

### v1.0.0

- ✅ پیاده‌سازی اولیه سیستم امتیازدهی
- ✅ ایجاد VIEW و INDEX های مورد نیاز
- ✅ پروایدر جداگانه برای پست‌های با تعامل
- ✅ بروزرسانی UI برای استفاده از پروایدر جدید

### v1.1.0 (آینده)

- 🔄 امتیازدهی وزنی
- 🔄 Materialized View optimization
- 🔄 Real-time updates
