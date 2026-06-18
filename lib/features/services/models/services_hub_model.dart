class ServiceSection {
  final int id;
  final String title;
  final String subtitle;
  final String icon;
  final String route;
  final String color;
  final bool isActive;
  final int sortOrder;

  const ServiceSection({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    required this.color,
    required this.isActive,
    required this.sortOrder,
  });

  factory ServiceSection.fromJson(Map<String, dynamic> json) => ServiceSection(
        id: json['id'] as int? ?? 0,
        title: json['title'] as String? ?? '',
        subtitle: json['subtitle'] as String? ?? '',
        icon: json['icon'] as String? ?? 'grid',
        route: json['route'] as String? ?? '',
        color: json['color'] as String? ?? '#6366F1',
        isActive: json['is_active'] as bool? ?? true,
        sortOrder: json['sort_order'] as int? ?? 0,
      );
}

// heightType: "sm"(100) | "md"(160) | "lg"(220) | "xl"(300)
// linkType:   "web" | "route" | "none"
class ServiceBanner {
  final int id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String link;
  final String linkType;
  final String heightType;
  final String bgColor;
  final String textColor;
  final bool isActive;
  final int sortOrder;

  const ServiceBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.link,
    required this.linkType,
    required this.heightType,
    required this.bgColor,
    required this.textColor,
    required this.isActive,
    required this.sortOrder,
  });

  double get heightDp => switch (heightType) {
        'sm' => 100,
        'lg' => 220,
        'xl' => 300,
        _ => 160,
      };

  factory ServiceBanner.fromJson(Map<String, dynamic> json) => ServiceBanner(
        id: json['id'] as int? ?? 0,
        title: json['title'] as String? ?? '',
        subtitle: json['subtitle'] as String? ?? '',
        imageUrl: json['image_url'] as String? ?? '',
        link: json['link'] as String? ?? '',
        linkType: json['link_type'] as String? ?? 'web',
        heightType: json['height_type'] as String? ?? 'md',
        bgColor: json['bg_color'] as String? ?? '#6366F1',
        textColor: json['text_color'] as String? ?? '#FFFFFF',
        isActive: json['is_active'] as bool? ?? true,
        sortOrder: json['sort_order'] as int? ?? 0,
      );
}

class ServicesHubData {
  final List<ServiceSection> sections;
  final List<ServiceBanner> banners;

  const ServicesHubData({required this.sections, required this.banners});

  factory ServicesHubData.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'] as List<dynamic>? ?? [];
    final rawBanners = json['banners'] as List<dynamic>? ?? [];
    return ServicesHubData(
      sections: rawSections
          .map((e) => ServiceSection.fromJson(e as Map<String, dynamic>))
          .toList(),
      banners: rawBanners
          .map((e) => ServiceBanner.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ContactVistaUser {
  final String id;
  final String username;
  final String fullName;
  final String avatarUrl;
  final bool isVerified;
  final String verificationType;
  final String phoneNumber;

  const ContactVistaUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.avatarUrl,
    required this.isVerified,
    required this.verificationType,
    required this.phoneNumber,
  });

  factory ContactVistaUser.fromJson(Map<String, dynamic> json) =>
      ContactVistaUser(
        id: json['id'] as String? ?? '',
        username: json['username'] as String? ?? '',
        fullName: json['full_name'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String? ?? '',
        isVerified: json['is_verified'] as bool? ?? false,
        verificationType: json['verification_type'] as String? ?? '',
        phoneNumber: json['phone_number'] as String? ?? '',
      );
}
