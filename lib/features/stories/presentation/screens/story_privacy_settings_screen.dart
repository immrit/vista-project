import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/entities.dart';
import '../../core/story_enums.dart';
import '../providers/story_providers.dart';

class StoryPrivacySettingsScreen extends ConsumerStatefulWidget {
  const StoryPrivacySettingsScreen({super.key});

  @override
  ConsumerState<StoryPrivacySettingsScreen> createState() =>
      _StoryPrivacySettingsScreenState();
}

class _StoryPrivacySettingsScreenState
    extends ConsumerState<StoryPrivacySettingsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<StoryUser> _allFriends = [];
  Set<String> _closeFriendIds = {};
  StoryReplyPermission _selectedReplyPermission = StoryReplyPermission.everyone;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final repository = ref.read(storyRepositoryProvider);

      // 1. دریافت لیست دوستان
      final friendsResult = await repository.getFriends();

      // 2. دریافت لیست Close Friends فعلی
      final closeFriendsResult = await repository.getCloseFriends();

      if (mounted) {
        setState(() {
          _allFriends = friendsResult.fold((l) => [], (r) => r);
          _closeFriendIds =
              closeFriendsResult.fold((l) => {}, (r) => r.toSet());
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final repository = ref.read(storyRepositoryProvider);
      await repository.updateCloseFriends(_closeFriendIds.toList());

      // رفرش کردن پروایدر برای اپدیت سایر بخش‌ها
      ref.invalidate(closeFriendsProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تنظیمات با موفقیت ذخیره شد'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در ذخیره تنظیمات: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredFriends = _searchController.text.isEmpty
        ? _allFriends
        : _allFriends
            .where((u) => u.username
                .toLowerCase()
                .contains(_searchController.text.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'دوستان نزدیک',
          style: TextStyle(fontFamily: 'Vazir'),
        ),
        backgroundColor: Colors.black,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            IconButton(
              onPressed: _saveChanges,
              icon: const Icon(Icons.check, color: Colors.green),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() {}),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'جستجو...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredFriends.isEmpty
                    ? Center(
                        child: Text(
                          'کاربری یافت نشد',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    : ListView(
                        children: [
                          // ========== دوستان نزدیک ==========
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                            child: Text(
                              'دوستان نزدیک',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Vazir',
                              ),
                            ),
                          ),
                          ...filteredFriends.map((user) {
                            final isSelected =
                                _closeFriendIds.contains(user.id);
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage:
                                    NetworkImage(user.avatarUrl ?? ''),
                                backgroundColor: Colors.grey[800],
                              ),
                              title: Text(
                                user.username,
                                style: const TextStyle(color: Colors.white),
                              ),
                              trailing: Checkbox(
                                value: isSelected,
                                activeColor: Colors.green,
                                checkColor: Colors.white,
                                side: BorderSide(color: Colors.grey[600]!),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _closeFriendIds.add(user.id);
                                    } else {
                                      _closeFriendIds.remove(user.id);
                                    }
                                  });
                                },
                              ),
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _closeFriendIds.remove(user.id);
                                  } else {
                                    _closeFriendIds.add(user.id);
                                  }
                                });
                              },
                            );
                          }),

                          // ========== تنظیمات پاسخ ==========
                          const Divider(color: Colors.grey, height: 32),
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                            child: Text(
                              'اجازه پاسخ از',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Vazir',
                              ),
                            ),
                          ),
                          ...StoryReplyPermission.values.map((perm) {
                            final isSelected = _selectedReplyPermission == perm;
                            return RadioListTile<StoryReplyPermission>(
                              title: Text(
                                perm.persianTitle,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey[400],
                                  fontFamily: 'Vazir',
                                ),
                              ),
                              value: perm,
                              groupValue: _selectedReplyPermission,
                              activeColor: Colors.green,
                              onChanged: (val) {
                                if (val != null) {
                                  setState(
                                      () => _selectedReplyPermission = val);
                                }
                              },
                            );
                          }),
                          const SizedBox(height: 24),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
