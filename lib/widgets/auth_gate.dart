import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_kuhlschrank/providers/locale_provider.dart';
import 'package:smart_kuhlschrank/screens/login_screen.dart';
import 'package:smart_kuhlschrank/main.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _loadedUserId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = snapshot.data;
        if (user != null && user.emailVerified) {
          final userId = user.uid;
          if (_loadedUserId != userId) {
            _loadedUserId = userId;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Provider.of<LocaleProvider>(context, listen: false).loadLocale();
            });
          }
          return const MainAppScreen();
        } else {
          if (user != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              FirebaseAuth.instance.signOut();
            });
          }
          if (_loadedUserId != null) {
            _loadedUserId = null;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Provider.of<LocaleProvider>(context, listen: false).clearLocale();
            });
          }
          return const LoginScreen();
        }
      },
    );
  }
}
