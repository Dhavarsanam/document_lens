import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:document_lens/services/settings_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// OCR via Groq's cloud vision model, used instead of the on-device
/// ML Kit/Tesseract path whenever the person has set a Groq API key in
/// Settings (get a free key at https://console.groq.com/keys).
///
/// Why this exists: ML Kit only ships 5 on-device SCRIPT recognizers
/// (Latin, Chinese, Japanese, Korean, Devanagari) — English, French,
/// German, and Spanish all map to the SAME Latin-script recognizer, so
/// switching "language" on the result screen re-runs OCR but produces
/// near-identical output, since ML Kit reads characters, not language
/// grammar. Groq's vision model actually understands the target language
/// and extracts text accordingly, so switching language produces
/// genuinely different, language-aware results.
class GroqOcrService {
  static const String _endpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  // ✅ Current Groq vision-capable model (Aug 2026). Groq's multimodal
  // lineup changes over time — check https://console.groq.com/docs/vision
  // if this ever needs updating.
  static const String _model = 'qwen/qwen3.6-27b';

  static String? get _apiKey => SettingsService.groqApiKey;

  static bool get hasApiKey {
    final key = _apiKey;
    return key != null && key.trim().isNotEmpty;
  }

  /// Extracts text from [imageFile], asking the model to read it as
  /// [languageName]. Throws a plain [Exception] with a user-facing message
  /// on any failure (missing key, network error, non-200 response, timeout,
  /// etc.) — callers should catch this and fall back to on-device OCR.
  static Future<String> extractText({
    required File imageFile,
    required String languageName,
  }) async {
    final apiKey = _apiKey;
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw Exception('No Groq API key set. Add one in Settings.');
    }

    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);
    final ext = imageFile.path.split('.').last.toLowerCase();
    final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';

    final prompt = 'This image contains a document written in '
        '$languageName. Extract ALL visible text exactly as written, '
        'preserving line breaks and layout as closely as possible. '
        'Output ONLY the extracted text — no commentary, no translation, '
        'no markdown formatting, no code fences. If there is no readable '
        'text in the image, output nothing.';

    late final http.Response response;
    try {
      response = await http
          .post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': prompt},
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:$mimeType;base64,$base64Image',
                  },
                },
              ],
            },
          ],
          'temperature': 0.1,
          'max_completion_tokens': 4096,
        }),
      )
          .timeout(const Duration(seconds: 45));
    } catch (e) {
      throw Exception('Could not reach Groq (check your internet): $e');
    }

    if (response.statusCode != 200) {
      String detail = response.body;
      try {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        detail = decoded['error']?['message']?.toString() ?? detail;
      } catch (_) {
        // response body wasn't JSON — use it as-is
      }
      if (response.statusCode == 401) {
        throw Exception('Groq API key is invalid. Check it in Settings.');
      }
      if (response.statusCode == 429) {
        throw Exception('Groq rate limit hit — try again shortly.');
      }
      throw Exception('Groq OCR failed (${response.statusCode}): $detail');
    }

    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Groq returned an unreadable response: $e');
    }

    final choices = decoded['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('Groq OCR returned no result.');
    }
    final message = choices.first['message'] as Map<String, dynamic>?;
    final content = (message?['content'] as String? ?? '').trim();
    return content;
  }
}