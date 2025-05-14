// lib/features/history/providers/history_provider.dart
import 'package:flutter/material.dart';
import 'package:aplikasir_mobile/model/transaction_model.dart';
import 'package:aplikasir_mobile/helper/db_helper.dart'; // Sesuaikan path jika perlu

enum HistoryFilter { all, sales, credit } // Enum untuk filter

class HistoryProvider extends ChangeNotifier {
  final int userId;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<TransactionModel> _allTransactions = [];
  List<TransactionModel> _filteredTransactions = [];
  HistoryFilter _selectedFilter = HistoryFilter.all;
  bool _isLoading = false;
  String _errorMessage = '';

  // Getters
  List<TransactionModel> get filteredTransactions => _filteredTransactions;
  HistoryFilter get selectedFilter => _selectedFilter;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  HistoryProvider({required this.userId}) {
    loadHistory(); // Langsung load saat provider dibuat
  }

  Future<void> loadHistory() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _allTransactions = await _dbHelper.getTransactionsByUserId(userId);
      _applyFilter(); // Terapkan filter awal setelah data dimuat
    } catch (e) {
      _errorMessage = 'Gagal memuat riwayat: ${e.toString()}';
      _allTransactions = [];
      _filteredTransactions = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setFilter(HistoryFilter filter) {
    if (_selectedFilter != filter) {
      _selectedFilter = filter;
      _applyFilter();
      notifyListeners();
    }
  }

  void _applyFilter() {
    switch (_selectedFilter) {
      case HistoryFilter.sales:
        _filteredTransactions = _allTransactions.where((t) =>
            t.metodePembayaran == 'Tunai' ||
            t.metodePembayaran == 'QRIS' ||
            t.metodePembayaran.startsWith('Pembayaran Kredit') // Ini transaksi PEMBAYARAN hutang, masuk sebagai penjualan/pemasukan
        ).toList();
        break;
      case HistoryFilter.credit:
        _filteredTransactions = _allTransactions.where((t) =>
            t.metodePembayaran == 'Kredit' // Ini transaksi PENJUALAN KREDIT (hutang baru)
        ).toList();
        break;
      case HistoryFilter.all:
      default:
        _filteredTransactions = List.from(_allTransactions);
        break;
    }
    // Urutkan berdasarkan tanggal terbaru
    _filteredTransactions.sort((a, b) => b.tanggalTransaksi.compareTo(a.tanggalTransaksi));
  }
}