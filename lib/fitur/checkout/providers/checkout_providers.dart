// lib/features/checkout/providers/checkout_provider.dart
import 'package:flutter/material.dart';
import 'package:aplikasir_mobile/model/product_model.dart';
import 'package:aplikasir_mobile/model/customer_model.dart';
import 'package:aplikasir_mobile/model/transaction_model.dart';
import 'package:aplikasir_mobile/helper/db_helper.dart'; // Sesuaikan path jika perlu

class CheckoutProvider extends ChangeNotifier {
  final int userId;
  final Map<int, int> initialCartQuantities;
  final List<Product> initialCartProducts;

  // Database Helper
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // State Internal Provider
  double _totalBelanja = 0;
  double _totalModal = 0;
  String _selectedPaymentMethod = 'Tunai';
  Customer? _selectedCustomer;
  List<Customer> _availableCustomers = [];
  bool _isLoadingCustomers = false;
  bool _isProcessingCheckout = false; // Untuk loading tombol utama
  String? _errorMessage;
  String? _successMessage;

  // Getters untuk UI
  double get totalBelanja => _totalBelanja;
  String get selectedPaymentMethod => _selectedPaymentMethod;
  Customer? get selectedCustomer => _selectedCustomer;
  List<Customer> get availableCustomers => _availableCustomers;
  bool get isLoadingCustomers => _isLoadingCustomers;
  bool get isProcessingCheckout => _isProcessingCheckout;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  CheckoutProvider({
    required this.userId,
    required this.initialCartQuantities,
    required this.initialCartProducts,
  }) {
    _calculateTotals();
  }

  void _calculateTotals() {
    double tempTotalBelanja = 0;
    double tempTotalModal = 0;
    initialCartProducts.forEach((product) {
      final quantity = initialCartQuantities[product.id] ?? 0;
      if (quantity > 0) {
        tempTotalBelanja += product.hargaJual * quantity;
        tempTotalModal += product.hargaModal * quantity;
      }
    });
    _totalBelanja = tempTotalBelanja;
    _totalModal = tempTotalModal;
    notifyListeners(); // Meskipun di constructor, bisa saja dipanggil lagi nanti
  }

  void selectPaymentMethod(String method) {
    if (_selectedPaymentMethod != method) {
      _selectedPaymentMethod = method;
      if (method != 'Kredit') {
        _selectedCustomer = null; // Reset customer jika bukan kredit
      }
      _clearMessages();
      notifyListeners();
    }
  }

  void selectCustomer(Customer? customer) {
    _selectedCustomer = customer;
    _clearMessages();
    notifyListeners();
  }

  Future<void> loadCustomers() async {
    if (_isLoadingCustomers) return;
    _isLoadingCustomers = true;
    _clearMessages();
    notifyListeners();
    try {
      _availableCustomers = await _dbHelper.getCustomersByUserId(userId);
    } catch (e) {
      _errorMessage = "Gagal memuat pelanggan: $e";
    } finally {
      _isLoadingCustomers = false;
      notifyListeners();
    }
  }

  Future<Customer?> addCustomer(String name, String? phone) async {
    _isLoadingCustomers = true; // Bisa juga pakai flag loading lain
    _clearMessages();
    notifyListeners();
    try {
      final newCustomer = Customer(
        idPengguna: userId,
        namaPelanggan: name.trim(),
        nomorTelepon: phone?.trim().isEmpty ?? true ? null : phone!.trim(),
        createdAt: DateTime.now(), // Tambahkan createdAt
      );
      final generatedId = await _dbHelper.insertCustomer(newCustomer);
      final savedCustomer = Customer(
        id: generatedId,
        idPengguna: newCustomer.idPengguna,
        namaPelanggan: newCustomer.namaPelanggan,
        nomorTelepon: newCustomer.nomorTelepon,
        createdAt: newCustomer.createdAt,
      );
      await loadCustomers(); // Reload list
      _successMessage = "Pelanggan '${savedCustomer.namaPelanggan}' ditambahkan.";
      notifyListeners();
      return savedCustomer;
    } catch (e) {
      _errorMessage = "Gagal menambah pelanggan: $e";
      notifyListeners();
      return null;
    } finally {
       _isLoadingCustomers = false;
       notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> processKreditTransaction() async {
    if (_selectedCustomer == null) {
      _errorMessage = "Pilih pelanggan untuk pembayaran kredit.";
      notifyListeners();
      return null;
    }

    _isProcessingCheckout = true;
    _clearMessages();
    notifyListeners();

    try {
      List<Map<String, dynamic>> detailItems = [];
      initialCartProducts.forEach((product) {
        final quantity = initialCartQuantities[product.id] ?? 0;
        if (quantity > 0) {
          detailItems.add({
            'product_id': product.id,
            'nama_produk': product.namaProduk,
            'kode_produk': product.kodeProduk,
            'harga_jual': product.hargaJual,
            'harga_modal': product.hargaModal,
            'quantity': quantity,
            'subtotal': product.hargaJual * quantity,
          });
        }
      });

      final transaction = TransactionModel(
        idPengguna: userId,
        tanggalTransaksi: DateTime.now(),
        totalBelanja: _totalBelanja,
        totalModal: _totalModal,
        metodePembayaran: 'Kredit',
        statusPembayaran: 'Belum Lunas',
        idPelanggan: _selectedCustomer!.id,
        detailItems: detailItems,
      );

      final transactionId = await _dbHelper.insertTransaction(transaction);

      // Update Stok
      for (var item in detailItems) {
        await _dbHelper.updateProductStock(item['product_id'], item['quantity']);
      }

      _successMessage = "Transaksi kredit berhasil disimpan.";
      return {'transactionId': transactionId, 'paymentMethod': 'Kredit'};

    } catch (e) {
      _errorMessage = "Gagal memproses transaksi kredit: $e";
      return null;
    } finally {
      _isProcessingCheckout = false;
      notifyListeners();
    }
  }

  // Untuk navigasi ke Tunai & QRIS, kita akan siapkan data yang dibutuhkan layar tsb
  Map<String, dynamic> prepareDataForCashPayment() {
    _isProcessingCheckout = true; // Set loading saat mau navigasi
    notifyListeners();
    return {
      'totalAmount': _totalBelanja,
      'userId': userId,
      'cartQuantities': initialCartQuantities,
      'cartProducts': initialCartProducts,
    };
  }

   Map<String, dynamic> prepareDataForQrisPayment() {
    _isProcessingCheckout = true;
    notifyListeners();
     return {
      'totalAmount': _totalBelanja,
      'userId': userId,
      'cartQuantities': initialCartQuantities,
      'cartProducts': initialCartProducts,
    };
  }

  void resetProcessingCheckout() {
    _isProcessingCheckout = false;
    notifyListeners();
  }

  void _clearMessages() {
    _errorMessage = null;
    _successMessage = null;
  }

  // Panggil ini jika checkout sukses & mau reset keranjang di provider (opsional, tergantung flow)
  void clearCartAndReset() {
    initialCartQuantities.clear();
    initialCartProducts.clear();
    _totalBelanja = 0;
    _totalModal = 0;
    _selectedCustomer = null;
    _selectedPaymentMethod = 'Tunai';
    notifyListeners();
  }
}