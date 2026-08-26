import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

class ObstructionResult {
  final bool hasObstruction;
  final String reason;

  const ObstructionResult({required this.hasObstruction, this.reason = ''});
}

/// Detects a finger/thumb/pen/stray object covering part of the document
/// in a just-captured photo.
///
/// ❌ Gap this fills: Smart Stabilizer only checked motion-blur (Laplacian
/// sharpness) before accepting a shot. A perfectly sharp, well-lit photo
/// where a thumb is holding down the corner of the page sailed straight
/// through — sharp ≠ "the whole document is actually visible".
///
/// ✅ Two on-device heuristics (no ML model, cheap enough to run right
/// after every capture), checked over the same document-guide rectangle
/// drawn on screen (see [_DocumentBorderPainter] in this file):
///  1. Skin-tone ratio in the four edge bands of that rectangle — the
///     most common real case is a finger/thumb holding the paper down,
///     which touches one edge of the frame.
///  2. A large, unusually flat (low local contrast) non-white patch
///     inside the rectangle — real paper with printed text is full of
///     small high-contrast edges; any object laid on top of it creates
///     a big smooth blob that breaks that texture.
class ObstructionCheckerService {
  ObstructionCheckerService._();

  static const double _borderBandFraction = 0.12;
  static const double _skinRatioThreshold = 0.22;
  static const double _blobRatioThreshold = 0.18;

  static Future<ObstructionResult> checkObstruction(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return const ObstructionResult(hasObstruction: false);
      }

      // Small copy is plenty for this heuristic and keeps it fast.
      final small = img.copyResize(decoded, width: 300);

      // Same guide rectangle the capture overlay shows the user.
      final left = (small.width * 0.06).round();
      final top = (small.height * 0.15).round();
      final right = (small.width * 0.94).round();
      final bottom = (small.height * 0.75).round();
      final docW = right - left;
      final docH = bottom - top;
      if (docW <= 4 || docH <= 4) {
        return const ObstructionResult(hasObstruction: false);
      }

      final bandW =
      (docW * _borderBandFraction).round().clamp(2, docW ~/ 2);
      final bandH =
      (docH * _borderBandFraction).round().clamp(2, docH ~/ 2);

      final topBand = _skinRatio(small, left, top, docW, bandH);
      final bottomBand =
      _skinRatio(small, left, bottom - bandH, docW, bandH);
      final leftBand = _skinRatio(small, left, top, bandW, docH);
      final rightBand =
      _skinRatio(small, right - bandW, top, bandW, docH);

      final maxEdgeSkin =
      [topBand, bottomBand, leftBand, rightBand].reduce(max);
      if (maxEdgeSkin > _skinRatioThreshold) {
        final side = maxEdgeSkin == topBand
            ? 'top'
            : maxEdgeSkin == bottomBand
            ? 'bottom'
            : maxEdgeSkin == leftBand
            ? 'left'
            : 'right';
        return ObstructionResult(
          hasObstruction: true,
          reason:
          'Looks like a finger is covering the $side edge of the document.',
        );
      }

      final blobRatio = _flatBlobRatio(small, left, top, docW, docH);
      if (blobRatio > _blobRatioThreshold) {
        return const ObstructionResult(
          hasObstruction: true,
          reason: 'Something appears to be covering part of the document.',
        );
      }

      return const ObstructionResult(hasObstruction: false);
    } catch (e) {
      // Heuristic failing should never block a capture the user wants.
      return const ObstructionResult(hasObstruction: false);
    }
  }

  static double _skinRatio(img.Image image, int x, int y, int w, int h) {
    final x0 = x.clamp(0, image.width - 1);
    final y0 = y.clamp(0, image.height - 1);
    final x1 = (x + w).clamp(x0 + 1, image.width);
    final y1 = (y + h).clamp(y0 + 1, image.height);

    int skin = 0;
    int total = 0;
    for (int py = y0; py < y1; py++) {
      for (int px = x0; px < x1; px++) {
        final p = image.getPixel(px, py);
        if (_isSkinTone(p.r.toInt(), p.g.toInt(), p.b.toInt())) skin++;
        total++;
      }
    }
    if (total == 0) return 0;
    return skin / total;
  }

  /// Simple RGB skin-tone rule (Kovac et al.) — good enough to catch a
  /// finger/hand at close range under normal phone-camera lighting,
  /// without needing a color-space conversion.
  static bool _isSkinTone(int r, int g, int b) {
    final maxC = max(r, max(g, b));
    final minC = min(r, min(g, b));
    return r > 95 &&
        g > 40 &&
        b > 20 &&
        (maxC - minC) > 15 &&
        (r - g).abs() > 15 &&
        r > g &&
        r > b;
  }

  /// Fraction of the doc rectangle taken up by the single largest
  /// contiguous "flat, non-white" patch — a stand-in for "an object is
  /// sitting on top of the page here", since plain paper margins are
  /// flat but bright/white, while printed text areas are non-white but
  /// full of small edges (not flat).
  static double _flatBlobRatio(
      img.Image image, int left, int top, int w, int h) {
    const cells = 12;
    final cellW = max(1, w ~/ cells);
    final cellH = max(1, h ~/ cells);
    final flat = List.generate(cells, (_) => List.filled(cells, false));

    for (int gy = 0; gy < cells; gy++) {
      for (int gx = 0; gx < cells; gx++) {
        final cx = left + gx * cellW;
        final cy = top + gy * cellH;
        final stats = _cellStats(image, cx, cy, cellW, cellH);
        flat[gy][gx] = stats.contrastRange < 18 && stats.meanLuminance < 180;
      }
    }

    final visited = List.generate(cells, (_) => List.filled(cells, false));
    int largest = 0;
    for (int gy = 0; gy < cells; gy++) {
      for (int gx = 0; gx < cells; gx++) {
        if (flat[gy][gx] && !visited[gy][gx]) {
          final size = _floodFillCount(flat, visited, gx, gy, cells);
          if (size > largest) largest = size;
        }
      }
    }
    return largest / (cells * cells);
  }

  static int _floodFillCount(List<List<bool>> flat, List<List<bool>> visited,
      int x, int y, int n) {
    final stack = <List<int>>[
      [x, y]
    ];
    int count = 0;
    while (stack.isNotEmpty) {
      final cur = stack.removeLast();
      final cx = cur[0], cy = cur[1];
      if (cx < 0 || cy < 0 || cx >= n || cy >= n) continue;
      if (visited[cy][cx] || !flat[cy][cx]) continue;
      visited[cy][cx] = true;
      count++;
      stack.add([cx + 1, cy]);
      stack.add([cx - 1, cy]);
      stack.add([cx, cy + 1]);
      stack.add([cx, cy - 1]);
    }
    return count;
  }

  static _CellStats _cellStats(img.Image image, int x, int y, int w, int h) {
    final x1 = min(image.width, x + w);
    final y1 = min(image.height, y + h);
    double minL = 255, maxL = 0, sum = 0;
    int count = 0;
    for (int py = y; py < y1; py++) {
      for (int px = x; px < x1; px++) {
        if (px < 0 || py < 0 || px >= image.width || py >= image.height) {
          continue;
        }
        final l = img.getLuminance(image.getPixel(px, py)).toDouble();
        if (l < minL) minL = l;
        if (l > maxL) maxL = l;
        sum += l;
        count++;
      }
    }
    if (count == 0) {
      return const _CellStats(contrastRange: 0, meanLuminance: 255);
    }
    return _CellStats(contrastRange: maxL - minL, meanLuminance: sum / count);
  }
}

class _CellStats {
  final double contrastRange;
  final double meanLuminance;

  const _CellStats(
      {required this.contrastRange, required this.meanLuminance});
}