import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

enum AppThemeMode {
  system,    // Follow system
  light,     // Always light
  dark,      // Always dark
  moodBased, // Auto change based on time
}

class ThemeProvider extends ChangeNotifier {
  static const String _boxKey = 'settings';
  static const String _themeKey = 'isDark';
  static const String _themeModeKey = 'themeMode';

  bool _isDark = false;
  AppThemeMode _appThemeMode = AppThemeMode.light;

  bool get isDark => _isDark;
  AppThemeMode get appThemeMode => _appThemeMode;

  ThemeMode get themeMode {
    switch (_appThemeMode) {
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.moodBased:
        return _isDark ? ThemeMode.dark : ThemeMode.light;
    }
  }

  // Mood info for display
  MoodInfo get currentMood => _getMoodInfo();

  ThemeProvider() {
    _loadTheme();
    _startMoodTimer();
  }

  void _loadTheme() {
    final box = Hive.box(_boxKey);
    _isDark = box.get(_themeKey, defaultValue: false);
    final modeIndex = box.get(_themeModeKey, defaultValue: 1);
    _appThemeMode = AppThemeMode.values[modeIndex];
    if (_appThemeMode == AppThemeMode.moodBased) {
      _applyMoodTheme();
    }
    notifyListeners();
  }

  // ✅ Timer — every 30 mins mood check pannurom
  void _startMoodTimer() {
    Future.delayed(const Duration(minutes: 30), () {
      if (_appThemeMode == AppThemeMode.moodBased) {
        _applyMoodTheme();
      }
      _startMoodTimer(); // recursive
    });
  }

  // ✅ Apply theme based on time
  void _applyMoodTheme() {
    final hour = DateTime.now().hour;
    bool shouldBeDark;

    if (hour >= 6 && hour < 12) {
      shouldBeDark = false; // Morning - Light
    } else if (hour >= 12 && hour < 17) {
      shouldBeDark = false; // Afternoon - Light warm
    } else if (hour >= 17 && hour < 20) {
      shouldBeDark = false; // Evening - Light orange
    } else {
      shouldBeDark = true; // Night - Dark
    }

    if (_isDark != shouldBeDark) {
      _isDark = shouldBeDark;
      notifyListeners();
    }
  }

  // Toggle simple dark/light
  void toggleTheme() {
    _isDark = !_isDark;
    _appThemeMode = _isDark ? AppThemeMode.dark : AppThemeMode.light;
    _saveTheme();
    notifyListeners();
  }

  // Set specific mode
  void setThemeMode(AppThemeMode mode) {
    _appThemeMode = mode;
    if (mode == AppThemeMode.moodBased) {
      _applyMoodTheme();
    } else if (mode == AppThemeMode.dark) {
      _isDark = true;
    } else if (mode == AppThemeMode.light) {
      _isDark = false;
    }
    _saveTheme();
    notifyListeners();
  }

  void _saveTheme() {
    final box = Hive.box(_boxKey);
    box.put(_themeKey, _isDark);
    box.put(_themeModeKey, _appThemeMode.index);
  }

  // ✅ Get mood info for UI display
  MoodInfo _getMoodInfo() {
    final hour = DateTime.now().hour;

    if (hour >= 6 && hour < 12) {
      return MoodInfo(
        name: 'Morning',
        emoji: '☀️',
        description: 'Light theme — Fresh start!',
        color: const Color(0xFF1A73E8),
        timeRange: '6 AM - 12 PM',
      );
    } else if (hour >= 12 && hour < 17) {
      return MoodInfo(
        name: 'Afternoon',
        emoji: '🌤️',
        description: 'Light warm theme — Stay productive!',
        color: const Color(0xFFF57C00),
        timeRange: '12 PM - 5 PM',
      );
    } else if (hour >= 17 && hour < 20) {
      return MoodInfo(
        name: 'Evening',
        emoji: '🌅',
        description: 'Sunset theme — Wind down!',
        color: const Color(0xFFE64A19),
        timeRange: '5 PM - 8 PM',
      );
    } else {
      return MoodInfo(
        name: 'Night',
        emoji: '🌙',
        description: 'Dark blue theme — Rest mode!',
        color: const Color(0xFF1A237E),
        timeRange: '8 PM - 6 AM',
      );
    }
  }
}

// Mood data class
class MoodInfo {
  final String name;
  final String emoji;
  final String description;
  final Color color;
  final String timeRange;

  MoodInfo({
    required this.name,
    required this.emoji,
    required this.description,
    required this.color,
    required this.timeRange,
  });
}