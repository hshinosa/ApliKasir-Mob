// lib/fitur/checkout/screens/qris_display_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart'; // Impor Provider

import 'package:aplikasir_mobile/helper/db_helper.dart';
import 'package:aplikasir_mobile/model/transaction_model.dart';
import 'package:aplikasir_mobile/model/product_model.dart';
import 'package:aplikasir_mobile/fitur/manage/qris/providers/qris_provider.dart'; // Impor QrisProvider
import 'checkout_success_screen.dart';

class QrisDisplayScreen extends StatelessWidget {
  // Ubah jadi StatelessWidget
  final double totalAmount;
  final int userId;
  final Map<int, int> cartQuantities;
  final List<Product> cartProducts;
  final int? transactionIdToUpdate;

  const QrisDisplayScreen({
    super.key,
    required this.totalAmount,
    required this.userId,
    required this.cartQuantities,
    required this.cartProducts,
    this.transactionIdToUpdate,
  });

  @override
  Widget build(BuildContext context) {
    // Sediakan QrisProvider di sini, khusus untuk screen ini
    // Ini memastikan QrisDisplayScreen bisa mendapatkan template dan generate QR
    // tanpa bergantung pada state dari QrisSetupScreen.
    return ChangeNotifierProvider(
      // userId mungkin tidak krusial untuk QrisProvider di sini jika hanya untuk generate
      create: (_) => QrisProvider(userId: userId),
      child: _QrisDisplayScreenContent(
        totalAmount: totalAmount,
        userId: userId,
        cartQuantities: cartQuantities,
        cartProducts: cartProducts,
        transactionIdToUpdate: transactionIdToUpdate,
      ),
    );
  }
}

class _QrisDisplayScreenContent extends StatefulWidget {
  final double totalAmount;
  final int userId;
  final Map<int, int> cartQuantities;
  final List<Product> cartProducts;
  final int? transactionIdToUpdate;

  const _QrisDisplayScreenContent({
    required this.totalAmount,
    required this.userId,
    required this.cartQuantities,
    required this.cartProducts,
    this.transactionIdToUpdate,
  });

  @override
  State<_QrisDisplayScreenContent> createState() =>
      _QrisDisplayScreenContentState();
}

class _QrisDisplayScreenContentState extends State<_QrisDisplayScreenContent> {
  final NumberFormat currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final Color _primaryColor = Colors.blue.shade700;

  String? _generatedQrDataPayload; // Hasil QR dinamis
  bool _isQrGenerationLoading = true; // Loading untuk generate QR
  String? _qrGenerationError;

  bool _isProcessingPayment = false; // Loading untuk simpan transaksi

  @override
  void initState() {
    super.initState();
    // Panggil provider untuk memuat template dan generate QR dinamis
    // Kita lakukan ini di didChangeDependencies atau setelah frame pertama agar provider terinisialisasi
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateDynamicQr();
    });
  }

  Future<void> _generateDynamicQr() async {
    if (!mounted) return;
    setState(() {
      _isQrGenerationLoading = true;
      _qrGenerationError = null;
      _generatedQrDataPayload = null;
    });

    final qrisProvider = context.read<QrisProvider>();
    // Pastikan template sudah dimuat oleh provider
    if (qrisProvider.rawQrisTemplate == null && !qrisProvider.isLoading) {
      // Jika belum ada, coba load (meskipun provider sudah melakukannya di init)
      await qrisProvider.loadSavedQrisTemplate();
    }

    if (qrisProvider.rawQrisTemplate == null) {
      if (mounted) {
        setState(() {
          _qrGenerationError =
              "Template QRIS belum diatur. Silakan atur di menu Kelola > QRIS.";
          _isQrGenerationLoading = false;
        });
      }
      return;
    }

    final dynamicQr =
        qrisProvider.generateDynamicQrisForDisplay(widget.totalAmount);

    if (mounted) {
      setState(() {
        if (dynamicQr != null) {
          _generatedQrDataPayload = dynamicQr;
          _qrGenerationError = null;
        } else {
          _generatedQrDataPayload = null;
          _qrGenerationError = qrisProvider.errorMessage ??
              "Gagal menghasilkan kode QRIS dinamis.";
        }
        _isQrGenerationLoading = false;
      });
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _confirmManualPayment() async {
    if (_isProcessingPayment) return;
    setState(() => _isProcessingPayment = true);

    try {
      bool isDebtPayment = widget.transactionIdToUpdate != null;
      List<Map<String, dynamic>> detailItems = [];
      double totalModal = 0;

      if (!isDebtPayment) {
        widget.cartProducts.forEach((product) {
          final quantity = widget.cartQuantities[product.id] ?? 0;
          if (quantity > 0) {
            detailItems.add({
              'product_id': product.id,
              'nama_produk': product.namaProduk,
              'kode_produk': product.kodeProduk,
              'harga_jual': product.hargaJual,
              'harga_modal': product.hargaModal,
              'quantity': quantity,
              'subtotal': product.hargaJual * quantity,
            });
            totalModal += product.hargaModal * quantity;
          }
        });
      } else {
        detailItems = [
          {
            'paid_debt_transaction_id': widget.transactionIdToUpdate,
            'paid_amount': widget.totalAmount
          }
        ];
        totalModal = 0;
      }

      final transaction = TransactionModel(
        idPengguna: widget.userId, tanggalTransaksi: DateTime.now(),
        totalBelanja: widget.totalAmount, totalModal: totalModal,
        metodePembayaran: isDebtPayment ? 'Pembayaran Kredit QRIS' : 'QRIS',
        statusPembayaran: 'Lunas', idPelanggan: null, detailItems: detailItems,
        jumlahBayar: widget.totalAmount, jumlahKembali: 0,
        idTransaksiHutang: widget.transactionIdToUpdate,
        createdAt: DateTime.now(), // Tambahkan createdAt
        updatedAt: DateTime.now(), // Tambahkan updatedAt
        syncStatus: 'new', // Set status sinkronisasi
      );

      // Gunakan insertTransactionLocal dari DB Helper (provider sudah mengaturnya)
      final transactionId =
          await DatabaseHelper.instance.insertTransactionLocal(transaction);

      if (isDebtPayment) {
        if (mounted) Navigator.pop(context, true);
        return;
      }

      // Update stok produk jika bukan pembayaran hutang (logika ini bisa dipindah ke insertTransactionLocal jika lebih baik)
      // if (!isDebtPayment) {
      //      for (var item in detailItems) {
      //       await DatabaseHelper.instance.updateProductStock(item['product_id'], item['quantity']);
      //     }
      // }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CheckoutSuccessScreen(
            transactionId: transactionId,
            userId: widget.userId,
            paymentMethod: 'QRIS',
            changeAmount: null,
          ),
        ),
      );
    } catch (e) {
      print("Error processing QRIS confirmation: $e");
      if (mounted) {
        _showSnackbar("Terjadi kesalahan: ${e.toString()}", isError: true);
        setState(() => _isProcessingPayment = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tidak perlu watch provider di sini jika pemanggilan hanya di initState/didChangeDependencies
    // Kecuali jika ada UI yang bergantung pada perubahan state provider secara live.

    return Scaffold(
      appBar: AppBar(
        title: Text('Pembayaran QRIS',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: _primaryColor)),
        backgroundColor: Colors.white,
        foregroundColor: _primaryColor,
        elevation: 1.0,
        shadowColor: Colors.black26,
        surfaceTintColor: Colors.white,
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF7F8FC),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text("Scan QR Code Berikut",
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
                "Total Pembayaran: ${currencyFormatter.format(widget.totalAmount)}",
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: _primaryColor),
                textAlign: TextAlign.center),
            const SizedBox(height: 15),
            Text("(Aplikasi pembayaran akan otomatis mendeteksi jumlah ini)",
                style: GoogleFonts.poppins(
                    fontSize: 11, color: Colors.grey.shade600),
                textAlign: TextAlign.center),
            const SizedBox(height: 25),
            Container(
              height: 250,
              width: 250,
              alignment: Alignment.center,
              child: _isQrGenerationLoading
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 15),
                          Text("Memuat QRIS...")
                        ])
                  : _qrGenerationError != null
                      ? Container(
                          padding: const EdgeInsets.all(15.0),
                          decoration: BoxDecoration(
                              border: Border.all(color: Colors.red.shade200),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.red.shade50),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline,
                                    color: Colors.red.shade700, size: 40),
                                const SizedBox(height: 10),
                                Text(_qrGenerationError!,
                                    style: GoogleFonts.poppins(
                                        color: Colors.red.shade800,
                                        fontSize: 14),
                                    textAlign: TextAlign.center),
                              ]))
                      : _generatedQrDataPayload != null
                          ? Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.grey.withOpacity(0.3),
                                        spreadRadius: 1,
                                        blurRadius: 5,
                                        offset: const Offset(0, 2))
                                  ]),
                              child: QrImageView(
                                data: _generatedQrDataPayload!,
                                version: QrVersions.auto,
                                size: 220.0,
                                gapless: false,
                                errorCorrectionLevel: QrErrorCorrectLevel.M,
                                errorStateBuilder: (cxt, err) => Center(
                                    child: Text("Gagal membuat QR Code.",
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.poppins(
                                            color: Colors.red))),
                              ),
                            )
                          : Center(
                              child: Text(
                                  "Gagal memuat data QRIS untuk ditampilkan.",
                                  style: GoogleFonts.poppins(
                                      color: Colors.orange.shade800))),
            ),
            const SizedBox(height: 30),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isProcessingPayment
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                    _isProcessingPayment
                        ? "Memproses..."
                        : "Pembayaran Diterima (Manual)",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                onPressed: _isQrGenerationLoading ||
                        _qrGenerationError != null ||
                        _isProcessingPayment ||
                        _generatedQrDataPayload == null
                    ? null
                    : _confirmManualPayment,
                style: ElevatedButton.styleFrom(
                    backgroundColor: (_isQrGenerationLoading ||
                            _qrGenerationError != null ||
                            _generatedQrDataPayload == null)
                        ? Colors.grey
                        : Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                child: Text("Batal",
                    style: GoogleFonts.poppins(color: Colors.red.shade600)),
                onPressed: _isProcessingPayment
                    ? null
                    : () => Navigator.pop(context, false),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
