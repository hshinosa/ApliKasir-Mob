// lib/features/checkout/screens/cash_payment_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:aplikasir_mobile/model/product_model.dart';
import 'package:aplikasir_mobile/model/transaction_model.dart';
import 'package:aplikasir_mobile/helper/db_helper.dart';
import '../widgets/numpad_widget.dart'; // Sesuaikan path jika perlu
import 'checkout_success_screen.dart';

class CashPaymentScreen extends StatefulWidget {
  final double totalAmount;
  final int userId;
  final Map<int, int> cartQuantities; // Untuk checkout biasa
  final List<Product> cartProducts;   // Untuk checkout biasa
  final int? transactionIdToUpdate; // ID Hutang yang akan dibayar (opsional)

  const CashPaymentScreen({
    super.key,
    required this.totalAmount,
    required this.userId,
    required this.cartQuantities, // Tetap ada, bisa kosong jika bayar hutang
    required this.cartProducts,   // Tetap ada, bisa kosong jika bayar hutang
    this.transactionIdToUpdate,
  });

  @override
  State<CashPaymentScreen> createState() => _CashPaymentScreenState();
}

class _CashPaymentScreenState extends State<CashPaymentScreen> with TickerProviderStateMixin {
  final NumberFormat currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final Color _primaryColor = Colors.blue.shade700;
  final Color _darkTextColor = Colors.black87;
  final Color _greyTextColor = Colors.grey.shade600;

  String _enteredAmountString = '';
  double _enteredAmount = 0.0;
  double _changeAmount = 0.0;
  bool _isProcessing = false;

  // Untuk notifikasi kustom
  OverlayEntry? _overlayEntry;
  AnimationController? _overlayAnimationController;
  final GlobalKey _scaffoldBodyKey = GlobalKey();


  @override
  void initState() {
    super.initState();
    // Inisialisasi animation controller jika diperlukan untuk notifikasi
  }

  @override
  void dispose() {
    _removeOverlay(); // Hapus overlay jika ada
    _overlayAnimationController?.dispose();
    super.dispose();
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

  void _showCustomNotificationWidget(String message,
      {bool isError = true, Duration duration = const Duration(seconds: 3)}) {
    _removeOverlay();
    _overlayAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    final overlay = Overlay.of(context);
    final RenderBox? bodyBox = _scaffoldBodyKey.currentContext?.findRenderObject() as RenderBox?;
    double topLimit = MediaQuery.of(context).padding.top + kToolbarHeight + 10;
    double targetTop = 150; // Default
    if (bodyBox != null && bodyBox.hasSize) {
      targetTop = topLimit + 30; // Sesuaikan posisi Y di bawah AppBar
    }

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: targetTop,
          left: 16.0,
          right: 16.0,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -1.5), // Mulai dari atas
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: _overlayAnimationController!, curve: Curves.easeOut)),
            child: Material(
              elevation: 4.0,
              borderRadius: BorderRadius.circular(8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                decoration: BoxDecoration(
                    color: isError ? Colors.redAccent.shade100 : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                        color: isError ? Colors.redAccent.shade400 : Colors.orange.shade700,
                        width: 1)),
                child: Text(
                  message,
                  style: GoogleFonts.poppins(
                      color: isError ? Colors.red.shade900 : Colors.orange.shade900,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_overlayEntry!);
    _overlayAnimationController?.forward(); // Mulai animasi
    Future.delayed(duration, _removeOverlay);
  }

  void _removeOverlay() {
    _overlayAnimationController?.reverse().then((_) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      // _overlayAnimationController?.dispose(); // Jangan dispose jika akan dipakai lagi di screen yg sama
      // _overlayAnimationController = null;
    }).catchError((e) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      // _overlayAnimationController?.dispose();
      // _overlayAnimationController = null;
    });
  }


  void _onNumpadKeyPress(String value) {
    if (_enteredAmountString.length < 12) { // Batasi panjang input
      setState(() {
        _enteredAmountString += value;
        _updateAmounts();
      });
    }
  }

  void _onNumpadBackspace() {
    if (_enteredAmountString.isNotEmpty) {
      setState(() {
        _enteredAmountString = _enteredAmountString.substring(0, _enteredAmountString.length - 1);
        _updateAmounts();
      });
    }
  }

  void _onNumpadClear() {
    setState(() {
      _enteredAmountString = '';
      _updateAmounts();
    });
  }

  void _updateAmounts() {
    _enteredAmount = double.tryParse(_enteredAmountString) ?? 0.0;
    if (_enteredAmount >= widget.totalAmount) {
      _changeAmount = _enteredAmount - widget.totalAmount;
    } else {
      _changeAmount = 0.0; // Tidak ada kembalian jika kurang
    }
     // Jika uang pas atau lebih, hilangkan notifikasi "uang kurang"
    if (_enteredAmount >= widget.totalAmount) {
      _removeOverlay();
    }
  }

  Future<void> _confirmPayment() async {
    if (_isProcessing) return;
    if (_enteredAmount < widget.totalAmount) {
      _showCustomNotificationWidget('Jumlah uang yang dibayarkan kurang!');
      return;
    }
    setState(() => _isProcessing = true);

    try {
      bool isDebtPayment = widget.transactionIdToUpdate != null;
      List<Map<String, dynamic>> detailItems = [];
      double totalModal = 0;

      if (!isDebtPayment) { // Checkout biasa
        widget.cartProducts.forEach((product) {
          final quantity = widget.cartQuantities[product.id] ?? 0;
          if (quantity > 0) {
            detailItems.add({
              'product_id': product.id, // Gunakan ID LOKAL produk
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
      } else { // Pembayaran hutang
        detailItems = [{
            'paid_debt_transaction_id': widget.transactionIdToUpdate,
            'paid_amount': widget.totalAmount, // Jumlah hutang yg dibayar
            'received_amount': _enteredAmount, // Uang yang diterima
            'change_amount': _changeAmount,    // Kembalian
        }];
        totalModal = 0; // Tidak ada modal untuk pembayaran hutang
      }

      final transaction = TransactionModel(
        idPengguna: widget.userId,
        tanggalTransaksi: DateTime.now(),
        totalBelanja: isDebtPayment ? widget.totalAmount : _enteredAmount, // Untuk bayar hutang, totalBelanja = jumlah hutang
        totalModal: totalModal,
        metodePembayaran: isDebtPayment ? 'Pembayaran Kredit Tunai' : 'Tunai',
        statusPembayaran: 'Lunas',
        idPelanggan: null, // Diisi oleh transaksi hutang asli jika ada
        detailItems: detailItems,
        jumlahBayar: _enteredAmount,
        jumlahKembali: _changeAmount,
        idTransaksiHutang: widget.transactionIdToUpdate,
      );

      final transactionId = await DatabaseHelper.instance.insertTransaction(transaction);

      // Jika ini adalah pembayaran hutang, pop dengan hasil true
      if (isDebtPayment) {
        if (mounted) {
          Navigator.pop(context, true); // Sinyal sukses ke DebtDetailScreen
        }
        return;
      }

      // Jika checkout biasa, update stok dan navigasi ke success screen
      if (!isDebtPayment) {
          for (var item in detailItems) {
            await DatabaseHelper.instance.updateProductStock(item['product_id'], item['quantity']);
          }
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CheckoutSuccessScreen(
            transactionId: transactionId,
            userId: widget.userId,
            paymentMethod: 'Tunai', // atau metode pembayaran yang sesuai
            changeAmount: _changeAmount,
          ),
        ),
      );
    } catch (e) {
      print("Error processing cash payment: $e");
      if (mounted) {
        _showSnackbar("Terjadi kesalahan: ${e.toString()}", isError: true);
        setState(() => _isProcessing = false);
      }
    }
    // Tidak perlu reset _isProcessing di sini jika navigasi sukses
  }

  @override
  Widget build(BuildContext context) {
    bool canConfirm = _enteredAmount >= widget.totalAmount && !_isProcessing;

    return Scaffold(
      key: _scaffoldBodyKey,
      appBar: AppBar(
        title: Text('Pembayaran Tunai', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _primaryColor)),
        backgroundColor: Colors.white,
        foregroundColor: _primaryColor,
        elevation: 0.5,
        shadowColor: Colors.black26,
        surfaceTintColor: Colors.white,
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF7F8FC),
      body: Column(
        children: [
          Container( // Card Informasi Total & Uang Diterima
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4))]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total yang Harus Dibayar', style: GoogleFonts.poppins(fontSize: 15, color: _greyTextColor)),
                const SizedBox(height: 5),
                Text(currencyFormatter.format(widget.totalAmount), style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: _primaryColor)),
                const SizedBox(height: 25),
                Text('Uang Diterima', style: GoogleFonts.poppins(fontSize: 15, color: _greyTextColor)),
                const SizedBox(height: 5),
                Container( // Display Uang Diterima
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _darkTextColor, width: 1.5))),
                  child: Text(
                    _enteredAmountString.isEmpty ? 'Rp 0' : currencyFormatter.format(_enteredAmount),
                    style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: _darkTextColor),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: NumpadWidget(
                onKeyPressed: _onNumpadKeyPress,
                onBackspacePressed: _onNumpadBackspace,
                onClearPressed: _onNumpadClear,
              ),
            ),
          ),
          Container( // Tombol Konfirmasi
            padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.of(context).padding.bottom * 0.5),
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.black12, width: 0.8))),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: canConfirm ? Colors.green.shade600 : Colors.grey.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: canConfirm ? _confirmPayment : null,
                child: Text(
                  _isProcessing ? 'Memproses...' : 'Konfirmasi Pembayaran',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}