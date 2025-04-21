import 'package:aplikasir_mobile/screen/manage/qris/qris_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Untuk SystemUiOverlayStyle
import 'package:google_fonts/google_fonts.dart';
import 'package:aplikasir_mobile/screen/manage/product/product_screen.dart'; // Impor ProductScreen untuk navigasi
import 'package:aplikasir_mobile/screen/manage/customer/customer_screen.dart'; // Impor ManageScreen untuk navigasi
import 'package:aplikasir_mobile/screen/manage/credit/credit_list_screen.dart'; // Impor CustomerDebtHistoryScreen untuk navigasi
import 'package:aplikasir_mobile/screen/manage/report/report_screen.dart'; // Impor ReportScreen untuk navigasi';

class ManageScreen extends StatelessWidget {
  final int userId;
  const ManageScreen({super.key, required this.userId});

  // --- Helper: Membangun Kartu Menu Kelola (Tetap Sama) ---
  Widget _buildManageCard({
    required BuildContext context,
    required String label,
    required IconData iconPlaceholder,
    required Color iconColor,
    required Color iconBackgroundColor,
    required VoidCallback onTap,
  }) {
    // ... (kode _buildManageCard sama) ...
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.4,
      height: MediaQuery.of(context).size.height * 0.18,
      child: Card(
        elevation: 2.0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        color: Colors.white,
        surfaceTintColor: Colors.white,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: iconBackgroundColor,
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Icon(
                    iconPlaceholder,
                    size: 40,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 12.0),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 33.0, vertical: 19.0),
        child: Wrap(
          spacing: 10.0,
          runSpacing: 10.0,
          alignment: WrapAlignment.center,
          children: [
            // --- Kartu Produk (MODIFIKASI onTap) ---
            _buildManageCard(
              context: context,
              label: 'Produk',
              iconPlaceholder: Icons.inventory_2_outlined,
              iconColor: Colors.orange.shade700,
              iconBackgroundColor: Colors.orange.shade50,
              onTap: () {
                print('Navigasi ke Product Screen');
                // Gunakan Navigator.push ke ProductScreen
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => ProductScreen(userId: userId)));
              },
            ),

            // --- Kartu QRIS (BARU) ---
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
                        builder: (context) => QrisSetupScreen(userId: userId)));
              },
            ),

            // --- Kartu Kredit (BARU) ---
            _buildManageCard(
              context: context,
              label: 'Kredit',
              iconPlaceholder: Icons.receipt_long_outlined,
              iconColor: Colors.teal.shade700,
              iconBackgroundColor: Colors.teal.shade50,
              onTap: () {
                print('Navigasi ke Credit List Screen');
                // *** Navigasi ke CreditListScreen ***
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            CreditListScreen(userId: userId)));
              },
            ),

            // --- Kartu Pelanggan (BARU) ---
            _buildManageCard(
              context: context,
              label: 'Pelanggan',
              iconPlaceholder: Icons.groups_outlined,
              iconColor: Colors.indigo.shade700,
              iconBackgroundColor: Colors.indigo.shade50,
              onTap: () {
                print('Navigasi ke Customer Screen');
                // *** Navigasi ke CustomerScreen ***
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => CustomerScreen(userId: userId)));
              },
            ),

            // --- Kartu Printer ---
            _buildManageCard(
              context: context,
              label: 'Printer',
              iconPlaceholder: Icons.print_outlined,
              iconColor: Colors.blue.shade700,
              iconBackgroundColor: Colors.blue.shade50,
              onTap: () {
                print('Buka Pengaturan Printer');
                // TODO: Tambahkan navigasi PUSH ke halaman Pengaturan Printer (karena ini layar baru)
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Fitur Pengaturan Printer belum dibuat.')));
              },
            ),

            // --- Kartu Laporan ---
            _buildManageCard(
              context: context,
              label: 'Laporan',
              iconPlaceholder: Icons.bar_chart_outlined,
              iconColor: Colors.green.shade700,
              iconBackgroundColor: Colors.green.shade50,
              onTap: () {
                print('Navigasi ke Customer Screen');
                // *** Navigasi ke CustomerScreen ***
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => ReportScreen(userId: userId)));
              },
            ),
          ],
        ),
      ),
    );
  }
}
