import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _userModel;
  UserModel? get userModel => _userModel;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Listen for authentication changes & fetch user details
  AuthProvider() {
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        await fetchUserDetails(user.uid);
      } else {
        _userModel = null;
      }
      notifyListeners();
    });
  }

  /// ✅ FIXED: Sign Up with Email & Firestore Integration
  Future<String?> signUpWithEmail(
      String name, String email, String password, String phone, String role) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Create user in Firebase Auth
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) return "Signup failed. Please try again.";

      String userId = credential.user!.uid;

      // Store user in Firestore
      _userModel = UserModel(
        id: userId,
        name: name,
        email: email,
        phone: phone,
        role: role,
      );

      await _firestore.collection('users').doc(userId).set(_userModel!.toJson());

      return userId; // Return userId on success
    } on FirebaseAuthException catch (e) {
      return e.message ?? "Signup failed. Please try again.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// ✅ FIXED: Sign In with Email (Returns userId on success)
  Future<String?> signInWithEmail(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) return "Login failed! User not found.";

      String userId = credential.user!.uid;
      await fetchUserDetails(userId);

      return userId; // ✅ Returning userId explicitly
    } on FirebaseAuthException catch (e) {
      return e.message ?? "Sign-in failed. Please try again.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// ✅ FIXED: Fetch User Details from Firestore
  Future<void> fetchUserDetails(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        _userModel = UserModel.fromFirestore(doc.data() as Map<String, dynamic>, userId);
      } else {
        _userModel = null;
      }
    } catch (e) {
      debugPrint("Error fetching user: $e");
      _userModel = null;
    }
    notifyListeners();
  }

  /// ✅ FIXED: Google Sign-In (Ensures Firestore Entry Exists)
  Future<String?> signInWithGoogle() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _googleSignIn.signOut(); // Ensures fresh account selection
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return "Google Sign-In was canceled.";

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        String userId = firebaseUser.uid;

        // Check if user exists in Firestore, else create new entry
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
        if (!userDoc.exists) {
          _userModel = UserModel(
            id: userId,
            name: firebaseUser.displayName ?? "User",
            email: firebaseUser.email ?? "",
            phone: firebaseUser.phoneNumber ?? "",
            role: "user", // Default role for Google Sign-In
          );
          await _firestore.collection('users').doc(userId).set(_userModel!.toJson());
        } else {
          _userModel = UserModel.fromFirestore(userDoc.data() as Map<String, dynamic>, userId);
        }

        return userId; // ✅ Return userId after Google Sign-In
      }
      return "Google Sign-In failed. Please try again.";
    } on FirebaseAuthException catch (e) {
      return e.message ?? "Google Sign-In failed. Please try again.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// ✅ Reset Password
  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return e.message ?? "Failed to send reset email.";
    }
  }

  /// ✅ Sign Out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
      _userModel = null;
      notifyListeners();
    } catch (e) {
      debugPrint("Error signing out: $e");
    }
  }
}
