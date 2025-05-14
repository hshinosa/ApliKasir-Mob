// lib/fitur/profile/screens/edit_profile_screen.dart
import 'dart:io';
import 'dart:typed_data'; // Untuk ByteData
import 'dart:ui' as ui;    // Untuk ui.Image

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Untuk TextInputFormatter
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_image/crop_image.dart'; // Pastikan ini ada di pubspec
import 'package:provider/provider.dart';

import 'package:aplikasir_mobile/model/user_model.dart';
import '../providers/profile_provider.dart';

class EditProfileScreen extends StatefulWidget {
  final User initialUser;

  const EditProfileScreen({super.key, required this.initialUser});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late CropController _cropController;

  // Controllers untuk form
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _storeNameController;
  late TextEditingController _storeAddressController;
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // State UI lokal
  File? _currentDisplayImageFile; // Untuk preview (bisa temporary atau dari path lama)
  String? _originalImagePathBeforeEdit; // Path gambar awal
  bool _isCropping = false;
  String? _imagePathForCropping; // Path file yang akan di-crop
  bool _isSavingCrop = false; // Loading saat konfirmasi crop

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialUser.name);
    _emailController = TextEditingController(text: widget.initialUser.email);
    _phoneController = TextEditingController(text: widget.initialUser.phoneNumber);
    _storeNameController = TextEditingController(text: widget.initialUser.storeName);
    _storeAddressController = TextEditingController(text: widget.initialUser.storeAddress);
    _originalImagePathBeforeEdit = widget.initialUser.profileImagePath;

    if (_originalImagePathBeforeEdit != null && File(_originalImagePathBeforeEdit!).existsSync()) {
      _currentDisplayImageFile = File(_originalImagePathBeforeEdit!);
    }

    _cropController = CropController(aspectRatio: 1.0, defaultCrop: const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _storeNameController.dispose();
    _storeAddressController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _cropController.dispose();
    // Hapus file temporary yang di-crop jika tidak jadi disimpan dan BUKAN file asli
    final profileProvider = context.read<ProfileProvider>();
    if (profileProvider.newTempProfileImageFile != null && 
        profileProvider.newTempProfileImageFile!.existsSync() &&
        profileProvider.newTempProfileImageFile!.path != _originalImagePathBeforeEdit) {
      try {
        profileProvider.newTempProfileImageFile!.delete();
      } catch(e) {print("Error deleting temp edit image on dispose: $e");}
    }
    profileProvider.setNewCroppedImage(null); // Bersihkan di provider juga
    super.dispose();
  }


  Future<void> _pickImage(ImageSource source, ProfileProvider provider) async {
    if (provider.isUpdatingProfile || _isCropping || _isSavingCrop) return;
    setState(() { _isCropping = false; _imagePathForCropping = null;}); // Keluar dari mode crop jika ada
    
    // Panggil method provider untuk pick image
    final File? pickedTempFile = await provider.pickImageForEdit(source);

    if (pickedTempFile != null && mounted) {
        setState(() {
            _imagePathForCropping = pickedTempFile.path; // Ini akan jadi path temporary dari provider
            _isCropping = true;
            _currentDisplayImageFile = null; // Sembunyikan preview lama saat cropping
        });
    }
    if (mounted && Navigator.canPop(context)) Navigator.pop(context); // Tutup bottom sheet
  }

  Future<void> _confirmCrop(ProfileProvider provider) async {
    if (_imagePathForCropping == null || _isSavingCrop || provider.isUpdatingProfile) return;
    setState(() => _isSavingCrop = true);

    try {
      ui.Image bitmap = await _cropController.croppedBitmap(quality: FilterQuality.high);
      ByteData? byteData = await bitmap.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception("Tidak bisa konversi gambar.");
      Uint8List pngBytes = byteData.buffer.asUint8List();

      // Simpan ke temporary directory BARU untuk hasil crop
      final tempDir = await Directory.systemTemp.createTemp('cropped_img_edit');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${tempDir.path}/temp_edit_profile_crop_$timestamp.png';
      final File newCroppedFile = File(filePath);
      await newCroppedFile.writeAsBytes(pngBytes);

      // Set file hasil crop baru ke provider (provider akan handle file temporary sebelumnya)
      provider.setNewCroppedImage(newCroppedFile);
      
      if (mounted) {
        setState(() {
          _currentDisplayImageFile = newCroppedFile; // Update preview dengan hasil crop baru
          _isCropping = false;
          _imagePathForCropping = null;
        });
      }
    } catch (e) {
      if (mounted) _showErrorSnackbar('Gagal memotong gambar: $e');
    } finally {
      if (mounted) setState(() => _isSavingCrop = false);
    }
  }

  void _cancelCrop(ProfileProvider provider) {
    if (provider.isUpdatingProfile) return;
    
    // Provider yang handle penghapusan file temporary hasil picker jika ada
    // provider.clearTemporaryImage(); // Ini akan menghapus _newTempProfileImageFile di provider
    
    setState(() {
      _isCropping = false;
      _imagePathForCropping = null; // Hapus path yang mau di-crop
      // Kembalikan preview ke gambar awal atau hasil crop sebelumnya dari provider
      _currentDisplayImageFile = provider.newTempProfileImageFile ?? 
                                 (_originalImagePathBeforeEdit != null && File(_originalImagePathBeforeEdit!).existsSync() 
                                  ? File(_originalImagePathBeforeEdit!) 
                                  : null);
    });
  }

  void _showImageSourceActionSheet(BuildContext context, ProfileProvider provider) {
    if (_isCropping || provider.isUpdatingProfile || _isSavingCrop) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.0))),
      builder: (BuildContext ctx) {
        return SafeArea(child: Wrap(children: <Widget>[
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Pilih dari Galeri'), onTap: () => _pickImage(ImageSource.gallery, provider)),
          ListTile(leading: const Icon(Icons.camera_alt_outlined), title: const Text('Ambil Foto dengan Kamera'), onTap: () => _pickImage(ImageSource.camera, provider)),
        ]));
      },
    );
  }

  Future<void> _saveProfileChanges(ProfileProvider provider) async {
    if (!_formKey.currentState!.validate()) return;
    // Validasi password tambahan
    final String newPassword = _newPasswordController.text;
    final String confirmPassword = _confirmPasswordController.text;

    if (newPassword.isNotEmpty && newPassword.length < 6) {
        _showErrorSnackbar('Kata sandi baru minimal 6 karakter!');
        return;
    }
    if (newPassword.isNotEmpty && newPassword != confirmPassword) {
        _showErrorSnackbar('Konfirmasi kata sandi baru tidak cocok!');
        return;
    }

    bool removeCurrentImageFlag = false;
    // Jika tidak ada _currentDisplayImageFile dan _originalImagePathBeforeEdit ada,
    // berarti user ingin menghapus gambar yang sudah ada.
    if (_currentDisplayImageFile == null && _originalImagePathBeforeEdit != null) {
        removeCurrentImageFlag = true;
    }


    final success = await provider.updateUserProfile(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      storeName: _storeNameController.text.trim(),
      storeAddress: _storeAddressController.text.trim(),
      newPassword: newPassword.isNotEmpty ? newPassword : null,
      // newProfileImage adalah _currentDisplayImageFile jika BUKAN file asli
      // atau null jika gambar dihapus atau tidak diubah.
      // Provider akan menggunakan newTempProfileImageFile yang sudah di-set.
      newProfileImage: provider.newTempProfileImageFile,
      removeCurrentImage: removeCurrentImageFlag,
    );

    if (!mounted) return;
    if (success) {
      _showSuccessSnackbar(provider.successMessage ?? 'Profil berhasil diperbarui!');
      Navigator.pop(context, true); // Kirim true untuk refresh ProfileScreen
    } else {
      _showErrorSnackbar(provider.errorMessage ?? 'Gagal menyimpan profil.');
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
  }
   void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green));
  }

  Widget _buildTextField({ /* ... (SAMA seperti di EditProfileScreen lama) ... */
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: MediaQuery.of(context).size.width < 400 ? 12 : 14, fontWeight: FontWeight.w500, color: Colors.black87)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller, maxLines: maxLines, keyboardType: keyboardType, inputFormatters: inputFormatters, enabled: enabled,
            decoration: InputDecoration(
              hintText: hint, hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
              prefixIcon: Icon(icon, color: Colors.grey[500], size: 20),
              filled: true, fillColor: enabled ? Colors.white : Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 15.0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: Colors.grey[300]!)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: Colors.grey[350]!)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: Colors.blue[600]!, width: 1.5)),
              errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: const BorderSide(color: Colors.red, width: 1.0)),
              focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
              disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
            style: GoogleFonts.poppins(fontSize: MediaQuery.of(context).size.width < 400 ? 12 : 14, color: enabled ? Colors.black87 : Colors.grey.shade700),
            validator: validator, autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({ /* ... (SAMA seperti di EditProfileScreen lama) ... */
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
          Text(label, style: GoogleFonts.poppins(fontSize: MediaQuery.of(context).size.width < 400 ? 12 : 14, fontWeight: FontWeight.w500, color: Colors.black87)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller, obscureText: obscureText,
            decoration: InputDecoration(
              hintText: hint, hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
              prefixIcon: Icon(Icons.lock_outline_rounded, color: Colors.grey[500], size: 20),
              suffixIcon: IconButton(
                icon: Icon(obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey[500], size: MediaQuery.of(context).size.width < 400 ? 18 : 20),
                onPressed: onToggleVisibility, tooltip: obscureText ? 'Tampilkan' : 'Sembunyikan',
              ),
              filled: true, fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 15.0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: Colors.grey[300]!)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: Colors.grey[350]!)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide(color: Colors.blue[600]!, width: 1.5)),
              errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: const BorderSide(color: Colors.red, width: 1.0)),
              focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
            ),
            style: GoogleFonts.poppins(fontSize: 14), validator: validator, autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
        ]));
  }

  Widget _buildCroppingUI(ProfileProvider provider) { /* ... (SAMA, tapi panggil _confirmCrop(provider) dan _cancelCrop(provider)) ... */
    if (_imagePathForCropping == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _cancelCrop(provider));
      return const Center(child: CircularProgressIndicator());
    }
    return Container(
      color: Colors.black,
      child: Column(children: <Widget>[
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CropImage(
                controller: _cropController, key: ValueKey(_imagePathForCropping),
                image: Image.file(File(_imagePathForCropping!)),
                gridColor: Colors.white.withOpacity(0.5), gridCornerSize: 25, gridThinWidth: 1, gridThickWidth: 3,
                scrimColor: Colors.black.withOpacity(0.5), alwaysShowThirdLines: true, minimumImageSize: 50,
              ),
            ),
          ),
          Container(
            color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: <Widget>[
                TextButton.icon(icon: const Icon(Icons.close, color: Colors.redAccent), label: const Text('Batal', style: TextStyle(color: Colors.redAccent)), onPressed: _isSavingCrop ? null : () => _cancelCrop(provider)),
                TextButton.icon(icon: const Icon(Icons.check, color: Colors.green), label: const Text('Konfirmasi', style: TextStyle(color: Colors.green)), onPressed: _isSavingCrop ? null : () => _confirmCrop(provider)),
              ],
            ),
          )
        ]));
  }


 @override
  Widget build(BuildContext context) {
    // Dapatkan provider dari context
    final profileProvider = context.watch<ProfileProvider>();

    // Update _currentDisplayImageFile jika ada perubahan di provider.newTempProfileImageFile
    // Ini untuk sinkronisasi preview jika picker/cropper dihandle provider
    if (profileProvider.newTempProfileImageFile != null &&
        _currentDisplayImageFile?.path != profileProvider.newTempProfileImageFile!.path) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
             if (mounted) {
                setState(() {
                  _currentDisplayImageFile = profileProvider.newTempProfileImageFile;
                });
             }
          });
    }


    return PopScope(
      canPop: !_isCropping && !profileProvider.isUpdatingProfile && !_isSavingCrop,
      onPopInvoked: (didPop) {
        if (!didPop && _isCropping) _cancelCrop(profileProvider);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        appBar: AppBar(
          title: Text(_isCropping ? 'Potong Gambar Profil' : 'Edit Profil Pengguna', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.blue.shade800)),
          backgroundColor: Colors.white, surfaceTintColor: Colors.white, shadowColor: Colors.black26,
          iconTheme: IconThemeData(color: Colors.blue.shade700), elevation: 1.0, centerTitle: true,
          automaticallyImplyLeading: !_isCropping && !profileProvider.isUpdatingProfile,
          leading: _isCropping || profileProvider.isUpdatingProfile ? Container() : null,
          actions: [
            if (!_isCropping)
              profileProvider.isUpdatingProfile
                  ? const Padding(padding: EdgeInsets.only(right: 16.0), child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))))
                  : IconButton(
                      icon: Icon(Icons.save_alt_outlined, color: Colors.blue.shade700, size: 26),
                      tooltip: 'Simpan Perubahan',
                      onPressed: () => _saveProfileChanges(profileProvider),
                    ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 65,
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage: _currentDisplayImageFile != null && _currentDisplayImageFile!.existsSync()
                                ? FileImage(_currentDisplayImageFile!)
                                : null, // Tidak perlu fallback ke _originalImagePathBeforeEdit lagi di sini
                            child: (_currentDisplayImageFile == null || !_currentDisplayImageFile!.existsSync())
                                ? Icon(Icons.person_rounded, size: MediaQuery.of(context).size.width * 0.15, color: Colors.grey.shade400)
                                : null,
                          ),
                          Material(
                            color: Colors.blue.shade600, shape: const CircleBorder(), elevation: 2,
                            child: InkWell(
                              onTap: () => _showImageSourceActionSheet(context, profileProvider),
                              customBorder: const CircleBorder(),
                              child: const Padding(padding: EdgeInsets.all(8.0), child: Icon(Icons.edit, color: Colors.white, size: 20)),
                            ),
                          )
                        ],
                      ),
                      if (_currentDisplayImageFile != null) // Tombol hapus jika ada gambar
                        TextButton.icon(
                            icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade600, size: 18),
                            label: Text("Hapus Foto Profil", style: GoogleFonts.poppins(color: Colors.red.shade600, fontSize: 13)),
                            onPressed: () {
                                setState(() {
                                    _currentDisplayImageFile = null; // Hapus preview
                                    profileProvider.clearTemporaryImage(); // Bersihkan juga di provider
                                });
                            },
                        ),
                      const SizedBox(height: 25),
                      _buildTextField(controller: _nameController, label: 'Nama Lengkap', hint: 'Masukkan nama lengkap', icon: Icons.person_outline, validator: (v) => v == null || v.isEmpty ? 'Nama tidak boleh kosong' : null),
                      _buildTextField(controller: _emailController, label: 'Email', hint: 'Masukkan alamat email', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress, enabled: false, validator: (v) { if (v == null || v.isEmpty) return 'Email tidak boleh kosong'; if (!v.contains('@')) return 'Format email tidak valid'; return null; }),
                      _buildTextField(controller: _phoneController, label: 'Nomor Telepon', hint: 'Masukkan nomor telepon', icon: Icons.phone_outlined, keyboardType: TextInputType.phone, validator: (v) => v == null || v.isEmpty ? 'Nomor telepon tidak boleh kosong' : null),
                      const SizedBox(height: 10), Divider(thickness: 0.8, color: Colors.grey.shade300, indent: 20, endIndent: 20), const SizedBox(height: 10),
                      _buildPasswordField(controller: _newPasswordController, label: 'Kata Sandi Baru (Opsional)', hint: 'Kosongkan jika tidak diubah', obscureText: _obscureNewPassword, onToggleVisibility: () => setState(() => _obscureNewPassword = !_obscureNewPassword), validator: (v) { if (v != null && v.isNotEmpty && v.length < 6) return 'Minimal 6 karakter'; return null; }),
                      _buildPasswordField(controller: _confirmPasswordController, label: 'Konfirmasi Kata Sandi Baru', hint: 'Masukkan ulang kata sandi baru', obscureText: _obscureConfirmPassword, onToggleVisibility: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword), validator: (v) { if (_newPasswordController.text.isNotEmpty && (v == null || v.isEmpty)) return 'Konfirmasi wajib diisi'; if (_newPasswordController.text.isNotEmpty && v != _newPasswordController.text) return 'Kata sandi tidak cocok'; return null; }),
                      const SizedBox(height: 10), Divider(thickness: 0.8, color: Colors.grey.shade300, indent: 20, endIndent: 20), const SizedBox(height: 10),
                      _buildTextField(controller: _storeNameController, label: 'Nama Toko', hint: 'Masukkan nama toko', icon: Icons.storefront_outlined, validator: (v) => v == null || v.isEmpty ? 'Nama toko tidak boleh kosong' : null),
                      _buildTextField(controller: _storeAddressController, label: 'Alamat Toko', hint: 'Masukkan alamat toko', icon: Icons.location_on_outlined, validator: (v) => v == null || v.isEmpty ? 'Alamat toko tidak boleh kosong' : null),
                      // Tombol simpan dipindah ke AppBar
                    ],
                  ),
                ),
              ),
              if (_isCropping) _buildCroppingUI(profileProvider),
              if (_isSavingCrop) Container(color: Colors.black.withOpacity(0.5), child: const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))),
            ],
          ),
        ),
      ),
    );
  }
}