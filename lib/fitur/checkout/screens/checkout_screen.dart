// lib/features/checkout/screens/checkout_screen.dart
import 'package:aplikasir_mobile/fitur/checkout/providers/checkout_providers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart'; // Import Provider
import 'package:aplikasir_mobile/model/product_model.dart';
import 'package:aplikasir_mobile/model/customer_model.dart';
import 'dart:io'; // Untuk File

// Impor layar QRIS & Tunai
import 'qris_display_screen.dart';
import 'cash_payment_screen.dart';
import 'checkout_success_screen.dart';

class CheckoutScreen extends StatefulWidget {
  // Dihapus: cartQuantities, cartProducts, userId (sudah di-pass ke Provider)

  const CheckoutScreen({
    super.key,
    // Hapus parameter yang sudah ada di Provider
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> with TickerProviderStateMixin {
  final NumberFormat currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  // State UI lokal, misal untuk animasi atau controller form dialog
  // State _isProcessing di Provider
  // State _totalBelanja dll di Provider

  final Color _primaryColor = Colors.blue.shade700;
  final Color _lightBorderColor = Colors.blue.shade100;
  final Color _darkTextColor = Colors.black87;
  final Color _greyTextColor = Colors.grey.shade600;

  OverlayEntry? _overlayEntry;
  AnimationController? _overlayAnimationController;
  final GlobalKey _bottomCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Data diinisialisasi oleh Provider
    // Jika perlu load customer saat screen pertama kali load untuk 'Kredit'
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   final provider = context.read<CheckoutProvider>();
    //   if (provider.selectedPaymentMethod == 'Kredit') {
    //     provider.loadCustomers();
    //   }
    // });
  }

  @override
  void dispose() {
    _removeOverlay();
    _overlayAnimationController?.dispose();
    super.dispose();
  }

  void _showCustomNotificationWidget(String message,
      {bool isError = false, Duration duration = const Duration(seconds: 3)}) {
    _removeOverlay();
    _overlayAnimationController = AnimationController(
      vsync: this, // Ganti vsync ke this
      duration: const Duration(milliseconds: 300),
    );
    final overlay = Overlay.of(context); // Gunakan Overlay.of(context)
    final RenderBox? bottomCardRenderBox =
        _bottomCardKey.currentContext?.findRenderObject() as RenderBox?;
    double bottomCardTopY = MediaQuery.of(context).size.height - 200;
    if (bottomCardRenderBox != null && bottomCardRenderBox.hasSize) {
      final offset = bottomCardRenderBox.localToGlobal(Offset.zero);
      bottomCardTopY = offset.dy;
    }
    const double notificationHeightEstimate = 60.0;
    const double marginBottom = 10.0;
    final double targetTop = bottomCardTopY - notificationHeightEstimate - marginBottom;

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
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                decoration: BoxDecoration(
                    color: isError ? Colors.redAccent.shade100 : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                        color: isError ? Colors.redAccent.shade400 : Colors.green.shade700,
                        width: 1)),
                child: Text(
                  message,
                  style: GoogleFonts.poppins(
                      color: isError ? Colors.red.shade900 : Colors.green.shade900,
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
      // _overlayAnimationController?.dispose(); // Jangan dispose di sini jika akan dipakai lagi
      // _overlayAnimationController = null;
    }).catchError((e) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      // _overlayAnimationController?.dispose();
      // _overlayAnimationController = null;
    });
  }

  Future<void> _handleProceedToPayment(CheckoutProvider provider) async {
    final paymentMethod = provider.selectedPaymentMethod;

    if (paymentMethod == 'Kredit') {
      final result = await provider.processKreditTransaction();
      if (result != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CheckoutSuccessScreen(
              transactionId: result['transactionId'],
              userId: provider.userId, // Ambil userId dari provider
              paymentMethod: result['paymentMethod'],
              changeAmount: null, // Tidak ada kembalian untuk kredit
            ),
          ),
        );
        // provider.clearCartAndReset(); // Opsional: reset cart di provider
      } else if (provider.errorMessage != null && mounted) {
        _showCustomNotificationWidget(provider.errorMessage!, isError: true);
      }
    } else if (paymentMethod == 'Tunai') {
      final paymentData = provider.prepareDataForCashPayment();
      if(mounted){
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CashPaymentScreen(
                totalAmount: paymentData['totalAmount'],
                userId: paymentData['userId'],
                cartQuantities: paymentData['cartQuantities'],
                cartProducts: paymentData['cartProducts'],
              ),
            ),
          ).then((_) {
            // Dipanggil saat CashPaymentScreen di-pop (baik sukses atau batal)
            if(mounted) provider.resetProcessingCheckout(); // Selalu reset loading
          });
      }
    } else if (paymentMethod == 'QRIS') {
      final paymentData = provider.prepareDataForQrisPayment();
       if(mounted){
           final paymentConfirmed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => QrisDisplayScreen(
                totalAmount: paymentData['totalAmount'],
                userId: paymentData['userId'],
                cartQuantities: paymentData['cartQuantities'],
                cartProducts: paymentData['cartProducts'],
              ),
            ),
          );
          if(mounted) provider.resetProcessingCheckout();
          if (paymentConfirmed == false && mounted) { // Pembayaran dibatalkan dari QrisScreen
            _showCustomNotificationWidget("Pembayaran QRIS dibatalkan.", isError: true);
          }
       }
    }
  }

  Future<void> _showSelectCustomerDialog(CheckoutProvider provider) async {
    await provider.loadCustomers(); // Pastikan customer di-load
     if (!mounted) return; // Cek mounted setelah await

    final selected = await showDialog<Customer>(
      context: context,
      builder: (BuildContext dialogContext) { // Gunakan dialogContext baru
        return StatefulBuilder( // Untuk update UI dialog internal
          builder: (context, setDialogState) { // context di sini adalah context dialog
            // Ambil state customer dari provider yang di-pass
            final currentCustomers = provider.availableCustomers;
            final isLoadingCust = provider.isLoadingCustomers;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              backgroundColor: Colors.white,
              title: Text("Pilih Pelanggan", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: _primaryColor)),
              contentPadding: const EdgeInsets.only(top: 10.0, bottom: 0),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoadingCust)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 20.0), child: Center(child: CircularProgressIndicator()))
                    else if (currentCustomers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 24.0),
                        child: Text("Belum ada pelanggan.", textAlign: TextAlign.center, style: GoogleFonts.poppins(color: _greyTextColor)),
                      )
                    else
                      ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: MediaQuery.of(dialogContext).size.height * 0.4),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: currentCustomers.length,
                          itemBuilder: (ctx, index) {
                            final customer = currentCustomers[index];
                            return ListTile(
                              title: Text(customer.namaPelanggan, style: GoogleFonts.poppins()),
                              subtitle: customer.nomorTelepon != null && customer.nomorTelepon!.isNotEmpty
                                  ? Text(customer.nomorTelepon!, style: GoogleFonts.poppins(fontSize: 12))
                                  : null,
                              onTap: () => Navigator.pop(dialogContext, customer), // Kirim customer terpilih
                            );
                          },
                        ),
                      ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.add_circle_outline, color: _primaryColor),
                      title: Text("Tambah Pelanggan Baru", style: GoogleFonts.poppins(color: _primaryColor, fontWeight: FontWeight.w500)),
                      onTap: () async {
                         Navigator.pop(dialogContext); // Tutup dialog pilih dulu
                         final newCustomer = await _showAddCustomerDialog(provider); // Buka dialog tambah
                         if (newCustomer != null) {
                            provider.selectCustomer(newCustomer); // Langsung pilih customer baru
                         }
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text("Batal", style: GoogleFonts.poppins(color: _greyTextColor)),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected != null) {
      provider.selectCustomer(selected);
    }
  }


  Future<Customer?> _showAddCustomerDialog(CheckoutProvider provider) async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSavingInDialog = false; // State loading khusus dialog
    if (!mounted) return null;

    return await showDialog<Customer>(
      context: context, // Gunakan context utama
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) { // context di sini adalah context dialog
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              title: Text("Tambah Pelanggan", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: _primaryColor)),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(labelText: "Nama Pelanggan", hintText: "Nama lengkap", border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), prefixIcon: const Icon(Icons.person)),
                      style: GoogleFonts.poppins(),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama tidak boleh kosong' : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: phoneController,
                      decoration: InputDecoration(labelText: "Nomor Telepon (Opsional)", hintText: "Contoh: 0812xxxx", border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), prefixIcon: const Icon(Icons.phone)),
                      keyboardType: TextInputType.phone,
                      style: GoogleFonts.poppins(),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: isSavingInDialog ? null : () => Navigator.pop(dialogContext),
                  child: Text("Batal", style: GoogleFonts.poppins(color: _greyTextColor)),
                ),
                ElevatedButton.icon(
                  icon: isSavingInDialog ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                  label: Text(isSavingInDialog ? "Menyimpan..." : "Simpan", style: GoogleFonts.poppins()),
                  style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: isSavingInDialog ? null : () async {
                    if (formKey.currentState!.validate()) {
                      setDialogState(() => isSavingInDialog = true);
                      final savedCustomer = await provider.addCustomer(nameController.text, phoneController.text);
                      setDialogState(() => isSavingInDialog = false);
                      if (savedCustomer != null && mounted) {
                        Navigator.pop(dialogContext, savedCustomer); // Kembalikan customer yang baru disimpan
                        _showCustomNotificationWidget("Pelanggan '${savedCustomer.namaPelanggan}' ditambahkan.", isError:false);
                      } else if (provider.errorMessage != null && mounted){
                        _showCustomNotificationWidget(provider.errorMessage!, isError:true);
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }


  Widget _buildOrderItem(Product product, int quantity) {
    ImageProvider? productImage;
    if (product.gambarProduk != null && product.gambarProduk!.isNotEmpty) {
      final imageFile = File(product.gambarProduk!);
      if (imageFile.existsSync()) {
        productImage = FileImage(imageFile);
      }
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: Colors.grey.shade200, width: 0.8)),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6.0),
            child: Container(
              width: 55,
              height: 55,
              color: Colors.grey.shade200,
              child: productImage != null
                  ? Image(image: productImage, width: 55, height: 55, fit: BoxFit.cover, errorBuilder: (c, e, s) => Icon(Icons.hide_image_outlined, color: Colors.grey[400], size: 30))
                  : Icon(Icons.inventory_2_outlined, color: Colors.grey[400], size: 30),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.namaProduk, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: _darkTextColor), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('${currencyFormatter.format(product.hargaJual)} x $quantity', style: GoogleFonts.poppins(fontSize: 12, color: _greyTextColor)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(currencyFormatter.format(product.hargaJual * quantity), style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: _darkTextColor)),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodButton({
    required CheckoutProvider provider, // Terima provider
    required String label,
    required String value,
    required IconData icon,
  }) {
    bool isSelected = provider.selectedPaymentMethod == value;
    return Expanded(
      child: InkWell(
        onTap: provider.isProcessingCheckout ? null : () async { // Nonaktifkan saat loading
          provider.selectPaymentMethod(value);
          if (value == 'Kredit') {
            await _showSelectCustomerDialog(provider); // Kirim provider
          }
        },
        borderRadius: BorderRadius.circular(8.0),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
          decoration: BoxDecoration(
            color: isSelected ? _primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: isSelected ? _primaryColor : _lightBorderColor, width: 1.5),
            boxShadow: isSelected ? [BoxShadow(color: _primaryColor.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))] : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? Colors.white : _primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: isSelected ? Colors.white : _primaryColor, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dapatkan provider
    final checkoutProvider = context.watch<CheckoutProvider>();
    final String mainButtonText = checkoutProvider.selectedPaymentMethod == 'Tunai'
        ? 'Bayar Tunai'
        : checkoutProvider.selectedPaymentMethod == 'QRIS'
            ? 'Lanjutkan ke QRIS'
            : 'Proses Hutang';

    // Listener untuk pesan dari provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (checkoutProvider.errorMessage != null && mounted) {
         _showCustomNotificationWidget(checkoutProvider.errorMessage!, isError: true);
         // provider.clearMessages(); // Opsional: clear message setelah ditampilkan
      }
      if (checkoutProvider.successMessage != null && mounted) {
         _showCustomNotificationWidget(checkoutProvider.successMessage!, isError: false);
         // provider.clearMessages();
      }
    });


    return Scaffold(
      appBar: AppBar(
        title: Text('Checkout', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _primaryColor)),
        backgroundColor: Colors.white,
        foregroundColor: _primaryColor,
        elevation: 0.5,
        shadowColor: Colors.black26,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: checkoutProvider.isProcessingCheckout ? null : () => Navigator.pop(context),
        ),
      ),
      backgroundColor: const Color(0xFFF7F8FC),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 15.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Ringkasan Pesanan', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: _darkTextColor)),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: checkoutProvider.initialCartProducts
                  .where((p) => (checkoutProvider.initialCartQuantities[p.id] ?? 0) > 0).length,
              itemBuilder: (context, index) {
                final relevantProducts = checkoutProvider.initialCartProducts
                    .where((p) => (checkoutProvider.initialCartQuantities[p.id] ?? 0) > 0).toList();
                if (index >= relevantProducts.length) return const SizedBox.shrink();
                final product = relevantProducts[index];
                final quantity = checkoutProvider.initialCartQuantities[product.id] ?? 0;
                return _buildOrderItem(product, quantity);
              },
            ),
          ),
          Container(
            key: _bottomCardKey,
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 20.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20.0), topRight: Radius.circular(20.0)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, -4))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Subtotal', style: GoogleFonts.poppins(fontSize: 14, color: _greyTextColor)),
                    Text(currencyFormatter.format(checkoutProvider.totalBelanja), style: GoogleFonts.poppins(fontSize: 14, color: _darkTextColor)),
                  ],
                ),
                const SizedBox(height: 5),
                Divider(color: Colors.grey.shade200, height: 10),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Pembayaran', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: _darkTextColor)),
                    Text(currencyFormatter.format(checkoutProvider.totalBelanja), style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryColor)),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Metode Pembayaran', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: _darkTextColor)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildPaymentMethodButton(provider: checkoutProvider, label: 'Cash', value: 'Tunai', icon: Icons.account_balance_wallet_outlined),
                    _buildPaymentMethodButton(provider: checkoutProvider, label: 'QRIS', value: 'QRIS', icon: Icons.qr_code_2),
                    _buildPaymentMethodButton(provider: checkoutProvider, label: 'Kredit', value: 'Kredit', icon: Icons.credit_card_outlined),
                  ],
                ),
                if (checkoutProvider.selectedPaymentMethod == 'Kredit')
                  Padding(
                    padding: const EdgeInsets.only(top: 15.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: checkoutProvider.selectedCustomer == null
                                  ? Text("Pelanggan: -", style: GoogleFonts.poppins(color: Colors.red.shade700, fontStyle: FontStyle.italic))
                                  : Text("Pelanggan: ${checkoutProvider.selectedCustomer!.namaPelanggan}", style: GoogleFonts.poppins(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                            ),
                            TextButton.icon(
                              icon: Icon(checkoutProvider.selectedCustomer == null ? Icons.person_search : Icons.sync, size: 18, color: _primaryColor),
                              label: Text(checkoutProvider.selectedCustomer == null ? "Pilih" : "Ganti", style: GoogleFonts.poppins(color: _primaryColor)),
                              onPressed: () => _showSelectCustomerDialog(checkoutProvider), // Kirim provider
                              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                            ),
                          ],
                        ),
                        const Divider(height: 10),
                      ],
                    ),
                  ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 2,
                    ),
                    onPressed: checkoutProvider.isProcessingCheckout ? null : () => _handleProceedToPayment(checkoutProvider),
                    child: checkoutProvider.isProcessingCheckout
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Text(mainButtonText, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

