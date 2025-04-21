import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_image/crop_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';

// --- Sesuaikan path impor model dan helper ---
import 'package:aplikasir_mobile/model/product_model.dart';
import 'package:aplikasir_mobile/helper/db_helper.dart';

class AddProductScreen extends StatefulWidget {
  final int userId;
  final String? initialName;
  final String? initialCode;
  final File? initialImageFile;

  const AddProductScreen({
    super.key,
    required this.userId,
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

  File? _newCroppedImageFile;
  File? _prefilledImageFile; // File dari parameter
  bool _imageRemoved = false;

  bool _isCropping = false;
  String? _originalImagePathForCropping;
  bool _isSavingCrop = false;
  bool _isSavingProduct = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _codeController = TextEditingController(text: widget.initialCode ?? '');
    _prefilledImageFile = widget.initialImageFile;
    if (_prefilledImageFile != null) {} // Anggap berubah jika ada prefilled

    _cropController = CropController(
      aspectRatio: 1.0,
      defaultCrop: const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9),
    );
    _costPriceController.text = _formatCurrencyInput(0);
    _sellingPriceController.text = _formatCurrencyInput(0);
  }

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
    _clearPrefilledImageFile(); // Hapus prefilled juga saat dispose
    super.dispose();
  }

  void _clearTemporaryCroppedFile() {
    if (_newCroppedImageFile != null && _newCroppedImageFile!.existsSync()) {
      _newCroppedImageFile!
          .delete()
          // ignore: invalid_return_type_for_catch_error
          .catchError((e) => print("Error deleting temp crop file: $e"));
    }
  }

  void _clearPrefilledImageFile() {
    if (_prefilledImageFile != null && _prefilledImageFile!.existsSync()) {
      // Asumsi file prefilled selalu temporary
      _prefilledImageFile!
          .delete()
          // ignore: invalid_return_type_for_catch_error
          .catchError((e) => print("Error deleting prefilled image file: $e"));
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isSavingProduct || _isCropping) return;
    setState(() {
      _isCropping = false;
      _originalImagePathForCropping = null;
      _clearTemporaryCroppedFile();
      _newCroppedImageFile = null;
      _clearPrefilledImageFile();
      _prefilledImageFile = null; // Hapus prefilled
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
      final filePath = '${tempDir.path}/temp_crop_add_$timestamp.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);
      _clearTemporaryCroppedFile();
      _clearPrefilledImageFile(); // Hapus prefilled juga
      setState(() {
        _newCroppedImageFile = file;
        _prefilledImageFile = null;
        _isCropping = false;
        _originalImagePathForCropping = null;
        _imageRemoved = false;
      });
    } catch (e) {
      print("Error cropping: $e");
      _showErrorSnackbar('Gagal memotong gambar: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSavingCrop = false;
        });
      }
    }
  }

  void _cancelCrop() {
    if (_isSavingProduct) return;
    setState(() {
      _isCropping = false;
      if (_originalImagePathForCropping != null) {
        final originalFile = File(_originalImagePathForCropping!);
        originalFile.exists().then((exists) {
          if (exists) {
            originalFile
                .delete()
                // ignore: invalid_return_type_for_catch_error
                .catchError((e) => print("Error deleting original: $e"));
          }
        });
        _originalImagePathForCropping = null;
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
      _clearTemporaryCroppedFile();
      _newCroppedImageFile = null;
      _clearPrefilledImageFile();
      _prefilledImageFile = null;
      _imageRemoved = true;
    });
    _showInfoSnackbar('Gambar dihapus.');
  }

  Future<void> _addProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSavingProduct) return;
    setState(() => _isSavingProduct = true);
    String? finalImagePath;

    try {
      File? imageToSave;
      if (_newCroppedImageFile != null) {
        imageToSave = _newCroppedImageFile;
      } else if (_prefilledImageFile != null && !_imageRemoved) {
        imageToSave = _prefilledImageFile;
      }

      if (imageToSave != null) {
        final documentsDir = await getApplicationDocumentsDirectory();
        final imagesDir = Directory(p.join(
            documentsDir.path, 'product_images', widget.userId.toString()));
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final permanentPath = p.join(
            imagesDir.path, 'product_new_${widget.userId}_$timestamp.png');
        final permanentFile = await imageToSave.copy(permanentPath);
        finalImagePath = permanentFile.path;
        await imageToSave.delete(); // Hapus temporary
        if (imageToSave == _newCroppedImageFile) _newCroppedImageFile = null;
        if (imageToSave == _prefilledImageFile) _prefilledImageFile = null;
      }

      final newProduct = Product(
        idPengguna: widget.userId,
        namaProduk: _nameController.text.trim(),
        kodeProduk: _codeController.text.trim(),
        jumlahProduk: int.tryParse(_stockController.text.trim()) ?? 0,
        hargaModal: _parseCurrencyInput(_costPriceController.text),
        hargaJual: _parseCurrencyInput(_sellingPriceController.text),
        gambarProduk: finalImagePath,
      );

      final dbHelper = DatabaseHelper.instance;
      final productId = await dbHelper.insertProduct(newProduct);

      if (!mounted) return; // Cek mounted setelah await

      if (productId > 0) {
        _showSuccessSnackbar('Produk baru berhasil ditambahkan!');
        Navigator.pop(context, true);
      } else {
        throw Exception('Gagal menambahkan produk ke database.');
      }
    } catch (e) {
      print("Error saving new product: $e");
      if (finalImagePath != null) {
        // Rollback gambar
        final savedImg = File(finalImagePath);
        try {
          if (await savedImg.exists()) await savedImg.delete();
        } catch (imgErr) {
          print("Error deleting image on failed save: $imgErr");
        }
      }
      if (mounted) {
        _showErrorSnackbar(
            'Gagal menyimpan produk: ${e.toString().replaceFirst("Exception: ", "")}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingProduct = false);
      }
    }
  }

  // --- Helper Snackbar ---
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

  // --- Helper Build TextField ---
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

  // --- Helper Build Currency Field ---
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
              ThousandsSeparatorInputFormatter(),
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

  // --- Helper Build Image Picker ---
  Widget _buildImagePicker() {
    ImageProvider? currentImage;
    if (_newCroppedImageFile != null) {
      currentImage = FileImage(_newCroppedImageFile!);
    } else if (_prefilledImageFile != null && !_imageRemoved) {
      currentImage = FileImage(_prefilledImageFile!);
    }

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

  // --- Helper Build Cropping UI ---
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
        ]));
  }

  // --- Build Method Utama ---
  @override
  Widget build(BuildContext context) {
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
                              : null,
                        ),
                        _buildTextField(
                          controller: _codeController,
                          label: 'Kode Produk (SKU)',
                          hint: 'Masukkan kode unik produk',
                          icon: Icons.qr_code_2_outlined,
                          validator: (v) => v == null || v.isEmpty
                              ? 'Kode produk wajib diisi'
                              : null,
                        ),
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
                              /* final cost = _parseCurrencyInput(_costPriceController.text); if (sell < cost) return 'Harga jual < modal'; */ return null;
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
} // End of _AddProductScreenState

// --- Helper Class ThousandsSeparatorInputFormatter ---
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  static final NumberFormat _formatter = NumberFormat("#,##0", "id_ID");
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }
    String newText = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (newText.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    try {
      double value = double.parse(newText);
      String formattedText = _formatter.format(value);
      return newValue.copyWith(
        text: formattedText,
        selection: TextSelection.collapsed(offset: formattedText.length),
      );
    } catch (e) {
      print("Error formatting number: $e");
      return oldValue;
    }
  }
} // End of ThousandsSeparatorInputFormatter
