# راهنمای نهایی پیاده‌سازی سیستم امتیازدهی پست‌ها

## 🎯 خلاصه تغییرات

بر اساس ساختار واقعی جداول شما، سیستم امتیازدهی پست‌ها بر اساس تعامل پیاده‌سازی شده است.

### ساختار جداول شما

- ✅ `posts` با فیلدهای `likes_count`, `comments_count`, `engagement_score`
- ✅ `likes` با `post_id` و `user_id`
- ✅ `comments` با `post_id` و `owner_id`
- ✅ فیلد `status` برای فیلتر کردن پست‌های منتشر شده

## 📋 مراحل اجرا

### مرحله 1: اجرای کوئریهای SQL

فایل `sql_engagement_corrected.sql` را در Supabase SQL Editor اجرا کنید:

```sql
-- این کوئریها را در Supabase SQL Editor اجرا کنید
-- فایل: sql_engagement_corrected.sql
```

**نکات مهم:**

- ✅ از فیلدهای موجود `likes_count` و `comments_count` استفاده می‌کند
- ✅ فقط پست‌های با `status = 'published'` را نمایش می‌دهد
- ✅ `engagement_score` را بر اساس `likes_count + comments_count` محاسبه می‌کند
- ✅ Trigger برای بروزرسانی خودکار `engagement_score` ایجاد می‌کند

### مرحله 2: اضافه کردن فایل پروایدر

فایل `lib/provider/engagement_posts_provider.dart` را به پروژه اضافه کنید.

**ویژگی‌های پروایدر:**

- ✅ از فیلدهای موجود در جدول استفاده می‌کند
- ✅ مرتب‌سازی بر اساس `engagement_score` (نزولی)
- ✅ Pagination با infinite scroll
- ✅ بررسی لایک کاربر فعلی
- ✅ Error handling کامل

### مرحله 3: بروزرسانی فایل publicPosts.dart

تغییرات زیر در فایل `lib/view/screen/PublicPosts/publicPosts.dart` اعمال شده:

```dart
// اضافه کردن import
import '../../../provider/engagement_posts_provider.dart';

// تغییر در کلاس _AllPostsPaginatedTab
final postsAsync = ref.watch(engagementPostsProvider);
final notifier = ref.watch(engagementPostsProvider.notifier);
```

## 🔧 تست سیستم

### تست 1: بررسی VIEW

```sql
SELECT 
    id, 
    content, 
    likes_count, 
    comments_count, 
    engagement_score,
    created_at
FROM posts_with_engagement 
ORDER BY engagement_score DESC 
LIMIT 10;
```

### تست 2: بررسی Function

```sql
SELECT * FROM get_posts_with_engagement(5, 0);
```

### تست 3: بررسی Trigger

```sql
-- بروزرسانی یک پست و بررسی engagement_score
UPDATE posts 
SET likes_count = likes_count + 1 
WHERE id = 'your_post_id';

-- بررسی بروزرسانی خودکار
SELECT engagement_score FROM posts WHERE id = 'your_post_id';
```

## 📊 نحوه کارکرد

### الگوریتم امتیازدهی

```dart
engagement_score = likes_count + comments_count
```

### مرتب‌سازی

1. **امتیاز تعامل** (نزولی) - پست‌های با تعامل بیشتر اول
2. **تاریخ ایجاد** (نزولی) - پست‌های جدیدتر اول

### فیلترها

- فقط پست‌های با `status = 'published'`
- حذف پست‌های draft و archived

## 🚀 ویژگی‌های پیاده‌سازی شده

### ✅ دیتابیس

- VIEW برای نمایش پست‌ها با امتیاز تعامل
- Stored Function برای pagination
- Trigger برای بروزرسانی خودکار
- INDEX های بهینه‌سازی شده

### ✅ Flutter

- پروایدر جداگانه برای پست‌های با تعامل
- Pagination با infinite scroll
- Pull-to-refresh
- Loading states
- Error handling
- Optimistic updates برای لایک

### ✅ UI

- نمایش پست‌ها بر اساس امتیاز تعامل
- آمار لایک و کامنت
- امکان لایک/آنلایک
- نمایش وضعیت لایک کاربر

## 🐛 عیب‌یابی

### مشکل: پست‌ها مرتب نمی‌شوند

```sql
-- بررسی VIEW
SELECT COUNT(*) FROM posts_with_engagement;

-- بررسی engagement_score
SELECT id, engagement_score, likes_count, comments_count 
FROM posts 
WHERE status = 'published' 
ORDER BY engagement_score DESC 
LIMIT 5;
```

### مشکل: عملکرد کند

```sql
-- بررسی INDEX ها
SELECT indexname, tablename FROM pg_indexes 
WHERE tablename IN ('posts', 'likes', 'comments');

-- بررسی آمار
SELECT 
    COUNT(*) as total_posts,
    AVG(engagement_score) as avg_engagement
FROM posts_with_engagement;
```

### مشکل: خطای Provider

```dart
// بررسی import
import '../../../provider/engagement_posts_provider.dart';

// بررسی provider
final postsAsync = ref.watch(engagementPostsProvider);
```

## 📈 بهینه‌سازی‌های آینده

### 🔄 امتیازدهی وزنی

```sql
-- لایک وزن 1، کامنت وزن 2
engagement_score = likes_count + (comments_count * 2)
```

### 🔄 در نظر گرفتن زمان

```sql
-- فرمول Reddit-style
engagement_score = (likes_count + comments_count) * 
                   POWER(EXTRACT(EPOCH FROM (NOW() - created_at)) / 45000, 1.5)
```

### 🔄 Materialized View

```sql
-- برای پست‌های با امتیاز بالا
CREATE MATERIALIZED VIEW popular_posts AS
SELECT * FROM posts_with_engagement 
WHERE engagement_score > 10;
```

## ✅ چک‌لیست نهایی

- [ ] کوئریهای SQL اجرا شده‌اند
- [ ] فایل پروایدر اضافه شده است
- [ ] فایل publicPosts.dart بروزرسانی شده است
- [ ] VIEW `posts_with_engagement` کار می‌کند
- [ ] Function `get_posts_with_engagement` کار می‌کند
- [ ] Trigger بروزرسانی خودکار کار می‌کند
- [ ] پست‌ها بر اساس امتیاز تعامل مرتب می‌شوند
- [ ] Pagination کار می‌کند
- [ ] لایک/آنلایک کار می‌کند

## 🎉 نتیجه

حالا تب "همه پست‌ها" پست‌ها را بر اساس مجموع لایک‌ها و کامنت‌ها مرتب می‌کند و پست‌های با تعامل بیشتر در بالای لیست نمایش داده می‌شوند.

**نکته:** سیستم از فیلدهای موجود در جدول شما استفاده می‌کند و نیازی به تغییر ساختار جداول نیست.
