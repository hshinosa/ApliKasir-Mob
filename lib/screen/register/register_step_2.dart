// lib/screen/register/register_step_2.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_image/crop_image.dart'; // Pastikan import crop_image
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// --- Impor yang diperlukan ---
import 'package:aplikasir_mobile/screen/login/login_screen.dart';
import 'package:aplikasir_mobile/services/api_services.dart'; // <-- Sesuaikan path jika perlu
// Model User tidak diperlukan di sini karena data dikirim sebagai Map

class RegisterStep2Screen extends StatefulWidget {
  final String name;
  final String email;
  final String phoneNumber;
  final String storeName;
  final String storeAddress;
  final String password;

  const RegisterStep2Screen({
    super.key,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.storeName,
    required this.storeAddress,
    required this.password,
  });

  @override
  _RegisterStep2ScreenState createState() => _RegisterStep2ScreenState();
}

class _RegisterStep2ScreenState extends State<RegisterStep2Screen> {
  File?
      _profileImage; // File untuk TAMPILAN PREVIEW (bisa temporary hasil crop)
  String?
      _savedImagePath; // Path file yang DISIMPAN permanen LOKAL setelah crop
  final ImagePicker _picker = ImagePicker();
  late CropController _cropController; // Pindahkan inisialisasi ke initState

  // State untuk cropping
  bool _isCropping = false;
  String? _originalImagePathForCropping; // <-- DEKLARASIKAN ini
  bool _isSavingCrop = false;
  bool _isRegistering = false;

  @override
  void initState() {
    super.initState();
    _cropController = CropController(
      aspectRatio: 1.0,
      defaultCrop: const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9),
    );
  }

  @override
  void dispose() {
    _cropController.dispose();
    _cleanupTemporaryFiles(); // Panggil fungsi cleanup
    super.dispose();
  }

  // Fungsi untuk membersihkan file temporary
  Future<void> _cleanupTemporaryFiles() async {
    // Hapus file asli yang dipilih untuk cropping jika masih ada
    if (_originalImagePathForCropping != null) {
      final originalFile = File(_originalImagePathForCropping!);
      try {
        if (await originalFile.exists()) {
          await originalFile.delete();
          print(
              "Deleted temporary original cropping file: $_originalImagePathForCropping");
        }
      } catch (e) {
        print("Error deleting temporary original file: $e");
      }
    }
    // File di _savedImagePath adalah file permanen LOKAL, JANGAN dihapus di dispose
    // kecuali ada logic khusus (misal jika registrasi dibatalkan total).
    // File di _profileImage biasanya menunjuk ke _savedImagePath setelah crop, jadi tidak perlu dihapus terpisah.
  }

  // --- Fungsi Pilih Gambar ---
  Future<void> _pickImage(ImageSource source) async {
    if (_isRegistering || _isCropping) return;
    setState(() {
      _isCropping = false; // Reset state cropping
      _originalImagePathForCropping = null; // Reset path asli
      _profileImage = null; // Reset preview
      _savedImagePath = null; // Reset path simpan
    });

    try {
      final pickedFile =
          await _picker.pickImage(source: source, imageQuality: 80);
      if (pickedFile != null) {
        setState(() {
          _originalImagePathForCropping =
              pickedFile.path; // Simpan path ASLI untuk cropping
          _isCropping = true; // Masuk mode cropping
        });
      }
    } catch (e) {
      print("Error picking image: $e");
      if (mounted) _showErrorSnackbar('Gagal memilih gambar: $e');
    }
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context); // Tutup bottom sheet
    }
  }

  // --- Fungsi Konfirmasi Hasil Crop ---
  Future<void> _confirmCrop() async {
    if (_originalImagePathForCropping == null ||
        _isSavingCrop ||
        _isRegistering) return;
    setState(() => _isSavingCrop = true);

    try {
      ui.Image bitmap =
          await _cropController.croppedBitmap(quality: FilterQuality.high);
      ByteData? byteData =
          await bitmap.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception("Tidak bisa mengkonversi gambar.");
      Uint8List pngBytes = byteData.buffer.asUint8List();

      // --- Simpan ke Application Documents Directory LOKAL ---
      final documentsDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imagesDir = Directory(
          p.join(documentsDir.path, 'profile_images_local')); // Folder lokal
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      // Nama file unik lokal
      final filePath = p.join(imagesDir.path, 'local_profile_$timestamp.png');
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);
      print("Cropped image saved locally to: $filePath");

      // --- Hapus gambar LAMA (_savedImagePath) jika ada ---
      if (_savedImagePath != null) {
        final previousImageFile = File(_savedImagePath!);
        try {
          if (await previousImageFile.exists()) {
            await previousImageFile.delete();
            print("Deleted previous saved local image: $_savedImagePath");
          }
        } catch (e) {
          print("Error deleting previous saved image: $e");
        }
      }

      // Update state dengan file LOKAL yang baru disimpan
      setState(() {
        _profileImage = file; // Update PREVIEW dengan file baru
        _savedImagePath = filePath; // Update PATH TERSIMPAN LOKAL
        _isCropping = false; // Keluar mode cropping
      });

      // Hapus file ASLI (_originalImagePathForCropping) setelah crop berhasil
      if (_originalImagePathForCropping != null) {
        final originalFile = File(_originalImagePathForCropping!);
        try {
          if (await originalFile.exists()) {
            await originalFile.delete();
            print(
                "Deleted temporary original cropping file: $_originalImagePathForCropping");
          }
        } catch (e) {
          print("Error deleting temporary original file after crop: $e");
        }
        _originalImagePathForCropping = null; // Reset path asli
      }
    } catch (e) {
      print("Error cropping/saving image: $e");
      if (mounted) _showErrorSnackbar('Gagal memotong gambar: $e');
    } finally {
      if (mounted) setState(() => _isSavingCrop = false);
    }
  }

  // --- Fungsi Membatalkan Proses Crop ---
  void _cancelCrop() {
    if (_isRegistering) return;
    setState(() {
      _isCropping = false;
      // Hapus file ASLI yang dipilih untuk crop jika ada
      if (_originalImagePathForCropping != null) {
        final originalFile = File(_originalImagePathForCropping!);
        try {
          if (originalFile.existsSync()) {
            // Gunakan sync check jika memungkinkan di UI thread
            originalFile.delete();
            print(
                "Deleted temporary original cropping file on cancel: $_originalImagePathForCropping");
          }
        } catch (e) {
          print("Error deleting temporary original file on cancel: $e");
        }
        _originalImagePathForCropping = null; // Reset path asli
      }
    });
  }

  // --- Tampilkan Bottom Sheet Sumber Gambar ---
  void _showImageSourceActionSheet(BuildContext context) {
    if (_isCropping || _isRegistering) return;
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.0))),
        builder: (BuildContext context) {
          return SafeArea(
              child: Wrap(children: <Widget>[
            ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeri'),
                onTap: () => _pickImage(ImageSource.gallery)),
            ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Kamera'),
                onTap: () => _pickImage(ImageSource.camera)),
          ]));
        });
  }

  // --- Fungsi Utama: Proses Registrasi (Memanggil API) ---
  Future<void> _onRegisterPressed() async {
    // Validasi apakah gambar sudah dipilih (path tersimpan lokal sudah ada)
    if (_savedImagePath == null) {
      if (mounted) {
        _showErrorSnackbar('Silakan pilih foto profil terlebih dahulu.');
      }
      return;
    }
    if (_isRegistering) return;
    setState(() => _isRegistering = true);

    final apiService = ApiService();
    File? imageFileToSend; // File yang akan dikirim ke API

    // Cek apakah path gambar tersimpan valid dan buat objek File
    if (_savedImagePath != null) {
      imageFileToSend = File(_savedImagePath!);
      if (!await imageFileToSend.exists()) {
        print("Error: Saved image file not found at $_savedImagePath.");
        if (mounted) {
          _showErrorSnackbar(
              "File gambar profil tidak ditemukan. Coba pilih ulang.");
        }
        setState(() => _isRegistering = false);
        return; // Hentikan jika file tidak ada
      }
    } else {
      // Seharusnya tidak terjadi karena ada validasi di awal, tapi sebagai safeguard
      if (mounted) {
        _showErrorSnackbar("Path gambar tidak valid.");
      }
      setState(() => _isRegistering = false);
      return;
    }

    // Persiapan data teks
    final Map<String, String> textData = {
      "name": widget.name,
      "email": widget.email,
      "phoneNumber": widget.phoneNumber,
      "storeName": widget.storeName,
      "storeAddress": widget.storeAddress,
      "password": widget.password, // Kirim password asli
    };

    try {
      // Panggil API Register dengan teks dan file
      // Tidak perlu menyimpan 'response' jika tidak digunakan
      await apiService.register(textData, imageFileToSend);

      if (!mounted) return; // Cek mounted setelah await

      // Handle sukses
      _showSuccessSnackbar('Pendaftaran berhasil! Silakan masuk.');

      // Hapus file LOKAL setelah berhasil register ke server
      try {
        await imageFileToSend.delete();
        print("Deleted local profile image after successful registration.");
      } catch (_) {}
      _cleanupTemporaryFiles(); // Bersihkan juga file temp lain jika ada

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => LoginScreen(initialEmail: widget.email),
        ),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      print("Registration API Error: $e");
      if (!mounted) return; // Cek mounted setelah await
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      _showErrorSnackbar('Pendaftaran gagal: $errorMessage');
      // Jangan hapus gambar lokal jika registrasi GAGAL
    } finally {
      if (mounted) {
        setState(() => _isRegistering = false);
      }
    }
  }

  // --- Helper Snackbar (Pastikan ada) ---
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isCropping && !_isRegistering && !_isSavingCrop,
      onPopInvoked: (didPop) {
        if (!didPop && _isCropping) _cancelCrop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F8F8),
        appBar: AppBar(
          title: Text(_isCropping ? 'Potong Gambar' : 'Foto Profil',
              style: GoogleFonts.poppins(
                  color: Colors.blue[700], fontWeight: FontWeight.w600)),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shadowColor: Colors.black26, // Lebih baik dari black saja
          iconTheme: IconThemeData(color: Colors.blue[700]),
          elevation: 2.5,
          centerTitle: true,
          automaticallyImplyLeading: !_isCropping && !_isRegistering,
          leading: _isCropping || _isRegistering ? Container() : null,
        ),
        body: SafeArea(
          child: Stack(
            children: [
              // --- Tampilan Utama (Pilih/Ganti Foto & Tombol Selesai) ---
              // Menggunakan _profileImage (File lokal hasil crop) untuk preview
              _isCropping ? _buildCroppingUI() : _buildMainUI(),

              // Loading overlay untuk SIMPAN CROP LOKAL
              if (_isSavingCrop)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                      child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white))),
                ),
              // Loading overlay untuk PROSES REGISTRASI ke API
              if (_isRegistering)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        const CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white)),
                        const SizedBox(height: 15),
                        Text('Mendaftarkan akun...',
                            style: GoogleFonts.poppins(
                                color: Colors.white, fontSize: 16))
                      ])),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Widget UI Utama ---
  Widget _buildMainUI() {
    // Key dinamis untuk CircleAvatar agar update saat gambar berubah
    final imageKey = ValueKey(_savedImagePath ?? 'placeholder');

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(30.0),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.0),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.grey.withOpacity(0.15),
                        spreadRadius: 2,
                        blurRadius: 10,
                        offset: const Offset(0, 5))
                  ]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _profileImage == null
                        ? 'Unggah Foto Profil Anda'
                        : 'Ganti Foto Profil',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'Foto ini akan ditampilkan di profil Anda.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 35),
                  Center(
                    child: GestureDetector(
                      onTap: () => _showImageSourceActionSheet(context),
                      child: CircleAvatar(
                        key: imageKey, // Gunakan key dinamis
                        radius: 80,
                        backgroundColor: Colors.grey.shade100,
                        // Tampilkan gambar dari _profileImage (File lokal hasil crop)
                        backgroundImage: _profileImage != null
                            ? FileImage(_profileImage!)
                            : null,
                        child: _profileImage == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                    Icon(Icons.camera_alt_outlined,
                                        size: 50, color: Colors.grey.shade500),
                                    const SizedBox(height: 8),
                                    Text("Pilih Foto",
                                        style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.grey.shade600))
                                  ])
                            : Container(
                                // Overlay edit
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black.withOpacity(0.4)),
                                child: const Center(
                                    child: Icon(Icons.edit,
                                        size: 40, color: Colors.white)),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 45),
                  ElevatedButton.icon(
                    // Enable tombol JIKA _savedImagePath TIDAK NULL (artinya crop sudah disimpan lokal)
                    onPressed: (_savedImagePath != null && !_isRegistering)
                        ? _onRegisterPressed
                        : null,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        disabledBackgroundColor:
                            Colors.blue[200]?.withOpacity(0.7),
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0)),
                        elevation: 4),
                    icon:
                        const Icon(Icons.person_add_alt_1, color: Colors.white),
                    label: Text('Selesaikan Pendaftaran',
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ),
                  const SizedBox(height: 15),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // --- Widget UI Cropping ---
  Widget _buildCroppingUI() {
    // Jika path asli null, kembali ke UI utama
    if (_originalImagePathForCropping == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _cancelCrop());
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: <Widget>[
        Expanded(
          child: Container(
            color: Colors.black,
            padding: const EdgeInsets.all(8.0),
            child: CropImage(
              controller: _cropController,
              key: ValueKey(
                  _originalImagePathForCropping), // Key jika gambar berubah
              image: Image.file(File(_originalImagePathForCropping!)),
              gridColor: Colors.white.withOpacity(0.5),
              gridCornerSize: 25,
              gridThinWidth: 1,
              gridThickWidth: 3,
              scrimColor: Colors.black.withOpacity(0.5),
              alwaysShowThirdLines: true,
              minimumImageSize: 50,
            ),
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              TextButton.icon(
                icon: const Icon(Icons.close, color: Colors.redAccent),
                label: const Text('Batal',
                    style: TextStyle(color: Colors.redAccent)),
                onPressed: _isSavingCrop ? null : _cancelCrop,
              ),
              TextButton.icon(
                icon: const Icon(Icons.check, color: Colors.green),
                label: const Text('Konfirmasi',
                    style: TextStyle(color: Colors.green)),
                onPressed: _isSavingCrop ? null : _confirmCrop,
              ),
            ],
          ),
        )
      ],
    );
  }
} // Akhir State
