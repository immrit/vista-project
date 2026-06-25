import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../model/message_model.dart';
import '../../../utils/avatar_asset_utils.dart';
import '../../../utils/compat_extensions.dart';
import '../../../utils/directional_navigation.dart';
import '../../../utils/user_friendly_error_utils.dart';
import '../../auth/providers/auth_controller.dart';
import '../models/group_member_item.dart';
import '../models/group_user_item.dart';
import '../providers/chat_providers.dart';
import '../services/chat_attachment_service.dart';
import '../services/group_service.dart';

class ModernGroupProfileScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const ModernGroupProfileScreen({
    super.key,
    required this.conversationId,
  });

  @override
  ConsumerState<ModernGroupProfileScreen> createState() =>
      _ModernGroupProfileScreenState();
}

class _ModernGroupProfileScreenState
    extends ConsumerState<ModernGroupProfileScreen>
    with SingleTickerProviderStateMixin {
  final _groupService = GroupService();
  final _attachmentService = ChatAttachmentService();
  final _memberSearchController = TextEditingController();

  late final TabController _tabController;

  static const _darkBg = Color(0xFF17212B);
  static const _darkCard = Color(0xFF232E3C);
  static const _darkDivider = Color(0xFF303D4F);
  static const _lightBg = Color(0xFFFFFFFF);
  static const _lightDivider = Color(0xFFE4E6E9);

  Color get _primaryColor => Theme.of(context).primaryColor;

  String _groupName = 'گروه';
  String? _groupImage;
  String? _groupDescription;
  String? _createdBy;
  String? _currentUserId;
  String? _inviteCode;

  bool _inviteEnabled = true;
  bool _isMuted = false;
  bool _isLoading = true;
  bool _isSaving = false;
  int _maxMembers = 20;
  List<GroupMemberItem> _members = const [];

  bool get _isCreator =>
      _currentUserId != null &&
      _createdBy != null &&
      _currentUserId == _createdBy;

  bool get _isAdmin =>
      _isCreator ||
      _members.any((m) => m.userId == _currentUserId && m.isAdmin);

  int get _adminCount => _members.where((m) => m.isAdmin).length;

  int get _memberCount => _members.length;

  int get _remainingSlots => (_maxMembers - _memberCount).clamp(0, _maxMembers);

  String get _inviteLink =>
      _inviteCode == null ? '' : 'https://cafevista.ir/group/$_inviteCode';

  List<GroupMemberItem> get _filteredMembers {
    final query = _memberSearchController.text.trim().toLowerCase();
    final ordered = List<GroupMemberItem>.from(_members)
      ..sort((a, b) {
        final aRank = _memberRank(a);
        final bRank = _memberRank(b);
        if (aRank != bRank) return bRank.compareTo(aRank);
        return a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            );
      });

    if (query.isEmpty) return ordered;
    return ordered.where((member) {
      return member.displayName.toLowerCase().contains(query) ||
          member.username.toLowerCase().contains(query) ||
          member.userId.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _memberSearchController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadGroup();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _memberSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadGroup() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      final currentUserId = await TokenStorage.getUserId();
      final info = await _groupService.fetchGroupInfo(widget.conversationId);
      final members =
          await _groupService.fetchGroupMembers(widget.conversationId);

      Map<String, dynamic> invite = const {};
      try {
        invite = await _groupService.getInvite(widget.conversationId);
      } catch (_) {
        invite = const {};
      }

      if (!mounted) return;
      setState(() {
        _currentUserId = currentUserId;
        _groupName = _stringFrom(info, const ['name']) ?? 'گروه';
        _groupImage = _stringFrom(info, const ['image', 'image_url']);
        _groupDescription =
            _stringFrom(info, const ['description', 'bio', 'about']);
        _createdBy =
            _stringFrom(info, const ['created_by', 'creator_id', 'owner_id']);
        _maxMembers = _intFrom(info, const ['max_members'], fallback: 20);
        _isMuted = _boolFrom(info, const ['is_muted'], fallback: _isMuted);
        _inviteCode = _stringFrom(invite, const ['invite_code', 'code']);
        _inviteEnabled = _boolFrom(
          invite,
          const ['invite_enabled', 'enabled'],
          fallback: true,
        );
        _members = members;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      UserFriendlyErrorUtils.showErrorSnackBar(
        context,
        _mapGroupError(error),
      );
    }
  }

  Future<void> _refreshGroup() async {
    await _loadGroup();
    await ref.read(chatRepositoryProvider).refreshConversations();
  }

  Future<void> _editName() async {
    if (!_isAdmin) return;
    final controller = TextEditingController(text: _groupName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ویرایش نام گروه'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 50,
          decoration: const InputDecoration(
            hintText: 'نام گروه',
            prefixIcon: Icon(Icons.groups_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );

    final newName = result?.trim() ?? '';
    if (newName.isEmpty || newName == _groupName || newName.length > 50) {
      return;
    }

    await _runSavingAction(
      () => _groupService.updateGroupInfo(widget.conversationId, name: newName),
      successMessage: 'نام گروه به‌روزرسانی شد',
      onSuccess: () {
        setState(() => _groupName = newName);
        ref.read(chatRepositoryProvider).refreshConversations();
      },
    );
  }

  Future<void> _changeGroupImage() async {
    if (!_isAdmin) return;
    final result = await _attachmentService.pickImageFromGallery(
      conversationId: widget.conversationId,
    );
    if (!result.success || result.url == null) return;

    await _runSavingAction(
      () => _groupService.updateGroupInfo(
        widget.conversationId,
        imageUrl: result.url,
      ),
      successMessage: 'تصویر گروه به‌روزرسانی شد',
      onSuccess: () {
        setState(() => _groupImage = result.url);
        ref.read(chatRepositoryProvider).refreshConversations();
      },
    );
  }

  Future<void> _toggleMute() async {
    await _runSavingAction(
      () => ref
          .read(chatRepositoryProvider)
          .toggleMuteConversation(widget.conversationId),
      successMessage:
          _isMuted ? 'اعلان‌های گروه فعال شد' : 'اعلان‌های گروه بی‌صدا شد',
      onSuccess: () => setState(() => _isMuted = !_isMuted),
    );
  }

  Future<void> _copyInviteLink() async {
    if (_inviteCode == null) {
      if (_isAdmin) {
        await _regenerateInvite();
      }
      return;
    }

    await Clipboard.setData(ClipboardData(text: _inviteLink));
    if (mounted) {
      UserFriendlyErrorUtils.showSuccessSnackBar(context, 'لینک دعوت کپی شد');
    }
  }

  Future<void> _shareInviteLink() async {
    if (_inviteCode == null) {
      if (_isAdmin) {
        await _regenerateInvite();
      }
      return;
    }
    await SharePlus.instance.share(
      ShareParams(text: 'دعوت به گروه $_groupName در Vista\n$_inviteLink'),
    );
  }

  Future<void> _regenerateInvite() async {
    if (!_isAdmin) return;
    await _runSavingAction(
      () => _groupService.regenerateInvite(widget.conversationId),
      successMessage: 'لینک دعوت تازه ساخته شد',
      onSuccessWithValue: (code) => setState(() => _inviteCode = code),
    );
  }

  Future<void> _toggleInvite(bool enabled) async {
    if (!_isAdmin) return;
    setState(() => _inviteEnabled = enabled);
    try {
      await _groupService.setInviteEnabled(widget.conversationId, enabled);
    } catch (error) {
      if (!mounted) return;
      setState(() => _inviteEnabled = !enabled);
      UserFriendlyErrorUtils.showErrorSnackBar(context, _mapGroupError(error));
    }
  }

  Future<void> _addMembers() async {
    if (!_isAdmin) return;
    if (_remainingSlots <= 0) {
      UserFriendlyErrorUtils.showErrorSnackBar(
        context,
        'ظرفیت گروه تکمیل است',
      );
      return;
    }

    final added = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddMembersSheet(
        remainingSlots: _remainingSlots,
        existingMemberIds: _members.map((m) => m.userId).toSet(),
      ),
    );

    if (added == null || added.isEmpty) return;

    await _runSavingAction(
      () => _groupService.addMembers(widget.conversationId, added),
      successMessage: '${added.length} عضو اضافه شد'.toPersianDigit(),
      onSuccess: _refreshGroup,
    );
  }

  Future<void> _removeMember(GroupMemberItem member) async {
    final confirmed = await _confirm(
      title: 'حذف عضو',
      message:
          'آیا از حذف ${member.displayName} از گروه مطمئن هستید؟ این کار برای عضو قابل مشاهده است.',
      confirmText: 'حذف',
      destructive: true,
    );
    if (!confirmed) return;

    await _runSavingAction(
      () => _groupService.removeMember(widget.conversationId, member.userId),
      successMessage: '${member.displayName} از گروه حذف شد',
      onSuccess: _refreshGroup,
    );
  }

  Future<void> _toggleAdmin(GroupMemberItem member) async {
    final makeAdmin = !member.isAdmin;
    if (makeAdmin) {
      final confirmed = await _confirm(
        title: 'ادمین کردن عضو',
        message:
            '${member.displayName} می‌تواند اعضا و اطلاعات گروه را مدیریت کند. ادامه می‌دهید؟',
        confirmText: 'ادمین کن',
      );
      if (!confirmed) return;
    }

    await _runSavingAction(
      () => _groupService.setAdmin(
        widget.conversationId,
        member.userId,
        makeAdmin: makeAdmin,
      ),
      successMessage: makeAdmin ? 'عضو ادمین شد' : 'دسترسی ادمین برداشته شد',
      onSuccess: _refreshGroup,
    );
  }

  Future<void> _leaveOrDeleteGroup() async {
    final deleting = _isCreator;
    final confirmed = await _confirm(
      title: deleting ? 'حذف گروه' : 'خروج از گروه',
      message: deleting
          ? 'با حذف گروه، این گفتگو برای اعضا از دسترس خارج می‌شود. این عملیات قابل بازگشت نیست.'
          : 'بعد از خروج، برای برگشت دوباره باید از طریق لینک دعوت یا ادمین وارد شوید.',
      confirmText: deleting ? 'حذف گروه' : 'خروج',
      destructive: true,
    );
    if (!confirmed) return;

    await _runSavingAction(
      () => deleting
          ? _groupService.deleteGroup(widget.conversationId)
          : _groupService.leaveGroup(widget.conversationId),
      successMessage: deleting ? 'گروه حذف شد' : 'از گروه خارج شدید',
      onSuccess: () async {
        await ref.read(chatRepositoryProvider).refreshConversations();
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
    );
  }

  Future<void> _clearHistory() async {
    final confirmed = await _confirm(
      title: 'پاک کردن تاریخچه',
      message:
          'پیام‌های این گروه فقط برای شما از دستگاه و کش گفتگو پاک می‌شود. ادامه می‌دهید؟',
      confirmText: 'پاک کن',
      destructive: true,
    );
    if (!confirmed) return;

    await _runSavingAction(
      () => ref.read(chatRepositoryProvider).clearConversation(
            widget.conversationId,
          ),
      successMessage: 'تاریخچه گروه پاک شد',
      onSuccess: () =>
          ref.invalidate(chatMessagesProvider(widget.conversationId)),
    );
  }

  Future<void> _runSavingAction<T>(
    Future<T> Function() action, {
    required String successMessage,
    VoidCallback? onSuccess,
    void Function(T value)? onSuccessWithValue,
  }) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final value = await action();
      if (!mounted) return;
      onSuccessWithValue?.call(value);
      onSuccess?.call();
      UserFriendlyErrorUtils.showSuccessSnackBar(context, successMessage);
    } catch (error) {
      if (mounted) {
        UserFriendlyErrorUtils.showErrorSnackBar(
          context,
          _mapGroupError(error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmText,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? _darkBg : _lightBg;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            RefreshIndicator(
              onRefresh: _loadGroup,
              child: CustomScrollView(
                slivers: [
                  _buildHeader(theme),
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildQuickActions(theme),
                        _buildGroupInfoSection(theme),
                        _buildTabsSection(theme),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (_isSaving)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.12),
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final avatarProvider = AvatarAssetUtils.imageProvider(_groupImage);
    final isDark = theme.brightness == Brightness.dark;
    return SliverToBoxAdapter(
      child: Stack(
        children: [
          Container(
            height: 340,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  isDark ? const Color(0xFF2A4157) : const Color(0xFF6C9BCF),
                  isDark ? _darkBg : _lightBg,
                ],
              ),
            ),
            child: avatarProvider != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image(image: avatarProvider, fit: BoxFit.cover),
                      ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                          child: ColoredBox(
                            color: Colors.black.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.22),
                              Colors.black.withValues(alpha: 0.62),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ],
                  )
                : null,
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Hero(
                  tag: 'group_avatar_${widget.conversationId}',
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
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
                                  source: _groupImage,
                                  fit: BoxFit.cover,
                                  fallback: _buildAvatarFallback(theme),
                                )
                              : _buildAvatarFallback(theme),
                        ),
                      ),
                      if (_isAdmin)
                        PositionedDirectional(
                          end: 0,
                          bottom: 0,
                          child: _SmallRoundButton(
                            icon: Icons.camera_alt_rounded,
                            onTap: _changeGroupImage,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _groupName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0,
                          shadows: [
                            Shadow(blurRadius: 10, color: Colors.black45),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_memberCount.toString().toPersianDigit()} عضو، ${_adminCount.toString().toPersianDigit()} ادمین',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          LocaleDirectionalPositioned(
            top: MediaQuery.of(context).padding.top + 8,
            start: 8,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: _HeaderCircleIcon(icon: directionalBackIcon(context)),
            ),
          ),
          LocaleDirectionalPositioned(
            top: MediaQuery.of(context).padding.top + 8,
            end: 8,
            child: PopupMenuButton<String>(
              icon: _HeaderCircleIcon(icon: Icons.more_vert),
              onSelected: _handleHeaderMenuAction,
              itemBuilder: (context) => [
                if (_isAdmin)
                  const PopupMenuItem(
                    value: 'edit',
                    child:
                        _MenuRow(icon: Icons.edit_rounded, text: 'ویرایش گروه'),
                  ),
                if (_isAdmin)
                  const PopupMenuItem(
                    value: 'add',
                    child: _MenuRow(
                      icon: Icons.person_add_alt_1_rounded,
                      text: 'افزودن عضو',
                    ),
                  ),
                const PopupMenuItem(
                  value: 'copy',
                  child:
                      _MenuRow(icon: Icons.copy_rounded, text: 'کپی لینک دعوت'),
                ),
                const PopupMenuItem(
                  value: 'share',
                  child: _MenuRow(
                    icon: Icons.ios_share_rounded,
                    text: 'اشتراک لینک',
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear',
                  child: _MenuRow(
                    icon: Icons.cleaning_services_rounded,
                    text: 'پاک کردن تاریخچه',
                  ),
                ),
                PopupMenuItem(
                  value: 'leave',
                  child: _MenuRow(
                    icon: _isCreator
                        ? Icons.delete_forever_rounded
                        : Icons.exit_to_app_rounded,
                    text: _isCreator ? 'حذف گروه' : 'خروج از گروه',
                    destructive: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback(ThemeData theme) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _primaryColor,
            _primaryColor.withValues(alpha: 0.72),
          ],
        ),
      ),
      child: Text(
        _groupName.trim().isNotEmpty ? _groupName.trim()[0].toUpperCase() : 'G',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 44,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  void _handleHeaderMenuAction(String value) {
    switch (value) {
      case 'edit':
        _editName();
        break;
      case 'add':
        _addMembers();
        break;
      case 'copy':
        _copyInviteLink();
        break;
      case 'share':
        _shareInviteLink();
        break;
      case 'clear':
        _clearHistory();
        break;
      case 'leave':
        _leaveOrDeleteGroup();
        break;
    }
  }

  Widget _buildQuickActions(ThemeData theme) {
    return _Section(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          _QuickAction(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'پیام',
            onTap: () => Navigator.of(context).pop(),
          ),
          _QuickAction(
            icon: _isMuted
                ? Icons.notifications_active_rounded
                : Icons.notifications_off_rounded,
            label: _isMuted ? 'فعال‌سازی' : 'بی‌صدا',
            onTap: _toggleMute,
          ),
          _QuickAction(
            icon: Icons.search_rounded,
            label: 'جستجو',
            onTap: () {
              _tabController.animateTo(0);
              FocusScope.of(context).requestFocus(FocusNode());
            },
          ),
          _QuickAction(
            icon:
                _isAdmin ? Icons.person_add_alt_1_rounded : Icons.link_rounded,
            label: _isAdmin ? 'افزودن' : 'دعوت',
            onTap: _isAdmin ? _addMembers : _copyInviteLink,
          ),
        ],
      ),
    );
  }

  Widget _buildGroupInfoSection(ThemeData theme) {
    final role = _isCreator
        ? 'سازنده'
        : _isAdmin
            ? 'ادمین'
            : 'عضو';
    final inviteTitle = _inviteCode == null
        ? (_isAdmin ? 'ساخت لینک دعوت' : 'لینک دعوت ساخته نشده')
        : _inviteLink;
    final inviteSubtitle = _inviteEnabled ? 'لینک دعوت' : 'لینک دعوت غیرفعال';

    return _Section(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.groups_2_rounded,
            title: 'ظرفیت گروه',
            value:
                '${_memberCount.toString().toPersianDigit()} از ${_maxMembers.toString().toPersianDigit()} عضو',
          ),
          _sectionDivider(theme),
          _InfoRow(
            icon: Icons.admin_panel_settings_rounded,
            title: 'نقش شما',
            value: role,
          ),
          if ((_groupDescription ?? '').trim().isNotEmpty) ...[
            _sectionDivider(theme),
            _InfoRow(
              icon: Icons.info_outline_rounded,
              title: 'درباره گروه',
              value: _groupDescription!,
              multiLine: true,
            ),
          ],
          _sectionDivider(theme),
          _InfoRow(
            icon: Icons.link_rounded,
            title: inviteSubtitle,
            value: inviteTitle,
            multiLine: _inviteCode == null,
            onTap: _inviteCode == null
                ? (_isAdmin ? _regenerateInvite : null)
                : _copyInviteLink,
            trailing: _buildInviteMenu(theme),
          ),
          if (_isAdmin) ...[
            _sectionDivider(theme),
            _InfoRow(
              icon: Icons.power_settings_new_rounded,
              title: 'وضعیت دعوت',
              value: _inviteEnabled ? 'فعال' : 'غیرفعال',
              trailing: Switch.adaptive(
                value: _inviteEnabled,
                onChanged: _toggleInvite,
              ),
            ),
            _sectionDivider(theme),
            _InfoRow(
              icon: Icons.edit_note_rounded,
              title: 'مدیریت گروه',
              value: 'ویرایش نام و هویت گروه',
              onTap: _editName,
              trailing: Icon(directionalForwardChevronIcon(context)),
            ),
            _sectionDivider(theme),
            _InfoRow(
              icon: Icons.person_add_alt_1_rounded,
              title: 'افزودن اعضا',
              value:
                  '${_remainingSlots.toString().toPersianDigit()} جای خالی باقی مانده',
              onTap: _addMembers,
              trailing: Icon(directionalForwardChevronIcon(context)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInviteMenu(ThemeData theme) {
    final hasInvite = _inviteCode != null;
    if (!hasInvite && !_isAdmin) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz_rounded, color: theme.hintColor),
      onSelected: (value) {
        switch (value) {
          case 'copy':
            _copyInviteLink();
            break;
          case 'share':
            _shareInviteLink();
            break;
          case 'regenerate':
            _regenerateInvite();
            break;
        }
      },
      itemBuilder: (context) => [
        if (hasInvite)
          const PopupMenuItem(
            value: 'copy',
            child: _MenuRow(icon: Icons.copy_rounded, text: 'کپی لینک'),
          ),
        if (hasInvite)
          const PopupMenuItem(
            value: 'share',
            child: _MenuRow(icon: Icons.ios_share_rounded, text: 'اشتراک لینک'),
          ),
        if (_isAdmin)
          PopupMenuItem(
            value: 'regenerate',
            child: _MenuRow(
              icon: Icons.refresh_rounded,
              text: hasInvite ? 'تغییر لینک' : 'ساخت لینک',
            ),
          ),
      ],
    );
  }

  Widget _sectionDivider(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Divider(
      height: 1,
      indent: 56,
      color: (isDark ? _darkDivider : _lightDivider).withValues(alpha: 0.9),
    );
  }

  Widget _buildTabsSection(ThemeData theme) {
    return _Section(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.hintColor,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: const [
              Tab(text: 'اعضا'),
              Tab(text: 'رسانه'),
              Tab(text: 'فایل‌ها'),
              Tab(text: 'لینک‌ها'),
              Tab(text: 'صدا'),
            ],
          ),
          SizedBox(
            height: 520,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMembersTab(theme),
                _GroupSharedMessagesTab(
                  conversationId: widget.conversationId,
                  filter: _isMediaMessage,
                  emptyIcon: Icons.photo_library_outlined,
                  emptyText: 'رسانه‌ای پیدا نشد',
                  grid: true,
                  mapError: _mapGroupError,
                ),
                _GroupSharedMessagesTab(
                  conversationId: widget.conversationId,
                  filter: _isFileMessage,
                  emptyIcon: Icons.insert_drive_file_outlined,
                  emptyText: 'فایلی پیدا نشد',
                  mapError: _mapGroupError,
                ),
                _GroupSharedMessagesTab(
                  conversationId: widget.conversationId,
                  filter: _hasLink,
                  emptyIcon: Icons.link_off_rounded,
                  emptyText: 'لینکی پیدا نشد',
                  isLinkTab: true,
                  mapError: _mapGroupError,
                ),
                _GroupSharedMessagesTab(
                  conversationId: widget.conversationId,
                  filter: _isVoiceMessage,
                  emptyIcon: Icons.keyboard_voice_outlined,
                  emptyText: 'پیام صوتی پیدا نشد',
                  mapError: _mapGroupError,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersTab(ThemeData theme) {
    final members = _filteredMembers;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: TextField(
            controller: _memberSearchController,
            decoration: InputDecoration(
              hintText: 'جستجوی اعضا',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _memberSearchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: _memberSearchController.clear,
                    ),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.45),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: members.isEmpty
              ? _EmptyPanel(
                  icon: Icons.person_search_rounded,
                  text: 'عضوی با این جستجو پیدا نشد',
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: members.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    indent: 72,
                    color: theme.dividerColor.withValues(alpha: 0.35),
                  ),
                  itemBuilder: (context, index) =>
                      _buildMemberTile(theme, members[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildMemberTile(ThemeData theme, GroupMemberItem member) {
    final isMe = member.userId == _currentUserId;
    final isTargetCreator = member.userId == _createdBy;
    final canManage = !isMe &&
        (_isCreator || (_isAdmin && !member.isAdmin && !isTargetCreator));

    return ListTile(
      leading: CircleAvatar(
        backgroundImage:
            member.avatarUrl != null ? NetworkImage(member.avatarUrl!) : null,
        child: member.avatarUrl == null
            ? Text(
                member.displayName.isNotEmpty
                    ? member.displayName[0].toUpperCase()
                    : '?',
              )
            : null,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              member.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (isMe) const SizedBox(width: 6),
          if (isMe) const _RolePill(text: 'شما'),
        ],
      ),
      subtitle: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          if (isTargetCreator)
            const _RolePill(text: 'سازنده', icon: Icons.workspace_premium),
          if (!isTargetCreator && member.isAdmin)
            const _RolePill(text: 'ادمین', icon: Icons.shield_rounded),
          if (member.joinedAt != null)
            Text(
              'عضویت: ${_formatShortDate(member.joinedAt!)}',
              style: TextStyle(color: theme.hintColor, fontSize: 12),
            ),
        ],
      ),
      trailing: canManage
          ? PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'admin') {
                  _toggleAdmin(member);
                } else if (value == 'remove') {
                  _removeMember(member);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'admin',
                  child: _MenuRow(
                    icon: member.isAdmin
                        ? Icons.remove_moderator_rounded
                        : Icons.admin_panel_settings_rounded,
                    text: member.isAdmin ? 'برداشتن ادمین' : 'ادمین کردن',
                  ),
                ),
                const PopupMenuItem(
                  value: 'remove',
                  child: _MenuRow(
                    icon: Icons.person_remove_rounded,
                    text: 'حذف از گروه',
                    destructive: true,
                  ),
                ),
              ],
            )
          : null,
    );
  }

  int _memberRank(GroupMemberItem member) {
    if (member.userId == _createdBy) return 3;
    if (member.isAdmin) return 2;
    if (member.userId == _currentUserId) return 1;
    return 0;
  }

  bool _isMediaMessage(MessageModel message) {
    final type = _messageType(message);
    return message.isImage ||
        message.isVideo ||
        type == 'gif' ||
        type == 'image' ||
        type == 'video' ||
        type == 'photo';
  }

  bool _isVoiceMessage(MessageModel message) {
    final type = _messageType(message);
    return (message.audioUrl?.trim().isNotEmpty ?? false) ||
        type == 'voice' ||
        type == 'audio' ||
        (message.attachmentType?.startsWith('audio') ?? false);
  }

  bool _isFileMessage(MessageModel message) {
    final type = _messageType(message);
    final hasAttachment = message.attachmentUrl?.trim().isNotEmpty ?? false;
    if (!hasAttachment) return false;
    if (_isMediaMessage(message) || _isVoiceMessage(message)) return false;
    return type == 'file' ||
        type == 'document' ||
        type == 'pdf' ||
        message.attachmentFileName != null ||
        message.attachmentMimeType != null;
  }

  bool _hasLink(MessageModel message) {
    return RegExp(r'(https?:\/\/|www\.)\S+', caseSensitive: false)
        .hasMatch(message.content);
  }

  String _messageType(MessageModel message) {
    return (message.messageType ?? message.attachmentType ?? '')
        .trim()
        .toLowerCase();
  }

  static String _formatShortDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}'.toPersianDigit();
  }

  static String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute'.toPersianDigit();
  }

  String _mapGroupError(Object error) {
    final message = error.toString();
    if (message.contains('max_members_exceeded')) {
      return 'ظرفیت گروه تکمیل است';
    }
    if (message.contains('user_add_not_allowed')) {
      return 'یکی از کاربران اجازه اضافه شدن به گروه را نداده است';
    }
    if (message.contains('admin_required')) {
      return 'فقط ادمین می‌تواند این کار را انجام دهد';
    }
    if (message.contains('creator_required')) {
      return 'فقط سازنده گروه می‌تواند این کار را انجام دهد';
    }
    if (message.contains('creator_cannot_leave')) {
      return 'سازنده گروه نمی‌تواند گروه را ترک کند';
    }
    return 'عملیات گروه انجام نشد';
  }

  static String? _stringFrom(Map<String, dynamic>? map, List<String> keys) {
    if (map == null) return null;
    for (final key in keys) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static int _intFrom(
    Map<String, dynamic>? map,
    List<String> keys, {
    required int fallback,
  }) {
    if (map == null) return fallback;
    for (final key in keys) {
      final value = map[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  static bool _boolFrom(
    Map<String, dynamic>? map,
    List<String> keys, {
    required bool fallback,
  }) {
    if (map == null) return fallback;
    for (final key in keys) {
      final value = map[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.toLowerCase();
        if (normalized == 'true' || normalized == '1') return true;
        if (normalized == 'false' || normalized == '0') return false;
      }
    }
    return fallback;
  }
}

class _AddMembersSheet extends StatefulWidget {
  final int remainingSlots;
  final Set<String> existingMemberIds;

  const _AddMembersSheet({
    required this.remainingSlots,
    required this.existingMemberIds,
  });

  @override
  State<_AddMembersSheet> createState() => _AddMembersSheetState();
}

class _AddMembersSheetState extends State<_AddMembersSheet> {
  final _service = GroupService();
  final _searchController = TextEditingController();
  final _selectedIds = <String>{};

  List<GroupUserItem> _interactions = const [];
  List<GroupUserItem> _results = const [];
  bool _isLoading = true;
  bool _isSearching = false;
  CancelToken? _searchCancelToken;

  @override
  void initState() {
    super.initState();
    _loadInteractions();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCancelToken?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInteractions() async {
    setState(() => _isLoading = true);
    final users = await _service.getInteractionUsers();
    if (!mounted) return;
    setState(() {
      _interactions = users
          .where((u) => !widget.existingMemberIds.contains(u.id))
          .toList(growable: false);
      _isLoading = false;
    });
  }

  Future<void> _onSearchChanged() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      if (mounted) setState(() => _results = const []);
      return;
    }

    _searchCancelToken?.cancel();
    _searchCancelToken = CancelToken();
    setState(() => _isSearching = true);
    try {
      final users = await _service.searchUsers(
        query,
        cancelToken: _searchCancelToken,
      );
      if (!mounted) return;
      setState(() {
        _results = users
            .where((u) => !widget.existingMemberIds.contains(u.id))
            .toList(growable: false);
        _isSearching = false;
      });
    } catch (error) {
      if (error is DioException && error.type == DioExceptionType.cancel) {
        return;
      }
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _toggle(GroupUserItem user) {
    if (_selectedIds.contains(user.id)) {
      setState(() => _selectedIds.remove(user.id));
      return;
    }
    if (_selectedIds.length >= widget.remainingSlots) {
      UserFriendlyErrorUtils.showErrorSnackBar(
        context,
        'ظرفیت باقی‌مانده کافی نیست',
      );
      return;
    }
    setState(() => _selectedIds.add(user.id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _searchController.text.trim();
    final list = query.isEmpty ? _interactions : _results;

    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'افزودن اعضا',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${_selectedIds.length}/${widget.remainingSlots}'
                          .toPersianDigit(),
                      style: TextStyle(color: theme.hintColor),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'جستجو در کاربران',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.45),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _isLoading || _isSearching
                    ? const Center(child: CircularProgressIndicator())
                    : list.isEmpty
                        ? const _EmptyPanel(
                            icon: Icons.person_search_rounded,
                            text: 'کاربری پیدا نشد',
                          )
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: list.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1, indent: 72),
                            itemBuilder: (context, index) {
                              final user = list[index];
                              final selected = _selectedIds.contains(user.id);
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: user.avatarUrl != null
                                      ? NetworkImage(user.avatarUrl!)
                                      : null,
                                  child: user.avatarUrl == null
                                      ? Text(user.displayName.isNotEmpty
                                          ? user.displayName[0].toUpperCase()
                                          : '?')
                                      : null,
                                ),
                                title: Text(
                                  user.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: user.messageCount > 0
                                    ? Text(
                                        '${user.messageCount} پیام مشترک'
                                            .toPersianDigit(),
                                      )
                                    : null,
                                trailing: Icon(
                                  selected
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  color: selected
                                      ? theme.colorScheme.primary
                                      : theme.hintColor,
                                ),
                                onTap: () => _toggle(user),
                              );
                            },
                          ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _selectedIds.isEmpty
                          ? null
                          : () => Navigator.pop(
                                context,
                                _selectedIds.toList(growable: false),
                              ),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('افزودن به گروه'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;

  const _Section({
    required this.child,
    this.margin = const EdgeInsets.fromLTRB(12, 8, 12, 8),
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? _ModernGroupProfileScreenState._darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDark
            ? null
            : Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: child,
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
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
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 23),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool multiLine;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
    this.multiLine = false,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment:
            multiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: multiLine ? 4 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

class _RolePill extends StatelessWidget {
  final String text;
  final IconData? icon;

  const _RolePill({required this.text, this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: theme.colorScheme.primary),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaThumb extends StatelessWidget {
  final MessageModel message;

  const _MediaThumb({required this.message});

  @override
  Widget build(BuildContext context) {
    final url = message.attachmentUrl;
    final isImage = message.isImage && url != null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isImage)
              Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
              )
            else
              const Center(
                child: Icon(Icons.play_circle_fill_rounded, size: 34),
              ),
            PositionedDirectional(
              end: 6,
              bottom: 6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  child: Text(
                    _ModernGroupProfileScreenState._formatTime(
                      message.createdAt,
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SharedMessageTile extends StatelessWidget {
  final MessageModel message;
  final bool isLink;

  const _SharedMessageTile({
    required this.message,
    required this.isLink,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = isLink
        ? Icons.link_rounded
        : (message.audioUrl != null
            ? Icons.keyboard_voice_rounded
            : Icons.insert_drive_file_rounded);
    final title = isLink
        ? _firstLink(message.content)
        : (message.attachmentFileName ?? message.content.trim());

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
        child: Icon(icon, color: theme.colorScheme.primary),
      ),
      title: Text(
        title.isEmpty ? 'پیام پیوست‌دار' : title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _ModernGroupProfileScreenState._formatShortDate(message.createdAt),
      ),
      onTap:
          isLink ? () => Clipboard.setData(ClipboardData(text: title)) : null,
    );
  }

  static String _firstLink(String content) {
    final match =
        RegExp(r'(https?:\/\/|www\.)\S+', caseSensitive: false).firstMatch(
      content,
    );
    return match?.group(0) ?? content;
  }
}

class _GroupSharedMessagesTab extends ConsumerStatefulWidget {
  const _GroupSharedMessagesTab({
    required this.conversationId,
    required this.filter,
    required this.emptyIcon,
    required this.emptyText,
    this.grid = false,
    this.isLinkTab = false,
    required this.mapError,
  });

  final String conversationId;
  final bool Function(MessageModel message) filter;
  final IconData emptyIcon;
  final String emptyText;
  final bool grid;
  final bool isLinkTab;
  final String Function(Object error) mapError;

  @override
  ConsumerState<_GroupSharedMessagesTab> createState() =>
      _GroupSharedMessagesTabState();
}

class _GroupSharedMessagesTabState
    extends ConsumerState<_GroupSharedMessagesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final messagesAsync =
        ref.watch(chatMessagesProvider(widget.conversationId));

    return messagesAsync.when(
      data: (messages) {
        final items = messages.where(widget.filter).toList(growable: false);
        if (items.isEmpty) {
          return _EmptyPanel(
            icon: widget.emptyIcon,
            text: widget.emptyText,
          );
        }
        if (widget.grid) {
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) => _MediaThumb(message: items[index]),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: items.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            indent: 64,
            color: theme.dividerColor.withValues(alpha: 0.35),
          ),
          itemBuilder: (context, index) => _SharedMessageTile(
            message: items[index],
            isLink: widget.isLinkTab,
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _EmptyPanel(
        icon: Icons.error_outline_rounded,
        text: widget.mapError(error),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyPanel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: theme.hintColor.withValues(alpha: 0.45)),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.hintColor),
          ),
        ],
      ),
    );
  }
}

class _SmallRoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SmallRoundButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.primary,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

class _HeaderCircleIcon extends StatelessWidget {
  final IconData icon;

  const _HeaderCircleIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool destructive;

  const _MenuRow({
    required this.icon,
    required this.text,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? Theme.of(context).colorScheme.error
        : IconTheme.of(context).color;
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            color: destructive ? Theme.of(context).colorScheme.error : null,
          ),
        ),
      ],
    );
  }
}
