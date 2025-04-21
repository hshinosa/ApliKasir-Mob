import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aplikasir_mobile/screen/register/register_step_2.dart'; // Import RegisterStep2Screen
import 'package:flutter/gestures.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _obscurePassword1 = true;
  bool _obscurePassword2 = true;

  // Controllers (tetap sama)
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _storeAddressController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>(); // Tambahkan GlobalKey

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _storeNameController.dispose();
    _storeAddressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Fungsi validasi dan navigasi (diperbarui untuk menggunakan _formKey)
  void _navigateToStep2() {
    // Validasi form terlebih dahulu
    if (!(_formKey.currentState?.validate() ?? false)) {
      // Jika validasi gagal, tampilkan pesan atau biarkan validator TextFormField bekerja
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap perbaiki error pada form!'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    // Ambil semua nilai dari controller (setelah validasi form)
    final String name = _nameController.text.trim();
    final String email = _emailController.text.trim();
    final String phone = _phoneController.text.trim();
    final String storeName = _storeNameController.text.trim();
    final String storeAddress = _storeAddressController.text.trim();
    final String password = _passwordController.text;
    final String confirmPassword = _confirmPasswordController.text;

    // Cek password match (validasi tambahan setelah form valid)
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Konfirmasi kata sandi tidak cocok!'),
            backgroundColor: Colors.redAccent),
      );
      // Set error manual pada field konfirmasi password (opsional)
      // Ini memerlukan cara lain karena TextFormField tidak punya metode setError secara langsung
      // Cara paling mudah adalah mengandalkan validator di TextFormField itu sendiri
      return;
    }

    // --- NAVIGASI KE STEP 2 (Dengan data lengkap) ---
    print('Navigasi ke Step 2');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegisterStep2Screen(
          name: name,
          email: email,
          phoneNumber: phone,
          storeName: storeName,
          storeAddress: storeAddress,
          password: password,
        ),
      ),
    );
  }

  // --- Helper untuk InputDecoration ---
  InputDecoration _buildInputDecoration({
    required String hintText,
    IconData? prefixIconData,
    Widget? suffixIcon, // Tambahkan parameter suffixIcon
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
      prefixIcon: prefixIconData != null
          ? Icon(prefixIconData, size: 18, color: Colors.grey[500])
          : null,
      suffixIcon: suffixIcon, // Gunakan suffixIcon yang diberikan
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(vertical: 15.0, horizontal: 15.0),
      // Style Border
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(color: Colors.grey[350]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: BorderSide(color: Colors.blue[600]!, width: 1.5),
      ),
      // Style Border Error
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: const BorderSide(color: Colors.red, width: 1.0)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: const BorderSide(color: Colors.red, width: 1.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Helper TextStyle untuk Label
    final labelStyle = GoogleFonts.poppins(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Colors.black87,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
          title: Text('Daftar Akun Baru',
              style: GoogleFonts.poppins(
                  color: Colors.blue[700], fontWeight: FontWeight.w600)),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.blue[700]),
          elevation: 2.5,
          centerTitle: true,
          shadowColor: Colors.black26 // Menggunakan Opacity
          ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Form(
              // Bungkus Column dengan Form dan berikan key
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  // --- Registration Form Card ---
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
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- Nama Lengkap Field ---
                        Text('Nama Lengkap', style: labelStyle),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameController,
                          keyboardType: TextInputType.name,
                          textCapitalization: TextCapitalization
                              .words, // Nama biasanya diawali huruf besar
                          decoration: _buildInputDecoration(
                            hintText: 'Masukkan nama lengkap Anda',
                            prefixIconData: Icons.person_outline,
                          ),
                          style: GoogleFonts.poppins(fontSize: 14),
                          validator: (value) {
                            // Tambahkan validator
                            if (value == null || value.trim().isEmpty) {
                              return 'Nama lengkap wajib diisi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // --- Email Field ---
                        Text('Email', style: labelStyle),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _buildInputDecoration(
                            hintText: 'Masukkan alamat email',
                            prefixIconData: Icons.email_outlined,
                          ),
                          style: GoogleFonts.poppins(fontSize: 14),
                          validator: (value) {
                            // Tambahkan validator
                            if (value == null || value.trim().isEmpty) {
                              return 'Email wajib diisi';
                            }
                            // Cek format email
                            final bool emailValid = RegExp(
                                    r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")
                                .hasMatch(value.trim());
                            if (!emailValid) {
                              return 'Format email tidak valid';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // --- Nomor Telepon Field ---
                        Text('Nomor Telepon', style: labelStyle),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ], // Hanya angka
                          decoration: _buildInputDecoration(
                            hintText: 'Contoh: 08123456789',
                            prefixIconData: Icons.phone_outlined,
                          ),
                          style: GoogleFonts.poppins(fontSize: 14),
                          validator: (value) {
                            // Tambahkan validator
                            if (value == null || value.trim().isEmpty) {
                              return 'Nomor telepon wajib diisi';
                            }
                            // Cek panjang minimal (contoh: 9 digit)
                            if (value.trim().length < 9) {
                              return 'Nomor telepon minimal 9 digit';
                            }
                            // Anda bisa tambahkan prefix check (misal '08') jika perlu
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // --- Nama Toko Field ---
                        Text('Nama Toko', style: labelStyle),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _storeNameController,
                          keyboardType: TextInputType.text,
                          textCapitalization: TextCapitalization.words,
                          decoration: _buildInputDecoration(
                            hintText: 'Masukkan nama toko Anda',
                            prefixIconData: Icons.storefront_outlined,
                          ),
                          style: GoogleFonts.poppins(fontSize: 14),
                          validator: (value) {
                            // Tambahkan validator
                            if (value == null || value.trim().isEmpty) {
                              return 'Nama toko wajib diisi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // --- Alamat Toko Field ---
                        Text('Alamat Toko', style: labelStyle),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _storeAddressController,
                          keyboardType: TextInputType.multiline,
                          maxLines: null,
                          minLines: 2,
                          decoration: _buildInputDecoration(
                            hintText: 'Masukkan alamat lengkap toko',
                            // Prefix icon tetap perlu dibuat manual jika butuh alignment khusus
                            prefixIconData: Icons.location_on_outlined,
                          ),
                          style: GoogleFonts.poppins(fontSize: 14),
                          validator: (value) {
                            // Tambahkan validator
                            if (value == null || value.trim().isEmpty) {
                              return 'Alamat toko wajib diisi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // --- Password Field ---
                        Text('Kata Sandi', style: labelStyle),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword1,
                          decoration: _buildInputDecoration(
                            // Gunakan helper
                            hintText: 'Minimal 6 karakter',
                            prefixIconData: Icons.lock_outline,
                            // Tambahkan suffix icon ke helper
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword1
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colors.grey[500],
                                size: 20,
                              ),
                              onPressed: () => setState(
                                  () => _obscurePassword1 = !_obscurePassword1),
                              tooltip: _obscurePassword1
                                  ? 'Tampilkan Kata Sandi'
                                  : 'Sembunyikan Kata Sandi',
                            ),
                          ),
                          style: GoogleFonts.poppins(fontSize: 14),
                          validator: (value) {
                            // Tambahkan validator
                            if (value == null || value.isEmpty) {
                              return 'Kata sandi wajib diisi';
                            }
                            if (value.length < 6) {
                              return 'Kata sandi minimal 6 karakter';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // --- Konfirmasi Password Field ---
                        Text('Konfirmasi Kata Sandi', style: labelStyle),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscurePassword2,
                          decoration: _buildInputDecoration(
                            // Gunakan helper
                            hintText: 'Masukkan ulang kata sandi',
                            prefixIconData: Icons.lock_outline,
                            // Tambahkan suffix icon ke helper
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword2
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colors.grey[500],
                                size: 20,
                              ),
                              onPressed: () => setState(
                                  () => _obscurePassword2 = !_obscurePassword2),
                              tooltip: _obscurePassword2
                                  ? 'Tampilkan Konfirmasi'
                                  : 'Sembunyikan Konfirmasi',
                            ),
                          ),
                          style: GoogleFonts.poppins(fontSize: 14),
                          validator: (value) {
                            // Tambahkan validator
                            if (value == null || value.isEmpty) {
                              return 'Konfirmasi kata sandi wajib diisi';
                            }
                            // Cek kecocokan dengan password field pertama
                            if (value != _passwordController.text) {
                              return 'Kata sandi tidak cocok';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 30),

                        // --- Tombol Lanjut ---
                        ElevatedButton(
                          onPressed:
                              _navigateToStep2, // Panggil fungsi navigasi
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            elevation: 3,
                          ),
                          child: Text(
                            'Lanjut',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ----- TapGestureRecognizer Import -----
// (Pastikan import ini ada jika belum)
