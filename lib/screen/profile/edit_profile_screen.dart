import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_image/crop_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// --- Impor yang diperlukan ---
import 'package:aplikasir_mobile/model/user_model.dart';
import 'package:aplikasir_mobile/helper/db_helper.dart';
import 'package:aplikasir_mobile/utils/auth_utils.dart'; // <- Impor untuk hash password

class EditProfileScreen extends StatefulWidget {
  final User initialUser; // Menerima data user awal

  const EditProfileScreen({super.key, required this.initialUser});

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>(); // Kunci untuk validasi form
  final ImagePicker _picker = ImagePicker();
  late CropController _cropController;

  // --- Controller untuk setiap field ---
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _storeNameController;
  late TextEditingController _storeAddressController;
  // --- TAMBAHKAN CONTROLLER PASSWORD BARU ---
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // --- State untuk gambar profil ---
  File? _newCroppedImageFile; // File hasil crop baru (sementara)
  String? _savedImagePath; // Path gambar yang TERSIMPAN di storage
  bool _imageChanged = false; // Flag apakah gambar diubah

  // --- State untuk cropping dan saving ---
  bool _isCropping = false;
  String? _originalImagePathForCropping; // Path gambar asli SEBELUM crop
  bool _isSavingCrop = false;
  bool _isSavingProfile = false; // Loading saat menyimpan ke DB

  // --- State untuk show/hide password ---
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();

    // Inisialisasi Controller dengan data awal
    _nameController = TextEditingController(text: widget.initialUser.name);
    _emailController = TextEditingController(text: widget.initialUser.email);
    _phoneController =
        TextEditingController(text: widget.initialUser.phoneNumber);
    _storeNameController =
        TextEditingController(text: widget.initialUser.storeName);
    _storeAddressController =
        TextEditingController(text: widget.initialUser.storeAddress);

    // Inisialisasi path gambar tersimpan
    _savedImagePath = widget.initialUser.profileImagePath;

    // Inisialisasi Crop Controller
    _cropController = CropController(
      aspectRatio: 1.0,
      defaultCrop: const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _storeNameController.dispose();
    _storeAddressController.dispose();
    _newPasswordController.dispose(); // Dispose password controllers
    _confirmPasswordController.dispose();
    _cropController.dispose();
    _clearTemporaryCroppedFile();
    super.dispose();
  }

  void _clearTemporaryCroppedFile() {
    if (_newCroppedImageFile != null && _newCroppedImageFile!.existsSync()) {
      // Hanya hapus jika pathnya BEDA dari yg sudah tersimpan
      if (_savedImagePath == null ||
          _newCroppedImageFile!.path != _savedImagePath) {
        _newCroppedImageFile!.delete().catchError(
            // ignore: invalid_return_type_for_catch_error
            (e) => print("Error deleting temp crop file on dispose: $e"));
      }
    }
  }

  // --- Fungsi Pilih Gambar (Mirip Register Step 2) ---
  Future<void> _pickImage(ImageSource source) async {
    if (_isSavingProfile || _isCropping) return;
    setState(() {
      _isCropping = false;
      _originalImagePathForCropping = null;
      _clearTemporaryCroppedFile(); // Hapus file crop lama jika ada
      _newCroppedImageFile = null;
    });

    try {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _originalImagePathForCropping = pickedFile.path;
          _isCropping = true;
        });
      }
    } catch (e) {
      print("Error picking image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memilih gambar: $e')),
        );
      }
    }
    if (mounted && Navigator.canPop(context)) {
      // Tutup bottom sheet
      Navigator.pop(context);
    }
  }

  // --- Fungsi Konfirmasi Crop (Mirip Register Step 2) ---
  Future<void> _confirmCrop() async {
    if (_originalImagePathForCropping == null ||
        _isSavingCrop ||
        _isSavingProfile) return;
    setState(() {
      _isSavingCrop = true;
    });

    try {
      ui.Image bitmap =
          await _cropController.croppedBitmap(quality: FilterQuality.high);
      ByteData? byteData =
          await bitmap.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception("Tidak bisa mengkonversi gambar.");
      Uint8List pngBytes = byteData.buffer.asUint8List();

      // Simpan ke temporary directory DULU, path final ditentukan saat save profile
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${tempDir.path}/temp_cropped_profile_$timestamp.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      // Hapus file crop sementara SEBELUMNYA (jika ada)
      _clearTemporaryCroppedFile();

      setState(() {
        _newCroppedImageFile = file; // Simpan file hasil crop baru
        _isCropping = false;
        _originalImagePathForCropping = null; // Hapus path asli setelah crop
        _imageChanged = true; // Tandai bahwa gambar sudah diubah
      });
    } catch (e) {
      print("Error cropping image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memotong gambar: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingCrop = false;
        });
      }
    }
  }

  // --- Fungsi Batal Crop ---
  void _cancelCrop() {
    if (_isSavingProfile) return;
    setState(() {
      _isCropping = false;
      // Hapus file asli yg dipilih untuk crop jika ada
      if (_originalImagePathForCropping != null) {
        final originalFile = File(_originalImagePathForCropping!);
        originalFile.exists().then((exists) {
          if (exists) {
            originalFile.delete().catchError(
                // ignore: invalid_return_type_for_catch_error
                (e) => print("Error deleting original on cancel crop: $e"));
          }
        });
        _originalImagePathForCropping = null;
      }
    });
  }

  // --- Tampilkan Bottom Sheet Sumber Gambar ---
  void _showImageSourceActionSheet(BuildContext context) {
    if (_isCropping || _isSavingProfile) return;
    showModalBottomSheet(
      context: context,
      // ... (builder bottom sheet sama seperti register_step_2) ...
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeri'),
                onTap: () => _pickImage(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Kamera'),
                onTap: () => _pickImage(ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Fungsi Hapus Gambar (Langsung hapus path saat ini) ---

  // --- Fungsi Simpan Perubahan Profil ---
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    } // Validasi form dulu
    if (_isSavingProfile) return;
    setState(() => _isSavingProfile = true);

    String? finalImagePath = _savedImagePath;
    String finalPasswordHash =
        widget.initialUser.passwordHash; // Default pakai hash lama

    // --- VALIDASI PASSWORD BARU ---
    final String newPassword = _newPasswordController.text;
    final String confirmPassword = _confirmPasswordController.text;

    if (newPassword.isNotEmpty || confirmPassword.isNotEmpty) {
      // Hanya proses jika salah satu diisi
      if (newPassword != confirmPassword) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Konfirmasi kata sandi baru tidak cocok!'),
            backgroundColor: Colors.redAccent));
        setState(() => _isSavingProfile = false); // Hentikan loading
        return; // Berhenti
      }
      if (newPassword.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Kata sandi baru minimal 6 karakter!'),
            backgroundColor: Colors.redAccent));
        setState(() => _isSavingProfile = false); // Hentikan loading
        return; // Berhenti
      }
      // Jika valid, hash password baru
      finalPasswordHash =
          hashPassword(newPassword); // Ganti hash lama dengan yang baru
      print("Password changed and hashed.");
    } else {
      print("Password not changed.");
    }
    // --- AKHIR VALIDASI PASSWORD BARU ---

    try {
      // 1. Jika ada gambar BARU hasil crop, pindahkan ke lokasi permanen
      if (_newCroppedImageFile != null && _imageChanged) {
        final documentsDir = await getApplicationDocumentsDirectory();
        final imagesDir =
            Directory(p.join(documentsDir.path, 'profile_images'));
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final permanentPath = p.join(
            imagesDir.path, 'profile_${widget.initialUser.id}_$timestamp.png');

        // Pindahkan file temporary ke path permanen
        final permanentFile = await _newCroppedImageFile!.copy(permanentPath);
        finalImagePath = permanentFile.path; // Update path final

        // Hapus file temporary setelah dipindah
        await _newCroppedImageFile!.delete();
        _newCroppedImageFile = null; // Reset file temporary

        // Hapus gambar LAMA dari storage jika ada DAN pathnya beda
        if (_savedImagePath != null && _savedImagePath != finalImagePath) {
          final oldImageFile = File(_savedImagePath!);
          if (await oldImageFile.exists()) {
            await oldImageFile.delete().catchError(
                // ignore: invalid_return_type_for_catch_error
                (e) => print("Error deleting old profile image: $e"));
          }
        }
        _savedImagePath = finalImagePath; // Update path tersimpan di state
        _imageChanged = false; // Reset flag setelah disimpan
      }

      // 2. Siapkan data user yang akan diupdate
      final updatedUser = User(
        id: widget.initialUser.id,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        storeName: _storeNameController.text.trim(),
        storeAddress: _storeAddressController.text.trim(),
        passwordHash: finalPasswordHash, // Gunakan hash final
        profileImagePath: finalImagePath,
      );

      // Update ke database
      final dbHelper = DatabaseHelper.instance;
      final rowsAffected = await dbHelper.updateUser(updatedUser);

      if (!mounted) return; // Cek mounted setelah await

      if (rowsAffected > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil berhasil diperbarui!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Kembali & signal refresh
      } else {
        throw Exception('Gagal memperbarui data pengguna di database.');
      }
    } catch (e) {
      print("Error saving profile: $e");
      // Rollback gambar jika gagal simpan DB setelah gambar baru dipindah
      if (finalImagePath != null &&
          finalImagePath != widget.initialUser.profileImagePath) {
        final newImg = File(finalImagePath);
        try {
          if (await newImg.exists()) await newImg.delete();
        } catch (imgErr) {
          print("Error rolling back new image: $imgErr");
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Gagal menyimpan profil: ${e.toString().replaceFirst("Exception: ", "")}'),
              backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // PopScope untuk handle back saat cropping
    return PopScope(
      canPop: !_isCropping && !_isSavingProfile && !_isSavingCrop,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_isCropping) {
          _cancelCrop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        appBar: AppBar(
          title: Text(
            _isCropping ? 'Potong Gambar' : 'Edit Profil',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: Colors.blue.shade800),
          ),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shadowColor: Colors.black26,
          iconTheme: IconThemeData(color: Colors.blue.shade700),
          elevation: 2.5,
          centerTitle: true,
          automaticallyImplyLeading:
              !_isCropping && !_isSavingProfile, // Sembunyikan back saat proses
          leading: _isCropping || _isSavingProfile ? Container() : null,
          // --- PINDAHKAN TOMBOL SIMPAN KE ACTIONS ---
          actions: [
            // Tampilkan tombol simpan hanya jika tidak sedang cropping
            if (!_isCropping)
              // Tampilkan loading atau ikon simpan
              _isSavingProfile
                  ? const Padding(
                      padding: EdgeInsets.only(right: 16.0),
                      child: Center(
                          child: SizedBox(
                              width: 24,
                              height: 24,
                              child:
                                  CircularProgressIndicator(strokeWidth: 3))))
                  : IconButton(
                      icon: Icon(Icons.save_outlined,
                          color: Colors.blue.shade700),
                      tooltip: 'Simpan Perubahan',
                      onPressed: _saveProfile, // Panggil fungsi save
                    ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            // Stack untuk overlay cropping dan loading
            children: [
              // --- Form Utama ---
              SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // --- Bagian Gambar Profil ---
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 65,
                            backgroundColor: Colors.grey.shade200,
                            // Prioritaskan gambar baru hasil crop, lalu gambar tersimpan, lalu placeholder
                            backgroundImage: _newCroppedImageFile != null
                                ? FileImage(_newCroppedImageFile!)
                                : (_savedImagePath != null &&
                                        File(_savedImagePath!).existsSync())
                                    ? FileImage(File(_savedImagePath!))
                                    : null, // Cast FileImage ke ImageProvider
                            child: (_newCroppedImageFile == null &&
                                    (_savedImagePath == null ||
                                        !File(_savedImagePath!).existsSync()))
                                ? Icon(Icons.person,
                                    size:
                                        MediaQuery.of(context).size.width * 0.3,
                                    color: Colors.grey.shade400)
                                : null,
                          ),
                          // Tombol Edit Gambar
                          Material(
                            color: Colors.blue.shade600,
                            shape: const CircleBorder(),
                            elevation: 2,
                            child: InkWell(
                              onTap: () => _showImageSourceActionSheet(context),
                              customBorder: const CircleBorder(),
                              child: const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Icon(Icons.edit,
                                    color: Colors.white, size: 20),
                              ),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 30),

                      // --- Input Fields ---
                      _buildTextField(
                        controller: _nameController,
                        label: 'Nama Lengkap',
                        hint: 'Masukkan nama lengkap',
                        icon: Icons.person_outline,
                        validator: (value) => value == null || value.isEmpty
                            ? 'Nama tidak boleh kosong'
                            : null,
                      ),
                      _buildTextField(
                          controller: _emailController,
                          label: 'Email',
                          hint: 'Masukkan alamat email',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          // Tambahkan validasi email jika perlu
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Email tidak boleh kosong';
                            if (!value.contains('@'))
                              return 'Format email tidak valid'; // Simple check
                            return null;
                          }),
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Nomor Telepon',
                        hint: 'Masukkan nomor telepon',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (value) => value == null || value.isEmpty
                            ? 'Nomor telepon tidak boleh kosong'
                            : null,
                      ),
                      _buildPasswordField(
                        controller: _newPasswordController,
                        label: 'Kata Sandi Baru',
                        hint: 'Kosongkan jika tidak ingin diubah',
                        obscureText: _obscureNewPassword,
                        onToggleVisibility: () => setState(
                            () => _obscureNewPassword = !_obscureNewPassword),
                        // Validator password baru (hanya jika diisi)
                        validator: (value) {
                          if (value != null &&
                              value.isNotEmpty &&
                              value.length < 6) {
                            return 'Minimal 6 karakter';
                          }
                          return null; // Boleh kosong
                        },
                      ),
                      _buildPasswordField(
                        controller: _confirmPasswordController,
                        label: 'Konfirmasi Kata Sandi Baru',
                        hint: 'Masukkan ulang kata sandi baru',
                        obscureText: _obscureConfirmPassword,
                        onToggleVisibility: () => setState(() =>
                            _obscureConfirmPassword = !_obscureConfirmPassword),
                        // Validator konfirmasi password (hanya jika password baru diisi)
                        validator: (value) {
                          if (_newPasswordController.text.isNotEmpty &&
                              (value == null || value.isEmpty)) {
                            return 'Konfirmasi wajib diisi jika mengatur sandi baru';
                          }
                          if (_newPasswordController.text.isNotEmpty &&
                              value != _newPasswordController.text) {
                            return 'Kata sandi tidak cocok';
                          }
                          return null;
                        },
                      ),
                      _buildTextField(
                        controller: _storeNameController,
                        label: 'Nama Toko',
                        hint: 'Masukkan nama toko',
                        icon: Icons.storefront_outlined,
                        validator: (value) => value == null || value.isEmpty
                            ? 'Nama toko tidak boleh kosong'
                            : null,
                      ),
                      _buildTextField(
                        controller: _storeAddressController,
                        label: 'Alamat Toko',
                        hint: 'Masukkan alamat toko',
                        icon: Icons.location_on_outlined,
                        maxLines: 1, // Allow multiple lines for address
                        validator: (value) => value == null || value.isEmpty
                            ? 'Alamat toko tidak boleh kosong'
                            : null,
                      ),
                    ],
                  ),
                ),
              ),

              // --- Overlay Cropping UI ---
              if (_isCropping) _buildCroppingUI(),

              // --- Overlay Loading saat Simpan Crop ---
              if (_isSavingCrop)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                      child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white))),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper untuk membangun TextFormField ---
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: MediaQuery.of(context).size.width < 400 ? 12 : 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
              prefixIcon: Icon(icon, color: Colors.grey[500], size: 20),
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
            ),
            style: GoogleFonts.poppins(
                fontSize: MediaQuery.of(context).size.width < 400 ? 12 : 14),
            validator: validator,
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
        ],
      ),
    );
  }

  // --- Helper TextFormField Password ---
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 20.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: MediaQuery.of(context).size.width < 400 ? 12 : 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            obscureText: obscureText,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
              prefixIcon:
                  Icon(Icons.lock_outline, color: Colors.grey[500], size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  obscureText
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.grey[500],
                  size: MediaQuery.of(context).size.width < 400 ? 18 : 20,
                ),
                onPressed: onToggleVisibility,
                tooltip: obscureText ? 'Tampilkan' : 'Sembunyikan',
              ),
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
            ),
            style: GoogleFonts.poppins(fontSize: 14),
            validator: validator,
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
        ]));
  }

  // --- UI untuk Cropping (Mirip Register Step 2) ---
  Widget _buildCroppingUI() {
    if (_originalImagePathForCropping == null) {
      // Seharusnya tidak terjadi jika state diatur dgn benar
      WidgetsBinding.instance.addPostFrameCallback((_) => _cancelCrop());
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      // Bungkus dengan container agar menutupi form
      color: Colors.black, // Background hitam saat cropping
      child: Column(
        children: <Widget>[
          Expanded(
            child: Padding(
              // Padding di dalam area hitam
              padding: const EdgeInsets.all(8.0),
              child: CropImage(
                controller: _cropController,
                key: ValueKey(
                    _originalImagePathForCropping), // Key jika gambar berubah
                image: Image.file(File(_originalImagePathForCropping!)),
                // ... (properti grid, scrim, dll sama seperti register_step_2) ...
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
          // Tombol Batal & Konfirmasi Crop
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                TextButton.icon(
                  icon: const Icon(Icons.close, color: Colors.redAccent),
                  label: const Text('Batal',
                      style: TextStyle(color: Colors.redAccent)),
                  onPressed: _isSavingCrop
                      ? null
                      : _cancelCrop, // Nonaktifkan saat menyimpan crop
                ),
                TextButton.icon(
                  icon: const Icon(Icons.check, color: Colors.green),
                  label: const Text('Konfirmasi',
                      style: TextStyle(color: Colors.green)),
                  onPressed: _isSavingCrop
                      ? null
                      : _confirmCrop, // Nonaktifkan saat menyimpan crop
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
