// lib/fitur/register/providers/register_provider.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// path_provider dan path mungkin tidak diperlukan di sini jika file hanya temporary
// dan langsung dikirim ke API atau disimpan oleh service lain setelah registrasi berhasil.
// Namun, jika ada proses penyimpanan lokal sementara sebelum kirim ke API, maka diperlukan.
// Untuk contoh ini, kita asumsikan file temporary langsung dikirim.

import 'package:aplikasir_mobile/services/api_services.dart'; // Sesuaikan path

class RegisterProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  // Data dari Step 1
  String name = '';
  String email = '';
  String phoneNumber = '';
  String storeName = '';
  String storeAddress = '';
  String password = '';

  // Data dari Step 2
  File? _profileImageTemporaryFile; // File temporary hasil picker/cropper

  bool _isLoading = false; // Untuk proses registrasi ke API
  String? _errorMessage;
  String? _successMessage;

  // Getters
  File? get profileImageTemporaryFile => _profileImageTemporaryFile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  void _clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    // notifyListeners(); // Biasanya dipanggil oleh method utama
  }

  // Dipanggil dari RegisterStep1Screen saat menekan "Lanjut"
  void setDataFromStep1({
    required String name,
    required String email,
    required String phoneNumber,
    required String storeName,
    required String storeAddress,
    required String password,
  }) {
    this.name = name;
    this.email = email;
    this.phoneNumber = phoneNumber;
    this.storeName = storeName;
    this.storeAddress = storeAddress;
    this.password = password;
    // Tidak perlu notifyListeners() di sini, karena belum ada UI yang bergantung pada data ini secara langsung di provider
    print("RegisterProvider: Data from Step 1 received.");
  }

  // Dipanggil dari RegisterStep2Screen untuk mengelola gambar profil
  Future<File?> pickProfileImage(ImageSource source) async {
    // Hapus file temporary lama jika ada
    if (_profileImageTemporaryFile != null && await _profileImageTemporaryFile!.exists()) {
       try { await _profileImageTemporaryFile!.delete(); } catch (e) { print("Error deleting old temp profile image: $e");}
    }
    _profileImageTemporaryFile = null;
    _clearMessages(); // Bersihkan pesan sebelum aksi baru
    // Tidak set loading di sini, biarkan UI Step 2 yang handle loading picker/cropper
    
    try {
      final pickedFile = await ImagePicker().pickImage(source: source, imageQuality: 80);
      if (pickedFile != null) {
        // File hasil picker ini adalah file temporary yang akan di-set di provider
        _profileImageTemporaryFile = File(pickedFile.path);
        notifyListeners(); // Update UI jika ada yang menampilkan preview dari provider
        return _profileImageTemporaryFile;
      }
    } catch (e) {
      _errorMessage = "Gagal memilih gambar: ${e.toString()}";
      notifyListeners();
    }
    return null;
  }

  // Dipanggil dari RegisterStep2Screen setelah cropping selesai
  void setCroppedProfileImage(File? croppedFile) {
     // Hapus file temporary lama (hasil picker) jika ada dan BEDA dari file hasil crop
    if (_profileImageTemporaryFile != null && _profileImageTemporaryFile != croppedFile && _profileImageTemporaryFile!.existsSync()) {
       try { _profileImageTemporaryFile!.delete(); } catch (e) { print("Error deleting picker temp image after crop in provider: $e");}
    }
    _profileImageTemporaryFile = croppedFile; // Ini adalah file temporary baru hasil crop
    _clearMessages();
    notifyListeners();
  }

  // Dipanggil dari RegisterStep2Screen saat proses registrasi akhir
  Future<bool> registerUser() async {
    if (_profileImageTemporaryFile == null || !await _profileImageTemporaryFile!.exists()) {
      _clearMessages();
      _errorMessage = "Silakan pilih foto profil terlebih dahulu.";
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _clearMessages();
    notifyListeners();

    final Map<String, String> textData = {
      "name": name,
      "email": email,
      "phoneNumber": phoneNumber,
      "storeName": storeName,
      "storeAddress": storeAddress,
      "password": password, // API akan menghash password di backend
    };

    try {
      // Panggil API Register dengan teks dan file gambar temporary
      await _apiService.register(textData, _profileImageTemporaryFile);
      _successMessage = "Pendaftaran berhasil! Silakan masuk.";
      
      // Penting: Hapus file temporary setelah berhasil dikirim ke API
      if (_profileImageTemporaryFile != null && await _profileImageTemporaryFile!.exists()) {
          try { await _profileImageTemporaryFile!.delete(); } catch (e) { print("Error deleting temp profile image after successful registration: $e");}
          _profileImageTemporaryFile = null; // Reset di provider
      }
      _isLoading = false;
      notifyListeners();
      return true;

    } catch (e) {
      _errorMessage = "Pendaftaran gagal: ${e.toString().replaceFirst('Exception: ', '')}";
      // Jangan hapus file temporary jika gagal, agar user bisa coba lagi tanpa pilih ulang gambar
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Bersihkan file temporary saat provider di-dispose (jika belum terkirim/dihapus)
  @override
  void dispose() {
    if (_profileImageTemporaryFile != null && _profileImageTemporaryFile!.existsSync()) {
       try { _profileImageTemporaryFile!.delete(); } catch (e) { print("Error deleting temp profile image on provider dispose: $e");}
    }
    super.dispose();
  }
}