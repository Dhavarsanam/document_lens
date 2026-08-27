import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// Translates OCR-extracted text from one language to another (any pair
/// this app supports, not just "into Tamil").
///
/// This is separate from OCR: OCR reads text in whatever script/language
/// it's written in; this service then converts that text's *meaning*
/// into a different language. Uses Google ML Kit's on-device translation
/// models — each language pair's model (~30MB) downloads once over the
/// internet, then works fully offline afterwards.
class TranslationService {
  TranslationService._();

  /// Maps our app's internal language codes to ML Kit's TranslateLanguage.
  /// Returns null for languages ML Kit's translator doesn't support
  /// (Sanskrit, Nepali) — caller should show a friendly "not supported"
  /// message rather than crash.
  static TranslateLanguage? _toTranslateLanguage(String code) {
    switch (code) {
      case 'english':
        return TranslateLanguage.english;
      case 'hindi':
        return TranslateLanguage.hindi;
      case 'tamil':
        return TranslateLanguage.tamil;
      case 'marathi':
        return TranslateLanguage.marathi;
      case 'chinese':
        return TranslateLanguage.chinese;
      case 'japanese':
        return TranslateLanguage.japanese;
      case 'korean':
        return TranslateLanguage.korean;
      case 'french':
        return TranslateLanguage.french;
      case 'german':
        return TranslateLanguage.german;
      case 'spanish':
        return TranslateLanguage.spanish;
      case 'sanskrit':
      case 'nepali':
      default:
        return null; // not in ML Kit's supported language list
    }
  }

  /// General-purpose translate: [text] from [sourceLanguageCode] into
  /// [targetLanguageCode] — both our app's internal language codes (e.g.
  /// 'tamil', 'english'). Throws [UnsupportedError] if either side has
  /// no ML Kit translation model. Returns [text] unchanged if source and
  /// target are the same language.
  ///
  /// ✅ FIX: previously sent the ENTIRE extracted text to
  /// `translator.translateText()` in one call. ML Kit's on-device
  /// translation model has a practical per-call length limit — for a
  /// short test sentence that's invisible, but for a real scanned page
  /// (a paragraph or more of OCR text) only the portion up to that limit
  /// actually got translated; the rest silently passed through
  /// unchanged, which is exactly "some words never convert" for longer
  /// documents. Now the text is chunked into safe-sized pieces (by line,
  /// staying under [_maxChunkChars]) and each chunk is translated
  /// separately with the same translator instance, then rejoined — so
  /// every line in the document actually gets translated, not just the
  /// first chunk.
  static const int _maxChunkChars = 500;

  static Future<String> translateText({
    required String text,
    required String sourceLanguageCode,
    required String targetLanguageCode,
  }) async {
    if (sourceLanguageCode == targetLanguageCode) return text;

    final sourceLang = _toTranslateLanguage(sourceLanguageCode);
    if (sourceLang == null) {
      throw UnsupportedError(
        'Translation from "$sourceLanguageCode" is not supported yet.',
      );
    }
    final targetLang = _toTranslateLanguage(targetLanguageCode);
    if (targetLang == null) {
      throw UnsupportedError(
        'Translation into "$targetLanguageCode" is not supported yet.',
      );
    }

    final modelManager = OnDeviceTranslatorModelManager();
    // Download both models if not already present (needs internet the
    // first time only; cached on-device afterwards).
    for (final lang in [sourceLang, targetLang]) {
      final isDownloaded = await modelManager.isModelDownloaded(
        _modelTag(lang),
      );
      if (!isDownloaded) {
        await modelManager.downloadModel(_modelTag(lang));
      }
    }

    final translator = OnDeviceTranslator(
      sourceLanguage: sourceLang,
      targetLanguage: targetLang,
    );
    try {
      final chunks = _splitIntoChunks(text);
      final translatedChunks = <String>[];
      for (final chunk in chunks) {
        // Blank/whitespace-only chunks would just come back empty (or
        // sometimes error) from the translator — keep them as-is to
        // preserve the document's original spacing.
        if (chunk.trim().isEmpty) {
          translatedChunks.add(chunk);
          continue;
        }
        translatedChunks.add(await translator.translateText(chunk));
      }
      return translatedChunks.join('\n');
    } catch (e) {
      debugPrint('Translation failed: $e');
      rethrow;
    } finally {
      await translator.close();
    }
  }

  /// Splits [text] into line-preserving chunks no longer than
  /// [_maxChunkChars] each, so every chunk stays safely inside the
  /// on-device translator's practical per-call length limit. Lines are
  /// never split mid-line — only grouped — so words are never cut in
  /// half across a chunk boundary.
  static List<String> _splitIntoChunks(String text) {
    final lines = text.split('\n');
    final chunks = <String>[];
    final buffer = StringBuffer();

    for (final line in lines) {
      final wouldBeLength =
          buffer.length + (buffer.isEmpty ? 0 : 1) + line.length;
      if (buffer.isNotEmpty && wouldBeLength > _maxChunkChars) {
        chunks.add(buffer.toString());
        buffer.clear();
      }
      if (buffer.isNotEmpty) buffer.write('\n');
      buffer.write(line);
    }
    if (buffer.isNotEmpty) chunks.add(buffer.toString());

    return chunks.isEmpty ? [text] : chunks;
  }

  /// Kept for anything still calling the old Tamil-only API — just a
  /// thin wrapper over [translateText] with the target fixed to Tamil.
  static Future<String> translateToTamil({
    required String text,
    required String sourceLanguageCode,
  }) =>
      translateText(
        text: text,
        sourceLanguageCode: sourceLanguageCode,
        targetLanguageCode: 'tamil',
      );

  static String _modelTag(TranslateLanguage lang) => lang.bcpCode;
}