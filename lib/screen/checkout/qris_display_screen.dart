// screen/checkout/qris_display_screen.dart
import 'package:crclib/catalog.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // Untuk utf8.encode
import 'package:aplikasir_mobile/helper/db_helper.dart';
import 'package:aplikasir_mobile/model/transaction_model.dart';
import 'checkout_success_screen.dart';
import 'package:aplikasir_mobile/model/product_model.dart'; // Diperlukan jika update stok di sini

class QrisDisplayScreen extends StatefulWidget {
  final double totalAmount;
  final int userId;
  // Data keranjang diperlukan JIKA update stok dilakukan SETELAH konfirmasi di sini
  // Atau jika ingin menampilkan item di struk pembayaran hutang
  final Map<int, int> cartQuantities;
  final List<Product> cartProducts;
  final int? transactionIdToUpdate; // ID Hutang yang akan dibayar (opsional)

  const QrisDisplayScreen({
    super.key,
    required this.totalAmount,
    required this.userId,
    required this.cartQuantities,
    required this.cartProducts,
    this.transactionIdToUpdate, // Terima ID hutang
  });

  @override
  State<QrisDisplayScreen> createState() => _QrisDisplayScreenState();
}

class _QrisDisplayScreenState extends State<QrisDisplayScreen> {
  final NumberFormat currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final Color _primaryColor = Colors.blue.shade700;

  String? _rawQrisTemplate;
  String? qrData; // Payload QRIS dinamis
  bool _isQrisLoading = true;
  String? _qrisError;
  bool _isProcessing = false; // Loading untuk simpan transaksi

  static const String qrisDataKey = 'raw_qris_data';

  @override
  void initState() {
    super.initState();
    _initializeAndGenerateQris();
  }

  Future<void> _initializeAndGenerateQris() async {
    if (!mounted) return;
    setState(() {
      _isQrisLoading = true;
      _qrisError = null;
      qrData = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      _rawQrisTemplate = prefs.getString(qrisDataKey);
      if (_rawQrisTemplate == null || _rawQrisTemplate!.isEmpty) {
        throw Exception("Data QRIS belum diatur.");
      }
      print("Loaded QRIS Template: $_rawQrisTemplate");
      _generateDynamicQrisDataFromStringManipulation();
    } catch (e) {
      print("Error initializing/generating QRIS: $e");
      if (mounted) {
        setState(() {
          _qrisError = e.toString().replaceFirst("Exception: ", "");
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isQrisLoading = false);
      }
    }
  }

  // --- Fungsi Generate QRIS Dinamis (Adaptasi PHP + crclib) ---
  void _generateDynamicQrisDataFromStringManipulation() {
    if (_rawQrisTemplate == null) {
      if (mounted)
        setState(() => _qrisError = "Template QRIS tidak ditemukan.");
      return;
    }
    try {
      print("Starting dynamic QRIS generation (PHP logic adaptation)...");
      if (_rawQrisTemplate!.length <= 4)
        throw Exception("Template QRIS tidak valid.");
      String qrisWithoutCrc =
          _rawQrisTemplate!.substring(0, _rawQrisTemplate!.length - 4);
      String payloadStep1 = qrisWithoutCrc.replaceFirst('010211', '010212');
      if (!payloadStep1.contains('010212'))
        print("  WARNING: '010211' not found.");
      else
        print("  2. Replaced '010211' with '010212'.");
      const String countryCodeTag = '58';
      int insertPos = payloadStep1.indexOf(countryCodeTag);
      if (insertPos == -1 ||
          insertPos % 2 != 0 ||
          payloadStep1.length < insertPos + 4) {
        print("  INFO: Tag '58' not found/invalid. Searching for Tag '59'...");
        const String merchantNameTag = '59';
        insertPos = payloadStep1.indexOf(merchantNameTag);
        if (insertPos == -1 ||
            insertPos % 2 != 0 ||
            payloadStep1.length < insertPos + 4) {
          throw Exception("Tag 58/59 tidak ditemukan/valid.");
        }
        print("  3. Found insertion marker tag '59' at index $insertPos.");
      } else {
        print("  3. Found insertion marker tag '58' at index $insertPos.");
      }
      String amountValue = widget.totalAmount.toInt().toString();
      if (amountValue.isEmpty || widget.totalAmount < 0) amountValue = '0';
      String amountLength = amountValue.length.toString().padLeft(2, '0');
      String amountTag = '54$amountLength$amountValue';
      print("  4. Formatted Amount Tag '54': $amountTag");
      String payloadBeforeCrc = payloadStep1.substring(0, insertPos) +
          amountTag +
          payloadStep1.substring(insertPos);
      print("  5. Payload before CRC calculation: $payloadBeforeCrc");
      List<int> bytes = utf8.encode(payloadBeforeCrc);
      var crcCalculator = Crc16();
      var crcValue = crcCalculator.convert(bytes);
      String crcString =
          crcValue.toRadixString(16).toUpperCase().padLeft(4, '0');
      print("  6. Calculated CRC (Hex): $crcString");
      final String finalPayload = payloadBeforeCrc + '6304' + crcString;
      print("  7. Final Dynamic Payload: $finalPayload");
      if (mounted) {
        setState(() {
          qrData = finalPayload;
          _qrisError = null;
        });
      }
    } catch (e) {
      print("Error generating dynamic QRIS payload: $e");
      if (mounted) {
        setState(() {
          _qrisError =
              "Gagal memproses QRIS: ${e.toString().replaceFirst("Exception: ", "")}";
          qrData = null;
        });
      }
    }
  }

  // --- Fungsi _showSnackbar (Sama) ---
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

  // --- Fungsi Konfirmasi Pembayaran (Kembali ke flow asli) ---
  Future<void> _confirmManualPayment() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });

    try {
      // Tentukan apakah ini pembayaran hutang atau checkout biasa
      bool isDebtPayment = widget.transactionIdToUpdate != null;

      // Buat Detail Items
      List<Map<String, dynamic>> detailItems = [];
      double totalModal = 0;
      if (!isDebtPayment) {
        // Jika checkout biasa, ambil dari cart
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
        // Jika pembayaran hutang
        detailItems = [
          {
            'paid_debt_transaction_id': widget.transactionIdToUpdate,
            'paid_amount': widget.totalAmount
          }
        ];
        totalModal = 0; // Tidak ada modal untuk bayar hutang
      }

      // Buat Transaksi Pembayaran QRIS
      final transaction = TransactionModel(
        idPengguna: widget.userId,
        tanggalTransaksi: DateTime.now(),
        totalBelanja: widget.totalAmount, // Jumlah yg dibayar
        totalModal: totalModal,
        metodePembayaran: isDebtPayment
            ? 'Pembayaran Kredit QRIS'
            : 'QRIS', // Bedakan metodenya
        statusPembayaran: 'Lunas',
        idPelanggan: null, // Tidak relevan untuk pembayaran ini
        detailItems: detailItems,
        jumlahBayar: widget.totalAmount, // Untuk QRIS, bayar = total
        jumlahKembali: 0,
        idTransaksiHutang:
            widget.transactionIdToUpdate, // Akan null jika bukan bayar hutang
      );

      // Simpan Transaksi Pembayaran
      final transactionId =
          await DatabaseHelper.instance.insertTransaction(transaction);
      print(
          "QRIS Payment Transaction saved: ID $transactionId (DebtPayment: $isDebtPayment)");

      // Jika ini adalah pembayaran hutang, pop dulu dengan hasil true
      if (isDebtPayment) {
        if (mounted) {
          print("Popping QrisDisplayScreen with true (debt paid)");
          Navigator.pop(
              context, true); // <-- Kirim sinyal sukses ke DebtDetailScreen
        }
        // Hentikan eksekusi di sini untuk pembayaran hutang
        return;
      }

      // Update Stok HANYA jika checkout biasa
      if (!isDebtPayment) {
        try {
          for (var item in detailItems) {
            await DatabaseHelper.instance
                .updateProductStock(item['product_id'], item['quantity']);
            print(
                "Stock updated: ID ${item['product_id']}, Qty: -${item['quantity']}");
          }
        } catch (stockError) {
          print("Stock update error for Tx $transactionId: $stockError");
          if (mounted)
            _showSnackbar("Gagal update stok! Tx $transactionId perlu dicek.",
                isError: true);
          setState(() => _isProcessing = false);
          return;
        }
      }

      // Navigasi ke Success Screen (sebagai pengganti pop(true))
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CheckoutSuccessScreen(
            transactionId: transactionId, // Kirim ID transaksi PEMBAYARAN
            userId: widget.userId,
            paymentMethod: isDebtPayment
                ? 'Pembayaran Kredit QRIS'
                : 'QRIS', // Kirim metode yg benar
            changeAmount: null,
          ),
        ),
      );
    } catch (e, stacktrace) {
      print("Error processing QRIS confirmation: $e\n$stacktrace");
      if (mounted) {
        _showSnackbar("Terjadi kesalahan: ${e.toString()}", isError: true);
        setState(() => _isProcessing = false);
      }
    }
    // State loading tidak direset jika navigasi sukses
  }

  @override
  Widget build(BuildContext context) {
    // ... (Widget build sama seperti jawaban sebelumnya, menampilkan loading/error/QR) ...
    // Tombol konfirmasi tetap memanggil _confirmManualPayment
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
            Text(
              "Scan QR Code Berikut",
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              "Total Pembayaran: ${currencyFormatter.format(widget.totalAmount)}",
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: _primaryColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 15),
            Text(
              "(Aplikasi pembayaran akan otomatis mendeteksi jumlah ini)",
              style: GoogleFonts.poppins(
                  fontSize: 11, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              height: 250,
              width: 250,
              alignment: Alignment.center,
              child: _isQrisLoading
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 15),
                        Text("Memuat QRIS...")
                      ],
                    )
                  : _qrisError != null
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
                              Text(
                                _qrisError!,
                                style: GoogleFonts.poppins(
                                    color: Colors.red.shade800, fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ))
                      : qrData != null
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
                                      offset: const Offset(0, 2),
                                    )
                                  ]),
                              child: QrImageView(
                                data: qrData!,
                                version: QrVersions.auto,
                                size: 220.0,
                                gapless: false,
                                errorCorrectionLevel: QrErrorCorrectLevel.M,
                                errorStateBuilder: (cxt, err) {
                                  return Center(
                                    child: Text(
                                      "Gagal membuat gambar QR Code.",
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(
                                          color: Colors.red),
                                    ),
                                  );
                                },
                              ),
                            )
                          : Center(
                              child: Text("Gagal memuat data QRIS.",
                                  style: GoogleFonts.poppins(
                                      color: Colors.orange.shade800)),
                            ),
            ),
            const SizedBox(height: 30),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                    _isProcessing
                        ? "Memproses..."
                        : "Pembayaran Diterima (Manual)",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                onPressed: _isQrisLoading || _qrisError != null || _isProcessing
                    ? null
                    : _confirmManualPayment,
                style: ElevatedButton.styleFrom(
                    backgroundColor: (_isQrisLoading || _qrisError != null)
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
                onPressed:
                    _isProcessing ? null : () => Navigator.pop(context, false),
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
