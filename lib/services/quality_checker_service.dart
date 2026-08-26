import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart'; // ✅ Add this
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

enum QualityLevel { excellent, good, fair, poor }

class QualityResult {
  final int overallScore;
  final int sharpnessScore;
  final int brightnessScore;
  final int contrastScore;
  final int noiseScore;
  final QualityLevel level;
  final List<String> issues;
  final List<String> suggestions;

  QualityResult({
    required this.overallScore,
    required this.sharpnessScore,
    required this.brightnessScore,
    required this.contrastScore,
    required this.noiseScore,
    required this.level,
    required this.issues,
    required this.suggestions,
  });
}

class QualityCheckerService {
  /// ✅ Main quality check function
  static Future<QualityResult> checkQuality(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);

    if (image == null) {
      return QualityResult(
        overallScore: 0,
        sharpnessScore: 0,
        brightnessScore: 0,
        contrastScore: 0,
        noiseScore: 0,
        level: QualityLevel.poor,
        issues: ['Could not analyze image'],
        suggestions: ['Try scanning again'],
      );
    }

    // Calculate scores
    final sharpness = _calculateSharpness(image);
    final brightness = _calculateBrightness(image);
    final contrast = _calculateContrast(image);
    final noise = _calculateNoise(image);

    // Overall score (weighted)
    final overall = ((sharpness * 0.4) +
        (brightness * 0.25) +
        (contrast * 0.25) +
        (noise * 0.1))
        .round()
        .clamp(0, 100);

    // Detect issues
    final issues = <String>[];
    final suggestions = <String>[];

    if (sharpness < 40) {
      issues.add('📷 Image is blurry');
      suggestions.add('Hold phone steady while scanning');
    }
    if (brightness < 30) {
      issues.add('🌑 Image is too dark');
      suggestions.add('Scan in better lighting or use flash');
    }
    if (brightness > 85) {
      issues.add('☀️ Image is overexposed');
      suggestions.add('Reduce lighting or move away from direct light');
    }
    if (contrast < 35) {
      issues.add('🔲 Low contrast detected');
      suggestions.add('Use Image Enhancement → Document Mode');
    }
    if (noise > 60) {
      issues.add('📡 High image noise');
      suggestions.add('Scan in better lighting to reduce noise');
    }

    if (issues.isEmpty) {
      suggestions.add('✅ Great scan quality! Ready for OCR.');
    }

    // Quality level
    QualityLevel level;
    if (overall >= 80) {
      level = QualityLevel.excellent;
    } else if (overall >= 60) {
      level = QualityLevel.good;
    } else if (overall >= 40) {
      level = QualityLevel.fair;
    } else {
      level = QualityLevel.poor;
    }

    return QualityResult(
      overallScore: overall,
      sharpnessScore: sharpness.round().clamp(0, 100),
      brightnessScore: brightness.round().clamp(0, 100),
      contrastScore: contrast.round().clamp(0, 100),
      noiseScore: (100 - noise).round().clamp(0, 100),
      level: level,
      issues: issues,
      suggestions: suggestions,
    );
  }

  /// Sharpness via Laplacian variance
  static double _calculateSharpness(img.Image image) {
    final gray = img.grayscale(image);
    final small = img.copyResize(gray,
        width: min(image.width, 200),
        height: min(image.height, 200));

    double sum = 0;
    double sumSq = 0;
    int count = 0;

    for (int y = 1; y < small.height - 1; y++) {
      for (int x = 1; x < small.width - 1; x++) {
        final center = img.getLuminance(small.getPixel(x, y));
        final top = img.getLuminance(small.getPixel(x, y - 1));
        final bottom = img.getLuminance(small.getPixel(x, y + 1));
        final left = img.getLuminance(small.getPixel(x - 1, y));
        final right = img.getLuminance(small.getPixel(x + 1, y));

        // Laplacian
        final lap = (4 * center - top - bottom - left - right).abs();
        sum += lap;
        sumSq += lap * lap;
        count++;
      }
    }

    if (count == 0) return 50;
    final mean = sum / count;
    final variance = (sumSq / count) - (mean * mean);

    // Normalize to 0-100
    return (variance / 500).clamp(0.0, 100.0) * 100;
  }

  /// Brightness — average luminance
  static double _calculateBrightness(img.Image image) {
    final small = img.copyResize(image,
        width: min(image.width, 100),
        height: min(image.height, 100));

    double total = 0;
    int count = 0;

    for (int y = 0; y < small.height; y++) {
      for (int x = 0; x < small.width; x++) {
        total += img.getLuminance(small.getPixel(x, y));
        count++;
      }
    }

    if (count == 0) return 50;
    final avgLuminance = total / count; // 0-255
    return (avgLuminance / 255) * 100;
  }

  /// Contrast — standard deviation of luminance
  static double _calculateContrast(img.Image image) {
    final small = img.copyResize(image,
        width: min(image.width, 100),
        height: min(image.height, 100));

    double sum = 0;
    double sumSq = 0;
    int count = 0;

    for (int y = 0; y < small.height; y++) {
      for (int x = 0; x < small.width; x++) {
        final lum = img.getLuminance(small.getPixel(x, y));
        sum += lum;
        sumSq += lum * lum;
        count++;
      }
    }

    if (count == 0) return 50;
    final mean = sum / count;
    final variance = (sumSq / count) - (mean * mean);
    final stdDev = sqrt(variance);

    // Normalize (max stddev ~127)
    return (stdDev / 80).clamp(0.0, 1.0) * 100;
  }

  /// Noise — high frequency variation
  static double _calculateNoise(img.Image image) {
    final gray = img.grayscale(image);
    final small = img.copyResize(gray,
        width: min(image.width, 150),
        height: min(image.height, 150));

    double noiseSum = 0;
    int count = 0;

    for (int y = 1; y < small.height - 1; y++) {
      for (int x = 1; x < small.width - 1; x++) {
        final c = img.getLuminance(small.getPixel(x, y));
        final r = img.getLuminance(small.getPixel(x + 1, y));
        final b = img.getLuminance(small.getPixel(x, y + 1));
        noiseSum += (c - r).abs() + (c - b).abs();
        count++;
      }
    }

    if (count == 0) return 0;
    final avgNoise = noiseSum / count;
    return (avgNoise / 30).clamp(0.0, 1.0) * 100;
  }

  static String levelLabel(QualityLevel level) {
    switch (level) {
      case QualityLevel.excellent:
        return 'Excellent';
      case QualityLevel.good:
        return 'Good';
      case QualityLevel.fair:
        return 'Fair';
      case QualityLevel.poor:
        return 'Poor';
    }
  }

  static Color levelColor(QualityLevel level) {
    switch (level) {
      case QualityLevel.excellent:
        return const Color(0xFF00C853);
      case QualityLevel.good:
        return const Color(0xFF64DD17);
      case QualityLevel.fair:
        return const Color(0xFFFFAB00);
      case QualityLevel.poor:
        return const Color(0xFFD50000);
    }
  }

  static String levelEmoji(QualityLevel level) {
    switch (level) {
      case QualityLevel.excellent:
        return '🌟';
      case QualityLevel.good:
        return '✅';
      case QualityLevel.fair:
        return '⚠️';
      case QualityLevel.poor:
        return '❌';
    }
  }
}