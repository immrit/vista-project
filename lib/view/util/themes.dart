import 'package:flutter/material.dart';

// تم روشن
final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: Colors.white,
  scaffoldBackgroundColor: Colors.white,
  appBarTheme: const AppBarTheme(
    color: Colors.white,
    iconTheme: IconThemeData(color: Colors.black),
    titleTextStyle: TextStyle(color: Colors.black, fontSize: 20),
    elevation: 0,
  ),
  colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.grey).copyWith(
    secondary: Colors.black,
    onPrimary: Colors.black,
    onSecondary: Colors.white,
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    selectedItemColor: Colors.black,
    unselectedItemColor: Colors.grey,
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: Colors.black,
    foregroundColor: Colors.white,
  ),
  fontFamily: 'Vazir',
);

// تم تاریک
final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: const Color(0xFF1E1E1E), // Charcoal base
  scaffoldBackgroundColor: const Color(0xFF1E1E1E), // Main background
  appBarTheme: const AppBarTheme(
    color: Color(0xFF252525), // Slightly lighter
    iconTheme: IconThemeData(color: Colors.white),
    titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
    elevation: 0,
  ),
  colorScheme: const ColorScheme.dark(
    primary: Colors.white, // Changed from blue to white
    secondary: Color(0xFF252525),
    surface: Color(0xFF252525),
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: Colors.white,
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: Colors.white,
    foregroundColor: Colors.black,
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Color(0xFF252525), // Nav bar background
    selectedItemColor: Colors.white, // Changed from blue to white
    unselectedItemColor: Color(0xFF8899A6),
  ),
  cardColor: const Color(0xFF252525),
  dividerColor: const Color(0xFF323232),
  fontFamily: 'Vazir',
);

// تم قرمز و سفید
final ThemeData redWhiteTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: Colors.red,
  scaffoldBackgroundColor: Colors.red[50],
  appBarTheme: AppBarTheme(
    color: Colors.red[200],
    iconTheme: const IconThemeData(color: Colors.white),
    titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
    elevation: 0,
  ),
  colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.red).copyWith(
    secondary: Colors.white,
    onPrimary: Colors.white,
    onSecondary: Colors.red,
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    selectedItemColor: Colors.red[400],
    unselectedItemColor: Colors.red[200],
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: Colors.red[400],
    foregroundColor: Colors.white,
  ),
  fontFamily: 'Vazir',
);

// تم زرد و مشکی
final ThemeData yellowBlackTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: Colors.yellow[700],
  scaffoldBackgroundColor: Colors.white,
  appBarTheme: AppBarTheme(
    color: Colors.yellow[700],
    iconTheme: const IconThemeData(color: Colors.black),
    titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20),
    elevation: 0,
  ),
  colorScheme: ColorScheme.light(
    primary: Colors.yellow[700]!,
    secondary: Colors.black,
    onPrimary: Colors.black,
    onSecondary: Colors.yellow,
    surface: Colors.yellow[100]!,
    onSurface: Colors.black,
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    selectedItemColor: Colors.yellow[700],
    unselectedItemColor: Colors.grey,
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: Colors.yellow[700],
    foregroundColor: Colors.black,
  ),
  fontFamily: 'Vazir',
);

// تم teal و سفید
// تم teal و سفید بهبود یافته
final ThemeData tealWhiteTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: Colors.teal[700],
  scaffoldBackgroundColor: Colors.teal[50],
  appBarTheme: AppBarTheme(
    color: Colors.teal[700],
    iconTheme: const IconThemeData(color: Colors.white),
    titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
    elevation: 0,
  ),
  colorScheme: ColorScheme.light(
    primary: Colors.teal[700]!,
    secondary: Colors.white,
    onPrimary: Colors.white,
    onSecondary: Colors.teal,
    surface: Colors.teal[100]!,
    onSurface: Colors.teal[900]!,
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    selectedItemColor: Colors.teal[700],
    unselectedItemColor: Colors.teal[200],
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: Colors.teal[700],
    foregroundColor: Colors.white,
  ),
  fontFamily: 'Vazir',
);
