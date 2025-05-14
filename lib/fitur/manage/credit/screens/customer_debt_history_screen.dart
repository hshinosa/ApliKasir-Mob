// lib/fitur/manage/credit/customer_debt_history_screen.dart
import 'package:aplikasir_mobile/fitur/manage/credit/providers/customer_debt_history_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:aplikasir_mobile/model/customer_model.dart';
import 'package:aplikasir_mobile/model/transaction_model.dart';
// import 'package:aplikasir_mobile/helper/db_helper.dart'; // Tidak perlu jika provider handle
import 'debt_detail_screen.dart';

class CustomerDebtHistoryScreen extends StatelessWidget { // Ubah jadi StatelessWidget
  final Customer customer;
  final int userId;

  const CustomerDebtHistoryScreen({super.key, required this.customer, required this.userId});

  // Pindahkan _dateFormatter dan currencyFormatter ke State jika dibutuhkan oleh widget buildTransactionItem
  // Atau buat sebagai static final di dalam class State

  // _buildTransactionItem sekarang menjadi static atau dipindah ke widget terpisah jika kompleks

  @override
  Widget build(BuildContext context) {
    final DateFormat _dateFormatter = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
    final NumberFormat currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final Color _primaryColor = Colors.blue.shade700;

    Widget _buildTransactionItemWidget(TransactionModel transaction) {
      bool isUnpaid = transaction.statusPembayaran == 'Belum Lunas';
      Color statusColor = isUnpaid ? Colors.orange.shade800 : Colors.green.shade700;

      return Container(
        margin: const EdgeInsets.only(bottom: 10.0),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200)),
        child: ListTile(
            leading: Icon(isUnpaid ? Icons.hourglass_bottom_outlined : Icons.check_circle_outline, color: statusColor),
            title: Text(_dateFormatter.format(transaction.tanggalTransaksi),
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
            subtitle: Text("Metode: ${transaction.metodePembayaran}",
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(currencyFormatter.format(transaction.totalBelanja),
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold)),
                Text(transaction.statusPembayaran,
                    style: GoogleFonts.poppins(fontSize: 11, color: statusColor, fontWeight: FontWeight.w500)),
              ],
            ),
            onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => DebtDetailScreen(
                              transaction: transaction,
                              userId: userId, // gunakan userId dari parameter
                              customerName: customer.namaPelanggan,
                            )))
                    .then((paymentMade) {
                  if (paymentMade == true) {
                     context.read<CustomerDebtHistoryProvider>().loadCustomerTransactions();
                  }
                });
            }),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => CustomerDebtHistoryProvider(customer: customer, userId: userId),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Riwayat ${customer.namaPelanggan}',
              overflow: TextOverflow.ellipsis, // Agar tidak overflow jika nama panjang
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _primaryColor)
          ),
          backgroundColor: Colors.white,
          foregroundColor: _primaryColor,
          shadowColor: Colors.black26,
          surfaceTintColor: Colors.white,
          elevation: 2.5,
          centerTitle: true,
        ),
        backgroundColor: const Color(0xFFF7F8FC),
        body: Consumer<CustomerDebtHistoryProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (provider.errorMessage.isNotEmpty) {
              return Center(child: Text(provider.errorMessage, style: GoogleFonts.poppins(color: Colors.red)));
            }
            if (provider.transactions.isEmpty) {
              return Center(child: Text('Tidak ada riwayat transaksi kredit untuk pelanggan ini.',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.poppins(color: Colors.grey.shade600)));
            }
            return RefreshIndicator(
              onRefresh: () => provider.loadCustomerTransactions(),
              child: Column(
                children: [
                  // Info Total Hutang
                   if (provider.totalOutstandingDebt > 0) // Hanya tampilkan jika ada hutang
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Total Hutang:", style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500)),
                              Text(
                                currencyFormatter.format(provider.totalOutstandingDebt),
                                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.only(
                        left: 16.0,
                        right: 16.0,
                        bottom: 16.0,
                        top: provider.totalOutstandingDebt > 0 ? 0 : 16.0 // Kurangi padding atas jika summary ada
                      ),
                      itemCount: provider.transactions.length,
                      itemBuilder: (context, index) {
                        return _buildTransactionItemWidget(provider.transactions[index]);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}