// screen/manage/credit/customer_debt_history_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:aplikasir_mobile/model/customer_model.dart';
import 'package:aplikasir_mobile/model/transaction_model.dart';
import 'package:aplikasir_mobile/helper/db_helper.dart';
import 'debt_detail_screen.dart'; // Layar baru untuk detail hutang

class CustomerDebtHistoryScreen extends StatefulWidget {
  final Customer customer;
  final int userId;

  const CustomerDebtHistoryScreen(
      {super.key, required this.customer, required this.userId});

  @override
  State<CustomerDebtHistoryScreen> createState() =>
      _CustomerDebtHistoryScreenState();
}

class _CustomerDebtHistoryScreenState extends State<CustomerDebtHistoryScreen> {
  List<TransactionModel> _transactions = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final Color _primaryColor = Colors.blue.shade700;

  final DateFormat _dateFormatter = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
  final NumberFormat currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadCustomerTransactions();
  }

  Future<void> _loadCustomerTransactions() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final transactions = await DatabaseHelper.instance
          .getTransactionsByCustomerId(widget.customer.id!, widget.userId);
      if (!mounted) return;
      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading customer transactions: $e");
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat riwayat: ${e.toString()}';
      });
    }
  }

  // Helper: Membangun item riwayat transaksi pelanggan
  Widget _buildTransactionItem(TransactionModel transaction) {
    bool isUnpaid = transaction.statusPembayaran == 'Belum Lunas';
    Color statusColor =
        isUnpaid ? Colors.orange.shade800 : Colors.green.shade700;

    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200)),
      child: ListTile(
          leading: Icon(
            isUnpaid
                ? Icons.hourglass_bottom_outlined
                : Icons.check_circle_outline,
            color: statusColor,
          ),
          title: Text(
            _dateFormatter.format(
                transaction.tanggalTransaksi), // Tampilkan tanggal & waktu
            style:
                GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            "Metode: ${transaction.metodePembayaran}",
            style:
                GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currencyFormatter.format(transaction.totalBelanja),
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Text(
                transaction.statusPembayaran,
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: statusColor,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
          onTap: () {
            // Hanya bisa di-tap jika belum lunas
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => DebtDetailScreen(
                          transaction: transaction,
                          userId: widget.userId,
                          customerName: widget.customer
                              .namaPelanggan, // Kirim nama untuk tampilan
                        ))).then((paymentMade) {
              // Reload data jika ada pembayaran dari detail screen
              if (paymentMade == true) {
                _loadCustomerTransactions();
              }
            });
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Riwayat ${widget.customer.namaPelanggan}',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: _primaryColor, // Sesuaikan warna AppBar
        shadowColor: Colors.black26,
        surfaceTintColor: Colors.white,
        elevation: 2.5,
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF7F8FC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Text(_errorMessage,
                      style: GoogleFonts.poppins(color: Colors.red)))
              : _transactions.isEmpty
                  ? Center(
                      child: Text(
                          'Tidak ada riwayat transaksi untuk pelanggan ini.',
                          style:
                              GoogleFonts.poppins(color: Colors.grey.shade600)))
                  : RefreshIndicator(
                      onRefresh: _loadCustomerTransactions,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _transactions.length,
                        itemBuilder: (context, index) {
                          return _buildTransactionItem(_transactions[index]);
                        },
                      ),
                    ),
    );
  }
}
