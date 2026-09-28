import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A service to handle fetching geolocation data and updating Firestore.
class GeolocationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetches the user's country based on their IP address and updates Firestore.
  ///
  /// This method is designed to fail silently if the API call or database update fails,
  /// as this information is not critical for the app to function.
  Future<void> updateUserCountry() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      // No user is logged in, so we can't update anything.
      return;
    }

    try {
      // Use a free IP-based geolocation API.
      final response = await http.get(Uri.parse('http://ip-api.com/json'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String? countryCode = data['countryCode'];

        if (countryCode != null && countryCode.isNotEmpty) {
          // Save the retrieved country code to the user's document.
          await _firestore.collection('users').doc(user.uid).set(
            {'countryCode': countryCode},
            SetOptions(merge: true), // Use merge to avoid overwriting other user data.
          );
        }
      }
    } catch (e) {
      // For debugging purposes, print the error. In a production app, you might log this.
      print('Failed to update user country: $e');
    }
  }
}
