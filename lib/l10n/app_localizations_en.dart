// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Inventory Monitoring';

  @override
  String get home => 'Inventory';

  @override
  String get shopping => 'Restock';

  @override
  String get notifications => 'Calibration';

  @override
  String get account => 'Account';

  @override
  String get inventoryMonitoring => 'Inventory Monitoring';

  @override
  String get shoppingList => 'Restocking List';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get add => 'Add';

  @override
  String get addNewItem => 'Add Product';

  @override
  String get itemName => 'Product Name';

  @override
  String get error => 'Error';

  @override
  String get yourShoppingListIsEmpty => 'Your restocking list is empty.';

  @override
  String get noProductsFound => 'No weighing platforms found.';

  @override
  String get logOut => 'Log Out';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get login => 'Login';

  @override
  String get register => 'Register';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get dontHaveAccount => 'Don\'\'t have an account?';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get category => 'Category';

  @override
  String get productSettings => 'Product Settings';

  @override
  String get productName => 'Product Name';

  @override
  String get unitWeight => 'Unit Weight';

  @override
  String get unitWeightHint => 'Known or calibrated weight of one item';

  @override
  String get minimumStockThreshold => 'Minimum Stock Threshold';

  @override
  String get optionalField => 'Optional';

  @override
  String get invalidProductSettings =>
      'Enter a product name, a positive unit weight, and a non-negative threshold.';

  @override
  String get currentWeight => 'Current Weight';

  @override
  String get estimatedQuantity => 'Estimated Quantity';

  @override
  String get stockStatus => 'Stock Status';

  @override
  String get lowStock => 'Low Stock';

  @override
  String get stockOk => 'Stock OK';

  @override
  String get thresholdNotConfigured => 'Threshold not set';

  @override
  String get notConfigured => 'Unit weight not set';

  @override
  String get sensorCalibration => 'Sensor Calibration';

  @override
  String get emptyPlatforms => 'Clear all weighing platforms.';

  @override
  String get setZero => 'Set Zero (Tare)';

  @override
  String get place800gP1 => 'Place 800 g on Platform 1.';

  @override
  String get place800gP2 => 'Place 800 g on Platform 2.';

  @override
  String get calibrateP1 => 'Calibrate Platform 1';

  @override
  String get calibrateP2 => 'Calibrate Platform 2';

  @override
  String get calibrationComplete => 'Calibration completed successfully.';

  @override
  String get startCalibration => 'Start Calibration';

  @override
  String get appearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get systemDefault => 'System default';

  @override
  String get lightTheme => 'Light';

  @override
  String get darkTheme => 'Dark';

  @override
  String get categoryAutomotive => 'Automotive';

  @override
  String get categoryElectronics => 'Electronics';

  @override
  String get categoryHardware => 'Hardware';

  @override
  String get categoryPackagedGoods => 'Packaged Goods';

  @override
  String get categoryCleaningSupplies => 'Cleaning Supplies';

  @override
  String get categoryOfficeSupplies => 'Office Supplies';

  @override
  String get categoryOther => 'Other';

  @override
  String get activePlatforms => 'Active platforms';

  @override
  String get lowStockProducts => 'Low stock';

  @override
  String get staleSensors => 'Stale sensors';

  @override
  String get sensorDataStale => 'Sensor data is stale';

  @override
  String get lastSensorUpdate => 'Last sensor update';

  @override
  String get addToRestockingList => 'Add to restocking list';

  @override
  String get addedToRestockingList => 'Added to the restocking list.';

  @override
  String get updateFailed =>
      'The update could not be completed. Please try again.';

  @override
  String get authInvalidCredentials => 'Email or password is incorrect.';

  @override
  String get authInvalidEmail => 'Enter a valid email address.';

  @override
  String get authWeakPassword => 'Use a password with at least 8 characters.';

  @override
  String get authRegistrationUnavailable =>
      'Registration could not be completed. Try signing in or resetting your password.';

  @override
  String get authVerificationRequired =>
      'Verify your email before signing in. A new verification email was requested.';

  @override
  String get authTooManyRequests =>
      'Too many attempts. Please wait and try again.';

  @override
  String get authNetworkError =>
      'Check your internet connection and try again.';

  @override
  String get authUnknownError =>
      'Authentication could not be completed. Please try again.';

  @override
  String get registrationEmailSent =>
      'Check your email to verify your account, then sign in.';

  @override
  String get noUser => 'No user';

  @override
  String get inventoryDeviceSetup => 'Inventory Device Setup';

  @override
  String get linkWeighingPlatform => 'Link ESP32 weighing platform';

  @override
  String get deviceSetup => 'Device Setup';

  @override
  String get readyToScan => 'Ready to scan';

  @override
  String get bluetoothOff => 'Bluetooth is off';

  @override
  String get noDevicesFound => 'No devices found. Try again.';

  @override
  String get selectDevice => 'Select your device';

  @override
  String get missingBluetoothPermissions =>
      'Bluetooth permissions are required.';

  @override
  String get couldNotTurnOnBluetooth => 'Bluetooth could not be turned on.';

  @override
  String get turnOnBluetoothManually => 'Turn on Bluetooth to continue.';

  @override
  String get scanning => 'Scanning...';

  @override
  String get scanCouldNotStart => 'Bluetooth scan could not be started.';

  @override
  String get loginFirst => 'Sign in first.';

  @override
  String connectingToDevice(String deviceName) {
    return 'Connecting to $deviceName...';
  }

  @override
  String get discoveringServices => 'Discovering services...';

  @override
  String get creatingSecureDeviceIdentity =>
      'Creating secure device identity...';

  @override
  String get sendingEncryptedCredentials => 'Sending encrypted credentials...';

  @override
  String get setupSuccess => 'Success';

  @override
  String get setupCompleted => 'Device setup completed successfully.';

  @override
  String get ok => 'OK';

  @override
  String get secureSetupFailed =>
      'Secure setup failed. Confirm the device is in pairing mode.';

  @override
  String devicesFound(int count) {
    return '$count devices found';
  }

  @override
  String get unknownDevice => 'Unknown device';

  @override
  String signalStrength(int rssi) {
    return 'Signal: $rssi dBm';
  }

  @override
  String get connect => 'Connect';

  @override
  String get stopScanning => 'Stop scanning';

  @override
  String get scanForDevices => 'Scan for devices';

  @override
  String get checkingPermissions => 'Checking permissions...';

  @override
  String get bluetoothPermissionDenied =>
      'Bluetooth permission was not granted.';

  @override
  String get searchingForDevice => 'Searching for device...';

  @override
  String get inventoryDeviceNotFound =>
      'Device not found. Make sure the ESP32 is turned on.';

  @override
  String get connectingToInventoryDevice => 'Connecting to device...';

  @override
  String get discoveringBluetoothServices =>
      'Discovering Bluetooth services...';

  @override
  String get deviceReady => 'Device ready.';

  @override
  String get writableCharacteristicNotFound =>
      'A writable device characteristic was not found.';

  @override
  String get secureBluetoothConnectionFailed =>
      'A secure Bluetooth connection could not be established.';

  @override
  String get commandSent => 'Command sent.';

  @override
  String get commandCouldNotBeSent => 'The command could not be sent securely.';

  @override
  String get startCalibrationPrompt => 'Press the button to start calibration.';
}
