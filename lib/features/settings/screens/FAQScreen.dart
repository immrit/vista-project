import 'package:flutter/material.dart';

class FAQScreen extends StatefulWidget {
  const FAQScreen({super.key});

  @override
  State<FAQScreen> createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<FAQItem> _faqItems = [
    // بخش حساب کاربری
    FAQItem(
      category: 'حساب کاربری',
      question: 'چگونه در ویستا ثبت‌نام کنم؟',
      answer: 'برای ثبت‌نام در ویستا:\n\n'
          '۱. اپلیکیشن را باز کنید\n'
          '۲. روی "ثبت‌نام" کلیک کنید\n'
          '۳. ایمیل خود را وارد کنید\n'
          '۴. رمز عبور قوی انتخاب کنید (حداقل ۶ کاراکتر)\n'
          '۵. رمز عبور را تأیید کنید\n'
          '۶. روی "ثبت‌نام" کلیک کنید\n'
          '۷. اطلاعات پروفایل خود را تکمیل کنید\n\n'
          'حداقل سن برای ثبت‌نام ۱۳ سال است.',
      icon: Icons.person_add,
      color: Colors.blue,
    ),
    FAQItem(
      category: 'حساب کاربری',
      question: 'چگونه رمز عبور خود را تغییر دهم؟',
      answer: 'برای تغییر رمز عبور:\n\n'
          '۱. به تنظیمات بروید\n'
          '۲. "حساب کاربری" را انتخاب کنید\n'
          '۳. "تغییر رمز عبور" را انتخاب کنید\n'
          '۴. رمز عبور فعلی را وارد کنید\n'
          '۵. رمز عبور جدید را وارد کنید\n'
          '۶. تغییرات را ذخیره کنید\n\n'
          'رمز عبور باید حداقل ۶ کاراکتر باشد.',
      icon: Icons.lock,
      color: Colors.orange,
    ),
    FAQItem(
      category: 'حساب کاربری',
      question: 'چگونه حساب کاربری خود را حذف کنم؟',
      answer: 'برای حذف حساب کاربری:\n\n'
          '۱. به تنظیمات بروید\n'
          '۲. "حساب کاربری" را انتخاب کنید\n'
          '۳. "حذف حساب" را انتخاب کنید\n'
          '۴. رمز عبور خود را تأیید کنید\n'
          '۵. دلیل حذف را انتخاب کنید\n'
          '۶. "حذف نهایی" را تأیید کنید\n\n'
          '⚠️ این عمل غیرقابل بازگشت است و تمام داده‌های شما حذف خواهد شد.',
      icon: Icons.delete_forever,
      color: Colors.red,
    ),
    FAQItem(
      category: 'حساب کاربری',
      question: 'چگونه پروفایل خود را ویرایش کنم؟',
      answer: 'برای ویرایش پروفایل:\n\n'
          '۱. روی عکس پروفایل خود کلیک کنید\n'
          '۲. "ویرایش پروفایل" را انتخاب کنید\n'
          '۳. اطلاعات مورد نظر را تغییر دهید:\n'
          '   • نام کاربری\n'
          '   • نام کامل\n'
          '   • بیوگرافی\n'
          '   • عکس پروفایل\n'
          '۴. تغییرات را ذخیره کنید\n\n'
          'نام کاربری باید منحصر به فرد باشد.',
      icon: Icons.edit,
      color: Colors.green,
    ),

    // بخش چت و پیام‌رسانی
    FAQItem(
      category: 'چت و پیام‌رسانی',
      question: 'چگونه با دوستانم چت کنم؟',
      answer: 'برای شروع چت:\n\n'
          '۱. روی آیکون چت در پایین صفحه کلیک کنید\n'
          '۲. "چت جدید" را انتخاب کنید\n'
          '۳. نام کاربری دوست خود را جستجو کنید\n'
          '۴. روی پروفایل او کلیک کنید\n'
          '۵. "شروع چت" را انتخاب کنید\n\n'
          'می‌توانید متن، تصویر، ویدیو و فایل ارسال کنید.',
      icon: Icons.chat,
      color: Colors.purple,
    ),
    FAQItem(
      category: 'چت و پیام‌رسانی',
      question: 'آیا پیام‌های من امن هستند؟',
      answer: 'بله، پیام‌های شما کاملاً امن هستند:\n\n'
          '• رمزگذاری End-to-End\n'
          '• هیچ کس نمی‌تواند پیام‌های شما را بخواند\n'
          '• حتی تیم ویستا دسترسی ندارد\n'
          '• پیام‌ها فقط روی دستگاه شما و گیرنده ذخیره می‌شوند\n'
          '• امکان حذف پیام‌ها برای هر دو طرف\n\n'
          'ویستا از پیشرفته‌ترین پروتکل‌های امنیتی استفاده می‌کند.',
      icon: Icons.security,
      color: Colors.indigo,
    ),
    FAQItem(
      category: 'چت و پیام‌رسانی',
      question: 'چگونه کاربری را مسدود کنم؟',
      answer: 'برای مسدود کردن کاربر:\n\n'
          '۱. به چت با آن کاربر بروید\n'
          '۲. روی نام کاربر کلیک کنید\n'
          '۳. "مسدود کردن" را انتخاب کنید\n'
          '۴. دلیل مسدود کردن را انتخاب کنید\n'
          '۵. "تأیید" را کلیک کنید\n\n'
          'کاربر مسدود شده:\n'
          '• نمی‌تواند به شما پیام بفرستد\n'
          '• پروفایل شما را نمی‌بیند\n'
          '• در جستجو نمایش داده نمی‌شود',
      icon: Icons.block,
      color: Colors.red,
    ),

    // بخش پست و محتوا
    FAQItem(
      category: 'پست و محتوا',
      question: 'چگونه پست جدید منتشر کنم؟',
      answer: 'برای انتشار پست:\n\n'
          '۱. روی آیکون "+" در پایین صفحه کلیک کنید\n'
          '۲. نوع محتوا را انتخاب کنید:\n'
          '   • متن\n'
          '   • تصویر\n'
          '   • ویدیو\n'
          '۳. محتوای خود را اضافه کنید\n'
          '۴. توضیحات و هشتگ‌ها را بنویسید\n'
          '۵. تنظیمات حریم خصوصی را انتخاب کنید\n'
          '۶. "انتشار" را کلیک کنید\n\n'
          'حداکثر سایز فایل: ۱۵ مگابایت\n'
          'فرمت‌های پشتیبانی شده: JPEG, PNG, GIF, WEBP',
      icon: Icons.add_circle,
      color: Colors.teal,
    ),
    FAQItem(
      category: 'پست و محتوا',
      question: 'چگونه استوری منتشر کنم؟',
      answer: 'برای انتشار استوری:\n\n'
          '۱. روی آیکون دوربین در بالای صفحه کلیک کنید\n'
          '۲. تصویر یا ویدیو بگیرید یا از گالری انتخاب کنید\n'
          '۳. فیلترها و استیکرها را اضافه کنید\n'
          '۴. متن یا نقاشی اضافه کنید\n'
          '۵. تنظیمات حریم خصوصی را انتخاب کنید\n'
          '۶. "انتشار" را کلیک کنید\n\n'
          'استوری‌ها ۲۴ ساعت نمایش داده می‌شوند.',
      icon: Icons.camera_alt,
      color: Colors.pink,
    ),
    FAQItem(
      category: 'پست و محتوا',
      question: 'چگونه پست کسی را گزارش کنم؟',
      answer: 'برای گزارش پست:\n\n'
          '۱. روی سه نقطه (⋯) در کنار پست کلیک کنید\n'
          '۲. "گزارش" را انتخاب کنید\n'
          '۳. نوع مشکل را انتخاب کنید:\n'
          '   • محتوای نامناسب\n'
          '   • اسپم\n'
          '   • آزار و اذیت\n'
          '   • نقض کپی‌رایت\n'
          '۴. توضیحات اضافی بنویسید\n'
          '۵. "ارسال گزارش" را کلیک کنید\n\n'
          'گزارش‌ها به صورت ناشناس بررسی می‌شوند.',
      icon: Icons.report,
      color: Colors.orange,
    ),

    // بخش امنیت
    FAQItem(
      category: 'امنیت',
      question: 'چگونه امنیت حساب خود را افزایش دهم؟',
      answer: 'برای افزایش امنیت:\n\n'
          '۱. رمز عبور قوی انتخاب کنید\n'
          '۲. تایید دو مرحله‌ای را فعال کنید\n'
          '۳. قفل اپلیکیشن را فعال کنید\n'
          '۴. از دستگاه‌های امن استفاده کنید\n'
          '۵. به‌طور منظم رمز عبور را تغییر دهید\n'
          '۶. از ورود از دستگاه‌های ناشناس خودداری کنید\n\n'
          'در صورت مشاهده فعالیت مشکوک، فوراً رمز عبور را تغییر دهید.',
      icon: Icons.shield,
      color: Colors.green,
    ),
    FAQItem(
      category: 'امنیت',
      question: 'تایید دو مرحله‌ای چیست؟',
      answer: 'تایید دو مرحله‌ای (2FA) یک لایه امنیتی اضافی است:\n\n'
          '• پس از وارد کردن رمز عبور، کد تایید ارسال می‌شود\n'
          '• کد از طریق SMS یا ایمیل دریافت می‌شود\n'
          '• حتی اگر رمز عبور شما لو برود، حساب امن می‌ماند\n'
          '• برای فعال‌سازی: تنظیمات > امنیت > تایید دو مرحله‌ای\n\n'
          'توصیه می‌شود حتماً این ویژگی را فعال کنید.',
      icon: Icons.verified_user,
      color: Colors.blue,
    ),

    // بخش موزیک
    FAQItem(
      category: 'موزیک',
      question: 'چگونه موزیک پخش کنم؟',
      answer: 'برای پخش موزیک:\n\n'
          '۱. به بخش موزیک بروید\n'
          '۲. آهنگ مورد نظر را جستجو کنید\n'
          '۳. روی آهنگ کلیک کنید\n'
          '۴. از کنترل‌های پخش استفاده کنید:\n'
          '   • پخش/توقف\n'
          '   • قبلی/بعدی\n'
          '   • تنظیم صدا\n'
          '   • تکرار\n\n'
          'می‌توانید پلی‌لیست شخصی ایجاد کنید.',
      icon: Icons.music_note,
      color: Colors.purple,
    ),
    FAQItem(
      category: 'موزیک',
      question: 'آیا می‌توانم موزیک آپلود کنم؟',
      answer: 'بله، می‌توانید موزیک آپلود کنید:\n\n'
          '• فرمت‌های پشتیبانی شده: MP3, M4A\n'
          '• حداکثر سایز فایل: ۱۰ مگابایت\n'
          '• باید مالک قانونی موزیک باشید\n'
          '• رعایت حقوق کپی‌رایت الزامی است\n'
          '• امکان اضافه کردن کاور و ژانر\n\n'
          '⚠️ آپلود موزیک غیرقانونی منجر به حذف حساب می‌شود.',
      icon: Icons.upload,
      color: Colors.amber,
    ),

    // بخش جستجو
    FAQItem(
      category: 'جستجو',
      question: 'چگونه در ویستا جستجو کنم؟',
      answer: 'ویستا دو نوع جستجو دارد:\n\n'
          '**جستجوی کاربران:**\n'
          '• نام کاربری یا ایمیل را تایپ کنید\n'
          '• نتایج بر اساس تطابق نمایش داده می‌شود\n'
          '• امکان مشاهده پروفایل کاربران\n\n'
          '**جستجوی هشتگ‌ها:**\n'
          '• با # شروع کنید (مثل #ویستا)\n'
          '• پست‌های مرتبط با هشتگ نمایش داده می‌شود\n'
          '• امکان ذخیره جستجوهای اخیر\n\n'
          'تاریخچه جستجو تا ۲۰ مورد ذخیره می‌شود.',
      icon: Icons.search,
      color: Colors.indigo,
    ),
    FAQItem(
      category: 'جستجو',
      question: 'چگونه تاریخچه جستجو را پاک کنم؟',
      answer: 'برای پاک کردن تاریخچه جستجو:\n\n'
          '۱. به صفحه جستجو بروید\n'
          '۲. روی آیکون سطل زباله کلیک کنید\n'
          '۳. "پاک کردن" را تأیید کنید\n\n'
          'همچنین می‌توانید:\n'
          '• جستجوهای فردی را با کشیدن به چپ حذف کنید\n'
          '• جستجوهای قدیمی خودکار حذف می‌شوند',
      icon: Icons.delete_sweep,
      color: Colors.red,
    ),

    // بخش استوری
    FAQItem(
      category: 'استوری',
      question: 'چگونه استوری منتشر کنم؟',
      answer: 'برای انتشار استوری:\n\n'
          '۱. روی آیکون دوربین در بالای صفحه کلیک کنید\n'
          '۲. تصویر یا ویدیو بگیرید یا از گالری انتخاب کنید\n'
          '۳. فیلترها و استیکرها را اضافه کنید\n'
          '۴. متن یا نقاشی اضافه کنید\n'
          '۵. تنظیمات حریم خصوصی را انتخاب کنید\n'
          '۶. "انتشار" را کلیک کنید\n\n'
          '**محدودیت‌ها:**\n'
          '• حداکثر سایز: ۱۵ مگابایت\n'
          '• فرمت‌های پشتیبانی: JPEG, PNG, GIF, WEBP\n'
          '• مدت نمایش: ۲۴ ساعت',
      icon: Icons.camera_alt,
      color: Colors.pink,
    ),
    FAQItem(
      category: 'استوری',
      question: 'چگونه استوری کسی را گزارش کنم؟',
      answer: 'برای گزارش استوری:\n\n'
          '۱. روی استوری کلیک کنید\n'
          '۲. روی سه نقطه (⋯) کلیک کنید\n'
          '۳. "گزارش" را انتخاب کنید\n'
          '۴. نوع مشکل را انتخاب کنید:\n'
          '   • محتوای نامناسب\n'
          '   • آزار و اذیت\n'
          '   • نقض کپی‌رایت\n'
          '۵. توضیحات اضافی بنویسید\n'
          '۶. "ارسال گزارش" را کلیک کنید\n\n'
          'گزارش‌ها به صورت ناشناس بررسی می‌شوند.',
      icon: Icons.report,
      color: Colors.orange,
    ),

    // بخش آفلاین
    FAQItem(
      category: 'آفلاین',
      question: 'آیا می‌توانم بدون اینترنت از ویستا استفاده کنم؟',
      answer: 'بله، ویستا قابلیت‌های آفلاین دارد:\n\n'
          '• مشاهده پیام‌های قبلی\n'
          '• مشاهده پست‌های کش شده\n'
          '• پخش موزیک‌های دانلود شده\n'
          '• مشاهده پروفایل‌های کش شده\n'
          '• تنظیمات شخصی\n\n'
          'برای استفاده کامل از ویستا، اتصال اینترنت لازم است.',
      icon: Icons.offline_bolt,
      color: Colors.grey,
    ),

    // بخش محدودیت‌ها
    FAQItem(
      category: 'محدودیت‌ها',
      question: 'محدودیت‌های فایل در ویستا چیست؟',
      answer: 'محدودیت‌های فایل در ویستا:\n\n'
          '**تصاویر:**\n'
          '• حداکثر سایز: ۱۵ مگابایت\n'
          '• فرمت‌های پشتیبانی: JPEG, PNG, GIF, WEBP\n\n'
          '**ویدیو:**\n'
          '• حداکثر سایز: ۵۰ مگابایت\n'
          '• فرمت‌های پشتیبانی: MP4, MOV, MKV\n'
          '• مدت زمان: کاربر عادی ۱ دقیقه، کاربر ویژه ۲ دقیقه\n\n'
          '**موزیک:**\n'
          '• حداکثر سایز: ۱۰ مگابایت\n'
          '• فرمت‌های پشتیبانی: MP3, M4A\n\n'
          '**استوری:**\n'
          '• حداکثر سایز: ۱۵ مگابایت\n'
          '• مدت نمایش: ۲۴ ساعت',
      icon: Icons.info,
      color: Colors.blue,
    ),

    // بخش مشکلات فنی
    FAQItem(
      category: 'مشکلات فنی',
      question: 'اپلیکیشن کند کار می‌کند، چه کنم؟',
      answer: 'برای بهبود عملکرد:\n\n'
          '۱. اپلیکیشن را ببندید و دوباره باز کنید\n'
          '۲. کش اپلیکیشن را پاک کنید\n'
          '۳. دستگاه را ریستارت کنید\n'
          '۴. فضای خالی دستگاه را بررسی کنید\n'
          '۵. اپلیکیشن را به‌روزرسانی کنید\n'
          '۶. در صورت ادامه مشکل، با پشتیبانی تماس بگیرید\n\n'
          'ویستا برای عملکرد بهینه طراحی شده است.',
      icon: Icons.speed,
      color: Colors.orange,
    ),
    FAQItem(
      category: 'مشکلات فنی',
      question: 'چگونه کش اپلیکیشن را پاک کنم؟',
      answer: 'برای پاک کردن کش:\n\n'
          '۱. به تنظیمات بروید\n'
          '۲. "حافظه و ذخیره‌سازی" را انتخاب کنید\n'
          '۳. "پاک کردن کش" را انتخاب کنید\n'
          '۴. نوع کش را انتخاب کنید:\n'
          '   • کش تصاویر\n'
          '   • کش پیام‌ها\n'
          '   • کش موزیک\n'
          '   • تمام کش\n'
          '۵. "تأیید" را کلیک کنید\n\n'
          'این کار فضای ذخیره‌سازی را آزاد می‌کند.',
      icon: Icons.cleaning_services,
      color: Colors.cyan,
    ),

    // بخش ویژگی‌های خاص
    FAQItem(
      category: 'ویژگی‌های خاص',
      question: 'نشان ویژه چیست و چه کاربردی دارد؟',
      answer: 'نشان ویژه نمادی است که اعتبار حساب شما را نشان می‌دهد:\n\n'
          '**مزایای نشان ویژه:**\n'
          '• اعتبار و شهرت بیشتر\n'
          '• ویدیوهای طولانی‌تر (تا ۲ دقیقه)\n'
          '• اولویت در نتایج جستجو\n'
          '• دسترسی به امکانات انحصاری\n'
          '• پشتیبانی ویژه\n\n'
          '**نحوه دریافت:**\n'
          '• از طریق فروشگاه ویستا\n'
          '• با پرداخت هزینه ماهانه\n'
          '• قابل تمدید یا لغو',
      icon: Icons.verified,
      color: Colors.amber,
    ),
    FAQItem(
      category: 'ویژگی‌های خاص',
      question: 'چگونه ویدیو آپلود کنم؟',
      answer: 'برای آپلود ویدیو:\n\n'
          '۱. روی "+" در پایین صفحه کلیک کنید\n'
          '۲. "ویدیو" را انتخاب کنید\n'
          '۳. ویدیو را از گالری انتخاب کنید\n'
          '۴. توضیحات و هشتگ‌ها را اضافه کنید\n'
          '۵. "انتشار" را کلیک کنید\n\n'
          '**محدودیت‌ها:**\n'
          '• کاربر عادی: حداکثر ۱ دقیقه\n'
          '• کاربر ویژه: حداکثر ۲ دقیقه\n'
          '• حداکثر سایز: ۵۰ مگابایت\n'
          '• فرمت‌های پشتیبانی: MP4, MOV, MKV',
      icon: Icons.video_library,
      color: Colors.red,
    ),
    FAQItem(
      category: 'ویژگی‌های خاص',
      question: 'چگونه در چت فایل ارسال کنم؟',
      answer: 'برای ارسال فایل در چت:\n\n'
          '۱. چت مورد نظر را باز کنید\n'
          '۲. روی آیکون گیره کاغذ کلیک کنید\n'
          '۳. نوع فایل را انتخاب کنید:\n'
          '   • تصویر\n'
          '   • ویدیو\n'
          '   • موزیک\n'
          '   • فایل\n'
          '۴. فایل را انتخاب کنید\n'
          '۵. "ارسال" را کلیک کنید\n\n'
          '**محدودیت‌ها:**\n'
          '• حداکثر سایز: ۵۰ مگابایت\n'
          '• فرمت‌های پشتیبانی: تمام فرمت‌های رایج\n'
          '• موزیک: حداکثر ۱۰ مگابایت',
      icon: Icons.attach_file,
      color: Colors.blue,
    ),

    // بخش پشتیبانی
    FAQItem(
      category: 'پشتیبانی',
      question: 'چگونه با پشتیبانی تماس بگیرم؟',
      answer: 'راه‌های تماس با پشتیبانی:\n\n'
          '• ایمیل: support@cafevista.ir\n'
          '• پشتیبانی درون‌برنامه‌ای\n'
          '• بخش "تماس با ما" در تنظیمات\n'
          '• گزارش مشکل در اپلیکیشن\n\n'
          'زمان پاسخ‌دهی:\n'
          '• سوالات عمومی: ۲۴ ساعت\n'
          '• مشکلات فنی: ۱۲ ساعت\n'
          '• مشکلات امنیتی: فوری',
      icon: Icons.support_agent,
      color: Colors.teal,
    ),
    FAQItem(
      category: 'پشتیبانی',
      question: 'آیا ویستا رایگان است؟',
      answer: 'ویستا کاملاً رایگان است:\n\n'
          '• تمام ویژگی‌های اصلی رایگان\n'
          '• چت و پیام‌رسانی رایگان\n'
          '• انتشار پست و استوری رایگان\n'
          '• پخش موزیک رایگان\n'
          '• پشتیبانی رایگان\n\n'
          'ویژگی‌های اضافی:\n'
          '• نشان ویژه (اختیاری)\n'
          '• امکانات پیشرفته (اختیاری)',
      icon: Icons.free_breakfast,
      color: Colors.green,
    ),
  ];

  List<FAQItem> get _filteredItems {
    if (_searchQuery.isEmpty) {
      return _faqItems;
    }
    return _faqItems.where((item) {
      return item.question.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.answer.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.category.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  List<String> get _categories {
    return _faqItems.map((item) => item.category).toSet().toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('سوالات متداول'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // نوار جستجو
          Container(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'جستجو در سوالات...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
              ),
            ),
          ),

          // فیلتر دسته‌بندی
          if (_searchQuery.isEmpty)
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(category),
                      selected: false,
                      onSelected: (selected) {
                        // می‌توانید فیلتر دسته‌بندی اضافه کنید
                      },
                    ),
                  );
                },
              ),
            ),

          // لیست سوالات
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                final item = _filteredItems[index];
                return _buildFAQItem(item, isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(FAQItem item, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              item.icon,
              color: item.color,
              size: 20,
            ),
          ),
          title: Text(
            item.question,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          subtitle: Text(
            item.category,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                item.answer,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.justify,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class FAQItem {
  final String category;
  final String question;
  final String answer;
  final IconData icon;
  final Color color;

  FAQItem({
    required this.category,
    required this.question,
    required this.answer,
    required this.icon,
    required this.color,
  });
}
