// lib/features/checkout/screens/receipt_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:aplikasir_mobile/model/transaction_model.dart';
import 'package:aplikasir_mobile/model/customer_model.dart';
import 'package:aplikasir_mobile/model/user_model.dart';
import 'package:aplikasir_mobile/helper/db_helper.dart'; // Sesuaikan path jika perlu

class ReceiptScreen extends StatefulWidget {
  final int transactionId;
  final int userId;

  const ReceiptScreen({
    super.key,
    required this.transactionId,
    required this.userId,
  });

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  TransactionModel? _transaction;
  Customer? _customer;
  User? _currentUser;
  TransactionModel? _originalDebtTransaction;
  bool _isLoading = true;
  String _errorMessage = '';

  final DateFormat _dateTimeFormatter = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
  final NumberFormat currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadReceiptData();
  }

  Future<void> _loadReceiptData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final currentTransaction = await DatabaseHelper.instance.getTransactionById(widget.transactionId);
      if (currentTransaction == null) throw Exception('Transaksi #${widget.transactionId} tidak ditemukan.');
      _transaction = currentTransaction;

      final user = await DatabaseHelper.instance.getUserById(widget.userId);
      _currentUser = user;

      bool isDebtPaymentReceipt = currentTransaction.metodePembayaran.startsWith('Pembayaran Kredit');

      if (isDebtPaymentReceipt && currentTransaction.idTransaksiHutang != null) {
        _originalDebtTransaction = await DatabaseHelper.instance.getTransactionById(currentTransaction.idTransaksiHutang!);
        if (_originalDebtTransaction?.idPelanggan != null) {
          _customer = await DatabaseHelper.instance.getCustomerById(_originalDebtTransaction!.idPelanggan!);
        }
      } else if (currentTransaction.idPelanggan != null) {
        _customer = await DatabaseHelper.instance.getCustomerById(currentTransaction.idPelanggan!);
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal memuat data struk: ${e.toString()}';
        });
      }
    }
  }

  Widget _buildReceiptItem(Map<String, dynamic> item) {
    // ... (Logika _buildReceiptItem SAMA seperti di file asli Anda) ...
    if (item.containsKey('paid_debt_transaction_id')) {
      return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Pembayaran Hutang (Ref: #${item['paid_debt_transaction_id'] ?? 'N/A'})", style: GoogleFonts.robotoMono(fontSize: 13)),
              // Tidak menampilkan amount di sini karena sudah di total
            ],
          ));
    }
    final String name = item['nama_produk'] ?? 'N/A';
    final int qty = (item['quantity'] ?? 0).toInt();
    final double price = (item['harga_jual'] ?? 0.0).toDouble();
    final double subtotal = (item['subtotal'] ?? (price * qty)).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: Text(name, style: GoogleFonts.robotoMono(fontSize: 13))),
          Expanded(
            flex: 4,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(qty.toString(), style: GoogleFonts.robotoMono(fontSize: 13)),
                Text(currencyFormatter.format(price).replaceAll('Rp', '').trim(), style: GoogleFonts.robotoMono(fontSize: 13)),
                Text(currencyFormatter.format(subtotal).replaceAll('Rp', '').trim(), style: GoogleFonts.robotoMono(fontSize: 13), textAlign: TextAlign.right),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isTotal = false, TextStyle? valueStyle}) {
    // ... (Logika _buildInfoRow SAMA seperti di file asli Anda) ...
    final labelStyle = GoogleFonts.poppins(fontSize: isTotal ? 14 : 12, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, color: Colors.grey.shade700);
    final finalValueStyle = valueStyle ?? GoogleFonts.poppins(fontSize: isTotal ? 14 : 12, fontWeight: isTotal ? FontWeight.bold : FontWeight.w500, color: Colors.black87);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: labelStyle), Text(value, style: finalValueStyle)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Colors.blue.shade800;
    final bool isDebtPaymentReceipt = _transaction?.metodePembayaran.startsWith('Pembayaran Kredit') ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text('Struk Transaksi', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: primaryColor)),
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        shadowColor: Colors.black26,
        surfaceTintColor: Colors.white,
        elevation: 2.5,
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF7F8FC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_errorMessage, style: GoogleFonts.poppins(color: Colors.red), textAlign: TextAlign.center)))
              : _transaction == null
                  ? Center(child: Text('Data transaksi tidak valid.', style: GoogleFonts.poppins()))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 3))]),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Header Struk
                            Text(_currentUser?.storeName ?? 'Nama Toko Anda', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center),
                            const SizedBox(height: 3),
                            Text(_currentUser?.storeAddress ?? 'Alamat Toko Anda', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600), textAlign: TextAlign.center),
                            const SizedBox(height: 5),
                            Text('Telp: ${_currentUser?.phoneNumber ?? '-'}', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600), textAlign: TextAlign.center),
                            const SizedBox(height: 15),
                            const Divider(thickness: 1, color: Colors.black54),
                            // Info Transaksi
                            _buildInfoRow('No. Struk:', "#${_transaction!.id ?? 'N/A'}"),
                            _buildInfoRow('Tanggal:', _dateTimeFormatter.format(_transaction!.tanggalTransaksi)),
                            if (_customer != null) _buildInfoRow('Pelanggan:', _customer!.namaPelanggan),
                            if (isDebtPaymentReceipt && _originalDebtTransaction != null) _buildInfoRow('Ref. Hutang:', '#${_originalDebtTransaction!.id}'),
                            const SizedBox(height: 12),
                            const Divider(thickness: 1, color: Colors.black54),
                            const SizedBox(height: 12),
                            // Judul Item
                            Text(isDebtPaymentReceipt ? "DETAIL PEMBAYARAN" : "DETAIL BARANG", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 8),
                            if (!isDebtPaymentReceipt) // Header Item
                              Padding(
                                padding: const EdgeInsets.only(bottom: 5.0),
                                child: Row(
                                  children: [
                                    Expanded(flex: 3, child: Text('Produk', style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.bold))),
                                    Expanded(flex: 4, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                      Text('Qty', style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.bold)),
                                      Text('Harga', style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.bold)),
                                      Text('Subttl', style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                                    ])),
                                  ],
                                ),
                              ),
                            if (!isDebtPaymentReceipt) const Divider(height: 1, color: Colors.black26),
                            // List Item
                            if (_transaction!.detailItems.isEmpty && !isDebtPaymentReceipt)
                              const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Center(child: Text('- Tidak ada item detail -')))
                            else
                              Column(children: _transaction!.detailItems.map((item) => _buildReceiptItem(item)).toList()),
                            const SizedBox(height: 12),
                            const Divider(thickness: 1, color: Colors.black54),
                            const SizedBox(height: 12),
                            // Total & Pembayaran
                            _buildInfoRow(isDebtPaymentReceipt ? 'JUMLAH BAYAR' : 'TOTAL', currencyFormatter.format(_transaction!.totalBelanja), isTotal: true),
                            const SizedBox(height: 5),
                            _buildInfoRow('Metode Bayar:', _transaction!.metodePembayaran),
                            if (_transaction!.metodePembayaran.contains('Tunai')) ...[
                              if (_transaction!.jumlahBayar != null) _buildInfoRow('Bayar:', currencyFormatter.format(_transaction!.jumlahBayar!)),
                              if (_transaction!.jumlahKembali != null && _transaction!.jumlahKembali! > 0) _buildInfoRow('Kembali:', currencyFormatter.format(_transaction!.jumlahKembali!)),
                            ],
                            if (!isDebtPaymentReceipt && _transaction!.metodePembayaran == 'Kredit')
                              _buildInfoRow('Status:', _transaction!.statusPembayaran, valueStyle: TextStyle(fontSize: 12, color: _transaction!.statusPembayaran == 'Lunas' ? Colors.green.shade700 : Colors.orange.shade800, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 25),
                            Center(child: Text('--- Terima Kasih ---', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600))),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),
    );
  }
}