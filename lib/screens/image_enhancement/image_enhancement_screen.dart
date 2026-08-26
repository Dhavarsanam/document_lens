import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:document_lens/services/image_enhancement_service.dart';
import 'package:document_lens/providers/ocr_provider.dart';

class ImageEnhancementScreen extends StatefulWidget {
  final File imageFile;

  const ImageEnhancementScreen({
    super.key,
    required this.imageFile,
  });

  @override
  State<ImageEnhancementScreen> createState() =>
      _ImageEnhancementScreenState();
}

class _ImageEnhancementScreenState
    extends State<ImageEnhancementScreen> {
  File? _enhancedImage;
  bool _isProcessing = false;
  String _activeFilter = 'Original';
  double _brightness = 1.0;
  double _contrast = 1.0;
  bool _showOriginal = false;

  // ✅ Manual crop — the reliable way to cut out an unwanted area (like a
  // finger holding the paper) since true AI object-removal isn't practical
  // to run on-device.
  bool _isCropMode = false;
  Size? _imagePixelSize;
  Rect _cropRect = Rect.zero;
  Size _cropDisplaySize = Size.zero;
  static const double _handleSize = 24;

  final List<Map<String, dynamic>> _filters = [
    {'name': 'Original', 'icon': Icons.image_rounded, 'color': Colors.grey},
    {'name': 'Auto Enhance', 'icon': Icons.auto_fix_high_rounded, 'color': Colors.blue},
    {'name': 'Document', 'icon': Icons.description_rounded, 'color': Colors.indigo},
    {'name': 'Grayscale', 'icon': Icons.tonality_rounded, 'color': Colors.blueGrey},
    {'name': 'Sharpen', 'icon': Icons.center_focus_strong_rounded, 'color': Colors.green},
    {'name': 'Invert', 'icon': Icons.invert_colors_rounded, 'color': Colors.purple},
  ];

  @override
  void initState() {
    super.initState();
    _enhancedImage = widget.imageFile;
  }

  Future<void> _applyFilter(String filterName) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _activeFilter = filterName;
    });

    File? result;
    switch (filterName) {
      case 'Auto Enhance':
        result = await ImageEnhancementService.autoEnhance(widget.imageFile);
        break;
      case 'Document':
        result = await ImageEnhancementService.applyDocumentMode(widget.imageFile);
        break;
      case 'Grayscale':
        result = await ImageEnhancementService.applyGrayscale(widget.imageFile);
        break;
      case 'Sharpen':
        result = await ImageEnhancementService.applySharpen(widget.imageFile);
        break;
      case 'Invert':
        result = await ImageEnhancementService.applyInvert(widget.imageFile);
        break;
      case 'Original':
        result = widget.imageFile;
        break;
    }

    if (mounted) {
      setState(() {
        _enhancedImage = result ?? widget.imageFile;
        _isProcessing = false;
      });
    }
  }

  Future<void> _applyBrightness(double value) async {
    if (_isProcessing) return;
    setState(() {
      _brightness = value;
      _isProcessing = true;
      _activeFilter = 'Brightness';
    });
    final result = await ImageEnhancementService.adjustBrightness(
        widget.imageFile, value);
    if (mounted) {
      setState(() {
        _enhancedImage = result ?? widget.imageFile;
        _isProcessing = false;
      });
    }
  }

  Future<void> _applyContrast(double value) async {
    if (_isProcessing) return;
    setState(() {
      _contrast = value;
      _isProcessing = true;
      _activeFilter = 'Contrast';
    });
    final result = await ImageEnhancementService.adjustContrast(
        widget.imageFile, value);
    if (mounted) {
      setState(() {
        _enhancedImage = result ?? widget.imageFile;
        _isProcessing = false;
      });
    }
  }

  Future<void> _useForOCR() async {
    if (_enhancedImage == null) return;
    final ocrProvider = context.read<OcrProvider>();
    await ocrProvider.processImageFromPath(_enhancedImage!.path);
    if (mounted && ocrProvider.status == OcrStatus.done) {
      Navigator.pushReplacementNamed(context, '/result');
    }
  }

  Future<void> _startCrop() async {
    if (_enhancedImage == null || _isProcessing) return;
    setState(() => _isProcessing = true);
    final size = await ImageEnhancementService.getImageSize(_enhancedImage!);
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      if (size != null) {
        _imagePixelSize = size;
        _isCropMode = true;
        // Default box is the full image — the person drags the handles
        // inward to exclude the unwanted area (e.g. a finger at an edge).
        _cropRect = Rect.zero; // set to full display rect on first layout
      }
    });
  }

  void _cancelCrop() {
    setState(() => _isCropMode = false);
  }

  Future<void> _applyCrop() async {
    if (_imagePixelSize == null ||
        _enhancedImage == null ||
        _cropDisplaySize == Size.zero) {
      return;
    }
    final scaleX = _imagePixelSize!.width / _cropDisplaySize.width;
    final scaleY = _imagePixelSize!.height / _cropDisplaySize.height;
    final pixelRect = Rect.fromLTRB(
      _cropRect.left * scaleX,
      _cropRect.top * scaleY,
      _cropRect.right * scaleX,
      _cropRect.bottom * scaleY,
    );

    setState(() => _isProcessing = true);
    final result =
    await ImageEnhancementService.cropImage(_enhancedImage!, pixelRect);
    if (mounted) {
      setState(() {
        if (result != null) _enhancedImage = result;
        _isCropMode = false;
        _isProcessing = false;
      });
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not crop the image. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _updateCropCorner({double? dLeft, double? dTop, double? dRight, double? dBottom}) {
    setState(() {
      var left = _cropRect.left + (dLeft ?? 0);
      var top = _cropRect.top + (dTop ?? 0);
      var right = _cropRect.right + (dRight ?? 0);
      var bottom = _cropRect.bottom + (dBottom ?? 0);

      const minSize = 40.0;
      left = left.clamp(0.0, right - minSize);
      top = top.clamp(0.0, bottom - minSize);
      right = right.clamp(left + minSize, _cropDisplaySize.width);
      bottom = bottom.clamp(top + minSize, _cropDisplaySize.height);

      _cropRect = Rect.fromLTRB(left, top, right, bottom);
    });
  }

  Widget _buildCropOverlay() {
    if (_imagePixelSize == null || _enhancedImage == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: AspectRatio(
        aspectRatio: _imagePixelSize!.width / _imagePixelSize!.height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final displaySize =
            Size(constraints.maxWidth, constraints.maxHeight);
            // Store for _applyCrop's pixel-space conversion.
            _cropDisplaySize = displaySize;
            // First layout after entering crop mode: default to the full image.
            if (_cropRect == Rect.zero) {
              _cropRect = Rect.fromLTWH(0, 0, displaySize.width, displaySize.height);
            }
            return Stack(
              children: [
                Positioned.fill(
                  child: Image.file(_enhancedImage!, fit: BoxFit.fill),
                ),
                // Darken everything outside the crop rect.
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CropShadePainter(_cropRect),
                  ),
                ),
                // Corner drag handles.
                _cropHandle(
                  left: _cropRect.left - _handleSize / 2,
                  top: _cropRect.top - _handleSize / 2,
                  onDrag: (d) =>
                      _updateCropCorner(dLeft: d.dx, dTop: d.dy),
                ),
                _cropHandle(
                  left: _cropRect.right - _handleSize / 2,
                  top: _cropRect.top - _handleSize / 2,
                  onDrag: (d) =>
                      _updateCropCorner(dRight: d.dx, dTop: d.dy),
                ),
                _cropHandle(
                  left: _cropRect.left - _handleSize / 2,
                  top: _cropRect.bottom - _handleSize / 2,
                  onDrag: (d) =>
                      _updateCropCorner(dLeft: d.dx, dBottom: d.dy),
                ),
                _cropHandle(
                  left: _cropRect.right - _handleSize / 2,
                  top: _cropRect.bottom - _handleSize / 2,
                  onDrag: (d) =>
                      _updateCropCorner(dRight: d.dx, dBottom: d.dy),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _cropHandle({
    required double left,
    required double top,
    required void Function(Offset delta) onDrag,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) => onDrag(details.delta),
        child: Container(
          width: _handleSize,
          height: _handleSize,
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3), blurRadius: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCropControls() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 16, color: Colors.blue),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Drag the corner handles to cut out the unwanted area (e.g. a finger), then tap Apply.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Cancel'),
                  onPressed: _isProcessing ? null : _cancelCrop,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  icon: _isProcessing
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                      : const Icon(Icons.check_rounded),
                  label: const Text('Apply Crop'),
                  onPressed: _isProcessing ? null : _applyCrop,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Enhancement'),
        actions: [
          if (!_isCropMode)
            IconButton(
              tooltip: 'Crop out an unwanted area (e.g. a finger)',
              icon: const Icon(Icons.crop_rounded, color: Colors.white),
              onPressed: _isProcessing ? null : _startCrop,
            ),
          if (!_isCropMode)
            TextButton.icon(
              icon: const Icon(Icons.document_scanner_rounded,
                  color: Colors.white, size: 18),
              label: const Text('Scan',
                  style: TextStyle(color: Colors.white)),
              onPressed: _isProcessing ? null : _useForOCR,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Image Preview
            Expanded(
              child: _isCropMode
                  ? _buildCropOverlay()
                  : Stack(
                children: [
                  Positioned.fill(
                    child: _enhancedImage != null
                        ? Image.file(_enhancedImage!, fit: BoxFit.contain)
                        : const Center(child: CircularProgressIndicator()),
                  ),
                  if (_activeFilter != 'Original')
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        onTapDown: (_) =>
                            setState(() => _showOriginal = true),
                        onTapUp: (_) =>
                            setState(() => _showOriginal = false),
                        onTapCancel: () =>
                            setState(() => _showOriginal = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.compare_rounded,
                                  color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text('Hold to compare',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (_showOriginal)
                    Positioned.fill(
                      child: Image.file(widget.imageFile,
                          fit: BoxFit.contain),
                    ),
                  if (_isProcessing)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.4),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                  color: Colors.white),
                              SizedBox(height: 12),
                              Text('Applying filter...',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(_activeFilter,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),

            // Controls
            Container(
              color: isDark ? const Color(0xFF1E2130) : Colors.white,
              child: _isCropMode
                  ? _buildCropControls()
                  : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Filter chips
                  SizedBox(
                    height: 90,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      itemCount: _filters.length,
                      itemBuilder: (context, index) {
                        final filter = _filters[index];
                        final isActive = _activeFilter == filter['name'];
                        return GestureDetector(
                          onTap: () => _applyFilter(filter['name']),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? (filter['color'] as Color)
                                  : (filter['color'] as Color)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: filter['color'] as Color,
                                width: isActive ? 0 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  filter['icon'] as IconData,
                                  color: isActive
                                      ? Colors.white
                                      : filter['color'] as Color,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  filter['name'],
                                  style: TextStyle(
                                    color: isActive
                                        ? Colors.white
                                        : filter['color'] as Color,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Brightness Slider
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.brightness_5_rounded,
                                size: 18, color: Colors.orange),
                            const SizedBox(width: 8),
                            const Text('Brightness',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                            const Spacer(),
                            Text('${(_brightness * 100).toInt()}%',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 8),
                          ),
                          child: Slider(
                            value: _brightness,
                            min: 0.5,
                            max: 2.0,
                            divisions: 30,
                            activeColor: Colors.orange,
                            onChanged: (val) =>
                                setState(() => _brightness = val),
                            onChangeEnd: _applyBrightness,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Contrast Slider
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.contrast_rounded,
                                size: 18, color: Colors.indigo),
                            const SizedBox(width: 8),
                            const Text('Contrast',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                            const Spacer(),
                            Text('${(_contrast * 100).toInt()}%',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 8),
                          ),
                          child: Slider(
                            value: _contrast,
                            min: 0.5,
                            max: 2.5,
                            divisions: 40,
                            activeColor: Colors.indigo,
                            onChanged: (val) =>
                                setState(() => _contrast = val),
                            onChangeEnd: _applyContrast,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Reset'),
                            onPressed: () {
                              setState(() {
                                _enhancedImage = widget.imageFile;
                                _activeFilter = 'Original';
                                _brightness = 1.0;
                                _contrast = 1.0;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            icon: const Icon(
                                Icons.document_scanner_rounded),
                            label: const Text('Scan Enhanced Image'),
                            onPressed: _isProcessing ? null : _useForOCR,
                          ),
                        ),
                      ],
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
}

/// Darkens everything outside [cropRect] and draws a border around it,
/// so it's obvious which part of the image will be kept.
class _CropShadePainter extends CustomPainter {
  final Rect cropRect;
  const _CropShadePainter(this.cropRect);

  @override
  void paint(Canvas canvas, Size size) {
    final shadePaint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final fullPath = Path()..addRect(Offset.zero & size);
    final cropPath = Path()..addRect(cropRect);
    final shadePath =
    Path.combine(PathOperation.difference, fullPath, cropPath);
    canvas.drawPath(shadePath, shadePaint);

    final borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(cropRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _CropShadePainter oldDelegate) =>
      oldDelegate.cropRect != cropRect;
}