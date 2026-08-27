import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

class ObstructionResult {
  final bool hasObstruction;
  final String reason;

  const ObstructionResult({required this.hasObstruction, this.reason = ''});
}

/// Detects (a) a finger/thumb/pen/stray object covering part of the
/// document, and (b) anything other than the document visible anywhere
/// else in the frame, in a just-captured photo.
///
/// ❌ Gap this fills: Smart Stabilizer only checked motion-blur (Laplacian
/// sharpness) before accepting a shot. A perfectly sharp, well-lit photo
/// where a thumb is holding down the corner of the page — or where a hand,
/// second object, or cluttered background sits next to the document —
/// sailed straight through — sharp ≠ "only the document is in frame".
///
/// ✅ On-device heuristics (no ML model, cheap enough to run right after
/// every capture), checked against the same document-guide rectangle
/// drawn on screen (see [_DocumentBorderPainter] in the camera screen):
///  1. Skin-tone ratio in the four edge bands *inside* that rectangle —
///     the most common real case is a finger/thumb holding the paper
///     down, which touches one edge of the frame.
///  2. A large, unusually flat (low local contrast) non-white patch
///     inside the rectangle — real paper with printed text is full of
///     small high-contrast edges; any object laid on top of it creates
///     a big smooth blob that breaks that texture.
///  3. Skin-tone ratio in the margin *outside* the rectangle (the strip
///     of frame around the guide box) — catches a hand, second phone, or
///     other body part visible next to the document rather than on it.
///  4. A large contiguous "colourful + edgy" patch in that same outside
///     margin — catches a stray object (pen, book, mug, phone, etc.)
///     sitting in frame beside the document; plain desks/floors are
///     mostly low-saturation and comparatively uniform.
///
/// Any single hit is enough to reject the shot — nothing here is only a
/// "warning"; the caller is expected to always require a retake rather
/// than ever silently accepting a flagged photo.
class ObstructionCheckerService {
  ObstructionCheckerService._();

  static const double _borderBandFraction = 0.12;
  static const double _skinRatioThreshold = 0.22;
  static const double _blobRatioThreshold = 0.18;

  // Outside-the-document (background/margin) thresholds — deliberately a
  // bit more forgiving than the on-document ones, since the margin can
  // legitimately contain some desk/table texture.
  static const double _marginSkinRatioThreshold = 0.10;
  static const double _marginClutterRatioThreshold = 0.20;
  static const double _clutterChromaThreshold = 40;
  static const double _clutterContrastThreshold = 35;

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

      // ── Checks 3 & 4: is only the document in frame, or is there a
      // hand/other object visible in the margin around the guide box? ──
      final marginSkin =
      _marginSkinRatio(small, left, top, right, bottom);
      if (marginSkin > _marginSkinRatioThreshold) {
        return const ObstructionResult(
          hasObstruction: true,
          reason:
          'A hand or object is visible next to the document — keep only '
              'the document in frame.',
        );
      }

      final marginClutter =
      _marginClutterRatio(small, left, top, right, bottom);
      if (marginClutter > _marginClutterRatioThreshold) {
        return const ObstructionResult(
          hasObstruction: true,
          reason:
          'Something else is visible in the frame — keep only the '
              'document in frame.',
        );
      }

      return const ObstructionResult(hasObstruction: false);
    } catch (e) {
      // Heuristic failing should never block a capture the user wants.
      return const ObstructionResult(hasObstruction: false);
    }
  }

  /// The four strips of the frame that fall *outside* the document guide
  /// rectangle but still inside the photo — i.e. everything the camera
  /// captured that isn't the document itself.
  static List<List<int>> _marginRegions(
      img.Image image, int left, int top, int right, int bottom) {
    final w = image.width;
    final h = image.height;
    return [
      // top strip: full width, above the doc box
      [0, 0, w, top],
      // bottom strip: full width, below the doc box
      [0, bottom, w, h - bottom],
      // left strip: beside the doc box, between top and bottom
      [0, top, left, bottom - top],
      // right strip: beside the doc box, between top and bottom
      [right, top, w - right, bottom - top],
    ];
  }

  /// Skin-tone ratio across all margin strips combined.
  static double _marginSkinRatio(
      img.Image image, int left, int top, int right, int bottom) {
    int skin = 0;
    int total = 0;
    for (final r in _marginRegions(image, left, top, right, bottom)) {
      final rx = r[0], ry = r[1], rw = r[2], rh = r[3];
      if (rw <= 0 || rh <= 0) continue;
      final x0 = rx.clamp(0, image.width - 1);
      final y0 = ry.clamp(0, image.height - 1);
      final x1 = (rx + rw).clamp(x0 + 1, image.width);
      final y1 = (ry + rh).clamp(y0 + 1, image.height);
      for (int py = y0; py < y1; py++) {
        for (int px = x0; px < x1; px++) {
          final p = image.getPixel(px, py);
          if (_isSkinTone(p.r.toInt(), p.g.toInt(), p.b.toInt())) skin++;
          total++;
        }
      }
    }
    if (total == 0) return 0;
    return skin / total;
  }

  /// Fraction of the largest contiguous "colourful + edgy" patch across
  /// all margin strips — a stand-in for "a foreign object is sitting in
  /// frame next to the document" (plain desk/floor background tends to
  /// be low-saturation and comparatively flat by comparison).
  static double _marginClutterRatio(
      img.Image image, int left, int top, int right, int bottom) {
    const cells = 10;
    double largestFraction = 0;

    for (final r in _marginRegions(image, left, top, right, bottom)) {
      final rx = r[0], ry = r[1], rw = r[2], rh = r[3];
      if (rw < cells || rh < cells) continue;

      final cellW = max(1, rw ~/ cells);
      final cellH = max(1, rh ~/ cells);
      final foreign = List.generate(cells, (_) => List.filled(cells, false));

      for (int gy = 0; gy < cells; gy++) {
        for (int gx = 0; gx < cells; gx++) {
          final cx = rx + gx * cellW;
          final cy = ry + gy * cellH;
          final stats = _cellStats(image, cx, cy, cellW, cellH);
          foreign[gy][gx] = stats.contrastRange > _clutterContrastThreshold &&
              stats.chromaMean > _clutterChromaThreshold;
        }
      }

      final visited = List.generate(cells, (_) => List.filled(cells, false));
      int largest = 0;
      for (int gy = 0; gy < cells; gy++) {
        for (int gx = 0; gx < cells; gx++) {
          if (foreign[gy][gx] && !visited[gy][gx]) {
            final size = _floodFillCount(foreign, visited, gx, gy, cells);
            if (size > largest) largest = size;
          }
        }
      }

      final fraction = largest / (cells * cells);
      if (fraction > largestFraction) largestFraction = fraction;
    }

    return largestFraction;
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
    double minL = 255, maxL = 0, sumL = 0, sumChroma = 0;
    int count = 0;
    for (int py = y; py < y1; py++) {
      for (int px = x; px < x1; px++) {
        if (px < 0 || py < 0 || px >= image.width || py >= image.height) {
          continue;
        }
        final p = image.getPixel(px, py);
        final l = img.getLuminance(p).toDouble();
        if (l < minL) minL = l;
        if (l > maxL) maxL = l;
        sumL += l;
        final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();
        sumChroma += (max(r, max(g, b)) - min(r, min(g, b))).toDouble();
        count++;
      }
    }
    if (count == 0) {
      return const _CellStats(
          contrastRange: 0, meanLuminance: 255, chromaMean: 0);
    }
    return _CellStats(
      contrastRange: maxL - minL,
      meanLuminance: sumL / count,
      chromaMean: sumChroma / count,
    );
  }
}

class _CellStats {
  final double contrastRange;
  final double meanLuminance;
  final double chromaMean;

  const _CellStats({
    required this.contrastRange,
    required this.meanLuminance,
    required this.chromaMean,
  });
}