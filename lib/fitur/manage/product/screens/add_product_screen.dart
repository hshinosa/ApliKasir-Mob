// lib/fitur/manage/product/add_product_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:aplikasir_mobile/model/product_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_image/crop_image.dart';
// Hapus path_provider dan path jika tidak digunakan langsung di sini
// import 'package:path_provider/path_provider.dart';
// import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart'; // Impor Provider

// --- Impor Provider Produk ---
import 'package:aplikasir_mobile/fitur/manage/product/providers/product_provider.dart';
// Model dan DB Helper tidak diimpor langsung jika semua via provider
// import 'package:aplikasir_mobile/model/product_model.dart';
// import 'package:aplikasir_mobile/helper/db_helper.dart';

class AddProductScreen extends StatefulWidget {
  final int
      userId; // Tetap dibutuhkan untuk inisialisasi jika provider tidak di-create di atasnya
  final String? initialName;
  final String? initialCode;
  final File? initialImageFile; // Ini adalah temporary file dari scan

  const AddProductScreen({
    super.key,
    required this.userId, // Atau ambil dari ProductProvider jika sudah ada di tree
    this.initialName,
    this.initialCode,
    this.initialImageFile,
  });

  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  late CropController _cropController;

  late TextEditingController _nameController;
  late TextEditingController _codeController;
  final TextEditingController _stockController =
      TextEditingController(text: '0');
  final TextEditingController _costPriceController = TextEditingController();
  final TextEditingController _sellingPriceController = TextEditingController();

  File? _newCroppedImageFile; // File temporary hasil crop
  // Hapus _prefilledImageFile, gunakan _newCroppedImageFile dari widget.initialImageFile
  // Removed unused field _imageRemoved

  bool _isCropping = false;
  String? _originalImagePathForCropping;
  bool _isSavingCrop = false;
  bool _isSavingProduct = false; // State loading untuk tombol utama
  bool _imageRemoved = false; // Tracks if the image has been removed

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _codeController = TextEditingController(text: widget.initialCode ?? '');

    // Jika ada initialImageFile, set sebagai _newCroppedImageFile untuk preview
    if (widget.initialImageFile != null) {
      _newCroppedImageFile = widget.initialImageFile;
      // Tidak perlu _imageChanged atau _imageRemoved di sini, karena ini adalah state awal
    }

    _cropController = CropController(
      aspectRatio: 1.0,
      defaultCrop: const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9),
    );
    _costPriceController.text = _formatCurrencyInput(0);
    _sellingPriceController.text = _formatCurrencyInput(0);
  }

  // ... (Fungsi _formatCurrencyInput, _parseCurrencyInput, _pickImage, _confirmCrop, _cancelCrop, _showImageSourceActionSheet, _removeCurrentImage SAMA)
  // Di _confirmCrop, _newCroppedImageFile akan di-set.
  // Di _pickImage, _newCroppedImageFile dan _originalImagePathForCropping akan di-handle.
  // Di _removeCurrentImage, _newCroppedImageFile di-null-kan, _imageRemoved = true.
  // Pastikan _clearTemporaryCroppedFile menghapus _newCroppedImageFile.
  String _formatCurrencyInput(double value) {
    final formatter = NumberFormat("#,##0", "id_ID");
    return formatter.format(value);
  }

  double _parseCurrencyInput(String text) {
    try {
      String cleanText = text.replaceAll(RegExp(r'[^\d]'), '');
      return double.tryParse(cleanText) ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _stockController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _cropController.dispose();
    _clearTemporaryCroppedFile();
    // Hapus widget.initialImageFile JIKA ITU TEMPORARY dan tidak akan dipakai lagi.
    // Biasanya, provider yang memanggil screen ini sudah menghandle lifecycle file temporary.
    // if (widget.initialImageFile != null && widget.initialImageFile!.existsSync()) {
    //   widget.initialImageFile!.delete().catchError((e) => print("Error deleting initial temp file: $e"));
    // }
    super.dispose();
  }

  void _clearTemporaryCroppedFile() {
    if (_newCroppedImageFile != null && _newCroppedImageFile!.existsSync()) {
      // Jika _newCroppedImageFile adalah widget.initialImageFile, jangan hapus di sini.
      // Biarkan provider atau pemanggil yang handle.
      if (widget.initialImageFile == null ||
          widget.initialImageFile?.path != _newCroppedImageFile?.path) {
        _newCroppedImageFile!
            .delete()
            .catchError((e) {
              print("Error deleting temp crop file: $e");
              return _newCroppedImageFile!;
            });
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isSavingProduct || _isCropping) return;
    setState(() {
      _isCropping = false;
      _originalImagePathForCropping = null;
      // _clearTemporaryCroppedFile(); // Hati-hati jika _newCroppedImageFile adalah initialImageFile
      if (_newCroppedImageFile != widget.initialImageFile)
        _clearTemporaryCroppedFile();
      _newCroppedImageFile = null;
      _imageRemoved = false;
    });
    try {
      final pickedFile =
          await _picker.pickImage(source: source, imageQuality: 80);
      if (pickedFile != null) {
        setState(() {
          _originalImagePathForCropping = pickedFile.path;
          _isCropping = true;
        });
      }
    } catch (e) {
      print("Error picking image: $e");
      _showErrorSnackbar('Gagal memilih gambar: $e');
    }
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _confirmCrop() async {
    if (_originalImagePathForCropping == null ||
        _isSavingCrop ||
        _isSavingProduct) return;
    setState(() {
      _isSavingCrop = true;
    });
    try {
      ui.Image bitmap =
          await _cropController.croppedBitmap(quality: FilterQuality.high);
      ByteData? byteData =
          await bitmap.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception("Tidak bisa konversi gambar.");
      Uint8List pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // Buat nama file yang lebih unik untuk crop
      final filePath = '${tempDir.path}/temp_crop_add_screen_$timestamp.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      // Hapus file crop temporary SEBELUMNYA, kecuali jika itu initialImageFile
      if (_newCroppedImageFile != null &&
          _newCroppedImageFile != widget.initialImageFile) {
        _clearTemporaryCroppedFile();
      }

      setState(() {
        _newCroppedImageFile = file; // Ini adalah file temporary baru
        _isCropping = false;
        _originalImagePathForCropping = null;
        _imageRemoved = false;
      });
    } catch (e) {
      print("Error cropping: $e");
      _showErrorSnackbar('Gagal memotong gambar: $e');
    } finally {
      if (mounted) setState(() => _isSavingCrop = false);
    }
  }

  void _cancelCrop() {
    if (_isSavingProduct) return;
    setState(() {
      _isCropping = false;
      if (_originalImagePathForCropping != null) {
        final originalFile = File(_originalImagePathForCropping!);
        originalFile.exists().then((exists) {
          if (exists)
            originalFile
                .delete()
                .catchError((e) {
                  print("Error deleting original: $e");
                  return originalFile;
                });
        });
        _originalImagePathForCropping = null;
      }
      // Jika batal crop, kembalikan _newCroppedImageFile ke widget.initialImageFile jika ada
      // atau null jika tidak ada initial. Ini agar preview kembali ke gambar awal (jika dari scan)
      if (widget.initialImageFile != null) {
        _newCroppedImageFile = widget.initialImageFile;
        _imageRemoved = false; // Gambar awal tidak jadi dihapus
      } else {
        _newCroppedImageFile = null;
      }
    });
  }

  void _showImageSourceActionSheet(BuildContext context) {
    if (_isCropping || _isSavingProduct) return;
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.0))),
        builder: (BuildContext context) {
          return SafeArea(
              child: Wrap(children: <Widget>[
            ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Pilih dari Galeri'),
                onTap: () => _pickImage(ImageSource.gallery)),
            ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Ambil Foto dengan Kamera'),
                onTap: () => _pickImage(ImageSource.camera)),
          ]));
        });
  }

  void _removeCurrentImage() {
    if (_isSavingProduct || _isCropping) return;
    setState(() {
      if (_newCroppedImageFile != widget.initialImageFile)
        _clearTemporaryCroppedFile(); // Hapus temp crop jika bukan initial
      _newCroppedImageFile = null; // Preview jadi kosong
      _imageRemoved = true; // Tandai gambar dihapus
    });
    _showInfoSnackbar('Gambar dihapus.');
  }

  // --- Logika Simpan Produk (MEMANGGIL PROVIDER) ---
  Future<void> _addProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSavingProduct) return;
    setState(() => _isSavingProduct = true);

    // Ambil ProductProvider
    final productProvider = context.read<ProductProvider>();

    final Product? savedProduct = await productProvider.addProduct(
      name: _nameController.text.trim(),
      code: _codeController.text.trim(),
      stock: int.tryParse(_stockController.text.trim()) ?? 0,
      costPrice: _parseCurrencyInput(_costPriceController.text),
      sellingPrice: _parseCurrencyInput(_sellingPriceController.text),
      // Kirim _newCroppedImageFile (bisa jadi ini adalah widget.initialImageFile jika tidak diubah, atau file crop baru)
      // Provider akan handle penyimpanan permanen.
      tempImageFile: _newCroppedImageFile,
    );

    if (!mounted) return;

    if (savedProduct != null) {
      _showSuccessSnackbar('Produk baru berhasil ditambahkan!');
      // Jika widget.initialImageFile adalah temporary dan sudah dipakai, mungkin perlu dihapus di sini atau oleh pemanggil ProductScreen
      // Namun, karena _newCroppedImageFile yg dikirim, dan provider meng-copy-nya, file asli _newCroppedImageFile bisa dihapus
      // setelah berhasil (jika itu bukan widget.initialImageFile).
      // _clearTemporaryCroppedFile() akan menghapus _newCroppedImageFile JIKA BUKAN initial.
      if (_newCroppedImageFile != null &&
          _newCroppedImageFile != widget.initialImageFile) {
        _newCroppedImageFile!
            .delete()
            .catchError((e) {
              print("Error deleting final temp add file: $e");
              return _newCroppedImageFile!;
            });
      }
      Navigator.pop(context, true); // Kirim true untuk refresh
    } else {
      // Ambil error message dari provider jika ada
      if (productProvider.errorMessage.isNotEmpty) {
        _showErrorSnackbar(
            'Gagal menyimpan produk: ${productProvider.errorMessage}');
      } else {
        _showErrorSnackbar('Gagal menyimpan produk.');
      }
    }
    setState(() => _isSavingProduct = false);
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green));
  }

  void _showInfoSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  // --- Widget UI SAMA seperti sebelumnya (_buildTextField, _buildCurrencyField, _buildImagePicker, _buildCroppingUI) ---
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
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
            inputFormatters: inputFormatters,
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
            style: GoogleFonts.poppins(fontSize: 14),
            validator: validator,
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
        ]));
  }

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
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              ThousandsSeparatorInputFormatter()
            ],
            decoration: InputDecoration(
              prefixText: 'Rp ',
              prefixStyle: GoogleFonts.poppins(
                  color: Colors.grey.shade600, fontSize: 14),
              hintText: '0',
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
            style: GoogleFonts.poppins(fontSize: 14),
            validator: validator,
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
        ]));
  }

  Widget _buildImagePicker() {
    ImageProvider? currentImage;
    // Gunakan _newCroppedImageFile untuk preview karena ini yang akan dikirim
    if (_newCroppedImageFile != null) {
      currentImage = FileImage(_newCroppedImageFile!);
    }
    // Tidak perlu _prefilledImageFile lagi jika _newCroppedImageFile di-init dari widget.initialImageFile

    return Column(children: [
      Text("Gambar Produk (Opsional)",
          style:
              GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
      const SizedBox(height: 15),
      InkWell(
        onTap: () => _showImageSourceActionSheet(context),
        child: Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            image: currentImage != null
                ? DecorationImage(image: currentImage, fit: BoxFit.cover)
                : null,
          ),
          child: currentImage == null
              ? Center(
                  child: Icon(Icons.add_a_photo_outlined,
                      color: Colors.grey.shade500, size: 40))
              : null,
        ),
      ),
      if (currentImage != null)
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: TextButton.icon(
            icon: Icon(Icons.delete_outline,
                color: Colors.red.shade600, size: 18),
            label: Text("Hapus Gambar",
                style: GoogleFonts.poppins(
                    color: Colors.red.shade600, fontSize: 13)),
            onPressed: _removeCurrentImage,
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
        ),
    ]);
  }

  Widget _buildCroppingUI() {
    if (_originalImagePathForCropping == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _cancelCrop());
      return const Center(child: CircularProgressIndicator());
    }
    return Container(
        color: Colors.black,
        child: Column(children: <Widget>[
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CropImage(
                controller: _cropController,
                key: ValueKey(_originalImagePathForCropping),
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
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                TextButton.icon(
                    icon: const Icon(Icons.close, color: Colors.redAccent),
                    label: const Text('Batal',
                        style: TextStyle(color: Colors.redAccent)),
                    onPressed: _isSavingCrop ? null : _cancelCrop),
                TextButton.icon(
                    icon: const Icon(Icons.check, color: Colors.green),
                    label: const Text('Konfirmasi',
                        style: TextStyle(color: Colors.green)),
                    onPressed: _isSavingCrop ? null : _confirmCrop),
              ],
            ),
          )
        ]));
  }

  @override
  Widget build(BuildContext context) {
    // ... (Build method utama sama, hanya fungsi _addProduct yang berubah)
    // Pastikan untuk menyediakan ProductProvider di atas screen ini jika belum (misal di ManageScreen atau ProductScreen saat navigasi)
    return PopScope(
      canPop: !_isCropping && !_isSavingProduct && !_isSavingCrop,
      onPopInvoked: (didPop) {
        if (!didPop && _isCropping) _cancelCrop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        appBar: AppBar(
          title: Text(_isCropping ? 'Potong Gambar' : 'Tambah Produk Baru',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, color: Colors.blue.shade800)),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shadowColor: Colors.black26,
          iconTheme: IconThemeData(color: Colors.blue.shade700),
          elevation: 0.5,
          centerTitle: true,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: !_isCropping && !_isSavingProduct,
          leading: _isCropping || _isSavingProduct ? Container() : null,
        ),
        body: SafeArea(
            child: Stack(children: [
          SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                  key: _formKey,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildImagePicker(),
                        const SizedBox(height: 30),
                        _buildTextField(
                            controller: _nameController,
                            label: 'Nama Produk',
                            hint: 'Masukkan nama produk',
                            icon: Icons.label_outline,
                            validator: (v) => v == null || v.isEmpty
                                ? 'Nama produk wajib diisi'
                                : null),
                        _buildTextField(
                            controller: _codeController,
                            label: 'Kode Produk (SKU)',
                            hint: 'Masukkan kode unik produk',
                            icon: Icons.qr_code_2_outlined,
                            validator: (v) => v == null || v.isEmpty
                                ? 'Kode produk wajib diisi'
                                : null),
                        _buildTextField(
                            controller: _stockController,
                            label: 'Jumlah Stok Awal',
                            hint: '0',
                            icon: Icons.inventory_2_outlined,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            validator: (v) {
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
                              if (v == null || v.isEmpty)
                                return 'Harga modal wajib diisi';
                              if (_parseCurrencyInput(v) < 0)
                                return 'Harga tidak valid';
                              return null;
                            }),
                        _buildCurrencyField(
                            controller: _sellingPriceController,
                            label: 'Harga Jual',
                            icon: Icons.sell_outlined,
                            validator: (v) {
                              if (v == null || v.isEmpty)
                                return 'Harga jual wajib diisi';
                              final sell = _parseCurrencyInput(v);
                              if (sell < 0) return 'Harga tidak valid';
                              return null;
                            }),
                        const SizedBox(height: 35),
                        ElevatedButton.icon(
                          onPressed: _isSavingProduct || _isCropping
                              ? null
                              : _addProduct,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            disabledBackgroundColor:
                                Colors.blue[200]?.withOpacity(0.7),
                            elevation: 3,
                          ),
                          icon: _isSavingProduct
                              ? Container()
                              : const Icon(Icons.add_circle_outline, size: 20),
                          label: _isSavingProduct
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Text('Tambah Produk',
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600)),
                        ),
                      ]))),
          if (_isCropping) _buildCroppingUI(),
          if (_isSavingCrop)
            Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                    child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white)))),
        ])),
      ),
    );
  }
}

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  static final NumberFormat _formatter = NumberFormat("#,##0", "id_ID");
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue.copyWith(text: '');
    String newText = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (newText.isEmpty)
      return const TextEditingValue(
          text: '', selection: TextSelection.collapsed(offset: 0));
    try {
      double value = double.parse(newText);
      String formattedText = _formatter.format(value);
      return newValue.copyWith(
          text: formattedText,
          selection: TextSelection.collapsed(offset: formattedText.length));
    } catch (e) {
      print("Error formatting number: $e");
      return oldValue;
    }
  }
}
