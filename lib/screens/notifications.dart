import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_kuhlschrank/l10n/app_localizations.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
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

  int _currentStep = 0;
  bool _isConnecting = false;
  BluetoothDevice? _targetDevice;
  BluetoothCharacteristic? _writeCharacteristic;
  String _statusMessage = "";

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> _requestPermissions() async {
    if (_isAndroid) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      if (statuses[Permission.bluetoothScan]!.isDenied || 
          statuses[Permission.bluetoothConnect]!.isDenied) {
        return false;
      }
    }
    return true;
  }

  Future<void> _findAndConnect() async {
    setState(() {
      _isConnecting = true;
      _statusMessage = "İzinler kontrol ediliyor...";
    });

    if (!await _requestPermissions()) {
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _statusMessage = "Bluetooth izinleri verilmedi.";
      });
      return;
    }

    if (!mounted) return;
    setState(() => _statusMessage = "Cihaz aranıyor...");

    try {
      // 1. Önce halihazırda bağlı cihazlara bak (Bağlı kalmış olabilir)
      List<BluetoothDevice> connectedDevices = FlutterBluePlus.connectedDevices;
      for (var device in connectedDevices) {
        if (_supportedDeviceNames.contains(device.platformName) ||
            _supportedDeviceNames.contains(device.advName)) {
          _targetDevice = device;
          break;
        }
      }

      // 2. Bağlı değilse tarama yap
      if (_targetDevice == null) {
        await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
        
        Completer<BluetoothDevice?> completer = Completer();
        var subscription = FlutterBluePlus.scanResults.listen((results) {
          for (ScanResult r in results) {
            final name = r.device.platformName.isNotEmpty ? r.device.platformName : r.advertisementData.advName;
            if (_supportedDeviceNames.contains(name)) {
              if (!completer.isCompleted) {
                completer.complete(r.device);
                FlutterBluePlus.stopScan();
              }
              break;
            }
          }
        });

        try {
          _targetDevice = await completer.future.timeout(
            const Duration(seconds: 10),
            onTimeout: () => null,
          );
        } finally {
          await subscription.cancel();
          await FlutterBluePlus.stopScan();
        }
      }

      if (_targetDevice == null) {
        if (!mounted) return;
        setState(() {
          _isConnecting = false;
          _statusMessage = "Cihaz bulunamadı. Lütfen ESP32'nin açık olduğundan emin olun.";
        });
        return;
      }

      // 3. Bağlan (Zaten bağlıysa hata vermez)
      if (!mounted) return;
      setState(() => _statusMessage = "Cihaza bağlanılıyor...");
      await _targetDevice!.connect(autoConnect: false).timeout(const Duration(seconds: 10));
      
      if (!mounted) return;
      setState(() => _statusMessage = "Servisler keşfediliyor...");
      List<BluetoothService> services = await _targetDevice!.discoverServices();
      
      _writeCharacteristic = null;
      final matchingServices = services.where(
        (service) => service.uuid.toString().toUpperCase() == _serviceUuid,
      );
      if (matchingServices.length == 1) {
        final characteristics = matchingServices.single.characteristics;
        final matchingCharacteristics = characteristics.where(
          (characteristic) =>
              characteristic.uuid.toString().toUpperCase() == _writeUuid &&
              characteristic.properties.write,
        );
        final identityCharacteristics = characteristics.where(
          (characteristic) =>
              characteristic.uuid.toString().toUpperCase() == _identityUuid &&
              characteristic.properties.read,
        );
        if (matchingCharacteristics.length == 1 &&
            identityCharacteristics.length == 1) {
          final identityValue = utf8.decode(
            await identityCharacteristics.single.read(),
            allowMalformed: false,
          );
          final identity = RegExp(r'^DEVICE:([A-F0-9]{32})$')
              .firstMatch(identityValue.trim());
          final user = FirebaseAuth.instance.currentUser;
          if (identity != null && user != null && user.emailVerified) {
            final device = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('devices')
                .doc(identity.group(1)!)
                .get();
            if (device.exists && device.data()?['status'] == 'active') {
              _writeCharacteristic = matchingCharacteristics.single;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _isConnecting = false;
          _statusMessage = _writeCharacteristic != null
              ? "Cihaz Hazır."
              : "Hata: Yazılabilir özellik bulunamadı.";
        });
      }
    } catch (_) {
      _targetDevice = null;
      _writeCharacteristic = null;
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _statusMessage = "Güvenli Bluetooth bağlantısı kurulamadı.";
        });
      }
    }
  }

  Future<bool> _sendCommand(String command) async {
    if (_writeCharacteristic == null) {
      await _findAndConnect();
    }

    if (_writeCharacteristic != null) {
      try {
        await _writeCharacteristic!.write(utf8.encode(command));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Komut gönderildi: $command"),
              backgroundColor: Colors.green,
            ),
          );
        }
        return true;
      } catch (_) {
        if (mounted) {
          setState(() => _statusMessage = "Komut güvenli biçimde gönderilemedi.");
        }
        _writeCharacteristic = null; // Bağlantı kopmuş olabilir, sıfırla
      }
    }
    return false;
  }

  @override
  void dispose() {
    unawaited(FlutterBluePlus.stopScan());
    final targetDevice = _targetDevice;
    if (targetDevice != null) unawaited(targetDevice.disconnect());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sensorCalibration),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isConnecting) const LinearProgressIndicator(),
            const SizedBox(height: 10),
            Text(
              _statusMessage.isEmpty ? "Kalibrasyona başlamak için butona basın." : _statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _statusMessage.contains("Hata") ? Colors.red : Colors.teal
              ),
            ),
            const SizedBox(height: 30),
            
            _buildStepCard(
              step: 1,
              title: l10n.emptyPlatforms,
              buttonLabel: l10n.setZero,
              icon: Icons.exposure_zero,
              onPressed: () async {
                if (await _sendCommand("CAL:ZERO") && mounted) {
                  setState(() => _currentStep = 1);
                }
              },
              isActive: _currentStep >= 0,
              isCompleted: _currentStep > 0,
            ),
            
            const SizedBox(height: 16),
            
            _buildStepCard(
              step: 2,
              title: l10n.place800gP1,
              buttonLabel: l10n.calibrateP1,
              icon: Icons.fitness_center,
              onPressed: () async {
                if (await _sendCommand("CAL:P1:800") && mounted) {
                  setState(() => _currentStep = 2);
                }
              },
              isActive: _currentStep >= 1,
              isCompleted: _currentStep > 1,
            ),
            
            const SizedBox(height: 16),
            
            _buildStepCard(
              step: 3,
              title: l10n.place800gP2,
              buttonLabel: l10n.calibrateP2,
              icon: Icons.fitness_center,
              onPressed: () async {
                if (await _sendCommand("CAL:P2:800") && mounted) {
                  setState(() => _currentStep = 3);
                }
              },
              isActive: _currentStep >= 2,
              isCompleted: _currentStep > 2,
            ),

            if (_currentStep == 3) ...[
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(child: Text(l10n.calibrationComplete, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => setState(() => _currentStep = 0),
                child: Text(l10n.startCalibration),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required int step,
    required String title,
    required String buttonLabel,
    required IconData icon,
    required VoidCallback onPressed,
    required bool isActive,
    required bool isCompleted,
  }) {
    return Opacity(
      opacity: isActive ? 1.0 : 0.5,
      child: Card(
        elevation: isActive ? 4 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: isCompleted ? Colors.green : (isActive ? Colors.teal : Colors.grey.shade300), width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: isCompleted ? Colors.green : (isActive ? Colors.teal : Colors.grey),
                    child: Text(step.toString(), style: const TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (isCompleted) const Icon(Icons.check_circle, color: Colors.green),
                ],
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (isActive && !_isConnecting) ? onPressed : null,
                  icon: Icon(icon),
                  label: Text(buttonLabel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCompleted ? Colors.green : Colors.teal,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade200,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
