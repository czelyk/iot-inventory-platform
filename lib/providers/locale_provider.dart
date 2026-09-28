import 'package:flutter/material.dart';
import 'package:smart_kuhlschrank/services/auth_service.dart';

class LocaleProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  Locale? _locale;

  Locale? get locale => _locale;

  /// Sets the app's locale and saves the preference to Firebase.
  Future<void> setLocale(Locale locale) async {
    if (_locale != locale) {
      _locale = locale;
      notifyListeners();
      await _authService.saveLanguagePreference(locale.languageCode);
    }
  }

  /// Loads the user's preferred locale from Firebase.
  /// If no preference is found, it does nothing, leaving the default device locale.
  Future<void> loadLocale() async {
    final languageCode = await _authService.getLanguagePreference();
    if (languageCode != null && languageCode.isNotEmpty) {
      _locale = Locale(languageCode);
      notifyListeners();
    }
  }
}
