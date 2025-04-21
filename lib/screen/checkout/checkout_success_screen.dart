// screen/checkout/checkout_success_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aplikasir_mobile/screen/homepage/homepage_screen.dart'; // Impor HomePage
import 'package:aplikasir_mobile/screen/checkout/receipt_screen.dart'; // Impor ReceiptScreen
import 'package:aplikasir_mobile/model/customer_model.dart';
import 'package:intl/intl.dart';

class CheckoutSuccessScreen extends StatefulWidget {
  final int transactionId;
  final int userId;
  final String paymentMethod; // 'Tunai', 'QRIS', 'Kredit'
  final double? changeAmount; // Kembalian untuk tunai
  // final int? customerId; // Bisa dikirim jika perlu nama pelanggan

  const CheckoutSuccessScreen({
    super.key,
    required this.transactionId,
    required this.userId,
    required this.paymentMethod,
    this.changeAmount,
    // this.customerId,
  });

  @override
  State<CheckoutSuccessScreen> createState() => _CheckoutSuccessScreenState();
}

class _CheckoutSuccessScreenState extends State<CheckoutSuccessScreen> {
  Customer? _customer; // Untuk menampilkan nama pelanggan kredit
  bool _isLoading = false; // Loading state jika fetch data customer

  final NumberFormat currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    if (widget.paymentMethod == 'Kredit') {
      _fetchTransactionAndCustomer(); // Ambil data customer jika kredit
    }
  }

  Future<void> _fetchTransactionAndCustomer() async {
    setState(() => _isLoading = true);
    try {
      // Ambil transaksi untuk mendapatkan ID pelanggan
      // Perlu fungsi getTransactionById di DBHelper
      // final transaction = await DatabaseHelper.instance.getTransactionById(widget.transactionId);
      // if (transaction != null && transaction.idPelanggan != null) {
      //   _customer = await DatabaseHelper.instance.getCustomerById(transaction.idPelanggan!);
      // }

      // Alternatif: Jika ID customer sudah dikirim dari proses sebelumnya
      // if (widget.customerId != null) {
      //    _customer = await DatabaseHelper.instance.getCustomerById(widget.customerId!);
      // }

      // **Simplifikasi Sementara:** Jika butuh nama customer, logic fetch perlu diimplementasikan
      // Untuk sekarang, kita tidak fetch customer di layar ini.
    } catch (e) {
      print("Error fetching customer for success screen: $e");
      // Handle error jika perlu
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Colors.blue.shade700;
    final Color successColor = Colors.green.shade600;

    return PopScope(
      // Cegah back button fisik (opsional)
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: successColor, size: 80),
                const SizedBox(height: 20),
                Text(
                  'Transaksi Berhasil!',
                  style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Metode Pembayaran: ${widget.paymentMethod}',
                  style: GoogleFonts.poppins(
                      fontSize: 16, color: Colors.grey.shade700),
                  textAlign: TextAlign.center,
                ),

                // Tampilkan Kembalian jika Tunai
                if (widget.paymentMethod == 'Tunai' &&
                    widget.changeAmount != null &&
                    widget.changeAmount! > 0) ...[
                  const SizedBox(height: 15),
                  Text(
                    'Kembalian: ${currencyFormatter.format(widget.changeAmount)}',
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                ],

                // Tampilkan Nama Pelanggan jika Kredit (jika data customer di-fetch)
                if (widget.paymentMethod == 'Kredit' && _customer != null) ...[
                  const SizedBox(height: 15),
                  Text(
                    'Ditambahkan ke Hutang: ${_customer!.namaPelanggan}',
                    style: GoogleFonts.poppins(
                        fontSize: 16, color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                ] else if (widget.paymentMethod == 'Kredit' &&
                    _isLoading) // Tampilkan loading jika fetch customer
                  const Padding(
                    padding: EdgeInsets.only(top: 15),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),

                const SizedBox(height: 40),

                // Tombol Aksi
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.receipt_long),
                    label: Text('Lihat Struk',
                        style:
                            GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReceiptScreen(
                            transactionId: widget.transactionId,
                            userId: widget.userId,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.home_outlined),
                    label: Text('Kembali ke Beranda',
                        style: GoogleFonts.poppins()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                            builder: (context) => HomePage(
                                userId: widget.userId)), // Kembali ke home
                        (Route<dynamic> route) =>
                            false, // Hapus semua rute sebelumnya
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
