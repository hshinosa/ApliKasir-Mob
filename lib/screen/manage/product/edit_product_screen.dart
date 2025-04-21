import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Untuk input formatter
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_image/crop_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart'; // Untuk parsing & formatting angka

// --- Sesuaikan path impor ini jika perlu ---
import 'package:aplikasir_mobile/model/product_model.dart';
import 'package:aplikasir_mobile/helper/db_helper.dart';

class EditProductScreen extends StatefulWidget {
  final Product initialProduct; // Menerima data produk awal

  const EditProductScreen({super.key, required this.initialProduct});

  @override
  _EditProductScreenState createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  late CropController _cropController;
  // Parser tidak diperlukan di state jika hanya dipakai di fungsi
  // final NumberFormat _currencyParser = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');

  // --- Controller untuk setiap field ---
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _stockController;
  late TextEditingController _costPriceController;
  late TextEditingController _sellingPriceController;

  // --- State untuk gambar produk ---
  File? _newCroppedImageFile;
  String? _savedImagePath; // Path gambar yang tersimpan
  bool _imageChanged = false; // Flag jika gambar baru dipilih/dihapus
  bool _imageRemoved = false; // Flag jika tombol hapus gambar ditekan

  // --- State untuk cropping dan saving ---
  bool _isCropping = false;
  String? _originalImagePathForCropping; // Path file asli yg dipilih untuk crop
  bool _isSavingCrop = false;
  bool _isSavingProduct = false; // Loading saat simpan ke DB

  @override
  void initState() {
    super.initState();

    // Inisialisasi Controller dengan data awal
    _nameController =
        TextEditingController(text: widget.initialProduct.namaProduk);
    _codeController =
        TextEditingController(text: widget.initialProduct.kodeProduk);
    _stockController = TextEditingController(
        text: widget.initialProduct.jumlahProduk.toString());
    // Format harga modal dan jual saat inisialisasi
    _costPriceController = TextEditingController(
        text: _formatCurrencyInput(widget.initialProduct.hargaModal));
    _sellingPriceController = TextEditingController(
        text: _formatCurrencyInput(widget.initialProduct.hargaJual));

    _savedImagePath = widget.initialProduct.gambarProduk;

    // Inisialisasi Crop Controller
    _cropController = CropController(
      aspectRatio: 1.0, // Rasio 1:1 untuk gambar produk
      defaultCrop: const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9), // Area crop default
    );
  }

  // Helper untuk format angka ke string Rp xxx.xxx (tanpa simbol)
  String _formatCurrencyInput(double value) {
    final formatter = NumberFormat("#,##0", "id_ID");
    return formatter.format(value);
  }

  // Helper untuk parse string format ribuan (Rp xxx.xxx) ke double
  double _parseCurrencyInput(String text) {
    try {
      // Hapus semua karakter kecuali digit
      String cleanText = text.replaceAll(RegExp(r'[^\d]'), '');
      return double.tryParse(cleanText) ?? 0.0;
    } catch (e) {
      print("Error parsing currency input '$text': $e");
      return 0.0; // Kembalikan 0 jika error
    }
  }

  @override
  void dispose() {
    // Dispose semua controller
    _nameController.dispose();
    _codeController.dispose();
    _stockController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _cropController.dispose();
    // Hapus file crop sementara jika ada
    _clearTemporaryCroppedFile();
    super.dispose();
  }

  // Hapus file temporary hasil crop jika ada
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

  // --- Fungsi Pilih Gambar ---
  Future<void> _pickImage(ImageSource source) async {
    // Jangan lakukan jika sedang proses simpan atau cropping
    if (_isSavingProduct || _isCropping) return;
    setState(() {
      _isCropping = false; // Keluar dari mode cropping jika sedang aktif
      _originalImagePathForCropping = null; // Reset path asli
      _clearTemporaryCroppedFile(); // Hapus file crop lama
      _newCroppedImageFile = null; // Reset file crop baru
      _imageChanged = false; // Reset flag perubahan gambar
      _imageRemoved = false; // Reset flag hapus gambar
    });

    try {
      final pickedFile = await _picker.pickImage(
          source: source, imageQuality: 80); // Atur kualitas gambar
      if (pickedFile != null) {
        setState(() {
          _originalImagePathForCropping =
              pickedFile.path; // Simpan path asli untuk crop
          _isCropping = true; // Masuk mode cropping
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
    // Tutup bottom sheet setelah memilih atau batal
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  // --- Fungsi Konfirmasi Hasil Crop ---
  Future<void> _confirmCrop() async {
    // Jangan lakukan jika path asli null atau sedang proses lain
    if (_originalImagePathForCropping == null ||
        _isSavingCrop ||
        _isSavingProduct) return;
    setState(() {
      _isSavingCrop = true;
    }); // Tampilkan loading crop

    try {
      // Dapatkan gambar hasil crop sebagai bitmap
      ui.Image bitmap =
          await _cropController.croppedBitmap(quality: FilterQuality.high);
      // Konversi ke byte data PNG
      ByteData? byteData =
          await bitmap.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception("Tidak bisa mengkonversi gambar.");
      Uint8List pngBytes = byteData.buffer.asUint8List();

      // Simpan byte data ke file temporary DULU
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${tempDir.path}/temp_crop_edit_prod_$timestamp.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      // Hapus file crop temporary SEBELUMNYA (jika ada)
      _clearTemporaryCroppedFile();

      // Update state dengan file baru hasil crop
      setState(() {
        _newCroppedImageFile = file; // File crop baru siap digunakan
        _isCropping = false; // Keluar mode cropping
        _originalImagePathForCropping = null; // Hapus path asli
        _imageChanged = true; // Tandai bahwa gambar sudah diubah
        _imageRemoved = false; // Pastikan flag hapus gambar false
      });
    } catch (e) {
      print("Error cropping image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memotong gambar: $e')),
        );
      }
    } finally {
      // Pastikan loading crop hilang meskipun error
      if (mounted) {
        setState(() {
          _isSavingCrop = false;
        });
      }
    }
  }

  // --- Fungsi Membatalkan Proses Crop ---
  void _cancelCrop() {
    // Jangan batalkan jika sedang menyimpan produk
    if (_isSavingProduct) return;
    setState(() {
      _isCropping = false; // Keluar mode cropping
      // Hapus file asli yg dipilih untuk crop jika belum diproses
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

  // --- Fungsi Menampilkan Bottom Sheet Pilihan Sumber Gambar ---
  void _showImageSourceActionSheet(BuildContext context) {
    // Jangan tampilkan jika sedang cropping atau menyimpan
    if (_isCropping || _isSavingProduct) return;
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          // Style bottom sheet
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
        ),
        builder: (BuildContext context) {
          // Konten Bottom Sheet
          return SafeArea(
            child: Wrap(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Pilih dari Galeri'),
                  onTap: () =>
                      _pickImage(ImageSource.gallery), // Panggil _pickImage
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Ambil Foto dengan Kamera'),
                  onTap: () =>
                      _pickImage(ImageSource.camera), // Panggil _pickImage
                ),
              ],
            ),
          );
        });
  }

  // --- Fungsi untuk Menandai Penghapusan Gambar Saat Ini ---
  void _removeCurrentImage() {
    // Jangan lakukan jika sedang proses
    if (_isSavingProduct || _isCropping) return;
    setState(() {
      _newCroppedImageFile = null; // Hapus referensi file crop baru (jika ada)
      _imageChanged = true; // Perubahan gambar (menjadi null/kosong)
      _imageRemoved = true; // Tandai bahwa gambar lama harus dihapus saat save
      // Jangan hapus _savedImagePath di state ini, file fisik dihapus saat _saveProduct
    });
    // Beri feedback ke pengguna
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Gambar akan dihapus saat disimpan.'),
      duration: Duration(seconds: 2),
    ));
  }

  // --- Fungsi Utama: Simpan Perubahan Produk ---
  Future<void> _saveProduct() async {
    // 1. Validasi Form
    if (!_formKey.currentState!.validate()) {
      return; // Hentikan jika form tidak valid
    }
    // 2. Cek apakah sedang proses simpan
    if (_isSavingProduct) return;

    // 3. Tampilkan loading simpan
    setState(() => _isSavingProduct = true);

    String? finalImagePath =
        _savedImagePath; // Mulai dengan path gambar yg sudah tersimpan

    try {
      // 4. Proses Gambar (jika ada perubahan)
      if (_imageChanged) {
        // Hanya proses jika flag _imageChanged true
        if (_imageRemoved) {
          // 4a. Jika gambar Dihapus (_imageRemoved true)
          // Hapus file fisik yang lama (jika ada) dari storage
          if (_savedImagePath != null && _savedImagePath!.isNotEmpty) {
            final oldImageFile = File(_savedImagePath!);
            if (await oldImageFile.exists()) {
              await oldImageFile.delete().catchError((e) =>
                  // ignore: invalid_return_type_for_catch_error
                  print("Error deleting old product image on removal: $e"));
            }
          }
          finalImagePath = null; // Path final di DB akan jadi null
        } else if (_newCroppedImageFile != null) {
          // 4b. Jika ada gambar BARU hasil crop (_newCroppedImageFile tidak null)
          // Pindahkan file temporary hasil crop ke lokasi penyimpanan permanen
          final documentsDir = await getApplicationDocumentsDirectory();
          // Buat subfolder berdasarkan ID pengguna untuk organisasi
          final imagesDir = Directory(p.join(
              documentsDir.path,
              'product_images', // Folder utama gambar produk
              widget.initialProduct.idPengguna.toString() // Subfolder per user
              ));
          if (!await imagesDir.exists()) {
            await imagesDir.create(
                recursive: true); // Buat folder jika belum ada
          }
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          // Buat nama file unik (misal: product_IDproduk_timestamp.png)
          final permanentPath = p.join(imagesDir.path,
              'product_${widget.initialProduct.id}_$timestamp.png');

          // Salin file temporary ke path permanen
          final permanentFile = await _newCroppedImageFile!.copy(permanentPath);
          finalImagePath = permanentFile.path; // Update path final

          // Hapus file temporary setelah berhasil disalin
          await _newCroppedImageFile!.delete();
          _newCroppedImageFile = null; // Reset state file temporary

          // Hapus gambar LAMA dari storage jika pathnya BEDA dengan yang baru
          if (_savedImagePath != null && _savedImagePath != finalImagePath) {
            final oldImageFile = File(_savedImagePath!);
            if (await oldImageFile.exists()) {
              await oldImageFile.delete().catchError((e) =>
                  // ignore: invalid_return_type_for_catch_error
                  print("Error deleting old product image on replacement: $e"));
            }
          }
        }
        // Jika _imageChanged true tapi _imageRemoved false dan _newCroppedImageFile null,
        // berarti ada error sebelumnya, path final tidak berubah.
      }
      // Jika _imageChanged false, maka finalImagePath tetap sama dengan _savedImagePath (tidak ada perubahan gambar)

      // 5. Siapkan Objek Produk yang Diupdate
      final updatedProduct = widget.initialProduct.copyWith(
        // Salin ID & idPengguna dari produk awal
        namaProduk: _nameController.text.trim(),
        kodeProduk: _codeController.text.trim(),
        jumlahProduk: int.tryParse(_stockController.text.trim()) ??
            0, // Konversi stok ke int
        hargaModal:
            _parseCurrencyInput(_costPriceController.text), // Parse harga modal
        hargaJual: _parseCurrencyInput(
            _sellingPriceController.text), // Parse harga jual
        gambarProduk: finalImagePath, // Gunakan path gambar final (bisa null)
        setGambarProdukNull: _imageRemoved, // Gunakan flag jika gambar dihapus
        updatedAt: DateTime.now().toIso8601String(), // Tambahkan waktu update
      );

      // 6. Update data di Database menggunakan DatabaseHelper
      final dbHelper = DatabaseHelper.instance; // Dapatkan instance DB Helper
      final rowsAffected =
          await dbHelper.updateProduct(updatedProduct); // Panggil fungsi update

      // 7. Handle Hasil Update
      if (rowsAffected > 0) {
        // Jika update berhasil (minimal 1 baris terpengaruh)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Produk berhasil diperbarui!'),
                backgroundColor: Colors.green),
          );
          // Kembali ke layar sebelumnya & kirim sinyal 'true' untuk refresh
          Navigator.pop(context, true);
        }
      } else {
        // Jika tidak ada baris terpengaruh (kemungkinan ID tidak ditemukan)
        throw Exception(
            'Gagal memperbarui produk di database (produk tidak ditemukan?).');
      }
    } catch (e) {
      // Tangkap error saat proses simpan/update
      print("Error saving product: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              // Tampilkan pesan error spesifik jika ada, atau pesan umum
              content: Text(
                  'Gagal menyimpan produk: ${e.toString().replaceFirst("Exception: ", "")}'),
              backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      // Pastikan loading hilang setelah selesai (baik sukses maupun error)
      if (mounted) {
        setState(() => _isSavingProduct = false);
      }
    }
  }

  // --- Helper Widget: TextFormField Biasa ---
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters, // Tambahkan parameter formatter
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters, // Gunakan formatter jika ada
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
            prefixIcon: Icon(icon, color: Colors.grey[500], size: 20),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 15.0, horizontal: 15.0),
            // Style Border (Normal, Enabled, Focused, Error)
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
          validator: validator, // Fungsi validasi
          autovalidateMode:
              AutovalidateMode.onUserInteraction, // Validasi saat interaksi
        ),
      ]),
    );
  }

  // --- Helper Widget: TextFormField Khusus Mata Uang ---
  Widget _buildCurrencyField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style:
                GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number, // Keyboard angka
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly, // Hanya izinkan angka
            // Formatter kustom untuk menambahkan titik ribuan saat mengetik
            ThousandsSeparatorInputFormatter(),
          ],
          decoration: InputDecoration(
            prefixText: 'Rp ', // Tampilkan simbol Rp di depan input
            prefixStyle:
                GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14),
            hintText: '0', // Hint jika kosong
            hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
            prefixIcon: Icon(icon, color: Colors.grey[500], size: 20),
            // Style Border, filled, dll.
            filled: true, fillColor: Colors.white,
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
          style: GoogleFonts.poppins(fontSize: 14), // Style teks input
          validator: validator, // Fungsi validasi
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
      ]),
    );
  }

  // --- Helper Widget: UI untuk Image Picker ---
  Widget _buildImagePicker() {
    ImageProvider? currentImage;
    // Prioritas penampilan gambar:
    // 1. Gambar baru hasil crop (_newCroppedImageFile)
    // 2. Gambar lama yang tersimpan (_savedImagePath), jika ada dan belum ditandai hapus (_imageRemoved == false)
    if (_newCroppedImageFile != null) {
      currentImage = FileImage(_newCroppedImageFile!);
    } else if (!_imageRemoved &&
        _savedImagePath != null &&
        File(_savedImagePath!).existsSync()) {
      // Pastikan file gambar lama ada sebelum menampilkannya
      currentImage = FileImage(File(_savedImagePath!));
    }

    // Tampilan widget image picker
    return Column(
      children: [
        Text("Gambar Produk (Opsional)",
            style:
                GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 15),
        // Area klik untuk memilih gambar
        InkWell(
          onTap: () => _showImageSourceActionSheet(
              context), // Panggil fungsi pilih sumber
          child: Container(
            width: 150, // Ukuran area gambar
            height: 150,
            decoration: BoxDecoration(
              color: Colors.grey.shade200, // Background jika tidak ada gambar
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300), // Border tipis
              // Tampilkan gambar jika ada (currentImage tidak null)
              image: currentImage != null
                  ? DecorationImage(
                      image: currentImage,
                      fit: BoxFit.cover) // Tampilkan gambar
                  : null, // Jika null, tampilkan child (icon)
            ),
            // Tampilkan icon 'tambah foto' jika tidak ada gambar
            child: currentImage == null
                ? Center(
                    child: Icon(Icons.add_a_photo_outlined,
                        color: Colors.grey.shade500, size: 40))
                : null, // Jika ada gambar, jangan tampilkan icon
          ),
        ),
        // Tombol "Hapus Gambar" (hanya muncul jika ada gambar yang ditampilkan)
        if (currentImage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: TextButton.icon(
              icon: Icon(Icons.delete_outline,
                  color: Colors.red.shade600, size: 18), // Icon hapus
              label: Text("Hapus Gambar",
                  style: GoogleFonts.poppins(
                      color: Colors.red.shade600, fontSize: 13)), // Teks tombol
              onPressed: _removeCurrentImage, // Panggil fungsi hapus gambar
              style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact), // Style tombol
            ),
          ),
      ],
    );
  }

  // --- Helper Widget: UI untuk Cropping Gambar ---
  Widget _buildCroppingUI() {
    // Jika path asli null (seharusnya tidak terjadi di sini), batal crop
    if (_originalImagePathForCropping == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _cancelCrop());
      return const Center(
          child: CircularProgressIndicator()); // Tampilkan loading sementara
    }

    // Tampilan utama saat cropping
    return Container(
      color: Colors.black, // Background hitam penuh saat cropping
      child: Column(
        children: <Widget>[
          // Area Crop Gambar
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0), // Padding di dalam area hitam
              child: CropImage(
                controller: _cropController, // Controller crop
                // Key penting jika sumber gambar bisa berubah agar widget di-rebuild
                key: ValueKey(_originalImagePathForCropping),
                // Sumber gambar dari file asli yang dipilih
                image: Image.file(File(_originalImagePathForCropping!)),
                // Style grid crop
                gridColor: Colors.white.withOpacity(0.5),
                gridCornerSize: 25,
                gridThinWidth: 1,
                gridThickWidth: 3,
                scrimColor:
                    Colors.black.withOpacity(0.5), // Warna overlay luar crop
                alwaysShowThirdLines: true, // Tampilkan garis bantu grid
                minimumImageSize: 50, // Ukuran minimum gambar (opsional)
              ),
            ),
          ),
          // Tombol Aksi Batal & Konfirmasi Crop
          Container(
            color: Colors.white, // Latar belakang putih untuk tombol
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceAround, // Tombol rata kiri-kanan
              children: <Widget>[
                // Tombol Batal
                TextButton.icon(
                  icon: const Icon(Icons.close, color: Colors.redAccent),
                  label: const Text('Batal',
                      style: TextStyle(color: Colors.redAccent)),
                  // Nonaktifkan tombol saat proses simpan crop
                  onPressed: _isSavingCrop ? null : _cancelCrop,
                ),
                // Tombol Konfirmasi
                TextButton.icon(
                  icon: const Icon(Icons.check, color: Colors.green),
                  label: const Text('Konfirmasi',
                      style: TextStyle(color: Colors.green)),
                  // Nonaktifkan tombol saat proses simpan crop
                  onPressed: _isSavingCrop ? null : _confirmCrop,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- Metode Build Utama ---
  @override
  Widget build(BuildContext context) {
    // PopScope untuk mencegah kembali saat cropping/saving tanpa konfirmasi
    return PopScope(
      canPop: !_isCropping &&
          !_isSavingProduct &&
          !_isSavingCrop, // Izinkan pop jika tidak sedang proses
      onPopInvoked: (didPop) {
        // Jika pop dicegah (karena canPop false) dan sedang cropping, batalkan crop
        if (!didPop && _isCropping) {
          _cancelCrop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FC), // Warna background konsisten
        // AppBar
        appBar: AppBar(
          // Judul dinamis berdasarkan state cropping
          title: Text(_isCropping ? 'Potong Gambar' : 'Edit Produk',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, color: Colors.blue.shade800)),
          backgroundColor: Colors.white, // Latar belakang AppBar
          iconTheme:
              IconThemeData(color: Colors.blue.shade700), // Warna ikon back
          elevation: 0.0, // Shadow tipis
          centerTitle: true, // Judul di tengah
          scrolledUnderElevation: 0,

          // Sembunyikan tombol back jika sedang cropping/saving
          automaticallyImplyLeading: !_isCropping && !_isSavingProduct,
          // Kosongkan leading jika tombol back disembunyikan
          leading: _isCropping || _isSavingProduct ? Container() : null,
        ),
        // Body Utama
        body: SafeArea(
          child: Stack(
            // Stack untuk menumpuk overlay loading/cropping
            children: [
              // --- Form Utama (Scrollable) ---
              SingleChildScrollView(
                padding: const EdgeInsets.all(24.0), // Padding form
                child: Form(
                  key: _formKey, // Kaitkan dengan GlobalKey form
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.center, // Konten rata tengah
                    children: [
                      // --- Bagian Input Gambar Produk ---
                      _buildImagePicker(), // Panggil helper widget image picker
                      const SizedBox(height: 30), // Jarak

                      // --- Input Fields ---
                      _buildTextField(
                        controller: _nameController,
                        label: 'Nama Produk',
                        hint: 'Masukkan nama produk',
                        icon: Icons.label_outline,
                        validator: (v) => v == null || v.isEmpty
                            ? 'Nama produk wajib diisi'
                            : null, // Validasi wajib isi
                      ),
                      _buildTextField(
                        controller: _codeController,
                        label: 'Kode Produk (SKU)',
                        hint: 'Masukkan kode unik produk',
                        icon: Icons.qr_code_2_outlined,
                        validator: (v) => v == null || v.isEmpty
                            ? 'Kode produk wajib diisi'
                            : null, // Validasi wajib isi
                      ),
                      _buildTextField(
                          controller: _stockController,
                          label: 'Jumlah Stok',
                          hint: '0',
                          icon: Icons.inventory_2_outlined,
                          keyboardType: TextInputType.number, // Keyboard angka
                          inputFormatters: [
                            // Hanya izinkan angka
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          validator: (v) {
                            // Validasi angka & wajib isi
                            if (v == null || v.isEmpty)
                              return 'Jumlah stok wajib diisi';
                            if (int.tryParse(v) == null)
                              return 'Masukkan angka valid';
                            return null;
                          }),
                      _buildCurrencyField(
                          controller: _costPriceController,
                          label: 'Harga Modal (Beli)',
                          icon: Icons.attach_money,
                          validator: (v) {
                            // Validasi angka & wajib isi
                            if (v == null || v.isEmpty)
                              return 'Harga modal wajib diisi';
                            if (_parseCurrencyInput(v) < 0)
                              return 'Harga tidak valid'; // Harga tidak boleh minus
                            return null;
                          }),
                      _buildCurrencyField(
                          controller: _sellingPriceController,
                          label: 'Harga Jual',
                          icon: Icons.sell_outlined,
                          validator: (v) {
                            // Validasi angka, wajib isi, & perbandingan (opsional)
                            if (v == null || v.isEmpty)
                              return 'Harga jual wajib diisi';
                            _parseCurrencyInput(
                                _costPriceController.text); // Ambil harga modal
                            final sell =
                                _parseCurrencyInput(v); // Ambil harga jual
                            if (sell < 0) return 'Harga tidak valid';
                            // if (sell < cost) return 'Harga jual tidak boleh lebih rendah dari modal'; // Validasi opsional
                            return null;
                          }),

                      const SizedBox(height: 35), // Jarak sebelum tombol

                      // --- Tombol Simpan ---
                      ElevatedButton.icon(
                        // Nonaktifkan tombol saat sedang menyimpan atau cropping
                        onPressed: _isSavingProduct || _isCropping
                            ? null
                            : _saveProduct,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700, // Warna tombol
                          foregroundColor: Colors.white, // Warna teks & ikon
                          minimumSize:
                              const Size(double.infinity, 50), // Ukuran tombol
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10)), // Bentuk tombol
                          disabledBackgroundColor: Colors.blue[200]
                              ?.withOpacity(0.7), // Warna saat disabled
                          elevation: 3, // Shadow tombol
                        ),
                        // Tampilkan ikon simpan atau loading indicator
                        icon: _isSavingProduct
                            ? Container() // Sembunyikan ikon saat loading
                            : const Icon(Icons.save_outlined, size: 20),
                        // Tampilkan teks "Simpan" atau loading indicator
                        label: _isSavingProduct
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text('Simpan Perubahan',
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),

              // --- Overlay UI Cropping (Ditampilkan jika _isCropping true) ---
              if (_isCropping) _buildCroppingUI(), // Panggil helper UI cropping

              // --- Overlay Loading saat Simpan Crop (Ditampilkan jika _isSavingCrop true) ---
              if (_isSavingCrop)
                Container(
                  color: Colors.black
                      .withOpacity(0.5), // Background semi-transparan
                  child: const Center(
                      child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white))), // Indikator putih
                ),

              // --- Overlay Loading saat Simpan Produk (Sudah ada di dalam tombol) ---
              // Bisa ditambahkan overlay full screen jika diinginkan, tapi di tombol sudah cukup jelas
            ],
          ),
        ),
      ),
    );
  }
}

// --- Helper Class untuk Format Input Ribuan ---
// (Kelas ini tetap sama, berfungsi untuk memformat input angka dengan titik ribuan)
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  static final NumberFormat _formatter = NumberFormat("#,##0", "id_ID");

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Jika teks dihapus atau kosong
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Hapus semua karakter non-digit
    String newText = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    // Jika setelah dibersihkan jadi kosong (misal input awalnya '.')
    if (newText.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Parse ke double dan format ulang
    try {
      double value = double.parse(newText);
      String formattedText = _formatter.format(value);

      // Kembalikan TextEditingValue dengan teks terformat dan posisi kursor di akhir
      return newValue.copyWith(
        text: formattedText,
        selection: TextSelection.collapsed(offset: formattedText.length),
      );
    } catch (e) {
      // Jika parsing gagal, kembalikan nilai lama untuk mencegah crash
      print("Error formatting number: $e");
      return oldValue;
    }
  }
}
