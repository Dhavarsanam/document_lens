import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:document_lens/services/quality_checker_service.dart';
import 'package:document_lens/providers/ocr_provider.dart';

class QualityCheckerScreen extends StatefulWidget {
  final File imageFile;
  const QualityCheckerScreen({super.key, required this.imageFile});

  @override
  State<QualityCheckerScreen> createState() =>
      _QualityCheckerScreenState();
}

class _QualityCheckerScreenState extends State<QualityCheckerScreen>
    with SingleTickerProviderStateMixin {
  QualityResult? _result;
  bool _isAnalyzing = true;
  late AnimationController _animController;
  late Animation<double> _scoreAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scoreAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _animController, curve: Curves.easeOutCubic),
    );
    _analyzeImage();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _analyzeImage() async {
    setState(() => _isAnalyzing = true);
    await Future.delayed(const Duration(milliseconds: 800));

    final result =
    await QualityCheckerService.checkQuality(widget.imageFile);

    if (mounted) {
      setState(() {
        _result = result;
        _isAnalyzing = false;
      });
      _animController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quality Checker'),
        actions: [
          // Re-analyze
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              _animController.reset();
              _analyzeImage();
            },
          ),
        ],
      ),
      body: _isAnalyzing
          ? _buildAnalyzingUI()
          : _result == null
          ? const Center(child: Text('Analysis failed'))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image preview
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                widget.imageFile,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

            const SizedBox(height: 20),

            // Overall Score Card
            _buildOverallScore(isDark),

            const SizedBox(height: 20),

            // Metric Cards
            const Text('Detailed Analysis',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    label: 'Sharpness',
                    score: _result!.sharpnessScore,
                    icon: Icons.center_focus_strong_rounded,
                    color: Colors.blue,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    label: 'Brightness',
                    score: _result!.brightnessScore,
                    icon: Icons.brightness_5_rounded,
                    color: Colors.orange,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    label: 'Contrast',
                    score: _result!.contrastScore,
                    icon: Icons.contrast_rounded,
                    color: Colors.indigo,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    label: 'Clarity',
                    score: _result!.noiseScore,
                    icon: Icons.hd_rounded,
                    color: Colors.teal,
                    isDark: isDark,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Issues
            if (_result!.issues.isNotEmpty) ...[
              const Text('Issues Found',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              ..._result!.issues.map((issue) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.red
                          .withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red,
                        size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(issue,
                          style: const TextStyle(
                              fontSize: 13)),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 12),
            ],

            // Suggestions
            const Text('Suggestions',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ..._result!.suggestions
                .map((suggestion) => Container(
              margin:
              const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green
                    .withValues(alpha: 0.08),
                borderRadius:
                BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.green
                        .withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(
                      Icons.lightbulb_rounded,
                      color: Colors.green,
                      size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(suggestion,
                        style: const TextStyle(
                            fontSize: 13)),
                  ),
                ],
              ),
            )),

            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                // Enhance button
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(
                        Icons.auto_fix_high_rounded),
                    label: const Text('Enhance'),
                    onPressed: () {
                      Navigator.pushReplacementNamed(
                        context,
                        '/image_enhance',
                        arguments: widget.imageFile,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Scan anyway
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    icon: const Icon(
                        Icons.document_scanner_rounded),
                    label: const Text('Scan Anyway'),
                    onPressed: () async {
                      final ocrProvider =
                      context.read<OcrProvider>();
                      await ocrProvider
                          .processImageFromPath(
                          widget.imageFile.path);
                      if (mounted &&
                          ocrProvider.status ==
                              OcrStatus.done) {
                        Navigator.pushReplacementNamed(
                            context, '/result');
                      }
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyzingUI() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.indigo.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.document_scanner_rounded,
                color: Colors.indigo, size: 48),
          ),
          const SizedBox(height: 24),
          const Text(
            'Analyzing Image Quality...',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Checking sharpness, brightness & contrast',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(color: Colors.indigo),
        ],
      ),
    );
  }

  Widget _buildOverallScore(bool isDark) {
    final result = _result!;
    final color = QualityCheckerService.levelColor(result.level);
    final label = QualityCheckerService.levelLabel(result.level);
    final emoji = QualityCheckerService.levelEmoji(result.level);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Circular progress
          SizedBox(
            width: 90,
            height: 90,
            child: AnimatedBuilder(
              animation: _scoreAnim,
              builder: (context, child) => Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: (_result!.overallScore / 100) *
                        _scoreAnim.value,
                    strokeWidth: 8,
                    backgroundColor:
                    Colors.grey.withValues(alpha: 0.2),
                    color: color,
                  ),
                  Center(
                    child: Text(
                      '${(_result!.overallScore * _scoreAnim.value).round()}%',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 20),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$emoji $label Quality',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  result.overallScore >= 80
                      ? 'Ready for OCR scanning!'
                      : result.overallScore >= 60
                      ? 'Acceptable for scanning'
                      : result.overallScore >= 40
                      ? 'Consider enhancing first'
                      : 'Poor quality — enhance recommended',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: AnimatedBuilder(
                    animation: _scoreAnim,
                    builder: (context, child) =>
                        LinearProgressIndicator(
                          value: (_result!.overallScore / 100) *
                              _scoreAnim.value,
                          minHeight: 8,
                          backgroundColor:
                          Colors.grey.withValues(alpha: 0.2),
                          color: color,
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

  Widget _buildMetricCard({
    required String label,
    required int score,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return AnimatedBuilder(
      animation: _scoreAnim,
      builder: (context, child) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2130) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                const Spacer(),
                Text(
                  '${(score * _scoreAnim.value).round()}%',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (score / 100) * _scoreAnim.value,
                minHeight: 6,
                backgroundColor:
                Colors.grey.withValues(alpha: 0.15),
                color: score >= 70
                    ? Colors.green
                    : score >= 50
                    ? Colors.orange
                    : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}