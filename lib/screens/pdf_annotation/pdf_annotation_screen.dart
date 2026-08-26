import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

enum AnnotationTool { highlight, text, draw, eraser }

class Annotation {
  final Offset position;
  final String type;
  final Color color;
  final String? text;
  final List<Offset>? drawPoints;

  Annotation({
    required this.position,
    required this.type,
    required this.color,
    this.text,
    this.drawPoints,
  });
}

class Stroke {
  final List<Offset> points;
  final Color color;
  Stroke({required this.points, required this.color});
}

class PdfAnnotationScreen extends StatefulWidget {
  final File imageFile;
  const PdfAnnotationScreen({super.key, required this.imageFile});

  @override
  State<PdfAnnotationScreen> createState() =>
      _PdfAnnotationScreenState();
}

class _PdfAnnotationScreenState extends State<PdfAnnotationScreen>
    with SingleTickerProviderStateMixin {
  AnnotationTool _activeTool = AnnotationTool.highlight;
  Color _activeColor = const Color(0xFFFFEB3B);
  final List<Annotation> _annotations = [];
  final List<Stroke> _drawStrokes = [];
  List<Offset> _currentStroke = [];
  bool _isDrawing = false;
  bool _isSaving = false;
  final GlobalKey _canvasKey = GlobalKey();

  // Animation for toolbar
  late AnimationController _toolbarController;
  late Animation<double> _toolbarAnim;

  final List<Color> _colors = [
    const Color(0xFFFFEB3B), // Yellow highlight
    const Color(0xFF4CAF50), // Green
    const Color(0xFFFF5252), // Red
    const Color(0xFF2196F3), // Blue
    const Color(0xFFFF9800), // Orange
    Colors.black,
  ];

  @override
  void initState() {
    super.initState();
    _toolbarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    _toolbarAnim = CurvedAnimation(
        parent: _toolbarController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _toolbarController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    if (_activeTool == AnnotationTool.draw) {
      setState(() {
        _isDrawing = true;
        _currentStroke = [details.localPosition];
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_activeTool == AnnotationTool.draw && _isDrawing) {
      setState(() {
        _currentStroke.add(details.localPosition);
      });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_activeTool == AnnotationTool.draw && _isDrawing) {
      setState(() {
        _drawStrokes.add(
            Stroke(points: List.from(_currentStroke), color: _activeColor));
        _currentStroke = [];
        _isDrawing = false;
      });
    }
  }

  void _onTapDown(TapDownDetails details) {
    if (_activeTool == AnnotationTool.highlight) {
      setState(() {
        _annotations.add(Annotation(
          position: details.localPosition,
          type: 'highlight',
          color: _activeColor,
        ));
      });
      _showHighlightFeedback(details.localPosition);
    } else if (_activeTool == AnnotationTool.text) {
      _showTextAnnotationDialog(details.localPosition);
    } else if (_activeTool == AnnotationTool.eraser) {
      _eraseNearby(details.localPosition);
    }
  }

  void _showHighlightFeedback(Offset position) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.highlight_rounded, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Highlight added!'),
          ],
        ),
        backgroundColor: _activeColor.computeLuminance() > 0.5
            ? Colors.grey[800]!
            : _activeColor,
        duration: const Duration(milliseconds: 800),
      ),
    );
  }

  void _showTextAnnotationDialog(Offset position) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Text Note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Type your annotation...',
            border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _annotations.add(Annotation(
                    position: position,
                    type: 'text',
                    color: _activeColor,
                    text: controller.text.trim(),
                  ));
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _eraseNearby(Offset position) {
    setState(() {
      _annotations.removeWhere((a) {
        final dx = a.position.dx - position.dx;
        final dy = a.position.dy - position.dy;
        return (dx * dx + dy * dy) < 2500; // 50px radius
      });
      _drawStrokes.removeWhere((stroke) {
        return stroke.points.any((pt) {
          final dx = pt.dx - position.dx;
          final dy = pt.dy - position.dy;
          return (dx * dx + dy * dy) < 2500;
        });
      });
    });
  }

  void _undo() {
    setState(() {
      if (_drawStrokes.isNotEmpty &&
          (_annotations.isEmpty ||
              _drawStrokes.length > _annotations.length)) {
        _drawStrokes.removeLast();
      } else if (_annotations.isNotEmpty) {
        _annotations.removeLast();
      }
    });
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear All?'),
        content:
        const Text('This will remove all annotations from the document.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _annotations.clear();
                _drawStrokes.clear();
              });
              Navigator.pop(context);
            },
            child: const Text('Clear',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAnnotations() async {
    if (_annotations.isEmpty && _drawStrokes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No annotations to save yet'),
          backgroundColor: Colors.grey,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final boundary = _canvasKey.currentContext?.findRenderObject()
      as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Canvas not ready');
      }

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData =
      await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Could not encode image');

      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/annotated_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);

      if (mounted) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: '${_annotations.length + _drawStrokes.length} annotations',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1117) : Colors.grey[100],
      appBar: AppBar(
        title: const Text('PDF Annotation'),
        actions: [
          // Undo
          IconButton(
            icon: const Icon(Icons.undo_rounded),
            tooltip: 'Undo',
            onPressed: _undo,
          ),
          // Clear
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Clear All',
            onPressed: _clearAll,
          ),
          // Save
          TextButton.icon(
            icon: _isSaving
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
                : const Icon(Icons.save_rounded,
                color: Colors.white, size: 18),
            label: const Text('Save',
                style: TextStyle(color: Colors.white)),
            onPressed: _isSaving ? null : _saveAnnotations,
          ),
        ],
      ),
      body: Column(
        children: [
          // ✅ Tool Banner
          FadeTransition(
            opacity: _toolbarAnim,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              color: isDark
                  ? const Color(0xFF1E2130)
                  : Colors.white,
              child: Row(
                children: [
                  // Tool buttons
                  _ToolButton(
                    icon: Icons.highlight_rounded,
                    label: 'Highlight',
                    isActive:
                    _activeTool == AnnotationTool.highlight,
                    activeColor: Colors.amber,
                    onTap: () => setState(
                            () => _activeTool = AnnotationTool.highlight),
                  ),
                  const SizedBox(width: 8),
                  _ToolButton(
                    icon: Icons.text_fields_rounded,
                    label: 'Text',
                    isActive: _activeTool == AnnotationTool.text,
                    activeColor: Colors.blue,
                    onTap: () => setState(
                            () => _activeTool = AnnotationTool.text),
                  ),
                  const SizedBox(width: 8),
                  _ToolButton(
                    icon: Icons.draw_rounded,
                    label: 'Draw',
                    isActive: _activeTool == AnnotationTool.draw,
                    activeColor: Colors.green,
                    onTap: () => setState(
                            () => _activeTool = AnnotationTool.draw),
                  ),
                  const SizedBox(width: 8),
                  _ToolButton(
                    icon: Icons.auto_fix_normal_rounded,
                    label: 'Erase',
                    isActive: _activeTool == AnnotationTool.eraser,
                    activeColor: Colors.red,
                    onTap: () => setState(
                            () => _activeTool = AnnotationTool.eraser),
                  ),

                  const Spacer(),

                  // Annotation count badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_annotations.length + _drawStrokes.length} notes',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.blue,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ✅ Color Picker Row
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            color: isDark
                ? const Color(0xFF1A1D2E)
                : Colors.grey[50],
            child: Row(
              children: [
                const Text('Color: ',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey)),
                ..._colors.map((color) => GestureDetector(
                  onTap: () =>
                      setState(() => _activeColor = color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    width: _activeColor == color ? 28 : 22,
                    height: _activeColor == color ? 28 : 22,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _activeColor == color
                            ? Colors.white
                            : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: _activeColor == color
                          ? [
                        BoxShadow(
                          color: color
                              .withValues(alpha: 0.5),
                          blurRadius: 6,
                        )
                      ]
                          : [],
                    ),
                  ),
                )),

                const Spacer(),

                // Active tool indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getToolColor()
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _getToolColor()
                            .withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getToolIcon(),
                          color: _getToolColor(), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _getToolName(),
                        style: TextStyle(
                            fontSize: 11,
                            color: _getToolColor(),
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ✅ Document Canvas
          Expanded(
            child: GestureDetector(
              onTapDown: _onTapDown,
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: RepaintBoundary(
                key: _canvasKey,
                child: Stack(
                  children: [
                    // Document image
                    Positioned.fill(
                      child: InteractiveViewer(
                        child: Image.file(
                          widget.imageFile,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    // Draw overlay
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _AnnotationPainter(
                          annotations: _annotations,
                          drawStrokes: _drawStrokes,
                          currentStroke: _currentStroke,
                          activeColor: _activeColor,
                        ),
                      ),
                    ),

                    // Text annotation labels
                    ..._annotations
                        .where((a) => a.type == 'text')
                        .map((a) => Positioned(
                      left: a.position.dx,
                      top: a.position.dy - 30,
                      child: Container(
                        constraints: const BoxConstraints(
                            maxWidth: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: a.color.withValues(alpha: 0.9),
                          borderRadius:
                          BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: 0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          a.text ?? '',
                          style: TextStyle(
                            fontSize: 11,
                            color: a.color.computeLuminance() >
                                0.5
                                ? Colors.black87
                                : Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )),
                  ],
                ),
              ),
            ),
          ),

          // ✅ Bottom tip bar
          Container(
            padding: const EdgeInsets.all(12),
            color: isDark
                ? const Color(0xFF1E2130)
                : Colors.white,
            child: Row(
              children: [
                Icon(_getToolIcon(),
                    color: _getToolColor(), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getToolTip(),
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
                if (_annotations.isNotEmpty ||
                    _drawStrokes.isNotEmpty)
                  TextButton(
                    onPressed: _isSaving ? null : _saveAnnotations,
                    child: const Text('Save'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getToolColor() {
    switch (_activeTool) {
      case AnnotationTool.highlight:
        return Colors.amber;
      case AnnotationTool.text:
        return Colors.blue;
      case AnnotationTool.draw:
        return Colors.green;
      case AnnotationTool.eraser:
        return Colors.red;
    }
  }

  IconData _getToolIcon() {
    switch (_activeTool) {
      case AnnotationTool.highlight:
        return Icons.highlight_rounded;
      case AnnotationTool.text:
        return Icons.text_fields_rounded;
      case AnnotationTool.draw:
        return Icons.draw_rounded;
      case AnnotationTool.eraser:
        return Icons.auto_fix_normal_rounded;
    }
  }

  String _getToolName() {
    switch (_activeTool) {
      case AnnotationTool.highlight:
        return 'Highlight';
      case AnnotationTool.text:
        return 'Text Note';
      case AnnotationTool.draw:
        return 'Draw';
      case AnnotationTool.eraser:
        return 'Eraser';
    }
  }

  String _getToolTip() {
    switch (_activeTool) {
      case AnnotationTool.highlight:
        return 'Tap anywhere on the document to add a highlight';
      case AnnotationTool.text:
        return 'Tap anywhere to add a text note';
      case AnnotationTool.draw:
        return 'Draw freely on the document';
      case AnnotationTool.eraser:
        return 'Tap on annotations to erase them';
    }
  }
}

// Tool Button Widget
class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? activeColor
                : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isActive ? activeColor : Colors.grey,
                size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? activeColor : Colors.grey,
                fontWeight: isActive
                    ? FontWeight.w700
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Annotation Painter
class _AnnotationPainter extends CustomPainter {
  final List<Annotation> annotations;
  final List<Stroke> drawStrokes;
  final List<Offset> currentStroke;
  final Color activeColor;

  _AnnotationPainter({
    required this.annotations,
    required this.drawStrokes,
    required this.currentStroke,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw highlights
    for (final annotation in annotations) {
      if (annotation.type == 'highlight') {
        final paint = Paint()
          ..color = annotation.color.withValues(alpha: 0.35)
          ..strokeWidth = 20
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

        canvas.drawLine(
          annotation.position + const Offset(-30, 0),
          annotation.position + const Offset(30, 0),
          paint,
        );
      }
    }

    // Draw strokes
    final strokePaint = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in drawStrokes) {
      if (stroke.points.length < 2) continue;
      strokePaint.color = stroke.color.withValues(alpha: 0.8);
      final path = Path()
        ..moveTo(stroke.points[0].dx, stroke.points[0].dy);
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, strokePaint);
    }

    // Draw current stroke
    if (currentStroke.length >= 2) {
      strokePaint.color = activeColor.withValues(alpha: 0.8);
      final path = Path()
        ..moveTo(currentStroke[0].dx, currentStroke[0].dy);
      for (int i = 1; i < currentStroke.length; i++) {
        path.lineTo(currentStroke[i].dx, currentStroke[i].dy);
      }
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(_AnnotationPainter oldDelegate) => true;
}