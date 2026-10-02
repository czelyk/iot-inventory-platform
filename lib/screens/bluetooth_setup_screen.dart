import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/device_provisioning_service.dart';

class BluetoothSetupScreen extends StatefulWidget {
  const BluetoothSetupScreen({super.key});

  @override
  State<BluetoothSetupScreen> createState() => _BluetoothSetupScreenState();
}

class _BluetoothSetupScreenState extends State<BluetoothSetupScreen> {
  static const String _serviceUuid =
      '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';
  static const String _writeUuid =
      '6E400002-B5A3-F393-E0A9-E50E24DCCA9E';
  static const String _identityUuid =
      '6E400003-B5A3-F393-E0A9-E50E24DCCA9E';
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
  String _statusMessage = 'Ready to scan';
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
        if (mounted) setState(() => _statusMessage = "Bluetooth is OFF");
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
          _statusMessage = _scanResults.isEmpty
              ? 'No devices found. Try again.'
              : 'Select your device';
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
      setState(() => _statusMessage = "Missing Permissions or GPS is OFF");
      return;
    }

    // 2. Bluetooth Açık mı?
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      if (_isAndroid) {
        try {
          await FlutterBluePlus.turnOn();
        } catch (e) {
          if (!mounted) return;
          setState(() => _statusMessage = "Could not turn on Bluetooth");
          return;
        }
      } else {
        setState(() => _statusMessage = "Please turn on Bluetooth manually");
        return;
      }
    }

    setState(() {
      _isScanning = true;
      _scanResults.clear();
      _statusMessage = 'Scanning...';
    });

    try {
      // 3. TARAMA BAŞLAT (Filtresiz ve Düşük Gecikmeli)
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: false,
      );

    } catch (_) {
      setState(() {
        _statusMessage = 'Bluetooth scan could not be started.';
        _isScanning = false;
      });
    }
  }

  Future<void> _connectAndSendUid(BluetoothDevice device) async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please login first")));
      return;
    }

    setState(() {
      _isConnecting = true;
      _statusMessage = 'Connecting to ${device.platformName}...';
    });

    try {
      // Bağlan
      await device.connect(autoConnect: false); // autoConnect: false daha hızlıdır
      if (_isAndroid) await device.requestMtu(512);

      if (!mounted) return;
      setState(() => _statusMessage = 'Discovering Services...');
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
      final identity = RegExp(r'^DEVICE:([A-F0-9]{32})$')
          .firstMatch(identityValue.trim());
      if (identity == null) {
        throw const DeviceProvisioningException('invalid-device');
      }

      if (mounted) {
        setState(() => _statusMessage = 'Creating secure device identity...');
      }
      final credentials = await _provisioningService.provision(
        identity.group(1)!,
      );
      final payload = utf8.encode(credentials.provisioningCommand);
      if (payload.length > 500) {
        throw const DeviceProvisioningException('invalid-response');
      }

      if (!mounted) return;
      setState(() => _statusMessage = 'Sending encrypted credentials...');
      await writeMatches.single.write(payload, withoutResponse: false);

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Success!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 50),
                const SizedBox(height: 10),
                const Text('Device setup completed successfully.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }

    } catch (_) {
      if (mounted) {
        setState(() => _statusMessage =
            'Secure setup failed. Confirm the device is in pairing mode.');
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
    return Scaffold(
      appBar: AppBar(title: const Text('Device Setup')),
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
                  _statusMessage,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                if (_scanResults.isNotEmpty) 
                  Text("${_scanResults.length} devices found", style: const TextStyle(color: Colors.grey)),
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
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.teal,
                      child: Icon(Icons.bluetooth, color: Colors.white),
                    ),
                    title: Text(
                      name.isNotEmpty ? name : "Unknown Device", 
                      style: TextStyle(
                        fontWeight: name.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                        color: isSupported
                            ? Colors.green
                            : Colors.black
                      )
                    ),
                    subtitle: Text("$id\nSignal: $rssi dBm"),
                    trailing: ElevatedButton(
                      onPressed: _isConnecting || !isSupported
                          ? null
                          : () => _connectAndSendUid(result.device),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSupported
                            ? Colors.green
                            : Colors.teal,
                        foregroundColor: Colors.white
                      ),
                      child: const Text("Connect"),
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
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : const Icon(Icons.search),
                label: Text(_isScanning ? 'STOP SCANNING' : 'SCAN FOR DEVICES', style: const TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isScanning ? Colors.redAccent : Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
}
