import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// Generated localization output is checked in because the app imports it
// directly. Run `flutter gen-l10n` after editing the ARB source files.
abstract class AppLocalizations {
  const AppLocalizations(this.localeName);

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  String get appTitle;
  String get home;
  String get shopping;
  String get notifications;
  String get account;
  String get inventoryMonitoring;
  String get shoppingList;
  String get save;
  String get cancel;
  String get add;
  String get addNewItem;
  String get itemName;
  String get error;
  String get yourShoppingListIsEmpty;
  String get noProductsFound;
  String get logOut;
  String get settings;
  String get language;
  String get login;
  String get register;
  String get email;
  String get password;
  String get dontHaveAccount;
  String get alreadyHaveAccount;
  String get category;
  String get productSettings;
  String get productName;
  String get unitWeight;
  String get unitWeightHint;
  String get minimumStockThreshold;
  String get optionalField;
  String get invalidProductSettings;
  String get currentWeight;
  String get estimatedQuantity;
  String get stockStatus;
  String get lowStock;
  String get stockOk;
  String get thresholdNotConfigured;
  String get notConfigured;
  String get sensorCalibration;
  String get emptyPlatforms;
  String get setZero;
  String get place800gP1;
  String get place800gP2;
  String get calibrateP1;
  String get calibrateP2;
  String get calibrationComplete;
  String get startCalibration;
  String get appearance;
  String get theme;
  String get systemDefault;
  String get lightTheme;
  String get darkTheme;
  String get categoryAutomotive;
  String get categoryElectronics;
  String get categoryHardware;
  String get categoryPackagedGoods;
  String get categoryCleaningSupplies;
  String get categoryOfficeSupplies;
  String get categoryOther;
  String get activePlatforms;
  String get lowStockProducts;
  String get staleSensors;
  String get sensorDataStale;
  String get lastSensorUpdate;
  String get addToRestockingList;
  String get addedToRestockingList;
  String get updateFailed;
  String get authInvalidCredentials;
  String get authInvalidEmail;
  String get authWeakPassword;
  String get authRegistrationUnavailable;
  String get authVerificationRequired;
  String get authTooManyRequests;
  String get authNetworkError;
  String get authUnknownError;
  String get registrationEmailSent;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) {
    return const {'de', 'en', 'tr'}.contains(locale.languageCode);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  switch (locale.languageCode) {
    case 'de':
      return const AppLocalizationsDe();
    case 'en':
      return const AppLocalizationsEn();
    case 'tr':
      return const AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate does not support locale "$locale".',
  );
}
