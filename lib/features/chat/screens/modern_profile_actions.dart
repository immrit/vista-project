part of 'modern_profile_screen.dart';

extension ModernProfileActionsExt on _VistaChatProfileScreenState {
  Widget _buildActionButtons(
    bool isDark,
    AsyncValue conversationAsync,
    AsyncValue<bool> isBlockedAsync,
  ) {
    final cardColor = isDark ? _darkCard : Colors.white;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // دکمه پیام
          _buildActionButton(
            icon: Icons.chat_bubble_outline,
            label: 'پیام',
            color: _primaryColor,
            isDark: isDark,
            onTap: () => Navigator.pop(context),
          ),

          const SizedBox(width: 8),

          // دکمه بی‌صدا
          conversationAsync.when(
            data: (conversation) {
              final isMuted = conversation?.isMuted ?? false;
              return _buildActionButton(
                icon: isMuted
                    ? Icons.notifications_off
                    : Icons.notifications_outlined,
                label: isMuted ? 'صدادار' : 'بی‌صدا',
                color: isDark ? Colors.white70 : Colors.grey[700]!,
                isDark: isDark,
                onTap: () => _toggleMute(),
              );
            },
            loading: () => _buildActionButton(
              icon: Icons.notifications_outlined,
              label: 'بی‌صدا',
              color: isDark ? Colors.white70 : Colors.grey[700]!,
              isDark: isDark,
              onTap: () {},
            ),
            error: (_, __) => _buildActionButton(
              icon: Icons.notifications_outlined,
              label: 'بی‌صدا',
              color: isDark ? Colors.white70 : Colors.grey[700]!,
              isDark: isDark,
              onTap: () {},
            ),
          ),

          const SizedBox(width: 8),

          // دکمه مشاهده پروفایل
          _buildActionButton(
            icon: Icons.person_outline,
            label: 'پروفایل',
            color: isDark ? Colors.white70 : Colors.grey[700]!,
            isDark: isDark,
            onTap: () => _viewProfile(),
          ),

          const SizedBox(width: 8),

          // دکمه جستجو
          _buildActionButton(
            icon: Icons.search,
            label: 'جستجو',
            color: isDark ? Colors.white70 : Colors.grey[700]!,
            isDark: isDark,
            onTap: () => _openSearch(),
          ),
        ],
      ),
    );
  }

  /// دکمه عملیات تکی - طراحی چهارگوش مدرن
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.grey.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 23),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// بخش اطلاعات کاربر
}
