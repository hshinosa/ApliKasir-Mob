// screen/manage/credit/credit_list_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:aplikasir_mobile/model/customer_model.dart';
import 'package:aplikasir_mobile/model/transaction_model.dart';
import 'package:aplikasir_mobile/helper/db_helper.dart';
import 'customer_debt_history_screen.dart';

// Model helper - sedikit dimodifikasi untuk total kredit keseluruhan
class CustomerCreditSummary {
  final Customer customer;
  final double totalCredit; // Total nilai transaksi kredit (lunas + belum)
  final double totalOutstandingDebt; // Hanya total yang belum lunas
  final int transactionCount; // Jumlah total transaksi kredit

  CustomerCreditSummary({
    required this.customer,
    required this.totalCredit,
    required this.totalOutstandingDebt,
    required this.transactionCount,
  });
}

class CreditListScreen extends StatefulWidget {
  final int userId;
  const CreditListScreen({super.key, required this.userId});

  @override
  State<CreditListScreen> createState() => _CreditListScreenState();
}

class _CreditListScreenState extends State<CreditListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final NumberFormat currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  // State untuk data
  List<TransactionModel> _allCreditTransactions = []; // Semua transaksi kredit
  List<CustomerCreditSummary> _allCustomerSummaries = [];
  List<CustomerCreditSummary> _filteredCustomerSummaries = [];
  bool _isLoading = true;
  String _errorMessage = '';
  bool _sortAscending = true; // Untuk sorting nama A-Z

  // Warna & Style (Gunakan Biru)
  final Color _primaryColor = Colors.blue.shade700; // Warna tema utama
  final Color _lightBgColor = Colors.white; // Background search/card
  final Color _iconColor = Colors.blue.shade600;
  final Color _iconBgColor = Colors.blue.shade50;
  final Color _darkTextColor = Colors.black87;
  final Color _greyTextColor = Colors.grey.shade600;
  final Color _debtColor = Colors.orange.shade800; // Warna hutang belum lunas
  final Color _paidColor = Colors.green.shade700; // Warna lunas

  @override
  void initState() {
    super.initState();
    _loadAndProcessCredits();
    _searchController.addListener(_filterAndSortSummaries);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterAndSortSummaries);
    _searchController.dispose();
    super.dispose();
  }

  // --- Fungsi Load & Proses Data Kredit ---
  Future<void> _loadAndProcessCredits() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      // 1. Ambil SEMUA transaksi dengan metode 'Kredit'
      //    Kita perlu modifikasi DB helper atau filter di sini
      // final allUserTransactions = await DatabaseHelper.instance.getTransactionsByUserId(widget.userId);
      // _allCreditTransactions = allUserTransactions.where((t) => t.metodePembayaran == 'Kredit').toList();
      // Alternatif: Buat fungsi baru di DB Helper getCreditTransactionsByUserId

      // Untuk sementara, kita gunakan getTransactionsByUserId lalu filter manual
      final allUserTransactions =
          await DatabaseHelper.instance.getTransactionsByUserId(widget.userId);
      _allCreditTransactions = allUserTransactions
          .where((t) => t.metodePembayaran == 'Kredit' && t.idPelanggan != null)
          .toList();

      // 2. Group berdasarkan id_pelanggan
      Map<int, List<TransactionModel>> grouped = {};
      for (var transaction in _allCreditTransactions) {
        if (transaction.idPelanggan != null) {
          grouped
              .putIfAbsent(transaction.idPelanggan!, () => [])
              .add(transaction);
        }
      }

      // 3. Fetch data customer dan buat summary
      List<CustomerCreditSummary> summaries = [];
      for (var entry in grouped.entries) {
        final customerId = entry.key;
        final customerTransactions = entry.value;
        final customerData =
            await DatabaseHelper.instance.getCustomerById(customerId);

        if (customerData != null) {
          double customerTotalCredit =
              customerTransactions.fold(0.0, (sum, t) => sum + t.totalBelanja);
          double customerOutstandingDebt = customerTransactions
              .where((t) => t.statusPembayaran == 'Belum Lunas')
              .fold(0.0, (sum, t) => sum + t.totalBelanja);

          summaries.add(CustomerCreditSummary(
            customer: customerData,
            totalCredit: customerTotalCredit,
            totalOutstandingDebt: customerOutstandingDebt,
            transactionCount: customerTransactions.length,
          ));
        } else {
          print("Warning: Customer data not found for ID $customerId");
        }
      }

      if (!mounted) return;
      setState(() {
        _allCustomerSummaries = summaries;
        _filteredCustomerSummaries = List.from(summaries);
        _isLoading = false;
        _filterAndSortSummaries(); // Terapkan filter & sort awal
      });
    } catch (e) {
      print("Error loading/processing credits: $e");
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat data kredit: ${e.toString()}';
      });
    }
  }

  // --- Fungsi Filter dan Sort ---
  void _filterAndSortSummaries() {
    if (!mounted) return;
    final query = _searchController.text.toLowerCase().trim();

    List<CustomerCreditSummary> tempFiltered =
        _allCustomerSummaries.where((summary) {
      // Filter Search (Nama atau Telp)
      if (query.isNotEmpty) {
        final nameLower = summary.customer.namaPelanggan.toLowerCase();
        final phoneLower = summary.customer.nomorTelepon?.toLowerCase() ?? '';
        if (!nameLower.contains(query) && !phoneLower.contains(query)) {
          return false;
        }
      }
      return true; // Lolos filter search
    }).toList();

    // Sorting Nama
    tempFiltered.sort((a, b) {
      int comparison = a.customer.namaPelanggan
          .toLowerCase()
          .compareTo(b.customer.namaPelanggan.toLowerCase());
      return _sortAscending ? comparison : -comparison;
    });

    setState(() {
      _filteredCustomerSummaries = tempFiltered;
    });
  }

  // --- Helper: Membangun Item Pelanggan Kredit ---
  Widget _buildCustomerCreditItem(CustomerCreditSummary summary) {
    bool hasOutstandingDebt = summary.totalOutstandingDebt > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
            vertical: 8.0, horizontal: 12.0), // Sesuaikan padding
        leading: CircleAvatar(
          backgroundColor: _iconBgColor,
          radius: 25,
          child: Icon(Icons.person_outline, color: _iconColor, size: 26),
        ),
        title: Text(
          summary.customer.namaPelanggan,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: summary.customer.nomorTelepon != null &&
                summary.customer.nomorTelepon!.isNotEmpty
            ? Text(
                summary.customer.nomorTelepon!,
                style: GoogleFonts.poppins(
                    fontSize: 12.5, color: Colors.grey.shade600),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                    // Tampilkan status berdasarkan ada/tidaknya hutang
                    hasOutstandingDebt ? "Belum Lunas" : "Lunas",
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: hasOutstandingDebt ? _debtColor : _paidColor,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                    // Tampilkan hutang jika ada, atau total kredit jika lunas semua
                    currencyFormatter.format(hasOutstandingDebt
                        ? summary.totalOutstandingDebt
                        : summary.totalCredit),
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _darkTextColor)),
              ],
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios,
                size: 16, color: Colors.grey.shade400),
          ],
        ),
        onTap: () {
          // Navigasi ke detail riwayat kredit pelanggan
          Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => CustomerDebtHistoryScreen(
                            customer: summary.customer,
                            userId: widget.userId,
                          )))
              .then((_) => _loadAndProcessCredits()); // Reload saat kembali
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalOverallDebt = _filteredCustomerSummaries.fold(
        0.0, (sum, item) => sum + item.totalOutstandingDebt);
    int totalCustomerWithDebt = _filteredCustomerSummaries
        .where((s) => s.totalOutstandingDebt > 0)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Kredit',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: _primaryColor)),
        backgroundColor: Colors.white,
        foregroundColor: _primaryColor,
        shadowColor: Colors.black26,
        surfaceTintColor: Colors.white,
        elevation: 2.5,
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF7F8FC),
      body: Column(
        children: [
          // --- Area Filter (Style seperti HomePage) ---
          SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 10.0),
            child: Row(children: [
              // Search Field
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                      color: _lightBgColor,
                      borderRadius: BorderRadius.circular(10.0),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 4,
                            offset: Offset(0, 1))
                      ]),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari Nama / No. Telp',
                      hintStyle: GoogleFonts.poppins(
                          color: Colors.grey.shade600, fontSize: 14),
                      prefixIcon: Icon(Icons.search,
                          color: Colors.grey.shade600, size: 22),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear,
                                  color: Colors.grey.shade500, size: 20),
                              onPressed: () {
                                _searchController.clear();
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 14.0, horizontal: 5),
                      isDense: true,
                    ),
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: Colors.black87),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Tombol Sort
              InkWell(
                onTap: () {
                  setState(() {
                    _sortAscending = !_sortAscending;
                    _filterAndSortSummaries();
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                      color: _lightBgColor,
                      borderRadius: BorderRadius.circular(10.0),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 4,
                            offset: Offset(0, 1))
                      ]),
                  child: Tooltip(
                    message: _sortAscending ? 'Urutkan Z-A' : 'Urutkan A-Z',
                    child: Icon(
                      Icons.sort_by_alpha,
                      color: _primaryColor,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ]),
          ),
          // --- Akhir Area Filter ---

          // --- Kartu Summary (Style seperti Kartu Pelanggan) ---
          Container(
            margin:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            padding:
                const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Total Hutang",
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: _greyTextColor)),
                    Text(currencyFormatter.format(totalOverallDebt),
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _debtColor))
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("Jumlah Pelanggan",
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: _greyTextColor)),
                    Text(totalCustomerWithDebt.toString(),
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _darkTextColor))
                  ],
                ),
              ],
            ),
          ),
          // --- Akhir Kartu Summary ---

          // --- Daftar Pelanggan ---
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
                    : _allCustomerSummaries.isEmpty
                        ? Center(
                            child: Text(
                              'Tidak ada pelanggan yang memiliki kredit.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                  color: Colors.grey.shade500),
                            ),
                          )
                        : _filteredCustomerSummaries.isEmpty
                            ? Center(
                                child: Text(
                                  'Pelanggan "${_searchController.text}" tidak ditemukan.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                      color: Colors.grey.shade500),
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _loadAndProcessCredits,
                                child: ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                      16.0, 8.0, 16.0, 16.0),
                                  itemCount: _filteredCustomerSummaries.length,
                                  itemBuilder: (context, index) {
                                    return _buildCustomerCreditItem(
                                        _filteredCustomerSummaries[index]);
                                  },
                                ),
                              ),
          ),
        ],
      ),
    );
  }
}
