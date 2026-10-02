import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

enum AuthFailureCode {
  invalidCredentials,
  invalidEmail,
  weakPassword,
  registrationUnavailable,
  verificationRequired,
  tooManyRequests,
  network,
  unknown,
}

class AuthServiceException implements Exception {
  const AuthServiceException(this.code);

  final AuthFailureCode code;
}

class AuthService {
  static final Uri _profileEndpoint = Uri.https(
    'us-central1-smart-kuehlschrank81.cloudfunctions.net',
    '/ensureUserProfile',
  );

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  // New method name matching LoginScreen
  Future<UserCredential> signIn(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null || !user.emailVerified) {
        if (user != null) {
          try {
            await user.sendEmailVerification();
          } on FirebaseAuthException {
            // Firebase rate limits repeated verification emails.
          }
        }
        await _firebaseAuth.signOut();
        throw const AuthServiceException(
          AuthFailureCode.verificationRequired,
        );
      }
      try {
        await _ensureUserProfile(user);
      } catch (error) {
        await _firebaseAuth.signOut();
        if (error is AuthServiceException) rethrow;
        throw const AuthServiceException(AuthFailureCode.unknown);
      }
      return credential;
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(_mapSignInFailure(e.code));
    }
  }

  // Old method namekept for compatibility if used elsewhere (or redirect)
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return signIn(email, password);
  }

  // New method name matching LoginScreen
  Future<UserCredential> signUp(String email, String password) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      try {
        if (user != null) {
          await user.sendEmailVerification();
        }
      } finally {
        await _firebaseAuth.signOut();
      }
      return credential;
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(_mapSignUpFailure(e.code));
    }
  }

  // Old method name kept for compatibility
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return signUp(email, password);
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  // --- Language Preference Methods ---

  /// Saves the user's language preference to Firestore.
  Future<void> saveLanguagePreference(String languageCode) async {
    final User? user = _firebaseAuth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'languageCode': languageCode,
      });
    }
  }

  /// Gets the user's language preference from Firestore.
  Future<String?> getLanguagePreference() async {
    final User? user = _firebaseAuth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data()!.containsKey('languageCode')) {
        return doc.data()!['languageCode'] as String?;
      }
    }
    return null;
  }

  static AuthFailureCode _mapSignInFailure(String code) {
    return switch (code) {
      'invalid-email' ||
      'invalid-credential' ||
      'user-disabled' ||
      'user-not-found' ||
      'wrong-password' =>
        AuthFailureCode.invalidCredentials,
      'too-many-requests' => AuthFailureCode.tooManyRequests,
      'network-request-failed' => AuthFailureCode.network,
      _ => AuthFailureCode.unknown,
    };
  }

  static AuthFailureCode _mapSignUpFailure(String code) {
    return switch (code) {
      'invalid-email' => AuthFailureCode.invalidEmail,
      'weak-password' ||
      'password-does-not-meet-requirements' =>
        AuthFailureCode.weakPassword,
      'email-already-in-use' => AuthFailureCode.registrationUnavailable,
      'too-many-requests' => AuthFailureCode.tooManyRequests,
      'network-request-failed' => AuthFailureCode.network,
      _ => AuthFailureCode.unknown,
    };
  }

  Future<void> _ensureUserProfile(User user) async {
    try {
      final existing = await _firestore.collection('users').doc(user.uid).get();
      if (existing.exists) return;
    } catch (_) {
      // The authenticated endpoint below is the authoritative fallback.
    }

    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw const AuthServiceException(AuthFailureCode.unknown);
    }

    try {
      final response = await http
          .post(
            _profileEndpoint,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: '{}',
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 204) {
        throw const AuthServiceException(AuthFailureCode.unknown);
      }
    } on TimeoutException {
      throw const AuthServiceException(AuthFailureCode.network);
    } on http.ClientException {
      throw const AuthServiceException(AuthFailureCode.network);
    }
  }
}
