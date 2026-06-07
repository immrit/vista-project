import 'package:flutter/material.dart';

const Set<String> _rtlLanguageCodes = <String>{
  'ar',
  'fa',
  'he',
  'iw',
  'ps',
  'ur'
};

bool isLocaleRtl(BuildContext context) {
  try {
    final languageCode =
        Localizations.localeOf(context).languageCode.toLowerCase();
    return _rtlLanguageCodes.contains(languageCode);
  } catch (_) {
    return Directionality.maybeOf(context) == TextDirection.rtl;
  }
}

bool isEffectiveRtl(BuildContext context) {
  final direction = Directionality.maybeOf(context);
  if (direction != null) {
    return direction == TextDirection.rtl;
  }
  return isLocaleRtl(context);
}

IconData directionalBackIcon(BuildContext context, {bool ios = false}) {
  final isRtl = isEffectiveRtl(context);
  if (ios) {
    return isRtl
        ? Icons.arrow_forward_ios_rounded
        : Icons.arrow_back_ios_new_rounded;
  }
  return isRtl ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded;
}

IconData directionalForwardChevronIcon(BuildContext context) {
  return isEffectiveRtl(context)
      ? Icons.chevron_left_rounded
      : Icons.chevron_right_rounded;
}

IconData directionalForwardIcon(BuildContext context) {
  return isEffectiveRtl(context)
      ? Icons.arrow_back_rounded
      : Icons.arrow_forward_rounded;
}

class LocaleDirectionalPositioned extends StatelessWidget {
  final double? start;
  final double? end;
  final double? top;
  final double? bottom;
  final double? width;
  final double? height;
  final Widget child;

  const LocaleDirectionalPositioned({
    super.key,
    this.start,
    this.end,
    this.top,
    this.bottom,
    this.width,
    this.height,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isRtl = isEffectiveRtl(context);
    return Positioned(
      left: isRtl ? end : start,
      right: isRtl ? start : end,
      top: top,
      bottom: bottom,
      width: width,
      height: height,
      child: child,
    );
  }
}

class DirectionalBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? color;
  final double iconSize;
  final bool ios;
  final String? tooltip;

  const DirectionalBackButton({
    super.key,
    this.onPressed,
    this.color,
    this.iconSize = 24,
    this.ios = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip ?? MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: onPressed ?? () => Navigator.maybePop(context),
      icon: Icon(
        directionalBackIcon(context, ios: ios),
        color: color,
        size: iconSize,
      ),
    );
  }
}
