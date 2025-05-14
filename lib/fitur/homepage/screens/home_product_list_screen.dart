// lib/fitur/homepage/screens/home_product_list_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../model/product_model.dart';
import '../providers/homepage_provider.dart'; // Import provider

class HomeProductListScreen extends StatefulWidget {
  // Tidak perlu userId, akan diambil dari provider
  const HomeProductListScreen({Key? key}) : super(key: key);

  @override
  State<HomeProductListScreen> createState() => _HomeProductListScreenState();
}

class _HomeProductListScreenState extends State<HomeProductListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final NumberFormat currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    // Listener untuk search controller akan memanggil provider
    _searchController.addListener(() {
      context.read<HomepageProvider>().filterHomeProducts(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showErrorSnackbarInView(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildQuantityControl({
    required int? productId,
    required int currentQuantity,
    required int maxStock,
    required HomepageProvider provider,
  }) {
    if (productId == null) return const SizedBox(height: 32);

    if (currentQuantity <= 0) {
      return SizedBox(
        height: 32,
        child: OutlinedButton.icon(
          onPressed: maxStock <= 0
              ? null
              : () => provider.updateCheckoutQuantity(productId, 1, showError: _showErrorSnackbarInView),
          icon: Icon(Icons.add, size: 18, color: maxStock <= 0 ? Colors.grey : Colors.blue.shade700),
          label: Text('Tambah', style: GoogleFonts.poppins(fontSize: 12, color: maxStock <= 0 ? Colors.grey : Colors.blue.shade700)),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.blue.shade700,
            side: BorderSide(color: maxStock <= 0 ? Colors.grey.shade300 : Colors.blue.shade600),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      );
    } else {
      return Container(
        height: 32,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => provider.updateCheckoutQuantity(productId, currentQuantity - 1, showError: _showErrorSnackbarInView),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                child: Icon(Icons.remove, size: 18, color: Colors.red.shade700),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              constraints: const BoxConstraints(minWidth: 24),
              child: Text(
                currentQuantity.toString(),
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            InkWell(
              onTap: currentQuantity >= maxStock
                  ? null
                  : () => provider.updateCheckoutQuantity(productId, currentQuantity + 1, showError: _showErrorSnackbarInView),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                child: Icon(
                  Icons.add,
                  size: 18,
                  color: currentQuantity >= maxStock ? Colors.grey : Colors.green.shade700,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildHomeProductCard(Product product, HomepageProvider provider) {
    final int currentQuantity = product.id != null ? (provider.checkoutCart[product.id!] ?? 0) : 0;
    final bool isSelected = currentQuantity > 0;

    ImageProvider? productImage;
    if (product.gambarProduk != null && product.gambarProduk!.isNotEmpty) {
      try {
        final imageFile = File(product.gambarProduk!);
        if (imageFile.existsSync()) {
          productImage = FileImage(imageFile);
        }
      } catch (e) {
        productImage = null;
      }
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      elevation: isSelected ? 3.0 : 1.5,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(
            color: isSelected ? Colors.blue.shade300 : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1.0,
          )),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Container(
                width: 65,
                height: 65,
                color: Colors.grey.shade200,
                child: productImage != null
                    ? Image(
                        key: ValueKey(product.id.toString() + (product.gambarProduk ?? '')), // Correct key usage
                        image: productImage,
                        width: 65,
                        height: 65,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Icon(Icons.broken_image, color: Colors.grey[400], size: 30))
                    : Icon(Icons.inventory_2_outlined, color: Colors.grey[400], size: 35),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  product.namaProduk,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15.0),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text('Kode: ${product.kodeProduk}', style: GoogleFonts.poppins(fontSize: 11.0, color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                Text(currencyFormatter.format(product.hargaJual), style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14.0, color: Colors.green.shade700)),
              ],
            )),
            Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Stok: ${product.jumlahProduk}',
                      style: GoogleFonts.poppins(
                          fontSize: 11.0,
                          color: product.jumlahProduk <= 0
                              ? Colors.red.shade700
                              : (product.jumlahProduk <= 5 ? Colors.orange.shade800 : Colors.black54),
                          fontWeight: product.jumlahProduk <= 5 ? FontWeight.w600 : FontWeight.normal)),
                  const SizedBox(height: 8),
                  _buildQuantityControl(
                    productId: product.id,
                    currentQuantity: currentQuantity,
                    maxStock: product.jumlahProduk,
                    provider: provider, // Pass provider
                  ),
                ]),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    // Dapatkan provider
    final homepageProvider = context.watch<HomepageProvider>();

    return Column(
      children: [
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 10.0),
          child: Row(children: [
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10.0),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 1))
                    ]),
                child: TextField(
                  controller: _searchController, // Digunakan untuk trigger filter di provider
                  decoration: InputDecoration(
                    hintText: 'Cari produk (nama/kode)',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: MediaQuery.of(context).size.width * 0.035),
                    prefixIcon: Icon(Icons.search, color: Colors.grey.shade600, size: MediaQuery.of(context).size.width * 0.06),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey.shade500, size: MediaQuery.of(context).size.width * 0.06),
                            onPressed: () {
                              _searchController.clear(); // Listener akan terpicu
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 5),
                    isDense: true,
                  ),
                  style: GoogleFonts.poppins(fontSize: MediaQuery.of(context).size.width * 0.015 + 8, color: Colors.black87), //Adjusted
                ),
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: () => homepageProvider.toggleSortOrder(),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: MediaQuery.of(context).size.width * 0.12,
                width: MediaQuery.of(context).size.width * 0.12,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10.0),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 1))
                    ]),
                child: Tooltip(
                  message: homepageProvider.sortAscending ? 'Urutkan Z-A' : 'Urutkan A-Z',
                  child: Icon(
                    Icons.sort_by_alpha, // Icon tetap, bisa ditambah visual sort direction jika mau
                    color: Colors.blue.shade700,
                    size: 24,
                  ),
                ),
              ),
            ),
          ]),
        ),
        Expanded(
          child: homepageProvider.homeIsLoading
              ? const Center(child: CircularProgressIndicator())
              : homepageProvider.homeErrorMessage.isNotEmpty
                  ? Center(
                      child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 40),
                              const SizedBox(height: 10),
                              Text(homepageProvider.homeErrorMessage,
                                  style: GoogleFonts.poppins(color: Colors.red.shade700, fontSize: 15),
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 15),
                              ElevatedButton.icon(
                                  onPressed: () => homepageProvider.loadHomeProducts(),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text("Coba Lagi")),
                            ],
                          )))
                  : homepageProvider.homeAllProducts.isEmpty // Cek _allProducts dari provider
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.storefront_outlined, color: Colors.grey, size: 50),
                              const SizedBox(height: 10),
                              Text('Belum ada produk ditambahkan.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: MediaQuery.of(context).size.width * 0.045)),
                              Text('Tambahkan melalui menu Kelola.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: MediaQuery.of(context).size.width * 0.035)),
                              const SizedBox(height: 15),
                              ElevatedButton.icon(
                                  onPressed: () => homepageProvider.loadHomeProducts(),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text("Muat Ulang"))
                            ],
                          ),
                        )
                      : homepageProvider.homeFilteredProducts.isEmpty
                          ? Center(
                              child: Text(
                              'Produk "${_searchController.text}" tidak ditemukan.',
                              style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 15),
                              textAlign: TextAlign.center,
                            ))
                          : RefreshIndicator(
                              onRefresh: () => homepageProvider.loadHomeProducts(),
                              child: ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.only(bottom: 90, top: 5), // bottom: FAB space
                                itemCount: homepageProvider.homeFilteredProducts.length,
                                itemBuilder: (context, index) {
                                  return _buildHomeProductCard(homepageProvider.homeFilteredProducts[index], homepageProvider);
                                },
                              ),
                            ),
        ),
      ],
    );
  }
}


