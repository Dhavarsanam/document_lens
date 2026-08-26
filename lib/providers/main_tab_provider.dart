import 'package:flutter/foundation.dart';

/// Allows any screen to request a tab switch on the MainWrapper's
/// bottom navigation, without needing to push a new route.
///
/// Tab indices: 0 = Home, 1 = Insights, 2 = History, 3 = Settings
class MainTabProvider extends ChangeNotifier {
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  void goToTab(int index) {
    if (_currentIndex == index) return;
    _currentIndex = index;
    notifyListeners();
  }

  // Convenience helpers for readability at call sites
  void goToHome() => goToTab(0);
  void goToInsights() => goToTab(1);
  void goToHistory() => goToTab(2);
  void goToSettings() => goToTab(3);
}