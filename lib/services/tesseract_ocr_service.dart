import 'package:flutter/foundation.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';

/// Tamil OCR via Tesseract (on-device, offline).
///
/// ✅ Why this exists: Google ML Kit's on-device text recognizer only
/// supports 5 scripts (Latin, Chinese, Japanese, Korean, Devanagari) —
/// Tamil script is NOT among them, so ML Kit can never read Tamil no
/// matter what "language" is selected in the UI. Tesseract's `tam`
/// trained-data model fills that gap.
///
/// Setup: assets/tessdata/tam.traineddata + eng.traineddata, declared in
/// assets/tessdata/tessdata_config.json — the plugin copies these from
/// the asset bundle into its native tessdata dir automatically on first
/// use, no manual file handling needed here.
class TesseractOcrService {
  TesseractOcrService._();

  /// Extracts text from [imagePath] using Tamil-only trained data (`tam`).
  /// ✅ FIX: was `tam+eng` before — running both models together made
  /// Tesseract try to force-match Tamil glyphs against the English
  /// alphabet too, and on real Tamil pages that produced a LOT of
  /// hallucinated English-looking fragments mixed into the output
  /// ("aren It likee the blood", "2244ச to fight" etc) instead of
  /// clean Tamil text. Tamil-only is far more accurate for actual
  /// Tamil documents; the trade-off is English words embedded in an
  /// otherwise-Tamil page may come out slightly mangled.
  static Future<String> extractTamilText(String imagePath) async {
    try {
      return await FlutterTesseractOcr.extractText(
        imagePath,
        language: 'tam',
        args: {
          'preserve_interword_spaces': '1',
        },
      );
    } catch (e) {
      debugPrint('Tesseract Tamil OCR failed: $e');
      rethrow;
    }
  }
}