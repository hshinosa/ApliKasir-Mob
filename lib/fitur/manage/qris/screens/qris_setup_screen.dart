// lib/fitur/manage/qris/screens/qris_setup_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/qris_provider.dart'; // Impor provider

class QrisSetupScreen extends StatelessWidget {
  final int userId;
  const QrisSetupScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => QrisProvider(userId: userId),
      child: const _QrisSetupScreenContent(),
    );
  }
}

class _QrisSetupScreenContent extends StatefulWidget {
  const _QrisSetupScreenContent();

  @override
  State<_QrisSetupScreenContent> createState() => _QrisSetupScreenContentState();
}

class _QrisSetupScreenContentState extends State<_QrisSetupScreenContent> {
  File? _selectedImageFileForDisplay; // Define the variable

  // Fungsi pick image sekarang hanya memanggil provider
  Future<void> _pickImageAndScan(ImageSource source, QrisProvider provider) async {
    // Provider akan handle state isScanningOrPickingImage
    await provider.pickAndScanImageForSetup(source);
    // Snackbar akan di-handle oleh listener di build method atau setelah await jika diperlukan
  }

  void _showSnackbar(String message, {bool isError = false, BuildContext? Ctx}) {
    final currentContext = Ctx ?? context;
    if (!currentContext.mounted) return;

    ScaffoldMessenger.of(currentContext).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qrisProvider = context.watch<QrisProvider>();
    final Color primaryColor = Colors.blue.shade700;
    final Color primaryLightColor = Colors.white;

    // Listener untuk pesan dari provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (qrisProvider.errorMessage != null && mounted) {
         _showSnackbar(qrisProvider.errorMessage!, isError: true);
         // Provider bisa punya method clearMessages() yang dipanggil setelah ini
      }
      if (qrisProvider.successMessage != null && mounted) {
         _showSnackbar(qrisProvider.successMessage!, isError: false);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('Pengaturan Template QRIS', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: primaryColor)),
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 1.0,
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF7F8FC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Simpan Template QRIS Statis Anda', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text('Ambil gambar QRIS statis dari merchant Anda (GOPAY, DANA, OVO, dll). Kode mentah akan disimpan untuk menghasilkan QRIS dinamis saat checkout.', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600), textAlign: TextAlign.center),
            const SizedBox(height: 30),

            Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.75, // Sedikit lebih lebar
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                child: Column(
                  children: [
                    Container(
                      height: 180, width: double.infinity,
                      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                      child: qrisProvider.selectedImageFileForSetup != null
                          ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(qrisProvider.selectedImageFileForSetup!, fit: BoxFit.contain))
                          : Center(child: Icon(Icons.qr_code_rounded, size: 80, color: Colors.grey.shade400)),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.photo_library_outlined, size: 18),
                          label: Text("Galeri", style: GoogleFonts.poppins(fontSize: 13)),
                          onPressed: qrisProvider.isScanningOrPickingImage ? null : () => _pickImageAndScan(ImageSource.gallery, qrisProvider),
                          style: ElevatedButton.styleFrom(backgroundColor: primaryLightColor, foregroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        ),
                        ElevatedButton.icon(
                           icon: const Icon(Icons.camera_alt_outlined, size: 18),
                          label: Text("Kamera", style: GoogleFonts.poppins(fontSize: 13)),
                          onPressed: qrisProvider.isScanningOrPickingImage ? null : () => _pickImageAndScan(ImageSource.camera, qrisProvider),
                          style: ElevatedButton.styleFrom(backgroundColor: primaryLightColor, foregroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    if (qrisProvider.isScanningOrPickingImage && qrisProvider.selectedImageFileForSetup != null)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Column(children: [CircularProgressIndicator(strokeWidth: 2), SizedBox(height: 5), Text("Memindai...")],))
                    else if (qrisProvider.scannedQrDataFromImage != null)
                      Column(children: [
                        Text("Hasil Scan (Calon Template):", style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(5)),
                          child: Text(qrisProvider.scannedQrDataFromImage!, style: GoogleFonts.robotoMono(fontSize: 11, color: Colors.green.shade800), textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.save_alt_rounded, size: 20),
                          label: Text("Simpan Template Ini", style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                          onPressed: qrisProvider.isLoading || qrisProvider.isScanningOrPickingImage ? null : () async {
                             bool success = await qrisProvider.saveScannedQrisDataAsTemplate();
                             // Snackbar sudah dihandle oleh listener di atas
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        )
                      ])
                    else if (qrisProvider.selectedImageFileForSetup != null && !qrisProvider.isScanningOrPickingImage && qrisProvider.errorMessage != null && qrisProvider.errorMessage!.contains("QR Code tidak ditemukan"))
                       Padding( // Pesan jika scan gagal tapi gambar ada
                         padding: const EdgeInsets.only(top:8.0),
                         child: Text(qrisProvider.errorMessage!, style: GoogleFonts.poppins(color: Colors.orange.shade800, fontSize: 12), textAlign: TextAlign.center,),
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 20),

            Text("Template QRIS Tersimpan Saat Ini:", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            (qrisProvider.isLoading && qrisProvider.rawQrisTemplate == null) // Loading awal data tersimpan
                ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2)))
                : qrisProvider.rawQrisTemplate != null
                    ? Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(qrisProvider.rawQrisTemplate!, style: GoogleFonts.robotoMono(fontSize: 12, color: Colors.black87), maxLines: 4, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: qrisProvider.isLoading // Disable tombol hapus saat proses simpan/hapus lain berjalan
                                ? Padding(padding: const EdgeInsets.all(8.0), child: SizedBox(width:18, height:18, child:CircularProgressIndicator(strokeWidth: 2, color: Colors.red.shade300)))
                                : TextButton.icon(
                                    icon: Icon(Icons.delete_outline, color: Colors.red.shade700, size: 18),
                                    label: Text("Hapus Template", style: GoogleFonts.poppins(color: Colors.red.shade700, fontSize: 13)),
                                    onPressed: qrisProvider.isScanningOrPickingImage ? null : () async {
                                      // Snackbar sudah dihandle listener
                                    },
                                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                                  ),
                            )
                          ],
                        ),
                      )
                    : Center(
                        child: Text("Belum ada template QRIS yang tersimpan.", style: GoogleFonts.poppins(color: Colors.grey.shade600)),
                      ),
            
            if(qrisProvider.selectedImageFileForSetup != null || qrisProvider.scannedQrDataFromImage != null)
              Padding(
                padding: const EdgeInsets.only(top: 25.0, bottom: 10.0),
                child: TextButton(
                  onPressed: qrisProvider.isScanningOrPickingImage ? null : () {
                    qrisProvider.clearUiScanState(); // Panggil method clear dari provider
                    setState(() { _selectedImageFileForDisplay = null; }); // Reset display lokal
                  },
                  child: Text("Bersihkan Pilihan Gambar & Hasil Scan", style: GoogleFonts.poppins(color: Colors.grey.shade700, fontSize: 12)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}