// lib/fitur/manage/credit/debt_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:aplikasir_mobile/model/transaction_model.dart'; // Pastikan path benar
import 'package:aplikasir_mobile/helper/db_helper.dart';         // Pastikan path benar
import 'package:aplikasir_mobile/fitur/checkout/screens/cash_payment_screen.dart'; // Pastikan path benar
import 'package:aplikasir_mobile/fitur/checkout/screens/qris_display_screen.dart'; // Pastikan path benar
import 'package:aplikasir_mobile/fitur/checkout/screens/receipt_screen.dart';     // Pastikan path benar

class DebtDetailScreen extends StatefulWidget {
  final TransactionModel transaction; // Transaksi hutang ASLI
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
  final DateFormat _dateTimeFormatter = DateFormat('dd MMMM yyyy, HH:mm', 'id_ID');
  final NumberFormat currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  bool _isProcessingPayment = false; // Loading untuk proses buka sheet/navigasi pembayaran
  late TransactionModel _currentTransaction; // Untuk menampilkan status terkini

  // --- Warna & Style Konsisten ---
  final Color _primaryColor = Colors.blue.shade700;
  final Color _successColor = Colors.green.shade600;
  final Color _warningColor = Colors.orange.shade800;
  final Color _lightBgColor = Colors.white;
  final Color _scaffoldBgColor = const Color(0xFFF7F8FC);
  final Color _darkTextColor = Colors.black87;
  final Color _greyTextColor = Colors.grey.shade600;

  @override
  void initState() {
    super.initState();
    _currentTransaction = widget.transaction; // Inisialisasi dengan data awal
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        duration: const Duration(seconds: 3), // Durasi lebih lama jika error
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _showPaymentMethodSheet() async {
    if (!mounted || _isProcessingPayment) return;
    setState(() => _isProcessingPayment = true);

    final selectedMethod = await showModalBottomSheet<String>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
        ),
        builder: (BuildContext context) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(left: 15.0, bottom: 10.0),
                  child: Text("Pilih Metode Pembayaran",
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                ListTile(
                  leading: Icon(Icons.account_balance_wallet_outlined, color: Colors.blue.shade700),
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

    if (!mounted) { // Cek mounted setelah await
        setState(() => _isProcessingPayment = false); // Hentikan loading jika widget sudah dispose
        return;
    }

    bool? paymentSuccessfullyMadeAndConfirmedByPaymentScreen;

    if (selectedMethod == 'Tunai') {
      paymentSuccessfullyMadeAndConfirmedByPaymentScreen = await _navigateToCashPaymentForDebt();
    } else if (selectedMethod == 'QRIS') {
      paymentSuccessfullyMadeAndConfirmedByPaymentScreen = await _navigateToQrisPaymentForDebt();
    }

    if (paymentSuccessfullyMadeAndConfirmedByPaymentScreen == true) {
      // Pembayaran (Tunai/QRIS) berhasil dan status hutang asli sudah diupdate di layar Cash/QRIS.
      // Tampilkan pesan sukses, muat ulang detail hutang (untuk status), dan kemudian pop dengan true.
      _showSnackbar("Pembayaran untuk hutang ini berhasil diproses.", isError: false);
      await _refreshTransactionDetails(); // Untuk update UI status jika masih di layar ini
      // Tidak langsung pop, biarkan user lihat status baru. Pop saat user tekan back.
      // Jika ingin langsung kembali ke list: Navigator.pop(context, true);
      // Karena payment screen yang akan melakukan pop(true), DebtDetailScreen ini
      // hanya perlu merefresh data lokalnya dan menghentikan loading.
      // Jika CashPaymentScreen/QrisDisplayScreen meng-pop DebtDetailScreen, maka kode ini mungkin tidak tereksekusi.

    } else {
      // Pembayaran dibatalkan atau gagal di layar pembayaran
      _showSnackbar("Pembayaran dibatalkan atau gagal.", isError: true);
    }

    // Selalu hentikan loading setelah semua proses selesai atau dibatalkan
    if(mounted){
      setState(() => _isProcessingPayment = false);
    }
  }

  Future<bool?> _navigateToCashPaymentForDebt() async {
    if (!mounted) return null;
    print("DebtDetailScreen: Navigating to CashPaymentScreen for Debt Payment");
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
    print("DebtDetailScreen: Returned from CashPaymentScreen with result: $result");
    // Jika result adalah true, artinya CashPaymentScreen sudah menghandle insert
    // transaksi pembayaran dan update status hutang asli.
    if (result == true && mounted) {
      // Navigator.pop(context, true); // Langsung pop DebtDetailScreen, CustomerDebtHistory akan refresh
      await _refreshTransactionDetails(); // Atau refresh dulu untuk update UI
      return true;
    }
    return result; // Atau result bisa null/false jika batal/gagal
  }

  Future<bool?> _navigateToQrisPaymentForDebt() async {
    if (!mounted) return null;
    print("DebtDetailScreen: Navigating to QrisDisplayScreen for Debt Payment");
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
    print("DebtDetailScreen: Returned from QrisDisplayScreen with result: $result");
    if (result == true && mounted) {
      // Navigator.pop(context, true); // Langsung pop DebtDetailScreen
      await _refreshTransactionDetails();
      return true;
    }
    return result;
  }

  // Fungsi untuk memuat ulang detail transaksi dari DB
  Future<void> _refreshTransactionDetails() async {
    if (_currentTransaction.id == null || !mounted) return;
    try {
      final latestTransaction = await DatabaseHelper.instance.getTransactionById(_currentTransaction.id!);
      if (latestTransaction != null && mounted) {
        setState(() {
          _currentTransaction = latestTransaction;
        });
      }
    } catch (e) {
      print("Error refreshing transaction details: $e");
      if(mounted) _showSnackbar("Gagal memperbarui detail transaksi.", isError: true);
    }
  }


  @override
  Widget build(BuildContext context) {
    // Menambahkan PopScope agar bisa mengirim `true` saat pengguna back secara manual
    // setelah status hutang lunas
    return PopScope(
      canPop: !_isProcessingPayment, // Hanya bisa pop jika tidak sedang proses
      onPopInvoked: (didPop) {
        if (didPop) {
          // Jika pop terjadi karena tombol back sistem atau AppBar
          // dan status hutang sudah lunas (karena pembayaran dari layar Cash/QRIS)
          // maka pastikan untuk memberi tahu layar sebelumnya untuk refresh.
          // Di sini, asumsi terbaik adalah kita mengirim hasil _currentTransaction.statusPembayaran
          // atau sebuah flag boolean khusus yang menandakan ada perubahan status.
          // Namun, jika kita hanya pop(true) ketika ada pembayaran yang berhasil DILAKUKAN MELALUI layar ini,
          // maka skenario ini lebih kompleks.

          // Untuk saat ini, jika pop terjadi, dan ada potensi status berubah
          // dari pembayaran yang berhasil DILAKUKAN DI Cash/QRIS Screen yang kemudian
          // di-pop lagi ke CustomerDebtHistoryScreen:
          // Kita hanya perlu pastikan `Navigator.pop(context, true)` di atas dieksekusi.

          // Sederhananya, CustomerDebtHistoryScreen yang akan load ulang saat kembali dari sini
          // tidak peduli DebtDetailScreen di-pop oleh apa.

          // Jika mau lebih spesifik, Anda bisa memodifikasi Navigator.pop() di AppBar's back button.
          // Tapi PopScope dengan then di CustomerDebtHistoryScreen sudah cukup.
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Detail Hutang', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _primaryColor)),
          backgroundColor: _lightBgColor,
          foregroundColor: _primaryColor,
          elevation: 2.5,
          shadowColor: Colors.black26,
          surfaceTintColor: _lightBgColor,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _isProcessingPayment ? null : () {
              // Pop dengan 'true' jika status lunas, agar CustomerDebtHistoryScreen tahu untuk refresh.
              // Jika belum lunas, pop biasa saja (defaultnya false/null)
              Navigator.pop(context, _currentTransaction.statusPembayaran == 'Lunas');
            }
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.receipt_long_outlined),
              tooltip: 'Lihat Struk Asli',
              onPressed: _isProcessingPayment ? null : () {
                if (_currentTransaction.id != null) {
                   Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ReceiptScreen(
                                transactionId: _currentTransaction.id!,
                                userId: widget.userId,
                              )));
                } else {
                   _showSnackbar("ID transaksi tidak valid untuk melihat struk.", isError: true);
                }
              },
            )
          ],
        ),
        backgroundColor: _scaffoldBgColor,
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Pelanggan:", style: GoogleFonts.poppins(fontSize: 14, color: _greyTextColor)),
              Text(widget.customerName, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: _darkTextColor)),
              const SizedBox(height: 20),
              Text("Detail Transaksi Hutang:", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: _darkTextColor)),
              const SizedBox(height: 10),
              Card(
                elevation: 1.5,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: _lightBgColor,
                surfaceTintColor: _lightBgColor,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildDetailRow("ID Transaksi:", "#${_currentTransaction.id ?? 'N/A'}"),
                      _buildDetailRow("Tanggal Hutang:", _dateTimeFormatter.format(_currentTransaction.tanggalTransaksi)),
                      _buildDetailRow("Metode Asal:", _currentTransaction.metodePembayaran),
                      _buildDetailRow("Status:", _currentTransaction.statusPembayaran,
                          valueStyle: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _currentTransaction.statusPembayaran == 'Lunas' ? _successColor : _warningColor)),
                      const Divider(height: 25, thickness: 0.8),
                      _buildDetailRow("Total Hutang:", currencyFormatter.format(_currentTransaction.totalBelanja), isTotal: true),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (_currentTransaction.statusPembayaran == 'Belum Lunas')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: _isProcessingPayment
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : const Icon(Icons.payment, size: 20),
                    label: Text(_isProcessingPayment ? "Memproses..." : "Bayar Kredit Ini",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
                    onPressed: _isProcessingPayment ? null : _showPaymentMethodSheet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor, // Tombol bayar tetap biru
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2.0,
                    ),
                  ),
                )
              else
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: Text("Hutang ini sudah lunas.", style: GoogleFonts.poppins(color: _successColor, fontWeight: FontWeight.w500, fontSize: 15)),
                  ),
                ),
              SizedBox(height: MediaQuery.of(context).padding.bottom > 0 ? 10 : 20), // Jarak bawah dengan mempertimbangkan safe area
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isTotal = false, TextStyle? valueStyle}) {
    final labelStyle = GoogleFonts.poppins(fontSize: 14, color: _greyTextColor);
    final finalValueStyle = valueStyle ?? GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: _darkTextColor);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: labelStyle),
          const SizedBox(width: 10),
          Expanded(
            child: Text(value, style: finalValueStyle, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}