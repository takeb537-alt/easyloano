// ============================================
// EasyLoan - AppProvider
// App-level state management
// ============================================

import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class AppProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _activeLoan;
  bool _isLoading = false;
  String? _error;
  int _onTimeRepayments = 0;

  Map<String, dynamic>? get userData => _userData;
  Map<String, dynamic>? get activeLoan => _activeLoan;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get onTimeRepayments => _onTimeRepayments;

  bool get isAuthenticated => _authService.isLoggedIn;

  /// Load user data from Firestore
  Future<void> loadUserData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _userData = await _firestoreService.getUser();
      _activeLoan = await _firestoreService.getActiveLoan();
      _onTimeRepayments = await _firestoreService.getOnTimeRepayments();
    } catch (e) {
      _error = 'Failed to load data';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh active loan
  Future<void> refreshActiveLoan() async {
    try {
      _activeLoan = await _firestoreService.getActiveLoan();
      notifyListeners();
    } catch (_) {}
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}