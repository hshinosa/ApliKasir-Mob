// lib/fitur/login/providers/login_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/api_services.dart'; // Sesuaikan path
import '../../../model/user_model.dart';     // Sesuaikan path

class LoginProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _obscurePassword = true;
  bool get obscurePassword => _obscurePassword;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  User? _loggedInUser;
  User? get loggedInUser => _loggedInUser;

  // Untuk prefill email jika dari RegisterScreen
  LoginProvider({String? initialEmail}) {
    if (initialEmail != null) {
      emailController.text = initialEmail;
    }
  }

  void togglePasswordVisibility() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearMessages() {
    _errorMessage = null;
    // _successMessage bisa ditambahkan jika perlu di state
    notifyListeners(); // Meskipun tidak ada UI langsung yg refresh, best practice
  }

  Future<bool> login() async {
    _clearMessages();
    if (!(formKey.currentState?.validate() ?? false)) {
      return false; // Validasi gagal
    }
    _setLoading(true);

    final String emailOrPhone = emailController.text.trim();
    final String password = passwordController.text;

    try {
      final loginResponse = await _apiService.login(emailOrPhone, password);

      final String? accessToken = loginResponse['accessToken'] as String?;
      if (accessToken == null || accessToken.isEmpty) {
        throw Exception(loginResponse['message'] ?? 'Login failed: Missing access token.');
      }

      final Map<String, dynamic>? userDataMap = loginResponse['user'] as Map<String, dynamic>?;
      if (userDataMap == null) {
        throw Exception(loginResponse['message'] ?? 'Login failed: Missing user data.');
      }

      _loggedInUser = User.fromMap(userDataMap);

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('accessToken', accessToken);

      if (_loggedInUser!.id != null) {
        await prefs.setInt('loggedInUserId', _loggedInUser!.id!);
        await prefs.setString('userName', _loggedInUser!.name);
        await prefs.setString('userEmail', _loggedInUser!.email);
        print('Login successful. Saved userId: ${_loggedInUser!.id} and token.');
      } else {
        await prefs.remove('isLoggedIn');
        await prefs.remove('accessToken');
        throw Exception('User ID is null after successful login.');
      }

      _setLoading(false);
      return true; // Sukses
    } catch (e) {
      print("LoginProvider Error: $e");
      try {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.remove('isLoggedIn');
        await prefs.remove('accessToken');
        await prefs.remove('loggedInUserId');
      } catch (prefsError) {
        print("Error clearing prefs on login failure: $prefsError");
      }
      _errorMessage = e.toString().replaceFirst("Exception: ", "");
      _setLoading(false);
      return false; // Gagal
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}