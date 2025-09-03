# قابلیت استوری Vista

این قابلیت امکان ایجاد تصاویر استوری زیبا با بک‌گراند سفارشی و قابلیت جابجایی پست را فراهم می‌کند.

## ویژگی‌ها

### 🎨 طراحی زیبا

- **سایز استوری اینستاگرام**: نسبت 9:16 برای سازگاری کامل
- **بک‌گراند گرادیانت**: ترکیب رنگ‌های زیبا با الگوی هندسی
- **لوگو VISTA**: نمایش لوگو در مرکز با افکت‌های بصری

### 🎯 قابلیت‌های تعاملی

- **جابجایی پست**: امکان کشیدن و جابجایی پست روی بک‌گراند
- **پیش‌نمایش زنده**: نمایش لحظه‌ای تغییرات
- **کنترل موقعیت**: محدودیت جابجایی به داخل صفحه

### 📱 اشتراک‌گذاری

- **اینستاگرام استوری**: اشتراک مستقیم به اینستاگرام
- **ذخیره در گالری**: ذخیره تصویر نهایی
- **اشتراک عمومی**: ارسال به سایر اپ‌ها

## فایل‌های ایجاد شده

### 1. `story_post_widget.dart`

ویجت اصلی برای نمایش پست با بک‌گراند سفارشی:

- بک‌گراند گرادیانت با الگوی هندسی
- پست قابل جابجایی
- لوگو VISTA در مرکز
- سایز استوری اینستاگرام

### 2. `post_image_share_widget.dart`

صفحه مدیریت و اشتراک‌گذاری استوری:

- پیش‌نمایش زنده
- قالب ثابت با هدر VISTA
- دکمه‌های اشتراک‌گذاری
- ذخیره در گالری

### 3. `story_demo_widget.dart`

صفحه تست و نمایش قابلیت‌ها:

- پست نمونه برای تست
- راهنمای ویژگی‌ها
- دکمه تست

## نحوه استفاده

### 1. از طریق اشتراک‌گذاری پست

```dart
// در صفحه پست، دکمه اشتراک‌گذاری را فشار دهید
// سپس "اینستاگرام استوری" را انتخاب کنید
```

### 2. مستقیماً از کد

```dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => PostImageShareWidget(
      post: yourPost,
      onShareComplete: () {
        // کد پس از اشتراک‌گذاری
      },
    ),
  ),
);
```

### 3. تست قابلیت

```dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => const StoryDemoWidget(),
  ),
);
```

## تنظیمات

### تغییر سایز

```dart
StoryPostWidget(
  post: post,
  size: Size(1080, 1920), // سایز دلخواه
)
```

### تغییر موقعیت پست

```dart
StoryPostWidget(
  post: post,
  postOffset: Offset(100, 200), // موقعیت دلخواه
)
```

### غیرفعال کردن بک‌گراند

```dart
StoryPostWidget(
  post: post,
  showBackground: false,
)
```

## رنگ‌بندی

### حالت تاریک

- گرادیانت: `#1a1a2e` → `#16213e` → `#0f3460`
- متن: سفید با شفافیت

### حالت روشن

- گرادیانت: `#667eea` → `#764ba2` → `#f093fb`
- متن: سفید با شفافیت

## الگوی هندسی

الگوی پس‌زمینه شامل:

- دایره‌های کوچک با شفافیت کم
- خطوط مورب اتصال
- افکت عمق بصری

## مجوزها

برای ذخیره در گالری، مجوزهای زیر مورد نیاز است:

- `android.permission.WRITE_EXTERNAL_STORAGE`
- `ios.permission.PHOTO_LIBRARY`

## وابستگی‌ها

- `flutter_screenutil`: برای اندازه‌گیری واکنش‌گرا
- `gal`: برای دسترسی به گالری
- `share_plus`: برای اشتراک‌گذاری
- `cached_network_image`: برای بارگذاری تصاویر

## نکات مهم

1. **کیفیت تصویر**: رزولوشن 2.0 برای تعادل بین کیفیت و حجم
2. **حافظه**: فایل‌های موقت به صورت خودکار پاک می‌شوند
3. **عملکرد**: استفاده از `RepaintBoundary` برای بهینه‌سازی
4. **سازگاری**: پشتیبانی از تم تاریک و روشن

## مثال کامل

```dart
class MyPostScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('پست من'),
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PostImageShareWidget(
                    post: currentPost,
                    onShareComplete: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('استوری به اشتراک گذاشته شد!')),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: YourPostContent(),
    );
  }
}
```

## پشتیبانی

برای گزارش مشکلات یا پیشنهادات، لطفاً با تیم توسعه تماس بگیرید.
