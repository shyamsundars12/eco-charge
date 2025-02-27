import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;

  User? get user => _user;

  AuthProvider() {
    _initAuthListener();
  }

  void _initAuthListener() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners(); // Notify UI when user changes
    });
  }

  // ✅ Email & Password Signup
  Future<String?> signUpWithEmail(String email, String password) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      _user = credential.user; // Update local user
      notifyListeners();
      return null; // Success
    } catch (e) {
      return e.toString(); // Return error message
    }
  }

  // ✅ Email & Password Sign-in
  Future<String?> signInWithEmail(String email, String password) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      _user = credential.user; // Update local user
      notifyListeners();
      return null; // Success
    } catch (e) {
      return e.toString(); // Return error message
    }
  }

  // ✅ Google Sign-In with Forced Account Selection
  Future<String?> signInWithGoogle() async {
    try {
      await GoogleSignIn().signOut(); // Ensures account selection every time
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return "Google Sign-In canceled"; // Handle cancellation

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      _user = userCredential.user; // Update local user
      notifyListeners();
      return null; // Success
    } catch (e) {
      return e.toString(); // Return error message
    }
  }

  // ✅ Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
    await GoogleSignIn().disconnect();
    await GoogleSignIn().signOut();
    _user = null;
    notifyListeners();
  }
}
