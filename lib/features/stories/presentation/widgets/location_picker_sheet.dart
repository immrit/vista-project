import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../../utils/user_friendly_error_utils.dart';

/// صفحه انتخاب لوکیشن با GPS (مشابه تلگرام)
class LocationPickerSheet extends StatefulWidget {
  final Function(String locationName, double lat, double lng)
      onLocationSelected;

  const LocationPickerSheet({super.key, required this.onLocationSelected});

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  bool _isLoading = true;
  String? _error;
  Position? _currentPosition;
  List<Placemark> _nearbyPlaces = [];
  String? _currentAddress;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // بررسی سرویس لوکیشن
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _error = 'سرویس موقعیت‌یابی غیرفعال است';
          _isLoading = false;
        });
        return;
      }

      // بررسی و درخواست مجوز
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _error = 'دسترسی به موقعیت‌یابی رد شد';
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _error = 'دسترسی به موقعیت‌یابی برای همیشه رد شده است';
          _isLoading = false;
        });
        return;
      }

      // گرفتن موقعیت فعلی
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() => _currentPosition = position);

      // تبدیل مختصات به آدرس
      await _getAddressFromCoordinates(position.latitude, position.longitude);
    } catch (e) {
      setState(() {
        _error = UserFriendlyErrorUtils.getUserFriendlyMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;

        // ساخت آدرس خوانا
        final addressParts = <String>[];
        if (place.thoroughfare?.isNotEmpty == true) {
          addressParts.add(place.thoroughfare!);
        }
        if (place.subLocality?.isNotEmpty == true) {
          addressParts.add(place.subLocality!);
        }
        if (place.locality?.isNotEmpty == true) {
          addressParts.add(place.locality!);
        }

        setState(() {
          _currentAddress =
              addressParts.isNotEmpty ? addressParts.join('، ') : 'موقعیت فعلی';
          _nearbyPlaces = placemarks;
          _isLoading = false;
        });
      } else {
        setState(() {
          _currentAddress = 'موقعیت فعلی';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _currentAddress = 'موقعیت فعلی';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // عنوان
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.red, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'انتخاب موقعیت',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.grey),

          // محتوا
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'در حال دریافت موقعیت...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, color: Colors.red[400], size: 48),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400]),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _getCurrentLocation,
              icon: const Icon(Icons.refresh),
              label: const Text('تلاش مجدد'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // موقعیت فعلی
        _buildLocationTile(
          icon: Icons.my_location,
          iconColor: Colors.blue,
          title: 'موقعیت فعلی',
          subtitle: _currentAddress ?? 'در حال دریافت...',
          onTap: () {
            final pos = _currentPosition;
            if (pos != null) {
              widget.onLocationSelected(
                _currentAddress ?? 'موقعیت فعلی',
                pos.latitude,
                pos.longitude,
              );
              Navigator.pop(context);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('موقعیت هنوز دریافت نشده است')),
              );
            }
          },
        ),

        const SizedBox(height: 8),

        // مکان‌های نزدیک
        if (_nearbyPlaces.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'مکان‌های نزدیک',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ..._nearbyPlaces.take(5).map((place) {
            final name = place.name ??
                place.thoroughfare ??
                place.subLocality ??
                'نامشخص';
            final address = [
              place.thoroughfare,
              place.subLocality,
              place.locality,
            ].where((e) => e?.isNotEmpty == true).join('، ');

            return _buildLocationTile(
              icon: Icons.place,
              iconColor: Colors.orange,
              title: name,
              subtitle: address.isNotEmpty ? address : 'آدرس نامشخص',
              onTap: () {
                final pos = _currentPosition;
                if (pos != null) {
                  widget.onLocationSelected(
                    name,
                    pos.latitude,
                    pos.longitude,
                  );
                  Navigator.pop(context);
                }
              },
            );
          }),
        ],

        const SizedBox(height: 16),

        // ورود دستی
        _buildLocationTile(
          icon: Icons.edit_location_alt,
          iconColor: Colors.green,
          title: 'وارد کردن دستی',
          subtitle: 'نام مکان را خودتان بنویسید',
          onTap: () => _showManualInput(),
        ),
      ],
    );
  }

  Widget _buildLocationTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      color: Colors.grey[800],
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.2),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.arrow_forward_ios,
            color: Colors.white38, size: 16),
        onTap: onTap,
      ),
    );
  }

  void _showManualInput() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('نام مکان', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'مثال: کافه پارسیان',
            hintStyle: TextStyle(color: Colors.grey[500]),
            prefixIcon: const Icon(Icons.location_on, color: Colors.red),
            filled: true,
            fillColor: Colors.grey[800],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                final latitude = _currentPosition?.latitude ?? double.nan;
                final longitude = _currentPosition?.longitude ?? double.nan;
                widget.onLocationSelected(
                  controller.text,
                  latitude,
                  longitude,
                );
                Navigator.pop(ctx);
                Navigator.pop(context);
              }
            },
            child: const Text('تأیید'),
          ),
        ],
      ),
    );
  }
}
