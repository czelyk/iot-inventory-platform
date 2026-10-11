import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../l10n/app_localizations.dart';
import '../services/device_provisioning_service.dart';

class BluetoothSetupScreen extends StatefulWidget {
  const BluetoothSetupScreen({super.key});

  @override
  State<BluetoothSetupScreen> createState() => _BluetoothSetupScreenState();
}

class _BluetoothSetupScreenState extends State<BluetoothSetupScreen> {
  static const String _serviceUuid = '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';
  static const String _writeUuid = '6E400002-B5A3-F393-E0A9-E50E24DCCA9E';
  static const String _identityUuid = '6E400003-B5A3-F393-E0A9-E50E24DCCA9E';
  static const Set<String> _supportedDeviceNames = {
    'Inventory Platform ESP32',
    // Backward compatibility for devices that have not received new firmware.
    'Smart Fridge ESP32',
  };

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DeviceProvisioningService _provisioningService =
      DeviceProvisioningService();
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  bool _isConnecting = false;
  _SetupStatus _status = _SetupStatus.readyToScan;
  String _connectingDeviceName = '';
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  StreamSubscription<bool>? _isScanningSubscription;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.off) {
        if (mounted) setState(() => _status = _SetupStatus.bluetoothOff);
      }
    });
    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (mounted) setState(() => _scanResults = results);
    });
    _isScanningSubscription = FlutterBluePlus.isScanning.listen((isScanning) {
      if (!mounted) return;
      setState(() {
        _isScanning = isScanning;
        if (!isScanning) {
          _status = _scanResults.isEmpty
              ? _SetupStatus.noDevicesFound
              : _SetupStatus.selectDevice;
        }
      });
    });
  }

  // EN KRİTİK FONKSİYON: İZİNLER
  Future<bool> _requestPermissions() async {
    if (_isAndroid) {
      // Android 12 ve üzeri için (API 31+)
      if (await Permission.bluetoothScan.status.isDenied ||
          await Permission.bluetoothConnect.status.isDenied) {
        Map<Permission, PermissionStatus> statuses = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.location, // Bazı cihazlar için hala gerekli
        ].request();

        if (statuses[Permission.bluetoothScan]!.isDenied ||
            statuses[Permission.bluetoothConnect]!.isDenied) {
          return false; // İzin verilmedi
        }
      }
    }
    return true;
  }

  Future<void> _startScan() async {
    // 1. İzinleri Kontrol Et
    bool hasPermissions = await _requestPermissions();
    if (!mounted) return;
    if (!hasPermissions) {
      setState(() => _status = _SetupStatus.missingPermissions);
      return;
    }

    // 2. Bluetooth Açık mı?
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      if (_isAndroid) {
        try {
          await FlutterBluePlus.turnOn();
        } catch (e) {
          if (!mounted) return;
          setState(() => _status = _SetupStatus.couldNotTurnOnBluetooth);
          return;
        }
      } else {
        setState(() => _status = _SetupStatus.turnOnBluetoothManually);
        return;
      }
    }

    setState(() {
      _isScanning = true;
      _scanResults.clear();
      _status = _SetupStatus.scanning;
    });

    try {
      // 3. TARAMA BAŞLAT (Filtresiz ve Düşük Gecikmeli)
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: false,
      );
    } catch (_) {
      setState(() {
        _status = _SetupStatus.scanCouldNotStart;
        _isScanning = false;
      });
    }
  }

  Future<void> _connectAndSendUid(BluetoothDevice device) async {
    final l10n = AppLocalizations.of(context)!;
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.loginFirst)),
      );
      return;
    }

    setState(() {
      _isConnecting = true;
      _connectingDeviceName = device.platformName.isEmpty
          ? l10n.unknownDevice
          : device.platformName;
      _status = _SetupStatus.connecting;
    });

    try {
      // Bağlan
      await device.connect(
          autoConnect: false); // autoConnect: false daha hızlıdır
      if (_isAndroid) await device.requestMtu(512);

      if (!mounted) return;
      setState(() => _status = _SetupStatus.discoveringServices);
      final services = await device.discoverServices();
      final expectedService = services.where(
        (service) => service.uuid.toString().toUpperCase() == _serviceUuid,
      );
      if (expectedService.length != 1) {
        throw const DeviceProvisioningException('invalid-device');
      }
      final characteristics = expectedService.single.characteristics;
      final writeMatches = characteristics.where(
        (characteristic) =>
            characteristic.uuid.toString().toUpperCase() == _writeUuid &&
            characteristic.properties.write,
      );
      final identityMatches = characteristics.where(
        (characteristic) =>
            characteristic.uuid.toString().toUpperCase() == _identityUuid &&
            characteristic.properties.read,
      );
      if (writeMatches.length != 1 || identityMatches.length != 1) {
        throw const DeviceProvisioningException('invalid-device');
      }

      final identityValue = utf8.decode(
        await identityMatches.single.read(),
        allowMalformed: false,
      );
      final identity =
          RegExp(r'^DEVICE:([A-F0-9]{32})$').firstMatch(identityValue.trim());
      if (identity == null) {
        throw const DeviceProvisioningException('invalid-device');
      }

      if (mounted) {
        setState(() => _status = _SetupStatus.creatingSecureDeviceIdentity);
      }
      final credentials = await _provisioningService.provision(
        identity.group(1)!,
      );
      final payload = utf8.encode(credentials.provisioningCommand);
      if (payload.length > 500) {
        throw const DeviceProvisioningException('invalid-response');
      }

      if (!mounted) return;
      setState(() => _status = _SetupStatus.sendingEncryptedCredentials);
      await writeMatches.single.write(payload, withoutResponse: false);

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.setupSuccess),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 50),
                const SizedBox(height: 10),
                Text(l10n.setupCompleted),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                },
                child: Text(l10n.ok),
              ),
            ],
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _status = _SetupStatus.secureSetupFailed);
      }
    } finally {
      try {
        await device.disconnect();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _adapterStateSubscription?.cancel();
    _scanResultsSubscription?.cancel();
    _isScanningSubscription?.cancel();
    if (_isScanning) unawaited(FlutterBluePlus.stopScan());
    _provisioningService.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.deviceSetup)),
      body: Column(
        children: [
          // Durum Paneli
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            color: Colors.teal.shade50,
            child: Column(
              children: [
                if (_isScanning) const LinearProgressIndicator(),
                const SizedBox(height: 10),
                Text(
                  _statusText(l10n),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                if (_scanResults.isNotEmpty)
                  Text(
                    l10n.devicesFound(_scanResults.length),
                    style: const TextStyle(color: Colors.grey),
                  ),
              ],
            ),
          ),

          // Cihaz Listesi
          Expanded(
            child: ListView.builder(
              itemCount: _scanResults.length,
              itemBuilder: (context, index) {
                final result = _scanResults[index];
                final name = result.device.platformName.isNotEmpty
                    ? result.device.platformName
                    : result.advertisementData.advName;
                final id = result.device.remoteId.toString();
                final rssi = result.rssi;
                final isSupported = _supportedDeviceNames.contains(name);

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.teal,
                      child: Icon(Icons.bluetooth, color: Colors.white),
                    ),
                    title: Text(name.isNotEmpty ? name : l10n.unknownDevice,
                        style: TextStyle(
                            fontWeight: name.isNotEmpty
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSupported ? Colors.green : Colors.black)),
                    subtitle: Text("$id\n${l10n.signalStrength(rssi)}"),
                    trailing: ElevatedButton(
                      onPressed: _isConnecting || !isSupported
                          ? null
                          : () => _connectAndSendUid(result.device),
                      style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isSupported ? Colors.green : Colors.teal,
                          foregroundColor: Colors.white),
                      child: Text(l10n.connect),
                    ),
                  ),
                );
              },
            ),
          ),

          // Tarama Butonu
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                icon: _isScanning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.search),
                label: Text(
                  _isScanning ? l10n.stopScanning : l10n.scanForDevices,
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isScanning ? Colors.redAccent : Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  if (_isScanning) {
                    FlutterBluePlus.stopScan();
                  } else {
                    _startScan();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _statusText(AppLocalizations l10n) {
    return switch (_status) {
      _SetupStatus.readyToScan => l10n.readyToScan,
      _SetupStatus.bluetoothOff => l10n.bluetoothOff,
      _SetupStatus.noDevicesFound => l10n.noDevicesFound,
      _SetupStatus.selectDevice => l10n.selectDevice,
      _SetupStatus.missingPermissions => l10n.missingBluetoothPermissions,
      _SetupStatus.couldNotTurnOnBluetooth => l10n.couldNotTurnOnBluetooth,
      _SetupStatus.turnOnBluetoothManually => l10n.turnOnBluetoothManually,
      _SetupStatus.scanning => l10n.scanning,
      _SetupStatus.scanCouldNotStart => l10n.scanCouldNotStart,
      _SetupStatus.connecting => l10n.connectingToDevice(_connectingDeviceName),
      _SetupStatus.discoveringServices => l10n.discoveringServices,
      _SetupStatus.creatingSecureDeviceIdentity =>
        l10n.creatingSecureDeviceIdentity,
      _SetupStatus.sendingEncryptedCredentials =>
        l10n.sendingEncryptedCredentials,
      _SetupStatus.secureSetupFailed => l10n.secureSetupFailed,
    };
  }
}

enum _SetupStatus {
  readyToScan,
  bluetoothOff,
  noDevicesFound,
  selectDevice,
  missingPermissions,
  couldNotTurnOnBluetooth,
  turnOnBluetoothManually,
  scanning,
  scanCouldNotStart,
  connecting,
  discoveringServices,
  creatingSecureDeviceIdentity,
  sendingEncryptedCredentials,
  secureSetupFailed,
}
