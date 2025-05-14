// lib/fitur/manage/credit/providers/customer_debt_history_provider.dart
import 'package:flutter/material.dart';
import 'package:aplikasir_mobile/model/transaction_model.dart';
import 'package:aplikasir_mobile/helper/db_helper.dart';
import 'package:aplikasir_mobile/model/customer_model.dart'; // Impor Customer

class CustomerDebtHistoryProvider extends ChangeNotifier {
  final Customer customer;
  final int userId;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<TransactionModel> _transactions = [];
  bool _isLoading = true;
  String _errorMessage = '';

  // Getters
  List<TransactionModel> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  double get totalOutstandingDebt => _transactions
      .where((t) => t.statusPembayaran == 'Belum Lunas')
      .fold(0.0, (sum, t) => sum + t.totalBelanja);

  CustomerDebtHistoryProvider({required this.customer, required this.userId}) {
    loadCustomerTransactions();
  }

  Future<void> loadCustomerTransactions() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _transactions = await _dbHelper.getTransactionsByCustomerId(customer.id!, userId);
      // Urutkan berdasarkan tanggal terbaru
      _transactions.sort((a,b) => b.tanggalTransaksi.compareTo(a.tanggalTransaksi));
    } catch (e) {
      _errorMessage = 'Gagal memuat riwayat hutang: ${e.toString()}';
      _transactions = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}