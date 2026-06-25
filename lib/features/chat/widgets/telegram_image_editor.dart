import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../../../utils/user_friendly_error_utils.dart';
import 'media_editor_result.dart';

// ─── Public widget ────────────────────────────────────────────────────────────

class TelegramImageEditor extends StatefulWidget {
  final File file;
  final String initialCaption;

  const TelegramImageEditor({
    super.key,
    required this.file,
    this.initialCaption = '',
  });

  @override
  State<TelegramImageEditor> createState() => _TelegramImageEditorState();
}

// ─── Internal types ───────────────────────────────────────────────────────────

enum _Mode { none, draw, crop }

class _DrawPath {
  List<Offset> points;
  final Color color;
  final double strokeWidth;
  _DrawPath(
      {required this.points, required this.color, required this.strokeWidth});
}

enum _CropHandle { topLeft, topRight, bottomLeft, bottomRight, move, none }

// ─── State ────────────────────────────────────────────────────────────────────

class _TelegramImageEditorState extends State<TelegramImageEditor> {
  // Image
  Uint8List? _imageBytes;
  int _imageWidth = 0;
  int _imageHeight = 0;

  // Mode
  _Mode _mode = _Mode.none;

  // Draw
  final List<_DrawPath> _paths = [];
  _DrawPath? _currentPath;
  Color _drawColor = Colors.white;
  static const double _strokeWidth = 5.0;

  static const List<Color> _palette = [
    Color(0xFFFFFFFF),
    Color(0xFFFF453A),
    Color(0xFFFF9F0A),
    Color(0xFFFFD60A),
    Color(0xFF30D158),
    Color(0xFF64D2FF),
    Color(0xFF0A84FF),
    Color(0xFFBF5AF2),
    Color(0xFFFF375F),
    Color(0xFF000000),
  ];

  // Crop
  Rect? _cropRect;

  // Export
  final GlobalKey _repaintKey = GlobalKey();
  bool _isProcessing = false;

  // Caption
  late final TextEditingController _captionController;
  final FocusNode _captionFocus = FocusNode();

  // ─── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(text: widget.initialCaption);
    _loadImage();
  }

  @override
  void dispose() {
    _captionController.dispose();
    _captionFocus.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    final bytes = await widget.file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _imageWidth = frame.image.width;
      _imageHeight = frame.image.height;
    });
  }

  double get _imageAR =>
      (_imageWidth > 0 && _imageHeight > 0) ? _imageWidth / _imageHeight : 1.0;

  // ─── Rotate ──────────────────────────────────────────────────────────────────

  Future<void> _rotate() async {
    if (_isProcessing || _imageBytes == null) return;
    _captionFocus.unfocus();
    setState(() => _isProcessing = true);
    final rotated = await compute(_rotateBytes, _imageBytes!);
    if (!mounted) return;
    setState(() {
      _imageBytes = rotated;
      _paths.clear();
      _currentPath = null;
      _cropRect = null;
      final tmp = _imageWidth;
      _imageWidth = _imageHeight;
      _imageHeight = tmp;
      _isProcessing = false;
    });
  }

  // Top-level-compatible static: rotate 90° CW using image package
  static Uint8List _rotateBytes(Uint8List bytes) {
    final decoded = img.decodeImage(bytes)!;
    final rotated = img.copyRotate(decoded, angle: 90);
    return Uint8List.fromList(img.encodeJpg(rotated, quality: 95));
  }

  // ─── Draw ─────────────────────────────────────────────────────────────────────

  void _onDrawStart(DragStartDetails d) {
    _currentPath = _DrawPath(
      points: [d.localPosition],
      color: _drawColor,
      strokeWidth: _strokeWidth,
    );
  }

  void _onDrawUpdate(DragUpdateDetails d) {
    if (_currentPath == null) return;
    setState(() => _currentPath!.points.add(d.localPosition));
  }

  void _onDrawEnd(DragEndDetails _) {
    if (_currentPath == null) return;
    setState(() {
      _paths.add(_currentPath!);
      _currentPath = null;
    });
  }

  void _undoDraw() {
    if (_paths.isNotEmpty) setState(() => _paths.removeLast());
  }

  // ─── Crop confirm ─────────────────────────────────────────────────────────────

  Future<void> _confirmCrop() async {
    if (_cropRect == null) {
      setState(() => _mode = _Mode.none);
      return;
    }
    setState(() => _isProcessing = true);

    try {
      final boundary = _repaintKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final pixelRatio = MediaQuery.of(context).devicePixelRatio;
      final uiImage = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      final png = byteData!.buffer.asUint8List();

      final cr = _cropRect!;
      final cropArgs = <double>[
        cr.left * pixelRatio,
        cr.top * pixelRatio,
        cr.width * pixelRatio,
        cr.height * pixelRatio,
      ];
      final cropped = await compute(
        _cropBytes,
        <String, dynamic>{'bytes': png, 'crop': cropArgs},
      );

      final codec = await ui.instantiateImageCodec(cropped);
      final frame = await codec.getNextFrame();

      if (!mounted) return;
      setState(() {
        _imageBytes = cropped;
        _imageWidth = frame.image.width;
        _imageHeight = frame.image.height;
        _paths.clear();
        _currentPath = null;
        _cropRect = null;
        _mode = _Mode.none;
        _isProcessing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      UserFriendlyErrorUtils.showErrorSnackBar(context, 'خطا در اعمال برش');
    }
  }

  static Uint8List _cropBytes(Map<String, dynamic> args) {
    final bytes = args['bytes'] as Uint8List;
    final c = args['crop'] as List;
    final left = (c[0] as num).toDouble();
    final top = (c[1] as num).toDouble();
    final width = (c[2] as num).toDouble();
    final height = (c[3] as num).toDouble();

    final decoded = img.decodeImage(bytes)!;
    final x = left.round().clamp(0, decoded.width - 1);
    final y = top.round().clamp(0, decoded.height - 1);
    final w = width.round().clamp(1, decoded.width - x);
    final h = height.round().clamp(1, decoded.height - y);

    final cropped = img.copyCrop(decoded, x: x, y: y, width: w, height: h);
    return Uint8List.fromList(img.encodeJpg(cropped, quality: 95));
  }

  // ─── Export ──────────────────────────────────────────────────────────────────

  Future<void> _onDone() async {
    if (_isProcessing) return;
    _captionFocus.unfocus();
    setState(() => _isProcessing = true);
    // Wait for keyboard to close and layout to settle
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    try {
      final boundary = _repaintKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final pixelRatio = MediaQuery.of(context).devicePixelRatio;
      final uiImage = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      var bytes = byteData!.buffer.asUint8List();

      // Apply pending crop (if user didn't confirm separately)
      if (_cropRect != null) {
        final cr = _cropRect!;
        final cropArgs = <double>[
          cr.left * pixelRatio,
          cr.top * pixelRatio,
          cr.width * pixelRatio,
          cr.height * pixelRatio,
        ];
        bytes = await compute(
          _cropBytes,
          <String, dynamic>{'bytes': bytes, 'crop': cropArgs},
        );
      }

      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        format: CompressFormat.jpeg,
        quality: 87,
      );

      final tmp = File(
        '${(await getTemporaryDirectory()).path}/vista_edit_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await tmp.writeAsBytes(compressed);

      if (mounted) {
        Navigator.pop(
          context,
          MediaEditorResult(tmp, _captionController.text.trim()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        UserFriendlyErrorUtils.showErrorSnackBar(
            context, 'خطا در ذخیره تصویر ویرایش شده');
      }
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(),
          Expanded(child: _buildImageArea()),
          _buildBottomBar(),
        ]),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        const Spacer(),
        if (_mode == _Mode.draw && _paths.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.undo, color: Colors.white),
            onPressed: _undoDraw,
          ),
        if (_mode == _Mode.crop)
          TextButton(
            onPressed: _isProcessing ? null : _confirmCrop,
            child: const Text(
              'تأیید برش',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Vazirmatn',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ]),
    );
  }

  Widget _buildImageArea() {
    if (_imageBytes == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Container(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: _imageAR,
          child: Stack(children: [
            // RepaintBoundary: image + draw layer ONLY (no UI overlays)
            RepaintBoundary(
              key: _repaintKey,
              child: Stack(children: [
                SizedBox.expand(
                  child: Image.memory(_imageBytes!, fit: BoxFit.fill),
                ),
                IgnorePointer(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _DrawPainter(
                      paths: _paths,
                      currentPath: _currentPath,
                    ),
                  ),
                ),
              ]),
            ),

            // Draw gesture capture (outside RepaintBoundary)
            if (_mode == _Mode.draw)
              GestureDetector(
                onPanStart: _onDrawStart,
                onPanUpdate: _onDrawUpdate,
                onPanEnd: _onDrawEnd,
                child: Container(color: Colors.transparent),
              ),

            // Crop overlay (outside RepaintBoundary)
            if (_mode == _Mode.crop)
              _CropOverlay(
                initialRect: _cropRect,
                onChanged: (rect) => setState(() => _cropRect = rect),
              ),

            // Processing spinner
            if (_isProcessing)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (_mode == _Mode.draw) _buildPalette(),
      _buildToolbar(),
      _buildCaptionRow(),
    ]);
  }

  Widget _buildPalette() {
    return SizedBox(
      height: 54,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        itemCount: _palette.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final color = _palette[i];
          final selected = color.toARGB32() == _drawColor.toARGB32();
          return GestureDetector(
            onTap: () => setState(() => _drawColor = color),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? Colors.white : Colors.white24,
                  width: selected ? 3.0 : 1.5,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                            color: color.withValues(alpha: 0.7), blurRadius: 8)
                      ]
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _ToolBtn(
              icon: Icons.edit_rounded,
              active: _mode == _Mode.draw,
              onTap: () {
                _captionFocus.unfocus();
                setState(() =>
                    _mode = _mode == _Mode.draw ? _Mode.none : _Mode.draw);
              },
            ),
            const SizedBox(width: 4),
            _ToolBtn(
              icon: Icons.crop,
              active: _mode == _Mode.crop,
              onTap: () {
                _captionFocus.unfocus();
                setState(() {
                  if (_mode == _Mode.crop) {
                    _mode = _Mode.none;
                    _cropRect = null;
                  } else {
                    _mode = _Mode.crop;
                  }
                });
              },
            ),
            const SizedBox(width: 4),
            _ToolBtn(
              icon: Icons.rotate_90_degrees_cw_outlined,
              active: false,
              onTap: _isProcessing ? () {} : _rotate,
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildCaptionRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: TextField(
            controller: _captionController,
            focusNode: _captionFocus,
            style:
                const TextStyle(color: Colors.white, fontFamily: 'Vazirmatn'),
            textDirection: TextDirection.rtl,
            maxLines: null,
            decoration: InputDecoration(
              hintText: 'کپشن...',
              hintStyle: const TextStyle(
                  color: Colors.white38, fontFamily: 'Vazirmatn'),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _isProcessing ? null : _onDone,
          child: Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Color(0xFF2AABEE),
              shape: BoxShape.circle,
            ),
            child: _isProcessing
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.send, color: Colors.white, size: 22),
          ),
        ),
      ]),
    );
  }
}

// ─── Tool button ──────────────────────────────────────────────────────────────

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _ToolBtn({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 44,
        height: 36,
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withValues(alpha: 0.22)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(
          icon,
          color: active ? Colors.white : Colors.white60,
          size: 22,
        ),
      ),
    );
  }
}

// ─── Draw painter ─────────────────────────────────────────────────────────────

class _DrawPainter extends CustomPainter {
  final List<_DrawPath> paths;
  final _DrawPath? currentPath;

  const _DrawPainter({required this.paths, this.currentPath});

  @override
  void paint(Canvas canvas, Size size) {
    final all = [...paths, if (currentPath != null) currentPath!];
    for (final p in all) {
      _paintPath(canvas, p);
    }
  }

  void _paintPath(Canvas canvas, _DrawPath dp) {
    if (dp.points.isEmpty) return;
    final paint = Paint()
      ..color = dp.color
      ..strokeWidth = dp.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(dp.points[0].dx, dp.points[0].dy);
    for (int i = 1; i < dp.points.length; i++) {
      final p0 = dp.points[i - 1];
      final p1 = dp.points[i];
      path.quadraticBezierTo(
        p0.dx,
        p0.dy,
        (p0.dx + p1.dx) / 2,
        (p0.dy + p1.dy) / 2,
      );
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_DrawPainter old) =>
      old.paths.length != paths.length || old.currentPath != currentPath;
}

// ─── Crop overlay ─────────────────────────────────────────────────────────────

class _CropOverlay extends StatefulWidget {
  final Rect? initialRect;
  final ValueChanged<Rect> onChanged;

  const _CropOverlay({this.initialRect, required this.onChanged});

  @override
  State<_CropOverlay> createState() => _CropOverlayState();
}

class _CropOverlayState extends State<_CropOverlay> {
  Rect? _rect;
  _CropHandle? _handle;

  static const double _hitRadius = 32.0;
  static const double _minDim = 60.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);

      // Initialize rect once
      if (_rect == null) {
        _rect =
            widget.initialRect ?? Rect.fromLTWH(0, 0, size.width, size.height);
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => widget.onChanged(_rect!),
        );
      }

      return GestureDetector(
        onPanStart: (d) => _handle = _hitTest(d.localPosition),
        onPanUpdate: (d) {
          if (_handle == null || _handle == _CropHandle.none) return;
          setState(() => _rect = _adjust(_rect!, _handle!, d.delta, size));
          widget.onChanged(_rect!);
        },
        onPanEnd: (_) => _handle = null,
        child: CustomPaint(
          size: size,
          painter: _CropPainter(rect: _rect!),
        ),
      );
    });
  }

  _CropHandle _hitTest(Offset p) {
    final r = _rect!;
    if ((p - r.topLeft).distance < _hitRadius) return _CropHandle.topLeft;
    if ((p - r.topRight).distance < _hitRadius) return _CropHandle.topRight;
    if ((p - r.bottomLeft).distance < _hitRadius) return _CropHandle.bottomLeft;
    if ((p - r.bottomRight).distance < _hitRadius) {
      return _CropHandle.bottomRight;
    }
    if (r.contains(p)) return _CropHandle.move;
    return _CropHandle.none;
  }

  Rect _adjust(Rect r, _CropHandle handle, Offset d, Size bounds) {
    double l = r.left, t = r.top, rt = r.right, b = r.bottom;

    switch (handle) {
      case _CropHandle.topLeft:
        l = (l + d.dx).clamp(0.0, rt - _minDim);
        t = (t + d.dy).clamp(0.0, b - _minDim);
      case _CropHandle.topRight:
        rt = (rt + d.dx).clamp(l + _minDim, bounds.width);
        t = (t + d.dy).clamp(0.0, b - _minDim);
      case _CropHandle.bottomLeft:
        l = (l + d.dx).clamp(0.0, rt - _minDim);
        b = (b + d.dy).clamp(t + _minDim, bounds.height);
      case _CropHandle.bottomRight:
        rt = (rt + d.dx).clamp(l + _minDim, bounds.width);
        b = (b + d.dy).clamp(t + _minDim, bounds.height);
      case _CropHandle.move:
        final dx = d.dx.clamp(-l, bounds.width - rt);
        final dy = d.dy.clamp(-t, bounds.height - b);
        l += dx;
        rt += dx;
        t += dy;
        b += dy;
      case _CropHandle.none:
        break;
    }

    return Rect.fromLTRB(l, t, rt, b);
  }
}

class _CropPainter extends CustomPainter {
  final Rect rect;
  const _CropPainter({required this.rect});

  @override
  void paint(Canvas canvas, Size size) {
    // Dark mask around crop area
    final mask = Paint()..color = Colors.black.withValues(alpha: 0.55);
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, rect.top), mask);
    canvas.drawRect(
        Rect.fromLTRB(0, rect.bottom, size.width, size.height), mask);
    canvas.drawRect(Rect.fromLTRB(0, rect.top, rect.left, rect.bottom), mask);
    canvas.drawRect(
        Rect.fromLTRB(rect.right, rect.top, size.width, rect.bottom), mask);

    // Crop rect border
    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Rule of thirds grid
    final thirds = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    for (int i = 1; i <= 2; i++) {
      final x = rect.left + rect.width * i / 3;
      final y = rect.top + rect.height * i / 3;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), thirds);
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), thirds);
    }

    // L-shaped corner handles
    final handle = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    const hLen = 18.0;
    _drawCorner(canvas, handle, rect.topLeft, 1, 1, hLen);
    _drawCorner(canvas, handle, rect.topRight, -1, 1, hLen);
    _drawCorner(canvas, handle, rect.bottomLeft, 1, -1, hLen);
    _drawCorner(canvas, handle, rect.bottomRight, -1, -1, hLen);
  }

  void _drawCorner(
      Canvas canvas, Paint p, Offset corner, double dx, double dy, double len) {
    canvas.drawLine(corner, corner + Offset(dx * len, 0), p);
    canvas.drawLine(corner, corner + Offset(0, dy * len), p);
  }

  @override
  bool shouldRepaint(_CropPainter old) => old.rect != rect;
}
