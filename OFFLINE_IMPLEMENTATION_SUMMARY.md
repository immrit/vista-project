# پیاده‌سازی سیستم کش آفلاین برای ویستا

## خلاصه تغییرات

این پیاده‌سازی شامل دو بخش اصلی است:

### 1. کش پروفایل و پست‌ها (Profile Cache)

#### فایل‌های جدید

- `lib/DB/profile_cache_service.dart` - سرویس کش پروفایل و آخرین 10 پست هر کاربر

#### ویژگی‌ها

- ✅ کش کردن پروفایل کاربران
- ✅ کش کردن آخرین 10 پست هر کاربر
- ✅ ذخیره در حافظه و دیسک
- ✅ اعتبار کش 2 ساعته
- ✅ به‌روزرسانی پس‌زمینه
- ✅ پشتیبانی از حالت آفلاین

#### تغییرات در فایل‌های موجود

- `lib/provider/provider.dart` - به‌روزرسانی ProfileNotifier برای استفاده از کش
- `lib/main.dart` - مقداردهی اولیه سرویس کش پروفایل

### 2. کش تنظیمات (Settings Cache)

#### فایل‌های جدید

- `lib/DB/settings_cache_service.dart` - سرویس کش تنظیمات کاربر
- `lib/provider/settings_providers.dart` - Providerهای جدید برای تنظیمات آفلاین
- `lib/view/screen/Settings/subpages/OfflineSettingsPage.dart` - صفحه تنظیمات آفلاین

#### ویژگی‌ها

- ✅ کش کردن تنظیمات کاربر
- ✅ کش کردن تنظیمات اپلیکیشن
- ✅ کش کردن تنظیمات حریم خصوصی
- ✅ کش کردن تنظیمات اعلان‌ها
- ✅ اعتبار کش 24 ساعته
- ✅ پشتیبانی کامل از حالت آفلاین

#### تغییرات در فایل‌های موجود

- `lib/view/screen/Settings/Settings.dart` - اضافه کردن لینک به تنظیمات آفلاین
- `lib/view/screen/Settings/subpages/StorageAndMemorySettingsPage.dart` - بهبود برای کار آفلاین

### 3. تست عملکرد آفلاین

#### فایل جدید

- `lib/test_offline_functionality.dart` - صفحه تست عملکرد آفلاین

#### ویژگی‌ها

- ✅ تست مقداردهی اولیه سرویس‌ها
- ✅ تست کش کردن تنظیمات
- ✅ تست دریافت آمار کش
- ✅ تست اعتبار کش
- ✅ رابط کاربری برای نمایش نتایج

## نحوه استفاده

### برای پروفایل

```dart
// دریافت پروفایل (اول از کش، سپس از سرور)
final profile = await profileCache.getProfile(userId);

// دریافت پست‌های کاربر
final posts = await profileCache.getUserPosts(userId);

// اضافه کردن پست جدید به کش
await profileCache.addPostToCache(userId, newPost);
```

### برای تنظیمات

```dart
// دریافت تنظیمات اپلیکیشن
final appSettings = await settingsCache.getAppSettings();

// دریافت تنظیمات حریم خصوصی
final privacySettings = await settingsCache.getPrivacySettings(userId);

// به‌روزرسانی تنظیمات
await settingsCache.updateAppSettings(newSettings);
```

## مزایای پیاده‌سازی

1. **عملکرد بهتر**: دسترسی سریع به داده‌های کش شده
2. **تجربه کاربری بهتر**: کار در حالت آفلاین
3. **کاهش مصرف اینترنت**: استفاده از داده‌های کش شده
4. **قابلیت اطمینان**: پشتیبانی از حالت آفلاین
5. **مدیریت حافظه**: محدودیت حجم کش و پاکسازی خودکار

## تنظیمات کش

### پروفایل

- حداکثر 10 پست برای هر کاربر
- اعتبار کش: 2 ساعت
- ذخیره در حافظه و دیسک

### تنظیمات

- اعتبار کش: 24 ساعت
- ذخیره در حافظه و دیسک
- به‌روزرسانی خودکار

## تست و بررسی

برای تست عملکرد آفلاین:

1. به تنظیمات بروید
2. "تست عملکرد آفلاین" را انتخاب کنید
3. نتایج تست را مشاهده کنید

## نکات مهم

1. کش به صورت خودکار مقداردهی می‌شود
2. در صورت عدم دسترسی به اینترنت، از کش استفاده می‌شود
3. کش در پس‌زمینه به‌روزرسانی می‌شود
4. حجم کش محدود است و مدیریت می‌شود

## فایل‌های کلیدی

- `lib/DB/profile_cache_service.dart` - کش پروفایل
- `lib/DB/settings_cache_service.dart` - کش تنظیمات
- `lib/provider/settings_providers.dart` - Providerهای تنظیمات
- `lib/view/screen/Settings/subpages/OfflineSettingsPage.dart` - صفحه آفلاین
- `lib/test_offline_functionality.dart` - تست عملکرد

این پیاده‌سازی باعث بهبود قابل توجه تجربه کاربری و عملکرد اپلیکیشن در حالت آفلاین می‌شود.

