// lib/fitur/manage/report/providers/report_provider.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // Impor chart
import 'package:intl/intl.dart';

import 'package:aplikasir_mobile/model/transaction_model.dart';
import 'package:aplikasir_mobile/helper/db_helper.dart';

enum ReportSegment { day, week, month, all }

class ReportProvider extends ChangeNotifier {
  final int userId;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  ReportSegment _selectedSegment = ReportSegment.day;
  DateTime _selectedDate = DateTime.now();
  DateTimeRange? _selectedWeek;
  DateTime? _selectedMonth;

  List<TransactionModel> _allTransactionsForPeriod =
      []; // Transaksi dari DB sesuai periode
  List<TransactionModel> _salesTransactionsForStats =
      []; // Hanya transaksi penjualan untuk statistik

  bool _isLoading = true;
  String _errorMessage = '';

  // Statistik
  int _totalSalesCount = 0;
  double _totalRevenue = 0.0;
  double _totalProfit = 0.0;

  // Data Chart
  List<FlSpot> _salesChartData = [];
  double _chartMaxY = 0; // Untuk skala chart
  Map<int, String> _chartBottomTitles = {}; // Label sumbu X

  // Getters
  ReportSegment get selectedSegment => _selectedSegment;
  DateTime get selectedDate => _selectedDate;
  DateTimeRange? get selectedWeek => _selectedWeek;
  DateTime? get selectedMonth => _selectedMonth;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  List<TransactionModel> get salesTransactionsForDisplay =>
      _salesTransactionsForStats; // Untuk daftar transaksi di UI

  int get totalSalesCount => _totalSalesCount;
  double get totalRevenue => _totalRevenue;
  double get totalProfit => _totalProfit;
  List<FlSpot> get salesChartData => _salesChartData;
  double get chartMaxY => _chartMaxY;
  Map<int, String> get chartBottomTitles => _chartBottomTitles;

  ReportProvider({required this.userId}) {
    final now = DateTime.now();
    _selectedWeek = DateTimeRange(
        start: now.subtract(Duration(days: now.weekday - 1)), // Senin
        end: now
            .add(Duration(days: DateTime.daysPerWeek - now.weekday))); // Minggu
    _selectedMonth = DateTime(now.year, now.month);
    loadAndProcessReports();
  }

  Future<void> loadAndProcessReports() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      DateTimeRange filterRange = _calculateDateRange();
      _allTransactionsForPeriod = await _dbHelper.getTransactionsByUserId(
        userId,
        startDate: filterRange.start,
        endDate: filterRange.end,
      );

      // Filter hanya transaksi penjualan untuk statistik dan daftar di UI
      _salesTransactionsForStats = _allTransactionsForPeriod
          .where((t) =>
                  t.metodePembayaran == 'Tunai' ||
                  t.metodePembayaran == 'QRIS' ||
                  t.metodePembayaran ==
                      'Kredit' // Penjualan kredit dihitung sebagai pendapatan
              )
          .toList();
      // Urutkan berdasarkan tanggal terbaru untuk tampilan daftar
      _salesTransactionsForStats
          .sort((a, b) => b.tanggalTransaksi.compareTo(a.tanggalTransaksi));

      _calculateStatistics();
      _prepareChartData();
    } catch (e) {
      _errorMessage = 'Gagal memuat laporan: ${e.toString()}';
      _resetReportData();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _resetReportData() {
    _salesTransactionsForStats = [];
    _totalSalesCount = 0;
    _totalRevenue = 0.0;
    _totalProfit = 0.0;
    _salesChartData = [];
    _chartMaxY = 0;
    _chartBottomTitles = {};
  }

  DateTimeRange _calculateDateRange() {
    final now = DateTime.now();
    DateTime start;
    DateTime end;

    switch (_selectedSegment) {
      case ReportSegment.day:
        start = DateTime(_selectedDate.year, _selectedDate.month,
            _selectedDate.day, 0, 0, 0);
        end = DateTime(_selectedDate.year, _selectedDate.month,
            _selectedDate.day, 23, 59, 59, 999);
        break;
      case ReportSegment.week:
        start = DateTime(_selectedWeek!.start.year, _selectedWeek!.start.month,
            _selectedWeek!.start.day, 0, 0, 0);
        end = DateTime(_selectedWeek!.end.year, _selectedWeek!.end.month,
            _selectedWeek!.end.day, 23, 59, 59, 999);
        break;
      case ReportSegment.month:
        start =
            DateTime(_selectedMonth!.year, _selectedMonth!.month, 1, 0, 0, 0);
        end = DateTime(_selectedMonth!.year, _selectedMonth!.month + 1, 0, 23,
            59, 59, 999); // Hari ke-0 bulan berikutnya
        break;
      case ReportSegment.all:
        // Ambil dari transaksi paling awal hingga sekarang
        // Ini bisa jadi query berat jika data banyak. Pertimbangkan batasan (misal 1 tahun)
        // Untuk contoh ini, kita batasi 5 tahun
        start = now.subtract(const Duration(days: 365 * 5));
        end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        break;
    }
    return DateTimeRange(start: start, end: end);
  }

  void _calculateStatistics() {
    _totalSalesCount = _salesTransactionsForStats.length;
    _totalRevenue =
        _salesTransactionsForStats.fold(0.0, (sum, t) => sum + t.totalBelanja);

    double totalModalCost = 0;
    for (var transaction in _salesTransactionsForStats) {
      // Gunakan field totalModal dari TransactionModel
      // Ini lebih akurat jika sudah dihitung saat transaksi dibuat
      totalModalCost += transaction.totalModal;
    }
    _totalProfit = _totalRevenue - totalModalCost;
  }

  void _prepareChartData() {
    List<FlSpot> spots = [];
    Map<int, String> bottomTitles = {};
    double maxY = 0;
    final DateFormat dayMonthFormat = DateFormat('d/M');
    final DateFormat monthYearFormat = DateFormat('MMM yy', 'id_ID');
    final DateFormat hourFormat = DateFormat('HH');

    if (_salesTransactionsForStats.isEmpty) {
      _salesChartData = [];
      _chartBottomTitles = {};
      _chartMaxY = 10000; // Default jika tidak ada data
      notifyListeners();
      return;
    }

    Map<double, double> aggregatedSales = {};

    switch (_selectedSegment) {
      case ReportSegment.day:
        // Agregasi per jam
        for (var tx in _salesTransactionsForStats) {
          double hour = tx.tanggalTransaksi.hour.toDouble();
          aggregatedSales[hour] =
              (aggregatedSales[hour] ?? 0) + tx.totalBelanja;
        }
        for (int i = 0; i < 24; i++) {
          // Sumbu X dari 0 (00:00) hingga 23 (23:00)
          double sales = aggregatedSales[i.toDouble()] ?? 0;
          spots.add(FlSpot(i.toDouble(), sales));
          if (sales > maxY) maxY = sales;
          if (i % 4 == 0) {
            // Tampilkan label jam tiap 4 jam
            bottomTitles[i] = hourFormat.format(DateTime(0, 0, 0, i));
          }
        }
        break;
      case ReportSegment.week:
        // Agregasi per hari dalam seminggu
        for (var tx in _salesTransactionsForStats) {
          double dayOfWeek =
              tx.tanggalTransaksi.weekday.toDouble(); // 1 (Mon) - 7 (Sun)
          aggregatedSales[dayOfWeek] =
              (aggregatedSales[dayOfWeek] ?? 0) + tx.totalBelanja;
        }
        List<String> weekDayLabels = [
          'Sen',
          'Sel',
          'Rab',
          'Kam',
          'Jum',
          'Sab',
          'Min'
        ];
        for (int i = 1; i <= 7; i++) {
          double sales = aggregatedSales[i.toDouble()] ?? 0;
          spots.add(FlSpot(i.toDouble(), sales));
          if (sales > maxY) maxY = sales;
          bottomTitles[i] = weekDayLabels[i - 1];
        }
        break;
      case ReportSegment.month:
        // Agregasi per tanggal dalam sebulan
        int daysInMonth =
            DateTime(_selectedMonth!.year, _selectedMonth!.month + 1, 0).day;
        for (var tx in _salesTransactionsForStats) {
          double dayOfMonth = tx.tanggalTransaksi.day.toDouble();
          aggregatedSales[dayOfMonth] =
              (aggregatedSales[dayOfMonth] ?? 0) + tx.totalBelanja;
        }
        for (int i = 1; i <= daysInMonth; i++) {
          double sales = aggregatedSales[i.toDouble()] ?? 0;
          spots.add(FlSpot(i.toDouble(), sales));
          if (sales > maxY) maxY = sales;
          if (i == 1 || i % 5 == 0 || i == daysInMonth) {
            // Tampilkan label untuk tanggal tertentu
            bottomTitles[i] = i.toString();
          }
        }
        break;
      case ReportSegment.all:
        // Agregasi per bulan dalam setahun (misal 12 bulan terakhir)
        DateTime endDate = DateTime.now();
        DateTime startDate = DateTime(endDate.year - 1, endDate.month + 1,
            1); // 12 bulan lalu dari awal bulan depan
        Map<String, double> monthlySales =
            {}; // Key: 'YYYY-MM', Value: total sales

        for (var tx in _salesTransactionsForStats) {
          if (tx.tanggalTransaksi
                  .isAfter(startDate.subtract(const Duration(days: 1))) &&
              tx.tanggalTransaksi
                  .isBefore(endDate.add(const Duration(days: 1)))) {
            String monthKey = DateFormat('yyyy-MM').format(tx.tanggalTransaksi);
            monthlySales[monthKey] =
                (monthlySales[monthKey] ?? 0) + tx.totalBelanja;
          }
        }

        List<String> sortedMonthKeys = monthlySales.keys.toList()..sort();
        if (sortedMonthKeys.length > 12) {
          // Batasi hingga 12 bulan terakhir jika datanya banyak
          sortedMonthKeys =
              sortedMonthKeys.sublist(sortedMonthKeys.length - 12);
        }

        for (int i = 0; i < sortedMonthKeys.length; i++) {
          String monthKey = sortedMonthKeys[i];
          double sales = monthlySales[monthKey] ?? 0;
          spots.add(
              FlSpot(i.toDouble(), sales)); // Sumbu X dari 0 hingga N-1 bulan
          if (sales > maxY) maxY = sales;
          // Label untuk sumbu X: Nama bulan
          try {
            DateTime dateFromKey = DateFormat('yyyy-MM').parse(monthKey);
            bottomTitles[i] = monthYearFormat.format(dateFromKey);
          } catch (_) {}
        }
        break;
    }

    _salesChartData = spots;
    _chartBottomTitles = bottomTitles;
    _chartMaxY = maxY == 0 ? 10000 : (maxY * 1.2); // Beri sedikit padding atas
    // notifyListeners(); // Sudah dipanggil di loadAndProcessReports
  }

  // --- Update State Filter ---
  void setSelectedSegment(ReportSegment segment) {
    if (_selectedSegment != segment) {
      _selectedSegment = segment;
      loadAndProcessReports(); // Muat ulang data
    }
  }

  Future<void> setSelectedDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('id', 'ID'),
    );
    if (picked != null && picked != _selectedDate) {
      _selectedDate = picked;
      loadAndProcessReports();
    }
  }

  Future<void> setSelectedWeek(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedWeek,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 7)), // Sedikit ke depan
      locale: const Locale('id', 'ID'),
      helpText: 'Pilih Rentang Minggu',
      // builder: (context, child) { // Anda bisa styling DateRangePicker
      //   return Theme(
      //     data: ThemeData.light().copyWith(
      //       colorScheme: ColorScheme.light(primary: _primaryColor),
      //     ),
      //     child: child!,
      //   );
      // }
    );
    if (picked != null && picked != _selectedWeek) {
      // Validasi agar range tidak lebih dari 7 hari jika ingin strictly per minggu
      if (picked.duration.inDays > 7) {
        // Ambil 7 hari dari tanggal mulai
        _selectedWeek = DateTimeRange(
            start: picked.start,
            end: picked.start.add(const Duration(days: 6)));
      } else {
        _selectedWeek = picked;
      }
      loadAndProcessReports();
    }
  }

  Future<void> setSelectedMonth(BuildContext context) async {
    final DateTime initial = _selectedMonth ?? DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialEntryMode:
          DatePickerEntryMode.calendarOnly, // Agar langsung kalender
      initialDatePickerMode:
          DatePickerMode.day, // Mulai dari pilih hari, lalu bisa ke bulan/tahun
      locale: const Locale('id', 'ID'),
      // Untuk picker bulan murni, package `month_picker_dialog` lebih baik
    );

    if (picked != null) {
      final pickedMonth = DateTime(picked.year, picked.month);
      if (pickedMonth != _selectedMonth) {
        _selectedMonth = pickedMonth;
        loadAndProcessReports();
      }
    }
  }
}
