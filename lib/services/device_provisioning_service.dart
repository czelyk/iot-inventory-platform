import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class DeviceCredentials {
  const DeviceCredentials({
    required this.deviceId,
    required this.ownerUid,
    required this.email,
    required this.password,
  });

  final String deviceId;
  final String ownerUid;
  final String email;
  final String password;

  String get provisioningCommand =>
      'PROVISION|$ownerUid|$email|$password';
}

class DeviceProvisioningException implements Exception {
  const DeviceProvisioningException([this.code = 'provisioning-failed']);

  final String code;
}

class DeviceProvisioningService {
  DeviceProvisioningService({
    FirebaseAuth? auth,
    http.Client? client,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _client = client ?? http.Client();

  static final Uri _endpoint = Uri.https(
    'us-central1-smart-kuehlschrank81.cloudfunctions.net',
    '/provisionDevice',
  );
  static final RegExp _deviceIdPattern = RegExp(r'^[A-F0-9]{32}$');

  final FirebaseAuth _auth;
  final http.Client _client;

  Future<DeviceCredentials> provision(String rawDeviceId) async {
    final deviceId = rawDeviceId.trim().toUpperCase();
    if (!_deviceIdPattern.hasMatch(deviceId)) {
      throw const DeviceProvisioningException('invalid-device-id');
    }

    final user = _auth.currentUser;
    if (user == null || !user.emailVerified) {
      throw const DeviceProvisioningException('authentication-required');
    }
    final idToken = await user.getIdToken(true);
    if (idToken == null || idToken.isEmpty) {
      throw const DeviceProvisioningException('authentication-required');
    }

    final http.Response response;
    try {
      response = await _client
          .post(
            _endpoint,
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'deviceId': deviceId}),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const DeviceProvisioningException('timeout');
    } on http.ClientException {
      throw const DeviceProvisioningException('network-error');
    }

    if (response.bodyBytes.length > 4096) {
      throw const DeviceProvisioningException('invalid-response');
    }

    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const DeviceProvisioningException('invalid-response');
    }
    if (response.statusCode != 200) {
      final code = decoded is Map<String, dynamic> &&
              decoded['error'] is String
          ? decoded['error'] as String
          : 'provisioning-failed';
      throw DeviceProvisioningException(code);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const DeviceProvisioningException('invalid-response');
    }

    final responseDeviceId = decoded['deviceId'];
    final ownerUid = decoded['ownerUid'];
    final email = decoded['email'];
    final password = decoded['password'];
    if (responseDeviceId != deviceId ||
        ownerUid != user.uid ||
        email is! String ||
        password is! String ||
        email.length > 254 ||
        password.length < 32 ||
        password.length > 128) {
      throw const DeviceProvisioningException('invalid-response');
    }

    return DeviceCredentials(
      deviceId: deviceId,
      ownerUid: ownerUid as String,
      email: email,
      password: password,
    );
  }

  void close() => _client.close();
}
