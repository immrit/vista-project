// lib/features/chat/widgets/block_report_bottom_sheet.dart
//
// Bottom Sheet برای مسدود کردن و گزارش کاربر
//
// ویژگی‌ها:
// ✅ UI مدرن و زیبا
// ✅ انیمیشن‌های روان
// ✅ Haptic feedback
// ✅ Form validation
// ✅ Loading states
//

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/user_moderation_service.dart';
import '../../../services/toast_service.dart';

/// نوع عملیات
enum ModerationType {
  block,
  unblock,
  report,
}

/// Bottom Sheet برای Block & Report
class BlockReportBottomSheet extends StatefulWidget {
  final String userId;
  final String userName;
  final bool isCurrentlyBlocked;
  final ModerationType initialType;

  const BlockReportBottomSheet({
    super.key,
    required this.userId,
    required this.userName,
    this.isCurrentlyBlocked = false,
    this.initialType = ModerationType.block,
  });

  /// نمایش Bottom Sheet
  static Future<bool?> show({
    required BuildContext context,
    required String userId,
    required String userName,
    bool isCurrentlyBlocked = false,
    ModerationType type = ModerationType.block,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BlockReportBottomSheet(
        userId: userId,
        userName: userName,
        isCurrentlyBlocked: isCurrentlyBlocked,
        initialType: type,
      ),
    );
  }

  @override
  State<BlockReportBottomSheet> createState() => _BlockReportBottomSheetState();
}

class _BlockReportBottomSheetState extends State<BlockReportBottomSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final _moderationService = UserModerationService();
  final _reportController = TextEditingController();

  bool _isLoading = false;
  ModerationReason _selectedReason = ModerationReason.inappropriateContent;
  late ModerationType _currentType;

  @override
  void initState() {
    super.initState();
    _currentType = widget.initialType;
    _setupAnimations();
  }

  void _setupAnimations() {
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _reportController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(theme),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildContent(theme, isDark),
                    ),
                  ),
                  _buildActions(theme, isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: 12),
        // Handle
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: theme.dividerColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 20),
        // Title
        Row(
          children: [
            const SizedBox(width: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getIconColor().withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getIcon(),
                color: _getIconColor(),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getTitle(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.titleLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.userName,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close_rounded, color: theme.hintColor),
            ),
            const SizedBox(width: 8),
          ],
        ),
        const SizedBox(height: 20),
        Divider(height: 1, color: theme.dividerColor),
      ],
    );
  }

  Widget _buildContent(ThemeData theme, bool isDark) {
    switch (_currentType) {
      case ModerationType.block:
        return _buildBlockContent(theme, isDark);
      case ModerationType.unblock:
        return _buildUnblockContent(theme, isDark);
      case ModerationType.report:
        return _buildReportContent(theme, isDark);
    }
  }

  Widget _buildBlockContent(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoBox(
            icon: Icons.info_outline_rounded,
            color: Colors.orange,
            title: 'توجه',
            description: 'با مسدود کردن ${widget.userName}:',
            items: [
              'دیگر نمی‌توانید پیام‌های یکدیگر را ببینید',
              'مکالمات قبلی حفظ می‌شود اما در دسترس نیست',
              'می‌توانید در هر زمان مسدودیت را برطرف کنید',
            ],
            isDark: isDark,
          ),
          const SizedBox(height: 24),
          _buildSwitchTile(
            theme: theme,
            icon: Icons.report_outlined,
            title: 'گزارش هم‌زمان',
            subtitle: 'علاوه بر مسدود کردن، این کاربر را گزارش کنید',
            value: false,
            onChanged: (value) {
              if (value) {
                HapticFeedback.lightImpact();
                setState(() => _currentType = ModerationType.report);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUnblockContent(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoBox(
            icon: Icons.check_circle_outline_rounded,
            color: Colors.green,
            title: 'رفع مسدودیت',
            description: 'با رفع مسدودیت ${widget.userName}:',
            items: [
              'دوباره می‌توانید با هم پیام رد و بدل کنید',
              'مکالمات قبلی قابل مشاهده خواهد بود',
              'می‌توانید در هر زمان دوباره مسدود کنید',
            ],
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildReportContent(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'دلیل گزارش',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 16),
          // Reason Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ModerationReason.values.map((reason) {
              final isSelected = _selectedReason == reason;
              return _buildReasonChip(
                theme: theme,
                reason: reason,
                isSelected: isSelected,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedReason = reason);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          // Additional Info
          Text(
            'توضیحات اضافی (اختیاری)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reportController,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'جزئیات بیشتر در مورد مشکل...',
              filled: true,
              fillColor:
                  isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.primaryColor,
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoBox(
            icon: Icons.privacy_tip_outlined,
            color: Colors.blue,
            title: 'حریم خصوصی',
            description: 'گزارش شما:',
            items: [
              'به صورت ناشناس ارسال می‌شود',
              'برای بررسی تیم پشتیبانی ارسال می‌شود',
              'کاربر از گزارش شما مطلع نمی‌شود',
            ],
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildReasonChip({
    required ThemeData theme,
    required ModerationReason reason,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: FilterChip(
        selected: isSelected,
        label: Text(reason.persianLabel),
        onSelected: (_) => onTap(),
        selectedColor: theme.primaryColor.withValues(alpha: 0.2),
        checkmarkColor: theme.primaryColor,
        backgroundColor: theme.cardColor,
        side: BorderSide(
          color: isSelected
              ? theme.primaryColor
              : theme.dividerColor.withValues(alpha: 0.3),
          width: isSelected ? 2 : 1,
        ),
        labelStyle: TextStyle(
          color: isSelected
              ? theme.primaryColor
              : theme.textTheme.bodyLarge?.color,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildInfoBox({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required List<String> items,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.only(top: 7, left: 8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 13,
                          color: color.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: theme.primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: theme.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildActions(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: theme.dividerColor),
              ),
              child: const Text('انصراف'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleAction,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: _getActionColor(),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_getIcon(), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _getActionText(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction() async {
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      ModerationResult result;

      switch (_currentType) {
        case ModerationType.block:
          result = await _moderationService.blockUser(widget.userId);
          break;
        case ModerationType.unblock:
          result = await _moderationService.unblockUser(widget.userId);
          break;
        case ModerationType.report:
          result = await _moderationService.reportUser(
            userId: widget.userId,
            reason: _selectedReason,
            additionalInfo: _reportController.text.trim().isEmpty
                ? null
                : _reportController.text.trim(),
          );
          break;
      }

      if (!mounted) return;

      if (result.success) {
        HapticFeedback.heavyImpact();
        Navigator.pop(context, true);
        ToastService.showSuccessToast(
          context,
          result.message ?? 'عملیات با موفقیت انجام شد',
        );
      } else {
        ToastService.showErrorToast(
          context,
          result.error ?? 'خطا در انجام عملیات',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getTitle() {
    switch (_currentType) {
      case ModerationType.block:
        return 'مسدود کردن کاربر';
      case ModerationType.unblock:
        return 'رفع مسدودیت';
      case ModerationType.report:
        return 'گزارش کاربر';
    }
  }

  IconData _getIcon() {
    switch (_currentType) {
      case ModerationType.block:
        return Icons.block_rounded;
      case ModerationType.unblock:
        return Icons.lock_open_rounded;
      case ModerationType.report:
        return Icons.flag_rounded;
    }
  }

  Color _getIconColor() {
    switch (_currentType) {
      case ModerationType.block:
        return Colors.red;
      case ModerationType.unblock:
        return Colors.green;
      case ModerationType.report:
        return Colors.orange;
    }
  }

  Color _getActionColor() {
    switch (_currentType) {
      case ModerationType.block:
        return Colors.red;
      case ModerationType.unblock:
        return Colors.green;
      case ModerationType.report:
        return Colors.orange;
    }
  }

  String _getActionText() {
    switch (_currentType) {
      case ModerationType.block:
        return 'مسدود کردن';
      case ModerationType.unblock:
        return 'رفع مسدودیت';
      case ModerationType.report:
        return 'ارسال گزارش';
    }
  }
}
