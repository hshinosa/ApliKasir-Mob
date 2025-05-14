// lib/fitur/manage/credit/credit_list_screen.dart
import 'package:aplikasir_mobile/fitur/manage/credit/providers/credit_list_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
// Impor model dan DB Helper JIKA MASIH DIGUNAKAN LANGSUNG DI SINI (seharusnya tidak lagi)
// import 'package:aplikasir_mobile/model/customer_model.dart';
// import 'package:aplikasir_mobile/model/transaction_model.dart';
// import 'package:aplikasir_mobile/helper/db_helper.dart';
import 'customer_debt_history_screen.dart';

// Hapus class CustomerCreditSummary dari sini, karena sudah ada di provider

class CreditListScreen extends StatefulWidget {
  final int userId; // userId masih dibutuhkan untuk inisialisasi Provider
  const CreditListScreen({super.key, required this.userId});

  @override
  State<CreditListScreen> createState() => _CreditListScreenState();
}

class _CreditListScreenState extends State<CreditListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final NumberFormat currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  // State untuk UI dipindahkan ke Provider (_allCustomerSummaries, _filteredCustomerSummaries, dll.)

  // Warna & Style (bisa tetap di sini atau di tema global)
  final Color _primaryColor = Colors.blue.shade700;
  final Color _lightBgColor = Colors.white;
  final Color _iconColor = Colors.blue.shade600;
  final Color _iconBgColor = Colors.blue.shade50;
  final Color _darkTextColor = Colors.black87;
  final Color _greyTextColor = Colors.grey.shade600;
  final Color _debtColor = Colors.orange.shade800;
  final Color _paidColor = Colors.green.shade700;

  @override
  void initState() {
    super.initState();
    // Provider akan memuat data saat diinisialisasi
    // Listener untuk search controller
    _searchController.addListener(() {
      // Panggil method di provider untuk update query
      // Kita tidak perlu lagi menjalankan filter secara manual di sini
      // Cukup update query di provider, dan provider akan handle filter + notifikasi UI
      // Tapi agar lebih reaktif, kita bisa memanggil metode setSearchQuery di provider saat onChanged di TextField
    });
  }

  @override
  void dispose() {
    _searchController.dispose(); // dispose controller tetap di sini
    super.dispose();
  }

  // --- Fungsi Load dan Sort tidak diperlukan lagi di sini, pindah ke Provider ---

  // --- Helper: Membangun Item Pelanggan Kredit (menggunakan data dari Provider) ---
  Widget _buildCustomerCreditItem(CustomerCreditSummary summary, BuildContext context) { // Tambah BuildContext
    bool hasOutstandingDebt = summary.totalOutstandingDebt > 0;
    // Ambil userId dari provider jika diperlukan untuk navigasi selanjutnya
    // atau langsung gunakan widget.userId
    final provider = context.read<CreditListProvider>();


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
        contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        leading: CircleAvatar(
          backgroundColor: _iconBgColor,
          radius: 25,
          child: Icon(Icons.person_outline, color: _iconColor, size: 26),
        ),
        title: Text(
          summary.customer.namaPelanggan,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: summary.customer.nomorTelepon != null && summary.customer.nomorTelepon!.isNotEmpty
            ? Text(
                summary.customer.nomorTelepon!,
                style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey.shade600),
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
                    hasOutstandingDebt ? "Belum Lunas" : "Lunas",
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: hasOutstandingDebt ? _debtColor : _paidColor,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                    currencyFormatter.format(hasOutstandingDebt ? summary.totalOutstandingDebt : summary.totalCredit),
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: _darkTextColor)),
              ],
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CustomerDebtHistoryScreen(
                customer: summary.customer,
                userId: provider.userId, // Ambil userId dari Provider
              ),
            ),
          ).then((_) {
            // Reload saat kembali
             if (mounted) context.read<CreditListProvider>().loadAndProcessCredits();
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Sediakan Provider di sini
    return ChangeNotifierProvider(
      create: (_) => CreditListProvider(userId: widget.userId),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Daftar Kredit', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _primaryColor)),
          backgroundColor: Colors.white,
          foregroundColor: _primaryColor,
          shadowColor: Colors.black26,
          surfaceTintColor: Colors.white,
          elevation: 2.5,
          centerTitle: true,
        ),
        backgroundColor: const Color(0xFFF7F8FC),
        // Gunakan Consumer untuk mendengarkan perubahan di Provider
        body: Consumer<CreditListProvider>(
          builder: (context, provider, child) {
            // Data diambil dari provider
            double totalOverallDebt = provider.totalOverallDebt;
            int totalCustomerWithDebt = provider.totalCustomerWithDebt;

            return Column(
              children: [
                // --- Area Filter ---
                SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 10.0),
                  child: Row(children: [
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
                          onChanged: (query) { // Panggil setSearchQuery di Provider
                             provider.setSearchQuery(query);
                          },
                          decoration: InputDecoration(
                            hintText: 'Cari Nama / No. Telp',
                            hintStyle: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14),
                            prefixIcon: Icon(Icons.search, color: Colors.grey.shade600, size: 22),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear, color: Colors.grey.shade500, size: 20),
                                    onPressed: () {
                                      _searchController.clear();
                                      provider.setSearchQuery(''); // Update query di provider
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 5),
                            isDense: true,
                          ),
                          style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () => provider.toggleSortOrder(), // Panggil toggleSortOrder di Provider
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
                          message: provider.sortAscending ? 'Urutkan Z-A' : 'Urutkan A-Z',
                          child: Icon(Icons.sort_by_alpha, color: _primaryColor, size: 24),
                        ),
                      ),
                    ),
                  ]),
                ),
                // --- Kartu Summary ---
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10.0),
                    boxShadow: [
                      BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Total Hutang", style: GoogleFonts.poppins(fontSize: 13, color: _greyTextColor)),
                          Text(currencyFormatter.format(totalOverallDebt),
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: _debtColor))
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("Jml Pelanggan", style: GoogleFonts.poppins(fontSize: 13, color: _greyTextColor)),
                          Text(totalCustomerWithDebt.toString(),
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: _darkTextColor))
                        ],
                      ),
                    ],
                  ),
                ),
                // --- Daftar Pelanggan ---
                Expanded(
                  child: provider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : provider.errorMessage.isNotEmpty
                          ? Center(
                              child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(provider.errorMessage,
                                      style: GoogleFonts.poppins(color: Colors.red),
                                      textAlign: TextAlign.center)))
                          : provider.filteredCustomerSummaries.isEmpty // Cek hasil filter dari provider
                              ? Center(
                                  child: Text(
                                    _searchController.text.isEmpty
                                     ? 'Tidak ada pelanggan yang memiliki kredit.'
                                     : 'Pelanggan "${_searchController.text}" tidak ditemukan.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(color: Colors.grey.shade500),
                                  ),
                                )
                              : RefreshIndicator(
                                  onRefresh: () => provider.loadAndProcessCredits(),
                                  child: ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
                                    itemCount: provider.filteredCustomerSummaries.length,
                                    itemBuilder: (context, index) {
                                      return _buildCustomerCreditItem(provider.filteredCustomerSummaries[index], context); // Pass context
                                    },
                                  ),
                                ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}