// screen/checkout/checkout_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:aplikasir_mobile/model/product_model.dart';
import 'package:aplikasir_mobile/model/transaction_model.dart';
import 'package:aplikasir_mobile/model/customer_model.dart'; // <-- Re-import Customer model
import 'package:aplikasir_mobile/helper/db_helper.dart';
import 'dart:io'; // Untuk File

// Impor layar QRIS
import 'qris_display_screen.dart';
import 'cash_payment_screen.dart';
import 'checkout_success_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final Map<int, int> cartQuantities;
  final List<Product> cartProducts;
  final int userId;

  const CheckoutScreen({
    super.key,
    required this.cartQuantities,
    required this.cartProducts,
    required this.userId,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen>
    with TickerProviderStateMixin {
  final NumberFormat currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  double _totalBelanja = 0;
  double _totalModal = 0;

  // State untuk metode pembayaran (Tunai, QRIS, Kredit)
  String _selectedPaymentMethod = 'Tunai';
  Customer? _selectedCustomer; // <-- Re-introduce selected customer state
  bool _isProcessing = false;

  // Warna primer dan teks (konsisten)
  final Color _primaryColor = Colors.blue.shade700;
  final Color _lightBorderColor = Colors.blue.shade100;
  final Color _darkTextColor = Colors.black87;
  final Color _greyTextColor = Colors.grey.shade600;

  // --- State untuk Notifikasi Kustom ---
  OverlayEntry? _overlayEntry; // Untuk kontrol overlay
  AnimationController? _overlayAnimationController;
  // --- Akhir State Notifikasi Kustom ---

  // Kunci Global untuk mendapatkan posisi card bawah
  final GlobalKey _bottomCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _calculateTotals();
  }

  // --- Helper untuk Notifikasi Kustom ---
  void _showCustomNotificationWidget(String message,
      {bool isError = false, Duration duration = const Duration(seconds: 3)}) {
    // Hapus overlay sebelumnya jika ada
    _removeOverlay();

    // Set state untuk pesan dan tipe notifikasi (jika diperlukan oleh widget overlay)
    // setState(() {
    //   _customNotificationMessage = message;
    //   _isErrorNotification = isError;
    // });

    _overlayAnimationController = AnimationController(
      vsync: Navigator.of(context)
          .overlay!, // Perlu TickerProvider, overlay bisa jadi vsync
      duration: const Duration(milliseconds: 300),
    );

    final overlay = Navigator.of(context).overlay!;

    // Dapatkan posisi RenderBox dari Card bawah untuk penempatan
    final RenderBox? bottomCardRenderBox =
        _bottomCardKey.currentContext?.findRenderObject() as RenderBox?;
    double bottomCardTopY =
        MediaQuery.of(context).size.height - 200; // Default fallback
    if (bottomCardRenderBox != null && bottomCardRenderBox.hasSize) {
      final offset = bottomCardRenderBox.localToGlobal(Offset.zero);
      bottomCardTopY = offset.dy;
      print("Bottom card Y: $bottomCardTopY"); // Debug posisi
    }

    _overlayEntry = OverlayEntry(
      builder: (context) {
        // Hitung posisi Y untuk overlay agar tepat di atas card bawah
        // Kurangi tinggi notifikasi (estimasi) dan sedikit margin
        const double notificationHeightEstimate =
            60.0; // Estimasi tinggi notifikasi
        const double marginBottom = 10.0;
        final double targetTop =
            bottomCardTopY - notificationHeightEstimate - marginBottom;

        return Positioned(
          top: targetTop, // Posisi vertikal
          left: 16.0, // Margin kiri
          right: 16.0, // Margin kanan
          child: SlideTransition(
            // Animasi slide dari atas
            position: Tween<Offset>(
              begin: const Offset(
                  0, -1.5), // Mulai dari atas (-1.5 * tinggi widget)
              end: Offset.zero,
            ).animate(CurvedAnimation(
                parent: _overlayAnimationController!, curve: Curves.easeOut)),
            child: Material(
              // Perlu Material agar shadow terlihat
              elevation: 4.0, // Beri shadow seperti snackbar
              borderRadius: BorderRadius.circular(8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 14.0),
                decoration: BoxDecoration(
                    color: isError
                        ? Colors.redAccent.shade400
                        : Colors.green.shade100, // Background lebih soft
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                        color: isError
                            ? Colors.redAccent.shade400
                            : Colors.green.shade700,
                        width: 1)),
                child: Text(
                  message,
                  style: GoogleFonts.poppins(
                      color: isError
                          ? const Color.fromARGB(255, 255, 255, 255)
                          : Colors.green.shade900, // Warna teks kontras
                      fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
        );
      },
    );

    // Tampilkan overlay
    overlay.insert(_overlayEntry!);
    _overlayAnimationController?.forward(); // Mulai animasi

    // Jadwalkan penghapusan overlay
    Future.delayed(duration, () {
      _removeOverlay();
    });
  }

  void _removeOverlay() {
    // Animasi keluar sebelum remove
    _overlayAnimationController?.reverse().then((_) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      _overlayAnimationController?.dispose();
      _overlayAnimationController = null;
    }).catchError((e) {
      // Jika animasi sudah di-dispose atau error lain
      _overlayEntry?.remove();
      _overlayEntry = null;
      _overlayAnimationController?.dispose();
      _overlayAnimationController = null;
    });
  }

  // Pastikan dispose controller saat state di-dispose
  @override
  void dispose() {
    _removeOverlay(); // Hapus overlay jika masih ada saat dispose
    _overlayAnimationController?.dispose(); // Dispose controller
    super.dispose();
  }
  // --- Akhir Helper Notifikasi Kustom ---

  void _calculateTotals() {
    // ... (Fungsi _calculateTotals tetap sama) ...
    double tempTotalBelanja = 0;
    double tempTotalModal = 0;
    widget.cartProducts.forEach((product) {
      final quantity = widget.cartQuantities[product.id] ?? 0;
      if (quantity > 0) {
        tempTotalBelanja += product.hargaJual * quantity;
        tempTotalModal += product.hargaModal * quantity;
      }
    });
    if (mounted) {
      setState(() {
        _totalBelanja = tempTotalBelanja;
        _totalModal = tempTotalModal;
      });
    }
  }

  // --- Fungsi Proses Transaksi (Logika Diperbaiki) ---
  Future<void> _navigateToPaymentStep() async {
    print("Processing payment for: $_selectedPaymentMethod");
    if (_isProcessing) return;

    if (_selectedPaymentMethod == 'Kredit' && _selectedCustomer == null) {
      _showSnackbar("Pilih pelanggan terlebih dahulu untuk pembayaran kredit.",
          isError: true);
      return;
    }

    print("Processing payment for: $_selectedPaymentMethod");
    setState(() {
      _isProcessing = true;
    });

    // --- Langsung tentukan aksi berdasarkan metode ---
    if (_selectedPaymentMethod == 'Tunai') {
      print("Navigating to CashPaymentScreen...");
      // Kita tidak 'await' push di sini agar loading bisa reset segera
      // State loading akan dihandle oleh CashPaymentScreen jika sukses,
      // atau oleh .then() jika user kembali.
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CashPaymentScreen(
            totalAmount: _totalBelanja,
            userId: widget.userId,
            cartQuantities: widget.cartQuantities,
            cartProducts: widget.cartProducts,
          ),
        ),
      ).then((_) {
        // Ini akan dipanggil saat CashPaymentScreen ditutup
        print("Returned from CashPaymentScreen via .then()");
        // Reset loading saat kembali (jika belum diganti)
        if (mounted) setState(() => _isProcessing = false);
      });
      // JANGAN panggil save/reset loading di sini
    } else if (_selectedPaymentMethod == 'QRIS') {
      print("Navigating to QrisDisplayScreen...");
      // Tunggu hasil dari QrisScreen untuk notifikasi batal
      final paymentConfirmed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => QrisDisplayScreen(
            totalAmount: _totalBelanja,
            userId: widget.userId,
            cartQuantities: widget.cartQuantities,
            cartProducts: widget.cartProducts,
          ),
        ),
      );

      // Reset loading SETELAH kembali
      if (mounted) setState(() => _isProcessing = false);

      // Tampilkan notifikasi jika batal
      if (paymentConfirmed == false && mounted) {
        _showCustomNotificationWidget("Pembayaran QRIS dibatalkan.",
            isError: true);
      }
      // JANGAN panggil save di sini
    } else if (_selectedPaymentMethod == 'Kredit') {
      // Langsung proses simpan Kredit
      try {
        print("Saving Kredit transaction directly...");
        await _saveTransactionAndStock(); // Panggil tanpa argumen boolean
        // Navigasi sukses sudah dihandle di dalam _saveTransactionAndStock
        // Reset loading tidak perlu karena sudah diganti layar
      } catch (e) {
        print("Error saving Kredit transaction: $e");
        // Snackbar sudah dihandle di _saveTransactionAndStock
        if (mounted) {
          // Reset loading jika kredit gagal
          setState(() => _isProcessing = false);
        }
      }
    } else {
      // Metode tidak dikenal
      print("Unknown payment method.");
      if (mounted) setState(() => _isProcessing = false); // Reset loading
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    // ... (Fungsi _showSnackbar tetap sama) ...
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

  // --- Fungsi Dialog Pilih Pelanggan (Aktifkan Kembali) ---
  Future<void> _showSelectCustomerDialog() async {
    // ... (Kode _showSelectCustomerDialog SAMA seperti versi kredit sebelumnya) ...
    List<Customer> customers = [];
    bool isLoadingCustomers = true;

    try {
      customers =
          await DatabaseHelper.instance.getCustomersByUserId(widget.userId);
      isLoadingCustomers = false;
    } catch (e) {
      print("Error fetching customers: $e");
      isLoadingCustomers = false;
      if (mounted)
        _showSnackbar("Gagal memuat daftar pelanggan.", isError: true);
    }

    if (!mounted) return;

    final selected = await showDialog<Customer>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0)),
              backgroundColor: Colors.white,
              title: Text("Pilih Pelanggan",
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, color: _primaryColor)),
              contentPadding: const EdgeInsets.only(top: 10.0, bottom: 0),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoadingCustomers)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (customers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 20.0, horizontal: 24.0),
                        child: Text(
                          "Belum ada pelanggan tersimpan.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(color: _greyTextColor),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.4,
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: customers.length,
                          itemBuilder: (context, index) {
                            final customer = customers[index];
                            return ListTile(
                              title: Text(customer.namaPelanggan,
                                  style: GoogleFonts.poppins()),
                              subtitle: customer.nomorTelepon != null &&
                                      customer.nomorTelepon!.isNotEmpty
                                  ? Text(customer.nomorTelepon!,
                                      style: GoogleFonts.poppins(fontSize: 12))
                                  : null,
                              onTap: () => Navigator.pop(context, customer),
                            );
                          },
                        ),
                      ),
                    const Divider(height: 1),
                    ListTile(
                      leading:
                          Icon(Icons.add_circle_outline, color: _primaryColor),
                      title: Text("Tambah Pelanggan Baru",
                          style: GoogleFonts.poppins(
                              color: _primaryColor,
                              fontWeight: FontWeight.w500)),
                      onTap: () async {
                        final newCustomer = await _showAddCustomerDialog();
                        if (newCustomer != null && mounted) {
                          try {
                            setDialogState(() => isLoadingCustomers = true);
                            final updatedCustomers = await DatabaseHelper
                                .instance
                                .getCustomersByUserId(widget.userId);
                            customers = updatedCustomers;
                            isLoadingCustomers = false;
                            if (mounted) Navigator.pop(context, newCustomer);
                          } catch (e) {
                            print("Error refreshing customer list: $e");
                            isLoadingCustomers = false;
                            if (mounted)
                              _showSnackbar("Gagal refresh daftar pelanggan.",
                                  isError: true);
                          } finally {
                            if (mounted) setDialogState(() {});
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Batal",
                      style: GoogleFonts.poppins(color: _greyTextColor)),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedCustomer = selected;
      });
    }
  }

  // --- Fungsi Dialog Tambah Pelanggan (Aktifkan Kembali) ---
  Future<Customer?> _showAddCustomerDialog() async {
    // ... (Kode _showAddCustomerDialog SAMA seperti versi kredit sebelumnya) ...
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    if (!mounted) return null;
    return await showDialog<Customer>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0)),
              backgroundColor: Colors.white,
              title: Text("Tambah Pelanggan Baru",
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, color: _primaryColor)),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: "Nama Pelanggan",
                        hintText: "Masukkan nama lengkap",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.person),
                      ),
                      style: GoogleFonts.poppins(),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Nama pelanggan tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: phoneController,
                      decoration: InputDecoration(
                        labelText: "Nomor Telepon (Opsional)",
                        hintText: "Contoh: 0812xxxx",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                      style: GoogleFonts.poppins(),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: Text("Batal",
                      style: GoogleFonts.poppins(color: _greyTextColor)),
                ),
                ElevatedButton.icon(
                  icon: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save),
                  label: Text(isSaving ? "Menyimpan..." : "Simpan",
                      style: GoogleFonts.poppins()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setDialogState(() => isSaving = true);
                            try {
                              final newCustomer = Customer(
                                idPengguna: widget.userId,
                                namaPelanggan: nameController.text.trim(),
                                nomorTelepon:
                                    phoneController.text.trim().isEmpty
                                        ? null
                                        : phoneController.text.trim(),
                              );
                              final generatedId = await DatabaseHelper.instance
                                  .insertCustomer(newCustomer);
                              final savedCustomer = Customer(
                                  id: generatedId,
                                  idPengguna: newCustomer.idPengguna,
                                  namaPelanggan: newCustomer.namaPelanggan,
                                  nomorTelepon: newCustomer.nomorTelepon,
                                  createdAt: newCustomer.createdAt);
                              if (!mounted) return;
                              _showSnackbar(
                                  "Pelanggan '${savedCustomer.namaPelanggan}' berhasil ditambahkan.");
                              Navigator.pop(context, savedCustomer);
                            } catch (e) {
                              print("Error saving customer: $e");
                              if (!mounted) return;
                              _showSnackbar(
                                  "Gagal menyimpan pelanggan: ${e.toString()}",
                                  isError: true);
                            } finally {
                              if (mounted)
                                setDialogState(() => isSaving = false);
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

  // --- Fungsi Helper Simpan Transaksi & Stok (FINAL - Dipanggil dari Kredit atau Layar Lain) ---
  Future<void> _saveTransactionAndStock() async {
    // Pastikan ini HANYA dipanggil untuk kredit
    if (_selectedPaymentMethod != 'Kredit') {
      print(
          "ERROR: _saveTransactionAndStock was called unexpectedly for $_selectedPaymentMethod");
      // Bisa lempar error atau return saja
      throw Exception(
          "_saveTransactionAndStock should only be called for Kredit method.");
      // return;
    }

    try {
      // ... (Kode detailItems, tentukan status/metode/pelanggan untuk Kredit SAMA) ...
      List<Map<String, dynamic>> detailItems = [];
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
        }
      });
      String statusPembayaran = 'Belum Lunas';
      int? idPelanggan = _selectedCustomer!.id;
      String paymentMethod = 'Kredit';
      // ... (Buat TransactionModel SAMA) ...
      final transaction = TransactionModel(
        idPengguna: widget.userId,
        tanggalTransaksi: DateTime.now(),
        totalBelanja: _totalBelanja,
        totalModal: _totalModal,
        metodePembayaran: paymentMethod,
        statusPembayaran: statusPembayaran,
        idPelanggan: idPelanggan,
        detailItems: detailItems,
      );
      // ... (Simpan Transaksi SAMA) ...
      final transactionId =
          await DatabaseHelper.instance.insertTransaction(transaction);
      print(
          "Transaction saved: ID $transactionId, Method: $paymentMethod, Status: $statusPembayaran");
      // ... (Update Stok SAMA) ...
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
        throw stockError;
      }

      // --- Navigasi Sukses KREDIT ---
      if (!mounted) return;
      print("Navigating to SuccessScreen after Kredit save.");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CheckoutSuccessScreen(
            transactionId: transactionId,
            userId: widget.userId,
            paymentMethod: 'Kredit',
            changeAmount: null,
          ),
        ),
      );
    } catch (e) {
      print("Error in _saveTransactionAndStock (Kredit): $e");
      if (mounted)
        _showSnackbar(
            "Terjadi kesalahan saat menyimpan data kredit: ${e.toString()}",
            isError: true);
      throw Exception(
          "Failed to save Kredit transaction or update stock"); // Lempar ulang agar ditangkap di pemanggil
    }
  }

  // --- Helper Widget untuk Tombol Metode Pembayaran (Re-introduce Kredit) ---
  Widget _buildPaymentMethodButton({
    required String label,
    required String value,
    required IconData icon,
  }) {
    bool isSelected = _selectedPaymentMethod == value;
    return Expanded(
      child: InkWell(
        onTap: _isProcessing
            ? null
            : () {
                if (mounted && _selectedPaymentMethod != value) {
                  setState(() {
                    _selectedPaymentMethod = value;
                    // *** Reset customer jika BUKAN kredit ***
                    if (value != 'Kredit') {
                      _selectedCustomer = null;
                    }
                  });
                  // *** Panggil dialog jika KREDIT dipilih ***
                  if (value == 'Kredit') {
                    _showSelectCustomerDialog();
                  }
                }
              },
        borderRadius: BorderRadius.circular(8.0),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
          decoration: BoxDecoration(
            color: isSelected ? _primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color: isSelected ? _primaryColor : _lightBorderColor,
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : _primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : _primaryColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper Widget untuk Item Produk (Tetap Sama) ---
  Widget _buildOrderItem(Product product, int quantity) {
    // ... (Kode _buildOrderItem sama seperti sebelumnya) ...
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
                  ? Image(
                      image: productImage,
                      width: 55,
                      height: 55,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Icon(Icons.hide_image_outlined,
                          color: Colors.grey[400], size: 30),
                    )
                  : Icon(Icons.inventory_2_outlined,
                      color: Colors.grey[400], size: 30),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.namaProduk,
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _darkTextColor),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${currencyFormatter.format(product.hargaJual)} x $quantity',
                  style:
                      GoogleFonts.poppins(fontSize: 12, color: _greyTextColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            currencyFormatter.format(product.hargaJual * quantity),
            style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _darkTextColor),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Teks Tombol Utama Dinamis (Tambah Kredit)
    String mainButtonText = 'Bayar Tunai';
    if (_selectedPaymentMethod == 'QRIS') {
      mainButtonText = 'Lanjutkan ke QRIS';
    } else if (_selectedPaymentMethod == 'Kredit') {
      mainButtonText = 'Proses Hutang';
    } // <-- Teks untuk Kredit

    return Scaffold(
      appBar: AppBar(
        // AppBar style tetap
        title: Text('Checkout',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: _primaryColor)),
        backgroundColor: Colors.white,
        foregroundColor: _primaryColor,
        elevation: 0.5,
        shadowColor: Colors.black26,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
        ),
      ),
      // *** Background Scaffold kembali ke default ***
      backgroundColor: const Color(
          0xFFF7F8FC), // Atau Theme.of(context).scaffoldBackgroundColor
      body: Column(
        // Layout utama Column
        children: [
          // === Bagian Atas: Judul Fixed, List Scrollable ===
          Padding(
            // Padding untuk judul
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 15.0),
            child: Align(
              // Pastikan judul rata kiri
              alignment: Alignment.centerLeft,
              child: Text(
                'Ringkasan Pesanan',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _darkTextColor),
              ),
            ),
          ),
          Expanded(
              // *** Expanded HANYA untuk ListView ***
              child: ListView.builder(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0), // Padding list
            itemCount: widget.cartProducts
                .where((p) => (widget.cartQuantities[p.id] ?? 0) > 0)
                .length, // Hitung item yang relevan saja
            itemBuilder: (context, index) {
              // Ambil produk yang relevan saja untuk di-build
              final relevantProducts = widget.cartProducts
                  .where((p) => (widget.cartQuantities[p.id] ?? 0) > 0)
                  .toList();
              if (index >= relevantProducts.length)
                return const SizedBox.shrink(); // Safety check

              final product = relevantProducts[index];
              final quantity = widget.cartQuantities[product.id] ?? 0;
              // return _buildOrderItem(product, quantity); // Build item
              // Pengkondisian di itemCount sudah cukup, build langsung
              return _buildOrderItem(product, quantity);
            },
          )
              //  widget.cartProducts.isEmpty // Kondisi kosong dipindah ke builder jika perlu
              //      ? Center(child: Text("Keranjang kosong.", style: GoogleFonts.poppins(color: _greyTextColor)))
              //      : ListView( // Ganti ke ListView biasa jika pakai map (tapi builder lebih efisien)
              //          padding: const EdgeInsets.symmetric(horizontal: 16.0),
              //          children: widget.cartProducts.map((product) {
              //            final quantity = widget.cartQuantities[product.id] ?? 0;
              //            if (quantity > 0) { return _buildOrderItem(product, quantity); }
              //            else { return const SizedBox.shrink(); }
              //          }).toList(),
              //        ),
              ), // Akhir Expanded ListView

          // === Bagian Bawah: Summary & Pembayaran ===
          Container(
            key: _bottomCardKey, // Kunci untuk posisi overlay
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 20.0),
            decoration: BoxDecoration(
              color: Colors.white, // Background putih
              // *** BorderRadius HANYA untuk sudut atas ***
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20.0),
                topRight: Radius.circular(20.0),
              ),
              boxShadow: [
                // Shadow halus di atas
                BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -4))
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ... (Baris Subtotal & Total Pembayaran SAMA) ...
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Subtotal',
                        style: GoogleFonts.poppins(
                            fontSize: 14, color: _greyTextColor)),
                    Text(currencyFormatter.format(_totalBelanja),
                        style: GoogleFonts.poppins(
                            fontSize: 14, color: _darkTextColor)),
                  ],
                ),
                const SizedBox(height: 5),
                Divider(color: Colors.grey.shade200, height: 10),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Pembayaran',
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _darkTextColor)),
                    Text(currencyFormatter.format(_totalBelanja),
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _primaryColor)),
                  ],
                ),
                const SizedBox(height: 20),

                // Judul Metode Pembayaran
                Text('Metode Pembayaran',
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _darkTextColor)),
                const SizedBox(height: 12),

                // Tombol Metode Pembayaran (Tambah Kredit)
                Row(
                  children: [
                    _buildPaymentMethodButton(
                        label: 'Cash',
                        value: 'Tunai',
                        icon: Icons.account_balance_wallet_outlined),
                    _buildPaymentMethodButton(
                        label: 'QRIS', value: 'QRIS', icon: Icons.qr_code_2),
                    _buildPaymentMethodButton(
                        label: 'Kredit',
                        value: 'Kredit',
                        icon: Icons.credit_card_outlined), // <-- Tambah Kredit
                  ],
                ),

                // *** Tampilkan Info Pelanggan (jika Kredit dipilih) ***
                if (_selectedPaymentMethod == 'Kredit')
                  Padding(
                    padding:
                        const EdgeInsets.only(top: 15.0), // Beri jarak atas
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: _selectedCustomer == null
                                  ? Text("Pelanggan: -",
                                      style: GoogleFonts.poppins(
                                          color: Colors.red.shade700,
                                          fontStyle: FontStyle
                                              .italic)) // Style beda jika blm pilih
                                  : Text(
                                      "Pelanggan: ${_selectedCustomer!.namaPelanggan}",
                                      style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                            ),
                            TextButton.icon(
                              icon: Icon(
                                  _selectedCustomer == null
                                      ? Icons.person_search
                                      : Icons.sync,
                                  size: 18,
                                  color: _primaryColor), // Ikon beda
                              label: Text(
                                  _selectedCustomer == null ? "Pilih" : "Ganti",
                                  style: GoogleFonts.poppins(
                                      color: _primaryColor)),
                              onPressed: _showSelectCustomerDialog,
                              style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8)),
                            ),
                          ],
                        ),
                        const Divider(height: 10),
                      ],
                    ),
                  ),

                const SizedBox(height: 25), // Jarak sebelum tombol utama

                // Tombol Aksi Utama
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 2,
                    ),
                    onPressed: _isProcessing ? null : _navigateToPaymentStep,
                    child: Text(
                      mainButtonText,
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ), // Teks dinamis
                  ),
                ),
              ],
            ),
          ) // Akhir Container Bawah
        ],
      ),
    );
  }
}
