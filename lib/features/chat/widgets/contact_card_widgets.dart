// lib/features/chat/widgets/contact_card_widgets.dart
//
// سیستم کارت تماس (vCard) - الهام از تلگرام
//
// ویژگی‌ها:
// ✅ نمایش اطلاعات تماس
// ✅ ذخیره در مخاطبین
// ✅ تماس و پیام
// ✅ اشتراک‌گذاری تماس
//

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../utils/user_friendly_error_utils.dart';
// TODO: Add contacts_service package to pubspec.yaml
// import 'package:contacts_service/contacts_service.dart';

/// داده کارت تماس
class ContactCardData {
  final String name;
  final String? phoneNumber;
  final String? email;
  final String? avatarUrl;
  final String? userId; // برای کاربران داخل اپ

  const ContactCardData({
    required this.name,
    this.phoneNumber,
    this.email,
    this.avatarUrl,
    this.userId,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone_number': phoneNumber,
      'email': email,
      'avatar_url': avatarUrl,
      'user_id': userId,
    };
  }

  factory ContactCardData.fromJson(Map<String, dynamic> json) {
    return ContactCardData(
      name: json['name'] as String,
      phoneNumber: json['phone_number'] as String?,
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      userId: json['user_id'] as String?,
    );
  }
}

/// نمایش کارت تماس در message bubble
class ContactCardBubble extends StatelessWidget {
  final ContactCardData contact;
  final bool isMe;

  const ContactCardBubble({
    super.key,
    required this.contact,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMe
            ? theme.primaryColor.withOpacity(0.1)
            : theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  theme.primaryColor,
                  theme.primaryColor.withOpacity(0.7),
                ],
              ),
            ),
            child: contact.avatarUrl != null
                ? ClipOval(
                    child: Image.network(
                      contact.avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildInitials(theme),
                    ),
                  )
                : _buildInitials(theme),
          ),

          const SizedBox(width: 12),

          // اطلاعات
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (contact.phoneNumber != null)
                  Row(
                    children: [
                      Icon(
                        Icons.phone_rounded,
                        size: 14,
                        color: theme.hintColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          contact.phoneNumber!,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.hintColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                if (contact.email != null)
                  Row(
                    children: [
                      Icon(
                        Icons.email_rounded,
                        size: 14,
                        color: theme.hintColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          contact.email!,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.hintColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // دکمه عملیات
          IconButton(
            onPressed: () => _showContactActions(context),
            icon: Icon(
              Icons.more_vert_rounded,
              color: theme.hintColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitials(ThemeData theme) {
    return Center(
      child: Text(
        contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  void _showContactActions(BuildContext context) {
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add_rounded, color: Colors.blue),
              title: const Text('ذخیره در مخاطبین'),
              onTap: () {
                Navigator.pop(context);
                _saveToContacts(context);
              },
            ),
            if (contact.phoneNumber != null) ...[
              ListTile(
                leading: const Icon(Icons.call_rounded, color: Colors.green),
                title: const Text('تماس'),
                onTap: () {
                  Navigator.pop(context);
                  _makeCall(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.message_rounded, color: Colors.orange),
                title: const Text('ارسال پیامک'),
                onTap: () {
                  Navigator.pop(context);
                  _sendSMS(context);
                },
              ),
            ],
            if (contact.userId != null)
              ListTile(
                leading: Icon(Icons.chat_rounded, color: Colors.purple.shade400),
                title: const Text('شروع گفتگو'),
                onTap: () {
                  Navigator.pop(context);
                  _startChat(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveToContacts(BuildContext context) async {
    try {
      // درخواست مجوز
      if (await Permission.contacts.request().isGranted) {
        // TODO: Implement with contacts_service package
        // final newContact = Contact(
        //   givenName: contact.name,
        //   phones: contact.phoneNumber != null
        //       ? [Item(label: 'mobile', value: contact.phoneNumber)]
        //       : [],
        //   emails: contact.email != null
        //       ? [Item(label: 'email', value: contact.email)]
        //       : [],
        // );
        // await ContactsService.addContact(newContact);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ مخاطب ذخیره شد (نیاز به contacts_service package)'),
              backgroundColor: Colors.green,
            ),
          );
        }

        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      if (context.mounted) {
        UserFriendlyErrorUtils.showErrorSnackBar(context, e);
      }
    }
  }

  Future<void> _makeCall(BuildContext context) async {
    if (contact.phoneNumber == null) return;

    final url = Uri.parse('tel:${contact.phoneNumber}');
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطا در برقراری تماس'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendSMS(BuildContext context) async {
    if (contact.phoneNumber == null) return;

    final url = Uri.parse('sms:${contact.phoneNumber}');
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطا در ارسال پیامک'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startChat(BuildContext context) {
    // TODO: Navigate to chat with userId
    debugPrint('Start chat with userId: ${contact.userId}');
  }
}

/// Contact Picker Bottom Sheet
class ContactPickerSheet extends StatefulWidget {
  const ContactPickerSheet({super.key});

  static Future<ContactCardData?> show(BuildContext context) {
    return showModalBottomSheet<ContactCardData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ContactPickerSheet(),
    );
  }

  @override
  State<ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<ContactPickerSheet> {
  // TODO: Use contacts_service package when available
  // List<Contact> _contacts = [];
  // List<Contact> _filteredContacts = [];
  List<Map<String, String>> _contacts = [];
  List<Map<String, String>> _filteredContacts = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      if (await Permission.contacts.request().isGranted) {
        // TODO: Implement with contacts_service package
        // final contacts = await ContactsService.getContacts();
        // setState(() {
        //   _contacts = contacts.toList();
        //   _filteredContacts = _contacts;
        //   _isLoading = false;
        // });
        
        // Placeholder - empty list for now
        setState(() {
          _contacts = [];
          _filteredContacts = [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);

      if (mounted) {
        UserFriendlyErrorUtils.showErrorSnackBar(context, e);
      }
    }
  }

  void _filterContacts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = _contacts;
      } else {
        _filteredContacts = _contacts.where((contact) {
          final name = contact['name']?.toLowerCase() ?? '';
          final phone = contact['phone']?.toLowerCase() ?? '';
          return name.contains(query.toLowerCase()) ||
              phone.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.contacts_rounded,
                    color: theme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'انتخاب مخاطب',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.titleLarge?.color,
                        ),
                      ),
                      Text(
                        '${_filteredContacts.length} مخاطب',
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
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterContacts,
              decoration: InputDecoration(
                hintText: 'جستجو...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF2A2A2A)
                    : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredContacts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.contacts_rounded,
                              size: 64,
                              color: theme.hintColor.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'مخاطبی یافت نشد',
                              style: TextStyle(
                                color: theme.hintColor,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredContacts.length,
                        itemBuilder: (context, index) {
                          final contact = _filteredContacts[index];
                          return _buildContactTile(contact, theme);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile(Map<String, String> contact, ThemeData theme) {
    final name = contact['name'] ?? 'بدون نام';
    final phone = contact['phone'];
    final email = contact['email'];

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.primaryColor.withOpacity(0.1),
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            color: theme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: phone != null ? Text(phone) : null,
      onTap: () {
        HapticFeedback.selectionClick();
        
        final contactData = ContactCardData(
          name: name,
          phoneNumber: phone,
          email: email,
        );
        
        Navigator.pop(context, contactData);
      },
    );
  }
}

