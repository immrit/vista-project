import 'package:flutter/material.dart';

import '../../../utils/avatar_asset_utils.dart';
import '../../../utils/compat_extensions.dart';
import '../theme/chat_theme.dart';

/// Lightweight reactor info for reaction UI.
class ReactionReactorInfo {
  final String userId;
  final String? userName;
  final String? userAvatar;

  const ReactionReactorInfo({
    required this.userId,
    this.userName,
    this.userAvatar,
  });
}

/// Overlapping avatar stack for group message reactions.
class ReactionReactorAvatarStack extends StatelessWidget {
  final List<ReactionReactorInfo> reactors;
  final ChatTheme theme;
  final double avatarSize;
  final int maxVisible;

  const ReactionReactorAvatarStack({
    super.key,
    required this.reactors,
    required this.theme,
    this.avatarSize = 16,
    this.maxVisible = 3,
  });

  @override
  Widget build(BuildContext context) {
    if (reactors.isEmpty) {
      return const SizedBox.shrink();
    }

    final visible = reactors.take(maxVisible).toList();
    final extraCount = reactors.length - visible.length;
    final overlap = avatarSize * 0.42;
    final stackWidth =
        avatarSize + (visible.length - 1) * (avatarSize - overlap);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: stackWidth,
          height: avatarSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < visible.length; i++)
                PositionedDirectional(
                  start: i * (avatarSize - overlap),
                  child: _buildAvatar(context, visible[i]),
                ),
            ],
          ),
        ),
        if (extraCount > 0) ...[
          const SizedBox(width: 4),
          Text(
            '+${extraCount.toString().toPersianDigit()}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: theme.otherBubbleTextColor.withValues(alpha: 0.75),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAvatar(BuildContext context, ReactionReactorInfo reactor) {
    final initial = (reactor.userName ?? '').trim().isNotEmpty
        ? reactor.userName!.trim()[0].toUpperCase()
        : '?';

    return Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: theme.myBubbleColor,
          width: 1.2,
        ),
        color: theme.sendButtonColor.withValues(alpha: 0.15),
      ),
      child: ClipOval(
        child: reactor.userAvatar != null && reactor.userAvatar!.isNotEmpty
            ? AvatarAssetUtils.image(
                source: reactor.userAvatar,
                fit: BoxFit.cover,
                memCacheWidth: 48,
                memCacheHeight: 48,
                placeholder: _buildInitial(initial),
                fallback: _buildInitial(initial),
              )
            : _buildInitial(initial),
      ),
    );
  }

  Widget _buildInitial(String initial) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: avatarSize * 0.45,
          fontWeight: FontWeight.w700,
          color: theme.sendButtonColor,
        ),
      ),
    );
  }
}
