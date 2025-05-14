// lib/fitur/register/screens/register_step_2.dart
import 'dart:io';
import 'dart:typed_data'; // Untuk ByteData
import 'dart:ui' as ui; // Untuk ui.Image

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_image/crop_image.dart';
import 'package:provider/provider.dart'; // Impor Provider

import 'package:aplikasir_mobile/fitur/login/screens/login_screen.dart';
import '../providers/register_provider.dart'; // Impor RegisterProvider
// path_provider dan path tidak diperlukan di sini jika provider yang handle file sementara

class RegisterStep2Screen extends StatefulWidget {
  // Hapus semua parameter konstruktor, data sudah ada di RegisterProvider
  const RegisterStep2Screen({super.key});

  @override
  State<RegisterStep2Screen> createState() => _RegisterStep2ScreenState();
}

class _RegisterStep2ScreenState extends State<RegisterStep2Screen> {
  // State UI lokal untuk cropping
  late CropController _cropController;
  bool _isCroppingImage = false; // State lokal untuk UI cropping
  String?
      _localOriginalImagePathForCropping; // Path asli gambar yang dipilih untuk di-crop (lokal state)
  bool _isSavingLocalCrop = false; // Loading saat konfirmasi crop lokal

  // File _profileImage dari provider akan digunakan untuk preview

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
    // Hapus _localOriginalImagePathForCropping jika ada dan belum diproses
    if (_localOriginalImagePathForCropping != null) {
      final tempFile = File(_localOriginalImagePathForCropping!);
      if (tempFile.existsSync())
        tempFile.delete().catchError(
            (e) {
              print("Error deleting local original crop file: $e");
              return tempFile;
            });
    }
    super.dispose();
  }

  // Fungsi pilih gambar dari UI, akan memanggil provider
  Future<void> _pickImageFromSource(
      ImageSource source, RegisterProvider provider) async {
    if (provider.isLoading || _isCroppingImage || _isSavingLocalCrop) return;
    setState(() {
      _isCroppingImage = false;
      _localOriginalImagePathForCropping = null;
    }); // Reset UI crop

    final File? pickedTempFileFromProvider =
        await provider.pickProfileImage(source);

    if (pickedTempFileFromProvider != null && mounted) {
      setState(() {
        _localOriginalImagePathForCropping = pickedTempFileFromProvider.path;
        _isCroppingImage = true; // Masuk mode cropping UI lokal
      });
    } else if (mounted && provider.errorMessage != null) {
      _showErrorSnackbar(provider.errorMessage!);
    }
    if (mounted && Navigator.canPop(context))
      Navigator.pop(context); // Tutup bottom sheet
  }

  // Konfirmasi crop di UI lokal, lalu set ke provider
  Future<void> _confirmLocalCrop(RegisterProvider provider) async {
    if (_localOriginalImagePathForCropping == null ||
        _isSavingLocalCrop ||
        provider.isLoading) return;
    setState(() => _isSavingLocalCrop = true);

    try {
      ui.Image bitmap =
          await _cropController.croppedBitmap(quality: FilterQuality.high);
      ByteData? byteData =
          await bitmap.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception("Tidak bisa konversi gambar.");
      Uint8List pngBytes = byteData.buffer.asUint8List();

      // Simpan ke file temporary BARU untuk hasil crop ini
      final tempDir = await Directory.systemTemp
          .createTemp('reg_crop_ui'); // Folder temp unik
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${tempDir.path}/temp_reg_crop_ui_$timestamp.png';
      final File newLocalCroppedFile = File(filePath);
      await newLocalCroppedFile.writeAsBytes(pngBytes);

      // Set file hasil crop ini ke provider
      provider.setCroppedProfileImage(newLocalCroppedFile);

      if (mounted) {
        setState(() {
          _isCroppingImage = false; // Keluar mode cropping UI
          _localOriginalImagePathForCropping = null; // Hapus path asli lokal
        });
      }
      // Hapus file ASLI (_localOriginalImagePathForCropping) yang tadi di-pick, karena sudah di-crop
      // dan provider sudah pegang file hasil crop yang baru.
      // File ini berbeda dari provider._profileImageTemporaryFile sebelum setCroppedProfileImage.
      // provider.pickProfileImage() membuat file temp, _confirmLocalCrop membuat file temp baru.
      // Seharusnya provider yang menghapus file temp dari pickProfileImage saat setCroppedProfileImage dipanggil.
      // Tidak perlu hapus _localOriginalImagePathForCropping di sini karena itu hanya path.
    } catch (e) {
      if (mounted) _showErrorSnackbar('Gagal memotong gambar: $e');
    } finally {
      if (mounted) setState(() => _isSavingLocalCrop = false);
    }
  }

  void _cancelLocalCrop(RegisterProvider provider) {
    if (provider.isLoading) return;
    // Hapus file asli yang di-pick untuk cropping jika ada
    if (_localOriginalImagePathForCropping != null) {
      final tempFile = File(_localOriginalImagePathForCropping!);
      if (tempFile.existsSync())
        tempFile.delete().catchError((e) =>
            print("Error deleting local original crop file on cancel: $e"));
    }
    setState(() {
      _isCroppingImage = false;
      _localOriginalImagePathForCropping = null;
    });
    // Tidak perlu clear provider.profileImageTemporaryFile di sini,
    // biarkan state provider apa adanya jika user batal crop.
  }

  void _showImageSourceActionSheetForUI(
      BuildContext context, RegisterProvider provider) {
    if (_isCroppingImage || provider.isLoading || _isSavingLocalCrop) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.0))),
      builder: (BuildContext ctx) {
        return SafeArea(
            child: Wrap(children: <Widget>[
          ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari Galeri'),
              onTap: () => _pickImageFromSource(ImageSource.gallery, provider)),
          ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Ambil Foto dengan Kamera'),
              onTap: () => _pickImageFromSource(ImageSource.camera, provider)),
        ]));
      },
    );
  }

  Future<void> _completeRegistration(RegisterProvider provider) async {
    // Provider akan handle validasi _profileImageTemporaryFile
    final success = await provider.registerUser();
    if (!mounted) return;

    if (success) {
      _showSuccessSnackbar(
          provider.successMessage ?? 'Pendaftaran berhasil! Silakan masuk.');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (context) => LoginScreen(
                initialEmail: provider.email)), // Kirim email ke LoginScreen
        (Route<dynamic> route) => false,
      );
    } else {
      _showErrorSnackbar(provider.errorMessage ?? 'Pendaftaran gagal.');
    }
  }

  void _showSuccessSnackbar(String message) {
    /* ... (SAMA) ... */ if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green));
  }

  void _showErrorSnackbar(String message) {
    /* ... (SAMA) ... */ if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    final registerProvider = context.watch<RegisterProvider>();
    final File? currentPreviewImage = registerProvider
        .profileImageTemporaryFile; // Gambar preview dari provider

    return PopScope(
      canPop: !_isCroppingImage &&
          !registerProvider.isLoading &&
          !_isSavingLocalCrop,
      onPopInvoked: (didPop) {
        if (!didPop && _isCroppingImage) _cancelLocalCrop(registerProvider);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F8F8),
        appBar: AppBar(
          title: Text(
              _isCroppingImage ? 'Potong Gambar Profil' : 'Unggah Foto Profil',
              style: GoogleFonts.poppins(
                  color: Colors.blue[700], fontWeight: FontWeight.w600)),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.blue[700]),
          elevation: 1.0,
          centerTitle: true,
          shadowColor: Colors.black26,
          automaticallyImplyLeading:
              !_isCroppingImage && !registerProvider.isLoading,
          leading: _isCroppingImage || registerProvider.isLoading
              ? Container()
              : null,
        ),
        body: SafeArea(
          child: Stack(
            children: [
              _isCroppingImage
                  ? _buildCroppingUIWidget(registerProvider)
                  : _buildMainUIWidget(registerProvider, currentPreviewImage),
              if (_isSavingLocalCrop ||
                  registerProvider.isLoading) // Gabungkan loading
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
                        Text(
                            _isSavingLocalCrop
                                ? 'Memproses gambar...'
                                : 'Mendaftarkan akun...',
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

  Widget _buildMainUIWidget(RegisterProvider provider, File? previewImage) {
    final imageKey = ValueKey(previewImage?.path ?? 'placeholder_reg2');
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
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 8,
                        offset: const Offset(0, 3))
                  ]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      previewImage == null
                          ? 'Unggah Foto Profil Anda'
                          : 'Ganti Foto Profil',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87)),
                  const SizedBox(height: 15),
                  Text('Foto ini akan ditampilkan di profil Anda.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 14, color: Colors.grey[600])),
                  const SizedBox(height: 35),
                  Center(
                    child: GestureDetector(
                      onTap: () =>
                          _showImageSourceActionSheetForUI(context, provider),
                      child: CircleAvatar(
                        key: imageKey,
                        radius: 80,
                        backgroundColor: Colors.grey.shade100,
                        backgroundImage:
                            previewImage != null && previewImage.existsSync()
                                ? FileImage(previewImage)
                                : null,
                        child:
                            previewImage == null || !previewImage.existsSync()
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                        Icon(Icons.camera_alt_outlined,
                                            size: 50,
                                            color: Colors.grey.shade500),
                                        const SizedBox(height: 8),
                                        Text("Pilih Foto",
                                            style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: Colors.grey.shade600))
                                      ])
                                : Container(
                                    decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.black.withOpacity(0.4)),
                                    child: const Center(
                                        child: Icon(Icons.edit_rounded,
                                            size: 40, color: Colors.white))),
                      ),
                    ),
                  ),
                  const SizedBox(height: 45),
                  ElevatedButton.icon(
                    onPressed: (previewImage != null &&
                            previewImage.existsSync() &&
                            !provider.isLoading)
                        ? () => _completeRegistration(provider)
                        : null,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        disabledBackgroundColor:
                            Colors.blue[200]?.withOpacity(0.7),
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0)),
                        elevation: 3),
                    icon: const Icon(Icons.person_add_alt_1_rounded,
                        color: Colors.white),
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
          ],
        ),
      ),
    );
  }

  Widget _buildCroppingUIWidget(RegisterProvider provider) {
    if (_localOriginalImagePathForCropping == null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _cancelLocalCrop(provider));
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
              key: ValueKey(_localOriginalImagePathForCropping),
              image: Image.file(File(_localOriginalImagePathForCropping!)),
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
                  onPressed: _isSavingLocalCrop
                      ? null
                      : () => _cancelLocalCrop(provider)),
              TextButton.icon(
                  icon: const Icon(Icons.check, color: Colors.green),
                  label: const Text('Konfirmasi',
                      style: TextStyle(color: Colors.green)),
                  onPressed: _isSavingLocalCrop
                      ? null
                      : () => _confirmLocalCrop(provider)),
            ],
          ),
        )
      ],
    );
  }
}
