import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  AppUser? _user;
  bool _loading = true;

  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get loading => _loading;

  /// Attempts to restore a session from a saved token.
  Future<void> tryAutoLogin() async {
    _loading = true;
    notifyListeners();
    final token = await ApiService.getToken();
    if (token == null) {
      _loading = false;
      notifyListeners();
      return;
    }
    try {
      final res = await ApiService.get('/api/profile');
      _user = AppUser.fromJson(res['account']);
    } catch (_) {
      await ApiService.clearToken();
      _user = null;
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> login({required String email, required String password, required String portal}) async {
    final res = await ApiService.post('/api/auth/login', body: {
      'email': email,
      'password': password,
      'portal': portal,
    });
    await ApiService.saveToken(res['token']);
    _user = AppUser.fromJson(res['user']);
    notifyListeners();
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String confirmPassword,
    required String securityQuestion1,
    required String securityAnswer1,
    required String securityQuestion2,
    required String securityAnswer2,
    String? branchId,
  }) async {
    final res = await ApiService.post('/api/auth/register', body: {
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'password': password,
      'confirm_password': confirmPassword,
      'security_question_1': securityQuestion1,
      'security_answer_1': securityAnswer1,
      'security_question_2': securityQuestion2,
      'security_answer_2': securityAnswer2,
      'branch_id': branchId,
    });
    await ApiService.saveToken(res['token']);
    _user = AppUser.fromJson(res['user']);
    notifyListeners();
  }

  Future<void> logout() async {
    await ApiService.clearToken();
    _user = null;
    notifyListeners();
  }
}
