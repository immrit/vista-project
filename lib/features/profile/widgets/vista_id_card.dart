import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../model/UserModel.dart';

/// Vista ID Card - Premium 3D Interactive Digital Business Card
class VistaIDCard extends StatefulWidget {
  final UserModel user;

  const VistaIDCard({super.key, required this.user});

  /// Show the Vista ID Card in a beautiful dialog with blur background
  static void show(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: VistaIDCard(user: user),
        ),
      ),
    );
  }

  @override
  State<VistaIDCard> createState() => _VistaIDCardState();
}

class _VistaIDCardState extends State<VistaIDCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _isFront = true;

  double _tiltX = 0.0;
  double _tiltY = 0.0;
  double _shimmerOffset = 0.5;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _flipAnimation = Tween<double>(begin: 0, end: math.pi).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );

    _flipController.addListener(() {
      setState(() {
        if (_flipAnimation.value > math.pi / 2 && _isFront) {
          _isFront = false;
        } else if (_flipAnimation.value < math.pi / 2 && !_isFront) {
          _isFront = true;
        }
      });
    });
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    if (_flipController.isAnimating) return;
    if (_flipController.status == AnimationStatus.completed) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    setState(() {
      _tiltX = (details.localPosition.dy - 100) / 100 * 0.12;
      _tiltY = -(details.localPosition.dx - 160) / 160 * 0.12;
      _tiltX = _tiltX.clamp(-0.15, 0.15);
      _tiltY = _tiltY.clamp(-0.15, 0.15);
      _shimmerOffset = (details.localPosition.dx / 320).clamp(0.0, 1.0);
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    setState(() {
      _tiltX = 0.0;
      _tiltY = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _toggleFlip,
            onPanUpdate: _handlePanUpdate,
            onPanEnd: _handlePanEnd,
            child: AnimatedBuilder(
              animation: _flipAnimation,
              builder: (context, child) {
                final angle = _flipAnimation.value;
                final isShowingFront = angle < math.pi / 2;

                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateX(_tiltX)
                    ..rotateY(_tiltY + angle),
                  child: isShowingFront
                      ? _buildFrontSide()
                      : Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateY(math.pi),
                          child: _buildBackSide(),
                        ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'ضربه بزنید تا برگردد',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              fontFamily: 'Vazir',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrontSide() {
    return Container(
      width: 320,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E1E2E),
            Color(0xFF12121C),
            Color(0xFF0A0A0F),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: _getGlowColor().withValues(alpha: 0.15),
            blurRadius: 30,
            spreadRadius: -5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Holographic shimmer overlay
            Positioned.fill(
              child: ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment(-1.0 + _shimmerOffset * 2, -0.5),
                  end: Alignment(_shimmerOffset * 2, 0.5),
                  colors: [
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.05),
                    Colors.purple.withValues(alpha: 0.03),
                    Colors.blue.withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                ).createShader(bounds),
                blendMode: BlendMode.srcOver,
                child: Container(color: Colors.white.withValues(alpha: 0.01)),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top: Logo and badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          // Vista Logo
                          Image.asset(
                            'lib/utils/images/logo/logo-white.png',
                            width: 32,
                            height: 32,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'VISTA ID',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                ),
                              ),
                              Text(
                                _getUserTitle(),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 8,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (widget.user.isVerified) _buildBadge(),
                    ],
                  ),

                  const Spacer(),

                  // Bottom: Avatar and info
                  Row(
                    children: [
                      // Avatar
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient:
                              LinearGradient(colors: _getGradientColors()),
                        ),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: const Color(0xFF1E1E2E),
                          backgroundImage: widget.user.avatarUrl != null
                              ? CachedNetworkImageProvider(
                                  widget.user.avatarUrl!)
                              : null,
                          child: widget.user.avatarUrl == null
                              ? const Icon(Icons.person,
                                  color: Colors.white38, size: 28)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Name and username
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.user.username,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Vazir',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '@${widget.user.username}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Holographic chip
                      _buildHoloChip(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackSide() {
    return Container(
      width: 320,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF5F5F7),
            Color(0xFFE8E8ED),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Subtle grid pattern
            Positioned.fill(
              child: CustomPaint(painter: _GridPatternPainter()),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Spacer(),
                  // QR Code
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: 'vista://user/${widget.user.id}',
                      version: QrVersions.auto,
                      size: 80,
                      gapless: false,
                      foregroundColor: const Color(0xFF1A1A2E),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'اسکن کنید',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Vazir',
                    ),
                  ),
                  const Spacer(),
                  // Bottom branding
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'lib/utils/images/logo/logo-white.png',
                            width: 18,
                            height: 18,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'VISTA',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '@${widget.user.username}',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge() {
    Color color;
    IconData icon;

    switch (widget.user.verificationType) {
      case VerificationType.goldTick:
        color = Colors.amber;
        icon = Icons.workspace_premium;
        break;
      case VerificationType.blueTick:
        color = Colors.blue;
        icon = Icons.verified;
        break;
      case VerificationType.blackTick:
        color = Colors.grey[300]!;
        icon = Icons.diamond_outlined;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }

  Widget _buildHoloChip() {
    return Container(
      width: 40,
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: LinearGradient(
          begin: Alignment(-1 + _shimmerOffset * 2, 0),
          end: Alignment(1 + _shimmerOffset * 2, 0),
          colors: [
            Colors.grey[700]!,
            Colors.grey[400]!,
            Colors.grey[600]!,
            Colors.grey[300]!,
            Colors.grey[700]!,
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: 30,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  List<Color> _getGradientColors() {
    switch (widget.user.verificationType) {
      case VerificationType.goldTick:
        return [Colors.amber, Colors.orange];
      case VerificationType.blueTick:
        return [Colors.blue, Colors.cyan];
      case VerificationType.blackTick:
        return [Colors.grey[600]!, Colors.grey[800]!];
      default:
        return [const Color(0xFF6366F1), const Color(0xFF8B5CF6)];
    }
  }

  Color _getGlowColor() {
    switch (widget.user.verificationType) {
      case VerificationType.goldTick:
        return Colors.amber;
      case VerificationType.blueTick:
        return Colors.blue;
      case VerificationType.blackTick:
        return Colors.grey[500]!;
      default:
        return const Color(0xFF6366F1);
    }
  }

  String _getUserTitle() {
    switch (widget.user.verificationType) {
      case VerificationType.goldTick:
        return 'PREMIUM';
      case VerificationType.blueTick:
        return 'VERIFIED';
      case VerificationType.blackTick:
        return 'DEVELOPER';
      default:
        return 'MEMBER';
    }
  }
}

class _GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    const spacing = 15.0;
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
