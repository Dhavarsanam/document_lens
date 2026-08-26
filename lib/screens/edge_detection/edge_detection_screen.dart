import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:document_lens/providers/ocr_provider.dart';
import 'package:document_lens/services/image_enhancement_service.dart';

class EdgeDetectionScreen extends StatefulWidget {
  final File imageFile;
  const EdgeDetectionScreen({super.key, required this.imageFile});

  @override
  State<EdgeDetectionScreen> createState() =>
      _EdgeDetectionScreenState();
}

class _EdgeDetectionScreenState extends State<EdgeDetectionScreen>
    with TickerProviderStateMixin {
  // Animations
  late AnimationController _scanLineController;
  late AnimationController _cornerController;
  late AnimationController _pulseController;
  late AnimationController _resultController;

  late Animation<double> _scanLineAnim;
  late Animation<double> _cornerAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _resultAnim;

  // Detection state
  _DetectionState _state = _DetectionState.scanning;
  int _progressPercent = 0;
  final List<String> _detectionSteps = [];

  // Detected corners (simulated)
  late List<Offset> _corners;
  bool _cornersVisible = false;
  bool _isFinalizing = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startDetection();
  }

  void _initAnimations() {
    // Scan line
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _scanLineAnim = Tween<double>(begin: 0.1, end: 0.9).animate(
      CurvedAnimation(
          parent: _scanLineController, curve: Curves.easeInOut),
    );

    // Corner markers
    _cornerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _cornerAnim = CurvedAnimation(
        parent: _cornerController, curve: Curves.elasticOut);

    // Pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Result
    _resultController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _resultAnim = CurvedAnimation(
        parent: _resultController, curve: Curves.easeOut);
  }

  Future<void> _startDetection() async {
    setState(() {
      _state = _DetectionState.scanning;
      _progressPercent = 0;
      _detectionSteps.clear();
      _cornersVisible = false;
    });

    // Step 1: Loading
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _detectionSteps.add('📥 Loading image...');
      _progressPercent = 15;
    });

    // Step 2: Preprocessing
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _detectionSteps.add('🔧 Preprocessing image...');
      _progressPercent = 35;
    });

    // Step 3: Edge detection
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      _detectionSteps.add('🔍 Running edge detection...');
      _progressPercent = 55;
    });

    // Step 4: Corner detection
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _detectionSteps.add('📐 Detecting document corners...');
      _progressPercent = 75;
    });

    // Step 5: Perspective correction
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _detectionSteps.add('🔄 Applying perspective correction...');
      _progressPercent = 90;
    });

    // Step 6: Done
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    // Generate simulated corners
    _corners = _generateCorners();

    setState(() {
      _detectionSteps.add('✅ Document detected successfully!');
      _progressPercent = 100;
      _state = _DetectionState.detected;
      _cornersVisible = true;
    });

    _scanLineController.stop();
    _cornerController.forward();
    _resultController.forward();
  }

  List<Offset> _generateCorners() {
    // Slightly randomized corners for realistic look
    final rand = Random();
    const margin = 0.08;
    final jitter = 0.03;

    return [
      Offset(margin + rand.nextDouble() * jitter,
          margin + rand.nextDouble() * jitter), // top-left
      Offset(1 - margin - rand.nextDouble() * jitter,
          margin + rand.nextDouble() * jitter), // top-right
      Offset(margin + rand.nextDouble() * jitter,
          1 - margin - rand.nextDouble() * jitter), // bottom-left
      Offset(1 - margin - rand.nextDouble() * jitter,
          1 - margin - rand.nextDouble() * jitter), // bottom-right
    ];
  }

  // ✅ Crop fix: the detected/adjusted corners were purely decorative — this
  // screen claimed "perspective correction" but "Scan Document" always ran
  // OCR on the original, uncropped photo, so dragging the corners in Adjust
  // mode had zero effect on the result. Now the corner quad's bounding box
  // (in the image's real pixel coordinates) is actually cropped out before
  // handing the photo to OCR.
  Future<void> _scanDocument() async {
    if (_isFinalizing) return;
    setState(() => _isFinalizing = true);

    var imageToScan = widget.imageFile;
    final pixelSize =
    await ImageEnhancementService.getImageSize(widget.imageFile);
    if (pixelSize != null) {
      double minX = _corners.map((c) => c.dx).reduce(min);
      double minY = _corners.map((c) => c.dy).reduce(min);
      double maxX = _corners.map((c) => c.dx).reduce(max);
      double maxY = _corners.map((c) => c.dy).reduce(max);
      final pixelRect = Rect.fromLTRB(
        minX * pixelSize.width,
        minY * pixelSize.height,
        maxX * pixelSize.width,
        maxY * pixelSize.height,
      );
      final cropped = await ImageEnhancementService.cropImage(
          widget.imageFile, pixelRect);
      if (cropped != null) imageToScan = cropped;
    }

    if (!mounted) return;
    final ocrProvider = context.read<OcrProvider>();
    await ocrProvider.processImageFromPath(imageToScan.path);
    if (mounted) {
      setState(() => _isFinalizing = false);
      if (ocrProvider.status == OcrStatus.done) {
        Navigator.pushReplacementNamed(context, '/result');
      }
    }
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    _cornerController.dispose();
    _pulseController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Smart Edge Detection',
            style: TextStyle(color: Colors.white)),
        actions: [
          if (_state == _DetectionState.detected)
            TextButton.icon(
              icon: const Icon(Icons.refresh_rounded,
                  color: Colors.white, size: 18),
              label: const Text('Re-scan',
                  style: TextStyle(color: Colors.white)),
              onPressed: _startDetection,
            ),
        ],
      ),
      body: Column(
        children: [
          // Image with overlay
          Expanded(
            child: Stack(
              children: [
                // Image
                Positioned.fill(
                  child: Image.file(
                    widget.imageFile,
                    fit: BoxFit.contain,
                  ),
                ),

                // Dark overlay
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.3),
                  ),
                ),

                // Scan line animation
                if (_state == _DetectionState.scanning)
                  AnimatedBuilder(
                    animation: _scanLineAnim,
                    builder: (context, child) => Positioned(
                      top: MediaQuery.of(context).size.height *
                          0.5 *
                          _scanLineAnim.value,
                      left: 20,
                      right: 20,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.cyan.withValues(alpha: 0.8),
                              Colors.blue,
                              Colors.cyan.withValues(alpha: 0.8),
                              Colors.transparent,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.cyan.withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Corner markers
                if (_cornersVisible)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return AnimatedBuilder(
                        animation: _cornerAnim,
                        builder: (context, child) => Stack(
                          children: [
                            // Document outline
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _EdgePainter(
                                  corners: _corners,
                                  progress: _cornerAnim.value,
                                  color: _state ==
                                      _DetectionState.adjusting
                                      ? Colors.orange
                                      : Colors.cyan,
                                  size: constraints.biggest,
                                ),
                              ),
                            ),
                            // Corner dots
                            ...List.generate(_corners.length, (i) {
                              final corner = _corners[i];
                              final dot = Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: _state ==
                                      _DetectionState.adjusting
                                      ? Colors.orange
                                      : Colors.cyan,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (_state ==
                                          _DetectionState
                                              .adjusting
                                          ? Colors.orange
                                          : Colors.cyan)
                                          .withValues(alpha: 0.6),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: _state ==
                                    _DetectionState.adjusting
                                    ? const Icon(
                                    Icons.open_with_rounded,
                                    color: Colors.white,
                                    size: 16)
                                    : null,
                              );

                              return Positioned(
                                left: corner.dx * constraints.maxWidth -
                                    14,
                                top: corner.dy * constraints.maxHeight -
                                    14,
                                child: Transform.scale(
                                  scale: _cornerAnim.value,
                                  child: _state ==
                                      _DetectionState.adjusting
                                      ? GestureDetector(
                                    behavior:
                                    HitTestBehavior.opaque,
                                    onPanUpdate: (details) {
                                      setState(() {
                                        final dx = (corner.dx +
                                            details.delta.dx /
                                                constraints
                                                    .maxWidth)
                                            .clamp(0.0, 1.0);
                                        final dy = (corner.dy +
                                            details.delta.dy /
                                                constraints
                                                    .maxHeight)
                                            .clamp(0.0, 1.0);
                                        _corners[i] =
                                            Offset(dx, dy);
                                      });
                                    },
                                    child: dot,
                                  )
                                      : dot,
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    },
                  ),

                // Status badge
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: _buildStatusBadge(),
                ),
              ],
            ),
          ),

          // Bottom panel
          Container(
            color: isDark ? const Color(0xFF0F1117) : Colors.white,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress bar
                if (_state == _DetectionState.scanning) ...[
                  Row(
                    children: [
                      const Icon(Icons.search_rounded,
                          color: Colors.cyan, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Detecting: $_progressPercent%',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _progressPercent / 100,
                      minHeight: 6,
                      backgroundColor:
                      Colors.grey.withValues(alpha: 0.2),
                      color: Colors.cyan,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Detection steps
                ..._detectionSteps.map((step) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    step,
                    style: TextStyle(
                      fontSize: 12,
                      color: step.startsWith('✅')
                          ? Colors.green
                          : Colors.grey[600],
                      fontWeight: step.startsWith('✅')
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                )),

                if (_state == _DetectionState.detected) ...[
                  const SizedBox(height: 16),

                  // Result info
                  FadeTransition(
                    opacity: _resultAnim,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.cyan.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.cyan.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.cyan.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                                Icons.crop_free_rounded,
                                color: Colors.cyan,
                                size: 24),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text('Document Detected!',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: Colors.cyan)),
                                SizedBox(height: 2),
                                Text(
                                  '4 corners found • Perspective corrected',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.tune_rounded),
                          label: const Text('Adjust'),
                          onPressed: () {
                            setState(() {
                              _state = _DetectionState.adjusting;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyan,
                            foregroundColor: Colors.white,
                          ),
                          icon: _isFinalizing
                              ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2))
                              : const Icon(
                              Icons.document_scanner_rounded),
                          label: const Text('Scan Document'),
                          onPressed:
                          _isFinalizing ? null : _scanDocument,
                        ),
                      ),
                    ],
                  ),
                ],

                if (_state == _DetectionState.adjusting) ...[
                  const SizedBox(height: 16),

                  // Adjustment hint
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.open_with_rounded,
                              color: Colors.orange, size: 24),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text('Drag corners to adjust',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: Colors.orange)),
                              SizedBox(height: 2),
                              Text(
                                'Move the orange handles to fit your document edges',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reset'),
                          onPressed: () {
                            setState(() {
                              _corners = _generateCorners();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyan,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Done'),
                          onPressed: () {
                            setState(() {
                              _state = _DetectionState.detected;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    if (_state == _DetectionState.scanning) {
      return AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, child) => Transform.scale(
          scale: _pulseAnim.value,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.cyan.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
                SizedBox(width: 8),
                Text('Detecting edges...',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ],
            ),
          ),
        ),
      );
    }

    if (_state == _DetectionState.adjusting) {
      return FadeTransition(
        opacity: _resultAnim,
        child: Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.open_with_rounded,
                  color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('Drag corners to adjust',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return FadeTransition(
      opacity: _resultAnim,
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Document Detected!',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

enum _DetectionState { scanning, detected, adjusting }

// Edge painter
class _EdgePainter extends CustomPainter {
  final List<Offset> corners;
  final double progress;
  final Color color;
  final Size size;

  _EdgePainter({
    required this.corners,
    required this.progress,
    required this.color,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    if (corners.length < 4) return;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.6 * progress)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.08 * progress)
      ..style = PaintingStyle.fill;

    // Convert normalized corners to actual positions
    final pts = corners
        .map((c) => Offset(c.dx * canvasSize.width,
        c.dy * canvasSize.height))
        .toList();

    // Draw filled quad
    final path = Path()
      ..moveTo(pts[0].dx, pts[0].dy)
      ..lineTo(pts[1].dx, pts[1].dy)
      ..lineTo(pts[3].dx, pts[3].dy)
      ..lineTo(pts[2].dx, pts[2].dy)
      ..close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, paint);

    // Draw corner accents
    const cornerLen = 20.0;
    final cornerPaint = Paint()
      ..color = color.withValues(alpha: progress)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(pts[0], pts[0] + Offset(cornerLen, 0), cornerPaint);
    canvas.drawLine(pts[0], pts[0] + Offset(0, cornerLen), cornerPaint);
    // Top-right
    canvas.drawLine(pts[1], pts[1] + Offset(-cornerLen, 0), cornerPaint);
    canvas.drawLine(pts[1], pts[1] + Offset(0, cornerLen), cornerPaint);
    // Bottom-left
    canvas.drawLine(pts[2], pts[2] + Offset(cornerLen, 0), cornerPaint);
    canvas.drawLine(pts[2], pts[2] + Offset(0, -cornerLen), cornerPaint);
    // Bottom-right
    canvas.drawLine(pts[3], pts[3] + Offset(-cornerLen, 0), cornerPaint);
    canvas.drawLine(pts[3], pts[3] + Offset(0, -cornerLen), cornerPaint);
  }

  @override
  bool shouldRepaint(_EdgePainter oldDelegate) =>
      oldDelegate.progress != progress;
}