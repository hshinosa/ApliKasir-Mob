// lib/fitur/manage/report/screens/report_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import 'package:aplikasir_mobile/model/transaction_model.dart';
import 'package:aplikasir_mobile/fitur/checkout/screens/receipt_screen.dart';
import '../providers/report_provider.dart'; // Impor Provider

class ReportScreen extends StatelessWidget {
  // Ubah jadi StatelessWidget
  final int userId;
  const ReportScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ReportProvider(userId: userId),
      child: const _ReportScreenContent(),
    );
  }
}

class _ReportScreenContent extends StatefulWidget {
  const _ReportScreenContent();

  @override
  State<_ReportScreenContent> createState() => _ReportScreenContentState();
}

class _ReportScreenContentState extends State<_ReportScreenContent> {
  // Formatters dan warna bisa tetap di sini atau di provider jika lebih umum
  final DateFormat _dateFormatter = DateFormat('dd MMM yyyy', 'id_ID');
  final DateFormat _monthFormatter = DateFormat('MMMM yyyy', 'id_ID');
  final NumberFormat _currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final NumberFormat _compactCurrencyFormatter = NumberFormat.compactCurrency(
      locale: 'id_ID', symbol: 'Rp ', decimalDigits: 1);

  final Color _primaryColor = Colors.blue.shade700;
  final Color _lightBgColor = Colors.white;
  final Color _scaffoldBgColor = const Color(0xFFF7F8FC);
  final Color _darkTextColor = Colors.black87;
  final Color _greyTextColor = Colors.grey.shade600;

  // Semua state terkait data (_selectedSegment, _selectedDate, statistik, chartData) PINDAH KE PROVIDER

  // initState dan fungsi load data PINDAH KE PROVIDER

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
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

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 10.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Container(
              // Container untuk background ikon
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  Icon(icon, color: color, size: 24), // Ukuran ikon disesuaikan
            ),
            const SizedBox(width: 12),
            Column(
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
                        color: _darkTextColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleTransactionItem(BuildContext context,
      TransactionModel transaction, ReportProvider provider) {
    IconData icon = Icons.receipt_long_outlined;
    Color color = _greyTextColor;
    if (transaction.metodePembayaran == 'Tunai') {
      icon = Icons.payments_outlined;
      color = Colors.green.shade700;
    } else if (transaction.metodePembayaran == 'QRIS') {
      icon = Icons.qr_code_2_outlined;
      color = Colors.blue.shade700;
    } else if (transaction.metodePembayaran == 'Kredit') {
      icon = Icons.credit_card_outlined;
      color = Colors.orange.shade800;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          color: _lightBgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          _dateFormatter.format(transaction.tanggalTransaksi),
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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReceiptScreen(
                transactionId: transaction.id!,
                userId: provider.userId,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reportProvider = context.watch<ReportProvider>();

    String dateFilterLabel = '';
    VoidCallback? onDateFilterTap;

    switch (reportProvider.selectedSegment) {
      case ReportSegment.day:
        dateFilterLabel = _dateFormatter.format(reportProvider.selectedDate);
        onDateFilterTap = () => reportProvider.setSelectedDate(context);
        break;
      case ReportSegment.week:
        dateFilterLabel = reportProvider.selectedWeek != null
            ? "${_dateFormatter.format(reportProvider.selectedWeek!.start)} - ${_dateFormatter.format(reportProvider.selectedWeek!.end)}"
            : "Pilih Minggu";
        onDateFilterTap = () => reportProvider.setSelectedWeek(context);
        break;
      case ReportSegment.month:
        dateFilterLabel = reportProvider.selectedMonth != null
            ? _monthFormatter.format(reportProvider.selectedMonth!)
            : "Pilih Bulan";
        onDateFilterTap = () => reportProvider.setSelectedMonth(context);
        break;
      case ReportSegment.all:
        dateFilterLabel = "Semua Waktu";
        onDateFilterTap = null;
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Laporan Penjualan',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: _primaryColor)),
        backgroundColor: _lightBgColor,
        foregroundColor: _primaryColor,
        elevation: 1.0,
        shadowColor: Colors.black26,
        surfaceTintColor: _lightBgColor,
        centerTitle: true,
      ),
      backgroundColor: _scaffoldBgColor,
      body: RefreshIndicator(
        onRefresh: () => reportProvider.loadAndProcessReports(),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                        color: _lightBgColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ReportSegment>(
                        value: reportProvider.selectedSegment,
                        isExpanded: true,
                        icon: Icon(Icons.arrow_drop_down_rounded,
                            color: _primaryColor, size: 28),
                        style: GoogleFonts.poppins(
                            color: _darkTextColor, fontSize: 14),
                        onChanged: (ReportSegment? newValue) {
                          if (newValue != null)
                            reportProvider.setSelectedSegment(newValue);
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
                              value: segment, child: Text(text));
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (reportProvider.selectedSegment != ReportSegment.all)
                  Expanded(
                    flex: 3,
                    child: InkWell(
                      onTap: onDateFilterTap,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 13.5),
                        decoration: BoxDecoration(
                            color: _lightBgColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                                child: Text(dateFilterLabel,
                                    style: GoogleFonts.poppins(
                                        fontSize: 14, color: _darkTextColor),
                                    overflow: TextOverflow.ellipsis)),
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
            // Kartu Statistik
            if (reportProvider.isLoading &&
                reportProvider.totalSalesCount ==
                    0) // Tampilkan loading hanya jika data awal belum ada
              const Center(
                  child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.0),
                      child: CircularProgressIndicator()))
            else if (!reportProvider.isLoading &&
                reportProvider.errorMessage.isNotEmpty &&
                reportProvider.totalSalesCount == 0)
              Center(
                  child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(reportProvider.errorMessage,
                          style: GoogleFonts.poppins(color: Colors.red),
                          textAlign: TextAlign.center)))
            else
              Column(children: [
                _buildStatCard(
                    "Total Penjualan",
                    reportProvider.totalSalesCount.toString(),
                    Icons.point_of_sale_outlined,
                    Colors.blue.shade700),
                _buildStatCard(
                    "Total Pendapatan",
                    _compactCurrencyFormatter
                        .format(reportProvider.totalRevenue),
                    Icons.monetization_on_outlined,
                    Colors.orange.shade800),
                _buildStatCard(
                    "Total Keuntungan",
                    _compactCurrencyFormatter
                        .format(reportProvider.totalProfit),
                    Icons.trending_up_rounded,
                    Colors.green.shade700),
              ]),
            const SizedBox(height: 25),

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
                        Text("Grafik Pendapatan",
                            style: GoogleFonts.poppins(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        // OutlinedButton.icon( // Tombol unduh bisa dihilangkan dulu jika belum implement
                        //   icon: Icon(Icons.download_outlined, size: 18, color: _primaryColor),
                        //   label: Text("Unduh", style: GoogleFonts.poppins(fontSize: 12, color: _primaryColor)),
                        //   onPressed: () => _showSnackbar("Fitur unduh laporan belum tersedia."),
                        //   style: OutlinedButton.styleFrom(side: BorderSide(color: _primaryColor.withOpacity(0.5)), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        // )
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                        height: 200,
                        child: reportProvider.isLoading
                            ? const Center(child: Text("Memuat data grafik..."))
                            : reportProvider.salesChartData.isEmpty
                                ? Center(
                                    child: Text(
                                        "Tidak ada data penjualan untuk grafik.",
                                        style: GoogleFonts.poppins(
                                            color: _greyTextColor)))
                                : LineChart(
                                    LineChartData(
                                      gridData: FlGridData(
                                          show: true,
                                          drawVerticalLine: false,
                                          horizontalInterval:
                                              reportProvider.chartMaxY > 0
                                                  ? reportProvider.chartMaxY / 4
                                                  : 2500, // Dinamis interval Y
                                          getDrawingHorizontalLine: (value) =>
                                              const FlLine(
                                                  color: Colors.black12,
                                                  strokeWidth: 0.8)),
                                      titlesData: FlTitlesData(
                                        leftTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize:
                                              45, // Ruang untuk label Y
                                          getTitlesWidget: (value, meta) {
                                            if (value == 0 ||
                                                value == meta.max ||
                                                value == meta.min ||
                                                value % (meta.max / 4) <
                                                        (meta.max / 20) &&
                                                    meta.max > 0) {
                                              // Tampilkan beberapa label Y
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                    right: 4.0),
                                                child: Text(
                                                    _compactCurrencyFormatter
                                                        .format(value)
                                                        .replaceAll('Rp', ''),
                                                    style: GoogleFonts.poppins(
                                                        color: _greyTextColor,
                                                        fontSize: 9)),
                                              );
                                            }
                                            return Container();
                                          },
                                        )),
                                        topTitles: const AxisTitles(
                                            sideTitles:
                                                SideTitles(showTitles: false)),
                                        bottomTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                          showTitles: true, reservedSize: 22,
                                          interval: 1, // Coba interval 1
                                          getTitlesWidget: (value, meta) {
                                            final title = reportProvider
                                                    .chartBottomTitles[
                                                value.toInt()];
                                            if (title != null) {
                                              return SideTitleWidget(
                                                  axisSide: meta.axisSide,
                                                  space: 4,
                                                  child: Text(title,
                                                      style: GoogleFonts.poppins(
                                                          fontSize: 10,
                                                          color:
                                                              _greyTextColor)));
                                            }
                                            return Container();
                                          },
                                        )),
                                        rightTitles: const AxisTitles(
                                            sideTitles:
                                                SideTitles(showTitles: false)),
                                      ),
                                      borderData: FlBorderData(
                                          show: true,
                                          border: Border(
                                              bottom: BorderSide(
                                                  color: Colors.grey.shade300),
                                              left: BorderSide(
                                                  color:
                                                      Colors.grey.shade300))),
                                      minY: 0,
                                      maxY: reportProvider
                                          .chartMaxY, // Gunakan maxY dari provider
                                      lineBarsData: [
                                        LineChartBarData(
                                          spots: reportProvider.salesChartData,
                                          isCurved: true, color: _primaryColor,
                                          barWidth: 2.5,
                                          isStrokeCapRound: true,
                                          dotData: const FlDotData(
                                              show:
                                                  true), // Tampilkan titik data
                                          belowBarData: BarAreaData(
                                              show: true,
                                              color: _primaryColor
                                                  .withOpacity(0.1)),
                                        ),
                                      ],
                                      lineTouchData: LineTouchData(
                                        touchTooltipData: LineTouchTooltipData(
                                          getTooltipItems: (touchedSpots) {
                                            return touchedSpots.map((spot) {
                                              return LineTooltipItem(
                                                _currencyFormatter
                                                    .format(spot.y),
                                                TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    fontFamily:
                                                        GoogleFonts.poppins()
                                                            .fontFamily),
                                              );
                                            }).toList();
                                          },
                                        ),
                                      ),
                                    ),
                                  )),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),

            Text("Daftar Transaksi Penjualan",
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            reportProvider.isLoading &&
                    reportProvider.salesTransactionsForDisplay
                        .isEmpty // Loading data awal transaksi
                ? const Center(
                    child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 15.0),
                        child: Text("Memuat transaksi...")))
                : reportProvider.salesTransactionsForDisplay.isEmpty
                    ? Center(
                        child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          reportProvider.errorMessage.isNotEmpty &&
                                  reportProvider.totalSalesCount == 0
                              ? reportProvider
                                  .errorMessage // Tampilkan error jika ada dan belum ada data sales
                              : "Tidak ada transaksi penjualan pada periode ini.",
                          style: GoogleFonts.poppins(color: _greyTextColor),
                          textAlign: TextAlign.center,
                        ),
                      ))
                    : ListView.builder(
                        // Tampilkan daftar transaksi dari provider
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount:
                            reportProvider.salesTransactionsForDisplay.length,
                        itemBuilder: (context, index) {
                          return _buildSimpleTransactionItem(
                              context,
                              reportProvider.salesTransactionsForDisplay[index],
                              reportProvider);
                        },
                      ),
          ],
        ),
      ),
    );
  }
}
