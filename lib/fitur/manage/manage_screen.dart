// lib/fitur/manage/manage_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Impor semua layar tujuan dan provider yang relevan (jika diperlukan untuk setup navigasi)
import 'package:aplikasir_mobile/fitur/manage/product/screens/product_screen.dart';
// Tidak perlu impor ProductProvider di sini karena ProductScreen akan membuat instancenya sendiri

import 'package:aplikasir_mobile/fitur/manage/qris/screens/qris_setup_screen.dart';
// Tidak perlu impor QrisProvider di sini

import 'package:aplikasir_mobile/fitur/manage/credit/screens/credit_list_screen.dart';
// Tidak perlu impor CreditListProvider di sini

import 'package:aplikasir_mobile/fitur/manage/customer/screens/customer_screen.dart';
// Tidak perlu impor CustomerProvider di sini

import 'package:aplikasir_mobile/fitur/manage/report/screens/report_screen.dart';
// Tidak perlu impor ReportProvider di sini

// Jika ada layar Printer, impor di sini
// import 'package:aplikasir_mobile/fitur/manage/printer/screens/printer_settings_screen.dart';

class ManageScreen extends StatelessWidget {
  final int userId;
  const ManageScreen({super.key, required this.userId});

  // Helper untuk membangun kartu menu
  Widget _buildManageCard({
    required BuildContext context,
    required String label,
    required IconData iconPlaceholder,
    required Color iconColor,
    required Color iconBackgroundColor,
    required VoidCallback onTap,
  }) {
    // Style Kartu
    final cardShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0));
    final cardElevation = 3.0;
    final cardColor = Colors.white;
    final cardSurfaceTintColor = Colors.white;

    // Style Ikon
    final iconSize = MediaQuery.of(context).size.width * 0.085; // Buat ikon sedikit lebih besar
    final iconContainerPadding = const EdgeInsets.all(18.0); // Kurangi padding jika ikon besar
    final iconContainerShape = BoxDecoration(
      color: iconBackgroundColor,
      borderRadius: BorderRadius.circular(12.0),
       boxShadow: [ // Tambahkan shadow lembut pada ikon container
        BoxShadow(
          color: iconColor.withOpacity(0.2),
          blurRadius: 5,
          offset: const Offset(0, 2),
        )
      ]
    );

    // Style Teks Label
    final labelTextStyle = GoogleFonts.poppins(
      fontSize: MediaQuery.of(context).size.width * 0.036, // Ukuran font responsif
      fontWeight: FontWeight.w500,
      color: Colors.grey.shade800, // Warna teks lebih gelap
    );

    return SizedBox(
      // Atur lebar dan tinggi berdasarkan persentase layar atau nilai tetap yang baik
      width: (MediaQuery.of(context).size.width - 48 - 10) / 2, // (lebar layar - padding horizontal - spacing) / 2
      // height: MediaQuery.of(context).size.height * 0.2, // Contoh tinggi responsif
      child: Card(
        elevation: cardElevation,
        shape: cardShape,
        color: cardColor,
        surfaceTintColor: cardSurfaceTintColor,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15.0), // Samakan dengan card shape
          splashColor: iconColor.withOpacity(0.1),
          highlightColor: iconColor.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 10.0), // Padding internal kartu
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: iconContainerPadding,
                  decoration: iconContainerShape,
                  child: Icon(
                    iconPlaceholder,
                    size: iconSize,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 12.0),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: labelTextStyle,
                  maxLines: 1, // Maksimal 1 baris untuk label
                  overflow: TextOverflow.ellipsis, // Jika terlalu panjang, beri elipsis
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Warna dari ReportScreen untuk konsistensi (jika diinginkan)
    // final Color primaryColor = Colors.blue.shade700; // Bisa didefinisikan di sini

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC), // Background konsisten
      // AppBar tidak diperlukan jika ini adalah bagian dari TabBarView di HomePage
      // Jika ini layar terpisah, tambahkan AppBar:
      // appBar: AppBar(
      //   title: Text('Menu Kelola', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: primaryColor)),
      //   backgroundColor: Colors.white,
      //   foregroundColor: primaryColor,
      //   elevation: 1.0,
      //   centerTitle: true,
      // ),
      body: Padding(
        // Beri padding keseluruhan untuk konten
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: GridView.count(
          crossAxisCount: 2, // 2 kartu per baris
          crossAxisSpacing: 12.0, // Jarak horizontal antar kartu
          mainAxisSpacing: 12.0,  // Jarak vertikal antar kartu
          childAspectRatio: 1.1, // Sesuaikan rasio aspek kartu (width / height)
          children: [
            _buildManageCard(
              context: context,
              label: 'Produk',
              iconPlaceholder: Icons.inventory_2_outlined,
              iconColor: Colors.orange.shade700,
              iconBackgroundColor: Colors.orange.shade50,
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => ProductScreen(userId: userId))); // ProductScreen akan membuat ProductProvider
              },
            ),
            _buildManageCard(
              context: context,
              label: 'QRIS',
              iconPlaceholder: Icons.qr_code_scanner_outlined,
              iconColor: Colors.purple.shade700,
              iconBackgroundColor: Colors.purple.shade50,
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => QrisSetupScreen(userId: userId))); // QrisSetupScreen akan membuat QrisProvider
              },
            ),
            _buildManageCard(
              context: context,
              label: 'Kredit',
              iconPlaceholder: Icons.receipt_long_outlined,
              iconColor: Colors.teal.shade700,
              iconBackgroundColor: Colors.teal.shade50,
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => CreditListScreen(userId: userId))); // CreditListScreen akan membuat CreditListProvider
              },
            ),
            _buildManageCard(
              context: context,
              label: 'Pelanggan',
              iconPlaceholder: Icons.groups_outlined,
              iconColor: Colors.indigo.shade700,
              iconBackgroundColor: Colors.indigo.shade50,
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => CustomerScreen(userId: userId))); // CustomerScreen akan membuat CustomerProvider
              },
            ),
            _buildManageCard(
              context: context,
              label: 'Printer',
              iconPlaceholder: Icons.print_outlined,
              iconColor: Colors.blue.shade700,
              iconBackgroundColor: Colors.blue.shade50,
              onTap: () {
                // TODO: Buat PrinterSettingsScreen dan Providernya jika perlu
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Fitur Pengaturan Printer belum dibuat.')));
              },
            ),
            _buildManageCard(
              context: context,
              label: 'Laporan',
              iconPlaceholder: Icons.bar_chart_outlined,
              iconColor: Colors.green.shade700,
              iconBackgroundColor: Colors.green.shade50,
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => ReportScreen(userId: userId))); // ReportScreen akan membuat ReportProvider
              },
            ),
          ],
        ),
      ),
    );
  }
}