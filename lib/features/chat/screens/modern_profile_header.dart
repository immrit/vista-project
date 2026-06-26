part of 'modern_profile_screen.dart';

extension ModernProfileHeaderExt on _VistaChatProfileScreenState {
  Widget _buildProfileHeader(bool isDark, AsyncValue<bool> userOnlineAsync) {
    final avatarProvider =
        AvatarAssetUtils.imageProvider(widget.otherUserAvatar);

    return SliverToBoxAdapter(
      child: Stack(
        children: [
          // تصویر پس‌زمینه با افکت بلور
          Container(
            height: 340,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  isDark ? AppColors.darkSurfaceVariant : AppColors.primaryLight,
                  isDark ? _darkBg : _lightBg,
                ],
              ),
            ),
            child: avatarProvider != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      // تصویر اصلی با بلور
                      Container(
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: avatarProvider,
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: ClipRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                      ),
                      // گرادیان روی تصویر
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.2),
                              Colors.black.withValues(alpha: 0.6),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ],
                  )
                : _buildDefaultAvatarBackground(isDark),
          ),

          // محتوای هدر
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // آواتار دایره‌ای
                GestureDetector(
                  onTap: () => _handleAvatarTap(),
                  child: Hero(
                    tag: 'profile_avatar_${widget.otherUserId}',
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? _darkBg : Colors.white,
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: avatarProvider != null
                            ? AvatarAssetUtils.image(
                                source: widget.otherUserAvatar,
                                fit: BoxFit.cover,
                                placeholder: _buildAvatarShimmer(),
                                fallback: _buildDefaultAvatar(isDark),
                              )
                            : _buildDefaultAvatar(isDark),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // نام کاربر
                Text(
                  widget.otherUserName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        blurRadius: 10,
                        color: Colors.black45,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // وضعیت آنلاین
                userOnlineAsync.when(
                  data: (isOnline) => _buildOnlineStatus(isOnline, isDark),
                  loading: () => Text(
                    'در حال بررسی...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  error: (_, __) => Text(
                    'آخرین بازدید اخیراً',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // دکمه بازگشت
          LocaleDirectionalPositioned(
            top: MediaQuery.of(context).padding.top + 8,
            start: 8,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  directionalBackIcon(context),
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),

          // دکمه منو
          LocaleDirectionalPositioned(
            top: MediaQuery.of(context).padding.top + 8,
            end: 8,
            child: IconButton(
              onPressed: () => _showOptionsMenu(context),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.more_vert,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// وضعیت آنلاین/آفلاین
  Widget _buildOnlineStatus(bool isOnline, bool isDark) {
    if (isOnline) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.onlineDark,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'آنلاین',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.onlineDark,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return Text(
      'آخرین بازدید اخیراً',
      style: TextStyle(
        fontSize: 14,
        color: Colors.white.withValues(alpha: 0.8),
      ),
    );
  }

  /// دکمه‌های عملیات سریع
}
