import 'package:flutter/material.dart';

import 'main.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = true;

  bool get isDarkMode => _isDarkMode;

  void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }
  void setDarkMode(value) {
    _isDarkMode = value;
    notifyListeners();
  }
}

final themeProvider = ThemeProvider();
