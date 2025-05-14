// lib/fitur/homepage/providers/homepage_provider.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io'; // Untuk File

import '../../../model/product_model.dart';
import '../../../helper/db_helper.dart';

class HomepageProvider extends ChangeNotifier {
  final int userId;

  List<Product> _homeAllProducts = [];
  List<Product> _homeFilteredProducts = [];
  bool _homeIsLoading = true;
  String _homeErrorMessage = '';
  bool _sortAscending = true; // Default A-Z
  final Map<int, int> _checkoutCart = {};

  // Getter untuk UI
  List<Product> get homeAllProducts => _homeAllProducts;
  List<Product> get homeFilteredProducts => _homeFilteredProducts;
  bool get homeIsLoading => _homeIsLoading;
  String get homeErrorMessage => _homeErrorMessage;
  bool get sortAscending => _sortAscending;
  Map<int, int> get checkoutCart => _checkoutCart;

  int get totalCartItems => _checkoutCart.values.fold(0, (sum, item) => sum + item);

  List<Product> get productsInCart {
    List<Product> products = [];
    _checkoutCart.forEach((productId, quantity) {
      try {
        final product = _homeAllProducts.firstWhere((p) => p.id == productId);
        products.add(product);
      } catch (e) {
        // Produk mungkin sudah dihapus, abaikan dari keranjang saat ini
        print("Product ID $productId not found in all products for cart display.");
      }
    });
    return products;
  }

  HomepageProvider({required this.userId}) {
    loadHomeProducts();
  }

  Future<void> loadHomeProducts() async {
    _homeIsLoading = true;
    _homeErrorMessage = '';
    notifyListeners();

    try {
      final products = await DatabaseHelper.instance.getProductsByUserId(userId);
      _homeAllProducts = products;
      _filterAndSortHomeProducts(); // Panggil filter dan sort setelah memuat
    } catch (e) {
      _homeErrorMessage = 'Gagal memuat produk: ${e.toString()}';
      _homeAllProducts = [];
      _homeFilteredProducts = [];
    } finally {
      _homeIsLoading = false;
      notifyListeners();
    }
  }

  void filterHomeProducts(String query) {
    _filterAndSortHomeProducts(searchQuery: query);
  }

  void toggleSortOrder() {
    _sortAscending = !_sortAscending;
    _filterAndSortHomeProducts(); // Terapkan filter & sort
  }

  void _filterAndSortHomeProducts({String? searchQuery}) {
    List<Product> productsToProcess = List.from(_homeAllProducts);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final queryLower = searchQuery.toLowerCase().trim();
      productsToProcess = productsToProcess.where((product) {
        final nameLower = product.namaProduk.toLowerCase();
        final codeLower = product.kodeProduk.toLowerCase();
        return nameLower.contains(queryLower) || codeLower.contains(queryLower);
      }).toList();
    }

    // Sorting
    productsToProcess.sort((a, b) {
      int comparison = a.namaProduk.toLowerCase().compareTo(b.namaProduk.toLowerCase());
      return _sortAscending ? comparison : -comparison;
    });

    _homeFilteredProducts = productsToProcess;
    notifyListeners();
  }


  void updateCheckoutQuantity(int productId, int newQuantity, {required Function(String) showError}) {
    final product = _homeAllProducts.firstWhere((p) => p.id == productId,
        orElse: () => Product(
            idPengguna: -1,
            namaProduk: 'N/A',
            kodeProduk: '',
            jumlahProduk: -1,
            hargaModal: 0,
            hargaJual: 0));

    if (product.idPengguna == -1) { // Product not found
      showError('Produk tidak ditemukan.');
      return;
    }

    if (newQuantity > product.jumlahProduk) {
      showError('Stok ${product.namaProduk} tidak mencukupi (tersisa ${product.jumlahProduk}).');
      // Kembalikan kuantitas ke stok maksimum jika input melebihi
      // atau biarkan UI tidak mengupdate quantity jika validasi di UI mencegah ini
      return;
    }

    if (newQuantity > 0) {
      _checkoutCart[productId] = newQuantity;
    } else {
      _checkoutCart.remove(productId);
    }
    notifyListeners();
  }

  void clearCheckoutCart() {
    _checkoutCart.clear();
    notifyListeners();
  }
}