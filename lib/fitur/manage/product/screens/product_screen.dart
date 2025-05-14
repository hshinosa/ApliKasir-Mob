// lib/fitur/manage/product/screens/product_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart'; // Hanya untuk ImageSource
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:aplikasir_mobile/model/product_model.dart';
import '../providers/product_provider.dart'; // Impor Provider
import 'add_product_screen.dart';
import 'edit_product_screen.dart';

class ProductScreen extends StatelessWidget { // Ubah jadi StatelessWidget
  final int userId;
  const ProductScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProductProvider(userId: userId),
      child: const _ProductScreenContent(),
    );
  }
}

class _ProductScreenContent extends StatefulWidget {
  const _ProductScreenContent();

  @override
  State<_ProductScreenContent> createState() => _ProductScreenContentState();
}

class _ProductScreenContentState extends State<_ProductScreenContent> {
  final TextEditingController _searchController = TextEditingController();
  final NumberFormat currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  // State _allProducts, _filteredProducts, _isLoading, _errorMessage, _isProcessingBarcode PINDAH KE PROVIDER

  @override
  void initState() {
    super.initState();
    // Listener untuk search controller
    _searchController.addListener(() {
      context.read<ProductProvider>().setSearchQuery(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Fungsi Load dan Filter PINDAH KE PROVIDER

  // --- Fungsi Navigasi ke Tambah Manual (DARI UI) ---
  Future<void> _navigateToAddProductManual() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        // Provider sudah di-create di atas, jadi AddProductScreen bisa akses via context.read
        // Tidak perlu pass ProductProvider secara eksplisit jika AddProductScreen juga provider-aware
        builder: (context) => AddProductScreen(userId: context.read<ProductProvider>().userId),
      ),
    );
    if (result == true && mounted) {
      context.read<ProductProvider>().loadProducts();
    }
  }

  // --- Fungsi Navigasi ke Tambah dengan Data Fetch (DARI UI) ---
  Future<void> _navigateToAddProductWithData(FetchedProductData fetchedData) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddProductScreen(
          userId: context.read<ProductProvider>().userId,
          initialName: fetchedData.name,
          initialCode: fetchedData.code,
          initialImageFile: fetchedData.imageFile, // Ini adalah temporary file
        ),
      ),
    );
    if (result == true && mounted) {
      context.read<ProductProvider>().loadProducts();
    }
  }

  // --- Fungsi Tampilkan Dialog Pilihan Tambah Produk (MEMANGGIL PROVIDER) ---
  Future<void> _showAddProductOptionsDialog(BuildContext scaffContext, ProductProvider provider) async {
     final BuildContext currentContext = scaffContext; // Simpan context sebelum async
    return showDialog<void>(
      context: currentContext,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          elevation: 5.0,
          title: Text('Tambah Produk', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18.0, color: Colors.blue.shade800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pilih metode penambahan produk:', style: GoogleFonts.poppins(fontSize: 14.0, color: Colors.grey.shade700, height: 1.4)),
              const SizedBox(height: 15),
              ListTile(
                leading: Icon(Icons.edit_note, color: Colors.blue.shade700, size: 30),
                title: Text('Input Manual', style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(dialogContext);
                  _navigateToAddProductManual(); // Panggil dari state
                },
                contentPadding: const EdgeInsets.symmetric(vertical: 5.0),
                visualDensity: VisualDensity.compact,
              ),
              ListTile(
                leading: Icon(Icons.qr_code_scanner, color: Colors.green.shade700, size: 30),
                title: Text('Scan Barcode', style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(dialogContext);
                  _startBarcodeScanFlowWithOptions(currentContext, provider); // Panggil dari state dengan provider
                },
                contentPadding: const EdgeInsets.symmetric(vertical: 5.0),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade600,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0), side: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Text('Batal', style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14)),
            ),
          ],
        );
      },
    );
  }

  // --- Alur Scan Barcode (DARI UI, MEMANGGIL PROVIDER) ---
  Future<void> _startBarcodeScanFlowWithOptions(BuildContext currentContext, ProductProvider provider) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: currentContext,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.camera_alt), title: Text('Kamera', style: GoogleFonts.poppins(fontSize: 16)), onTap: () => Navigator.pop(context, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library), title: Text('Galeri', style: GoogleFonts.poppins(fontSize: 16)), onTap: () => Navigator.pop(context, ImageSource.gallery)),
        ]),
      ),
    );
    if (source == null || !mounted) return;

    // Tampilkan dialog loading di UI saat provider scan
    // Provider akan set _isProcessingBarcode = true
    // Ini bisa dilakukan di dalam method provider atau di sini observe state provider

    final FetchedProductData? fetchedData = await provider.startBarcodeScanFlow(currentContext, source);

    if (!mounted) return;

    if (fetchedData != null) {
        if (fetchedData.code == null && fetchedData.name == null && fetchedData.imageFile == null) {
            // Indikasi gagal scan dari provider
            _showInfoSnackbar('Barcode tidak terdeteksi. Silakan input manual.');
             await Future.delayed(const Duration(milliseconds: 500));
            _navigateToAddProductManual();
        } else {
             // Jika ada data (walaupun mungkin hanya kode), navigasi
            _navigateToAddProductWithData(fetchedData);
        }
    } else {
        // Jika error besar terjadi di provider dan return null (seharusnya tidak terjadi jika FetchedProductData(null,null,null) dikembalikan)
        _showErrorSnackbar('Terjadi kesalahan saat scan. Silakan input manual.');
        await Future.delayed(const Duration(milliseconds: 500));
        _navigateToAddProductManual();
    }
  }

  // Fungsi Ekstrak Barcode dan Fetch Data PINDAH KE PROVIDER

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
  }

  void _showInfoSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(milliseconds: 2500)));
  }
  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green));
  }


  // --- Fungsi Navigasi ke Edit Produk (DARI UI) ---
  Future<void> _navigateToEditProduct(Product product, ProductProvider provider) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProductScreen(initialProduct: product),
      ),
    );
    if (result == true && mounted) {
      provider.loadProducts();
    }
  }

  // --- Fungsi Hapus Produk (MEMANGGIL PROVIDER) ---
  Future<void> _deleteProduct(Product product, ProductProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: Text('Anda yakin ingin menghapus produk "${product.namaProduk}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ya, Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      final success = await provider.deleteProduct(context, product); // Provider handle password
      if (success && mounted) {
        _showSuccessSnackbar('Produk "${product.namaProduk}" berhasil dihapus.');
        // loadProducts sudah dipanggil di dalam provider.deleteProduct jika sukses
      } else if (!success && provider.errorMessage.isNotEmpty && mounted) {
         _showErrorSnackbar(provider.errorMessage);
      } else if (!success && mounted) {
        // Pesan error umum jika tidak ada dari provider (misal pembatalan password)
        // _showErrorSnackbar('Gagal menghapus produk.'); // Atau tidak tampilkan apa2 jika batal
      }
    }
  }

  // --- Helper: Build Product Card (Menggunakan data dari Provider) ---
  Widget _buildProductCard(Product product, ProductProvider provider) {
    // ... (Logika _buildProductCard sama seperti sebelumnya, tapi panggil provider.deleteProduct, dll.) ...
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
            ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Container(
                  width: 65,
                  height: 65,
                  color: Colors.grey[200],
                  child: productImage != null
                      ? Image(image: productImage, width: 65, height: 65, fit: BoxFit.cover, errorBuilder: (c, e, s) => Icon(Icons.broken_image, color: Colors.grey[400], size: 30))
                      : Icon(Icons.inventory_2_outlined, color: Colors.grey[400], size: 30),
                )),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.namaProduk, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text("Kode: ${product.kodeProduk}", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
                  const SizedBox(height: 4),
                  Text('Stok: ${product.jumlahProduk}', style: GoogleFonts.poppins(fontSize: 12, color: isStockZero ? Colors.red.shade600 : Colors.blue.shade700, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 10),
                  Row(children: [
                    _buildPriceColumn('Harga Modal', product.hargaModal),
                    const SizedBox(width: 20),
                    _buildPriceColumn('Harga Jual', product.hargaJual),
                  ]),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  height: 32,
                  child: ElevatedButton.icon(
                    onPressed: () => _deleteProduct(product, provider), // Panggil dengan provider
                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.white),
                    label: Text('Hapus', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 12)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 32,
                  child: ElevatedButton.icon(
                    onPressed: () => _navigateToEditProduct(product, provider), // Panggil dengan provider
                    icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.white),
                    label: Text('Edit', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 12)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPriceColumn(String label, double price) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
      const SizedBox(height: 2),
      Text(currencyFormatter.format(price), style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>(); // Dapatkan provider

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: Text('Kelola Produk', style: GoogleFonts.poppins(color: Colors.blue.shade800, fontWeight: FontWeight.bold, fontSize: 22)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue.shade800,
        shadowColor: Colors.black26,
        surfaceTintColor: Colors.white,
        elevation: 0.5,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        automaticallyImplyLeading: true,
        iconTheme: IconThemeData(color: Colors.blue.shade700),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              decoration: BoxDecoration(color: Colors.blue.shade50.withOpacity(0.7), borderRadius: BorderRadius.circular(12.0)),
              child: Row(children: [
                Icon(Icons.search, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(hintText: 'Cari nama atau kode produk', hintStyle: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 14)),
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                  ),
                ),
                IconButton(
                  icon: Icon(productProvider.sortAscending ? Icons.sort_by_alpha : Icons.sort_by_alpha, color: Colors.blue.shade700), // Bisa diubah jika ada icon Z-A
                  tooltip: productProvider.sortAscending ? 'Urutkan Z-A' : 'Urutkan A-Z',
                  onPressed: () => productProvider.toggleSortOrder(),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: productProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : productProvider.errorMessage.isNotEmpty
                      ? Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(productProvider.errorMessage, style: GoogleFonts.poppins(color: Colors.red), textAlign: TextAlign.center)))
                      : productProvider.filteredProducts.isEmpty && productProvider.searchQuery.isEmpty // Cek apakah semua produk kosong (sebelum filter)
                            ? Center(child: Text('Data barang tidak ada.\nTekan tombol + untuk menambah.', textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.grey.shade500)))
                            : productProvider.filteredProducts.isEmpty // Cek hasil filter
                                ? Center(child: Text('Produk tidak ditemukan.', style: GoogleFonts.poppins(color: Colors.grey.shade500)))
                                : RefreshIndicator(
                                    onRefresh: () => productProvider.loadProducts(),
                                    child: ListView.builder(
                                      physics: const AlwaysScrollableScrollPhysics(),
                                      itemCount: productProvider.filteredProducts.length,
                                      itemBuilder: (context, index) {
                                        return _buildProductCard(productProvider.filteredProducts[index], productProvider);
                                      },
                                    ),
                                  ),
            ),
          ],
        ),
      ),
      floatingActionButton: SizedBox(
        width: 60, height: 60,
        child: FittedBox(
          child: FloatingActionButton(
            onPressed: productProvider.isProcessingBarcode ? null : () => _showAddProductOptionsDialog(context, productProvider), // Panggil dengan provider
            backgroundColor: productProvider.isProcessingBarcode ? Colors.grey : Colors.blue.shade600,
            elevation: 3.0,
            tooltip: 'Tambah Produk',
            child: productProvider.isProcessingBarcode
                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                : const Icon(Icons.add, color: Colors.white, size: 26),
            shape: const CircleBorder(),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}