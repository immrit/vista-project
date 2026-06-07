import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_controller.dart';
import '../services/group_service.dart';
import '../services/chat_attachment_service.dart';
import '../providers/chat_providers.dart';

class GroupEditScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const GroupEditScreen({super.key, required this.conversationId});

  @override
  ConsumerState<GroupEditScreen> createState() => _GroupEditScreenState();
}

class _GroupEditScreenState extends ConsumerState<GroupEditScreen> {
  final _groupService = GroupService();
  final _attachmentService = ChatAttachmentService();

  bool _isLoading = true;
  bool _isSaving = false;
  String _groupName = '';
  String? _groupImage;
  String? _inviteCode;
  bool _inviteEnabled = true;
  String? _createdBy;
  String? _currentUserId;

  bool get _isCreator => _createdBy == _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final userId = await TokenStorage.getUserId();
      final info = await _groupService.fetchGroupInfo(widget.conversationId);
      final invite = await _groupService.getInvite(widget.conversationId);

      if (!mounted) return;
      setState(() {
        _currentUserId = userId;
        _groupName = info?['name'] as String? ?? 'گروه';
        _groupImage = info?['image'] as String?;
        _createdBy = info?['created_by'] as String?;
        _inviteCode = invite['invite_code'] as String?;
        _inviteEnabled = invite['invite_enabled'] as bool? ?? true;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack('خطا در دریافت اطلاعات');
    }
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: _groupName);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ویرایش نام گروه'),
        content: TextField(
          controller: controller,
          maxLength: 50,
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

    final newName = result?.trim() ?? '';
    if (newName.isEmpty || newName.length > 50 || newName == _groupName) return;
    setState(() => _isSaving = true);
    try {
      await _groupService.updateGroupInfo(widget.conversationId, name: newName);
      await ref.read(chatRepositoryProvider).refreshConversations();
      if (mounted) setState(() => _groupName = newName);
    } catch (e) {
      if (mounted) _showSnack('خطا در تغییر نام');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _changeGroupImage() async {
    final result = await _attachmentService.pickImageFromGallery(
      conversationId: widget.conversationId,
    );
    if (!result.success || result.url == null) return;
    setState(() => _isSaving = true);
    try {
      await _groupService.updateGroupInfo(
        widget.conversationId,
        imageUrl: result.url,
      );
      await ref.read(chatRepositoryProvider).refreshConversations();
      if (mounted) setState(() => _groupImage = result.url);
    } catch (e) {
      if (mounted) _showSnack('خطا در تغییر تصویر');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String get _inviteLink =>
      _inviteCode == null ? '' : 'https://cafevista.ir/group/$_inviteCode';

  Future<void> _copyInviteLink() async {
    if (_inviteCode == null) return;
    await Clipboard.setData(ClipboardData(text: _inviteLink));
    if (mounted) _showSnack('لینک دعوت کپی شد');
  }

  Future<void> _regenerateInvite() async {
    setState(() => _isSaving = true);
    try {
      final code = await _groupService.regenerateInvite(widget.conversationId);
      if (mounted) setState(() => _inviteCode = code);
    } catch (e) {
      if (mounted) _showSnack('خطا در تغییر لینک');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _toggleInvite(bool enabled) async {
    setState(() => _inviteEnabled = enabled);
    try {
      await _groupService.setInviteEnabled(widget.conversationId, enabled);
    } catch (e) {
      if (mounted) {
        setState(() => _inviteEnabled = !enabled);
        _showSnack('خطا در تغییر وضعیت لینک');
      }
    }
  }

  Future<void> _leaveOrDeleteGroup() async {
    final isDeleting = _isCreator;
    final title = isDeleting ? 'حذف گروه' : 'خروج از گروه';
    final content = isDeleting
        ? 'آیا از حذف کامل این گروه اطمینان دارید؟ این عملیات غیرقابل بازگشت است.'
        : 'آیا می‌خواهید از این گروه خارج شوید؟';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isDeleting ? 'حذف' : 'خروج',
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      setState(() => _isSaving = true);
      if (isDeleting) {
        await _groupService.deleteGroup(widget.conversationId);
      } else {
        await _groupService.leaveGroup(widget.conversationId);
      }
      await ref.read(chatRepositoryProvider).refreshConversations();
      if (mounted) {
        // Pop all the way back to main chat screen
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showSnack('خطا در انجام عملیات');
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظیمات گروه'),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                ListView(
                  children: [
                    _buildAvatarSection(theme),
                    const Divider(height: 1),
                    _buildNameSection(theme),
                    const SizedBox(height: 20),
                    _buildInviteSection(theme),
                    const SizedBox(height: 20),
                    _buildDangerZone(theme),
                    const SizedBox(height: 40),
                  ],
                ),
                if (_isSaving)
                  Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
    );
  }

  Widget _buildAvatarSection(ThemeData theme) {
    return Container(
      color: theme.cardColor,
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            backgroundImage:
                _groupImage != null ? NetworkImage(_groupImage!) : null,
            child: _groupImage == null
                ? Text(
                    _groupName.isNotEmpty ? _groupName[0] : 'G',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _changeGroupImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameSection(ThemeData theme) {
    return Material(
      color: theme.cardColor,
      child: ListTile(
        title: const Text('نام گروه'),
        subtitle: Text(_groupName, style: const TextStyle(fontSize: 16)),
        trailing: const Icon(Icons.edit, size: 20),
        onTap: _editName,
      ),
    );
  }

  Widget _buildInviteSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'لینک دعوت',
            style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
          ),
        ),
        Material(
          color: theme.cardColor,
          child: Column(
            children: [
              ListTile(
                title: Text(_inviteCode == null ? 'لینک هنوز ساخته نشده' : _inviteLink,
                    style: TextStyle(color: theme.hintColor, fontSize: 14)),
                trailing: IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: _inviteCode == null ? null : _copyInviteLink,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('تغییر لینک دعوت'),
                onTap: _regenerateInvite,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.link),
                title: const Text('فعال بودن لینک دعوت'),
                value: _inviteEnabled,
                onChanged: _toggleInvite,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDangerZone(ThemeData theme) {
    final isDeleting = _isCreator;
    return Material(
      color: theme.cardColor,
      child: ListTile(
        leading: Icon(isDeleting ? Icons.delete_forever : Icons.exit_to_app, color: Colors.red),
        title: Text(
          isDeleting ? 'حذف گروه' : 'خروج از گروه',
          style: const TextStyle(color: Colors.red),
        ),
        onTap: _leaveOrDeleteGroup,
      ),
    );
  }
}
