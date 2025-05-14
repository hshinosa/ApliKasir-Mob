// lib/features/checkout/screens/checkout_success_screen.dart
import 'package:aplikasir_mobile/fitur/homepage/homepage_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'receipt_screen.dart'; // Path ke receipt screen

class CheckoutSuccessScreen extends StatefulWidget {
  final int transactionId;
  final int userId;
  final String paymentMethod;
  final double? changeAmount;

  const CheckoutSuccessScreen({
    super.key,
    required this.transactionId,
    required this.userId,
    required this.paymentMethod,
    this.changeAmount,
  });

  @override
  State<CheckoutSuccessScreen> createState() => _CheckoutSuccessScreenState();
}

class _CheckoutSuccessScreenState extends State<CheckoutSuccessScreen> {
  final NumberFormat currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Colors.blue.shade700;
    final Color successColor = Colors.green.shade600;

    return PopScope( // Mencegah back button fisik, navigasi harus via tombol
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
                  style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Metode Pembayaran: ${widget.paymentMethod}',
                  style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade700),
                  textAlign: TextAlign.center,
                ),
                if (widget.paymentMethod == 'Tunai' && widget.changeAmount != null && widget.changeAmount! > 0) ...[
                  const SizedBox(height: 15),
                  Text(
                    'Kembalian: ${currencyFormatter.format(widget.changeAmount)}',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                ],
                // Anda bisa tambahkan info pelanggan jika ini transaksi kredit (dari parameter widget.customerName misal)
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.receipt_long),
                    label: Text('Lihat Struk', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReceiptScreen( // Pastikan ReceiptScreen ada di path yg benar
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
                    label: Text('Kembali ke Beranda', style: GoogleFonts.poppins()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => HomePage(userId: widget.userId)),
                        (Route<dynamic> route) => false,
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