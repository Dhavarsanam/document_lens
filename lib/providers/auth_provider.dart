import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:document_lens/models/app_user.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading, error }

/// ✅ Backed by Firebase Auth (was: local Hive users box + sha256 password
/// hashing). Session persistence, password security, and multi-device
/// login are now handled by Firebase itself.
class AuthProvider extends ChangeNotifier {
  // ✅ Not initialized eagerly anymore — on web, if Firebase hasn't been
  // configured for the web platform (see firebase_options.dart), even
  // touching FirebaseAuth.instance throws synchronously and crashes the
  // whole widget tree during MultiProvider setup. We now grab it lazily
  // inside a try/catch so a missing web config degrades to
  // "unauthenticated" instead of crashing the app.
  fb.FirebaseAuth? _auth;
  StreamSubscription<fb.User?>? _authSub;

  AuthStatus _status = AuthStatus.initial;
  AppUser? _currentUser;
  String _errorMessage = '';

  AuthStatus get status => _status;
  AppUser? get currentUser => _currentUser;
  String get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  AuthProvider() {
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    try {
      _auth = fb.FirebaseAuth.instance;
    } catch (e) {
      debugPrint(
          '⚠️ FirebaseAuth unavailable (Firebase not configured for this '
              'platform yet — see firebase_options.dart). Falling back to '
              'unauthenticated: $e');
      _status = AuthStatus.unauthenticated;
      Future.microtask(notifyListeners);
      return;
    }
    _authSub = _auth!.authStateChanges().listen((fb.User? user) {
      if (user != null) {
        _currentUser = AppUser(
          uid: user.uid,
          name: (user.displayName == null || user.displayName!.isEmpty)
              ? (user.email?.split('@').first ?? 'User')
              : user.displayName!,
          email: user.email ?? '',
        );
        _status = AuthStatus.authenticated;
      } else {
        _currentUser = null;
        _status = AuthStatus.unauthenticated;
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Email already registered!';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak (minimum 6 characters).';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password!';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      final cred = await _auth!.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await cred.user?.updateDisplayName(name.trim());
      await cred.user?.reload();
      // authStateChanges listener above sets _currentUser/_status.
      return true;
    } on fb.FirebaseAuthException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _friendlyError(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'Registration failed. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      await _auth!.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      // authStateChanges listener above sets _currentUser/_status.
      return true;
    } on fb.FirebaseAuthException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _friendlyError(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'Login failed. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _auth?.signOut();
    // authStateChanges listener above clears _currentUser/_status.
  }

  /// Updates the current user's display name and persists it (Firebase Auth).
  Future<bool> updateName(String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || _auth?.currentUser == null) return false;

    try {
      await _auth!.currentUser!.updateDisplayName(trimmed);
      await _auth!.currentUser!.reload();
      _currentUser = AppUser(
        uid: _currentUser!.uid,
        name: trimmed,
        email: _currentUser!.email,
      );
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Sends a password-reset email via Firebase.
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _auth!.sendPasswordResetEmail(email: email.trim());
      return true;
    } catch (e) {
      return false;
    }
  }
}