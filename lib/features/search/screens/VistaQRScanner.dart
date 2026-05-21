import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../chat/screens/ChatPartnerInfoScreen.dart';
import '../../chat/screens/modern_chat_screen.dart';
import '../../chat/services/group_service.dart';
import '../../profile/data/profile_repository.dart';
import '../../posts/screens/profileScreen.dart';

/// اسکنر پیشرفته ویستا برای اسکن QR کدهای پروفایل
class VistaQRScanner extends ConsumerStatefulWidget {
  const VistaQRScanner({super.key});

  @override
  ConsumerState<VistaQRScanner> createState() => _VistaQRScannerState();
}

class _VistaQRScannerState extends ConsumerState<VistaQRScanner>
    with SingleTickerProviderStateMixin {
  late MobileScannerController _controller;
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isProcessing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    _animationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || _isLoading) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? code = barcode.rawValue;
      if (code != null) {
        // پردازش کد QR
        await _processQRCode(code);
        return;
      }
    }
  }

  Future<void> _processQRCode(String code) async {
    // بررسی فرمت vista://user/
    if (code.startsWith('vista://user/')) {
      setState(() {
        _isProcessing = true;
        _isLoading = true;
      });

      // Haptic Feedback
      HapticFeedback.mediumImpact();

      final userId = code.replaceFirst('vista://user/', '');

      try {
        // دریافت اطلاعات کاربر از دیتابیس
        final Map<String, dynamic>? response =
            await ProfileRepository().fetchProfileById(userId);

        if (!mounted) return;

        if (response != null) {
          final username = response['username'] as String? ?? 'کاربر';
          // avatarUrl available if needed for future features

          setState(() => _isLoading = false);

          // بستن اسکنر و رفتن به پروفایل
          Navigator.pop(context);

          // رفتن به صفحه پروفایل کاربر
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProfileScreen(
                userId: userId,
                username: username,
              ),
            ),
          );
        } else {
          // کاربر یافت نشد
          setState(() {
            _isLoading = false;
            _isProcessing = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('کاربر یافت نشد'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red[400],
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _isProcessing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در دریافت اطلاعات: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red[400],
          ),
        );
      }
      return;
    }

    // بررسی فرمت vista://chat/
    if (code.startsWith('vista://chat/')) {
      setState(() {
        _isProcessing = true;
        _isLoading = true;
      });

      HapticFeedback.mediumImpact();

      final chatData = code.replaceFirst('vista://chat/', '');
      // فرمت: userId/username (اختیاری)
      final parts = chatData.split('/');
      final userId = parts.isNotEmpty ? parts[0] : '';

      if (userId.isEmpty) {
        setState(() {
          _isLoading = false;
          _isProcessing = false;
        });
        return;
      }

      try {
        final Map<String, dynamic>? response =
            await ProfileRepository().fetchProfileById(userId);

        if (!mounted) return;

        if (response != null) {
          final username = response['username'] as String? ?? 'کاربر';
          final avatarUrl = response['avatar_url'] as String?;

          setState(() => _isLoading = false);
          Navigator.pop(context);

          // رفتن به صفحه اطلاعات مخاطب چت
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatPartnerInfoScreen(
                conversationId: '', // خالی - صفحه خودش هندل می‌کند
                otherUserId: userId,
                otherUserName: username,
                otherUserAvatar: avatarUrl,
              ),
            ),
          );
        } else {
          setState(() {
            _isLoading = false;
            _isProcessing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('کاربر یافت نشد'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red[400],
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _isProcessing = false;
        });
      }
      return;
    }

    // بررسی فرمت گروه (vista://group یا https://cafevista.ir/group)
    if (code.startsWith('vista://group/') ||
        code.startsWith('https://cafevista.ir/group/') ||
        code.startsWith('http://cafevista.ir/group/')) {
      setState(() {
        _isProcessing = true;
        _isLoading = true;
      });

      HapticFeedback.mediumImpact();

      final inviteCode = code
          .replaceFirst('vista://group/', '')
          .replaceFirst('https://cafevista.ir/group/', '')
          .replaceFirst('http://cafevista.ir/group/', '');
      if (inviteCode.isEmpty) {
        setState(() {
          _isLoading = false;
          _isProcessing = false;
        });
        return;
      }

      try {
        final service = GroupService();
        final conversationId = await service.joinByInvite(inviteCode);
        final info = await service.fetchGroupInfo(conversationId);

        if (!mounted) return;

        setState(() => _isLoading = false);
        Navigator.pop(context);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ModernChatScreen(
              args: ChatScreenArgs(
                conversationId: conversationId,
                otherUserId: '',
                otherUserName: info?['name'] as String? ?? 'گروه',
                otherUserAvatar: info?['image'] as String?,
              ),
            ),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_mapGroupInviteError(e)),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red[400],
          ),
        );
      }
      return;
    }

    // فرمت نامعتبر
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('کد QR نامعتبر است'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.orange[400],
      ),
    );
  }

  String _mapGroupInviteError(Object error) {
    final msg = error.toString();
    if (msg.contains('invalid_invite')) {
      return 'لینک دعوت معتبر نیست یا غیرفعال شده است';
    }
    if (msg.contains('max_members_exceeded')) {
      return 'ظرفیت گروه تکمیل است';
    }
    if (msg.contains('unauthorized')) {
      return 'برای ورود ابتدا وارد حساب شوید';
    }
    return 'خطا در پیوستن به گروه';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // دوربین
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.white, size: 56),
                    const SizedBox(height: 16),
                    Text(
                      'خطا در دوربین: ${error.errorCode}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _controller.start(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('تلاش مجدد'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Overlay
          CustomPaint(
            painter: _ScannerOverlayPainter(
              borderColor: isDark ? Colors.white : Colors.white,
              scanLinePosition: _animation.value,
            ),
            child: const SizedBox.expand(),
          ),

          // لودینگ اورلی
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'در حال بررسی...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

          // AppBar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 28),
                    ),
                    const Text(
                      'اسکن کد QR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _controller.toggleTorch(),
                      icon: ValueListenableBuilder(
                        valueListenable: _controller,
                        builder: (context, state, child) {
                          return Icon(
                            state.torchState == TorchState.on
                                ? Icons.flash_on
                                : Icons.flash_off,
                            color: Colors.white,
                            size: 28,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // راهنما
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'کد QR پروفایل را اسکن کنید',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // دکمه تغییر دوربین
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () => _controller.switchCamera(),
                    icon: const Icon(
                      Icons.cameraswitch_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// پینتر سفارشی برای اورلی اسکنر
class _ScannerOverlayPainter extends CustomPainter {
  final Color borderColor;
  final double scanLinePosition;

  _ScannerOverlayPainter({
    required this.borderColor,
    required this.scanLinePosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scanAreaSize = size.width * 0.7;
    final double left = (size.width - scanAreaSize) / 2;
    final double top = (size.height - scanAreaSize) / 2;

    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.5);

    // رسم اورلی تاریک
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()
          ..addRRect(RRect.fromRectAndRadius(
            Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize),
            const Radius.circular(20),
          )),
      ),
      overlayPaint,
    );

    // رسم گوشه‌ها
    final cornerLength = scanAreaSize * 0.1;
    final cornerPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // بالا چپ
    canvas.drawLine(
        Offset(left, top + cornerLength), Offset(left, top + 10), cornerPaint);
    canvas.drawLine(
        Offset(left, top), Offset(left + cornerLength, top), cornerPaint);

    // بالا راست
    canvas.drawLine(Offset(left + scanAreaSize - cornerLength, top),
        Offset(left + scanAreaSize, top), cornerPaint);
    canvas.drawLine(Offset(left + scanAreaSize, top),
        Offset(left + scanAreaSize, top + cornerLength), cornerPaint);

    // پایین چپ
    canvas.drawLine(Offset(left, top + scanAreaSize - cornerLength),
        Offset(left, top + scanAreaSize), cornerPaint);
    canvas.drawLine(Offset(left, top + scanAreaSize),
        Offset(left + cornerLength, top + scanAreaSize), cornerPaint);

    // پایین راست
    canvas.drawLine(
        Offset(left + scanAreaSize - cornerLength, top + scanAreaSize),
        Offset(left + scanAreaSize, top + scanAreaSize),
        cornerPaint);
    canvas.drawLine(
        Offset(left + scanAreaSize, top + scanAreaSize - cornerLength),
        Offset(left + scanAreaSize, top + scanAreaSize),
        cornerPaint);

    // خط اسکن متحرک
    final scanLinePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withOpacity(0),
          Colors.white.withOpacity(0.8),
          Colors.white.withOpacity(0),
        ],
      ).createShader(Rect.fromLTWH(left, 0, scanAreaSize, 2));

    final scanLineY = top + (scanAreaSize * scanLinePosition);
    canvas.drawLine(
      Offset(left + 20, scanLineY),
      Offset(left + scanAreaSize - 20, scanLineY),
      scanLinePaint..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.scanLinePosition != scanLinePosition;
  }
}
