// screen/checkout/cash_payment_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:aplikasir_mobile/model/product_model.dart';
import 'package:aplikasir_mobile/model/transaction_model.dart';
import 'package:aplikasir_mobile/helper/db_helper.dart';
import 'widgets/numpad_widget.dart';
import 'checkout_success_screen.dart';

class CashPaymentScreen extends StatefulWidget {
  final double totalAmount;
  final int userId;
  final Map<int, int> cartQuantities;
  final List<Product> cartProducts;
  final int? transactionIdToUpdate; // ID Hutang yang akan dibayar (opsional)

  const CashPaymentScreen({
    super.key,
    required this.totalAmount,
    required this.userId,
    required this.cartQuantities,
    required this.cartProducts,
    this.transactionIdToUpdate, // Terima ID hutang
  });

  @override
  State<CashPaymentScreen> createState() => _CashPaymentScreenState();
}

class _CashPaymentScreenState extends State<CashPaymentScreen>
    with TickerProviderStateMixin {
  // ... (State, formatter, color, controller, overlay, notifikasi, numpad handlers, calculateTotalModal SAMA) ...
  final NumberFormat currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final Color _primaryColor = Colors.blue.shade700;
  final Color _darkTextColor = Colors.black87;
  final Color _greyTextColor = Colors.grey.shade600;
  String _enteredAmountString = '';
  double _enteredAmount = 0.0;
  double _changeAmount = 0.0;
  bool _isProcessing = false;
  OverlayEntry? _overlayEntry;
  AnimationController? _overlayAnimationController;
  final GlobalKey _scaffoldBodyKey = GlobalKey();
  @override
  void initState() {
    super.initState();
    print("CashPaymentScreen initState called");
  }

  @override
  void dispose() {
    _removeOverlay();
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
    final RenderBox? bodyBox =
        _scaffoldBodyKey.currentContext?.findRenderObject() as RenderBox?;
    double topLimit = MediaQuery.of(context).padding.top + kToolbarHeight + 10;
    double targetTop = 150;
    if (bodyBox != null && bodyBox.hasSize) {
      targetTop = topLimit + 30;
    }
    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: targetTop,
          left: 16.0,
          right: 16.0,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -1.5),
              end: Offset.zero,
            ).animate(CurvedAnimation(
                parent: _overlayAnimationController!, curve: Curves.easeOut)),
            child: Material(
              elevation: 4.0,
              borderRadius: BorderRadius.circular(8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 14.0),
                decoration: BoxDecoration(
                    color: isError
                        ? Colors.redAccent.shade100
                        : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                        color: isError
                            ? Colors.redAccent.shade400
                            : Colors.orange.shade700,
                        width: 1)),
                child: Text(
                  message,
                  style: GoogleFonts.poppins(
                      color: isError
                          ? Colors.red.shade900
                          : Colors.orange.shade900,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_overlayEntry!);
    _overlayAnimationController?.forward();
    Future.delayed(duration, _removeOverlay);
  }

  void _removeOverlay() {
    _overlayAnimationController?.reverse().then((_) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      _overlayAnimationController?.dispose();
      _overlayAnimationController = null;
    }).catchError((e) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      _overlayAnimationController?.dispose();
      _overlayAnimationController = null;
    });
  }

  void _onNumpadKeyPress(String value) {
    if (_enteredAmountString.length < 12) {
      setState(() {
        _enteredAmountString += value;
        _updateAmounts();
      });
    }
  }

  void _onNumpadBackspace() {
    if (_enteredAmountString.isNotEmpty) {
      setState(() {
        _enteredAmountString =
            _enteredAmountString.substring(0, _enteredAmountString.length - 1);
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
      _changeAmount = 0.0;
    }
    if (_enteredAmount >= widget.totalAmount) {
      _removeOverlay();
    }
  }

  // --- Fungsi Konfirmasi Pembayaran (Kembali ke Flow Asli) ---
  Future<void> _confirmPayment() async {
    if (_isProcessing) return;
    if (_enteredAmount < widget.totalAmount) {
      _showCustomNotificationWidget('Jumlah uang yang dibayarkan kurang!');
      return;
    }
    setState(() {
      _isProcessing = true;
    });

    try {
      // Tentukan apakah ini pembayaran hutang
      bool isDebtPayment = widget.transactionIdToUpdate != null;

      // Buat Detail Items (atau placeholder jika bayar hutang)
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
            'paid_amount': widget.totalAmount,
            'received_amount': _enteredAmount,
            'change_amount': _changeAmount,
          }
        ];
        totalModal = 0;
      }

      // Buat Transaksi Pembayaran Tunai
      final transaction = TransactionModel(
        idPengguna: widget.userId,
        tanggalTransaksi: DateTime.now(),
        totalBelanja: _enteredAmount, // Jumlah uang yg diterima
        totalModal: totalModal,
        metodePembayaran: isDebtPayment
            ? 'Pembayaran Kredit Tunai'
            : 'Tunai', // Bedakan metode
        statusPembayaran: 'Lunas',
        idPelanggan: null,
        detailItems: detailItems,
        jumlahBayar: _enteredAmount,
        jumlahKembali: _changeAmount,
        idTransaksiHutang: widget.transactionIdToUpdate,
      );

      // Simpan Transaksi Pembayaran
      final transactionId =
          await DatabaseHelper.instance.insertTransaction(transaction);
      print(
          "Cash Payment Transaction saved: ID $transactionId (DebtPayment: $isDebtPayment)");

      // --- PERUBAHAN DI SINI ---
      // Jika ini adalah pembayaran hutang, pop dulu dengan hasil true
      if (isDebtPayment) {
        if (mounted) {
          print("Popping CashPaymentScreen with true (debt paid)");
          Navigator.pop(
              context, true); // <-- Kirim sinyal sukses ke DebtDetailScreen
        }
        // Hentikan eksekusi di sini untuk pembayaran hutang,
        // tidak perlu navigasi ke Success Screen dari sini.
        return;
      }
      // --- AKHIR PERUBAHAN --

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

      // Navigasi ke Success Screen (Selalu)
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CheckoutSuccessScreen(
            transactionId: transactionId,
            userId: widget.userId,
            paymentMethod: isDebtPayment
                ? 'Pembayaran Kredit Tunai'
                : 'Tunai', // Kirim metode yg benar
            changeAmount: _changeAmount,
          ),
        ),
      );
    } catch (e, stacktrace) {
      print("Error processing cash payment: $e\n$stacktrace");
      if (mounted) {
        _showSnackbar("Terjadi kesalahan: ${e.toString()}", isError: true);
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (Widget build SAMA seperti sebelumnya) ...
    print("CashPaymentScreen build method called");
    bool canConfirm = _enteredAmount >= widget.totalAmount && !_isProcessing;
    return Scaffold(
      key: _scaffoldBodyKey,
      appBar: AppBar(
        title: Text('Pembayaran Tunai',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: _primaryColor)),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.grey.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 4))
                ]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total yang Harus Dibayar',
                    style: GoogleFonts.poppins(
                        fontSize: 15, color: _greyTextColor)),
                const SizedBox(height: 5),
                Text(currencyFormatter.format(widget.totalAmount),
                    style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor)),
                const SizedBox(height: 25),
                Text('Uang Diterima',
                    style: GoogleFonts.poppins(
                        fontSize: 15, color: _greyTextColor)),
                const SizedBox(height: 5),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                      border: Border(
                          bottom:
                              BorderSide(color: _darkTextColor, width: 1.5))),
                  child: Text(
                    _enteredAmountString.isEmpty
                        ? 'Rp 0'
                        : currencyFormatter.format(_enteredAmount),
                    style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: _darkTextColor),
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
          Container(
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, 16 + MediaQuery.of(context).padding.bottom * 0.5),
            decoration: const BoxDecoration(
                color: Colors.white,
                border:
                    Border(top: BorderSide(color: Colors.black12, width: 0.8))),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      canConfirm ? Colors.green.shade600 : Colors.grey.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: canConfirm ? _confirmPayment : null,
                child: Text(
                  _isProcessing ? 'Memproses...' : 'Konfirmasi Pembayaran',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
