// ============================================
// EasyLoan - AuthService
// Firebase Phone Authentication + OTP
// ============================================

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Verification ID stored for OTP submission
  String? _verificationId;
  int? _resendToken;

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ─── Send OTP ───────────────────────────────
  Future<void> sendOTP({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    required Function(PhoneAuthCredential credential) onAutoVerified,
  }) async {
    final cleanedPhone = '+91${phoneNumber.replaceAll(RegExp(r'[\s\-]'), '')}';

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: cleanedPhone,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,

        // Auto-retrieval on SMS (Android)
        verificationCompleted: (PhoneAuthCredential credential) {
          onAutoVerified(credential);
        },

        // If verification fails
        verificationFailed: (FirebaseAuthException e) {
          String message;
          switch (e.code) {
            case 'invalid-phone-number':
              message = 'Invalid phone number format';
              break;
            case 'too-many-requests':
              message = 'Too many attempts. Please try after some time.';
              break;
            case 'quota-exceeded':
              message = 'SMS quota exceeded. Please try later.';
              break;
            default:
              message = 'Failed to send OTP. Please try again.';
          }
          onError(message);
        },

        // OTP sent successfully
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          onCodeSent(verificationId);
        },

        // Auto-retrieval timeout
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      onError('An error occurred. Please try again.');
    }
  }

  // ─── Verify OTP ─────────────────────────────
  Future<UserCredential?> verifyOTP({
    required String otp,
    required String? verificationId,
  }) async {
    final vId = verificationId ?? _verificationId;
    if (vId == null) throw Exception('Verification ID not found. Please resend OTP.');

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: vId,
        smsCode: otp,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      return userCredential;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-verification-code':
          throw Exception('Invalid OTP. Please check and try again.');
        case 'session-expired':
          throw Exception('OTP has expired. Please request a new one.');
        default:
          throw Exception('OTP verification failed. Please try again.');
      }
    }
  }

  // ─── Sign out ───────────────────────────────
  Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await _auth.signOut();
    } catch (e) {
      await _auth.signOut();
    }
  }

  // ─── Check if user completed KYC ────────────
  Future<bool> isKYCCompleted() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore
          .collection(FirestoreCollections.users)
          .doc(user.uid)
          .get();

      if (!doc.exists) return false;
      return doc.data()?['kycCompleted'] ?? false;
    } catch (e) {
      return false;
    }
  }

  // ─── Get current user ID ────────────────────
  String? get userId => _auth.currentUser?.uid;

  // ─── Get current phone number ───────────────
  String? get userPhone => _auth.currentUser?.phoneNumber;

  // ─── Refresh user token ─────────────────────
  Future<String?> getIdToken() async {
    try {
      return await _auth.currentUser?.getIdToken();
    } catch (e) {
      return null;
    }
  }

  // ─── Delete account (for compliance) ────────
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Delete user data from Firestore
    await _firestore
        .collection(FirestoreCollections.users)
        .doc(user.uid)
        .delete();

    await user.delete();
  }
}