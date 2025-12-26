import 'package:flutter/material.dart';
import '../../services/network_status_service.dart';

/// ویجت نمایش وضعیت شبکه در بالای صفحه
class NetworkStatusBanner extends StatefulWidget {
  final Widget child;
  final bool showWhenOnline;

  const NetworkStatusBanner({
    super.key,
    required this.child,
    this.showWhenOnline = false,
  });

  @override
  State<NetworkStatusBanner> createState() => _NetworkStatusBannerState();
}

class _NetworkStatusBannerState extends State<NetworkStatusBanner> {
  final NetworkStatusService _networkService = NetworkStatusService();

  @override
  void initState() {
    super.initState();
    _networkService.initialize();
    _networkService.addListener(_onNetworkStatusChanged);
  }

  @override
  void dispose() {
    _networkService.removeListener(_onNetworkStatusChanged);
    super.dispose();
  }

  void _onNetworkStatusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // نمایش بنر وضعیت شبکه فقط زمانی که آفلاین هستیم
        if (!_networkService.isOnline || widget.showWhenOnline)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: _networkService.statusColor.withOpacity(0.9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _networkService.statusIcon,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  _networkService.statusMessage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (!_networkService.isOnline) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      await _networkService.checkConnectivity();
                    },
                    child: const Text(
                      'تلاش مجدد',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        // محتوای اصلی
        Expanded(child: widget.child),
      ],
    );
  }
}

/// ویجت کوچک نمایش وضعیت شبکه
class NetworkStatusIndicator extends StatefulWidget {
  final double size;
  final bool showText;

  const NetworkStatusIndicator({
    super.key,
    this.size = 16,
    this.showText = false,
  });

  @override
  State<NetworkStatusIndicator> createState() => _NetworkStatusIndicatorState();
}

class _NetworkStatusIndicatorState extends State<NetworkStatusIndicator> {
  final NetworkStatusService _networkService = NetworkStatusService();

  @override
  void initState() {
    super.initState();
    _networkService.initialize();
    _networkService.addListener(_onNetworkStatusChanged);
  }

  @override
  void dispose() {
    _networkService.removeListener(_onNetworkStatusChanged);
    super.dispose();
  }

  void _onNetworkStatusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: _networkService.statusColor,
            shape: BoxShape.circle,
          ),
        ),
        if (widget.showText) ...[
          const SizedBox(width: 4),
          Text(
            _networkService.statusMessage,
            style: TextStyle(
              fontSize: widget.size * 0.7,
              color: _networkService.statusColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
