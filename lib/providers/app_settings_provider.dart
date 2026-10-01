import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  AppSettingsProvider() {
    _loadSettings();
  }

  // Ayarları telefondan yükle
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Temayı yükle
    final themeIndex = prefs.getInt(_themeKey) ?? ThemeMode.system.index;
    _themeMode = themeIndex >= 0 && themeIndex < ThemeMode.values.length
        ? ThemeMode.values[themeIndex]
        : ThemeMode.system;
    
    notifyListeners();
  }

  // Tema modunu ayarla ve telefona kaydet
  Future<void> setThemeMode(ThemeMode? mode) async {
    if (mode == null || _themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
  }

  // Bildirim gün sayısını ayarla ve telefona kaydet
}
