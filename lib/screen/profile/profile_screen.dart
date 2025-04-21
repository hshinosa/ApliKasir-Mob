import 'dart:io'; // Untuk FileImage
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Untuk SharedPreferences

// --- Impor yang Diperlukan ---
import 'package:aplikasir_mobile/helper/db_helper.dart'; // Sesuaikan path jika perlu
import 'package:aplikasir_mobile/model/user_model.dart'; // Sesuaikan path jika perlu
import 'package:aplikasir_mobile/screen/login/login_screen.dart'; // Untuk logout
import 'package:aplikasir_mobile/screen/profile/edit_profile_screen.dart'; // Layar edit yang akan dibuat

class AccountScreen extends StatefulWidget {
  // --- Tambahkan userId ---
  final int userId;

  const AccountScreen({super.key, required this.userId});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  // --- State untuk menyimpan data user dan status loading ---
  User? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // --- Fungsi untuk mengambil data pengguna dari DB ---
  Future<void> _loadUserData() async {
    // Pastikan widget masih terpasang sebelum setState
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = await DatabaseHelper.instance.getUserById(widget.userId);
      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading user data: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data pengguna: $e')),
        );
      }
    }
  }

  // --- Fungsi Logout dengan Dialog yang Disesuaikan Gayanya ---
  Future<void> _logout() async {
    // Tampilkan dialog konfirmasi
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible:
          false, // Opsional: Mencegah menutup dialog dgn tap di luar
      builder: (BuildContext dialogContext) {
        // Beri nama context yang berbeda
        return AlertDialog(
          // --- Modifikasi Gaya AlertDialog ---
          backgroundColor: Colors.white, // Warna latar belakang dialog
          shape: RoundedRectangleBorder(
            // Bentuk sudut dialog
            borderRadius: BorderRadius.circular(15.0),
          ),
          elevation: 5.0, // Efek shadow dialog

          // --- Judul Dialog ---
          title: Text(
            'Konfirmasi Keluar',
            style: GoogleFonts.poppins(
              // Gunakan GoogleFonts atau TextStyle biasa
              fontWeight: FontWeight.w600,
              fontSize: 18.0,
              color: Colors.blue.shade800, // Warna judul
            ),
          ),

          // --- Konten/Isi Dialog ---
          content: Text(
            'Apakah Anda yakin ingin keluar dari akun ini?',
            style: GoogleFonts.poppins(
              fontSize: 14.0,
              color: Colors.grey.shade700, // Warna teks konten
              height: 1.4, // Jarak antar baris (jika teks panjang)
            ),
          ),

          // --- Tombol Aksi (Actions) ---
          actionsPadding: const EdgeInsets.symmetric(
              horizontal: 16.0, vertical: 12.0), // Padding di sekitar tombol
          actions: [
            // Tombol Batal
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false), // Gunakan dialogContext
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade600, // Warna teks tombol
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    side: BorderSide(
                        color: Colors.grey.shade300) // Opsional: border
                    ),
              ),
              child: Text(
                'Batal',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),

            // Tombol Ya, Keluar
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, true), // Gunakan dialogContext
              style: TextButton.styleFrom(
                foregroundColor: Colors.white, // Warna teks tombol
                backgroundColor: Colors.red.shade600, // Warna latar tombol
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                elevation: 2, // Shadow tombol
              ),
              child: Text(
                'Ya, Keluar',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, // Sedikit lebih tebal
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      // --- HAPUS DATA LOGIN DARI PREFERENCES ---
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', false); // Set jadi false
      await prefs.remove('loggedInUserId'); // Hapus ID pengguna
      print('Logged out. Cleared login status.'); // Logging
      // --- AKHIR BAGIAN HAPUS DATA ---

      // Pastikan widget masih terpasang sebelum navigasi
      if (!mounted) return;

      // Navigasi kembali ke LoginScreen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  // --- Fungsi Navigasi ke Edit Profile ---
  void _navigateToEditProfile() async {
    if (_currentUser != null) {
      // Gunakan Navigator.push dan tunggu hasilnya (jika ada perubahan)
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditProfileScreen(
            // Kirim data user saat ini ke layar edit
            initialUser: _currentUser!,
          ),
        ),
      );

      // Jika halaman edit dikembalikan dengan hasil 'true' (artinya ada update)
      // Muat ulang data pengguna untuk menampilkan perubahan
      if (result == true && mounted) {
        _loadUserData();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data pengguna belum dimuat.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      // --- Tampilkan loading atau konten ---
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentUser == null
              ? Center(
                  child: Text(
                  'Gagal memuat data pengguna.',
                  style: GoogleFonts.poppins(color: Colors.grey.shade600),
                ))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      // Gunakan _currentUser untuk menampilkan data
                      _buildProfileCard(_currentUser!),
                      const SizedBox(height: 24),
                      _buildSettingsItem(
                        icon: Icons.info_outline,
                        iconBgColor: Colors.blue.shade50,
                        iconColor: Colors.blue.shade700,
                        text: 'Privasi & Keamanan',
                        onTap: () {/* Navigasi jika perlu */},
                      ),
                      _buildSettingsItem(
                        icon: Icons.flag_outlined,
                        iconBgColor: Colors.blue.shade50,
                        iconColor: Colors.blue.shade700,
                        text: 'Bahasa',
                        trailing: Text('Indonesia',
                            style: GoogleFonts.poppins(
                                fontSize: 14, color: Colors.grey.shade600)),
                        onTap: () {/* Navigasi jika perlu */},
                      ),
                      _buildSettingsItem(
                        icon: Icons.notifications_outlined,
                        iconBgColor: Colors.blue.shade50,
                        iconColor: Colors.blue.shade700,
                        text: 'Preferensi Notifikasi',
                        onTap: () {/* Navigasi jika perlu */},
                      ),
                      _buildSettingsItem(
                        icon: Icons.help_outline,
                        iconBgColor: Colors.blue.shade50,
                        iconColor: Colors.blue.shade700,
                        text: 'Yang Sering Ditanyakan',
                        onTap: () {/* Navigasi jika perlu */},
                      ),
                      _buildSettingsItem(
                        icon: Icons.sync,
                        iconBgColor: Colors.blue.shade50,
                        iconColor: Colors.blue.shade700,
                        text: 'Sinkronisasi',
                        onTap: () {/* Aksi sinkronisasi */},
                      ),
                      const SizedBox(height: 16),
                      // --- Tombol Logout memanggil _logout ---
                      _buildSettingsItem(
                        icon: Icons.logout,
                        iconBgColor: Colors.red.shade50,
                        iconColor: Colors.red.shade700,
                        text: 'Keluar',
                        onTap: _logout, // Panggil fungsi logout
                      ),
                    ],
                  ),
                ),
    );
  }

  // --- Helper Widget untuk Profile Card (Menerima User) ---
  Widget _buildProfileCard(User user) {
    ImageProvider? profileImage;
    if (user.profileImagePath != null && user.profileImagePath!.isNotEmpty) {
      final imageFile = File(user.profileImagePath!);
      // Cek apakah file ada sebelum digunakan
      if (imageFile.existsSync()) {
        profileImage = FileImage(imageFile);
      }
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Profile Picture
          CircleAvatar(
            radius: 35,
            // Gunakan gambar dari DB atau placeholder
            backgroundImage: profileImage,
            // Tampilkan placeholder jika tidak ada gambar
            backgroundColor: Colors.grey.shade200,
            child: profileImage == null
                ? Icon(Icons.person, size: 35, color: Colors.grey.shade500)
                : null,
          ),
          const SizedBox(width: 16),
          // Name and Email Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name, // Gunakan nama dari DB
                  style: GoogleFonts.poppins(
                    fontSize: MediaQuery.of(context).size.width * 0.045,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  user.email, // Gunakan email dari DB
                  style: GoogleFonts.poppins(
                    fontSize: MediaQuery.of(context).size.width * 0.035,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Edit Button memanggil _navigateToEditProfile
          IconButton(
            icon: Icon(Icons.edit_outlined, color: Colors.blue.shade700),
            onPressed: _navigateToEditProfile, // Panggil fungsi navigasi
          ),
        ],
      ),
    );
  }

  // --- Helper Widget _buildSettingsItem (Tetap Sama) ---
  Widget _buildSettingsItem({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String text,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12.0),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Icon(icon,
                      color: iconColor,
                      size: MediaQuery.of(context).size.width * 0.06),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    text,
                    style: GoogleFonts.poppins(
                      fontSize: MediaQuery.of(context).size.width * 0.04,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
                if (trailing != null) const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
