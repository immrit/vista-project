import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Responsive Design Constants for Vista App
/// Using flutter_screenutil for consistent scaling across devices
/// Design based on iPhone X (375x812) as reference

class AppTextStyles {
  // Heading Styles
  static TextStyle get heading1 => TextStyle(
        fontSize: ScreenUtil().setSp(32),
        fontWeight: FontWeight.bold,
        fontFamily: 'Vazir',
        height: 1.2,
      );

  static TextStyle get heading2 => TextStyle(
        fontSize: ScreenUtil().setSp(28),
        fontWeight: FontWeight.bold,
        fontFamily: 'Vazir',
        height: 1.25,
      );

  static TextStyle get heading3 => TextStyle(
        fontSize: ScreenUtil().setSp(24),
        fontWeight: FontWeight.w600,
        fontFamily: 'Vazir',
        height: 1.3,
      );

  static TextStyle get heading4 => TextStyle(
        fontSize: ScreenUtil().setSp(20),
        fontWeight: FontWeight.w600,
        fontFamily: 'Vazir',
        height: 1.35,
      );

  // Body Text Styles
  static TextStyle get bodyLarge => TextStyle(
        fontSize: ScreenUtil().setSp(18),
        fontWeight: FontWeight.normal,
        fontFamily: 'Vazir',
        height: 1.5,
      );

  static TextStyle get bodyMedium => TextStyle(
        fontSize: ScreenUtil().setSp(16),
        fontWeight: FontWeight.normal,
        fontFamily: 'Vazir',
        height: 1.5,
      );

  static TextStyle get bodySmall => TextStyle(
        fontSize: ScreenUtil().setSp(14),
        fontWeight: FontWeight.normal,
        fontFamily: 'Vazir',
        height: 1.5,
      );

  // Caption and Label Styles
  static TextStyle get caption => TextStyle(
        fontSize: ScreenUtil().setSp(12),
        fontWeight: FontWeight.normal,
        fontFamily: 'Vazir',
        height: 1.4,
      );

  static TextStyle get labelSmall => TextStyle(
        fontSize: ScreenUtil().setSp(11),
        fontWeight: FontWeight.normal,
        fontFamily: 'Vazir',
        height: 1.4,
      );

  static TextStyle get labelTiny => TextStyle(
        fontSize: ScreenUtil().setSp(10),
        fontWeight: FontWeight.normal,
        fontFamily: 'Vazir',
        height: 1.4,
      );

  // Button Styles
  static TextStyle get buttonLarge => TextStyle(
        fontSize: ScreenUtil().setSp(18),
        fontWeight: FontWeight.w600,
        fontFamily: 'Vazir',
        height: 1.2,
      );

  static TextStyle get buttonMedium => TextStyle(
        fontSize: ScreenUtil().setSp(16),
        fontWeight: FontWeight.w600,
        fontFamily: 'Vazir',
        height: 1.2,
      );

  static TextStyle get buttonSmall => TextStyle(
        fontSize: ScreenUtil().setSp(14),
        fontWeight: FontWeight.w600,
        fontFamily: 'Vazir',
        height: 1.2,
      );

  // Input Styles
  static TextStyle get inputText => TextStyle(
        fontSize: ScreenUtil().setSp(16),
        fontWeight: FontWeight.normal,
        fontFamily: 'Vazir',
        height: 1.5,
      );

  static TextStyle get inputHint => TextStyle(
        fontSize: ScreenUtil().setSp(16),
        fontWeight: FontWeight.normal,
        fontFamily: 'Vazir',
        height: 1.5,
      );

  // Chat Styles
  static TextStyle get chatMessage => TextStyle(
        fontSize: ScreenUtil().setSp(16),
        fontWeight: FontWeight.normal,
        fontFamily: 'Vazir',
        height: 1.4,
      );

  static TextStyle get chatTime => TextStyle(
        fontSize: ScreenUtil().setSp(12),
        fontWeight: FontWeight.normal,
        fontFamily: 'Vazir',
        height: 1.2,
      );

  static TextStyle get chatSender => TextStyle(
        fontSize: ScreenUtil().setSp(14),
        fontWeight: FontWeight.w600,
        fontFamily: 'Vazir',
        height: 1.3,
      );

  // Special Styles
  static TextStyle get errorText => TextStyle(
        fontSize: ScreenUtil().setSp(14),
        fontWeight: FontWeight.normal,
        fontFamily: 'Vazir',
        height: 1.4,
        color: Colors.red,
      );

  static TextStyle get successText => TextStyle(
        fontSize: ScreenUtil().setSp(14),
        fontWeight: FontWeight.normal,
        fontFamily: 'Vazir',
        height: 1.4,
        color: Colors.green,
      );
}

class AppSizes {
  // Margins and Padding
  static double get tinyMargin => ScreenUtil().setWidth(4);
  static double get smallMargin => ScreenUtil().setWidth(8);
  static double get mediumMargin => ScreenUtil().setWidth(16);
  static double get largeMargin => ScreenUtil().setWidth(24);
  static double get extraLargeMargin => ScreenUtil().setWidth(32);

  // Padding
  static double get tinyPadding => ScreenUtil().setWidth(4);
  static double get smallPadding => ScreenUtil().setWidth(8);
  static double get mediumPadding => ScreenUtil().setWidth(16);
  static double get largePadding => ScreenUtil().setWidth(24);
  static double get extraLargePadding => ScreenUtil().setWidth(32);

  // Border Radius
  static double get tinyRadius => ScreenUtil().radius(4);
  static double get smallRadius => ScreenUtil().radius(8);
  static double get mediumRadius => ScreenUtil().radius(12);
  static double get largeRadius => ScreenUtil().radius(16);
  static double get extraLargeRadius => ScreenUtil().radius(24);
  static double get circularRadius => ScreenUtil().radius(50);

  // Icon Sizes
  static double get tinyIcon => ScreenUtil().setWidth(16);
  static double get smallIcon => ScreenUtil().setWidth(20);
  static double get mediumIcon => ScreenUtil().setWidth(24);
  static double get largeIcon => ScreenUtil().setWidth(28);
  static double get extraLargeIcon => ScreenUtil().setWidth(32);

  // Avatar Sizes
  static double get smallAvatar => ScreenUtil().setWidth(32);
  static double get mediumAvatar => ScreenUtil().setWidth(48);
  static double get largeAvatar => ScreenUtil().setWidth(64);
  static double get extraLargeAvatar => ScreenUtil().setWidth(80);

  // Button Sizes
  static double get smallButtonHeight => ScreenUtil().setHeight(36);
  static double get mediumButtonHeight => ScreenUtil().setHeight(48);
  static double get largeButtonHeight => ScreenUtil().setHeight(56);

  static double get smallButtonWidth => ScreenUtil().setWidth(80);
  static double get mediumButtonWidth => ScreenUtil().setWidth(120);
  static double get largeButtonWidth => ScreenUtil().setWidth(160);

  // Input Field Sizes
  static double get inputHeight => ScreenUtil().setHeight(48);
  static double get inputBorderWidth => ScreenUtil().setWidth(1);

  // Chat Bubble Sizes
  static double get chatBubblePadding => ScreenUtil().setWidth(12);
  static double get chatBubbleMargin => ScreenUtil().setWidth(8);

  // Card Sizes
  static double get cardPadding => ScreenUtil().setWidth(16);
  static double get cardMargin => ScreenUtil().setWidth(8);
  static double get cardElevation => ScreenUtil().setWidth(2);

  // Screen Spacing
  static double get screenHorizontalPadding => ScreenUtil().setWidth(20);
  static double get screenVerticalPadding => ScreenUtil().setHeight(20);

  // App Bar
  static double get appBarHeight => ScreenUtil().setHeight(56);
  static double get appBarElevation => ScreenUtil().setWidth(1);

  // Bottom Navigation
  static double get bottomNavHeight => ScreenUtil().setHeight(60);
  static double get bottomNavIconSize => ScreenUtil().setWidth(24);

  // Tab Bar
  static double get tabHeight => ScreenUtil().setHeight(48);

  // Dialog
  static double get dialogPadding => ScreenUtil().setWidth(24);
  static double get dialogBorderRadius => ScreenUtil().radius(16);

  // Loading
  static double get loadingSize => ScreenUtil().setWidth(24);
  static double get loadingStrokeWidth => ScreenUtil().setWidth(2);

  // Screen constraints
  static double get maxMobileWidth => ScreenUtil().setWidth(480);
  static double get maxTabletWidth => ScreenUtil().setWidth(768);

  // Minimum touch targets
  static double get minTouchTarget => ScreenUtil().setWidth(44);
}

class AppConstraints {
  // Maximum widths for different screen sizes
  static double get maxMobileWidth => ScreenUtil().setWidth(480);
  static double get maxTabletWidth => ScreenUtil().setWidth(768);

  // Minimum touch targets
  static double get minTouchTarget => ScreenUtil().setWidth(44);
}

// Common responsive widgets
class ResponsiveWidgets {
  static EdgeInsets get screenPadding => EdgeInsets.symmetric(
        horizontal: AppSizes.screenHorizontalPadding,
        vertical: AppSizes.screenVerticalPadding,
      );

  static EdgeInsets get cardPadding => EdgeInsets.all(AppSizes.cardPadding);

  static EdgeInsets get chatBubblePadding =>
      EdgeInsets.all(AppSizes.chatBubblePadding);

  static BorderRadius get defaultBorderRadius =>
      BorderRadius.circular(AppSizes.mediumRadius);

  static BorderRadius get largeBorderRadius =>
      BorderRadius.circular(AppSizes.largeRadius);

  static BoxDecoration get cardDecoration => BoxDecoration(
        color: Colors.white,
        borderRadius: defaultBorderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: AppSizes.cardElevation,
            offset: Offset(0, AppSizes.tinyMargin),
          ),
        ],
      );
}
