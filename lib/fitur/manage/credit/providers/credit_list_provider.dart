// lib/fitur/manage/credit/providers/credit_list_provider.dart
import 'package:flutter/material.dart';
import 'package:aplikasir_mobile/model/customer_model.dart';
import 'package:aplikasir_mobile/model/transaction_model.dart';
import 'package:aplikasir_mobile/helper/db_helper.dart';

// Model helper untuk summary tetap ada di sini atau dipisah jika lebih kompleks
class CustomerCreditSummary {
  final Customer customer;
  final double totalCredit;
  final double totalOutstandingDebt;
  final int transactionCount;

  CustomerCreditSummary({
    required this.customer,
    required this.totalCredit,
    required this.totalOutstandingDebt,
    required this.transactionCount,
  });
}

class CreditListProvider extends ChangeNotifier {
  final int userId;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<CustomerCreditSummary> _allCustomerSummaries = [];
  List<CustomerCreditSummary> _filteredCustomerSummaries = [];
  bool _isLoading = true;
  String _errorMessage = '';
  bool _sortAscending = true; // Default A-Z
  String _searchQuery = '';

  // Getters
  List<CustomerCreditSummary> get filteredCustomerSummaries => _filteredCustomerSummaries;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  bool get sortAscending => _sortAscending;
  String get searchQuery => _searchQuery; // Untuk UI (misal search bar)

  double get totalOverallDebt =>
      _filteredCustomerSummaries.fold(0.0, (sum, item) => sum + item.totalOutstandingDebt);

  int get totalCustomerWithDebt =>
      _filteredCustomerSummaries.where((s) => s.totalOutstandingDebt > 0).length;


  CreditListProvider({required this.userId}) {
    loadAndProcessCredits();
  }

  Future<void> loadAndProcessCredits() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners(); // Beri tahu UI bahwa sedang loading

    try {
      final allUserTransactions = await _dbHelper.getTransactionsByUserId(userId);
      final List<TransactionModel> allCreditTransactions = allUserTransactions
          .where((t) => t.metodePembayaran == 'Kredit' && t.idPelanggan != null)
          .toList();

      Map<int, List<TransactionModel>> grouped = {};
      for (var transaction in allCreditTransactions) {
        if (transaction.idPelanggan != null) {
          grouped.putIfAbsent(transaction.idPelanggan!, () => []).add(transaction);
        }
      }

      List<CustomerCreditSummary> summaries = [];
      for (var entry in grouped.entries) {
        final customerId = entry.key;
        final customerTransactions = entry.value;
        final customerData = await _dbHelper.getCustomerById(customerId);

        if (customerData != null) {
          double customerTotalCredit = customerTransactions.fold(0.0, (sum, t) => sum + t.totalBelanja);
          double customerOutstandingDebt = customerTransactions
              .where((t) => t.statusPembayaran == 'Belum Lunas')
              .fold(0.0, (sum, t) => sum + t.totalBelanja);

          summaries.add(CustomerCreditSummary(
            customer: customerData,
            totalCredit: customerTotalCredit,
            totalOutstandingDebt: customerOutstandingDebt,
            transactionCount: customerTransactions.length,
          ));
        }
      }
      _allCustomerSummaries = summaries;
      _applyFiltersAndSort(); // Panggil fungsi gabungan
    } catch (e) {
      _errorMessage = 'Gagal memuat data kredit: ${e.toString()}';
      _allCustomerSummaries = [];
      _filteredCustomerSummaries = [];
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
    List<CustomerCreditSummary> tempFiltered = _allCustomerSummaries;

    // Filter Search
    if (_searchQuery.isNotEmpty) {
      tempFiltered = tempFiltered.where((summary) {
        final nameLower = summary.customer.namaPelanggan.toLowerCase();
        final phoneLower = summary.customer.nomorTelepon?.toLowerCase() ?? '';
        return nameLower.contains(_searchQuery) || phoneLower.contains(_searchQuery);
      }).toList();
    }

    // Sorting Nama
    tempFiltered.sort((a, b) {
      int comparison = a.customer.namaPelanggan.toLowerCase().compareTo(b.customer.namaPelanggan.toLowerCase());
      return _sortAscending ? comparison : -comparison;
    });

    _filteredCustomerSummaries = tempFiltered;
    notifyListeners();
  }
}