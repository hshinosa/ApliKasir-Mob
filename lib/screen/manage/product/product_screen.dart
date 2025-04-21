import 'dart:convert'; // <-- Import dart:convert
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http; // <-- Import http
import 'package:path/path.dart' as p; // <-- Import path
import 'package:path_provider/path_provider.dart'; // <-- Import path_provider

// --- Sesuaikan path impor model dan helper ---
import 'package:aplikasir_mobile/model/product_model.dart';
import 'package:aplikasir_mobile/helper/db_helper.dart';
import 'add_product_screen.dart';
import 'edit_product_screen.dart';

class ProductScreen extends StatefulWidget {
  final int userId;
  const ProductScreen({super.key, required this.userId});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

// Class penampung data hasil fetch API
class FetchedProductData {
  final String? name;
  final String? code;
  final File? imageFile;
  FetchedProductData({this.name, this.code, this.imageFile});
}

class _ProductScreenState extends State<ProductScreen> {
  final TextEditingController _searchController = TextEditingController();
  final NumberFormat currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final ImagePicker _imagePicker = ImagePicker();
  final BarcodeScanner _barcodeScanner = BarcodeScanner();

  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  bool _isProcessingBarcode = false; // State loading untuk scan/fetch
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchController.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterProducts);
    _searchController.dispose();
    _barcodeScanner.close();
    super.dispose();
  }

  // --- Fungsi Load Products ---
  Future<void> _loadProducts() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final products =
          await DatabaseHelper.instance.getProductsByUserId(widget.userId);
      if (!mounted) return; // Cek lagi setelah await
      setState(() {
        _allProducts = products;
        _filteredProducts = products;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading products: $e");
      if (!mounted) return; // Cek lagi setelah await
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat produk: ${e.toString()}';
      });
    }
  }

  // --- Fungsi Filter Products ---
  void _filterProducts() {
    final query = _searchController.text.toLowerCase().trim();
    if (!mounted) return;
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = _allProducts;
      } else {
        _filteredProducts = _allProducts.where((product) {
          final nameLower = product.namaProduk.toLowerCase();
          final codeLower = product.kodeProduk.toLowerCase();
          return nameLower.contains(query) || codeLower.contains(query);
        }).toList();
      }
    });
  }

  // --- Fungsi Navigasi ke Tambah Manual ---
  Future<void> _navigateToAddProductManual() async {
    // Pastikan context masih valid sebelum navigasi
    if (!mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddProductScreen(userId: widget.userId),
      ),
    );
    if (result == true && mounted) {
      _loadProducts();
    }
  }

  // --- Fungsi Navigasi ke Tambah dengan Data Fetch ---
  Future<void> _navigateToAddProductWithData(
      FetchedProductData fetchedData) async {
    // Pastikan context masih valid sebelum navigasi
    if (!mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddProductScreen(
          userId: widget.userId,
          initialName: fetchedData.name,
          initialCode: fetchedData.code,
          initialImageFile: fetchedData.imageFile,
        ),
      ),
    );
    if (result == true && mounted) {
      _loadProducts();
    }
  }

  // --- Fungsi Tampilkan Dialog Pilihan Tambah Produk (DENGAN STYLE BARU) ---
  Future<void> _showAddProductOptionsDialog() async {
    // Simpan BuildContext lokal sebelum async gap
    final BuildContext currentContext = context;
    return showDialog<void>(
      context: currentContext, // Gunakan context lokal
      barrierDismissible: true, // Bisa ditutup dengan tap di luar
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          // --- Terapkan Gaya AlertDialog dari Logout ---
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          elevation: 5.0,

          // --- Terapkan Gaya Judul dari Logout ---
          title: Text(
            'Tambah Produk', // Judul tetap
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 18.0,
              color: Colors.blue.shade800, // Warna judul biru
            ),
          ),

          // --- Konten Dialog (ListTile sedikit berbeda dari teks biasa) ---
          content: Column(
            mainAxisSize: MainAxisSize.min, // Tinggi secukupnya
            crossAxisAlignment: CrossAxisAlignment.start, // Teks rata kiri
            children: [
              // Teks deskripsi dengan gaya mirip logout content
              Text(
                'Pilih metode penambahan produk:',
                style: GoogleFonts.poppins(
                  fontSize: 14.0,
                  color: Colors.grey.shade700, // Warna teks abu
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 15), // Jarak

              // Opsi Input Manual
              ListTile(
                leading: Icon(Icons.edit_note,
                    color: Colors.blue.shade700, size: 30),
                title: Text(
                  'Input Manual',
                  // Style teks di dalam ListTile
                  style: GoogleFonts.poppins(
                      fontSize: 14.5, fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(dialogContext);
                  _navigateToAddProductManual();
                },
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 5.0), // Atur padding
                visualDensity: VisualDensity.compact, // Buat lebih rapat
              ),

              // Opsi Scan Barcode
              ListTile(
                leading: Icon(Icons.qr_code_scanner,
                    color: Colors.green.shade700, size: 30),
                title: Text(
                  'Scan Barcode',
                  // Style teks di dalam ListTile
                  style: GoogleFonts.poppins(
                      fontSize: 14.5, fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(dialogContext);
                  _startBarcodeScanFlow(currentContext); // Gunakan context awal
                },
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 5.0), // Atur padding
                visualDensity: VisualDensity.compact, // Buat lebih rapat
              ),
            ],
          ),

          // --- Tombol Aksi (Actions) ---
          // Terapkan Padding dari Logout
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          actions: <Widget>[
            // Tombol Batal (Gunakan Style dari Tombol Batal Logout)
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(
                // Terapkan Style
                foregroundColor: Colors.grey.shade600,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    side: BorderSide(color: Colors.grey.shade300) // Border abu
                    ),
              ),
              child: Text(
                // Terapkan Style Teks Tombol
                'Batal',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
            // Tidak ada tombol konfirmasi merah di dialog ini
          ],
        );
      },
    );
  }

  // --- Alur Scan Barcode (MODIFIKASI LOGIKA SAAT FETCH GAGAL/NULL) ---
  Future<void> _startBarcodeScanFlow(BuildContext currentContext) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: currentContext,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(
                'Kamera',
                style: GoogleFonts.poppins(fontSize: 16),
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(
                'Galeri',
                style: GoogleFonts.poppins(fontSize: 16),
              ),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final XFile? pickedFile = await _imagePicker.pickImage(source: source);
    if (pickedFile == null || !mounted) return;

    final File imageFile = File(pickedFile.path);

    if (!mounted) return;
    setState(() => _isProcessingBarcode = true);

    BuildContext? loadingDialogContext; // Untuk menyimpan context dialog
    if (Navigator.of(currentContext).canPop()) {
      final currentRoute = ModalRoute.of(currentContext);
      if (currentRoute is PopupRoute) {
        loadingDialogContext = currentContext;
      }
    }

    try {
      final barcodeValue = await _extractBarcodeFromImage(imageFile);

      // Tutup dialog loading barcode
      // (Gunakan try-finally atau pastikan pop di semua cabang)
      if (loadingDialogContext != null &&
          Navigator.of(loadingDialogContext).canPop()) {
        Navigator.pop(loadingDialogContext);
        loadingDialogContext = null; // Reset context dialog
      } else if (mounted && Navigator.of(currentContext).canPop()) {
        // Fallback? Hati-hati
        // Coba cari cara identifikasi dialog yg lebih baik jika perlu
      }

      if (!mounted) return;

      if (barcodeValue == null) {
        // GAGAL DETEKSI BARCODE -> Input Manual (Tetap)
        _showInfoSnackbar('Barcode tidak terdeteksi. Silakan input manual.');
        await Future.delayed(const Duration(milliseconds: 500));
        _navigateToAddProductManual();
        return; // Keluar dari fungsi
      }

      // Barcode terdeteksi, lanjutkan fetch data
      if (!mounted) return;
      if (Navigator.of(currentContext).canPop()) {
        // Simpan context dialog baru
        final currentRoute = ModalRoute.of(currentContext);
        if (currentRoute is PopupRoute) {
          loadingDialogContext = currentContext;
        }
      }

      FetchedProductData? fetchedData; // Deklarasi di luar try-catch fetch
      try {
        fetchedData = await _fetchProductData(barcodeValue);
      } catch (fetchError) {
        print("Error fetching product data: $fetchError");
        // Set fetchedData jadi null jika error fetch
        fetchedData = null;
      } finally {
        // Tutup dialog loading fetch (selalu tutup)
        if (loadingDialogContext != null &&
            Navigator.of(loadingDialogContext).canPop()) {
          Navigator.pop(loadingDialogContext);
          loadingDialogContext = null;
        } else if (mounted && Navigator.of(currentContext).canPop()) {
          // Fallback?
        }
      }

      if (!mounted) return; // Cek lagi

      // *** LOGIKA BARU: Cek hasil fetch ***
      if (fetchedData != null) {
        // *** SUKSES FETCH -> Navigasi dengan SEMUA data ***
        _navigateToAddProductWithData(fetchedData);
      } else {
        // *** GAGAL FETCH/DATA NULL -> Navigasi HANYA dengan KODE BARCODE ***
        _showInfoSnackbar(
            'Data produk tidak ditemukan di database online. Kode produk akan diisi otomatis.');
        await Future.delayed(const Duration(milliseconds: 500));
        // Buat objek FetchedProductData hanya dengan kode
        final barcodeOnlyData = FetchedProductData(code: barcodeValue);
        _navigateToAddProductWithData(barcodeOnlyData); // Kirim data ini
      }
    } catch (e) {
      // Catch error dari _extractBarcodeFromImage atau error tak terduga lain
      print("Error during barcode scan flow (outer catch): $e");
      // Tutup dialog loading jika masih ada
      if (loadingDialogContext != null &&
          Navigator.of(loadingDialogContext).canPop()) {
        Navigator.pop(loadingDialogContext);
      } else if (mounted && Navigator.of(currentContext).canPop()) {
        // Fallback?
      }

      if (mounted) {
        _showErrorSnackbar(
            'Terjadi kesalahan saat scan: ${e.toString().replaceFirst("Exception: ", "")}. Silakan input manual.');
        await Future.delayed(const Duration(milliseconds: 500));
        _navigateToAddProductManual(); // Arahkan ke manual jika error parah
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingBarcode = false);
      }
    }
  }

  // --- Fungsi Ekstrak Barcode dari Gambar (Diperbarui) ---
  Future<String?> _extractBarcodeFromImage(File imageFile) async {
    print("Attempting to scan barcode from: ${imageFile.path}");
    try {
      final InputImage inputImage = InputImage.fromFilePath(imageFile.path);

      // Proses gambar untuk mendeteksi barcode
      final List<Barcode> barcodes =
          await _barcodeScanner.processImage(inputImage);

      if (barcodes.isNotEmpty) {
        print("Detected ${barcodes.length} barcode(s).");

        // --- Logika Pemilihan Barcode ---
        // Prioritaskan EAN-13 atau UPC-A jika ada
        Barcode? selectedBarcode;
        for (var barcode in barcodes) {
          print(
              "  - Format: ${barcode.format.name}, Value: ${barcode.rawValue}, Type: ${barcode.type.name}");
          if (barcode.format == BarcodeFormat.ean13 ||
              barcode.format == BarcodeFormat.upca) {
            // Ambil EAN-13 atau UPC-A pertama yang ditemukan
            selectedBarcode = barcode;
            print("  -> Selected EAN-13/UPC-A: ${selectedBarcode.rawValue}");
            break; // Hentikan pencarian setelah EAN-13/UPC-A ditemukan
          }
        }

        // Jika tidak ada EAN-13/UPC-A, ambil barcode pertama yang terdeteksi
        selectedBarcode ??= barcodes.first;
        print("Final selected barcode value: ${selectedBarcode.rawValue}");

        // Pastikan nilai rawValue tidak null atau kosong sebelum dikembalikan
        if (selectedBarcode.rawValue != null &&
            selectedBarcode.rawValue!.isNotEmpty) {
          return selectedBarcode.rawValue;
        } else {
          print("Selected barcode has null or empty rawValue.");
          return null;
        }
      } else {
        print("No barcode detected in the image.");
        return null; // Tidak ada barcode terdeteksi
      }
    } catch (e) {
      print("Error scanning barcode: $e");
      // Pertimbangkan untuk tidak melempar ulang agar alur bisa lanjut ke manual
      // rethrow;
      // Kembalikan null agar bisa ditangani sebagai "tidak terdeteksi"
      return null;
    }
  }

  // --- Fungsi Fetch Data dari Open Food Facts ---
  Future<FetchedProductData?> _fetchProductData(String barcode) async {
    final url = Uri.parse(
        'https://world.openfoodfacts.org/api/v3/product/$barcode.json');
    print("Fetching data from: $url");

    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'ApliKasir/1.0 - Android'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['product'] != null) {
          final product = data['product'];

          // Filter response untuk mengambil data yang relevan
          final filteredResponse = {
            'code': data['code'],
            'name': product['product_name_en'],
            'selectedImages': {
              'front': product['selected_images']['front']['display']['en'],
            },
          };

          File? downloadedImageFile;
          final frontImageUrl = filteredResponse['selectedImages']['front'];
          if (frontImageUrl != null) {
            downloadedImageFile = await _downloadImage(frontImageUrl, barcode);
          }

          print(filteredResponse); // Log untuk debugging

          return FetchedProductData(
            name: filteredResponse['name'],
            code: filteredResponse['code'],
            imageFile: downloadedImageFile,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Produk tidak ditemukan!')),
          );
          return null;
        }
      } else {
        throw Exception('Failed to load product data');
      }
    } catch (error) {
      print('Error fetching product data: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengambil data produk!')),
      );
      return null;
    }
  }

  // --- Fungsi Download Gambar ---
  Future<File?> _downloadImage(String imageUrl, String barcode) async {
    try {
      final response = await http.get(Uri.parse(imageUrl),
          headers: {'User-Agent': 'ApliKasir/1.0 - Android'});
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final filePath = p.join(tempDir.path, 'temp_prod_img_$barcode.png');
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        print("Image downloaded to: $filePath");
        return file;
      } else {
        print("Failed to download image. Status: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Exception during image download: $e");
      return null;
    }
  }

  // --- Helper tampilkan Snackbar error ---
  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  // --- Helper Snackbar Info (BARU) ---
  void _showInfoSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(message),
            duration:
                const Duration(milliseconds: 2500)) // Durasi sedikit lebih lama
        );
  }

  // --- Fungsi Navigasi ke Edit Produk ---
  Future<void> _navigateToEditProduct(Product product) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProductScreen(initialProduct: product),
      ),
    );
    if (result == true && mounted) {
      _loadProducts();
    }
  }

  // --- Fungsi Hapus Produk ---
  Future<void> _deleteProduct(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content:
            Text('Anda yakin ingin menghapus produk "${product.namaProduk}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ya, Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Hapus gambar terkait
        if (product.gambarProduk != null && product.gambarProduk!.isNotEmpty) {
          final imageFile = File(product.gambarProduk!);
          // Gunakan try-catch untuk delete file juga
          try {
            if (await imageFile.exists()) {
              await imageFile.delete();
              print("Deleted image file: ${product.gambarProduk}");
            }
          } catch (e) {
            print("Error deleting product image file: $e");
            // Tidak perlu menghentikan proses hapus DB jika hapus file gagal
          }
        }

        // Hapus dari database
        final rowsAffected = await DatabaseHelper.instance
            .deleteProduct(product.id!, widget.userId);
        if (!mounted) return; // Cek mounted setelah await

        if (rowsAffected > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Produk "${product.namaProduk}" berhasil dihapus.'),
                backgroundColor: Colors.green),
          );
          _loadProducts(); // Muat ulang
        } else {
          _showErrorSnackbar('Gagal menghapus produk dari database.');
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackbar('Error saat menghapus: ${e.toString()}');
        }
      }
    }
  }

  // --- Helper: Build Product Card ---
  Widget _buildProductCard(Product product) {
    bool isStockZero = product.jumlahProduk == 0;
    ImageProvider? productImage;
    if (product.gambarProduk != null && product.gambarProduk!.isNotEmpty) {
      final imageFile = File(product.gambarProduk!);
      if (imageFile.existsSync()) {
        productImage = FileImage(imageFile);
      }
    }

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gambar
            ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Container(
                  width: 65,
                  height: 65,
                  color: Colors.grey[200],
                  child: productImage != null
                      ? Image(
                          image: productImage,
                          width: 65,
                          height: 65,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Icon(Icons.broken_image,
                              color: Colors.grey[400], size: 30))
                      : Icon(Icons.inventory_2_outlined,
                          color: Colors.grey[400], size: 30),
                )),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.namaProduk,
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Kode: ${product.kodeProduk}",
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stock Barang: ${product.jumlahProduk}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isStockZero
                          ? Colors.red.shade600
                          : Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildPriceColumn('Harga Modal', product.hargaModal),
                      const SizedBox(width: 20),
                      _buildPriceColumn('Harga Jual', product.hargaJual),
                    ],
                  ),
                ],
              ),
            ),
            // Tombol
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  height: 32,
                  child: ElevatedButton.icon(
                    onPressed: () => _deleteProduct(product),
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: Colors.white),
                    label: Text('Hapus',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade400,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 32,
                  child: ElevatedButton.icon(
                    onPressed: () => _navigateToEditProduct(product),
                    icon: const Icon(Icons.edit_outlined,
                        size: 16, color: Colors.white),
                    label: Text('Edit',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // --- Helper: Build Price Column ---
  Widget _buildPriceColumn(String label, double price) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          currencyFormatter.format(price),
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  // --- Build Method Utama ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: Text(
          'Produk',
          style: GoogleFonts.poppins(
            color: Colors.blue.shade800,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue.shade800,
        shadowColor: Colors.black26,
        surfaceTintColor: Colors.white,
        elevation: 0.5,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        automaticallyImplyLeading: true,
        iconTheme:
            IconThemeData(color: Colors.blue.shade700), // Warna ikon back
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
        child: Column(
          children: [
            const SizedBox(
              height: 20,
            ),
            // Search Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              decoration: BoxDecoration(
                color: Colors.blue.shade50.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Cari nama atau kode produk',
                        hintStyle: GoogleFonts.poppins(
                            color: Colors.grey.shade600, fontSize: 14),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      style: GoogleFonts.poppins(
                          fontSize: 14, color: Colors.black87),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.filter_list, color: Colors.grey.shade700),
                    tooltip: 'Filter / Urutkan',
                    onPressed: () {
                      print('Tombol Filter ditekan');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Daftar Produk
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage.isNotEmpty
                      ? Center(
                          child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(_errorMessage,
                                  style: GoogleFonts.poppins(color: Colors.red),
                                  textAlign: TextAlign.center)))
                      : _allProducts
                              .isEmpty // Cek _allProducts untuk pesan awal
                          ? Center(
                              child: Text(
                                'Data barang tidak ada.\nTekan tombol + untuk menambah.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                    color: Colors.grey.shade500),
                              ),
                            )
                          : _filteredProducts
                                  .isEmpty // Cek _filteredProducts untuk hasil cari
                              ? Center(
                                  child: Text(
                                    'Produk tidak ditemukan.',
                                    style: GoogleFonts.poppins(
                                        color: Colors.grey.shade500),
                                  ),
                                )
                              : RefreshIndicator(
                                  onRefresh: _loadProducts,
                                  child: ListView.builder(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(), // Selalu bisa scroll untuk refresh
                                    itemCount: _filteredProducts.length,
                                    itemBuilder: (context, index) {
                                      return _buildProductCard(
                                          _filteredProducts[index]);
                                    },
                                  ),
                                ),
            ),
          ],
        ),
      ),
      floatingActionButton: SizedBox(
        width: 60,
        height: 60,
        child: FittedBox(
          child: FloatingActionButton(
            onPressed:
                _isProcessingBarcode ? null : _showAddProductOptionsDialog,
            backgroundColor:
                _isProcessingBarcode ? Colors.grey : Colors.blue.shade600,
            elevation: 3.0,
            tooltip: 'Tambah Produk',
            child: _isProcessingBarcode
                ? const CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 3)
                : const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 26,
                  ),
            shape: const CircleBorder(),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
} // End of _ProductScreenState
