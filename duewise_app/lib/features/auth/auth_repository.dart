import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart'; // Import Hive

import '../subscriptions/subscription_model.dart'; // Path adjust kar lein
import '../subscriptions/payment_log_model.dart'; // Path adjust kar lein

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Email & Password Sign Up
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Email & Password Sign In
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Google Sign-In
  Future<UserCredential?> signInWithGoogle() async {
    if (kIsWeb) {
      // Web authentication flow
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      return await _auth.signInWithPopup(googleProvider);
    } else {
      // Mobile native authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User cancelled flow

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    }
  }

  // Sign Out (Updated with Local Hive Clear)
  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }
      await _auth.signOut();

      // Clear local Hive storage on logout
      if (Hive.isBoxOpen('subscriptions')) {
        await Hive.box<Subscription>('subscriptions').clear();
      }
      if (Hive.isBoxOpen('payment_logs')) {
        await Hive.box<PaymentLog>('payment_logs').clear();
      }
    } catch (e) {
      print('Error during sign out & clear cache: $e');
    }
  }
}
