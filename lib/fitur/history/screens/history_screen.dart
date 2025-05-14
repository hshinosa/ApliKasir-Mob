// lib/features/history/screens/history_screen.dart
import 'package:aplikasir_mobile/fitur/checkout/screens/receipt_screen.dart';
import 'package:aplikasir_mobile/fitur/history/providers/history_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // Import Provider
import 'package:aplikasir_mobile/model/transaction_model.dart';
import 'package:provider/provider.dart';


class HistoryScreen extends StatefulWidget {
  // Hapus userId, karena akan di-pass ke Provider
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // Formatters tetap di state jika hanya dipakai di UI ini
  final DateFormat _dateFormatter = DateFormat('dd MMM yyyy', 'id_ID');
  final DateFormat _timeFormatter = DateFormat('HH:mm', 'id_ID');
  final NumberFormat _currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  // Tidak perlu _allTransactions, _filteredTransactions, _isLoading, _errorMessage, _selectedFilterIndex
  // Semua itu sekarang ada di HistoryProvider

  @override
  void initState() {
    super.initState();
    // Data akan di-load oleh HistoryProvider saat dibuat
    // Jika Anda ingin memuat ulang saat layar pertama kali terlihat (setelah provider dibuat):
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   context.read<HistoryProvider>().loadHistory();
    // });
  }

  Widget _buildFilterChip(BuildContext context, String label, HistoryFilter filterValue) {
    // Akses provider untuk mendapatkan filter terpilih
    final provider = context.watch<HistoryProvider>();
    bool isSelected = provider.selectedFilter == filterValue;

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onTap: () {
          // Panggil method di provider untuk mengubah filter
          context.read<HistoryProvider>().setFilter(filterValue);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade600 : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
              width: 1.2,
            ),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.blue.shade100, blurRadius: 3, offset: const Offset(0, 1))]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: isSelected ? Colors.white : Colors.blueGrey.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, TransactionModel transaction) {
    // Akses userId dari provider jika diperlukan untuk navigasi struk
    final userId = context.read<HistoryProvider>().userId;

    IconData iconData;
    Color iconBgColor;
    Color iconColor;
    String title = 'Transaksi';
    String subtitle = '';
    Color amountColor = Colors.grey.shade800;
    double amount = transaction.totalBelanja;

    // Logika penentuan ikon, warna, dll. SAMA seperti sebelumnya
    if (transaction.metodePembayaran == 'Tunai') {
      iconData = Icons.payments_outlined;
      iconBgColor = Colors.green.shade50;
      iconColor = Colors.green.shade700;
      title = 'Penjualan Tunai';
      subtitle = _timeFormatter.format(transaction.tanggalTransaksi);
      amountColor = Colors.green.shade700;
    } else if (transaction.metodePembayaran == 'QRIS') {
      iconData = Icons.qr_code_scanner;
      iconBgColor = Colors.blue.shade50;
      iconColor = Colors.blue.shade700;
      title = 'Pembayaran QRIS';
      subtitle = _timeFormatter.format(transaction.tanggalTransaksi);
      amountColor = Colors.green.shade700;
    } else if (transaction.metodePembayaran == 'Kredit') {
      iconData = Icons.credit_card_off_outlined;
      iconBgColor = Colors.orange.shade50;
      iconColor = Colors.orange.shade700;
      title = 'Penjualan Kredit';
      subtitle = 'Status: ${transaction.statusPembayaran}';
      amountColor = transaction.statusPembayaran == 'Lunas'
          ? Colors.grey.shade500
          : Colors.orange.shade800;
    } else if (transaction.metodePembayaran.startsWith('Pembayaran Kredit')) {
      iconData = Icons.check_circle;
      iconBgColor = Colors.teal.shade50;
      iconColor = Colors.teal.shade700;
      title = 'Pembayaran Hutang';
      subtitle = 'via ${transaction.metodePembayaran.split(' ').last} (#${transaction.idTransaksiHutang ?? 'N/A'})';
      amountColor = Colors.teal.shade700;
      amount = transaction.jumlahBayar ?? transaction.totalBelanja;
    } else {
      iconData = Icons.receipt_long_outlined;
      iconBgColor = Colors.grey.shade100;
      iconColor = Colors.grey.shade700;
      title = 'Transaksi Lain';
      subtitle = _timeFormatter.format(transaction.tanggalTransaksi);
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReceiptScreen(
              transactionId: transaction.id!,
              userId: userId, // Gunakan userId dari provider
            ),
          ),
        ).then((_) {
          // Muat ulang data riwayat setelah kembali dari struk jika ada perubahan
          context.read<HistoryProvider>().loadHistory();
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10.0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200, width: 1.2),
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(10)),
              child: Icon(iconData, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade800)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_dateFormatter.format(transaction.tanggalTransaksi), style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade500)),
                const SizedBox(height: 3),
                Text(_currencyFormatter.format(amount), style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12, color: amountColor)),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dengarkan HistoryProvider
    final historyProvider = context.watch<HistoryProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: RefreshIndicator(
        onRefresh: () => context.read<HistoryProvider>().loadHistory(), // Panggil refresh dari provider
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20), // Spasi dari AppBar (jika ada AppBar di HomePage)
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.045,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildFilterChip(context, "Semua", HistoryFilter.all),
                    _buildFilterChip(context, "Penjualan", HistoryFilter.sales), // Tunai, QRIS, Bayar Kredit
                    _buildFilterChip(context, "Kredit", HistoryFilter.credit), // Penjualan Kredit
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.only(left: 4.0, bottom: 12.0),
                child: Text(
                  'Riwayat Terbaru',
                  style: GoogleFonts.poppins(
                    fontSize: MediaQuery.of(context).size.width * 0.045,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              Expanded(
                child: historyProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : historyProvider.errorMessage.isNotEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                historyProvider.errorMessage,
                                style: GoogleFonts.poppins(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : historyProvider.filteredTransactions.isEmpty
                            ? Center(
                                child: Text(
                                  historyProvider.selectedFilter == HistoryFilter.all
                                      ? 'Belum ada riwayat transaksi.'
                                      : 'Tidak ada riwayat untuk filter ini.',
                                  style: GoogleFonts.poppins(color: Colors.grey.shade500),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                itemCount: historyProvider.filteredTransactions.length,
                                itemBuilder: (context, index) {
                                  return _buildHistoryItem(context, historyProvider.filteredTransactions[index]);
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}