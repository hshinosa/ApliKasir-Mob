// lib/fitur/register/screens/register_step_1.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart'; // Impor Provider

import 'register_step_2.dart';
import '../providers/register_provider.dart'; // Impor RegisterProvider

class RegisterScreen extends StatelessWidget {
  // Ubah jadi StatelessWidget
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Sediakan RegisterProvider untuk step 1 dan step 2
    return ChangeNotifierProvider(
      create: (_) => RegisterProvider(),
      child: const _RegisterScreenContent(),
    );
  }
}

class _RegisterScreenContent extends StatefulWidget {
  const _RegisterScreenContent({Key? key}) : super(key: key);

  @override
  State<_RegisterScreenContent> createState() => _RegisterScreenContentState();
}

class _RegisterScreenContentState extends State<_RegisterScreenContent> {
  // Controller tetap di state UI lokal
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _storeAddressController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _obscurePassword1 = true;
  bool _obscurePassword2 = true;

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

  void _navigateToStep2() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Harap perbaiki error pada form!'),
            backgroundColor: Colors.orangeAccent),
      );
      return;
    }
    // Tidak perlu validasi password match di sini, bisa di provider atau step 2

    // Ambil RegisterProvider dari context
    final registerProvider = context.read<RegisterProvider>();
    registerProvider.setDataFromStep1(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      storeName: _storeNameController.text.trim(),
      storeAddress: _storeAddressController.text.trim(),
      password: _passwordController.text, // Kirim password ke provider
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        // RegisterStep2Screen akan mengakses RegisterProvider yang sama dari context
        builder: (context) => const RegisterStep2Screen(),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    /* ... (SAMA seperti sebelumnya) ... */
    required String hintText,
    IconData? prefixIconData,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
      prefixIcon: prefixIconData != null
          ? Icon(prefixIconData, size: 18, color: Colors.grey[500])
          : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(vertical: 15.0, horizontal: 15.0),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide(color: Colors.grey[300]!)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide(color: Colors.grey[350]!)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide(color: Colors.blue[600]!, width: 1.5)),
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
    final labelStyle = GoogleFonts.poppins(
        fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
          title: Text('Daftar Akun (Langkah 1)',
              style: GoogleFonts.poppins(
                  color: Colors.blue[700], fontWeight: FontWeight.w600)),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.blue[700]),
          elevation: 1.0,
          centerTitle: true,
          shadowColor: Colors.black26),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(25.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.0),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 8,
                            offset: const Offset(0, 3))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nama Lengkap', style: labelStyle),
                        const SizedBox(height: 8),
                        TextFormField(
                            controller: _nameController,
                            keyboardType: TextInputType.name,
                            textCapitalization: TextCapitalization.words,
                            decoration: _buildInputDecoration(
                                hintText: 'Masukkan nama lengkap Anda',
                                prefixIconData: Icons.person_outline),
                            style: GoogleFonts.poppins(fontSize: 14),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Nama lengkap wajib diisi'
                                : null),
                        const SizedBox(height: 20),
                        Text('Email', style: labelStyle),
                        const SizedBox(height: 8),
                        TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _buildInputDecoration(
                                hintText: 'Masukkan alamat email',
                                prefixIconData: Icons.email_outlined),
                            style: GoogleFonts.poppins(fontSize: 14),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty)
                                return 'Email wajib diisi';
                              if (!RegExp(
                                      r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")
                                  .hasMatch(v.trim()))
                                return 'Format email tidak valid';
                              return null;
                            }),
                        const SizedBox(height: 20),
                        Text('Nomor Telepon', style: labelStyle),
                        const SizedBox(height: 8),
                        TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            decoration: _buildInputDecoration(
                                hintText: 'Contoh: 08123456789',
                                prefixIconData: Icons.phone_outlined),
                            style: GoogleFonts.poppins(fontSize: 14),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty)
                                return 'Nomor telepon wajib diisi';
                              if (v.trim().length < 9)
                                return 'Nomor telepon minimal 9 digit';
                              return null;
                            }),
                        const SizedBox(height: 20),
                        Text('Nama Toko', style: labelStyle),
                        const SizedBox(height: 8),
                        TextFormField(
                            controller: _storeNameController,
                            keyboardType: TextInputType.text,
                            textCapitalization: TextCapitalization.words,
                            decoration: _buildInputDecoration(
                                hintText: 'Masukkan nama toko Anda',
                                prefixIconData: Icons.storefront_outlined),
                            style: GoogleFonts.poppins(fontSize: 14),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Nama toko wajib diisi'
                                : null),
                        const SizedBox(height: 20),
                        Text('Alamat Toko', style: labelStyle),
                        const SizedBox(height: 8),
                        TextFormField(
                            controller: _storeAddressController,
                            keyboardType: TextInputType.streetAddress,
                            maxLines: 2,
                            minLines: 1,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: _buildInputDecoration(
                                hintText: 'Masukkan alamat lengkap toko',
                                prefixIconData: Icons.location_on_outlined),
                            style: GoogleFonts.poppins(fontSize: 14),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Alamat toko wajib diisi'
                                : null),
                        const SizedBox(height: 20),
                        Text('Kata Sandi', style: labelStyle),
                        const SizedBox(height: 8),
                        TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword1,
                            decoration: _buildInputDecoration(
                                hintText: 'Minimal 6 karakter',
                                prefixIconData: Icons.lock_outline,
                                suffixIcon: IconButton(
                                    icon: Icon(
                                        _obscurePassword1
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: Colors.grey[500],
                                        size: 20),
                                    onPressed: () => setState(() =>
                                        _obscurePassword1 =
                                            !_obscurePassword1))),
                            style: GoogleFonts.poppins(fontSize: 14),
                            validator: (v) {
                              if (v == null || v.isEmpty)
                                return 'Kata sandi wajib diisi';
                              if (v.length < 6)
                                return 'Kata sandi minimal 6 karakter';
                              return null;
                            }),
                        const SizedBox(height: 20),
                        Text('Konfirmasi Kata Sandi', style: labelStyle),
                        const SizedBox(height: 8),
                        TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscurePassword2,
                            decoration: _buildInputDecoration(
                                hintText: 'Masukkan ulang kata sandi',
                                prefixIconData: Icons.lock_outline,
                                suffixIcon: IconButton(
                                    icon: Icon(
                                        _obscurePassword2
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: Colors.grey[500],
                                        size: 20),
                                    onPressed: () => setState(() =>
                                        _obscurePassword2 =
                                            !_obscurePassword2))),
                            style: GoogleFonts.poppins(fontSize: 14),
                            validator: (v) {
                              if (v == null || v.isEmpty)
                                return 'Konfirmasi kata sandi wajib diisi';
                              if (v != _passwordController.text)
                                return 'Kata sandi tidak cocok';
                              return null;
                            }),
                        const SizedBox(height: 30),
                        ElevatedButton(
                          onPressed: _navigateToStep2,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.0)),
                              elevation: 3),
                          child: Text('Lanjut ke Langkah 2',
                              style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  RichText(
                    // Link kembali ke Login
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: Colors.grey[700]),
                      children: <TextSpan>[
                        const TextSpan(text: 'Sudah punya akun? '),
                        TextSpan(
                            text: 'Masuk di sini',
                            style: GoogleFonts.poppins(
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w600),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.pop(
                                    context); // Kembali ke layar sebelumnya (Login)
                              }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
