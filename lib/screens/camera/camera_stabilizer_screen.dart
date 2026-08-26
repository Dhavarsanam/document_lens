import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:provider/provider.dart';
import 'package:document_lens/providers/ocr_provider.dart';
import 'package:document_lens/services/quality_checker_service.dart';
import 'package:document_lens/services/obstruction_checker_service.dart';

enum StabilityStatus { unstable, stabilizing, stable }

class CameraStabilizerScreen extends StatefulWidget {
  const CameraStabilizerScreen({super.key});

  @override
  State<CameraStabilizerScreen> createState() =>
      _CameraStabilizerScreenState();
}

class _CameraStabilizerScreenState
    extends State<CameraStabilizerScreen>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isCapturing = false;
  String? _cameraError;

  // Stability tracking
  StabilityStatus _stabilityStatus = StabilityStatus.unstable;
  double _stabilityScore = 0.0;
  StreamSubscription? _accelerometerSub;
  List<double> _recentReadings = [];
  Timer? _captureTimer;
  Timer? _stabilityTimer;
  int _stableSeconds = 0;
  FlashMode _flashMode = FlashMode.off;

  // ✅ Smart Stabilizer defect fix: accelerometer "stable" only means the
  // PHONE wasn't shaking — it says nothing about focus hunting or shutter
  // lag, which can still produce a blurry photo. This flag makes sure we
  // only auto-retake ONCE per capture attempt (never loop forever if the
  // shot genuinely can't sharpen, e.g. very close-up subjects).
  bool _retriedForBlur = false;

  // ✅ Same idea, for the NEW obstruction check: a finger/object covering
  // part of the document can produce a perfectly sharp photo, so blur
  // detection alone lets it through. Only auto-retake ONCE per attempt.
  bool _retriedForObstruction = false;

  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  late AnimationController _borderController;
  late Animation<Color?> _borderColorAnim;

  // Thresholds
  static const double _stableThreshold = 0.3;
  static const double _unstableThreshold = 0.8;
  static const int _requiredStableSeconds = 2;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initCamera();
    _startAccelerometer();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _borderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _borderColorAnim = ColorTween(
      begin: Colors.red,
      end: Colors.green,
    ).animate(_borderController);
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() => _cameraError = 'No camera found on this device.');
        }
        return;
      }

      _cameraController = CameraController(
        _cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _cameraError = null;
        });
      }
    } on CameraException catch (e) {
      debugPrint('Camera init error: ${e.code} — ${e.description}');
      if (mounted) {
        setState(() {
          _cameraError = e.code == 'CameraAccessDenied'
              ? 'Camera permission denied. Please allow camera access in Settings.'
              : 'Could not start the camera. Please try again.';
        });
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
      if (mounted) {
        setState(() => _cameraError = 'Could not start the camera. Please try again.');
      }
    }
  }

  void _startAccelerometer() {
    _accelerometerSub =
        accelerometerEventStream().listen((AccelerometerEvent event) {
          // Calculate magnitude of movement
          final magnitude = sqrt(
            event.x * event.x +
                event.y * event.y +
                event.z * event.z,
          );

          // Remove gravity (approx 9.8)
          final movement = (magnitude - 9.8).abs();

          _recentReadings.add(movement);
          if (_recentReadings.length > 20) {
            _recentReadings.removeAt(0);
          }

          // Calculate average movement
          final avgMovement = _recentReadings.isEmpty
              ? 0.0
              : _recentReadings.reduce((a, b) => a + b) /
              _recentReadings.length;

          // Update stability score (0 = unstable, 1 = stable)
          final newScore =
              1.0 - (avgMovement / _unstableThreshold).clamp(0.0, 1.0);

          if (mounted) {
            setState(() => _stabilityScore = newScore);
            _updateStabilityStatus(avgMovement);
          }
        });
  }

  void _updateStabilityStatus(double movement) {
    if (movement < _stableThreshold) {
      // Phone is stable
      if (_stabilityStatus != StabilityStatus.stable) {
        _stabilityStatus = StabilityStatus.stabilizing;
        _stableSeconds++;

        if (_stableSeconds >= _requiredStableSeconds * 10) {
          // ~2 seconds of stable readings
          _stabilityStatus = StabilityStatus.stable;
          _borderController.forward();
          _scheduleAutoCapture();
        }
      }
    } else {
      // Phone is moving
      _stabilityStatus = StabilityStatus.unstable;
      _stableSeconds = 0;
      _captureTimer?.cancel();
      _borderController.reverse();
    }
  }

  void _scheduleAutoCapture() {
    if (_isCapturing) return;
    _captureTimer?.cancel();
    _captureTimer = Timer(const Duration(milliseconds: 500), () {
      if (_stabilityStatus == StabilityStatus.stable &&
          !_isCapturing) {
        _captureImage();
      }
    });
  }

  Future<void> _captureImage() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      // ✅ Let focus/exposure settle before firing the shutter. Previously
      // the photo was taken the instant the accelerometer reported
      // "stable", which could catch the camera mid-autofocus and produce
      // a soft shot even though the phone itself wasn't moving.
      try {
        await _cameraController!.setFocusMode(FocusMode.auto);
      } catch (_) {
        // Some devices/cameras don't support manual focus-mode control —
        // safe to ignore and just capture.
      }
      await Future.delayed(const Duration(milliseconds: 250));

      final image = await _cameraController!.takePicture();

      // ✅ Verify the actual photo isn't blurry. Accelerometer stability
      // alone doesn't guarantee a sharp shot (focus hunting / shutter lag
      // can still blur it) — this is the "defect" the Smart Stabilizer
      // was letting through. Reuses the same sharpness check the Quality
      // Checker screen already uses (Laplacian variance).
      final quality =
      await QualityCheckerService.checkQuality(File(image.path));

      if (quality.sharpnessScore < 35 && !_retriedForBlur) {
        _retriedForBlur = true;
        if (mounted) {
          setState(() => _isCapturing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '📷 Photo came out blurry — hold steadier, retrying…'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
          // Reset stability so it has to prove "stable" again before the
          // next auto-capture attempt.
          _stableSeconds = 0;
          _stabilityStatus = StabilityStatus.unstable;
          _borderController.reverse();
        }
        return;
      }
      _retriedForBlur = false;

      // ✅ Check whether a finger/hand/object is covering part of the
      // document — a sharp, well-lit photo can still fail this if a
      // thumb is holding the page down over the text.
      final obstruction =
      await ObstructionCheckerService.checkObstruction(File(image.path));

      if (obstruction.hasObstruction && !_retriedForObstruction) {
        _retriedForObstruction = true;
        if (mounted) {
          setState(() => _isCapturing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ ${obstruction.reason} Move it away and hold steady…'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
          // Reset stability so it has to prove "stable" again before the
          // next auto-capture attempt.
          _stableSeconds = 0;
          _stabilityStatus = StabilityStatus.unstable;
          _borderController.reverse();
        }
        return;
      }
      _retriedForObstruction = false;

      if (mounted) {
        final ocrProvider = context.read<OcrProvider>();
        // Pass image to OCR provider
        await ocrProvider.processImageFromPath(image.path);

        if (mounted && ocrProvider.status == OcrStatus.done) {
          Navigator.pushReplacementNamed(context, '/result');
        }
      }
    } catch (e) {
      debugPrint('Capture error: $e');
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _manualCapture() async {
    await _captureImage();
  }

  FlashMode _nextFlashMode(FlashMode current) {
    switch (current) {
      case FlashMode.off:
        return FlashMode.auto;
      case FlashMode.auto:
        return FlashMode.torch;
      case FlashMode.torch:
        return FlashMode.off;
      case FlashMode.always:
        return FlashMode.off;
    }
  }

  IconData _flashModeIcon(FlashMode mode) {
    switch (mode) {
      case FlashMode.off:
        return Icons.flash_off_rounded;
      case FlashMode.auto:
        return Icons.flash_auto_rounded;
      case FlashMode.torch:
      case FlashMode.always:
        return Icons.flash_on_rounded;
    }
  }

  String _flashModeLabel(FlashMode mode) {
    switch (mode) {
      case FlashMode.off:
        return 'Flash: Off';
      case FlashMode.auto:
        return 'Flash: Auto';
      case FlashMode.torch:
      case FlashMode.always:
        return 'Flash: On';
    }
  }

  @override
  void dispose() {
    _accelerometerSub?.cancel();
    _captureTimer?.cancel();
    _stabilityTimer?.cancel();
    _pulseController.dispose();
    _borderController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera Preview
            if (_isCameraInitialized && _cameraController != null)
              Positioned.fill(
                child: CameraPreview(_cameraController!),
              )
            else if (_cameraError != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam_off_rounded,
                          color: Colors.white70, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        _cameraError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            child: const Text('Go Back',
                                style: TextStyle(color: Colors.white70)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              setState(() => _cameraError = null);
                              _initCamera();
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            // Document border overlay
            Positioned.fill(
              child: _buildDocumentOverlay(),
            ),

            // Top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopBar(),
            ),

            // Bottom controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomControls(),
            ),

            // Stability indicator
            Positioned(
              top: 80,
              left: 20,
              right: 20,
              child: _buildStabilityIndicator(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentOverlay() {
    return AnimatedBuilder(
      animation: _borderColorAnim,
      builder: (context, child) {
        final borderColor = _stabilityStatus == StabilityStatus.stable
            ? Colors.green
            : _stabilityStatus == StabilityStatus.stabilizing
            ? Colors.orange
            : Colors.red.withValues(alpha: 0.7);

        return CustomPaint(
          painter: _DocumentBorderPainter(
            borderColor: borderColor,
            stabilityScore: _stabilityScore,
          ),
        );
      },
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Camera Stabilizer',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Flash toggle
          IconButton(
            icon: Icon(_flashModeIcon(_flashMode), color: Colors.white),
            tooltip: _flashModeLabel(_flashMode),
            onPressed: () async {
              if (_cameraController == null) return;
              final nextMode = _nextFlashMode(_flashMode);
              try {
                await _cameraController!.setFlashMode(nextMode);
                if (mounted) setState(() => _flashMode = nextMode);
              } catch (e) {
                debugPrint('Flash mode error: $e');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStabilityIndicator() {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    switch (_stabilityStatus) {
      case StabilityStatus.stable:
        statusText = 'Stable — Capturing...';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_rounded;
        break;
      case StabilityStatus.stabilizing:
        statusText = 'Stabilizing...';
        statusColor = Colors.orange;
        statusIcon = Icons.radio_button_checked_rounded;
        break;
      case StabilityStatus.unstable:
        statusText = 'Hold phone steady';
        statusColor = Colors.red;
        statusIcon = Icons.warning_rounded;
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(statusIcon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          if (_stabilityStatus == StabilityStatus.stabilizing) ...[
            const SizedBox(width: 8),
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stability bar
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _stabilityScore.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: _stabilityStatus == StabilityStatus.stable
                      ? Colors.green
                      : _stabilityStatus ==
                      StabilityStatus.stabilizing
                      ? Colors.orange
                      : Colors.red,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Stability: ${(_stabilityScore * 100).toInt()}%',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 20),

          // Capture button
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Gallery button
              GestureDetector(
                onTap: () async {
                  final ocrProvider = context.read<OcrProvider>();
                  await ocrProvider.pickFromGallery();
                  if (mounted &&
                      ocrProvider.status == OcrStatus.done) {
                    Navigator.pushReplacementNamed(
                        context, '/result');
                  }
                },
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded,
                      color: Colors.white, size: 24),
                ),
              ),

              const SizedBox(width: 30),

              // Main capture button
              GestureDetector(
                onTap: _isCapturing ? null : _manualCapture,
                child: AnimatedBuilder(
                  animation: _stabilityStatus ==
                      StabilityStatus.stable
                      ? _pulseAnim
                      : const AlwaysStoppedAnimation(1.0),
                  builder: (context, child) => Transform.scale(
                    scale: _stabilityStatus == StabilityStatus.stable
                        ? _pulseAnim.value
                        : 1.0,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: _isCapturing
                            ? Colors.grey
                            : _stabilityStatus ==
                            StabilityStatus.stable
                            ? Colors.green
                            : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: (_stabilityStatus ==
                                StabilityStatus.stable
                                ? Colors.green
                                : Colors.white)
                                .withValues(alpha: 0.4),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isCapturing
                            ? Icons.hourglass_top_rounded
                            : Icons.camera_rounded,
                        color: _stabilityStatus ==
                            StabilityStatus.stable
                            ? Colors.white
                            : Colors.black,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 30),

              // Info button
              GestureDetector(
                onTap: _showHelpDialog,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.info_outline_rounded,
                      color: Colors.white, size: 24),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            _stabilityStatus == StabilityStatus.stable
                ? '✅ Auto capturing...'
                : 'Hold steady for auto capture',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Camera Stabilizer'),
        content: const Text(
          '📱 How to use:\n\n'
              '1. Hold your phone steady over the document\n'
              '2. Wait for the green border to appear\n'
              '3. Photo captures automatically when stable\n'
              '4. Or tap the camera button manually\n\n'
              '🎯 Tips:\n'
              '• Use both hands to hold phone\n'
              '• Place document on flat surface\n'
              '• Good lighting gives better results\n'
              '• Keep fingers off the document — the app warns and '
              'retakes automatically if something is covering it',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}

// Document border painter
class _DocumentBorderPainter extends CustomPainter {
  final Color borderColor;
  final double stabilityScore;

  _DocumentBorderPainter({
    required this.borderColor,
    required this.stabilityScore,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = borderColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    // Document rect (center 80% of screen)
    final docRect = Rect.fromLTRB(
      size.width * 0.06,
      size.height * 0.15,
      size.width * 0.94,
      size.height * 0.75,
    );

    // Draw dark overlay outside document
    final outerPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final innerPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
          docRect, const Radius.circular(12)));
    final overlayPath =
    Path.combine(PathOperation.difference, outerPath, innerPath);
    canvas.drawPath(overlayPath, overlayPaint);

    // Draw document border
    canvas.drawRRect(
      RRect.fromRectAndRadius(docRect, const Radius.circular(12)),
      paint,
    );

    // Draw corner markers
    _drawCorner(canvas, paint, docRect.topLeft, true, true);
    _drawCorner(canvas, paint, docRect.topRight, false, true);
    _drawCorner(canvas, paint, docRect.bottomLeft, true, false);
    _drawCorner(canvas, paint, docRect.bottomRight, false, false);
  }

  void _drawCorner(Canvas canvas, Paint paint, Offset corner,
      bool isLeft, bool isTop) {
    const length = 20.0;
    final xDir = isLeft ? 1.0 : -1.0;
    final yDir = isTop ? 1.0 : -1.0;

    final thickPaint = Paint()
      ..color = paint.color
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
        corner, corner + Offset(length * xDir, 0), thickPaint);
    canvas.drawLine(
        corner, corner + Offset(0, length * yDir), thickPaint);
  }

  @override
  bool shouldRepaint(_DocumentBorderPainter oldDelegate) =>
      oldDelegate.borderColor != borderColor ||
          oldDelegate.stabilityScore != stabilityScore;
}