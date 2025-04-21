// screen/manage/credit/debt_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:aplikasir_mobile/model/transaction_model.dart';
import 'package:aplikasir_mobile/helper/db_helper.dart';
import 'package:aplikasir_mobile/screen/checkout/cash_payment_screen.dart';
import 'package:aplikasir_mobile/screen/checkout/qris_display_screen.dart';
import 'package:aplikasir_mobile/screen/checkout/receipt_screen.dart';

class DebtDetailScreen extends StatefulWidget {
  final TransactionModel transaction;
  final int userId;
  final String customerName;

  const DebtDetailScreen({
    super.key,
    required this.transaction,
    required this.userId,
    required this.customerName,
  });

  @override
  State<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends State<DebtDetailScreen> {
  final DateFormat _dateTimeFormatter =
      DateFormat('dd MMMM yyyy, HH:mm', 'id_ID');
  final NumberFormat currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  bool _isProcessingPayment = false;
  late TransactionModel _currentTransaction;

  // --- Warna & Style Konsisten ---
  final Color _primaryColor = Colors.blue.shade700; // Warna utama biru
  final Color _successColor = Colors.green.shade600; // Warna sukses/lunas
  final Color _warningColor = Colors.orange.shade800; // Warna belum lunas
  final Color _lightBgColor = Colors.white;
  final Color _scaffoldBgColor = const Color(0xFFF7F8FC);
  final Color _darkTextColor = Colors.black87;
  final Color _greyTextColor = Colors.grey.shade600;
  // --- Akhir Warna & Style ---

  // ... (initState, _showSnackbar, _showPaymentMethodSheet, navigasi SAMA) ...
  @override
  void initState() {
    super.initState();
    _currentTransaction = widget.transaction;
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _showPaymentMethodSheet() async {
    if (!mounted || _isProcessingPayment) return;
    final selectedMethod = await showModalBottomSheet<String>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
        ),
        builder: (BuildContext context) {
          return Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(left: 15.0, bottom: 10.0),
                  child: Text("Pilih Metode Pembayaran",
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                ListTile(
                  leading: Icon(Icons.account_balance_wallet_outlined,
                      color: Colors.blue.shade700),
                  title: Text('Bayar Tunai', style: GoogleFonts.poppins()),
                  onTap: () => Navigator.pop(context, 'Tunai'),
                ),
                ListTile(
                  leading: Icon(Icons.qr_code_2, color: Colors.purple.shade700),
                  title: Text('Bayar via QRIS', style: GoogleFonts.poppins()),
                  onTap: () => Navigator.pop(context, 'QRIS'),
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        });
    if (selectedMethod != null && mounted) {
      bool? paymentResult;
      if (selectedMethod == 'Tunai') {
        paymentResult = await _navigateToCashPaymentForDebt();
      } else if (selectedMethod == 'QRIS') {
        paymentResult = await _navigateToQrisPaymentForDebt();
      }
      if (paymentResult == true && mounted) {
        await _markDebtAsPaid();
      } else if (mounted) {
        print("Debt payment cancelled or failed.");
      }
    }
  }

  Future<bool?> _navigateToCashPaymentForDebt() async {
    if (!mounted) return null;
    print("Navigating to CashPaymentScreen for Debt Payment");
    final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (context) => CashPaymentScreen(
                  totalAmount: _currentTransaction.totalBelanja,
                  userId: widget.userId,
                  cartQuantities: const {},
                  cartProducts: const [],
                  transactionIdToUpdate: _currentTransaction.id,
                )));
    print("Returned from CashPaymentScreen with result: $result");
    return result;
  }

  Future<bool?> _navigateToQrisPaymentForDebt() async {
    if (!mounted) return null;
    print("Navigating to QrisDisplayScreen for Debt Payment");
    final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (context) => QrisDisplayScreen(
                  totalAmount: _currentTransaction.totalBelanja,
                  userId: widget.userId,
                  cartQuantities: const {},
                  cartProducts: const [],
                  transactionIdToUpdate: _currentTransaction.id,
                )));
    print("Returned from QrisDisplayScreen with result: $result");
    return result;
  }

  // --- Fungsi Update Status (Sama) ---
  Future<void> _markDebtAsPaid() async {
    if (_currentTransaction.id == null || !mounted) return;
    setState(() => _isProcessingPayment = true);
    try {
      int updatedRows = await DatabaseHelper.instance
          .updateTransactionStatus(_currentTransaction.id!, 'Lunas');
      if (updatedRows > 0) {
        final latestTransaction = await DatabaseHelper.instance
            .getTransactionById(_currentTransaction.id!);
        if (latestTransaction != null && mounted) {
          setState(() {
            _currentTransaction = latestTransaction;
            _isProcessingPayment = false;
          });
          _showSnackbar("Pembayaran hutang berhasil.", isError: false);
          // Tidak pop otomatis, biarkan user melihat status baru
        } else if (mounted) {
          /* ... error handling refresh ... */ _showSnackbar(
              "Gagal refresh detail.",
              isError: true);
          setState(() => _isProcessingPayment = false);
        }
      } else if (mounted) {
        /* ... error handling update DB ... */ _showSnackbar(
            "Gagal update status.",
            isError: true);
        setState(() => _isProcessingPayment = false);
      }
    } catch (e) {
      /* ... error handling umum ... */ print("Error marking debt as paid: $e");
      if (mounted) _showSnackbar("Gagal update status hutang.", isError: true);
      setState(() => _isProcessingPayment = false);
    }
    // finally tidak dibutuhkan lagi karena setState ada di semua cabang try/catch
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- AppBar Style Disesuaikan ---
      appBar: AppBar(
        title: Text('Detail Hutang',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: _primaryColor)), // Warna aksen kredit
        backgroundColor: _lightBgColor, // Background putih/terang
        foregroundColor: _primaryColor, // Warna ikon back
        elevation: 2.5,
        shadowColor: Colors.black26,
        surfaceTintColor: _lightBgColor, // Samakan dengan background
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Lihat Struk Asli',
            onPressed: _isProcessingPayment
                ? null
                : () {
                    // Disable saat proses
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ReceiptScreen(
                                  transactionId: _currentTransaction.id!,
                                  userId: widget.userId,
                                )));
                  },
          )
        ],
      ),
      backgroundColor: _scaffoldBgColor, // Background utama
      body: Padding(
        padding: const EdgeInsets.all(16.0), // Padding utama body
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Info Header ---
            Text(
              "Pelanggan:",
              style: GoogleFonts.poppins(fontSize: 14, color: _greyTextColor),
            ),
            Text(
              widget.customerName,
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _darkTextColor),
            ),
            const SizedBox(height: 20),
            Text(
              "Detail Transaksi Hutang:",
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _darkTextColor),
            ),
            const SizedBox(height: 10),

            // --- Kartu Detail (Style Disesuaikan) ---
            Card(
              elevation: 1.5,
              margin: EdgeInsets.zero, // Hapus margin default card
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)), // Radius konsisten
              color: _lightBgColor, // Background putih
              surfaceTintColor: _lightBgColor,
              child: Padding(
                padding: const EdgeInsets.all(16.0), // Padding dalam card
                child: Column(
                  children: [
                    _buildDetailRow("ID Transaksi:",
                        "#${_currentTransaction.id ?? 'N/A'}"), // Handle ID null
                    _buildDetailRow(
                        "Tanggal Hutang:",
                        _dateTimeFormatter
                            .format(_currentTransaction.tanggalTransaksi)),
                    _buildDetailRow(
                        "Metode Asal:", _currentTransaction.metodePembayaran),
                    _buildDetailRow(
                        "Status:", _currentTransaction.statusPembayaran,
                        valueStyle: GoogleFonts.poppins(
                            // Gunakan GoogleFonts
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color:
                                _currentTransaction.statusPembayaran == 'Lunas'
                                    ? _successColor
                                    : _warningColor // Gunakan warna konsisten
                            )),
                    const Divider(
                        height: 25, thickness: 0.8), // Divider lebih jelas
                    _buildDetailRow(
                        "Total Hutang:",
                        currencyFormatter
                            .format(_currentTransaction.totalBelanja),
                        isTotal: true),
                  ],
                ),
              ),
            ),
            // --- Akhir Kartu Detail ---

            const Spacer(), // Dorong tombol ke bawah

            // --- Tombol Bayar (Style Disesuaikan) ---
            if (_currentTransaction.statusPembayaran == 'Belum Lunas')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _isProcessingPayment
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : const Icon(Icons.payment, size: 20),
                  label: Text(
                      _isProcessingPayment
                          ? "Memproses..."
                          : "Bayar Kredit Ini",
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 16)),
                  onPressed:
                      _isProcessingPayment ? null : _showPaymentMethodSheet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor, // Warna hijau konfirmasi
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14), // Padding konsisten
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(10)), // Radius konsisten
                    elevation: 2.0,
                  ),
                ),
              )
            else // Tampilkan pesan lunas
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Text("Hutang ini sudah lunas.",
                      style: GoogleFonts.poppins(
                          color: _successColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 15)),
                ),
              ),
            SizedBox(
              height: 20,
            ), // Jarak bawah sebelum tombol
          ],
        ),
      ),
    );
  }

  // --- Helper widget untuk baris detail (Style Disesuaikan) ---
  Widget _buildDetailRow(String label, String value,
      {bool isTotal = false, TextStyle? valueStyle}) {
    final labelStyle = GoogleFonts.poppins(
        fontSize: 14, color: _greyTextColor); // Ukuran font konsisten
    final finalValueStyle = valueStyle ??
        GoogleFonts.poppins(
            fontSize: 14, // Ukuran font konsisten
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: _darkTextColor // Warna teks value
            );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0), // Beri jarak vertikal
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment:
            CrossAxisAlignment.start, // Align start jika teks panjang
        children: [
          Text(label, style: labelStyle),
          const SizedBox(width: 10), // Jarak antara label dan value
          Expanded(
            // Agar value bisa wrap jika panjang
            child: Text(
              value,
              style: finalValueStyle,
              textAlign: TextAlign.right, // Rata kanan untuk nilai
            ),
          ),
        ],
      ),
    );
  }
}
