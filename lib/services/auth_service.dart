// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Lightweight result wrapper used by auth methods.
class AuthResult {
  final bool success;
  final String? message;
  final User? user;

  AuthResult({required this.success, this.message, this.user});
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Create account with email & password. Returns AuthResult with user on success.
  Future<AuthResult> register(String email, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      return AuthResult(success: true, user: cred.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: e.message ?? 'Auth error');
    } catch (e) {
      if (kDebugMode) print('register error: $e');
      return AuthResult(success: false, message: 'Unexpected error');
    }
  }

  /// Sign in with email & password.
  Future<AuthResult> login(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return AuthResult(success: true, user: cred.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult(success: false, message: e.message ?? 'Auth error');
    } catch (e) {
      if (kDebugMode) print('login error: $e');
      return AuthResult(success: false, message: 'Unexpected error');
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
}
