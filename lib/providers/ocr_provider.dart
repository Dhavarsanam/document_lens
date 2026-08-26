import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:document_lens/services/notification_service.dart';
import 'package:document_lens/services/image_enhancement_service.dart';
import 'package:document_lens/services/tesseract_ocr_service.dart';
import 'package:document_lens/services/translation_service.dart';
import 'package:document_lens/services/groq_ocr_service.dart';
import 'package:document_lens/services/text_ordering_service.dart';
import 'package:document_lens/services/obstruction_checker_service.dart';
import 'package:document_lens/core/constants/app_constants.dart';
import 'dart:io';

enum OcrStatus { idle, picking, processing, done, error }
enum TranslationStatus { idle, translating, done, error }

/// On-device OCR using Google ML Kit for Latin, Chinese, Japanese, Korean,
/// and Devanagari scripts, plus Tesseract (offline, on-device) for Tamil —
/// ML Kit has no Tamil script recognizer, so Tamil is routed separately.
/// See [TesseractOcrService]. Optionally, Groq's cloud vision model is
/// tried first when the person has an API key configured — see
/// [GroqOcrService].
class OcrProvider extends ChangeNotifier {
  OcrStatus _status = OcrStatus.idle;
  String _extractedText = '';
  String _errorMessage = '';
  // ✅ True when the current _errorMessage came from the obstruction check
  // (finger/object covering the document) rather than a generic OCR
  // failure — lets the UI show a "Retake Photo" action instead of a
  // plain error snackbar.
  bool _isObstructionError = false;

  // ✅ FIX: this is now always the ORIGINAL color photo the user took/picked.
  // It is what gets shown, saved as the document image, and passed to
  // Image Enhancement — never the grayscale copy used internally for OCR.
  // Previously this field was overwritten with the grayscale-enhanced
  // version, which is why every scanned photo looked black & white.
  File? _selectedImage;

  // The language OCR actually ran in for the CURRENT scan — locked once
  // a scan completes. Changing the post-scan language selector no longer
  // re-runs OCR against this language; see _targetLanguage below.
  // ✅ FIX: default was 'latin' — an internal OCR-script name, not a real
  // selectable language (it's not even in AppConstants.supportedLanguages).
  // If someone scanned without picking a language first, _selectedLanguage
  // stayed 'latin' forever, and TranslationService had no mapping for it —
  // every translate attempt failed with "Translation from 'latin' is not
  // supported yet." 'english' is the real language 'latin' script defaults
  // to, so use that instead.
  String _selectedLanguage = 'english';
  bool _isBusy = false; // ✅ true while a TextRecognizer is actively running

  // Whether the MOST RECENT scan actually went through Groq's cloud
  // vision model (vs. on-device ML Kit/Tesseract). Used by the UI to show
  // which engine produced the current text — and because Groq only
  // engages when a key is set AND the call succeeds, this can be false
  // even with a key configured (e.g. it failed and fell back).
  bool _usedGroqForLastScan = false;

  // ✅ CHANGED BEHAVIOR: the post-scan language selector used to re-run
  // OCR against the same photo in a different script — which only ever
  // made sense if the photo genuinely contained that script. What people
  // actually wanted was: "show me this text in a different language" —
  // i.e. TRANSLATE it. _targetLanguage tracks that selection; '' means
  // "no translation requested, show the raw scan language".
  String _targetLanguage = '';

  // ✅ Optional translation of the extracted text into _targetLanguage
  // (or, via the dedicated Tamil card, into Tamil specifically). The
  // person can view either the original-language text or the
  // translation; both stay available side by side.
  String _translatedText = '';
  TranslationStatus _translationStatus = TranslationStatus.idle;
  String _translationError = '';
  bool _showTranslation = false;

  OcrStatus get status => _status;
  String get extractedText => _extractedText;
  String get errorMessage => _errorMessage;
  bool get isObstructionError => _isObstructionError;
  File? get selectedImage => _selectedImage;
  String get selectedLanguage => _selectedLanguage;
  // What language the result screen's language selector should show as
  // "currently selected" — the translation target if one is active,
  // otherwise the language the document was actually scanned in.
  String get targetLanguage =>
      _targetLanguage.isEmpty ? _selectedLanguage : _targetLanguage;
  String get translatedText => _translatedText;
  TranslationStatus get translationStatus => _translationStatus;
  String get translationError => _translationError;
  bool get showTranslation => _showTranslation;
  bool get usedGroqForLastScan => _usedGroqForLastScan;
  bool get hasGroqApiKey => GroqOcrService.hasApiKey;
  /// What the UI should currently display: a translation if one is ready
  /// (via the language selector or the dedicated Tamil card), otherwise
  /// the raw OCR text.
  String get displayText {
    if (_targetLanguage.isNotEmpty &&
        _targetLanguage != _selectedLanguage &&
        _translationStatus == TranslationStatus.done) {
      return _translatedText;
    }
    if (_showTranslation && _translationStatus == TranslationStatus.done) {
      return _translatedText;
    }
    return _extractedText;
  }

  final ImagePicker _picker = ImagePicker();

  /// Sets the OCR language BEFORE a scan (e.g. from a pre-scan language
  /// picker). If a photo was already scanned, this re-runs OCR against
  /// the new script — use [changeDisplayLanguage] instead for the
  /// post-scan "translate this text" selector.
  void setLanguage(String langCode) {
    if (_selectedLanguage == langCode) return;
    _selectedLanguage = langCode;
    // A fresh scan language invalidates any translation that was showing.
    _targetLanguage = '';
    _translatedText = '';
    _translationStatus = TranslationStatus.idle;
    _showTranslation = false;
    notifyListeners();

    // ✅ Skip if a recognizer is already running — starting a second
    // TextRecognizer before the first one closes is a known native
    // crash (ML Kit "multiple instances" bug) that force-closes the app.
    if (!_isBusy &&
        _selectedImage != null &&
        (_status == OcrStatus.done || _status == OcrStatus.error)) {
      _processImage();
    }
  }

  /// Post-scan "show this text in another language" — the language
  /// selector on the result screen calls this. Translates the ALREADY
  /// EXTRACTED text from the language it was scanned in into [langCode];
  /// never re-runs OCR or touches the camera/photo.
  Future<void> changeDisplayLanguage(String langCode) async {
    if (_extractedText.trim().isEmpty) return;
    if (_translationStatus == TranslationStatus.translating) return;

    _targetLanguage = langCode;
    _showTranslation = false; // the language-chip path takes precedence

    // Selecting the language the document was actually scanned in just
    // shows the raw OCR text — nothing to translate.
    if (langCode == _selectedLanguage) {
      _translationStatus = TranslationStatus.idle;
      _translatedText = '';
      _translationError = '';
      notifyListeners();
      return;
    }

    _translationStatus = TranslationStatus.translating;
    _translationError = '';
    notifyListeners();

    try {
      _translatedText = await TranslationService.translateText(
        text: _extractedText,
        sourceLanguageCode: _selectedLanguage,
        targetLanguageCode: langCode,
      );
      _translationStatus = TranslationStatus.done;
    } on UnsupportedError catch (e) {
      _translationStatus = TranslationStatus.error;
      _translationError =
          e.message ?? 'Translation into this language is not supported yet.';
    } catch (e) {
      _translationStatus = TranslationStatus.error;
      _translationError =
      'Translation failed. Check your internet connection and try again.';
    }
    notifyListeners();
  }

  Future<void> pickFromCamera() async {
    _status = OcrStatus.picking;
    notifyListeners();
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (photo != null) {
        // ✅ Keep the ORIGINAL color photo. Enhancement happens later,
        // only as a throwaway copy fed to the OCR engine (see
        // _processImage), never replacing what the user sees/saves.
        _selectedImage = File(photo.path);
        await _processImage();
      } else {
        _status = OcrStatus.idle;
        notifyListeners();
      }
    } catch (e) {
      _status = OcrStatus.error;
      _errorMessage = 'Camera error: $e';
      notifyListeners();
    }
  }

  Future<void> pickFromGallery() async {
    _status = OcrStatus.picking;
    notifyListeners();
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (image != null) {
        _selectedImage = File(image.path);
        await _processImage();
      } else {
        _status = OcrStatus.idle;
        notifyListeners();
      }
    } catch (e) {
      _status = OcrStatus.error;
      _errorMessage = 'Gallery error: $e';
      notifyListeners();
    }
  }

  // ✅ Camera Stabilizer use pannurom
  Future<void> processImageFromPath(String imagePath) async {
    _selectedImage = File(imagePath);
    _status = OcrStatus.processing;
    notifyListeners();
    await _processImage();
  }

  /// Auto-applies OCR-friendly preprocessing (grayscale + contrast/sharpen)
  /// to a THROWAWAY copy of the photo before running text recognition.
  /// Raw phone photos (uneven lighting, low contrast) hurt OCR accuracy if
  /// sent straight to ML Kit, so this pass exists purely to help the
  /// recognizer — it must never be what gets saved or shown to the user.
  /// ✅ Script-aware: Devanagari/Chinese/Japanese/Korean/Tamil use a GENTLER
  /// pass (no sharpen) — the full "Document Mode" contrast+sharpen combo
  /// distorts their fine strokes (matras, conjuncts, radicals) and causes
  /// misrecognition. Latin-based languages keep the stronger pass.
  /// Falls back to the original file if enhancement fails for any reason.
  Future<File> _enhanceForOcr(File original) async {
    const complexScripts = {'hindi', 'marathi', 'sanskrit', 'nepali',
      'chinese', 'japanese', 'korean', 'tamil'};
    try {
      final enhanced = complexScripts.contains(_selectedLanguage)
          ? await ImageEnhancementService.applyGentleDocumentMode(original)
          : await ImageEnhancementService.applyDocumentMode(original);
      return enhanced ?? original;
    } catch (e) {
      debugPrint('Pre-OCR enhance failed, using original photo: $e');
      return original;
    }
  }

  Future<void> _processImage() async {
    if (_selectedImage == null) return;
    // ✅ Never let two TextRecognizer instances run at once (native crash risk).
    if (_isBusy) return;
    _isBusy = true;

    _status = OcrStatus.processing;
    _errorMessage = '';
    _isObstructionError = false;
    // ✅ A previous translation belonged to the previous scan/language —
    // clear it so the UI doesn't show stale translated text next to new
    // OCR text.
    _targetLanguage = '';
    _translatedText = '';
    _translationStatus = TranslationStatus.idle;
    _translationError = '';
    _showTranslation = false;
    notifyListeners();

    try {
      // ✅ Block OCR outright if a finger/hand/other object is covering
      // part of the document — checked on the ORIGINAL color photo
      // (never the grayscale OCR-enhanced copy, which hides skin tone).
      // Every capture path (camera, gallery, Smart Stabilizer, Edge
      // Detection, Image Enhancement) funnels through _processImage, so
      // this one check covers all of them — Groq and on-device alike —
      // and a covered document never reaches either OCR engine.
      final obstruction =
      await ObstructionCheckerService.checkObstruction(_selectedImage!);
      if (obstruction.hasObstruction) {
        _status = OcrStatus.error;
        _isObstructionError = true;
        _errorMessage = '${obstruction.reason} '
            'Please retake the photo without anything covering the document.';
        notifyListeners();
        return;
      }

      // ✅ Groq cloud OCR (optional) — tried FIRST when the person has
      // an API key in Settings. Unlike ML Kit's script-only recognition,
      // this actually understands the target language, so switching
      // language on the result screen produces genuinely different/better
      // text. Uses the original color photo directly (an LLM vision model
      // doesn't need the grayscale/contrast pre-processing that classical
      // OCR engines do). Falls through to on-device OCR on any failure —
      // missing/invalid key, no internet, rate limit, etc.
      if (GroqOcrService.hasApiKey) {
        try {
          final languageName = _languageName(_selectedLanguage);
          _extractedText = await GroqOcrService.extractText(
            imageFile: _selectedImage!,
            languageName: languageName,
          );
          _usedGroqForLastScan = true;
          _status = OcrStatus.done;
          notifyListeners();
          _notifyScanComplete();
          return;
        } catch (e) {
          debugPrint('Groq OCR failed, falling back to on-device OCR: $e');
          // fall through to the on-device path below
        }
      }
      _usedGroqForLastScan = false;

      // ✅ FIX: enhance a fresh throwaway copy of the ORIGINAL photo every
      // time OCR runs (including on language switch), instead of mutating
      // _selectedImage. This is what actually feeds the recognizer;
      // _selectedImage (the color original) is untouched.
      final ocrImage = await _enhanceForOcr(_selectedImage!);

      // ✅ Tamil: ML Kit on-device has no Tamil script recognizer at all,
      // so route Tamil through Tesseract instead of TextRecognizer.
      if (_selectedLanguage == 'tamil') {
        _extractedText =
        await TesseractOcrService.extractTamilText(ocrImage.path);
      } else {
        final script = _getScript(_selectedLanguage);
        final textRecognizer = TextRecognizer(script: script);
        try {
          final inputImage = InputImage.fromFile(ocrImage);
          final recognizedText = await textRecognizer.processImage(inputImage);
          // ✅ Newspaper / brochure style multi-column pages: raw
          // recognizedText.text interleaves lines across columns and reads
          // like scrambled text. Re-order blocks column-by-column first.
          _extractedText =
              TextOrderingService.buildReadingOrderText(recognizedText);
        } finally {
          await textRecognizer.close();
        }
      }
      _status = OcrStatus.done;
      notifyListeners();
      // Pop-up reminder when the scan finishes (even if user navigated away).
      _notifyScanComplete();
      return;
    } catch (e) {
      _status = OcrStatus.error;
      _errorMessage = 'OCR processing failed: $e';
    } finally {
      _isBusy = false;
    }
    notifyListeners();
  }

  /// Maps a language code (as used throughout this app / AppConstants) to
  /// its display name, for the Groq OCR prompt ("this document is in ...").
  String _languageName(String code) {
    final match = AppConstants.supportedLanguages.firstWhere(
          (l) => l['code'] == code,
      orElse: () => {'name': code, 'code': code},
    );
    return match['name']!;
  }

  Future<void> _notifyScanComplete() async {
    try {
      final body = _extractedText.trim().isEmpty
          ? 'No readable text was found in the image.'
          : 'Your text is ready to view: "${_preview(_extractedText, 50)}"';
      await NotificationService.showNotification(
        id: 2001,
        title: '📄 Scan Complete — DOCMIND',
        body: body,
      );
    } catch (_) {
      // notifications are optional; ignore failures
    }
  }

  String _preview(String s, int max) {
    final cleaned = s.replaceAll('\n', ' ').trim();
    final runes = cleaned.runes.toList();
    if (runes.length <= max) return cleaned;
    return '${String.fromCharCodes(runes.take(max))}…';
  }

  /// Translates the current [extractedText] into Tamil, whatever language
  /// it was originally scanned in. Separate step from OCR — the person
  /// chooses to run this (or not) after seeing the scanned text. Kept
  /// alongside [changeDisplayLanguage] for the dedicated Tamil card on
  /// the result screen.
  Future<void> translateToTamil() async {
    if (_extractedText.trim().isEmpty) return;
    if (_translationStatus == TranslationStatus.translating) return;

    // This card's own translation, decoupled from the language selector.
    _targetLanguage = '';

    // Already Tamil — nothing to translate, just show as-is.
    if (_selectedLanguage == 'tamil') {
      _translatedText = _extractedText;
      _translationStatus = TranslationStatus.done;
      _showTranslation = true;
      notifyListeners();
      return;
    }

    _translationStatus = TranslationStatus.translating;
    _translationError = '';
    notifyListeners();

    try {
      _translatedText = await TranslationService.translateToTamil(
        text: _extractedText,
        sourceLanguageCode: _selectedLanguage,
      );
      _translationStatus = TranslationStatus.done;
      _showTranslation = true;
    } on UnsupportedError catch (e) {
      _translationStatus = TranslationStatus.error;
      _translationError = e.message ?? 'Translation not supported for this language.';
    } catch (e) {
      _translationStatus = TranslationStatus.error;
      _translationError = 'Translation failed. Check your internet connection and try again.';
    }
    notifyListeners();
  }

  /// Switches the result screen between the original scanned text and
  /// its Tamil translation (only meaningful once a translation is ready).
  void toggleShowTranslation(bool show) {
    _showTranslation = show;
    notifyListeners();
  }

  /// ML Kit on-device supports ONLY these 5 scripts.
  TextRecognitionScript _getScript(String code) {
    switch (code) {
      case 'chinese':
        return TextRecognitionScript.chinese;
      case 'japanese':
        return TextRecognitionScript.japanese;
      case 'korean':
        return TextRecognitionScript.korean;
      case 'hindi':
      case 'marathi':
      case 'sanskrit':
      case 'nepali':
        return TextRecognitionScript.devanagiri; // plugin spells it 'devanagiri'
      case 'english':
      case 'french':
      case 'german':
      case 'spanish':
      case 'latin':
      default:
        return TextRecognitionScript.latin;
    }
  }

  void reset() {
    _status = OcrStatus.idle;
    _extractedText = '';
    _errorMessage = '';
    _isObstructionError = false;
    _selectedImage = null;
    _usedGroqForLastScan = false;
    _targetLanguage = '';
    _translatedText = '';
    _translationStatus = TranslationStatus.idle;
    _translationError = '';
    _showTranslation = false;
    notifyListeners();
  }
}