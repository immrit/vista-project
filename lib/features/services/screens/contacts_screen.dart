import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:Vista/core/theme/app_theme.dart';
import 'package:Vista/widgets/skeleton_loading.dart';
import '../models/services_hub_model.dart';
import '../providers/services_hub_provider.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(contactsProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(contactsProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          backgroundColor:
              isDark ? AppColors.darkBackground : AppColors.lightBackground,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : Colors.black,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'مخاطبین در ویستا',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: state.when(
                loading: () => ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 10,
                  itemBuilder: (_, __) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        const BaseSkeletonWidget(width: 48, height: 48, borderRadius: BorderRadius.all(Radius.circular(24))),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            BaseSkeletonWidget(width: 120, height: 16),
                            SizedBox(height: 8),
                            BaseSkeletonWidget(width: 80, height: 12),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                error: (_, __) => _contactsError(isDark),
                data: (users) => users.isEmpty
                    ? _noContacts(isDark)
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        physics: const BouncingScrollPhysics(),
                        itemCount: users.length,
                        itemBuilder: (context, index) => _contactItem(users[index], isDark),
                      ),
              ),
      ),
    );
  }

  Widget _contactItem(ContactVistaUser u, bool isDark) {
    return ListTile(
      onTap: () => Navigator.pushNamed(context, '/profile', arguments: u.id),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
        backgroundImage: u.avatarUrl.isNotEmpty
            ? NetworkImage(u.avatarUrl)
            : null,
        child: u.avatarUrl.isEmpty
            ? Text(
                u.fullName.isNotEmpty ? u.fullName[0] : '?',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              )
            : null,
      ),
      title: Text(
        u.fullName,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      subtitle: u.username.isNotEmpty
          ? Text(
              '@${u.username}',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            )
          : null,
    );
  }

  Widget _noContacts(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
            border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.group_off_rounded,
                  size: 40,
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextSecondary),
              const SizedBox(height: 10),
              Text(
                'هنوز کسی از مخاطبینت ویستا نصب نکرده',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contactsError(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error),
            const SizedBox(width: 8),
            Text('خطا در بارگذاری مخاطبین',
                style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary)),
            const SizedBox(width: 16),
            TextButton(
              onPressed: () => ref.read(contactsProvider.notifier).load(),
              child: const Text('تلاش مجدد',
                  style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }
}
