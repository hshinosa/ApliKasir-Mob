// main.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart'; // Impor tetap diperlukan
import 'screen/onboarding/onboarding_screen.dart';
import 'package:aplikasir_mobile/screen/homepage/homepage_screen.dart';
import 'package:aplikasir_mobile/screen/login/login_screen.dart';
// ... impor lain jika ada

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- HAPUS INISIALISASI DARI SINI ---
  // await initializeDateFormatting('id_ID', ''); // Tidak dipanggil di sini lagi
  // --- AKHIR PENGHAPUSAN ---

  // Logika SharedPreferences tetap sama
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  final int loggedInUserId = prefs.getInt('loggedInUserId') ?? -1;
  final bool onboardingCompleted =
      prefs.getBool('onboardingCompleted') ?? false;

  Widget initialScreen;
  if (!onboardingCompleted) {
    initialScreen = const OnboardingScreen();
  } else if (isLoggedIn && loggedInUserId != -1) {
    initialScreen = HomePage(userId: loggedInUserId);
  } else {
    initialScreen = const LoginScreen();
  }

  // Kirim initialScreen ke MyApp (yang sekarang stateful)
  runApp(MyApp(initialScreen: initialScreen));
}

// --- UBAH MyApp MENJADI StatefulWidget ---
class MyApp extends StatefulWidget {
  final Widget initialScreen;

  const MyApp({super.key, required this.initialScreen});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDateFormattingInitialized = false; // Status inisialisasi
  bool _initializationError = false; // Status error inisialisasi

  @override
  void initState() {
    super.initState();
    _initializeDependencies(); // Panggil fungsi inisialisasi
  }

  // Fungsi untuk inisialisasi dependensi asinkron
  Future<void> _initializeDependencies() async {
    try {
      // --- LAKUKAN INISIALISASI DI SINI ---
      print("Initializing date formatting...");
      await initializeDateFormatting(
          'id_ID', ''); // Lakukan inisialisasi di sini
      print("Date formatting initialized successfully.");
      if (mounted) {
        setState(() {
          _isDateFormattingInitialized =
              true; // Set status jadi true jika sukses
        });
      }
    } catch (e) {
      print("Error initializing date formatting: $e");
      if (mounted) {
        setState(() {
          _initializationError = true; // Tandai jika ada error
        });
        // Tampilkan pesan error jika diperlukan
        // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal inisialisasi format tanggal.")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tampilkan loading atau error state selama inisialisasi belum selesai
    if (!_isDateFormattingInitialized && !_initializationError) {
      // Tampilan Loading Sederhana
      return const MaterialApp(
        home: Scaffold(
          body: Center(
              child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 10),
              Text("Inisialisasi..."),
            ],
          )),
        ),
        debugShowCheckedModeBanner: false,
      );
    } else if (_initializationError) {
      // Tampilan Error Sederhana
      return const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              "Terjadi kesalahan saat memulai aplikasi.",
              style: TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        debugShowCheckedModeBanner: false,
      );
    }

    // Jika inisialisasi selesai dan tidak error, tampilkan aplikasi utama
    return MaterialApp(
      title: 'ApliKasir',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      // Gunakan initialScreen yang diterima dari main()
      home: widget.initialScreen,
      debugShowCheckedModeBanner: false,
    );
  }
}
// --- AKHIR PERUBAHAN MyApp ---
