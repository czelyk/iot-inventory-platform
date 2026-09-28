import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  // New method name matching LoginScreen
  Future<UserCredential> signIn(String email, String password) async {
    try {
      return await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
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
      UserCredential cred = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Initialize user document
      if (cred.user != null) {
        await _firestore.collection('users').doc(cred.user!.uid).set({
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
          'languageCode': 'en', // Default
        });
      }
      return cred;

    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
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
      await _firestore.collection('users').doc(user.uid).set(
        {'languageCode': languageCode},
        SetOptions(merge: true), // Use merge to avoid overwriting other fields
      );
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
}
