import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';

/// Lightweight wrapper around the 'settings' Hive box for simple
/// persisted preferences that don't need their own model/provider.
class SettingsService {
  static const String _box = 'settings';
  static const String _appLockKey = 'app_lock_enabled';
  static const String _groqApiKeyKey = 'groq_api_key';

  static bool get appLockEnabled {
    try {
      return Hive.box(_box).get(_appLockKey, defaultValue: false) as bool;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setAppLockEnabled(bool enabled) async {
    try {
      await Hive.box(_box).put(_appLockKey, enabled);
    } catch (_) {
      // Ignore persistence errors; toggle will simply not persist.
    }
  }

  // ✅ Groq API key — used by GroqOcrService to route OCR through Groq's
  // cloud vision model instead of on-device ML Kit/Tesseract, whenever a
  // key is present. Stored locally only (Hive box on-device); never synced
  // to Firestore or anywhere else.
  static String? get groqApiKey {
    try {
      return Hive.box(_box).get(_groqApiKeyKey) as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<void> setGroqApiKey(String key) async {
    try {
      await Hive.box(_box).put(_groqApiKeyKey, key.trim());
    } catch (_) {
      // Ignore persistence errors; key will simply not persist.
    }
  }

  static Future<void> clearGroqApiKey() async {
    try {
      await Hive.box(_box).delete(_groqApiKeyKey);
    } catch (_) {}
  }
}