// lib/fitur/login/login_screen.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart'; // Import Provider

// --- Imports for Register & Home ---
import '../../register/screens/register_step_1.dart'; // Sesuaikan path
import '../../homepage/homepage_screen.dart';   // Sesuaikan path
// --- Impor Provider ---
import '../providers/login_provider.dart';   // Sesuaikan path

class LoginScreen extends StatelessWidget {
  final String? initialEmail;

  const LoginScreen({Key? key, this.initialEmail}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Sediakan LoginProvider di sini agar bisa diakses oleh _LoginScreenContent
    return ChangeNotifierProvider(
      create: (_) => LoginProvider(initialEmail: initialEmail),
      child: const _LoginScreenContent(), // UI sebenarnya ada di sini
    );
  }
}

class _LoginScreenContent extends StatefulWidget {
  // Tidak perlu initialEmail lagi di sini, sudah dihandle Provider
  const _LoginScreenContent({Key? key}) : super(key: key);

  @override
  State<_LoginScreenContent> createState() => _LoginScreenContentState();
}

class _LoginScreenContentState extends State<_LoginScreenContent> {
  // _obscurePassword dan _isLoggingIn akan diambil dari Provider
  // _emailController dan _passwordController akan diambil dari Provider
  // _formKey akan diambil dari Provider

  // Fungsi navigasi bisa tetap di UI
  void _navigateToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
  }

  // Helper Snackbar (bisa tetap di UI)
  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.poppins()), backgroundColor: Colors.green),
    );
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.poppins()), backgroundColor: Colors.redAccent),
    );
  }

  Future<void> _attemptLogin(LoginProvider provider) async {
      final success = await provider.login(); // login() di provider sudah handle formKey
      if (!mounted) return;

      if (success) {
          final user = provider.loggedInUser;
          if (user != null && user.id != null) {
              _showSuccessSnackbar('Login berhasil! Selamat datang ${user.name}.');
              Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => HomePage(userId: user.id!)),
                  (Route<dynamic> route) => false,
              );
          } else {
             // Ini skenario yang aneh, user null setelah login sukses
             _showErrorSnackbar('Terjadi kesalahan internal setelah login.');
          }
      } else {
          if (provider.errorMessage != null) {
              _showErrorSnackbar(provider.errorMessage!);
          } else if (!(provider.formKey.currentState?.validate() ?? true)) {
              // Tidak perlu tampilkan snackbar jika errornya dari validasi form
              // Karena validator TextFormField sudah menampilkan pesan errornya
          } else {
              // Error umum jika bukan dari validasi atau pesan spesifik
              _showErrorSnackbar('Login gagal. Periksa kembali data Anda.');
          }
      }
  }


  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    // Gunakan context.watch untuk mendapatkan instance LoginProvider dan rebuild saat ada perubahan
    final loginProvider = context.watch<LoginProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: loginProvider.formKey, // Gunakan formKey dari provider
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
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
                          controller: loginProvider.emailController, // Dari Provider
                          keyboardType: TextInputType.emailAddress,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Email atau nomor telepon tidak boleh kosong';
                            }
                            return null;
                          },
                          decoration: InputDecoration( /* Style sama seperti sebelumnya */
                            hintText: 'Masukkan email atau nomor telepon',
                            hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 15.0),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: Colors.grey[300]!)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: Colors.grey[350]!)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: Colors.blue[600]!, width: 1.5)),
                            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: const BorderSide(color: Colors.red, width: 1.0)),
                            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
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
                          controller: loginProvider.passwordController, // Dari Provider
                          obscureText: loginProvider.obscurePassword, // Dari Provider
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Kata sandi tidak boleh kosong';
                            }
                            return null;
                          },
                          decoration: InputDecoration( /* Style sama seperti sebelumnya */
                            hintText: 'Masukkan Kata sandi',
                            hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 15.0),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: Colors.grey[300]!)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: Colors.grey[350]!)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: Colors.blue[600]!, width: 1.5)),
                            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: const BorderSide(color: Colors.red, width: 1.0)),
                            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                  loginProvider.obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Colors.grey[500],
                                  size: 20),
                              onPressed: () => loginProvider.togglePasswordVisibility(),
                            ),
                          ),
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Fitur Lupa Kata Sandi belum diimplementasikan.')));
                            },
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                            child: Text('Lupa kata sandi',
                                style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.w500)),
                          ),
                        ),
                        const SizedBox(height: 25),
                        ElevatedButton(
                          onPressed: loginProvider.isLoading ? null : () => _attemptLogin(loginProvider),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            disabledBackgroundColor: Colors.blue[300],
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                            elevation: 3,
                          ),
                          child: loginProvider.isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
                      children: <TextSpan>[
                        const TextSpan(text: 'Belum memiliki akun? '),
                        TextSpan(
                          text: 'Daftar',
                          style: GoogleFonts.poppins(color: Colors.blue[700], fontWeight: FontWeight.w600),
                          recognizer: TapGestureRecognizer()..onTap = _navigateToRegister,
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