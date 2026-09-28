import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BluetoothSetupScreen extends StatefulWidget {
  const BluetoothSetupScreen({Key? key}) : super(key: key);

  @override
  State<BluetoothSetupScreen> createState() => _BluetoothSetupScreenState();
}

class _BluetoothSetupScreenState extends State<BluetoothSetupScreen> {
  static const Set<String> _supportedDeviceNames = {
    'Inventory Platform ESP32',
    // Backward compatibility for devices that have not received new firmware.
    'Smart Fridge ESP32',
  };

  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  BluetoothDevice? _connectedDevice;
  bool _isConnecting = false;
  String _statusMessage = 'Ready to scan';

  @override
  void initState() {
    super.initState();
    // Ekran açılır açılmaz Bluetooth durumunu kontrol et
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    // Bluetooth durumunu dinle
    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.off) {
        if (mounted) setState(() => _statusMessage = "Bluetooth is OFF");
      }
    });
  }

  // EN KRİTİK FONKSİYON: İZİNLER
  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
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
      
      // Eski Android sürümleri için (Android 11 ve altı)
      if (await Permission.location.status.isDenied) {
        await Permission.location.request();
      }

      // GPS Servisi Açık mı?
      if (!await Permission.location.serviceStatus.isEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enable GPS (Location Service)'),
              backgroundColor: Colors.red,
            )
          );
        }
        return false;
      }
    }
    return true;
  }

  Future<void> _startScan() async {
    // 1. İzinleri Kontrol Et
    bool hasPermissions = await _requestPermissions();
    if (!hasPermissions) {
      setState(() => _statusMessage = "Missing Permissions or GPS is OFF");
      return;
    }

    // 2. Bluetooth Açık mı?
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      if (Platform.isAndroid) {
        try {
          await FlutterBluePlus.turnOn();
        } catch (e) {
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
        androidUsesFineLocation: true, // Konum iznini tam kullan
      );

      // Sonuçları dinle
      FlutterBluePlus.scanResults.listen((results) {
        if (mounted) {
          setState(() {
            _scanResults = results;
          });
        }
      });

      // Tarama bitti mi?
      FlutterBluePlus.isScanning.listen((isScanning) {
        if (mounted) {
          setState(() {
            _isScanning = isScanning;
            if (!isScanning) {
              _statusMessage = _scanResults.isEmpty 
                  ? 'No devices found. Try again.' 
                  : 'Select your device';
            }
          });
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Scan Error: $e';
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
      _connectedDevice = device;
      
      if (Platform.isAndroid) await device.requestMtu(512);

      setState(() => _statusMessage = 'Discovering Services...');
      List<BluetoothService> services = await device.discoverServices();
      
      BluetoothCharacteristic? writeCharacteristic;

      // Akıllı Arama: Yazılabilir (Writable) herhangi bir karakteristik bul
      for (var service in services) {
        for (var c in service.characteristics) {
           if (c.properties.write || c.properties.writeWithoutResponse) {
               writeCharacteristic = c;
               break; 
           }
        }
        if (writeCharacteristic != null) break;
      }

      if (writeCharacteristic != null) {
        setState(() => _statusMessage = 'Sending UID...');
        
        String dataToSend = "UID:${user.uid}\n";
        await writeCharacteristic.write(utf8.encode(dataToSend));
        
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
                  const SizedBox(height: 10),
                  Text('UID Sent:\n${user.uid}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () { 
                    Navigator.of(ctx).pop(); 
                    Navigator.of(context).pop(); 
                  }, 
                  child: const Text('OK')
                )
              ],
            ),
          );
        }
        await device.disconnect();
      } else {
        setState(() => _statusMessage = 'Error: Device is not writable.');
        await device.disconnect();
      }

    } catch (e) {
      setState(() => _statusMessage = 'Connection Failed: $e');
      try { await device.disconnect(); } catch (_) {}
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _connectedDevice = null;
        });
      }
    }
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
                final name = result.device.platformName;
                final id = result.device.remoteId.toString();
                final rssi = result.rssi;

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
                        color: _supportedDeviceNames.contains(name)
                            ? Colors.green
                            : Colors.black
                      )
                    ),
                    subtitle: Text("$id\nSignal: $rssi dBm"),
                    trailing: ElevatedButton(
                      onPressed: _isConnecting ? null : () => _connectAndSendUid(result.device),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _supportedDeviceNames.contains(name)
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
