import 'dart:math';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Fixes OCR reading order for multi-column layouts (newspapers, brochures,
/// two-column notices etc).
///
/// ❌ Problem: `RecognizedText.text` just concatenates ML Kit's [TextBlock]s
/// in whatever internal order the recognizer returns them — for a single
/// paragraph photo that's fine, but for a newspaper-style page (2-3 text
/// columns side by side) it interleaves lines from different columns, so
/// the extracted text reads like words jumbled from unrelated sentences.
/// That's what makes it LOOK like "language recognition isn't working"
/// even though every individual character was read correctly.
///
/// ✅ Fix: re-order blocks using their bounding boxes — cluster them into
/// vertical columns by horizontal (x-axis) overlap, sort columns left to
/// right, then sort each column's blocks top to bottom — before joining
/// into the final text. Single-column photos (the common case) fall
/// through unchanged since everything lands in one column.
class TextOrderingService {
  TextOrderingService._();

  static String buildReadingOrderText(RecognizedText recognizedText) {
    final blocks = recognizedText.blocks;
    if (blocks.isEmpty) return recognizedText.text;
    if (blocks.length <= 2) return recognizedText.text;

    final columns = _clusterIntoColumns(blocks);

    // ✅ FIX: only trust the column-based reorder when it looks like a
    // GENUINE multi-column layout — a handful of columns, most holding
    // more than one block. Without this guard, a normal single-column
    // paragraph (where line widths vary naturally) got mis-clustered
    // into many one-block "columns", and sorting those left-to-right
    // scrambled the sentence into isolated word fragments ("rned",
    // "keep", "hiva"...) instead of leaving it alone. Anything that
    // doesn't clearly look like columns falls back to ML Kit's own
    // (normal, correct) block order.
    final multiBlockColumns = columns.where((c) => c.length > 1).length;
    final looksLikeGenuineColumns = columns.length >= 2 &&
        columns.length <= 4 &&
        multiBlockColumns >= columns.length - 1;

    if (!looksLikeGenuineColumns) {
      return recognizedText.text;
    }

    for (final col in columns) {
      col.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));
    }
    return columns.expand((c) => c).map((b) => b.text).join('\n\n');
  }

  static List<List<TextBlock>> _clusterIntoColumns(List<TextBlock> blocks) {
    // Cluster blocks into columns by left-to-right x-overlap.
    final byLeft = [...blocks]
      ..sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));

    final List<List<TextBlock>> columns = [];
    for (final block in byLeft) {
      final rect = block.boundingBox;
      List<TextBlock>? bestColumn;
      double bestOverlapRatio = 0;

      for (final col in columns) {
        final colLeft =
        col.map((b) => b.boundingBox.left).reduce(min);
        final colRight =
        col.map((b) => b.boundingBox.right).reduce(max);
        final overlap =
            min(rect.right, colRight) - max(rect.left, colLeft);
        if (overlap <= 0) continue;
        final ratio = overlap / rect.width;
        if (ratio > bestOverlapRatio) {
          bestOverlapRatio = ratio;
          bestColumn = col;
        }
      }

      // >40% horizontal overlap with an existing column -> same column.
      // Otherwise it's a new column band.
      if (bestColumn != null && bestOverlapRatio > 0.4) {
        bestColumn.add(block);
      } else {
        columns.add([block]);
      }
    }

    // Columns left to right by their leftmost edge.
    columns.sort((a, b) {
      final aLeft = a.map((bl) => bl.boundingBox.left).reduce(min);
      final bLeft = b.map((bl) => bl.boundingBox.left).reduce(min);
      return aLeft.compareTo(bLeft);
    });

    // Inside each column, top to bottom (also needed before the caller
    // decides whether these columns look genuine).
    for (final col in columns) {
      col.sort(
              (a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));
    }

    return columns;
  }
}