import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Impor SharedPreferences

// --- Imports for Register & Home ---
import 'package:aplikasir_mobile/screen/register/register_step_1.dart'; // Keep existing Step 1 import
import 'package:aplikasir_mobile/screen/homepage/homepage_screen.dart'; // Import Homepage
// --- Imports for DB & Auth ---
import 'package:aplikasir_mobile/model/user_model.dart';
import 'package:aplikasir_mobile/services/api_services.dart'; // Import ApiService

class LoginScreen extends StatefulWidget {
  // --- Add optional parameter for prefilling email ---
  final String? initialEmail;

  const LoginScreen({Key? key, this.initialEmail}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;
  bool _isLoggingIn = false; // State for loading indicator

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>(); // For validation

  @override
  void initState() {
    super.initState();
    // --- Prefill email if provided ---
    if (widget.initialEmail != null) {
      _emailController.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- Modifikasi Fungsi _login ---
  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isLoggingIn) return;
    setState(() => _isLoggingIn = true);

    final String emailOrPhone = _emailController.text.trim();
    final String password = _passwordController.text;
    final apiService = ApiService(); // Instance service API

    try {
      final loginResponse = await apiService.login(emailOrPhone, password);

      // --- PERIKSA KEBERADAAN ACCESS TOKEN ---
      final String? accessToken = loginResponse['accessToken']
          as String?; // Cast sebagai String? (nullable)
      if (accessToken == null || accessToken.isEmpty) {
        // Jika token null atau kosong, anggap login gagal meskipun status 200 (kasus aneh)
        throw Exception(
            loginResponse['message'] ?? 'Login failed: Missing access token.');
      }

      // --- PERIKSA KEBERADAAN USER DATA ---
      final Map<String, dynamic>? userData =
          loginResponse['user'] as Map<String, dynamic>?;
      if (userData == null) {
        throw Exception(
            loginResponse['message'] ?? 'Login failed: Missing user data.');
      }

      // Buat objek User (asumsi fromMap bisa handle field null internalnya)
      final user = User.fromMap(userData);

      // --- Simpan ke SharedPreferences dengan Pengecekan Null ---
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString(
          'accessToken', accessToken); // Token sudah pasti non-null di sini

      if (user.id != null) {
        await prefs.setInt('loggedInUserId', user.id!);

        // Simpan data lain dengan aman (gunakan '' jika null)
        await prefs.setString(
            'userName', user.name); // Default ke string kosong jika null
        await prefs.setString(
            'userEmail', user.email); // Default ke string kosong jika null
        // Jika ada field lain yang wajib String, tambahkan pengecekan serupa

        print('Login successful. Saved userId: ${user.id} and token.');
      } else {
        // Hapus token jika ID user null (tidak konsisten)
        await prefs.remove('accessToken');
        await prefs.remove('isLoggedIn');
        throw Exception('User ID is null after successful login.');
      }

      if (!mounted) return;

      _showSuccessSnackbar(
          'Login berhasil! Selamat datang ${user.name}.'); // Handle nama null di pesan

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => HomePage(userId: user.id!)),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      print("Login API Error: $e");
      // Pastikan menghapus state login jika error terjadi
      try {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.remove('isLoggedIn');
        await prefs.remove('accessToken');
        await prefs.remove('loggedInUserId');
        // Hapus data user lain jika disimpan
      } catch (prefsError) {
        print("Error clearing prefs on login failure: $prefsError");
      }

      _showErrorSnackbar(e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) {
        setState(() => _isLoggingIn = false);
      }
    }
  }

  // Helper Snackbar (tambahkan jika belum ada)
  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  // --- Navigate to Register Step 1 ---
  void _navigateToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => RegisterScreen()), // Goes to Step 1
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              // Wrap content in a Form widget
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  // --- Logo Section (Keep as is) ---
                  Padding(
                    padding: EdgeInsets.only(
                      top: screenSize.height * 0.08,
                      bottom: screenSize.height * 0.05,
                    ),
                    child: Image.asset(
                      'assets/images/logo_utama.png',
                      height: screenSize.height * 0.1,
                      width: screenSize.width * 0.5,
                      fit: BoxFit.fitWidth,
                    ),
                  ),

                  Text(
                    'Masuk dan\nKembangkan Bisnismu',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        height: 1.3),
                  ),

                  SizedBox(height: screenSize.height * 0.04),

                  Container(
                    padding: const EdgeInsets.all(25.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.0),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.grey.withOpacity(0.15),
                            spreadRadius: 1,
                            blurRadius: 10,
                            offset: const Offset(0, 5))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Email atau Nomor Telepon',
                            style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Email atau nomor telepon tidak boleh kosong';
                            }
                            // Basic check (can be improved)
                            // if (!value.contains('@') && !RegExp(r'^[0-9]+$').hasMatch(value)) {
                            //   return 'Format tidak valid';
                            // }
                            return null;
                          },
                          decoration: InputDecoration(
                            hintText: 'Masukkan email atau nomor telepon',
                            hintStyle:
                                GoogleFonts.poppins(color: Colors.grey[400]),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 15.0, horizontal: 15.0),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.0),
                                borderSide:
                                    BorderSide(color: Colors.grey[300]!)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.0),
                                borderSide:
                                    BorderSide(color: Colors.grey[350]!)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.0),
                                borderSide: BorderSide(
                                    color: Colors.blue[600]!, width: 1.5)),
                            errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.0),
                                borderSide: const BorderSide(
                                    color: Colors.red, width: 1.0)),
                            focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.0),
                                borderSide: const BorderSide(
                                    color: Colors.red, width: 1.5)),
                          ),
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                        const SizedBox(height: 20),
                        Text('Kata Sandi',
                            style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Kata sandi tidak boleh kosong';
                            }
                            // Optional: Add length validation etc.
                            // if (value.length < 6) {
                            //   return 'Kata sandi minimal 6 karakter';
                            // }
                            return null;
                          },
                          decoration: InputDecoration(
                            hintText: 'Masukkan Kata sandi',
                            hintStyle:
                                GoogleFonts.poppins(color: Colors.grey[400]),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 15.0, horizontal: 15.0),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.0),
                                borderSide:
                                    BorderSide(color: Colors.grey[300]!)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.0),
                                borderSide:
                                    BorderSide(color: Colors.grey[350]!)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.0),
                                borderSide: BorderSide(
                                    color: Colors.blue[600]!, width: 1.5)),
                            errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.0),
                                borderSide: const BorderSide(
                                    color: Colors.red, width: 1.0)),
                            focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10.0),
                                borderSide: const BorderSide(
                                    color: Colors.red, width: 1.5)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Colors.grey[500],
                                  size: 20),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              // TODO: Implement forgot password flow
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Fitur Lupa Kata Sandi belum diimplementasikan.')));
                            },
                            style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap),
                            child: Text('Lupa kata sandi',
                                style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.w500)),
                          ),
                        ),
                        const SizedBox(height: 25),
                        ElevatedButton(
                          // Use the _login method here
                          onPressed: _isLoggingIn
                              ? null
                              : _login, // Disable button while logging in
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            disabledBackgroundColor: Colors
                                .blue[300], // Visual feedback when disabled
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0)),
                            elevation: 3,
                          ),
                          child: _isLoggingIn
                              ? const SizedBox(
                                  // Show loading indicator inside button
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Text(
                                  'Masuk',
                                  style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white),
                                ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.poppins(
                          fontSize: 14, color: Colors.grey[700]),
                      children: <TextSpan>[
                        const TextSpan(text: 'Belum memiliki akun? '),
                        TextSpan(
                          text: 'Daftar',
                          style: GoogleFonts.poppins(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w600),
                          // Use the navigation method
                          recognizer: TapGestureRecognizer()
                            ..onTap = _navigateToRegister,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: screenSize.height * 0.05),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
