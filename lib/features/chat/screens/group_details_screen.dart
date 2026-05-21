import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_controller.dart';
import '../models/group_member_item.dart';
import '../models/group_user_item.dart';
import '../services/group_service.dart';
import '../services/chat_attachment_service.dart';
import '../providers/chat_providers.dart';

class GroupDetailsScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const GroupDetailsScreen({super.key, required this.conversationId});

  @override
  ConsumerState<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends ConsumerState<GroupDetailsScreen> {
  final _groupService = GroupService();
  final _attachmentService = ChatAttachmentService();

  String _groupName = 'گروه';
  String? _groupImage;
  String? _inviteCode;
  bool _inviteEnabled = true;
  String? _createdBy;
  int _maxMembers = 20;
  bool _isLoading = true;
  bool _isSaving = false;
  List<GroupMemberItem> _members = [];
  String? _currentUserId;

  bool get _isAdmin =>
      _members.any((m) => m.userId == _currentUserId && m.isAdmin);

  bool get _isCreator => _createdBy == _currentUserId;

  int get _memberCount => _members.length;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _loadGroup();
  }

  Future<void> _loadCurrentUserId() async {
    final userId = await TokenStorage.getUserId();
    if (!mounted) return;
    setState(() => _currentUserId = userId);
  }

  Future<void> _loadGroup() async {
    setState(() => _isLoading = true);
    final info = await _groupService.fetchGroupInfo(widget.conversationId);
    final members =
        await _groupService.fetchGroupMembers(widget.conversationId);
    final invite = await _groupService.getInvite(widget.conversationId);

    if (!mounted) return;
    setState(() {
      _groupName = info?['name'] as String? ?? 'گروه';
      _groupImage = info?['image'] as String?;
      _createdBy = info?['created_by'] as String?;
      _maxMembers = info?['max_members'] as int? ?? 20;
      _members = members;
      _inviteCode = invite['invite_code'] as String?;
      _inviteEnabled = invite['invite_enabled'] as bool? ?? true;
      _isLoading = false;
    });
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: _groupName);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ویرایش نام گروه'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'نام گروه'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;
    setState(() => _isSaving = true);
    await _groupService.updateGroupInfo(widget.conversationId, name: result);
    await ref.read(chatRepositoryProvider).refreshConversations();
    if (mounted) {
      setState(() {
        _groupName = result;
        _isSaving = false;
      });
    }
  }

  Future<void> _changeGroupImage() async {
    final result = await _attachmentService.pickImageFromGallery(
      conversationId: widget.conversationId,
    );
    if (!result.success || result.url == null) return;
    setState(() => _isSaving = true);
    await _groupService.updateGroupInfo(
      widget.conversationId,
      imageUrl: result.url,
    );
    await ref.read(chatRepositoryProvider).refreshConversations();
    if (mounted) {
      setState(() {
        _groupImage = result.url;
        _isSaving = false;
      });
    }
  }

  String get _inviteLink =>
      _inviteCode == null ? '' : 'https://cafevista.ir/group/$_inviteCode';

  Future<void> _copyInviteLink() async {
    if (_inviteCode == null) return;
    await Clipboard.setData(ClipboardData(text: _inviteLink));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لینک دعوت کپی شد')),
      );
    }
  }

  Future<void> _regenerateInvite() async {
    if (!_isAdmin) return;
    setState(() => _isSaving = true);
    final code = await _groupService.regenerateInvite(widget.conversationId);
    if (mounted) {
      setState(() {
        _inviteCode = code;
        _isSaving = false;
      });
    }
  }

  Future<void> _toggleInvite(bool enabled) async {
    if (!_isAdmin) return;
    setState(() => _inviteEnabled = enabled);
    await _groupService.setInviteEnabled(widget.conversationId, enabled);
  }

  Future<void> _addMembers() async {
    final remaining = _maxMembers - _memberCount;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ظرفیت گروه تکمیل است')),
      );
      return;
    }

    final added = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddMembersSheet(
        remainingSlots: remaining,
        existingMemberIds: _members.map((m) => m.userId).toSet(),
      ),
    );

    if (added == null || added.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await _groupService.addMembers(widget.conversationId, added);
      await _loadGroup();
    } catch (e) {
      if (mounted) {
        _showSnack(_mapGroupError(e));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _removeMember(GroupMemberItem member) async {
    await _groupService.removeMember(widget.conversationId, member.userId);
    await _loadGroup();
  }

  Future<void> _toggleAdmin(GroupMemberItem member) async {
    await _groupService.setAdmin(
      widget.conversationId,
      member.userId,
      makeAdmin: !member.isAdmin,
    );
    await _loadGroup();
  }

  Future<void> _leaveGroup() async {
    await _groupService.leaveGroup(widget.conversationId);
    await ref.read(chatRepositoryProvider).refreshConversations();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _deleteGroup() async {
    await _groupService.deleteGroup(widget.conversationId);
    await ref.read(chatRepositoryProvider).refreshConversations();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _mapGroupError(Object error) {
    final msg = error.toString();
    if (msg.contains('max_members_exceeded')) {
      return 'حداکثر ۲۰ عضو (با شما) مجاز است';
    }
    if (msg.contains('user_add_not_allowed')) {
      return 'یکی از کاربران اجازه اضافه شدن به گروه را نداده است';
    }
    if (msg.contains('admin_required')) {
      return 'فقط ادمین می‌تواند این کار را انجام دهد';
    }
    if (msg.contains('creator_required')) {
      return 'فقط سازنده گروه می‌تواند این کار را انجام دهد';
    }
    if (msg.contains('creator_cannot_leave')) {
      return 'سازنده گروه نمی‌تواند خارج شود';
    }
    return 'خطا در انجام عملیات';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('مدیریت گروه'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeader(theme),
                const SizedBox(height: 16),
                _buildInviteSection(theme),
                const SizedBox(height: 16),
                _buildMembersSection(theme),
                const SizedBox(height: 16),
                _buildDangerZone(theme),
                if (_isSaving) const SizedBox(height: 12),
                if (_isSaving)
                  const Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final accent = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: accent.withOpacity(0.12),
                backgroundImage:
                    _groupImage != null ? NetworkImage(_groupImage!) : null,
                child: _groupImage == null
                    ? Text(
                        _groupName.isNotEmpty ? _groupName[0] : 'G',
                        style: TextStyle(
                          color: accent,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
              if (_isAdmin)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _changeGroupImage,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 14),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _groupName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_isAdmin)
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: _editName,
                        tooltip: 'ویرایش نام',
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '$_memberCount عضو',
                  style: TextStyle(color: theme.hintColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'لینک دعوت',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SelectableText(
            _inviteCode == null ? 'لینک هنوز ساخته نشده' : _inviteLink,
            style: TextStyle(color: theme.hintColor, height: 1.4),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _inviteCode == null ? null : _copyInviteLink,
                icon: const Icon(Icons.copy),
                label: const Text('کپی لینک'),
              ),
              if (_isAdmin)
                OutlinedButton.icon(
                  onPressed: _regenerateInvite,
                  icon: const Icon(Icons.refresh),
                  label: const Text('تغییر لینک'),
                ),
            ],
          ),
          if (_isAdmin) const SizedBox(height: 8),
          if (_isAdmin)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('فعال بودن لینک دعوت'),
              value: _inviteEnabled,
              onChanged: _toggleInvite,
            ),
          if (!_inviteEnabled)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'لینک دعوت غیرفعال است',
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMembersSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'اعضا',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (_isAdmin)
                TextButton.icon(
                  onPressed: _addMembers,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('افزودن'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ..._members.map((m) => _buildMemberTile(m, theme)),
        ],
      ),
    );
  }

  Widget _buildMemberTile(GroupMemberItem member, ThemeData theme) {
    final isMe = member.userId == _currentUserId;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundImage:
            member.avatarUrl != null ? NetworkImage(member.avatarUrl!) : null,
        child: member.avatarUrl == null
            ? Text(member.displayName.isNotEmpty
                ? member.displayName[0].toUpperCase()
                : '?')
            : null,
      ),
      title: Text(member.displayName),
      subtitle: member.isAdmin ? const Text('ادمین') : null,
      trailing: _isAdmin && !isMe
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
                  child: Text(member.isAdmin ? 'حذف ادمین' : 'ادمین کردن'),
                ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Text('حذف از گروه'),
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildDangerZone(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'عملیات گروه',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (!_isCreator)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.exit_to_app, color: Colors.orange),
              title: const Text('خروج از گروه'),
              onTap: _leaveGroup,
            ),
          if (_isCreator)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('حذف گروه'),
              onTap: _deleteGroup,
            ),
        ],
      ),
    );
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
  List<GroupUserItem> _interactions = [];
  List<GroupUserItem> _results = [];
  bool _isLoading = true;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadInteractions();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInteractions() async {
    setState(() => _isLoading = true);
    final users = await _service.getInteractionUsers();
    if (!mounted) return;
    setState(() {
      _interactions =
          users.where((u) => !widget.existingMemberIds.contains(u.id)).toList();
      _isLoading = false;
    });
  }

  void _onSearchChanged() async {
    final q = _searchController.text.trim();
    if (q.isEmpty) {
      if (mounted) setState(() => _results = []);
      return;
    }
    setState(() => _isSearching = true);
    final users = await _service.searchUsers(q);
    if (!mounted) return;
    setState(() {
      _results =
          users.where((u) => !widget.existingMemberIds.contains(u.id)).toList();
      _isSearching = false;
    });
  }

  void _toggle(GroupUserItem user) {
    if (_selectedIds.contains(user.id)) {
      setState(() => _selectedIds.remove(user.id));
      return;
    }
    if (_selectedIds.length >= widget.remainingSlots) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ظرفیت باقی‌مانده کافی نیست')),
      );
      return;
    }
    setState(() => _selectedIds.add(user.id));
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    final list = query.isEmpty ? _interactions : _results;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'افزودن اعضا',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  '${_selectedIds.length} انتخاب شده',
                  style: TextStyle(color: Theme.of(context).hintColor),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'جستجو در کل کاربران',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading || _isSearching
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? const Center(child: Text('کاربری یافت نشد'))
                    : ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
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
                            title: Text(user.displayName),
                            trailing: selected
                                ? const Icon(Icons.check_circle)
                                : const Icon(Icons.circle_outlined),
                            onTap: () => _toggle(user),
                          );
                        },
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _selectedIds.isEmpty
                    ? null
                    : () => Navigator.pop(context, _selectedIds.toList()),
                child: const Text('افزودن'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
