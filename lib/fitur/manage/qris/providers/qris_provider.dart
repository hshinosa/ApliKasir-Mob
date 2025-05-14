// lib/fitur/manage/qris/providers/qris_provider.dart
import 'dart:io';
import 'dart:convert'; // Untuk utf8.encode
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crclib/catalog.dart'; // Untuk CRC

class QrisProvider extends ChangeNotifier {
  final int userId; // Mungkin berguna untuk scope di masa depan
  final ImagePicker _imagePicker = ImagePicker();
  final BarcodeScanner _barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.qrCode]);

  String? _rawQrisTemplate; // Template mentah yang tersimpan
  String? _scannedQrDataFromImage; // Hasil scan QR dari gambar (untuk setup)
  File? _selectedImageFileForSetup; // File gambar yang DIPILIH untuk setup QRIS

  bool _isLoading = false; // Loading umum untuk load/save/delete template
  bool _isScanningOrPickingImage = false; // Loading saat pilih gambar & scan di setup screen
  String? _errorMessage;
  String? _successMessage;


  // Kunci SharedPreferences (konsisten dengan QrisSetupScreen lama)
  static const String qrisDataKey = 'raw_qris_data';

  // Getters
  String? get rawQrisTemplate => _rawQrisTemplate;
  String? get scannedQrDataFromImage => _scannedQrDataFromImage;
  File? get selectedImageFileForSetup => _selectedImageFileForSetup;
  bool get isLoading => _isLoading;
  bool get isScanningOrPickingImage => _isScanningOrPickingImage;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;


  QrisProvider({required this.userId}) {
    loadSavedQrisTemplate();
  }

  @override
  void dispose() {
    _barcodeScanner.close();
    // Hapus file temporary jika ada saat provider di-dispose
    if (_selectedImageFileForSetup != null && _selectedImageFileForSetup!.existsSync()) {
        _selectedImageFileForSetup!.delete().catchError((e) {
          print("Error deleting temp setup image on dispose: $e");
          return _selectedImageFileForSetup!;
        });
    }
    super.dispose();
  }

  void _clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    // notifyListeners(); // Biasanya dipanggil oleh method utama
  }

  void _clearScanAndImageSelection() {
    if (_selectedImageFileForSetup != null && _selectedImageFileForSetup!.existsSync()) {
        _selectedImageFileForSetup!.delete().catchError((e) {
          print("Error deleting temp setup image: $e");
          return _selectedImageFileForSetup!;
        });
    }
    _selectedImageFileForSetup = null;
    _scannedQrDataFromImage = null;
    // _clearMessages(); // Jangan clear message global di sini, mungkin ada pesan lain
    // notifyListeners(); // Akan dipanggil oleh method yang memanggil ini
  }

  Future<void> loadSavedQrisTemplate() async {
    _isLoading = true;
    _clearMessages();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      _rawQrisTemplate = prefs.getString(qrisDataKey);
      _successMessage = _rawQrisTemplate != null ? null : null; // Tidak perlu pesan sukses untuk load
    } catch (e) {
      _errorMessage = "Gagal memuat template QRIS tersimpan: ${e.toString()}";
      print("Error loading QRIS template: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> pickAndScanImageForSetup(ImageSource source) async {
    if (_isScanningOrPickingImage) return;
    _isScanningOrPickingImage = true;
    _clearMessages();
    _clearScanAndImageSelection(); // Bersihkan state scan sebelumnya
    notifyListeners();

    try {
      final XFile? pickedFile = await _imagePicker.pickImage(source: source, imageQuality: 85);
      if (pickedFile != null) {
        _selectedImageFileForSetup = File(pickedFile.path);
        notifyListeners(); // Update UI untuk tampilkan gambar terpilih
        
        final InputImage inputImage = InputImage.fromFilePath(_selectedImageFileForSetup!.path);
        final List<Barcode> barcodes = await _barcodeScanner.processImage(inputImage);

        String? foundQrData;
        if (barcodes.isNotEmpty) {
          for (var barcode in barcodes) {
            if (barcode.format == BarcodeFormat.qrCode && barcode.rawValue != null) {
              foundQrData = barcode.rawValue;
              break;
            }
          }
        }

        if (foundQrData != null) {
          _scannedQrDataFromImage = foundQrData;
          _successMessage = "QR Code berhasil dipindai dari gambar!";
        } else {
          _errorMessage = "QR Code tidak ditemukan pada gambar yang dipilih.";
          // Jangan hapus _selectedImageFileForSetup agar user bisa lihat gambar yg gagal di-scan
        }
      } else {
        _errorMessage = "Pemilihan gambar dibatalkan.";
      }
    } catch (e) {
      _errorMessage = "Gagal memproses gambar: ${e.toString()}";
       // Hapus gambar jika terjadi error, agar tidak ada preview gambar yg error
      _clearScanAndImageSelection();
    } finally {
      _isScanningOrPickingImage = false;
      notifyListeners();
    }
  }


  Future<bool> saveScannedQrisDataAsTemplate() async {
    if (_scannedQrDataFromImage == null || _scannedQrDataFromImage!.isEmpty) {
      _clearMessages();
      _errorMessage = "Tidak ada data QRIS dari hasil scan untuk disimpan sebagai template.";
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _clearMessages();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(qrisDataKey, _scannedQrDataFromImage!);
      _rawQrisTemplate = _scannedQrDataFromImage;
      _clearScanAndImageSelection(); // Bersihkan UI scan setelah berhasil disimpan
      _successMessage = "Template QRIS berhasil disimpan!";
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = "Gagal menyimpan template QRIS: ${e.toString()}";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteSavedQrisTemplate() async {
    _isLoading = true;
    _clearMessages();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(qrisDataKey);
      _rawQrisTemplate = null;
      _clearScanAndImageSelection(); // Bersihkan UI scan juga
      _successMessage = "Template QRIS berhasil dihapus.";
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = "Gagal menghapus template QRIS: ${e.toString()}";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Untuk QrisDisplayScreen: menghasilkan string QRIS dinamis
  String? generateDynamicQrisForDisplay(double totalAmount) {
    if (_rawQrisTemplate == null || _rawQrisTemplate!.isEmpty) {
      // Tidak set _errorMessage di sini karena ini dipanggil dari layar lain
      // Layar pemanggil yang akan handle jika template null
      print("QRIS Provider: Template QRIS belum diatur untuk generate QR dinamis.");
      return null;
    }
    
    try {
      // Pastikan panjang template cukup untuk substring
      if (_rawQrisTemplate!.length <= 4) throw Exception("Template QRIS tidak valid (terlalu pendek).");
      
      String qrisWithoutCrc = _rawQrisTemplate!.substring(0, _rawQrisTemplate!.length - 4);
      
      // Validasi apakah template sudah dinamis (010212) atau masih statis (010211)
      if (!qrisWithoutCrc.contains("010212")) {
          // Jika masih statis, coba ubah ke dinamis
          if (qrisWithoutCrc.contains("010211")) {
              qrisWithoutCrc = qrisWithoutCrc.replaceFirst('010211', '010212');
              print("QRIS Provider: Template diubah dari statis (010211) ke dinamis (010212).");
          } else {
              // Jika tidak ada 010211 atau 010212, mungkin template tidak standar
              throw Exception("Template QRIS tidak mengandung indicator point of initiation method (010211/010212).");
          }
      }

      String payloadStep1 = qrisWithoutCrc; // Sekarang sudah pasti 010212

      // Cari posisi untuk menyisipkan tag nominal (tag '54')
      // Tag '54' (Transaction Amount) harus disisipkan SEBELUM tag '58' (Country Code)
      // atau SEBELUM tag '59' (Merchant Name) jika '58' tidak ada.
      // Urutan umum: ...[Tag Amount '54']...[Tag Country Code '58']...[Tag Merchant Name '59']...
      const String countryCodeTagId = '58';
      const String merchantNameTagId = '59';
      int insertPos = -1;

      // Coba cari posisi setelah tag '53' (Transaction Currency) jika ada, atau sebelum '58'
      // Ini adalah pendekatan yang lebih baik, namun untuk simplifikasi, kita tetap pada '58' atau '59'.
      
      // Cari posisi untuk menyisipkan tag nominal.
      // QRIS spec: Amount (54) should be before Country Code (58) or Merchant Name (59)
      // So we find 58 or 59, and insert 54 *before* it.

      int pos58 = payloadStep1.indexOf(countryCodeTagId);
      int pos59 = payloadStep1.indexOf(merchantNameTagId);

      if (pos58 != -1 && (pos59 == -1 || pos58 < pos59)) {
          insertPos = pos58;
      } else if (pos59 != -1) {
          insertPos = pos59;
      }

      if (insertPos == -1 || insertPos % 2 != 0) {
          // Jika tidak ditemukan '58' atau '59', atau posisinya ganjil (tidak valid untuk TLV)
          // coba cari posisi sebelum tag '62' (Additional Data Field Template)
          const String additionalDataTagId = '62';
          int pos62 = payloadStep1.indexOf(additionalDataTagId);
          if (pos62 != -1 && pos62 % 2 == 0) {
              insertPos = pos62;
          } else {
            throw Exception("Tidak dapat menemukan posisi valid untuk menyisipkan nominal (tag '58', '59', atau '62' tidak ditemukan/valid).");
          }
      }
      
      String amountValue = totalAmount.toInt().toString();
      if (amountValue.isEmpty || totalAmount < 0) amountValue = '0';
      if (amountValue.length > 13) { // Sesuai standar EMV, max 13 digit untuk amount
          throw Exception("Jumlah transaksi terlalu besar (maksimal 13 digit).");
      }
      String amountLength = amountValue.length.toString().padLeft(2, '0');
      String amountTag = '54$amountLength$amountValue';

      String payloadBeforeCrc = payloadStep1.substring(0, insertPos) + amountTag + payloadStep1.substring(insertPos);
      
      // Hitung CRC
      List<int> bytes = utf8.encode(payloadBeforeCrc);
      var crcCalculator = Crc16(); // Default CRC-16/CCITT-FALSE
      var crcValue = crcCalculator.convert(bytes);
      String crcString = crcValue.toRadixString(16).toUpperCase().padLeft(4, '0');

      final String finalPayload = payloadBeforeCrc + '6304' + crcString; // '6304' adalah tag untuk CRC
      
      // _errorMessage = null; // Tidak set error di sini
      // notifyListeners(); // Tidak perlu notify dari sini
      return finalPayload;

    } catch (e) {
      print("Error generating dynamic QRIS: $e");
      // Tidak set _errorMessage di sini
      // notifyListeners();
      return null; // Kembalikan null jika gagal generate
    }
  }
}