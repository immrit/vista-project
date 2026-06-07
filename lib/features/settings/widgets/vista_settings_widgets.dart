import 'package:flutter/material.dart';

import '../../../utils/directional_navigation.dart';

/// ویجت‌های مشترک تنظیمات ویستا
/// طراحی مدرن و تمیز با الهام از ویستا

/// آیتم تنظیمات با طراحی یکپارچه
class VistaSettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? titleColor;
  final bool showArrow;

  const VistaSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.titleColor,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultTextColor = isDark ? Colors.white : Colors.black;
    final defaultIconColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final subtitleColor = isDark ? Colors.grey[500] : Colors.grey[600];

    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: (iconColor ?? defaultIconColor)!.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: iconColor ?? defaultIconColor,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: titleColor ?? defaultTextColor,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                fontSize: 13,
                color: subtitleColor,
              ),
            )
          : null,
      trailing: trailing ??
          (showArrow
              ? Icon(
                  directionalForwardChevronIcon(context),
                  color: isDark ? Colors.grey[700] : Colors.grey[400],
                  size: 20,
                )
              : null),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

/// آیتم تنظیمات با سوئیچ
class VistaSettingsSwitch extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? iconColor;

  const VistaSettingsSwitch({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    this.onChanged,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEnabled = onChanged != null;

    return VistaSettingsTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      iconColor: isEnabled
          ? iconColor
          : (isDark ? Colors.grey[700] : Colors.grey[400]),
      titleColor:
          isEnabled ? null : (isDark ? Colors.grey[600] : Colors.grey[400]),
      showArrow: false,
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: isDark ? Colors.white : Colors.black,
        activeTrackColor: isDark ? Colors.grey[600] : Colors.grey[400],
        inactiveThumbColor: isDark ? Colors.grey[600] : Colors.grey[400],
        inactiveTrackColor: isDark ? Colors.grey[800] : Colors.grey[300],
      ),
    );
  }
}

/// عنوان بخش تنظیمات
class VistaSettingsSection extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry? padding;

  const VistaSettingsSection({
    super.key,
    required this.title,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(32, 24, 32, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.grey[500] : Colors.grey[600],
        ),
      ),
    );
  }
}

/// گروه تنظیمات با کارت
class VistaSettingsGroup extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? margin;

  const VistaSettingsGroup({
    super.key,
    required this.children,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: List.generate(children.length, (index) {
          return Column(
            children: [
              children[index],
              if (index < children.length - 1)
                Divider(
                  height: 1,
                  indent: 68,
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                ),
            ],
          );
        }),
      ),
    );
  }
}

/// انتخابگر گزینه‌ها (برای مثال: همه / مخاطبین / هیچکس)
class VistaSettingsChoice<T> extends StatelessWidget {
  final IconData icon;
  final String title;
  final T value;
  final List<VistaChoiceOption<T>> options;
  final ValueChanged<T> onChanged;
  final Color? iconColor;

  const VistaSettingsChoice({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    this.iconColor,
  });

  String _getSelectedLabel() {
    final selected = options.firstWhere(
      (opt) => opt.value == value,
      orElse: () => options.first,
    );
    return selected.label;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return VistaSettingsTile(
      icon: icon,
      title: title,
      subtitle: _getSelectedLabel(),
      iconColor: iconColor,
      onTap: () => _showChoiceSheet(context, isDark),
    );
  }

  void _showChoiceSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            const Divider(height: 1),
            ...options.map((option) => ListTile(
                  title: Text(
                    option.label,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  trailing: value == option.value
                      ? Icon(
                          Icons.check,
                          color: isDark ? Colors.white : Colors.black,
                        )
                      : null,
                  onTap: () {
                    onChanged(option.value);
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// مدل گزینه انتخابی
class VistaChoiceOption<T> {
  final T value;
  final String label;

  const VistaChoiceOption({
    required this.value,
    required this.label,
  });
}
