import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// لیست فونت‌های جایگزین برای نمایش صحیح ایموجی‌ها
const List<String> defaultFontFallback = [
  'Apple Color Emoji',
  'Segoe UI Emoji',
  'Segoe UI Symbol',
  'Noto Color Emoji',
  'Android Emoji',
  'EmojiSymbols',
  'Arial',
];

// enum برای رنگ‌های اصلی
enum ThemeColor {
  blue,
  red,
  yellow,
  teal,
  white, // رنگ سفید برای تم تاریک
}

// تابع برای ایجاد تم بر اساس رنگ و brightness
ThemeData createTheme(
  ThemeColor color, 
  Brightness brightness, {
  bool largeText = false,
  bool boldText = false,
  bool highContrast = false,
  String colorBlindMode = 'none',
}) {
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
      primaryColor = isDark ? Colors.white : Colors.black;
      break;
  }

  if (isDark) {
    // تم تاریک
    background = const Color(0xFF1E1E1E);
    surface = const Color(0xFF252525);

    // تعیین colorScheme بر اساس کنتراست
    final colorScheme = highContrast 
        ? ColorScheme.dark(
            primary: primaryColor,
            secondary: Colors.white,
            surface: surface,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: Colors.white,
            error: Colors.red[400]!,
            brightness: Brightness.dark,
          )
        : ColorScheme.dark(
            primary: primaryColor,
            secondary: surface,
            surface: surface,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: Colors.white,
          );
    
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      colorScheme: colorScheme,
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
      textTheme: _buildTextTheme(
        isDark: true,
        largeText: largeText,
        boldText: boldText,
      ),
    );
  } else {
    // تم روشن
    background = Colors.white;
    surface = color == ThemeColor.white
        ? Colors.white
        : (color == ThemeColor.blue
            ? Colors.grey[50]!
            : _getColorShade(color, 50));

    // تعیین colorScheme بر اساس کنتراست
    final colorScheme = highContrast
        ? ColorScheme.light(
            primary: primaryColor,
            secondary: Colors.black,
            surface: surface,
            onPrimary: Colors.white,
            onSecondary: color == ThemeColor.white ? Colors.black : primaryColor,
            onSurface: Colors.black87,
            error: Colors.red[700]!,
            brightness: Brightness.light,
          )
        : ColorScheme.light(
            primary: primaryColor,
            secondary: surface,
            surface: surface,
            onPrimary: Colors.white,
            onSecondary: color == ThemeColor.white ? Colors.black : primaryColor,
            onSurface: Colors.black87,
          );
    
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor:
            color == ThemeColor.white ? Colors.white : primaryColor,
        foregroundColor:
            color == ThemeColor.white ? Colors.black : Colors.white,
        iconTheme: IconThemeData(
          color: color == ThemeColor.white ? Colors.black : Colors.white,
        ),
        titleTextStyle: TextStyle(
          color: color == ThemeColor.white ? Colors.black : Colors.white,
          fontSize: 20,
        ),
        elevation: 0,
        systemOverlayStyle: color == ThemeColor.white
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),
      colorScheme: colorScheme,
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
      textTheme: _buildTextTheme(
        isDark: false,
        largeText: largeText,
        boldText: boldText,
      ),
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

// تابع برای اعمال color blind filter
ColorFilter? getColorBlindFilter(String colorBlindMode) {
  switch (colorBlindMode) {
    case 'protanopia':
      // Protanopia: قرمز-سبز (قرمز نمی‌بینند)
      return const ColorFilter.matrix([
        0.567, 0.433, 0.0, 0.0, 0.0,
        0.558, 0.442, 0.0, 0.0, 0.0,
        0.0, 0.242, 0.758, 0.0, 0.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
      ]);
    case 'deuteranopia':
      // Deuteranopia: قرمز-سبز (سبز نمی‌بینند)
      return const ColorFilter.matrix([
        0.625, 0.375, 0.0, 0.0, 0.0,
        0.7, 0.3, 0.0, 0.0, 0.0,
        0.0, 0.3, 0.7, 0.0, 0.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
      ]);
    case 'tritanopia':
      // Tritanopia: آبی-زرد (آبی نمی‌بینند)
      return const ColorFilter.matrix([
        0.95, 0.05, 0.0, 0.0, 0.0,
        0.0, 0.433, 0.567, 0.0, 0.0,
        0.0, 0.475, 0.525, 0.0, 0.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
      ]);
    case 'none':
    default:
      return null;
  }
}

// تابع کمکی برای ساخت TextTheme با تنظیمات دسترسی‌پذیری
TextTheme _buildTextTheme({
  required bool isDark,
  required bool largeText,
  required bool boldText,
}) {
  final baseSize = largeText ? 1.2 : 1.0;
  final fontWeight = boldText ? FontWeight.bold : FontWeight.normal;
  
  // تابع کمکی برای ساخت استایل با fontFamilyFallback
  TextStyle makeStyle(double fontSize, Color color) {
    return TextStyle(
      fontSize: fontSize * baseSize,
      fontWeight: fontWeight,
      color: color,
      fontFamily: 'Vazir',
      fontFamilyFallback: defaultFontFallback,
    );
  }
  
  // رنگ متن بر اساس تم
  final mainColor = isDark ? Colors.white : Colors.black87;
  final subColor = isDark ? Colors.grey[400] : Colors.grey[600];
  
  return TextTheme(
    displayLarge: makeStyle(57, mainColor),
    displayMedium: makeStyle(45, mainColor),
    displaySmall: makeStyle(36, mainColor),
    headlineLarge: makeStyle(32, mainColor),
    headlineMedium: makeStyle(28, mainColor),
    headlineSmall: makeStyle(24, mainColor),
    titleLarge: makeStyle(22, mainColor),
    titleMedium: makeStyle(16, mainColor),
    titleSmall: makeStyle(14, mainColor),
    bodyLarge: makeStyle(16, mainColor),
    bodyMedium: makeStyle(14, mainColor),
    bodySmall: makeStyle(12, subColor!),
    labelLarge: makeStyle(14, mainColor),
    labelMedium: makeStyle(12, mainColor),
    labelSmall: makeStyle(11, subColor),
  );
}

// تم‌های پیش‌فرض برای سازگاری با کد قبلی
final ThemeData lightTheme = createTheme(ThemeColor.blue, Brightness.light);
final ThemeData darkTheme = createTheme(ThemeColor.blue, Brightness.dark);
final ThemeData redWhiteTheme = createTheme(ThemeColor.red, Brightness.light);
final ThemeData yellowBlackTheme =
    createTheme(ThemeColor.yellow, Brightness.light);
final ThemeData tealWhiteTheme = createTheme(ThemeColor.teal, Brightness.light);
