// lib/fitur/profile/providers/profile_provider.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart'; // Untuk logout

import 'package:aplikasir_mobile/model/user_model.dart';
import 'package:aplikasir_mobile/helper/db_helper.dart';
import 'package:aplikasir_mobile/utils/auth_utils.dart'; // Untuk hashPassword
// import 'package:aplikasir_mobile/services/api_services.dart'; // Jika ada sinkronisasi profil ke server

class ProfileProvider extends ChangeNotifier {
  final int userId;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  // final ApiService _apiService = ApiService(); // Uncomment jika ada API service

  User? _currentUser;
  bool _isLoading = true;
  String? _errorMessage;
  String? _successMessage;

  // Untuk Edit Profile
  File? _newTempProfileImageFile; // File temporary hasil picker/cropper di EditProfileScreen
  bool _isUpdatingProfile = false;

  // Getters
  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  File? get newTempProfileImageFile => _newTempProfileImageFile;
  bool get isUpdatingProfile => _isUpdatingProfile;

  ProfileProvider({required this.userId}) {
    loadUserData();
  }

  void _clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    // notifyListeners(); // Biasanya dipanggil oleh method utama
  }

  Future<void> loadUserData() async {
    _isLoading = true;
    _clearMessages();
    notifyListeners();
    try {
      _currentUser = await _dbHelper.getUserById(userId);
      if (_currentUser == null) {
        _errorMessage = "Data pengguna tidak ditemukan.";
      }
    } catch (e) {
      _errorMessage = "Gagal memuat data pengguna: ${e.toString()}";
      print("Error loading user data in ProfileProvider: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Untuk EditProfileScreen: memilih gambar dari galeri/kamera
  Future<File?> pickImageForEdit(ImageSource source) async {
    // Hapus file temporary lama jika ada
    if (_newTempProfileImageFile != null && await _newTempProfileImageFile!.exists()) {
      try {
        await _newTempProfileImageFile!.delete();
      } catch (e) { print("Error deleting old temp image: $e");}
    }
    _newTempProfileImageFile = null;

    try {
      final pickedFile = await ImagePicker().pickImage(source: source, imageQuality: 80);
      if (pickedFile != null) {
        _newTempProfileImageFile = File(pickedFile.path);
        notifyListeners(); // Untuk update UI preview di EditProfileScreen
        return _newTempProfileImageFile;
      }
    } catch (e) {
      _clearMessages();
      _errorMessage = "Gagal memilih gambar: ${e.toString()}";
      notifyListeners();
    }
    return null;
  }

  // Untuk EditProfileScreen: mengeset file hasil crop sebagai temporary image
  Future<void> setNewCroppedImage(File? croppedFile) async {
    // Hapus file temporary lama (hasil picker) jika ada dan beda dari file crop
    if (_newTempProfileImageFile != null && _newTempProfileImageFile != croppedFile && await _newTempProfileImageFile!.exists()) {
       try {
        _newTempProfileImageFile!.delete();
      } catch (e) { print("Error deleting picker temp image after crop: $e");}
    }
    _newTempProfileImageFile = croppedFile;
    notifyListeners(); // Update UI preview di EditProfileScreen
  }

  // Untuk EditProfileScreen: membersihkan pilihan gambar temporary
  void clearTemporaryImage() {
    if (_newTempProfileImageFile != null && _newTempProfileImageFile!.existsSync()) {
      try {
        _newTempProfileImageFile!.delete();
      } catch (e) { print("Error deleting temp image on clear: $e");}
    }
    _newTempProfileImageFile = null;
    notifyListeners();
  }

  Future<bool> updateUserProfile({
    required String name,
    required String email,
    required String phoneNumber,
    required String storeName,
    required String storeAddress,
    String? newPassword, // Password baru, bisa null jika tidak diubah
    File? newProfileImage, // File BARU dari EditProfileScreen (sudah di-crop jika perlu)
    bool removeCurrentImage = false, // Flag jika user ingin menghapus gambar profil
  }) async {
    if (_currentUser == null) {
      _errorMessage = "Tidak ada data pengguna untuk diperbarui.";
      notifyListeners();
      return false;
    }

    _isUpdatingProfile = true;
    _clearMessages();
    notifyListeners();

    String finalPasswordHash = _currentUser!.passwordHash;
    if (newPassword != null && newPassword.isNotEmpty) {
      // Validasi panjang password bisa ditambahkan di UI atau di sini
      finalPasswordHash = hashPassword(newPassword);
    }

    String? finalImagePath = _currentUser!.profileImagePath;

    try {
      if (removeCurrentImage) {
        // Hapus gambar lama dari storage jika ada
        if (_currentUser!.profileImagePath != null) {
          final oldImageFile = File(_currentUser!.profileImagePath!);
          if (await oldImageFile.exists()) await oldImageFile.delete();
        }
        finalImagePath = null;
      } else if (newProfileImage != null) {
        // Ada gambar baru, simpan ke lokasi permanen
        final documentsDir = await getApplicationDocumentsDirectory();
        final imagesDir = Directory(p.join(documentsDir.path, 'profile_images'));
        if (!await imagesDir.exists()) await imagesDir.create(recursive: true);
        
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final permanentPath = p.join(imagesDir.path, 'profile_${userId}_$timestamp.png');
        
        final permanentFile = await newProfileImage.copy(permanentPath);
        finalImagePath = permanentFile.path;

        // Hapus gambar lama dari storage jika ada dan beda path
        if (_currentUser!.profileImagePath != null && _currentUser!.profileImagePath != finalImagePath) {
          final oldImageFile = File(_currentUser!.profileImagePath!);
          if (await oldImageFile.exists()) await oldImageFile.delete();
        }
        // Hapus file temporary newProfileImage setelah dicopy
        if (await newProfileImage.exists()){
            await newProfileImage.delete();
            _newTempProfileImageFile = null; // Reset di provider
        }
      }

      final updatedUser = User(
        id: userId,
        name: name,
        email: email,
        phoneNumber: phoneNumber,
        storeName: storeName,
        storeAddress: storeAddress,
        passwordHash: finalPasswordHash,
        profileImagePath: finalImagePath,
        createdAt: _currentUser!.createdAt, // Tetap gunakan createdAt asli
        updatedAt: DateTime.now(), // Set waktu update
      );

      // Update ke database lokal
      final rowsAffected = await _dbHelper.updateUser(updatedUser);

      if (rowsAffected > 0) {
        _currentUser = updatedUser; // Update state pengguna saat ini di provider
        _successMessage = "Profil berhasil diperbarui!";
        _isUpdatingProfile = false;
        notifyListeners();
        return true;
      } else {
        throw Exception("Gagal memperbarui data pengguna di database lokal.");
      }
    } catch (e) {
      _errorMessage = "Gagal menyimpan profil: ${e.toString()}";
      // Pertimbangkan rollback gambar jika gagal simpan DB (kompleks)
      _isUpdatingProfile = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> logout() async {
    _isLoading = true; // Bisa pakai _isLoggingOut
    notifyListeners();
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('isLoggedIn');
      await prefs.remove('loggedInUserId');
      await prefs.remove('accessToken'); // Jika ada token API
      // Hapus data sensitif lain jika ada
      _currentUser = null;
      _isLoading = false;
      notifyListeners();
      print("Logout successful from ProfileProvider.");
      return true;
    } catch (e) {
      _errorMessage = "Gagal melakukan logout: ${e.toString()}";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}