import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_kuhlschrank/providers/locale_provider.dart';
import 'package:smart_kuhlschrank/services/geolocation_service.dart'; // Import the new service
import 'package:smart_kuhlschrank/screens/login_screen.dart';
import 'package:smart_kuhlschrank/main.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isInitialDataLoaded = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasData) {
          // If user is logged in, load initial data (locale, country, etc.)
          if (!_isInitialDataLoaded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // Load language preference from Firebase
              Provider.of<LocaleProvider>(context, listen: false).loadLocale();
              
              // Update user's country based on IP in the background
              GeolocationService().updateUserCountry();
            });
            _isInitialDataLoaded = true;
          }
          return const MainAppScreen();
        } else {
          // If user is logged out, reset the flag
          _isInitialDataLoaded = false;
          return const LoginScreen();
        }
      },
    );
  }
}
