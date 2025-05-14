// lib/fitur/profile/screens/profile_screen.dart
import 'dart:io';
import 'package:aplikasir_mobile/model/user_model.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:aplikasir_mobile/fitur/login/screens/login_screen.dart';
import 'edit_profile_screen.dart';
import '../providers/profile_provider.dart'; // Impor ProfileProvider
// Hapus impor model User jika tidak digunakan langsung

class ProfileScreen extends StatelessWidget {
  // Ubah nama dari AccountScreen
  final int userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProfileProvider(userId: userId),
      child: const _ProfileScreenContent(),
    );
  }
}

class _ProfileScreenContent extends StatelessWidget {
  const _ProfileScreenContent();

  // Pindahkan _showLogoutConfirmationDialog ke sini atau buat sebagai static/top-level function
  Future<bool?> _showLogoutConfirmationDialog(
      BuildContext context, ProfileProvider provider) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          elevation: 5.0,
          title: Text('Konfirmasi Keluar',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 18.0,
                  color: Colors.blue.shade800)),
          content: Text('Apakah Anda yakin ingin keluar dari akun ini?',
              style: GoogleFonts.poppins(
                  fontSize: 14.0, color: Colors.grey.shade700, height: 1.4)),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      side: BorderSide(color: Colors.grey.shade300))),
              child: Text('Batal',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500, fontSize: 14)),
            ),
            TextButton(
              onPressed: provider.isLoading
                  ? null
                  : () async {
                      // Gunakan provider.isLoading
                      Navigator.pop(dialogContext, true); // Tutup dialog dulu
                      bool loggedOut = await provider.logout();
                      if (loggedOut && dialogContext.mounted) {
                        // Gunakan context asli untuk navigasi
                        Navigator.pushAndRemoveUntil(
                          dialogContext, // Sebaiknya gunakan context dari build utama
                          MaterialPageRoute(
                              builder: (context) => const LoginScreen()),
                          (Route<dynamic> route) => false,
                        );
                      } else if (!loggedOut &&
                          dialogContext.mounted &&
                          provider.errorMessage != null) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                              content: Text(provider.errorMessage!),
                              backgroundColor: Colors.redAccent),
                        );
                      }
                    },
              style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.red.shade600,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0)),
                  elevation: 2),
              child: provider.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white)))
                  : Text('Ya, Keluar',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 14)),
            ),
          ],
        );
      },
    );
  }

  void _navigateToEditProfile(
      BuildContext context, ProfileProvider provider) async {
    if (provider.currentUser != null) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          // EditProfileScreen akan membuat ProfileProvider-nya sendiri atau
          // kita bisa pass provider yang sudah ada jika EditProfileScreen tidak punya provider sendiri
          // Untuk kasus ini, EditProfileScreen akan dibuat sebagai StatefulWidget yang mengelola state formnya sendiri
          // dan memanggil method update di ProfileProvider ini.
          builder: (_) => EditProfileScreen(initialUser: provider.currentUser!),
        ),
      );
      if (result == true && context.mounted) {
        provider.loadUserData(); // Refresh data di ProfileProvider
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data pengguna belum dimuat.')),
      );
    }
  }

  Widget _buildProfileCard(
      BuildContext context, User user, ProfileProvider provider) {
    ImageProvider? profileImage;
    if (user.profileImagePath != null && user.profileImagePath!.isNotEmpty) {
      final imageFile = File(user.profileImagePath!);
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
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundImage: profileImage,
            backgroundColor: Colors.grey.shade200,
            child: profileImage == null
                ? Icon(Icons.person_rounded,
                    size: 35, color: Colors.grey.shade500)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name,
                    style: GoogleFonts.poppins(
                        fontSize: MediaQuery.of(context).size.width * 0.045,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(user.email,
                    style: GoogleFonts.poppins(
                        fontSize: MediaQuery.of(context).size.width * 0.035,
                        color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.edit_outlined, color: Colors.blue.shade700),
            tooltip: "Edit Profil",
            onPressed: () => _navigateToEditProfile(context, provider),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required BuildContext context, // Tambahkan context
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
              offset: const Offset(0, 2))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12.0),
          splashColor: iconBgColor.withOpacity(0.3),
          highlightColor: iconBgColor.withOpacity(0.15),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(8.0)),
                  child: Icon(icon,
                      color: iconColor,
                      size: MediaQuery.of(context).size.width *
                          0.055), // Ukuran ikon disesuaikan
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(text,
                      style: GoogleFonts.poppins(
                          fontSize: MediaQuery.of(context).size.width * 0.038,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87)),
                ),
                if (trailing != null) trailing,
                if (trailing != null) const SizedBox(width: 8),
                if (text != 'Keluar') // Jangan tampilkan chevron untuk logout
                  Icon(Icons.chevron_right,
                      color: Colors.grey.shade400,
                      size: MediaQuery.of(context).size.width * 0.05),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();

    // Listener untuk pesan dari provider (jika ada)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (profileProvider.errorMessage != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(profileProvider.errorMessage!),
              backgroundColor: Colors.redAccent),
        );
        // provider.clearMessages(); // Opsional
      }
      if (profileProvider.successMessage != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(profileProvider.successMessage!),
              backgroundColor: Colors.green),
        );
        // provider.clearMessages();
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: profileProvider.isLoading && profileProvider.currentUser == null
          ? const Center(child: CircularProgressIndicator())
          : profileProvider.currentUser == null
              ? Center(
                  child: Column(
                  // Tambahkan tombol refresh jika gagal load awal
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                        profileProvider.errorMessage ??
                            'Gagal memuat data pengguna.',
                        style:
                            GoogleFonts.poppins(color: Colors.grey.shade600)),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                        onPressed: () => profileProvider.loadUserData(),
                        icon: const Icon(Icons.refresh),
                        label: const Text("Coba Lagi"))
                  ],
                ))
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                      16.0, 20.0, 16.0, 16.0), // Sesuaikan padding atas
                  child: Column(
                    children: [
                      _buildProfileCard(context, profileProvider.currentUser!,
                          profileProvider),
                      const SizedBox(height: 24),
                      // --- Item Pengaturan ---
                      _buildSettingsItem(
                          context: context,
                          icon: Icons.store_outlined,
                          iconBgColor: Colors.teal.shade50,
                          iconColor: Colors.teal.shade700,
                          text: 'Informasi Toko',
                          onTap: () =>
                              _navigateToEditProfile(context, profileProvider)),
                      _buildSettingsItem(
                          context: context,
                          icon: Icons.lock_outline_rounded,
                          iconBgColor: Colors.orange.shade50,
                          iconColor: Colors.orange.shade700,
                          text: 'Ubah Kata Sandi',
                          onTap: () => _navigateToEditProfile(context,
                              profileProvider)), // Arahkan ke edit juga
                      _buildSettingsItem(
                          context: context,
                          icon: Icons.notifications_outlined,
                          iconBgColor: Colors.blue.shade50,
                          iconColor: Colors.blue.shade700,
                          text: 'Notifikasi',
                          onTap: () {}),
                      _buildSettingsItem(
                          context: context,
                          icon: Icons.shield_outlined,
                          iconBgColor: Colors.purple.shade50,
                          iconColor: Colors.purple.shade700,
                          text: 'Privasi & Keamanan',
                          onTap: () {}),
                      _buildSettingsItem(
                          context: context,
                          icon: Icons.help_outline_rounded,
                          iconBgColor: Colors.green.shade50,
                          iconColor: Colors.green.shade700,
                          text: 'Bantuan & Dukungan',
                          onTap: () {}),
                      const SizedBox(height: 16),
                      _buildSettingsItem(
                          context: context,
                          icon: Icons.logout_rounded,
                          iconBgColor: Colors.red.shade50,
                          iconColor: Colors.red.shade700,
                          text: 'Keluar',
                          onTap: () => _showLogoutConfirmationDialog(
                              context, profileProvider)),
                    ],
                  ),
                ),
    );
  }
}
