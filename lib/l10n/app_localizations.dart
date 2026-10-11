import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('tr')
  ];

  /// No description provided for @appTitle.
  ///
  /// In de, this message translates to:
  /// **'Bestandsüberwachung'**
  String get appTitle;

  /// No description provided for @home.
  ///
  /// In de, this message translates to:
  /// **'Bestand'**
  String get home;

  /// No description provided for @shopping.
  ///
  /// In de, this message translates to:
  /// **'Nachbestellen'**
  String get shopping;

  /// No description provided for @notifications.
  ///
  /// In de, this message translates to:
  /// **'Kalibrierung'**
  String get notifications;

  /// No description provided for @account.
  ///
  /// In de, this message translates to:
  /// **'Konto'**
  String get account;

  /// No description provided for @inventoryMonitoring.
  ///
  /// In de, this message translates to:
  /// **'Bestandsüberwachung'**
  String get inventoryMonitoring;

  /// No description provided for @shoppingList.
  ///
  /// In de, this message translates to:
  /// **'Nachbestellliste'**
  String get shoppingList;

  /// No description provided for @save.
  ///
  /// In de, this message translates to:
  /// **'Speichern'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get cancel;

  /// No description provided for @add.
  ///
  /// In de, this message translates to:
  /// **'Hinzufügen'**
  String get add;

  /// No description provided for @addNewItem.
  ///
  /// In de, this message translates to:
  /// **'Produkt hinzufügen'**
  String get addNewItem;

  /// No description provided for @itemName.
  ///
  /// In de, this message translates to:
  /// **'Produktname'**
  String get itemName;

  /// No description provided for @error.
  ///
  /// In de, this message translates to:
  /// **'Fehler'**
  String get error;

  /// No description provided for @yourShoppingListIsEmpty.
  ///
  /// In de, this message translates to:
  /// **'Ihre Nachbestellliste ist leer.'**
  String get yourShoppingListIsEmpty;

  /// No description provided for @noProductsFound.
  ///
  /// In de, this message translates to:
  /// **'Keine Wiegeplattformen gefunden.'**
  String get noProductsFound;

  /// No description provided for @logOut.
  ///
  /// In de, this message translates to:
  /// **'Abmelden'**
  String get logOut;

  /// No description provided for @settings.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In de, this message translates to:
  /// **'Sprache'**
  String get language;

  /// No description provided for @login.
  ///
  /// In de, this message translates to:
  /// **'Anmelden'**
  String get login;

  /// No description provided for @register.
  ///
  /// In de, this message translates to:
  /// **'Registrieren'**
  String get register;

  /// No description provided for @email.
  ///
  /// In de, this message translates to:
  /// **'E-Mail'**
  String get email;

  /// No description provided for @password.
  ///
  /// In de, this message translates to:
  /// **'Passwort'**
  String get password;

  /// No description provided for @dontHaveAccount.
  ///
  /// In de, this message translates to:
  /// **'Sie haben noch kein Konto?'**
  String get dontHaveAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In de, this message translates to:
  /// **'Sie haben bereits ein Konto?'**
  String get alreadyHaveAccount;

  /// No description provided for @category.
  ///
  /// In de, this message translates to:
  /// **'Kategorie'**
  String get category;

  /// No description provided for @productSettings.
  ///
  /// In de, this message translates to:
  /// **'Produkteinstellungen'**
  String get productSettings;

  /// No description provided for @productName.
  ///
  /// In de, this message translates to:
  /// **'Produktname'**
  String get productName;

  /// No description provided for @unitWeight.
  ///
  /// In de, this message translates to:
  /// **'Stückgewicht'**
  String get unitWeight;

  /// No description provided for @unitWeightHint.
  ///
  /// In de, this message translates to:
  /// **'Bekanntes oder kalibriertes Gewicht eines Artikels'**
  String get unitWeightHint;

  /// No description provided for @minimumStockThreshold.
  ///
  /// In de, this message translates to:
  /// **'Mindestbestand'**
  String get minimumStockThreshold;

  /// No description provided for @optionalField.
  ///
  /// In de, this message translates to:
  /// **'Optional'**
  String get optionalField;

  /// No description provided for @invalidProductSettings.
  ///
  /// In de, this message translates to:
  /// **'Geben Sie Produktname, positives Stückgewicht und einen nicht negativen Grenzwert ein.'**
  String get invalidProductSettings;

  /// No description provided for @currentWeight.
  ///
  /// In de, this message translates to:
  /// **'Aktuelles Gewicht'**
  String get currentWeight;

  /// No description provided for @estimatedQuantity.
  ///
  /// In de, this message translates to:
  /// **'Geschätzte Stückzahl'**
  String get estimatedQuantity;

  /// No description provided for @stockStatus.
  ///
  /// In de, this message translates to:
  /// **'Bestandsstatus'**
  String get stockStatus;

  /// No description provided for @lowStock.
  ///
  /// In de, this message translates to:
  /// **'Niedriger Bestand'**
  String get lowStock;

  /// No description provided for @stockOk.
  ///
  /// In de, this message translates to:
  /// **'Bestand OK'**
  String get stockOk;

  /// No description provided for @thresholdNotConfigured.
  ///
  /// In de, this message translates to:
  /// **'Grenzwert nicht gesetzt'**
  String get thresholdNotConfigured;

  /// No description provided for @notConfigured.
  ///
  /// In de, this message translates to:
  /// **'Stückgewicht nicht gesetzt'**
  String get notConfigured;

  /// No description provided for @sensorCalibration.
  ///
  /// In de, this message translates to:
  /// **'Sensorkalibrierung'**
  String get sensorCalibration;

  /// No description provided for @emptyPlatforms.
  ///
  /// In de, this message translates to:
  /// **'Alle Wiegeplattformen leeren.'**
  String get emptyPlatforms;

  /// No description provided for @setZero.
  ///
  /// In de, this message translates to:
  /// **'Nullsetzen (Tara)'**
  String get setZero;

  /// No description provided for @place800gP1.
  ///
  /// In de, this message translates to:
  /// **'Legen Sie 800 g auf Plattform 1.'**
  String get place800gP1;

  /// No description provided for @place800gP2.
  ///
  /// In de, this message translates to:
  /// **'Legen Sie 800 g auf Plattform 2.'**
  String get place800gP2;

  /// No description provided for @calibrateP1.
  ///
  /// In de, this message translates to:
  /// **'Plattform 1 kalibrieren'**
  String get calibrateP1;

  /// No description provided for @calibrateP2.
  ///
  /// In de, this message translates to:
  /// **'Plattform 2 kalibrieren'**
  String get calibrateP2;

  /// No description provided for @calibrationComplete.
  ///
  /// In de, this message translates to:
  /// **'Kalibrierung erfolgreich abgeschlossen.'**
  String get calibrationComplete;

  /// No description provided for @startCalibration.
  ///
  /// In de, this message translates to:
  /// **'Kalibrierung starten'**
  String get startCalibration;

  /// No description provided for @appearance.
  ///
  /// In de, this message translates to:
  /// **'Darstellung'**
  String get appearance;

  /// No description provided for @theme.
  ///
  /// In de, this message translates to:
  /// **'Design'**
  String get theme;

  /// No description provided for @systemDefault.
  ///
  /// In de, this message translates to:
  /// **'Systemstandard'**
  String get systemDefault;

  /// No description provided for @lightTheme.
  ///
  /// In de, this message translates to:
  /// **'Hell'**
  String get lightTheme;

  /// No description provided for @darkTheme.
  ///
  /// In de, this message translates to:
  /// **'Dunkel'**
  String get darkTheme;

  /// No description provided for @categoryAutomotive.
  ///
  /// In de, this message translates to:
  /// **'Automobil'**
  String get categoryAutomotive;

  /// No description provided for @categoryElectronics.
  ///
  /// In de, this message translates to:
  /// **'Elektronik'**
  String get categoryElectronics;

  /// No description provided for @categoryHardware.
  ///
  /// In de, this message translates to:
  /// **'Werkzeug und Beschläge'**
  String get categoryHardware;

  /// No description provided for @categoryPackagedGoods.
  ///
  /// In de, this message translates to:
  /// **'Verpackte Waren'**
  String get categoryPackagedGoods;

  /// No description provided for @categoryCleaningSupplies.
  ///
  /// In de, this message translates to:
  /// **'Reinigungsmittel'**
  String get categoryCleaningSupplies;

  /// No description provided for @categoryOfficeSupplies.
  ///
  /// In de, this message translates to:
  /// **'Bürobedarf'**
  String get categoryOfficeSupplies;

  /// No description provided for @categoryOther.
  ///
  /// In de, this message translates to:
  /// **'Sonstiges'**
  String get categoryOther;

  /// No description provided for @activePlatforms.
  ///
  /// In de, this message translates to:
  /// **'Aktive Plattformen'**
  String get activePlatforms;

  /// No description provided for @lowStockProducts.
  ///
  /// In de, this message translates to:
  /// **'Niedriger Bestand'**
  String get lowStockProducts;

  /// No description provided for @staleSensors.
  ///
  /// In de, this message translates to:
  /// **'Veraltete Sensoren'**
  String get staleSensors;

  /// No description provided for @sensorDataStale.
  ///
  /// In de, this message translates to:
  /// **'Sensordaten sind veraltet'**
  String get sensorDataStale;

  /// No description provided for @lastSensorUpdate.
  ///
  /// In de, this message translates to:
  /// **'Letzte Sensoraktualisierung'**
  String get lastSensorUpdate;

  /// No description provided for @addToRestockingList.
  ///
  /// In de, this message translates to:
  /// **'Zur Nachbestellliste hinzufügen'**
  String get addToRestockingList;

  /// No description provided for @addedToRestockingList.
  ///
  /// In de, this message translates to:
  /// **'Zur Nachbestellliste hinzugefügt.'**
  String get addedToRestockingList;

  /// No description provided for @updateFailed.
  ///
  /// In de, this message translates to:
  /// **'Die Aktualisierung konnte nicht abgeschlossen werden. Bitte versuchen Sie es erneut.'**
  String get updateFailed;

  /// No description provided for @authInvalidCredentials.
  ///
  /// In de, this message translates to:
  /// **'E-Mail-Adresse oder Passwort ist falsch.'**
  String get authInvalidCredentials;

  /// No description provided for @authInvalidEmail.
  ///
  /// In de, this message translates to:
  /// **'Geben Sie eine gültige E-Mail-Adresse ein.'**
  String get authInvalidEmail;

  /// No description provided for @authWeakPassword.
  ///
  /// In de, this message translates to:
  /// **'Verwenden Sie ein Passwort mit mindestens 8 Zeichen.'**
  String get authWeakPassword;

  /// No description provided for @authRegistrationUnavailable.
  ///
  /// In de, this message translates to:
  /// **'Die Registrierung konnte nicht abgeschlossen werden. Versuchen Sie, sich anzumelden oder Ihr Passwort zurückzusetzen.'**
  String get authRegistrationUnavailable;

  /// No description provided for @authVerificationRequired.
  ///
  /// In de, this message translates to:
  /// **'Bestätigen Sie vor der Anmeldung Ihre E-Mail-Adresse. Eine neue Bestätigungs-E-Mail wurde angefordert.'**
  String get authVerificationRequired;

  /// No description provided for @authTooManyRequests.
  ///
  /// In de, this message translates to:
  /// **'Zu viele Versuche. Bitte warten Sie und versuchen Sie es erneut.'**
  String get authTooManyRequests;

  /// No description provided for @authNetworkError.
  ///
  /// In de, this message translates to:
  /// **'Prüfen Sie Ihre Internetverbindung und versuchen Sie es erneut.'**
  String get authNetworkError;

  /// No description provided for @authUnknownError.
  ///
  /// In de, this message translates to:
  /// **'Die Authentifizierung konnte nicht abgeschlossen werden. Bitte versuchen Sie es erneut.'**
  String get authUnknownError;

  /// No description provided for @registrationEmailSent.
  ///
  /// In de, this message translates to:
  /// **'Bestätigen Sie Ihr Konto über die E-Mail und melden Sie sich danach an.'**
  String get registrationEmailSent;

  /// No description provided for @noUser.
  ///
  /// In de, this message translates to:
  /// **'Kein Benutzer'**
  String get noUser;

  /// No description provided for @inventoryDeviceSetup.
  ///
  /// In de, this message translates to:
  /// **'Einrichtung des Inventargeräts'**
  String get inventoryDeviceSetup;

  /// No description provided for @linkWeighingPlatform.
  ///
  /// In de, this message translates to:
  /// **'ESP32-Wägeplattform verbinden'**
  String get linkWeighingPlatform;

  /// No description provided for @deviceSetup.
  ///
  /// In de, this message translates to:
  /// **'Geräteeinrichtung'**
  String get deviceSetup;

  /// No description provided for @readyToScan.
  ///
  /// In de, this message translates to:
  /// **'Bereit zum Scannen'**
  String get readyToScan;

  /// No description provided for @bluetoothOff.
  ///
  /// In de, this message translates to:
  /// **'Bluetooth ist ausgeschaltet'**
  String get bluetoothOff;

  /// No description provided for @noDevicesFound.
  ///
  /// In de, this message translates to:
  /// **'Keine Geräte gefunden. Versuchen Sie es erneut.'**
  String get noDevicesFound;

  /// No description provided for @selectDevice.
  ///
  /// In de, this message translates to:
  /// **'Wählen Sie Ihr Gerät'**
  String get selectDevice;

  /// No description provided for @missingBluetoothPermissions.
  ///
  /// In de, this message translates to:
  /// **'Bluetooth-Berechtigungen sind erforderlich.'**
  String get missingBluetoothPermissions;

  /// No description provided for @couldNotTurnOnBluetooth.
  ///
  /// In de, this message translates to:
  /// **'Bluetooth konnte nicht eingeschaltet werden.'**
  String get couldNotTurnOnBluetooth;

  /// No description provided for @turnOnBluetoothManually.
  ///
  /// In de, this message translates to:
  /// **'Schalten Sie Bluetooth ein, um fortzufahren.'**
  String get turnOnBluetoothManually;

  /// No description provided for @scanning.
  ///
  /// In de, this message translates to:
  /// **'Suche läuft...'**
  String get scanning;

  /// No description provided for @scanCouldNotStart.
  ///
  /// In de, this message translates to:
  /// **'Die Bluetooth-Suche konnte nicht gestartet werden.'**
  String get scanCouldNotStart;

  /// No description provided for @loginFirst.
  ///
  /// In de, this message translates to:
  /// **'Melden Sie sich zuerst an.'**
  String get loginFirst;

  /// No description provided for @connectingToDevice.
  ///
  /// In de, this message translates to:
  /// **'Verbindung mit {deviceName} wird hergestellt...'**
  String connectingToDevice(String deviceName);

  /// No description provided for @discoveringServices.
  ///
  /// In de, this message translates to:
  /// **'Dienste werden gesucht...'**
  String get discoveringServices;

  /// No description provided for @creatingSecureDeviceIdentity.
  ///
  /// In de, this message translates to:
  /// **'Sichere Geräteidentität wird erstellt...'**
  String get creatingSecureDeviceIdentity;

  /// No description provided for @sendingEncryptedCredentials.
  ///
  /// In de, this message translates to:
  /// **'Verschlüsselte Zugangsdaten werden gesendet...'**
  String get sendingEncryptedCredentials;

  /// No description provided for @setupSuccess.
  ///
  /// In de, this message translates to:
  /// **'Erfolgreich'**
  String get setupSuccess;

  /// No description provided for @setupCompleted.
  ///
  /// In de, this message translates to:
  /// **'Die Geräteeinrichtung wurde erfolgreich abgeschlossen.'**
  String get setupCompleted;

  /// No description provided for @ok.
  ///
  /// In de, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @secureSetupFailed.
  ///
  /// In de, this message translates to:
  /// **'Die sichere Einrichtung ist fehlgeschlagen. Prüfen Sie den Kopplungsmodus des Geräts.'**
  String get secureSetupFailed;

  /// No description provided for @devicesFound.
  ///
  /// In de, this message translates to:
  /// **'{count} Geräte gefunden'**
  String devicesFound(int count);

  /// No description provided for @unknownDevice.
  ///
  /// In de, this message translates to:
  /// **'Unbekanntes Gerät'**
  String get unknownDevice;

  /// No description provided for @signalStrength.
  ///
  /// In de, this message translates to:
  /// **'Signal: {rssi} dBm'**
  String signalStrength(int rssi);

  /// No description provided for @connect.
  ///
  /// In de, this message translates to:
  /// **'Verbinden'**
  String get connect;

  /// No description provided for @stopScanning.
  ///
  /// In de, this message translates to:
  /// **'Suche stoppen'**
  String get stopScanning;

  /// No description provided for @scanForDevices.
  ///
  /// In de, this message translates to:
  /// **'Nach Geräten suchen'**
  String get scanForDevices;

  /// No description provided for @checkingPermissions.
  ///
  /// In de, this message translates to:
  /// **'Berechtigungen werden geprüft...'**
  String get checkingPermissions;

  /// No description provided for @bluetoothPermissionDenied.
  ///
  /// In de, this message translates to:
  /// **'Die Bluetooth-Berechtigung wurde nicht erteilt.'**
  String get bluetoothPermissionDenied;

  /// No description provided for @searchingForDevice.
  ///
  /// In de, this message translates to:
  /// **'Gerät wird gesucht...'**
  String get searchingForDevice;

  /// No description provided for @inventoryDeviceNotFound.
  ///
  /// In de, this message translates to:
  /// **'Gerät nicht gefunden. Stellen Sie sicher, dass der ESP32 eingeschaltet ist.'**
  String get inventoryDeviceNotFound;

  /// No description provided for @connectingToInventoryDevice.
  ///
  /// In de, this message translates to:
  /// **'Verbindung zum Gerät wird hergestellt...'**
  String get connectingToInventoryDevice;

  /// No description provided for @discoveringBluetoothServices.
  ///
  /// In de, this message translates to:
  /// **'Bluetooth-Dienste werden gesucht...'**
  String get discoveringBluetoothServices;

  /// No description provided for @deviceReady.
  ///
  /// In de, this message translates to:
  /// **'Gerät bereit.'**
  String get deviceReady;

  /// No description provided for @writableCharacteristicNotFound.
  ///
  /// In de, this message translates to:
  /// **'Keine beschreibbare Geräteeigenschaft gefunden.'**
  String get writableCharacteristicNotFound;

  /// No description provided for @secureBluetoothConnectionFailed.
  ///
  /// In de, this message translates to:
  /// **'Eine sichere Bluetooth-Verbindung konnte nicht hergestellt werden.'**
  String get secureBluetoothConnectionFailed;

  /// No description provided for @commandSent.
  ///
  /// In de, this message translates to:
  /// **'Befehl gesendet.'**
  String get commandSent;

  /// No description provided for @commandCouldNotBeSent.
  ///
  /// In de, this message translates to:
  /// **'Der Befehl konnte nicht sicher gesendet werden.'**
  String get commandCouldNotBeSent;

  /// No description provided for @startCalibrationPrompt.
  ///
  /// In de, this message translates to:
  /// **'Drücken Sie die Taste, um die Kalibrierung zu starten.'**
  String get startCalibrationPrompt;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
