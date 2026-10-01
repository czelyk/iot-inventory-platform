import 'package:flutter/material.dart';
import 'package:smart_kuhlschrank/services/auth_service.dart';

class LocaleProvider with ChangeNotifier {
  static const Set<String> _supportedLanguageCodes = {'de', 'en', 'tr'};

  final AuthService _authService = AuthService();
  Locale? _locale;

  Locale? get locale => _locale;

  /// Sets the app's locale and saves the preference to Firebase.
  Future<void> setLocale(Locale locale) async {
    if (!_supportedLanguageCodes.contains(locale.languageCode)) return;
    final normalizedLocale = Locale(locale.languageCode);
    if (_locale != normalizedLocale) {
      _locale = normalizedLocale;
      notifyListeners();
      try {
        await _authService.saveLanguagePreference(locale.languageCode);
      } catch (_) {
        // Keep the selected locale locally when the device is offline.
      }
    }
  }

  /// Loads the user's preferred locale from Firebase.
  /// If no preference is found, it does nothing, leaving the default device locale.
  Future<void> loadLocale() async {
    try {
      final languageCode = await _authService.getLanguagePreference();
      final nextLocale = _supportedLanguageCodes.contains(languageCode)
          ? Locale(languageCode!)
          : null;
      if (_locale != nextLocale) {
        _locale = nextLocale;
        notifyListeners();
      }
    } catch (_) {
      // Retain the current locale if the remote preference is unavailable.
    }
  }

  void clearLocale() {
    if (_locale != null) {
      _locale = null;
      notifyListeners();
    }
  }
}
