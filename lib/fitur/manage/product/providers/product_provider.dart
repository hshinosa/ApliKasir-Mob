// lib/fitur/manage/product/providers/product_provider.dart
import 'dart:io';
import 'dart:convert'; // Untuk jsonDecode
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Untuk OpenFoodFacts
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:google_fonts/google_fonts.dart'; // Untuk dialog password

import 'package:aplikasir_mobile/model/product_model.dart';
import 'package:aplikasir_mobile/helper/db_helper.dart';
import 'package:aplikasir_mobile/model/user_model.dart'; // Untuk User di dialog password
import 'package:aplikasir_mobile/utils/auth_utils.dart'; // Untuk verifyPassword

// Definisikan FetchedProductData di sini atau impor dari path yang benar
class FetchedProductData {
  final String? name;
  final String? code;
  final File? imageFile; // Ini akan jadi temporary file
  FetchedProductData({this.name, this.code, this.imageFile});
}

class ProductProvider extends ChangeNotifier {
  final int userId;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final BarcodeScanner _barcodeScanner =
      BarcodeScanner(formats: [BarcodeFormat.qrCode, BarcodeFormat.ean13, BarcodeFormat.upca, BarcodeFormat.code128]); // Tambah format lain

  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  String _errorMessage = '';
  bool _sortAscending = true; // Default A-Z by name
  String _searchQuery = '';
  bool _isProcessingBarcode = false;
  bool _isDialogActionLoading = false; // Untuk loading di dialog

  // Getters
  List<Product> get filteredProducts => _filteredProducts;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  bool get sortAscending => _sortAscending;
  String get searchQuery => _searchQuery;
  bool get isProcessingBarcode => _isProcessingBarcode;
  bool get isDialogActionLoading => _isDialogActionLoading;


  ProductProvider({required this.userId}) {
    loadProducts();
  }

  @override
  void dispose() {
    _barcodeScanner.close();
    super.dispose();
  }

  Future<void> loadProducts() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    try {
      _allProducts = await _dbHelper.getProductsByUserId(userId);
      _applyFiltersAndSort();
    } catch (e) {
      _errorMessage = 'Gagal memuat produk: ${e.toString()}';
      _allProducts = [];
      _filteredProducts = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase().trim();
    _applyFiltersAndSort();
  }

  void toggleSortOrder() {
    _sortAscending = !_sortAscending;
    _applyFiltersAndSort();
  }

  void _applyFiltersAndSort() {
    List<Product> tempFiltered = List.from(_allProducts);

    if (_searchQuery.isNotEmpty) {
      tempFiltered = tempFiltered.where((product) {
        final nameLower = product.namaProduk.toLowerCase();
        final codeLower = product.kodeProduk.toLowerCase();
        return nameLower.contains(_searchQuery) ||
            codeLower.contains(_searchQuery);
      }).toList();
    }

    tempFiltered.sort((a, b) {
      int comparison =
          a.namaProduk.toLowerCase().compareTo(b.namaProduk.toLowerCase());
      return _sortAscending ? comparison : -comparison;
    });

    _filteredProducts = tempFiltered;
    notifyListeners();
  }

  // --- Helper untuk menyimpan gambar ke storage permanen lokal ---
  Future<String?> _saveImageToPermanentLocation(File tempImageFile,
      {required int userId, int? localProductIdForName}) async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final imagesDir =
          Directory(p.join(documentsDir.path, 'product_images', userId.toString()));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final String fileName = localProductIdForName != null
          ? 'prod_${localProductIdForName}_$timestamp.png'
          : 'new_prod_${userId}_$timestamp.png';
      final permanentPath = p.join(imagesDir.path, fileName);
      final permanentFile = await tempImageFile.copy(permanentPath);
      print("Image saved to permanent location: ${permanentFile.path}");
      return permanentFile.path;
    } catch (e) {
      print("Error saving image to permanent location: $e");
      return null;
    }
  }

  // --- Helper untuk menghapus gambar lokal ---
  Future<void> _deleteLocalImage(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return;
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        print("Deleted local image: $imagePath");
      }
    } catch (e) {
      print("Error deleting local image $imagePath: $e");
    }
  }

  Future<Product?> addProduct({
    required String name,
    required String code,
    required int stock,
    required double costPrice,
    required double sellingPrice,
    File? tempImageFile, // Temporary file from AddProductScreen's picker/cropper
  }) async {
    _isLoading = true; // Bisa juga pakai flag loading lain untuk aksi ini
    _errorMessage = '';
    notifyListeners();

    String? finalLocalImagePath;
    if (tempImageFile != null) {
      finalLocalImagePath = await _saveImageToPermanentLocation(tempImageFile, userId: userId);
      if (finalLocalImagePath == null) {
        _errorMessage = "Gagal menyimpan gambar produk.";
        _isLoading = false;
        notifyListeners();
        return null;
      }
    }

    final newProduct = Product(
      idPengguna: userId,
      namaProduk: name,
      kodeProduk: code,
      jumlahProduk: stock,
      hargaModal: costPrice,
      hargaJual: sellingPrice,
      gambarProduk: finalLocalImagePath,
      createdAt: DateTime.now(), // Set created_at
      updatedAt: DateTime.now(), // Set updated_at
      syncStatus: 'new',
    );

    try {
      final productId = await _dbHelper.insertProductLocal(newProduct);
      await loadProducts(); // Reload list
      _isLoading = false;
      notifyListeners();
      return newProduct.copyWith(id: productId); // Kembalikan dengan ID lokal
    } catch (e) {
      _errorMessage = "Gagal menambah produk: ${e.toString()}";
      // Rollback gambar jika gagal simpan DB
      if (finalLocalImagePath != null) await _deleteLocalImage(finalLocalImagePath);
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<Product?> updateProduct({
    required Product existingProduct,
    required String name,
    required String code,
    required int stock,
    required double costPrice,
    required double sellingPrice,
    File? tempNewImageFile, // Temporary file from EditProductScreen
    bool imageWasRemovedByUser = false, // Dari EditProductScreen
  }) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    String? finalLocalImagePath = existingProduct.gambarProduk;

    if (imageWasRemovedByUser) {
      if (existingProduct.gambarProduk != null) {
        await _deleteLocalImage(existingProduct.gambarProduk!);
      }
      finalLocalImagePath = null;
    } else if (tempNewImageFile != null) {
      // Ada gambar baru, hapus yang lama (jika ada), simpan yang baru
      if (existingProduct.gambarProduk != null) {
        await _deleteLocalImage(existingProduct.gambarProduk!);
      }
      finalLocalImagePath = await _saveImageToPermanentLocation(tempNewImageFile, userId: userId, localProductIdForName: existingProduct.id);
      if (finalLocalImagePath == null) {
        _errorMessage = "Gagal menyimpan gambar baru.";
        _isLoading = false;
        notifyListeners();
        return null;
      }
    }

    final updatedProduct = existingProduct.copyWith(
      namaProduk: name,
      kodeProduk: code,
      jumlahProduk: stock,
      hargaModal: costPrice,
      hargaJual: sellingPrice,
      gambarProduk: finalLocalImagePath,
      setGambarProdukNull: imageWasRemovedByUser, // Untuk model
      updatedAt: DateTime.now(),
      syncStatus: (existingProduct.syncStatus == 'new') ? 'new' : 'updated',
    );

    try {
      await _dbHelper.updateProductLocal(updatedProduct);
      await loadProducts(); // Reload list
      _isLoading = false;
      notifyListeners();
      return updatedProduct;
    } catch (e) {
      _errorMessage = "Gagal memperbarui produk: ${e.toString()}";
      // Jika gambar baru gagal disimpan ke DB, mungkin perlu rollback gambar baru yg sudah disimpan permanen
      // Tapi ini kompleks, untuk saat ini biarkan.
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteProduct(BuildContext context, Product product) async {
    if (product.id == null) {
      _errorMessage = "ID Produk tidak valid untuk dihapus.";
      notifyListeners();
      return false;
    }
    
    _isDialogActionLoading = true; // Untuk dialog
    notifyListeners();

    final bool? passwordConfirmed = await _showPasswordConfirmationDialog(context);
    
    _isDialogActionLoading = false; // Selesai dialog
    notifyListeners();

    if (passwordConfirmed != true) {
       if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Penghapusan dibatalkan (password salah/batal).'), backgroundColor: Colors.orange),
          );
       }
       return false;
    }

    _isLoading = true; // Loading untuk proses hapus
    _errorMessage = '';
    notifyListeners();

    try {
      // Hapus gambar terkait dari storage lokal
      if (product.gambarProduk != null) {
        await _deleteLocalImage(product.gambarProduk!);
      }
      // Hapus dari database
      await _dbHelper.softDeleteProductLocal(product.id!, userId);
      await loadProducts(); // Reload list
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = "Gagal menghapus produk: ${e.toString()}";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // --- Password Confirmation Dialog (Adaptasi dari CustomerProvider) ---
  Future<bool?> _showPasswordConfirmationDialog(BuildContext context) async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    // bool dialogIsLoading = false; // Diganti _isDialogActionLoading
    bool obscurePassword = true;
    String? dialogErrorMessage;

    final ShapeBorder dialogShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0));
    final EdgeInsets dialogActionsPadding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0);
    TextStyle dialogTitleStyle(BuildContext ctx) => GoogleFonts.poppins(
      fontWeight: FontWeight.w600, fontSize: 18.0, color: Theme.of(ctx).primaryColorDark,
    );
    TextStyle dialogContentStyle(BuildContext ctx) => GoogleFonts.poppins(fontSize: 14.0, color: Colors.grey.shade700, height: 1.4);
    ButtonStyle cancelButtonStyle(BuildContext ctx) => TextButton.styleFrom(
      foregroundColor: Colors.grey.shade600,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0), side: BorderSide(color: Colors.grey.shade300)),
    );
    ButtonStyle primaryActionButtonStyle(BuildContext ctx) => ElevatedButton.styleFrom(
      backgroundColor: Theme.of(ctx).primaryColor, foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)), elevation: 2,
    );

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            shape: dialogShape,
            title: Text('Konfirmasi Password', style: dialogTitleStyle(dialogContext)),
            actionsPadding: dialogActionsPadding,
            content: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text("Masukkan password Anda untuk melanjutkan:", style: dialogContentStyle(dialogContext)),
                const SizedBox(height: 15),
                TextFormField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.lock_outline), errorText: dialogErrorMessage,
                    suffixIcon: IconButton(
                      icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Password tidak boleh kosong' : null,
                ),
              ]),
            ),
            actions: [
              TextButton(
                onPressed: isDialogActionLoading ? null : () => Navigator.pop(dialogContext, false),
                style: cancelButtonStyle(dialogContext),
                child: Text('Batal', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
              ),
              ElevatedButton(
                onPressed: isDialogActionLoading ? null : () async {
                  if (formKey.currentState!.validate()) {
                    setDialogState(() { _isDialogActionLoading = true; dialogErrorMessage = null; });
                    notifyListeners(); // Update UI utama untuk loading
                    bool passwordMatch = await _verifyPassword(passwordController.text);
                    setDialogState(() => _isDialogActionLoading = false);
                    notifyListeners();
                    if (passwordMatch) {
                      if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                    } else {
                      setDialogState(() => dialogErrorMessage = 'Password salah.');
                    }
                  }
                },
                style: primaryActionButtonStyle(dialogContext),
                child: isDialogActionLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Konfirmasi', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ],
          );
        });
      },
    );
  }

  Future<bool> _verifyPassword(String enteredPassword) async {
    try {
      User? currentUser = await _dbHelper.getUserById(userId);
      if (currentUser == null) return false;
      return verifyPassword(enteredPassword, currentUser.passwordHash);
    } catch (e) {
      print("Error verifying password in provider: $e");
      return false;
    }
  }

  // --- Barcode Scanning Flow ---
  Future<FetchedProductData?> startBarcodeScanFlow(BuildContext context, ImageSource source) async {
    _isProcessingBarcode = true;
    notifyListeners();
    FetchedProductData? resultData;

    try {
      final XFile? pickedFile = await ImagePicker().pickImage(source: source);
      if (pickedFile == null) {
        _isProcessingBarcode = false;
        notifyListeners();
        return null;
      }
      final File imageFile = File(pickedFile.path);
      final barcodeValue = await _extractBarcodeFromImage(imageFile);

      if (barcodeValue == null) {
        // Gagal deteksi barcode, langsung return null, UI akan handle
        _isProcessingBarcode = false;
        notifyListeners();
        return FetchedProductData(code: null, name: null, imageFile: null); // Indikasi gagal scan
      }

      // Barcode terdeteksi, coba fetch
      final fetchedApiData = await _fetchProductDataFromApi(barcodeValue);
      File? downloadedImageFile;
      if (fetchedApiData != null && fetchedApiData['imageUrl'] != null) {
          downloadedImageFile = await _downloadImage(fetchedApiData['imageUrl'], barcodeValue);
      }

      resultData = FetchedProductData(
        name: fetchedApiData?['name'],
        code: barcodeValue, // Selalu isi kode dari hasil scan
        imageFile: downloadedImageFile, // Ini akan jadi temporary file
      );

    } catch (e) {
      _errorMessage = "Error saat scan: ${e.toString()}";
      resultData = FetchedProductData(code: null, name: null, imageFile: null); // Kembalikan data kosong jika error besar
    } finally {
      _isProcessingBarcode = false;
      notifyListeners();
    }
    return resultData;
  }

  Future<String?> _extractBarcodeFromImage(File imageFile) async {
     try {
      final InputImage inputImage = InputImage.fromFilePath(imageFile.path);
      final List<Barcode> barcodes = await _barcodeScanner.processImage(inputImage);
      if (barcodes.isNotEmpty) {
        Barcode? selectedBarcode;
        for (var barcode in barcodes) {
          if (barcode.format == BarcodeFormat.ean13 || barcode.format == BarcodeFormat.upca) {
            selectedBarcode = barcode; break;
          }
        }
        selectedBarcode ??= barcodes.firstWhere((b) => b.rawValue != null && b.rawValue!.isNotEmpty, orElse: () => barcodes.first);
        return selectedBarcode.rawValue;
      }
      return null;
    } catch (e) {
      print("Error extracting barcode: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchProductDataFromApi(String barcode) async {
    final url = Uri.parse('https://world.openfoodfacts.org/api/v3/product/$barcode.json');
    try {
      final response = await http.get(url, headers: {'User-Agent': 'ApliKasir/1.0'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['product'] != null) {
          final productData = data['product'];
          return {
            'name': productData['product_name_en'] ?? productData['product_name'], // Prioritaskan EN
            'imageUrl': productData['selected_images']?['front']?['display']?['en'],
          };
        }
      }
      return null;
    } catch (e) {
      print("Error fetching from OpenFoodFacts: $e");
      return null;
    }
  }
  
  Future<File?> _downloadImage(String imageUrl, String barcode) async {
    try {
      final response = await http.get(Uri.parse(imageUrl), headers: {'User-Agent': 'ApliKasir/1.0'});
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        // Buat nama file yang lebih unik untuk menghindari konflik jika barcode sama discan berulang kali
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filePath = p.join(tempDir.path, 'temp_dl_prod_img_${barcode}_$timestamp.png');
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        return file;
      }
      return null;
    } catch (e) {
      print("Error downloading image: $e");
      return null;
    }
  }
}