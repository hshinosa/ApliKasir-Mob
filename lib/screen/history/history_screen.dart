// screen/history/history_screen.dart (Sesuaikan path jika perlu)
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:aplikasir_mobile/model/transaction_model.dart';
import 'package:aplikasir_mobile/helper/db_helper.dart';
import 'package:aplikasir_mobile/screen/checkout/receipt_screen.dart'; // Impor ReceiptScreen

class RiwayatScreen extends StatefulWidget {
  final int userId;

  const RiwayatScreen({super.key, required this.userId});

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  int _selectedFilterIndex = 0; // 0: Semua, 1: Transaksi, 2: Kredit

  List<TransactionModel> _allTransactions = []; // Semua transaksi user
  List<TransactionModel> _filteredTransactions = []; // Transaksi yg ditampilkan
  bool _isLoading = true;
  String _errorMessage = '';

  // Formatters
  final DateFormat _dateFormatter = DateFormat('dd MMM yyyy', 'id_ID');
  final DateFormat _timeFormatter = DateFormat('HH:mm', 'id_ID');
  final NumberFormat _currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  // --- Fungsi Fetch Data Riwayat Transaksi ---
  Future<void> _loadHistory() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      // Ambil SEMUA transaksi untuk user ini
      final transactions =
          await DatabaseHelper.instance.getTransactionsByUserId(widget.userId);
      if (!mounted) return;
      setState(() {
        _allTransactions = transactions;
        _filterHistory(); // Panggil filter setelah data dimuat
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading transaction history: $e");
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat riwayat: ${e.toString()}';
      });
    }
  }

  // --- Fungsi filter (Sekarang filter _allTransactions) ---
  void _filterHistory() {
    if (!mounted) return;
    setState(() {
      switch (_selectedFilterIndex) {
        case 1: // Transaksi (Penjualan Tunai, QRIS, & Pembayaran Kredit)
          _filteredTransactions = _allTransactions
              .where((t) =>
                  t.metodePembayaran == 'Tunai' ||
                  t.metodePembayaran == 'QRIS' ||
                  t.metodePembayaran.startsWith('Pembayaran Kredit'))
              .toList();
          break;
        case 2: // Kredit (Hanya Penjualan Kredit - Lunas atau Belum)
          _filteredTransactions = _allTransactions
              .where((t) => t.metodePembayaran == 'Kredit')
              .toList();
          break;
        default: // Semua
          _filteredTransactions = List.from(_allTransactions); // Salin semua
          break;
      }
    });
  }

  // --- Helper: Filter Chip ---
  Widget _buildFilterChip(String label, int index) {
    bool isSelected = _selectedFilterIndex == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onTap: () {
          if (_selectedFilterIndex != index) {
            // Hanya filter jika indeks berubah
            setState(() {
              _selectedFilterIndex = index;
            });
            _filterHistory(); // Panggil filter
          }
        },
        child: Container(
          /* ... Style chip sama ... */ padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade600 : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
              width: 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.blue.shade100,
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    )
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: isSelected ? Colors.white : Colors.blueGrey.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Helper History Item (Menampilkan TransactionModel) ---
  Widget _buildHistoryItem(TransactionModel transaction) {
    IconData iconData;
    Color iconBgColor;
    Color iconColor;
    String title = 'Transaksi';
    String subtitle = '';
    Color amountColor = Colors.grey.shade800;
    double amount = transaction.totalBelanja; // Amount yg ditampilkan

    // Logika penentuan ikon, warna, judul, subtitle, amount color (SAMA seperti sebelumnya)
    if (transaction.metodePembayaran == 'Tunai') {
      iconData = Icons.payments_outlined;
      iconBgColor = Colors.green.shade50;
      iconColor = Colors.green.shade700;
      title = 'Penjualan Tunai';
      subtitle = _timeFormatter.format(transaction.tanggalTransaksi);
      amountColor = Colors.green.shade700;
    } else if (transaction.metodePembayaran == 'QRIS') {
      iconData = Icons.qr_code_scanner;
      iconBgColor = Colors.blue.shade50;
      iconColor = Colors.blue.shade700;
      title = 'Pembayaran QRIS';
      subtitle = _timeFormatter.format(transaction.tanggalTransaksi);
      amountColor = Colors.green.shade700;
    } else if (transaction.metodePembayaran == 'Kredit') {
      iconData = Icons.credit_card_off_outlined;
      iconBgColor = Colors.orange.shade50;
      iconColor = Colors.orange.shade700;
      title = 'Penjualan Kredit';
      subtitle = 'Status: ${transaction.statusPembayaran}';
      amountColor = transaction.statusPembayaran == 'Lunas'
          ? Colors.grey.shade500
          : Colors.orange.shade800;
    } else if (transaction.metodePembayaran.startsWith('Pembayaran Kredit')) {
      iconData = Icons.check_circle;
      iconBgColor = Colors.teal.shade50;
      iconColor = Colors.teal.shade700;
      title = 'Pembayaran Hutang';
      subtitle =
          'via ${transaction.metodePembayaran.split(' ').last} (#${transaction.idTransaksiHutang ?? 'N/A'})';
      amountColor = Colors.teal.shade700;
      amount = transaction.jumlahBayar ??
          transaction.totalBelanja; // Tampilkan jumlah bayar jika ada
    } else {
      iconData = Icons.receipt_long_outlined;
      iconBgColor = Colors.grey.shade100;
      iconColor = Colors.grey.shade700;
      title = 'Transaksi Lain';
      subtitle = _timeFormatter.format(transaction.tanggalTransaksi);
    }

    return GestureDetector(
      onTap: () {
        // Navigasi ke struk
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReceiptScreen(
              transactionId: transaction.id!,
              userId: widget.userId,
            ),
          ),
        ).then(
            (_) => _loadHistory()); // Reload saat kembali dari struk (opsional)
      },
      child: Container(
        /* ... Dekorasi item sama ... */
        margin: const EdgeInsets.only(bottom: 10.0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1.2,
          ),
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            /* ... Ikon ... */ Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                iconData,
                color: iconColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /* ... Judul & Subtitle ... */ Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                /* ... Tanggal & Jumlah ... */ Text(
                  _dateFormatter.format(transaction.tanggalTransaksi),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _currencyFormatter.format(amount),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: amountColor,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Tidak perlu memanggil getFilteredHistoryItems() di sini lagi
    // karena _filteredTransactions diupdate oleh _filterHistory() via setState

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20),
              // --- Filter Chips ---
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.045,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildFilterChip("Semua", 0),
                    _buildFilterChip(
                        "Transaksi", 1), // Tunai, QRIS, Bayar Kredit
                    _buildFilterChip("Kredit", 2), // Penjualan Kredit
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // --- Judul "Riwayat Terbaru" ---
              Padding(
                padding: const EdgeInsets.only(left: 4.0, bottom: 12.0),
                child: Text(
                  'Riwayat Terbaru',
                  style: GoogleFonts.poppins(
                    fontSize: MediaQuery.of(context).size.width * 0.045,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              // --- Daftar Riwayat (Scrollable) ---
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage.isNotEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                _errorMessage,
                                style: GoogleFonts.poppins(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        // Cek _allTransactions untuk pesan awal 'belum ada riwayat'
                        : _allTransactions.isEmpty
                            ? Center(
                                child: Text(
                                  'Belum ada riwayat transaksi.',
                                  style: GoogleFonts.poppins(
                                      color: Colors.grey.shade500),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            // Cek _filteredTransactions untuk pesan 'tidak ada filter'
                            : _filteredTransactions.isEmpty
                                ? Center(
                                    child: Text(
                                      'Tidak ada riwayat untuk filter ini.',
                                      style: GoogleFonts.poppins(
                                          color: Colors.grey.shade500),
                                      textAlign: TextAlign.center,
                                    ),
                                  )
                                : ListView.builder(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    itemCount: _filteredTransactions
                                        .length, // Gunakan list terfilter
                                    itemBuilder: (context, index) {
                                      return _buildHistoryItem(
                                          _filteredTransactions[
                                              index]); // Kirim TransactionModel
                                    },
                                  ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
