import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

// AUTH provider - Manages authentication state globally
class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => ApiService.isLoggedIn;
  String? get errorMessage => _errorMessage;

  String get userName => _user?['name'] ?? 'Resident';
  String get userPhone => _user?['phone'] ?? '';
  String get userRole => _user?['role'] ?? 'resident';

  // Login
  Future<bool> login(String phone, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await ApiService.login(phone, password);

    _isLoading = false;

    if (result['success']) {
      _user = result['user'];
      notifyListeners();
      return true;
    } else {
      _errorMessage = result['message'];
      notifyListeners();
      return false;
    }
  }

  // Logout
  void logout() {
    _user = null;
    _errorMessage = null;
    ApiService.clearStorage();
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}