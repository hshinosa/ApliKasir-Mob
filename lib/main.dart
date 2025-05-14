// main.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart'; // Impor GoogleFonts

import 'fitur/onboarding/onboarding_screen.dart';
import 'package:aplikasir_mobile/fitur/homepage/homepage_screen.dart';
import 'package:aplikasir_mobile/fitur/login/screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  final int loggedInUserId = prefs.getInt('loggedInUserId') ?? -1;
  final bool onboardingCompleted = prefs.getBool('onboardingCompleted') ?? false;

  Widget initialScreen;
  if (!onboardingCompleted) {
    initialScreen = const OnboardingScreen();
  } else if (isLoggedIn && loggedInUserId != -1) {
    initialScreen = HomePage(userId: loggedInUserId);
  } else {
    initialScreen = const LoginScreen();
  }

  runApp(MyApp(initialScreen: initialScreen));
}

class MyApp extends StatefulWidget {
  final Widget initialScreen;

  const MyApp({super.key, required this.initialScreen});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDateFormattingInitialized = false;
  bool _initializationError = false;
  String _initializationErrorMessage = ''; // Untuk menyimpan pesan error spesifik

  @override
  void initState() {
    super.initState();
    _initializeDependencies();
  }

  Future<void> _initializeDependencies() async {
    try {
      print("Initializing date formatting...");
      await initializeDateFormatting('id_ID', null); // null untuk path data default
      print("Date formatting initialized successfully.");
      if (mounted) {
        setState(() {
          _isDateFormattingInitialized = true;
        });
      }
    } catch (e) {
      print("Error initializing date formatting: $e");
      if (mounted) {
        setState(() {
          _initializationError = true;
          _initializationErrorMessage = "Gagal menginisialisasi format tanggal: ${e.toString()}";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDateFormattingInitialized && !_initializationError) {
      // Tampilan Loading
      return MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white, // Warna background loading
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
                ),
                const SizedBox(height: 20),
                Text(
                  "Memuat aplikasi...",
                  style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ),
        debugShowCheckedModeBanner: false,
      );
    } else if (_initializationError) {
      // Tampilan Error
      return MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline_rounded, color: Colors.red.shade400, size: 60),
                  const SizedBox(height: 16),
                  Text(
                    "Terjadi Kesalahan",
                    style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.red.shade700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _initializationErrorMessage.isNotEmpty
                        ? _initializationErrorMessage
                        : "Tidak dapat memulai aplikasi. Silakan coba lagi nanti.",
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon( // Tombol coba lagi (opsional)
                    icon: const Icon(Icons.refresh),
                    label: const Text("Coba Lagi"),
                    onPressed: () {
                      setState(() { // Reset state dan coba inisialisasi lagi
                        _isDateFormattingInitialized = false;
                        _initializationError = false;
                        _initializationErrorMessage = '';
                      });
                      _initializeDependencies();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
        debugShowCheckedModeBanner: false,
      );
    }

    // Aplikasi Utama
    return MaterialApp(
      title: 'ApliKasir', // Sesuaikan dengan nama aplikasi Anda
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue.shade700, // Warna utama aplikasi Anda
          brightness: Brightness.light, // Default ke tema terang
          // Anda bisa override warna spesifik di sini jika perlu
          // primary: Colors.blue.shade700,
          // secondary: Colors.amber.shade700,
          // error: Colors.red.shade700,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme,
        ).copyWith(
          // Kustomisasi style teks tertentu jika perlu
          titleLarge: GoogleFonts.poppins(fontSize: 22.0, fontWeight: FontWeight.w600),
          titleMedium: GoogleFonts.poppins(fontSize: 18.0, fontWeight: FontWeight.w500),
          bodyMedium: GoogleFonts.poppins(fontSize: 14.0),
          labelLarge: GoogleFonts.poppins(fontSize: 15.0, fontWeight: FontWeight.w600), // Untuk teks tombol
        ),
        appBarTheme: AppBarTheme(
          elevation: 0.8, // Shadow yang lebih halus
          backgroundColor: Colors.white,
          foregroundColor: Colors.blue.shade800, // Untuk ikon dan judul default
          surfaceTintColor: Colors.white, // Mencegah perubahan warna saat scroll di M3
          iconTheme: IconThemeData(color: Colors.blue.shade700), // Warna ikon back, dll.
          titleTextStyle: GoogleFonts.poppins(
            color: Colors.blue.shade800,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 2,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData( // Style default OutlinedButton
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.blue.shade700,
            side: BorderSide(color: Colors.blue.shade700.withOpacity(0.7), width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          )
        ),
        textButtonTheme: TextButtonThemeData( // Style default TextButton
          style: TextButton.styleFrom(
            foregroundColor: Colors.blue.shade700,
            textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          )
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 15.0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: Colors.blue.shade600, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: Colors.red.shade400, width: 1.0),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: Colors.red.shade600, width: 1.5),
          ),
          labelStyle: GoogleFonts.poppins(color: Colors.grey.shade700, fontSize: 14),
          hintStyle: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 14),
          prefixIconColor: Colors.grey.shade600,
          suffixIconColor: Colors.grey.shade600,
          errorStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.red.shade700),
        ),
        cardTheme: CardTheme( // Style default Card
            elevation: 1.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: Colors.white,
            surfaceTintColor: Colors.white,
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0) // Margin default kartu
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData( // Style default FAB
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)) // Bentuk FAB
        ),
        dialogTheme: DialogTheme( // Style default Dialog
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            titleTextStyle: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
            contentTextStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade700)
        ),
        bottomSheetTheme: BottomSheetThemeData( // Style default BottomSheet
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20))
            )
        ),
        useMaterial3: true,
      ),
      home: widget.initialScreen,
      debugShowCheckedModeBanner: false,
    );
  }
}