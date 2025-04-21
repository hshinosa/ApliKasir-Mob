// screen/manage/report/report_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart'; // Impor package chart
import 'package:aplikasir_mobile/model/transaction_model.dart';
import 'package:aplikasir_mobile/helper/db_helper.dart';
import 'package:aplikasir_mobile/screen/checkout/receipt_screen.dart'; // Impor detail laporan jika perlu
// Impor model lain jika perlu untuk data tambahan

enum ReportSegment { day, week, month, all } // Enum untuk segmen waktu

class ReportScreen extends StatefulWidget {
  final int userId;
  const ReportScreen({super.key, required this.userId});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  // --- State ---
  ReportSegment _selectedSegment = ReportSegment.day; // Default Harian
  DateTime _selectedDate =
      DateTime.now(); // Tanggal terpilih untuk filter Harian
  DateTimeRange? _selectedWeek; // Range untuk filter Mingguan
  DateTime? _selectedMonth; // Bulan terpilih untuk filter Bulanan

  List<TransactionModel> _allTransactions = []; // Semua transaksi user
  List<TransactionModel> _filteredTransactions = []; // Transaksi sesuai filter
  bool _isLoading = true;
  String _errorMessage = '';

  // Statistik
  int _totalSalesCount = 0;
  double _totalRevenue = 0.0; // Total Penjualan (Harga Jual)
  double _totalProfit = 0.0; // Total Keuntungan (Jual - Modal)

  // Data untuk chart (Contoh: List of spots (day, total_sales))
  List<FlSpot> _salesChartData = [];

  // Formatters
  final DateFormat _dateFormatter = DateFormat('dd MMM yyyy', 'id_ID');
  final DateFormat _monthFormatter = DateFormat('MMMM yyyy', 'id_ID');
  final NumberFormat _currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final NumberFormat _compactCurrencyFormatter = NumberFormat.compactCurrency(
      locale: 'id_ID', symbol: 'Rp ', decimalDigits: 1);

  // Warna & Style
  final Color _primaryColor = Colors.blue.shade700; // Warna tema laporan
  final Color _lightBgColor = Colors.white;
  final Color _scaffoldBgColor = const Color(0xFFF7F8FC);
  final Color _darkTextColor = Colors.black87;
  final Color _greyTextColor = Colors.grey.shade600;

  @override
  void initState() {
    super.initState();
    // Set default filter mingguan/bulanan agar tidak null saat pertama kali dipilih
    final now = DateTime.now();
    _selectedWeek = DateTimeRange(
        start: now.subtract(Duration(days: now.weekday - 1)),
        end: now.add(Duration(days: DateTime.daysPerWeek - now.weekday)));
    _selectedMonth = DateTime(now.year, now.month);
    _loadAndProcessReports(); // Muat data awal (harian)
  }

  // --- Fungsi Load & Proses Data ---
  Future<void> _loadAndProcessReports() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      DateTimeRange filterRange = _calculateDateRange();
      print(
          "Loading reports for range: ${filterRange.start} - ${filterRange.end}");

      // Ambil transaksi berdasarkan range waktu
      _allTransactions = await DatabaseHelper.instance.getTransactionsByUserId(
        widget.userId,
        startDate: filterRange.start,
        endDate: filterRange.end,
      );
      print("Fetched ${_allTransactions.length} transactions for the period.");

      // Filter hanya transaksi penjualan (bukan pembayaran hutang) untuk statistik
      _filteredTransactions = _allTransactions
          .where((t) =>
                  t.metodePembayaran == 'Tunai' ||
                  t.metodePembayaran == 'QRIS' ||
                  t.metodePembayaran ==
                      'Kredit' // Masukkan kredit sebagai penjualan
              )
          .toList();

      _calculateStatistics(); // Hitung statistik
      _prepareChartData(); // Siapkan data chart

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading/processing reports: $e");
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat laporan: ${e.toString()}';
      });
    }
  }

  // --- Hitung Range Tanggal Berdasarkan Segmen ---
  DateTimeRange _calculateDateRange() {
    final now = DateTime.now();
    DateTime start;
    DateTime end;

    switch (_selectedSegment) {
      case ReportSegment.day:
        start = DateTime(_selectedDate.year, _selectedDate.month,
            _selectedDate.day); // Awal hari
        end = DateTime(_selectedDate.year, _selectedDate.month,
            _selectedDate.day, 23, 59, 59); // Akhir hari
        break;
      case ReportSegment.week:
        // Gunakan _selectedWeek yang sudah diupdate oleh date picker
        start = _selectedWeek!.start;
        // Set end ke akhir hari dari tanggal akhir minggu
        end = DateTime(_selectedWeek!.end.year, _selectedWeek!.end.month,
            _selectedWeek!.end.day, 23, 59, 59);
        break;
      case ReportSegment.month:
        // Gunakan _selectedMonth yang sudah diupdate
        start = DateTime(_selectedMonth!.year, _selectedMonth!.month, 1);
        // Akhir bulan: hari pertama bulan berikutnya dikurangi 1 hari
        end = DateTime(_selectedMonth!.year, _selectedMonth!.month + 1, 0, 23,
            59, 59); // Trik: hari ke-0 bulan berikutnya
        break;
      case ReportSegment.all:
        // Contoh: Ambil semua data dalam 1 tahun terakhir (atau sesuaikan)
        start = now.subtract(const Duration(days: 365));
        end = now;
        break;
    }
    return DateTimeRange(start: start, end: end);
  }

  // --- Hitung Statistik Penjualan & Keuntungan ---
  void _calculateStatistics() {
    _totalSalesCount =
        _filteredTransactions.length; // Jumlah transaksi penjualan
    _totalRevenue =
        _filteredTransactions.fold(0.0, (sum, t) => sum + t.totalBelanja);

    double totalModalCost = 0;
    for (var transaction in _filteredTransactions) {
      // Akumulasi total modal dari detail item setiap transaksi
      totalModalCost += transaction.detailItems.fold(0.0, (sum, item) {
        final modal = (item['harga_modal'] as num?)?.toDouble() ?? 0.0;
        final qty = (item['quantity'] as num?)?.toInt() ?? 0;
        return sum + (modal * qty);
      });
      // Atau gunakan field totalModal di TransactionModel jika sudah akurat
      // totalModalCost += transaction.totalModal;
    }

    _totalProfit = _totalRevenue - totalModalCost;
    print(
        "Calculated Stats: SalesCount=$_totalSalesCount, Revenue=$_totalRevenue, Profit=$_totalProfit");
  }

  // --- Siapkan Data untuk Grafik (Contoh: Penjualan Harian dalam Seminggu) ---
  void _prepareChartData() {
    // Logika ini perlu disesuaikan berdasarkan segmen yang dipilih
    // Contoh sederhana untuk Harian (tampilkan 7 hari terakhir) atau Mingguan

    Map<int, double> salesPerDay = {}; // Key: hari (1-7), Value: total sales
    final range = _calculateDateRange();
    final startDay = range.start;
    final endDay = range.end;

    // Inisialisasi map untuk semua hari dalam range
    // Ini penting jika range > 7 hari atau untuk segmen bulanan/mingguan
    // ... (logika inisialisasi map sesuai range) ...

    // Contoh: Agregasi data _filteredTransactions berdasarkan hari
    for (var transaction in _filteredTransactions) {
      // Pastikan tanggal transaksi ada dalam range yang dipilih
      if (!transaction.tanggalTransaksi.isBefore(startDay) &&
          !transaction.tanggalTransaksi.isAfter(endDay)) {
        int dayOfWeek =
            transaction.tanggalTransaksi.weekday; // 1 (Mon) - 7 (Sun)
        // Atau gunakan hari dalam bulan/minggu tergantung segmen
        // int dayOfMonth = transaction.tanggalTransaksi.day;
        salesPerDay[dayOfWeek] =
            (salesPerDay[dayOfWeek] ?? 0.0) + transaction.totalBelanja;
      }
    }

    // Konversi ke FlSpot (contoh untuk mingguan)
    List<FlSpot> spots = [];
    for (int i = 1; i <= 7; i++) {
      // Iterasi hari Senin-Minggu
      spots.add(FlSpot(i.toDouble(), salesPerDay[i] ?? 0.0));
    }

    // Jika segmen Bulanan, sumbu X bisa jadi tanggal 1-31
    // Jika segmen Tahunan (atau 'Semua' yg panjang), sumbu X bisa jadi bulan 1-12

    setState(() {
      _salesChartData = spots;
    });
    print("Chart Data Prepared: ${_salesChartData.length} spots");
  }

  // --- Fungsi Pilih Tanggal/Minggu/Bulan ---
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('id', 'ID'), // Set locale ke Indonesia
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadAndProcessReports(); // Muat ulang data
    }
  }

  // Fungsi pilih minggu (lebih kompleks, contoh sederhana)
  Future<void> _selectWeek() async {
    // Contoh sederhana: Ambil minggu yang mengandung _selectedDate saat ini
    // Untuk UI picker minggu yg proper, perlu package/custom widget
    final currentSelection = _selectedWeek ??
        DateTimeRange(
            start: _selectedDate,
            end: _selectedDate.add(const Duration(days: 6)));

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 7)), // Sedikit ke depan
      initialDateRange: currentSelection,
      locale: const Locale('id', 'ID'),
      helpText: 'Pilih Rentang Minggu',
      // Anda bisa coba batasi pemilihan hanya 7 hari
    );

    if (picked != null && picked != _selectedWeek) {
      // Pastikan range adalah 1 minggu jika perlu
      // Untuk simplifikasi, kita gunakan saja hasil picker
      setState(() {
        _selectedWeek = picked;
      });
      _loadAndProcessReports();
    }
  }

  // Fungsi pilih bulan (contoh menggunakan showDatePicker dengan mode bulan)
  Future<void> _selectMonth() async {
    final DateTime initial = _selectedMonth ?? DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month), // Fokus ke bulan
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year, // Mulai dari pilih tahun
      locale: const Locale('id', 'ID'),
      // Tidak ada mode pilih bulan langsung di showDatePicker standar
      // Mungkin perlu package `month_picker_dialog` atau custom
    );

    // Karena tidak ada picker bulan, kita ambil bulan & tahun dari hasil datepicker
    if (picked != null) {
      final pickedMonth = DateTime(picked.year, picked.month);
      if (pickedMonth != _selectedMonth) {
        setState(() {
          _selectedMonth = pickedMonth;
        });
        _loadAndProcessReports();
      }
    }
  }

  // --- Helper Snackbar ---
  void _showSnackbar(String message, {bool isError = false}) {
    /* ... kode sama ... */ if (!mounted) return;
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

  // --- Helper Widget Statistik ---
  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    // HAPUS Expanded di sini
    // return Expanded(
    return Card(
      // Langsung return Card
      elevation: 1.5,
      margin:
          const EdgeInsets.only(bottom: 10.0), // Beri margin bawah antar card
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16.0, vertical: 12.0), // Sesuaikan padding
        child: Row(
          // Gunakan Row untuk ikon dan teks
          children: [
            Icon(icon, color: color, size: 28), // Sedikit perbesar ikon
            const SizedBox(width: 12),
            Column(
              // Teks dalam Column
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: _greyTextColor)),
                const SizedBox(height: 4),
                Text(value,
                    style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: _darkTextColor)), // Sesuaikan size value
              ],
            ),
          ],
        ),
      ),
      // );
    );
  }

  @override
  Widget build(BuildContext context) {
    String dateFilterLabel = '';
    VoidCallback? onDateFilterTap;

    switch (_selectedSegment) {
      case ReportSegment.day:
        dateFilterLabel = _dateFormatter.format(_selectedDate);
        onDateFilterTap = _selectDate;
        break;
      case ReportSegment.week:
        dateFilterLabel =
            "${_dateFormatter.format(_selectedWeek!.start)} - ${_dateFormatter.format(_selectedWeek!.end)}";
        onDateFilterTap = _selectWeek;
        break;
      case ReportSegment.month:
        dateFilterLabel = _monthFormatter.format(_selectedMonth!);
        onDateFilterTap = _selectMonth;
        break;
      case ReportSegment.all:
        dateFilterLabel = "Semua Waktu";
        onDateFilterTap = null; // Tidak ada aksi tap
        break;
    }

    return Scaffold(
      // --- TAMBAHKAN AppBar ---
      appBar: AppBar(
        title: Text('Laporan',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700)), // Warna AppBar
        backgroundColor: _lightBgColor, // Background putih/terang
        foregroundColor: Colors.blue.shade700, // Warna ikon back
        elevation: 1.0,
        shadowColor: Colors.black26,
        surfaceTintColor: _lightBgColor,
        centerTitle: true,
        // Tombol back otomatis ditambahkan oleh Navigator
      ),
      // --- AKHIR TAMBAHAN AppBar ---
      // AppBar tidak dibutuhkan jika ini adalah tab
      backgroundColor: _scaffoldBgColor,
      body: RefreshIndicator(
        onRefresh: _loadAndProcessReports, // Panggil refresh utama
        child: ListView(
          // Gunakan ListView agar bisa scroll keseluruhan jika konten panjang
          padding: const EdgeInsets.all(16.0),
          children: [
            // --- Dropdown Filter Waktu & Tombol Pilih Tanggal ---
            Row(
              children: [
                // Dropdown
                Expanded(
                  flex: 2, // Lebar dropdown
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                        color: _lightBgColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ReportSegment>(
                        value: _selectedSegment,
                        isExpanded: true,
                        icon: Icon(Icons.arrow_drop_down, color: _primaryColor),
                        style: GoogleFonts.poppins(
                            color: _darkTextColor, fontSize: 14),
                        onChanged: (ReportSegment? newValue) {
                          if (newValue != null &&
                              newValue != _selectedSegment) {
                            setState(() {
                              _selectedSegment = newValue;
                            });
                            _loadAndProcessReports(); // Muat ulang data
                          }
                        },
                        items:
                            ReportSegment.values.map((ReportSegment segment) {
                          String text = '';
                          switch (segment) {
                            case ReportSegment.day:
                              text = 'Harian';
                              break;
                            case ReportSegment.week:
                              text = 'Mingguan';
                              break;
                            case ReportSegment.month:
                              text = 'Bulanan';
                              break;
                            case ReportSegment.all:
                              text = 'Semua';
                              break;
                          }
                          return DropdownMenuItem<ReportSegment>(
                            value: segment,
                            child: Text(text),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Tombol Pilih Tanggal/Rentang (jika bukan 'Semua')
                if (_selectedSegment != ReportSegment.all)
                  Expanded(
                    flex: 3, // Lebar tombol tanggal
                    child: InkWell(
                      onTap: onDateFilterTap, // Panggil fungsi pilih tanggal
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 13.5), // Samakan tinggi dgn dropdown
                        decoration: BoxDecoration(
                            color: _lightBgColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(dateFilterLabel,
                                style: GoogleFonts.poppins(
                                    fontSize: 14, color: _darkTextColor)),
                            Icon(Icons.calendar_today_outlined,
                                size: 18, color: _primaryColor),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // --- Kartu Statistik (Gunakan Column) ---
            Column(
              // <-- Ganti Row menjadi Column
              children: [
                _buildStatCard("Penjualan", _totalSalesCount.toString(),
                    Icons.point_of_sale, Colors.blue.shade700),
                // Hapus SizedBox antar card karena sudah ada margin di _buildStatCard
                _buildStatCard(
                    "Pendapatan",
                    _compactCurrencyFormatter.format(_totalRevenue),
                    Icons.monetization_on_outlined,
                    Colors.orange.shade800),
                _buildStatCard(
                    "Keuntungan",
                    _compactCurrencyFormatter.format(_totalProfit),
                    Icons.trending_up,
                    Colors.green.shade700),
              ],
            ),
            // --- Akhir Kartu Statistik ---
            const SizedBox(height: 25),

            // --- Kartu Grafik ---
            Card(
              elevation: 1.5,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              color: _lightBgColor,
              surfaceTintColor: _lightBgColor,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Grafik Penjualan",
                            style: GoogleFonts.poppins(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        // Tombol Download (Placeholder)
                        OutlinedButton.icon(
                          icon: Icon(Icons.download_outlined,
                              size: 18, color: _primaryColor),
                          label: Text("Unduh",
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: _primaryColor)),
                          onPressed: () {
                            _showSnackbar(
                                "Fitur unduh laporan belum tersedia.");
                          },
                          style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                  color: _primaryColor.withOpacity(0.5)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8))),
                        )
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Placeholder Grafik (Gunakan fl_chart)
                    SizedBox(
                        height: 200, // Tinggi grafik
                        child: _isLoading
                            ? const Center(child: Text("Memuat data grafik..."))
                            : _salesChartData.isEmpty
                                ? Center(
                                    child: Text(
                                        "Tidak ada data penjualan untuk grafik.",
                                        style: GoogleFonts.poppins(
                                            color: _greyTextColor)))
                                : LineChart(
                                    // Contoh LineChart
                                    LineChartData(
                                      gridData: FlGridData(
                                          show: true,
                                          drawVerticalLine: false,
                                          horizontalInterval:
                                              _calculateChartInterval(
                                                  _totalRevenue),
                                          getDrawingHorizontalLine: (value) =>
                                              const FlLine(
                                                  color: Colors.black12,
                                                  strokeWidth: 0.8)),
                                      titlesData: FlTitlesData(
                                        // Sembunyikan judul sumbu default
                                        leftTitles: const AxisTitles(
                                            sideTitles:
                                                SideTitles(showTitles: false)),
                                        topTitles: const AxisTitles(
                                            sideTitles:
                                                SideTitles(showTitles: false)),
                                        bottomTitles: AxisTitles(
                                            sideTitles:
                                                _buildBottomTitles()), // Judul bawah (hari/minggu/bulan)
                                        rightTitles: const AxisTitles(
                                            sideTitles:
                                                SideTitles(showTitles: false)),
                                      ),
                                      borderData: FlBorderData(
                                          show: false), // Hilangkan border luar
                                      minY: 0, // Mulai dari 0
                                      lineBarsData: [
                                        LineChartBarData(
                                          spots: _salesChartData,
                                          isCurved: true,
                                          color: _primaryColor,
                                          barWidth: 3,
                                          isStrokeCapRound: true,
                                          dotData: const FlDotData(
                                              show: false), // Titik di data
                                          belowBarData: BarAreaData(
                                              show: true,
                                              color: _primaryColor.withOpacity(
                                                  0.1)), // Area di bawah garis
                                        ),
                                      ],
                                      // Tambahkan tooltip jika diinginkan
                                      lineTouchData: LineTouchData(
                                        touchTooltipData: LineTouchTooltipData(
                                          getTooltipItems: (touchedSpots) {
                                            return touchedSpots.map((spot) {
                                              final yValue = spot.y;
                                              return LineTooltipItem(
                                                _currencyFormatter
                                                    .format(yValue),
                                                const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              );
                                            }).toList();
                                          },
                                        ),
                                      ),
                                    ),
                                    // swapAnimationDuration: const Duration(milliseconds: 250), // Optional
                                    // swapAnimationCurve: Curves.linear, // Optional
                                  )),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),

            // --- Daftar Transaksi Terbaru (Sesuai Filter) ---
            Text("Daftar Transaksi",
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _isLoading
                ? const Center(child: Text("Memuat transaksi..."))
                : _filteredTransactions.isEmpty
                    ? Center(
                        child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          _errorMessage.isNotEmpty
                              ? _errorMessage
                              : "Tidak ada transaksi pada periode ini.",
                          style: GoogleFonts.poppins(color: _greyTextColor),
                          textAlign: TextAlign.center,
                        ),
                      ))
                    : ListView.builder(
                        // Gunakan builder di dalam ListView utama (non-scrollable)
                        shrinkWrap: true, // Penting agar tidak konflik scroll
                        physics:
                            const NeverScrollableScrollPhysics(), // Non-scrollable
                        itemCount: _filteredTransactions.length,
                        itemBuilder: (context, index) {
                          // Gunakan helper dari RiwayatScreen (perlu diimpor atau dicopy)
                          // atau buat helper baru di sini
                          return _buildSimpleTransactionItem(
                              _filteredTransactions[index]);
                        },
                      ),
          ],
        ),
      ),
    );
  }

  // --- Helper untuk Judul Bawah Grafik ---
  SideTitles _buildBottomTitles() {
    late Widget Function(double value, TitleMeta meta) getTitlesWidget;
    double interval = 1;

    switch (_selectedSegment) {
      case ReportSegment.week:
        // Tampilkan label hari (Sen, Sel, ...)
        getTitlesWidget = (value, meta) {
          String text = '';
          switch (value.toInt()) {
            case 1:
              text = 'Sen';
              break;
            case 2:
              text = 'Sel';
              break;
            case 3:
              text = 'Rab';
              break;
            case 4:
              text = 'Kam';
              break;
            case 5:
              text = 'Jum';
              break;
            case 6:
              text = 'Sab';
              break;
            case 7:
              text = 'Min';
              break;
          }
          return SideTitleWidget(
              axisSide: meta.axisSide,
              space: 4,
              child: Text(text,
                  style: GoogleFonts.poppins(
                      fontSize: 10, color: _greyTextColor)));
        };
        interval = 1;
        break;
      case ReportSegment.month:
        // Tampilkan label tanggal (1, 5, 10, ...)
        getTitlesWidget = (value, meta) {
          // Tampilkan hanya kelipatan 5 atau sesuai kebutuhan
          if (value.toInt() % 5 == 0 || value.toInt() == 1) {
            return SideTitleWidget(
                axisSide: meta.axisSide,
                space: 4,
                child: Text(value.toInt().toString(),
                    style: GoogleFonts.poppins(
                        fontSize: 10, color: _greyTextColor)));
          }
          return Container();
        };
        interval = 5; // Tampilkan tiap 5 tanggal
        break;
      case ReportSegment
            .day: // Jika harian, sumbu X mungkin jam? Atau hanya 1 titik?
      case ReportSegment
            .all: // Default Harian/Semua (contoh: hanya tampilkan tanggal awal/akhir)
        getTitlesWidget = (value, meta) => Container(); // Sembunyikan label
        interval = 7; // Default interval
        break;
    }

    return SideTitles(
      showTitles: true,
      reservedSize: 22, // Ruang untuk label bawah
      interval: interval, // Jarak antar label
      getTitlesWidget: getTitlesWidget,
    );
  }

  // --- Helper untuk Interval Grid Horizontal Grafik ---
  double _calculateChartInterval(double maxValue) {
    if (maxValue <= 0) return 10000; // Default jika tidak ada data
    // Buat interval yang 'masuk akal' berdasarkan nilai maksimum
    if (maxValue <= 50000) return 10000;
    if (maxValue <= 100000) return 20000;
    if (maxValue <= 500000) return 100000;
    if (maxValue <= 1000000) return 200000;
    return (maxValue / 5).ceilToDouble(); // Default: bagi 5
  }

  // --- Helper untuk Item Transaksi Sederhana ---
  Widget _buildSimpleTransactionItem(TransactionModel transaction) {
    // Bisa copy/adaptasi dari _buildHistoryItem di RiwayatScreen
    // tapi mungkin lebih simpel di sini
    IconData icon = Icons.receipt_long;
    Color color = Colors.grey;
    switch (transaction.metodePembayaran) {
      case 'Tunai':
        icon = Icons.payments_outlined;
        color = Colors.green;
        break;
      case 'QRIS':
        icon = Icons.qr_code_2;
        color = Colors.blue;
        break;
      case 'Kredit':
        icon = Icons.credit_card;
        color = Colors.orange;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          color: _lightBgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200)),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          _dateFormatter
              .format(transaction.tanggalTransaksi), // Tampilkan tanggal
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          'Metode: ${transaction.metodePembayaran}',
          style: GoogleFonts.poppins(fontSize: 11, color: _greyTextColor),
        ),
        trailing: Text(
          _currencyFormatter.format(transaction.totalBelanja),
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, fontSize: 13, color: _darkTextColor),
        ),
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
          );
        },
      ),
    );
  }
} // End of State
