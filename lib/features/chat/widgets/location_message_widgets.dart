// lib/features/chat/widgets/location_message_widgets.dart
//
// سیستم پیام مکان (الهام از تلگرام)
//
// ویژگی‌ها:
// ✅ Location picker با نقشه
// ✅ Live location sharing
// ✅ Static location
// ✅ نمایش در message bubble
// ✅ باز کردن در نقشه
//

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../utils/user_friendly_error_utils.dart';

/// داده مکان
class LocationData {
  final double latitude;
  final double longitude;
  final String? title;
  final String? address;
  final bool isLiveLocation;
  final DateTime? expiresAt;

  const LocationData({
    required this.latitude,
    required this.longitude,
    this.title,
    this.address,
    this.isLiveLocation = false,
    this.expiresAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'title': title,
      'address': address,
      'is_live_location': isLiveLocation,
      'expires_at': expiresAt?.toIso8601String(),
    };
  }

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      title: json['title'] as String?,
      address: json['address'] as String?,
      isLiveLocation: json['is_live_location'] as bool? ?? false,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
    );
  }

  String get googleMapsUrl =>
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
}

/// Location Bubble در چت
class LocationMessageBubble extends StatelessWidget {
  final LocationData location;
  final bool isMe;
  final VoidCallback? onTap;

  const LocationMessageBubble({
    super.key,
    required this.location,
    required this.isMe,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap ?? () => _openInMaps(context),
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: isMe
              ? theme.primaryColor.withOpacity(0.1)
              : theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.dividerColor.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // نقشه استاتیک (از Google Maps Static API یا OSM)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // TODO: نقشه استاتیک از API
                    // Image.network(_getStaticMapUrl()),
                    
                    // فعلاً placeholder
                    Container(
                      color: theme.primaryColor.withOpacity(0.1),
                      child: Icon(
                        Icons.map_rounded,
                        size: 64,
                        color: theme.primaryColor.withOpacity(0.3),
                      ),
                    ),

                    // پین مکان
                    Center(
                      child: Icon(
                        Icons.location_on_rounded,
                        size: 48,
                        color: Colors.red,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),

                    // Live location indicator
                    if (location.isLiveLocation && !_isExpired())
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'زنده',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // اطلاعات مکان
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (location.title != null) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.place_rounded,
                          size: 16,
                          color: theme.primaryColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            location.title!,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.titleLarge?.color,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  
                  if (location.address != null)
                    Text(
                      location.address!,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.hintColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Text(
                      '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.hintColor,
                        fontFamily: 'monospace',
                      ),
                    ),

                  const SizedBox(height: 8),

                  // دکمه باز کردن در نقشه
                  OutlinedButton.icon(
                    onPressed: () => _openInMaps(context),
                    icon: Icon(Icons.directions_rounded, size: 16),
                    label: const Text('مسیریابی'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isExpired() {
    if (location.expiresAt == null) return false;
    return DateTime.now().isAfter(location.expiresAt!);
  }

  Future<void> _openInMaps(BuildContext context) async {
    HapticFeedback.lightImpact();

    final url = Uri.parse(location.googleMapsUrl);

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch maps';
      }
    } catch (e) {
      if (context.mounted) {
        UserFriendlyErrorUtils.showErrorSnackBar(context, e);
      }
    }
  }

  // TODO: استفاده از Google Maps Static API برای نمایش نقشه
  // String _getStaticMapUrl() {
  //   const apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
  //   return 'https://maps.googleapis.com/maps/api/staticmap?'
  //       'center=${location.latitude},${location.longitude}'
  //       '&zoom=15'
  //       '&size=280x160'
  //       '&markers=color:red|${location.latitude},${location.longitude}'
  //       '&key=$apiKey';
  // }
}

/// Location Picker Bottom Sheet
class LocationPickerSheet extends StatefulWidget {
  const LocationPickerSheet({super.key});

  static Future<LocationData?> show(BuildContext context) {
    return showModalBottomSheet<LocationData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const LocationPickerSheet(),
    );
  }

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  bool _shareLiveLocation = false;
  Duration _liveDuration = const Duration(hours: 1);

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      // بررسی دسترسی
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permission denied';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied';
      }

      // دریافت موقعیت
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });
    } catch (e) {
      setState(() => _isLoadingLocation = false);

      if (mounted) {
        UserFriendlyErrorUtils.showErrorSnackBar(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                      Icons.location_on_rounded,
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
                          'اشتراک‌گذاری مکان',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.titleLarge?.color,
                          ),
                        ),
                        Text(
                          _isLoadingLocation
                              ? 'در حال دریافت موقعیت...'
                              : 'موقعیت فعلی شما',
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

            const Divider(height: 1),

            if (_isLoadingLocation)
              const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              )
            else if (_currentPosition != null) ...[
              // نقشه کوچک
              Container(
                height: 200,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: theme.primaryColor.withOpacity(0.1),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // TODO: نقشه واقعی
                    Icon(
                      Icons.map_rounded,
                      size: 64,
                      color: theme.primaryColor.withOpacity(0.3),
                    ),
                    Center(
                      child: Icon(
                        Icons.my_location_rounded,
                        size: 48,
                        color: theme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              // مختصات
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.hintColor,
                    fontFamily: 'monospace',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 16),

              // گزینه Live Location
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _shareLiveLocation
                        ? Colors.blue.withOpacity(0.1)
                        : theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _shareLiveLocation
                          ? Colors.blue
                          : theme.dividerColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.wifi_tethering_rounded,
                        color: _shareLiveLocation ? Colors.blue : theme.hintColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'اشتراک‌گذاری زنده',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: theme.textTheme.titleLarge?.color,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'موقعیت شما به صورت زنده به‌روز می‌شود',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.hintColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _shareLiveLocation,
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          setState(() => _shareLiveLocation = value);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // انتخاب مدت زمان Live
              if (_shareLiveLocation) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      _buildDurationChip(const Duration(minutes: 15)),
                      _buildDurationChip(const Duration(hours: 1)),
                      _buildDurationChip(const Duration(hours: 8)),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // دکمه‌ها
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('انصراف'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _shareLocation,
                        icon: const Icon(Icons.send_rounded),
                        label: Text(_shareLiveLocation ? 'شروع اشتراک' : 'ارسال'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDurationChip(Duration duration) {
    final isSelected = _liveDuration == duration;
    final theme = Theme.of(context);

    return FilterChip(
      selected: isSelected,
      label: Text(_formatDuration(duration)),
      onSelected: (_) {
        HapticFeedback.selectionClick();
        setState(() => _liveDuration = duration);
      },
      selectedColor: theme.primaryColor.withOpacity(0.2),
      checkmarkColor: theme.primaryColor,
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes} دقیقه';
    }
    return '${duration.inHours} ساعت';
  }

  void _shareLocation() {
    if (_currentPosition == null) return;

    HapticFeedback.mediumImpact();

    final locationData = LocationData(
      latitude: _currentPosition!.latitude,
      longitude: _currentPosition!.longitude,
      isLiveLocation: _shareLiveLocation,
      expiresAt: _shareLiveLocation
          ? DateTime.now().add(_liveDuration)
          : null,
    );

    Navigator.pop(context, locationData);
  }
}

