import 'package:flutter/material.dart';

// enum برای رنگ‌های اصلی
enum ThemeColor {
  blue,
  red,
  yellow,
  teal,
  white, // رنگ سفید برای تم تاریک
}

// تابع برای ایجاد تم بر اساس رنگ و brightness
ThemeData createTheme(ThemeColor color, Brightness brightness) {
  final bool isDark = brightness == Brightness.dark;

  // تعیین رنگ اصلی بر اساس انتخاب
  Color primaryColor;
  Color background;
  Color surface;

  switch (color) {
    case ThemeColor.blue:
      primaryColor = isDark ? Colors.blue[300]! : Colors.blue[700]!;
      break;
    case ThemeColor.red:
      primaryColor = isDark ? Colors.red[300]! : Colors.red[700]!;
      break;
    case ThemeColor.yellow:
      primaryColor = isDark ? Colors.amber[300]! : Colors.amber[700]!;
      break;
    case ThemeColor.teal:
      primaryColor = isDark ? Colors.teal[300]! : Colors.teal[700]!;
      break;
    case ThemeColor.white:
      primaryColor = isDark ? Colors.white : Colors.grey[800]!;
      break;
  }

  if (isDark) {
    // تم تاریک
    background = const Color(0xFF1E1E1E);
    surface = const Color(0xFF252525);

    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        color: surface,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
        elevation: 0,
      ),
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        secondary: surface,
        surface: surface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primaryColor,
        unselectedItemColor: const Color(0xFF8899A6),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      cardColor: surface,
      dividerColor: const Color(0xFF323232),
      fontFamily: 'Vazir',
    );
  } else {
    // تم روشن
    background = Colors.white;
    surface = color == ThemeColor.blue
        ? Colors.grey[50]!
        : color == ThemeColor.white
            ? Colors.grey[100]!
            : _getColorShade(color, 50);

    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        color: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
        elevation: 0,
      ),
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: surface,
        surface: surface,
        onPrimary: Colors.white,
        onSecondary: primaryColor,
        onSurface: Colors.black87,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      cardColor: Colors.white,
      dividerColor: Colors.grey[300],
      fontFamily: 'Vazir',
    );
  }
}

// تابع کمکی برای گرفتن سایه رنگ
Color _getColorShade(ThemeColor color, int shade) {
  switch (color) {
    case ThemeColor.red:
      return Colors.red[shade]!;
    case ThemeColor.yellow:
      return Colors.amber[shade]!;
    case ThemeColor.teal:
      return Colors.teal[shade]!;
    case ThemeColor.blue:
      return Colors.blue[shade]!;
    case ThemeColor.white:
      return Colors.grey[shade]!;
  }
}

// تم‌های پیش‌فرض برای سازگاری با کد قبلی
final ThemeData lightTheme = createTheme(ThemeColor.blue, Brightness.light);
final ThemeData darkTheme = createTheme(ThemeColor.blue, Brightness.dark);
final ThemeData redWhiteTheme = createTheme(ThemeColor.red, Brightness.light);
final ThemeData yellowBlackTheme =
    createTheme(ThemeColor.yellow, Brightness.light);
final ThemeData tealWhiteTheme = createTheme(ThemeColor.teal, Brightness.light);
