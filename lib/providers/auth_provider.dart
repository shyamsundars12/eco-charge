import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(); // ✅ Single instance

  User? _user;
  User? get user => _user;

  AuthProvider() {
    _initAuthListener();
  }

  void _initAuthListener() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  // ✅ Sign Up with Email
  Future<String?> signUpWithEmail(String email, String password) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      _user = credential.user;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? "Signup failed. Try again.";
    } catch (e) {
      return "An unexpected error occurred: ${e.toString()}";
    }
  }

  // ✅ Sign In with Email
  Future<String?> signInWithEmail(String email, String password) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      _user = credential.user;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? "Sign-in failed. Try again.";
    } catch (e) {
      return "An unexpected error occurred: ${e.toString()}";
    }
  }

  // ✅ Sign In with Google (Improved)
  Future<String?> signInWithGoogle() async {
    try {
      await _googleSignIn.signOut(); // ✅ Ensures fresh account selection
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return "Google Sign-In canceled.";

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      _user = userCredential.user;
      notifyListeners();
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return e.message ?? "Google Sign-In failed. Try again.";
    } catch (e) {
      return "An unexpected error occurred: ${e.toString()}";
    }
  }

  // ✅ Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
    _user = null;
    notifyListeners();
  }
}
