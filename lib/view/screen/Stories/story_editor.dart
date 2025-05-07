import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';

class StoryEditorScreen extends StatefulWidget {
  final String? initialImagePath;

  const StoryEditorScreen({super.key, this.initialImagePath});

  @override
  State<StoryEditorScreen> createState() => _StoryEditorScreenState();
}

class _StoryEditorScreenState extends State<StoryEditorScreen>
    with TickerProviderStateMixin {
  // ویژگی‌های اصلی
  File? _imageFile;
  ui.Image? _loadedImage;
  Size? _imageSize;
  bool _isLoading = false;
  bool _isSaving = false;
  Uint8List? _imageBytes; // برای ذخیره داده‌های تصویر در وب

  final GlobalKey _canvasKey = GlobalKey();
  final List<StoryElement> _elements = [];
  StoryElement? _selectedElement;
  late TransformationController _transformationController;

  // برای جابجایی نرم المان‌ها
  Offset? _startDragPosition;
  Offset? _startElementPosition;

  // ویژگی‌های متن
  final TextEditingController _textController = TextEditingController();
  Color _currentColor = Colors.white;
  double _currentFontSize = 24.0;
  String _currentFontFamily = 'Default';
  TextAlign _currentTextAlign = TextAlign.center;
  final List<String> _availableFonts = [
    'Default',
    'Roboto',
    'OpenSans',
    'Lato',
    'Montserrat',
    'PlayfairDisplay',
    'Ubuntu',
  ];

  // ویژگی‌های نقاشی
  final List<DrawingPoint> _drawingPoints = [];
  Color _brushColor = Colors.white;
  double _brushSize = 5.0;
  bool _isDrawingMode = false;

  // ویژگی‌های فیلتر
  String _currentFilter = 'Normal';
  final double _filterIntensity = 1.0;
  final Map<String, ColorFilter> _filters = {
    'Normal': const ColorFilter.mode(Colors.transparent, BlendMode.srcOver),
    'Grayscale': const ColorFilter.matrix([
      0.2126,
      0.7152,
      0.0722,
      0,
      0,
      0.2126,
      0.7152,
      0.0722,
      0,
      0,
      0.2126,
      0.7152,
      0.0722,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]),
    'Sepia': const ColorFilter.matrix([
      0.393,
      0.769,
      0.189,
      0,
      0,
      0.349,
      0.686,
      0.168,
      0,
      0,
      0.272,
      0.534,
      0.131,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]),
    'Vintage': const ColorFilter.matrix([
      0.9,
      0.5,
      0.1,
      0,
      0,
      0.3,
      0.8,
      0.1,
      0,
      0,
      0.2,
      0.3,
      0.5,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]),
    'Sweet': const ColorFilter.matrix([
      1.0,
      0.0,
      0.2,
      0,
      0,
      0.0,
      1.0,
      0.0,
      0,
      0,
      0.0,
      0.0,
      0.8,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]),
    'Cold': const ColorFilter.matrix([
      0.8,
      0.0,
      0.0,
      0,
      0,
      0.0,
      0.9,
      0.1,
      0,
      0,
      0.0,
      0.2,
      1.2,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]),
    'Warm': const ColorFilter.matrix([
      1.1,
      0.0,
      0.0,
      0,
      10,
      0.0,
      1.0,
      0.0,
      0,
      0,
      0.0,
      0.0,
      0.8,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]),
  };

  // انیمیشن‌ها و کنترل‌کننده‌ها
  late AnimationController _toolbarAnimController;
  late Animation<Offset> _toolbarAnimation;

  late TabController _tabController;
  int _currentTabIndex = -1;

  // برای انیمیشن المان‌ها
  final Map<int, AnimationController> _elementAnimControllers = {};

  @override
  void initState() {
    super.initState();

    _transformationController = TransformationController();

    _setupAnimations();
    _loadInitialImage();
  }

  void _setupAnimations() {
    // راه‌اندازی انیمیشن‌ها
    _toolbarAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _toolbarAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _toolbarAnimController, curve: Curves.easeOut),
    );
    _toolbarAnimController.forward();

    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {
        // اگر تب فعلی همان تب انتخاب شده باشد، آن را غیرفعال کنیم
        if (_currentTabIndex == _tabController.index) {
          _currentTabIndex = -1;
        } else {
          _currentTabIndex = _tabController.index;
        }
        _selectedElement = null;
      });
    });
  }

  Future<void> _loadInitialImage() async {
    if (widget.initialImagePath != null) {
      try {
        final file = File(widget.initialImagePath!);
        if (await file.exists()) {
          setState(() {
            _imageFile = file;
            _isLoading = true;
          });
          await _loadImage();
        } else {
          _showErrorMessage('فایل تصویر یافت نشد');
          _pickImage(); // Try picking a new image
        }
      } catch (e) {
        _showErrorMessage('خطا در بارگذاری تصویر: $e');
        _pickImage(); // Try picking a new image
      }
    } else {
      _pickImage();
    }
  }

  @override
  void dispose() {
    _toolbarAnimController.dispose();
    _tabController.dispose();
    _textController.dispose();
    _transformationController.dispose();

    // حذف تمام انیمیشن کنترلرها
    for (final controller in _elementAnimControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  // ایجاد انیمیشن کنترلر برای المان جدید
  AnimationController _createElementAnimController(int elementId) {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _elementAnimControllers[elementId] = controller;
    return controller;
  }

  Future<void> _pickImage() async {
    if (!mounted) return;

    final ImagePicker picker = ImagePicker();
    try {
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
      );

      if (pickedFile != null && mounted) {
        setState(() {
          _isLoading = true;
        });

        // روش سازگار با وب برای خواندن تصویر
        if (kIsWeb) {
          final bytes = await pickedFile.readAsBytes();
          await _loadImageFromBytes(bytes);
        } else {
          _imageFile = File(pickedFile.path);
          await _loadImage();
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('خطا در انتخاب تصویر: e');
      }
    }
  }

  Future<void> _loadImageFromBytes(Uint8List bytes) async {
    if (!mounted) return;

    try {
      setState(() {
        _isLoading = true;
      });

      final codec = await ui.instantiateImageCodec(bytes);
      final frameInfo = await codec.getNextFrame();

      if (!mounted) return;

      // محاسبه سایز تصویر
      final image = frameInfo.image;
      final imageSize = Size(image.width.toDouble(), image.height.toDouble());

      setState(() {
        _loadedImage = image;
        _imageSize = imageSize;
        // ذخیره بایت‌ها برای استفاده بعدی
        _imageBytes = bytes;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorMessage('خطا در بارگذاری تصویر: e');
      }
    }
  }

  Future<void> _loadImage() async {
    if (!mounted) return;

    try {
      setState(() {
        _isLoading = true;
      });

      // روش متفاوت برای خواندن فایل در موبایل
      final bytes = await _imageFile!.readAsBytes();
      await _loadImageFromBytes(bytes);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorMessage('خطا در بارگذاری تصویر: e');
      }
    }
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _saveStory() async {
    if (_isSaving) return;

    try {
      setState(() {
        _isSaving = true;
        _selectedElement = null; // حذف انتخاب قبل از ذخیره
      });

      // کوتاه مدت تاخیر جهت اطمینان از اعمال تغییرات UI
      await Future.delayed(const Duration(milliseconds: 100));

      // اخذ تصویر از صفحه نمایش
      RenderRepaintBoundary boundary = _canvasKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);

      // استفاده از PNG برای حفظ کیفیت
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('خطا در تبدیل تصویر');
      }

      Uint8List pngBytes = byteData.buffer.asUint8List();

      // بازگشت از صفحه ویرایشگر با داده‌های تصویر
      Navigator.pop(context, pngBytes);
    } catch (e) {
      _showErrorMessage('خطا در ذخیره استوری: {e.toString()}');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _addTextElement() {
    _textController.clear();
    _showTextInputDialog();
  }

  void _showTextInputDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF191919),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _textController,
                        autofocus: true,
                        style: TextStyle(
                          color: _currentColor,
                          fontSize: _currentFontSize,
                          fontFamily: _getFontFamily(_currentFontFamily),
                        ),
                        textAlign: _currentTextAlign,
                        maxLines: 5,
                        minLines: 1,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'متن خود را وارد کنید...',
                          hintStyle: TextStyle(
                            color: _currentColor.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildTextFormattingOptions(setModalState),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.close, color: Colors.white),
                            label: const Text('لغو',
                                style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: const Text('افزودن',
                                style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              if (_textController.text.trim().isNotEmpty) {
                                _addNewTextElement(_textController.text);
                                Navigator.pop(context);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTextFormattingOptions(StateSetter setModalState) {
    return Column(
      children: [
        // انتخاب رنگ
        SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // رنگ سفید
              _buildColorOption(Colors.white),
              // رنگ‌های اصلی
              ...Colors.primaries.map((color) => _buildColorOption(color)),
              // رنگ سیاه
              _buildColorOption(Colors.black),
            ],
          ),
        ),
        // بقیه کد...

        const SizedBox(height: 16),

        // تنظیمات دیگر (اندازه، تراز، فونت)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // کنترل اندازه متن
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, color: Colors.white),
                    onPressed: () {
                      setModalState(() {
                        _currentFontSize = math.max(12, _currentFontSize - 2);
                      });
                    },
                  ),
                  Text(
                    '${_currentFontSize.toInt()}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.white),
                    onPressed: () {
                      setModalState(() {
                        _currentFontSize = math.min(72, _currentFontSize + 2);
                      });
                    },
                  ),
                ],
              ),

              // کنترل تراز متن
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.format_align_left,
                        color: Colors.white),
                    onPressed: () {
                      setModalState(() {
                        _currentTextAlign = TextAlign.left;
                      });
                    },
                    color: _currentTextAlign == TextAlign.left
                        ? Colors.blue
                        : Colors.white,
                  ),
                  IconButton(
                    icon: const Icon(Icons.format_align_center,
                        color: Colors.white),
                    onPressed: () {
                      setModalState(() {
                        _currentTextAlign = TextAlign.center;
                      });
                    },
                    color: _currentTextAlign == TextAlign.center
                        ? Colors.blue
                        : Colors.white,
                  ),
                  IconButton(
                    icon: const Icon(Icons.format_align_right,
                        color: Colors.white),
                    onPressed: () {
                      setModalState(() {
                        _currentTextAlign = TextAlign.right;
                      });
                    },
                    color: _currentTextAlign == TextAlign.right
                        ? Colors.blue
                        : Colors.white,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // انتخاب فونت
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _availableFonts.length,
            itemBuilder: (context, index) {
              final font = _availableFonts[index];
              return GestureDetector(
                onTap: () {
                  setModalState(() {
                    _currentFontFamily = font;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _currentFontFamily == font
                        ? Colors.blue
                        : Colors.grey[800],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    font,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: _getFontFamily(font),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildColorOption(Color color, {StateSetter? setModalState}) {
    return GestureDetector(
      key: ValueKey('color_option_${color.value}'), // کلید یکتا برای هر رنگ
      onTap: () {
        if (setModalState != null) {
          setModalState(() {
            _currentColor = color;
            _brushColor = color;
          });
        } else {
          setState(() {
            _currentColor = color;
            _brushColor = color;
          });
        }
      },
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: _currentColor == color ? Colors.white : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            if (_currentColor == color)
              BoxShadow(
                color: Colors.blue.withOpacity(0.5),
                blurRadius: 6,
                spreadRadius: 1,
              ),
          ],
        ),
      ),
    );
  }

  String _getFontFamily(String fontName) {
    switch (fontName) {
      case 'Roboto':
        return GoogleFonts.roboto().fontFamily!;
      case 'OpenSans':
        return GoogleFonts.openSans().fontFamily!;
      case 'Lato':
        return GoogleFonts.lato().fontFamily!;
      case 'Montserrat':
        return GoogleFonts.montserrat().fontFamily!;
      case 'PlayfairDisplay':
        return GoogleFonts.playfairDisplay().fontFamily!;
      case 'Ubuntu':
        return GoogleFonts.ubuntu().fontFamily!;
      default:
        return GoogleFonts.vazirmatn()
            .fontFamily!; // استفاده از فونت فارسی به صورت پیش‌فرض
    }
  }

  void _addNewTextElement(String text) {
    final newElement = StoryElement(
      id: _elements.length,
      type: ElementType.text,
      position: const Offset(100, 200),
      data: TextElementData(
        text: text,
        color: _currentColor,
        fontSize: _currentFontSize,
        fontFamily: _currentFontFamily,
        textAlign: _currentTextAlign,
      ),
    );

    setState(() {
      _elements.add(newElement);
      _selectedElement = newElement;
    });

    // ایجاد انیمیشن ورود المان
    final controller = _createElementAnimController(newElement.id);
    controller.forward();
  }

  Widget _buildCanvas() {
    if (_loadedImage == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                color: Colors.white.withOpacity(0.6),
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                'تصویری انتخاب نشده است',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('انتخاب تصویر'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _pickImage,
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final screenSize = Size(constraints.maxWidth, constraints.maxHeight);
      final calculatedSize = _imageSize != null
          ? _calculateFitSize(_imageSize!, screenSize)
          : screenSize;

      return Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. تصویر پس‌زمینه تار شده
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Transform.scale(
                  scale: 1.2,
                  child: kIsWeb && _imageBytes != null
                      ? Image.memory(
                          _imageBytes!,
                          fit: BoxFit.cover,
                        )
                      : _imageFile != null
                          ? Image.file(
                              _imageFile!,
                              fit: BoxFit.cover,
                            )
                          : Container(color: Colors.black),
                ),
              ),
            ),

            // 2. تصویر اصلی با فیلتر
            Center(
              child: SizedBox(
                width: calculatedSize.width,
                height: calculatedSize.height,
                child: ColorFiltered(
                  colorFilter: _filters[_currentFilter]!,
                  child: kIsWeb && _imageBytes != null
                      ? Image.memory(
                          _imageBytes!,
                          fit: BoxFit.contain,
                        )
                      : _imageFile != null
                          ? Image.file(
                              _imageFile!,
                              fit: BoxFit.contain,
                            )
                          : Container(color: Colors.black),
                ),
              ),
            ),

            // 3. لایه نقاشی
            Positioned.fill(
              child: CustomPaint(
                painter: DrawingPainter(points: _drawingPoints),
                size: Size.infinite,
              ),
            ),

            // 4. لایه المان‌های اضافه شده (متن و غیره)
            ..._buildElementsLayer(),

            // 5. لایه ترسیم فعال (زمانی که حالت نقاشی فعال است)
            if (_isDrawingMode) _buildDrawingLayer(),
          ],
        ),
      );
    });
  }

  Widget _buildBackgroundImage() {
    if (_loadedImage == null || _imageSize == null) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = Size(constraints.maxWidth, constraints.maxHeight);
        final imageSize = _imageSize!;
        final fitSize = _calculateFitSize(imageSize, screenSize);

        return Stack(
          children: [
            // Blurred background with key
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Transform.scale(
                  scale: 1.2,
                  child: Image.file(
                    _imageFile!,
                    key: ValueKey('blurred_${_imageFile!.path}'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            // Main image with key
            Center(
              child: SizedBox(
                width: fitSize.width,
                height: fitSize.height,
                child: ColorFiltered(
                  colorFilter: _filters[_currentFilter]!,
                  child: Image.file(
                    _imageFile!,
                    key: ValueKey('main_${_imageFile!.path}'),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Size _calculateFitSize(Size imageSize, Size screenSize) {
    final imageAspectRatio = imageSize.width / imageSize.height;
    final screenAspectRatio = screenSize.width / screenSize.height;

    late double width;
    late double height;

    if (imageAspectRatio > screenAspectRatio) {
      width = screenSize.width;
      height = width / imageAspectRatio;
    } else {
      height = screenSize.height;
      width = height * imageAspectRatio;
    }

    return Size(width, height);
  }

  List<Widget> _buildElementsLayer() {
    return _elements.map((element) {
      // دریافت انیمیشن کنترلر المان
      final animController = _elementAnimControllers[element.id];
      final isSelected = _selectedElement?.id == element.id;

      Widget elementWidget;

      switch (element.type) {
        case ElementType.text:
          final textData = element.data as TextElementData;
          elementWidget = _buildTextElement(textData);
          break;
        // اضافه کردن سایر انواع المان در آینده
        default:
          elementWidget = const SizedBox.shrink();
      }

      // افزودن انیمیشن ورودی به المان
      if (animController != null) {
        elementWidget = ScaleTransition(
          scale: CurvedAnimation(
            parent: animController,
            curve: Curves.easeOutBack,
          ),
          child: elementWidget,
        );
      }

      // استفاده از GestureDetector برای گرفتن تعاملات کاربر
      return Positioned(
        left: element.position.dx,
        top: element.position.dy,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedElement = isSelected ? null : element;
            });
          },
          onPanStart: (details) {
            _startDragPosition = details.globalPosition;
            _startElementPosition = element.position;
            setState(() {
              _selectedElement = element;
            });
          },
          onPanUpdate: (details) {
            if (_startDragPosition != null && _startElementPosition != null) {
              final delta = details.globalPosition - _startDragPosition!;
              setState(() {
                final newPosition = _startElementPosition! + delta;
                final index = _elements.indexWhere((e) => e.id == element.id);
                if (index != -1) {
                  _elements[index] = element.copyWith(position: newPosition);
                  _selectedElement = _elements[index];
                }
              });
            }
          },
          onPanEnd: (_) {
            _startDragPosition = null;
            _startElementPosition = null;
          },
          child: Stack(
            children: [
              elementWidget,
              if (isSelected)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.blue,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              // دکمه حذف المان
              if (isSelected)
                Positioned(
                  right: -12,
                  top: -12,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _elements.removeWhere((e) => e.id == element.id);
                        _selectedElement = null;
                      });
                    },
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildTextElement(TextElementData data) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        // حذف کادر دور متن در حالت عادی
        color: Colors.transparent,
      ),
      child: Text(
        data.text,
        style: TextStyle(
          color: data.color,
          fontSize: data.fontSize,
          fontFamily: _getFontFamily(data.fontFamily),
          height: 1.2,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.6),
              offset: const Offset(1, 1),
              blurRadius: 3,
            ),
          ],
        ),
        textAlign: data.textAlign,
      ),
    );
  }

  Widget _buildDrawingLayer() {
    return GestureDetector(
      onPanStart: (details) {
        setState(() {
          _drawingPoints.add(
            DrawingPoint(
              id: _drawingPoints.length,
              points: [details.localPosition],
              color: _brushColor,
              width: _brushSize,
            ),
          );
        });
      },
      onPanUpdate: (details) {
        setState(() {
          if (_drawingPoints.isNotEmpty) {
            final currentPoints = List<Offset>.from(_drawingPoints.last.points);
            currentPoints.add(details.localPosition);
            _drawingPoints.last = _drawingPoints.last.copyWith(
              points: currentPoints,
            );
          }
        });
      },
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.transparent,
      ),
    );
  }

  Widget _buildToolbar() {
    return SlideTransition(
      position: _toolbarAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF191919),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // نشانگر کشیدن
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 12),

            // تب‌ها
            Theme(
              data: ThemeData(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(icon: Icon(Icons.text_fields), text: 'متن'),
                  Tab(icon: Icon(Icons.brush), text: 'نقاشی'),
                  Tab(icon: Icon(Icons.filter), text: 'فیلتر'),
                  Tab(icon: Icon(Icons.layers), text: 'لایه‌ها'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // محتوای تب‌ها
            SizedBox(
              height: 130,
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // تب متن
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildToolbarButton(
                            icon: Icons.text_fields,
                            label: 'افزودن متن',
                            color: Colors.blue,
                            onTap: _addTextElement,
                          ),
                          if (_selectedElement != null &&
                              _selectedElement!.data is TextElementData)
                            _buildToolbarButton(
                              icon: Icons.edit,
                              label: 'ویرایش متن',
                              color: Colors.orange,
                              onTap: () => _editTextElement(_selectedElement!),
                            ),
                        ],
                      ),
                    ],
                  ),

                  // تب نقاشی
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isDrawingMode = !_isDrawingMode;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: _isDrawingMode
                                    ? Colors.blue
                                    : Colors.grey[800],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _isDrawingMode ? Icons.check : Icons.brush,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isDrawingMode
                                        ? 'در حال نقاشی'
                                        : 'شروع نقاشی',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_isDrawingMode) ...[
                            const SizedBox(width: 16),
                            IconButton(
                              onPressed: () {
                                if (_drawingPoints.isNotEmpty) {
                                  setState(() {
                                    _drawingPoints.removeLast();
                                  });
                                }
                              },
                              icon: const Icon(Icons.undo, color: Colors.white),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _drawingPoints.clear();
                                });
                              },
                              icon: const Icon(Icons.delete, color: Colors.red),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_isDrawingMode)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // کنترل اندازه قلم
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove,
                                      color: Colors.white, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _brushSize =
                                          math.max(1.0, _brushSize - 2.0);
                                    });
                                  },
                                ),
                                Container(
                                  width: 100,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[800],
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: (100 *
                                            _brushSize /
                                            20), // نرمال‌سازی (max size = 20)
                                        decoration: BoxDecoration(
                                          color: _brushColor,
                                          borderRadius:
                                              BorderRadius.circular(3),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add,
                                      color: Colors.white, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _brushSize =
                                          math.min(20.0, _brushSize + 2.0);
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            // انتخاب رنگ قلم
                            SizedBox(
                              height: 40,
                              width: 150,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  _buildColorOption(Colors.white),
                                  _buildColorOption(Colors.black),
                                  _buildColorOption(Colors.red),
                                  _buildColorOption(Colors.green),
                                  _buildColorOption(Colors.blue),
                                  _buildColorOption(Colors.yellow),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),

                  // تب فیلتر
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 80,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: _filters.entries.map((entry) {
                            final isSelected = _currentFilter == entry.key;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _currentFilter = entry.key;
                                });
                              },
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.blue
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: Colors.blue.withOpacity(0.6),
                                            blurRadius: 8,
                                          )
                                        ]
                                      : null,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: ColorFiltered(
                                    colorFilter: entry.value,
                                    child: _imageFile != null
                                        ? Image.file(
                                            _imageFile!,
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            width: 60,
                                            height: 60,
                                            color: Colors.grey,
                                          ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _currentFilter,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),

                  // تب لایه‌ها
                  _selectedElement != null
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildToolbarButton(
                                    icon: Icons.delete,
                                    label: 'حذف',
                                    color: Colors.red,
                                    onTap: _deleteSelectedElement,
                                  ),
                                  _buildToolbarButton(
                                    icon: Icons.copy,
                                    label: 'کپی',
                                    color: Colors.amber,
                                    onTap: _duplicateSelectedElement,
                                  ),
                                  _buildToolbarButton(
                                    icon: Icons.flip_to_front,
                                    label: 'جلو',
                                    color: Colors.green,
                                    onTap: _bringElementForward,
                                  ),
                                  _buildToolbarButton(
                                    icon: Icons.flip_to_back,
                                    label: 'عقب',
                                    color: Colors.purple,
                                    onTap: _sendElementBackward,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      : Center(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'یک المان را انتخاب کنید',
                              style: TextStyle(color: Colors.white),
                            ),
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

  Widget _buildToolbarButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteSelectedElement() {
    if (_selectedElement != null) {
      setState(() {
        _elements.removeWhere((element) => element.id == _selectedElement!.id);
        _selectedElement = null;
      });
    }
  }

  void _duplicateSelectedElement() {
    if (_selectedElement != null) {
      final newElement = _selectedElement!.copyWith(
        id: _elements.length,
        position: Offset(
          _selectedElement!.position.dx + 20,
          _selectedElement!.position.dy + 20,
        ),
      );

      setState(() {
        _elements.add(newElement);
        _selectedElement = newElement;
      });

      // ایجاد انیمیشن ورود برای المان جدید
      final controller = _createElementAnimController(newElement.id);
      controller.forward();
    }
  }

  void _editTextElement(StoryElement element) {
    if (element.data is TextElementData) {
      final textData = element.data as TextElementData;

      // تنظیم متغیرهای فعلی برای ویرایش
      _textController.text = textData.text;
      _currentColor = textData.color;
      _currentFontSize = textData.fontSize;
      _currentFontFamily = textData.fontFamily;
      _currentTextAlign = textData.textAlign;

      // نمایش دیالوگ ویرایش
      _showEditTextDialog(isEditing: true, elementId: element.id);
    }
  }

  // نمایش دیالوگ متن با حالت ویرایش
  void _showEditTextDialog({bool isEditing = false, int? elementId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF191919),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _textController,
                        autofocus: true,
                        style: TextStyle(
                          color: _currentColor,
                          fontSize: _currentFontSize,
                          fontFamily: _getFontFamily(_currentFontFamily),
                        ),
                        textAlign: _currentTextAlign,
                        maxLines: 5,
                        minLines: 1,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'متن خود را وارد کنید...',
                          hintStyle: TextStyle(
                            color: _currentColor.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildTextFormattingOptions(setModalState),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.close, color: Colors.white),
                            label: const Text('لغو',
                                style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          ElevatedButton.icon(
                            icon: Icon(
                              isEditing ? Icons.save : Icons.add,
                              color: Colors.white,
                            ),
                            label: Text(
                              isEditing ? 'ذخیره' : 'افزودن',
                              style: const TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              if (_textController.text.trim().isNotEmpty) {
                                if (isEditing && elementId != null) {
                                  _updateTextElement(elementId);
                                } else {
                                  _addNewTextElement(_textController.text);
                                }
                                Navigator.pop(context);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _updateTextElement(int elementId) {
    final index = _elements.indexWhere((element) => element.id == elementId);
    if (index != -1) {
      final oldElement = _elements[index];
      final newData = TextElementData(
        text: _textController.text,
        color: _currentColor,
        fontSize: _currentFontSize,
        fontFamily: _currentFontFamily,
        textAlign: _currentTextAlign,
      );

      setState(() {
        _elements[index] = oldElement.copyWith(data: newData);
        _selectedElement = _elements[index];
      });
    }
  }

  void _bringElementForward() {
    if (_selectedElement != null && _elements.length > 1) {
      final index = _elements.indexWhere((e) => e.id == _selectedElement!.id);

      if (index < _elements.length - 1) {
        setState(() {
          final element = _elements.removeAt(index);
          _elements.insert(index + 1, element);
        });
      }
    }
  }

  void _sendElementBackward() {
    if (_selectedElement != null && _elements.length > 1) {
      final index = _elements.indexWhere((e) => e.id == _selectedElement!.id);

      if (index > 0) {
        setState(() {
          final element = _elements.removeAt(index);
          _elements.insert(index - 1, element);
        });
      }
    }
  }

  void _showFiltersDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF191919),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'انتخاب فیلتر',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 220,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemCount: _filters.length,
                  itemBuilder: (context, index) {
                    final entry = _filters.entries.elementAt(index);
                    final isSelected = _currentFilter == entry.key;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentFilter = entry.key;
                        });
                        Navigator.pop(context);
                      },
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.blue
                                      : Colors.transparent,
                                  width: 3,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: Colors.blue.withOpacity(0.6),
                                          blurRadius: 8,
                                        )
                                      ]
                                    : null,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: ColorFiltered(
                                  colorFilter: entry.value,
                                  child: _imageFile != null
                                      ? Image.file(
                                          _imageFile!,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(color: Colors.grey),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            entry.key,
                            style: TextStyle(
                              color: isSelected ? Colors.blue : Colors.white,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSideToolbar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          _buildToolbarItem(
            icon: Icons.text_fields,
            isSelected: _currentTabIndex == 0,
            onTap: () => _setCurrentTab(0),
          ),
          _buildToolbarItem(
            icon: Icons.brush,
            isSelected: _currentTabIndex == 1,
            onTap: () => _setCurrentTab(1),
          ),
          _buildToolbarItem(
            icon: Icons.filter,
            isSelected: _currentTabIndex == 2,
            onTap: () => _setCurrentTab(2),
          ),
          _buildToolbarItem(
            icon: Icons.layers,
            isSelected: _currentTabIndex == 3,
            onTap: () => _setCurrentTab(3),
          ),
          // اضافه کردن سایر آیکون‌های مورد نیاز
        ],
      ),
    );
  }

  Widget _buildToolbarItem({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blue : Colors.white,
              size: 28,
            ),
            const SizedBox(height: 4),
            if (isSelected)
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _setCurrentTab(int index) {
    setState(() {
      if (_currentTabIndex == index) {
        _currentTabIndex = -1; // برای بستن پنل در صورت کلیک مجدد
      } else {
        _currentTabIndex = index;
        _selectedElement = null;
      }
    });
  }

  Widget _buildOptionPanel() {
    return AnimatedOpacity(
      opacity: _currentTabIndex != -1 ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10, width: 1),
        ),
        child: _getOptionsForCurrentTab(),
      ),
    );
  }

  Widget _getOptionsForCurrentTab() {
    switch (_currentTabIndex) {
      case 0:
        return _buildTextOptions();
      case 1:
        return _buildDrawingOptions();
      case 2:
        return _buildFilterOptions();
      case 3:
        return _buildLayersOptions();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTextOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'افزودن متن',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // دکمه افزودن متن
        InkWell(
          onTap: _addTextElement,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: const [
                Icon(Icons.add, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'متن جدید',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // گزینه ویرایش متن (فقط اگر متنی انتخاب شده باشد)
        if (_selectedElement != null &&
            _selectedElement!.data is TextElementData)
          InkWell(
            onTap: () => _editTextElement(_selectedElement!),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: const [
                  Icon(Icons.edit, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'ویرایش متن',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

        // اینجا می‌توانید گزینه‌های بیشتری اضافه کنید
      ],
    );
  }

  Widget _buildDrawingOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'نقاشی',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // دکمه فعال/غیرفعال کردن حالت نقاشی
        InkWell(
          onTap: () {
            setState(() {
              _isDrawingMode = !_isDrawingMode;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: _isDrawingMode
                  ? Colors.blue.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  _isDrawingMode ? Icons.check : Icons.brush,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  _isDrawingMode ? 'در حال نقاشی' : 'شروع نقاشی',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),

        if (_isDrawingMode) ...[
          const SizedBox(height: 16),

          // تنظیم اندازه قلم
          Row(
            children: [
              const Text('اندازه:', style: TextStyle(color: Colors.white)),
              Expanded(
                child: Slider(
                  value: _brushSize,
                  min: 1,
                  max: 30,
                  divisions: 29,
                  activeColor: Colors.blue,
                  inactiveColor: Colors.grey,
                  onChanged: (value) {
                    setState(() {
                      _brushSize = value;
                    });
                  },
                ),
              ),
              Text(
                _brushSize.toInt().toString(),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // انتخاب رنگ
          const Text('رنگ:', style: TextStyle(color: Colors.white)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...Colors.primaries.map((color) => _buildColorOption(color)),
                _buildColorOption(Colors.white),
                _buildColorOption(Colors.black),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // دکمه‌های بازگشت و پاک کردن
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (_drawingPoints.isNotEmpty)
                InkWell(
                  onTap: () {
                    setState(() {
                      _drawingPoints.removeLast();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.undo, color: Colors.white),
                  ),
                ),
              InkWell(
                onTap: () {
                  setState(() {
                    _drawingPoints.clear();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildFilterOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'فیلترها',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.9,
            ),
            itemCount: _filters.length,
            itemBuilder: (context, index) {
              final entry = _filters.entries.elementAt(index);
              final isSelected = _currentFilter == entry.key;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _currentFilter = entry.key;
                  });
                },
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color:
                                isSelected ? Colors.blue : Colors.transparent,
                            width: 2,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.3),
                                    blurRadius: 6,
                                  )
                                ]
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: ColorFiltered(
                            colorFilter: entry.value,
                            child: _imageFile != null
                                ? Image.file(
                                    _imageFile!,
                                    fit: BoxFit.cover,
                                  )
                                : Container(color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entry.key,
                      style: TextStyle(
                        color: isSelected ? Colors.blue : Colors.white,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLayersOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'لایه‌ها',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (_selectedElement != null) ...[
          // دکمه حذف
          InkWell(
            onTap: _deleteSelectedElement,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: const [
                  Icon(Icons.delete, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'حذف',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

          // دکمه کپی
          InkWell(
            onTap: _duplicateSelectedElement,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: const [
                  Icon(Icons.copy, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'کپی',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

          // دکمه جلو آوردن
          InkWell(
            onTap: _bringElementForward,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: const [
                  Icon(Icons.arrow_upward, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'آوردن به جلو',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

          // دکمه بردن به عقب
          InkWell(
            onTap: _sendElementBackward,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: const [
                  Icon(Icons.arrow_downward, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'بردن به عقب',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ] else
          const Center(
            child: Text(
              'یک المان را انتخاب کنید',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        // با کلیک روی صفحه، تب‌ها بسته شوند
        onTap: () {
          setState(() {
            _currentTabIndex = -1;
            _selectedElement = null;
          });
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // تصویر انتخاب شده و محتوای اصلی
            if (_loadedImage != null)
              Positioned.fill(
                child: RepaintBoundary(
                  key: _canvasKey,
                  child: _buildCanvas(),
                ),
              ),

            // پنل ابزار کناری (جایگزین نوار ابزار پایین)
            Positioned(
              top: 60,
              bottom: 20,
              right: 10,
              width: 80,
              child: _buildSideToolbar(),
            ),

            // پنل گزینه‌های انتخاب شده
            if (_currentTabIndex != -1)
              Positioned(
                top: 60,
                bottom: 20,
                right: 100,
                width: 200,
                child: _buildOptionPanel(),
              ),

            // دکمه‌های بالای صفحه
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.photo_library,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _isSaving ? null : _saveStory,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 24,
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // نشانگر بارگذاری
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// تغییر ساختار داده‌ها برای کارایی بهتر

class StoryElement {
  final int id;
  final ElementType type;
  final Offset position;
  final ElementData data;

  StoryElement({
    required this.id,
    required this.type,
    required this.position,
    required this.data,
  });

  StoryElement copyWith({
    int? id,
    ElementType? type,
    Offset? position,
    ElementData? data,
  }) {
    return StoryElement(
      id: id ?? this.id,
      type: type ?? this.type,
      position: position ?? this.position,
      data: data ?? this.data,
    );
  }
}

enum ElementType {
  text,
  drawing,
  sticker,
}

abstract class ElementData {}

class TextElementData extends ElementData {
  final String text;
  final Color color;
  final double fontSize;
  final String fontFamily;
  final TextAlign textAlign;

  TextElementData({
    required this.text,
    required this.color,
    required this.fontSize,
    required this.fontFamily,
    required this.textAlign,
  });
}

class DrawingPoint {
  final int id;
  final List<Offset> points;
  final Color color;
  final double width;

  DrawingPoint({
    required this.id,
    required this.points,
    required this.color,
    required this.width,
  });

  DrawingPoint copyWith({
    int? id,
    List<Offset>? points,
    Color? color,
    double? width,
  }) {
    return DrawingPoint(
      id: id ?? this.id,
      points: points ?? this.points,
      color: color ?? this.color,
      width: width ?? this.width,
    );
  }
}

class DrawingPainter extends CustomPainter {
  final List<DrawingPoint> points;

  DrawingPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    for (final point in points) {
      final paint = Paint()
        ..color = point.color
        ..strokeWidth = point.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      for (int i = 0; i < point.points.length - 1; i++) {
        canvas.drawLine(point.points[i], point.points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) => true;
}
