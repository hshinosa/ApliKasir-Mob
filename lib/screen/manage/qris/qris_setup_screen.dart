// screen/manage/qris/qris_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io'; // Untuk File

class QrisSetupScreen extends StatefulWidget {
  final int userId; // User ID mungkin diperlukan untuk scope penyimpanan

  const QrisSetupScreen({super.key, required this.userId});

  @override
  State<QrisSetupScreen> createState() => _QrisSetupScreenState();
}

class _QrisSetupScreenState extends State<QrisSetupScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final BarcodeScanner _barcodeScanner =
      BarcodeScanner(formats: [BarcodeFormat.qrCode]); // Hanya fokus ke QR Code

  File? _selectedImageFile; // File gambar QRIS yang dipilih
  String? _currentRawQrisData; // Data QRIS mentah yang tersimpan
  String? _scannedQrisData; // Data QRIS mentah dari hasil scan terakhir
  bool _isLoading = false; // Loading saat scan/simpan
  bool _isScanning = false; // Loading spesifik saat scan

  // Kunci SharedPreferences
  static const String qrisDataKey =
      'raw_qris_data'; // Pertimbangkan tambahkan userId jika multi-user

  @override
  void initState() {
    super.initState();
    _loadSavedQrisData(); // Muat data saat layar dibuka
  }

  @override
  void dispose() {
    _barcodeScanner.close();
    super.dispose();
  }

  // Muat data QRIS yang sudah tersimpan
  Future<void> _loadSavedQrisData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _currentRawQrisData = prefs.getString(qrisDataKey);
      });
    } catch (e) {
      print("Error loading saved QRIS data: $e");
      _showSnackbar("Gagal memuat data QRIS tersimpan.", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Fungsi untuk memilih gambar dari galeri atau kamera
  Future<void> _pickImage(ImageSource source) async {
    if (_isScanning) return; // Hindari pick saat sedang scan
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _selectedImageFile = File(pickedFile.path);
          _scannedQrisData = null; // Reset hasil scan sebelumnya
        });
        _scanImageForQrCode(); // Langsung scan setelah gambar dipilih
      }
    } catch (e) {
      print("Error picking image: $e");
      _showSnackbar("Gagal memilih gambar: ${e.toString()}", isError: true);
    }
  }

  // Fungsi untuk scan QR Code dari gambar yang dipilih
  Future<void> _scanImageForQrCode() async {
    if (_selectedImageFile == null) return;
    setState(() {
      _isScanning = true;
      _scannedQrisData = null;
    });

    try {
      final InputImage inputImage =
          InputImage.fromFilePath(_selectedImageFile!.path);
      final List<Barcode> barcodes =
          await _barcodeScanner.processImage(inputImage);

      String? foundQrData;
      if (barcodes.isNotEmpty) {
        // Cari barcode dengan format QR Code
        for (var barcode in barcodes) {
          print(
              "Detected Barcode: Format=${barcode.format.name}, Type=${barcode.type.name}, Value=${barcode.rawValue}");
          if (barcode.format == BarcodeFormat.qrCode &&
              barcode.rawValue != null) {
            foundQrData = barcode.rawValue;
            break; // Ambil QR Code pertama yang valid
          }
        }
      }

      if (foundQrData != null) {
        setState(() {
          _scannedQrisData = foundQrData;
        });
        _showSnackbar("QR Code berhasil dipindai!", isError: false);
      } else {
        setState(() {
          _scannedQrisData = null;
        }); // Reset jika tidak ditemukan
        _showSnackbar("QR Code tidak ditemukan pada gambar.", isError: true);
      }
    } catch (e) {
      print("Error scanning QR Code: $e");
      _showSnackbar("Gagal memindai QR Code: ${e.toString()}", isError: true);
      setState(() {
        _scannedQrisData = null;
      }); // Reset jika error
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  // Fungsi untuk menyimpan data QRIS mentah ke SharedPreferences
  Future<void> _saveQrisData() async {
    if (_scannedQrisData == null || _scannedQrisData!.isEmpty) {
      _showSnackbar("Tidak ada data QRIS untuk disimpan.", isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(qrisDataKey, _scannedQrisData!);
      setState(() {
        _currentRawQrisData =
            _scannedQrisData; // Update tampilan data tersimpan
      });
      _showSnackbar("Data QRIS berhasil disimpan!", isError: false);
    } catch (e) {
      print("Error saving QRIS data: $e");
      _showSnackbar("Gagal menyimpan data QRIS: ${e.toString()}",
          isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Fungsi untuk menghapus data QRIS tersimpan
  Future<void> _deleteQrisData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(qrisDataKey);
      setState(() {
        _currentRawQrisData = null;
        _selectedImageFile = null; // Hapus juga gambar terpilih
        _scannedQrisData = null; // Hapus data hasil scan
      });
      _showSnackbar("Data QRIS berhasil dihapus.", isError: false);
    } catch (e) {
      print("Error deleting QRIS data: $e");
      _showSnackbar("Gagal menghapus data QRIS: ${e.toString()}",
          isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper Snackbar
  void _showSnackbar(String message, {bool isError = false}) {
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

  @override
  Widget build(BuildContext context) {
    final Color primaryColor =
        Colors.blue.shade700; // Sesuaikan warna tema QRIS
    final Color primaryLightColor = Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text('Pengaturan QRIS',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: primaryColor)),
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 1.0,
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF7F8FC),
      body: SingleChildScrollView(
        // Agar bisa discroll jika konten panjang
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, // Lebarkan tombol
          children: [
            Text(
              'Simpan Kode QRIS Anda',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Ambil gambar QRIS statis Anda dari galeri atau kamera. Kode mentah akan disimpan untuk digunakan saat checkout.',
              style: GoogleFonts.poppins(
                  fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            // Area Preview Gambar & Hasil Scan
            Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.7, // Lebar preview
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300)),
                child: Column(
                  children: [
                    // Tampilkan gambar yang dipilih
                    Container(
                      height: 180, // Tinggi area gambar
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _selectedImageFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(_selectedImageFile!,
                                  fit: BoxFit.contain))
                          : Center(
                              child: Icon(Icons.qr_code_rounded,
                                  size: 80, color: Colors.grey.shade400),
                            ),
                    ),
                    const SizedBox(height: 15),
                    // Tombol Pilih Gambar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton.filledTonal(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          tooltip: "Pilih dari Galeri",
                          style: IconButton.styleFrom(
                              backgroundColor: primaryLightColor,
                              foregroundColor: primaryColor),
                        ),
                        IconButton.filledTonal(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined),
                          tooltip: "Ambil dari Kamera",
                          style: IconButton.styleFrom(
                              backgroundColor: primaryLightColor,
                              foregroundColor: primaryColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    // Hasil Scan
                    if (_isScanning)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (_scannedQrisData != null)
                      Column(
                        children: [
                          Text("Hasil Scan:",
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(5)),
                            child: Text(
                              _scannedQrisData!,
                              style: GoogleFonts.robotoMono(
                                  fontSize: 11,
                                  color: Colors
                                      .green.shade800), // Font mono untuk kode
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.save_alt),
                            label: Text("Simpan Kode QRIS Ini",
                                style: GoogleFonts.poppins()),
                            onPressed: _isLoading
                                ? null
                                : _saveQrisData, // Panggil fungsi simpan
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white),
                          )
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 20),

            // Informasi QRIS Tersimpan
            Text("Data QRIS Tersimpan Saat Ini:",
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _currentRawQrisData != null
                    ? Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentRawQrisData!,
                              style: GoogleFonts.robotoMono(
                                  fontSize: 12, color: Colors.black87),
                              maxLines: 4, // Batasi tampilan
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                icon: Icon(Icons.delete_outline,
                                    color: Colors.red.shade700, size: 18),
                                label: Text("Hapus",
                                    style: GoogleFonts.poppins(
                                        color: Colors.red.shade700,
                                        fontSize: 13)),
                                onPressed: _isLoading ? null : _deleteQrisData,
                                style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8)),
                              ),
                            )
                          ],
                        ),
                      )
                    : Center(
                        child: Text(
                          "Belum ada data QRIS yang tersimpan.",
                          style:
                              GoogleFonts.poppins(color: Colors.grey.shade600),
                        ),
                      ),
          ],
        ),
      ),
    );
  }
}
