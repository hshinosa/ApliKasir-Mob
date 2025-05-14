import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aplikasir_mobile/fitur/login/screens/login_screen.dart'; // Pastikan path impor benar
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart'; // Impor SharedPreferences

// --- Data untuk Carousel (Tetap Sama) ---
final List<String> illustrationPaths = [
  'assets/images/art1.png',
  'assets/images/art2.png',
  'assets/images/art2.png',
];

final List<String> titles = [
  "Pilihan tepat terpercaya\nuntuk membantu usahamu",
  "Kelola Stok & Penjualan\ndengan Efisien",
  "Laporan Keuangan\nOtomatis & Akurat",
];

final List<String> descriptions = [
  "ApliKasir adalah pilihan tepat dan terpercaya untuk anda mengelola keuangan usaha anda dengan lebih mudah",
  "Pantau inventaris secara real-time dan catat setiap transaksi tanpa repot.",
  "Dapatkan insight bisnis berharga melalui laporan yang mudah dipahami.",
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    )..value = (0 + 1) / illustrationPaths.length;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  Widget _buildPageIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 5.0),
      height: 10.0,
      width: 10.0,
      decoration: BoxDecoration(
        color: isActive ? Colors.blue[700] : Colors.grey[300],
        shape: BoxShape.circle,
      ),
    );
  }

  // --- Fungsi untuk menandai onboarding selesai dan navigasi ---
  Future<void> _completeOnboardingAndNavigate() async {
    print('Onboarding Selesai. Navigasi ke Login Screen');
    // Dapatkan instance SharedPreferences
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    // Simpan status onboarding selesai
    await prefs.setBool('onboardingCompleted', true);

    // Pastikan widget masih terpasang sebelum navigasi
    if (!mounted) return;

    // Ganti halaman ke LoginScreen, user tidak bisa kembali ke onboarding
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final int totalPages = illustrationPaths.length;
    // Tetap hitung tinggi card bawah
    final double bottomCardHeight = screenSize.height * 0.45;

    assert(totalPages == titles.length && titles.length == descriptions.length);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: SafeArea(
        child: Column(
          // Layout utama tetap Column
          children: <Widget>[
            // --- Spasi Atas ---
            SizedBox(
                height: screenSize.height * 0.03), // Kurangi sedikit spasi atas

            // --- Carousel Section (PageView) - DIBUNGKUS Flexible ---
            Flexible(
              // <-- Gunakan Flexible di sini
              // Tidak perlu flex factor jika hanya satu Flexible/Expanded
              child: PageView.builder(
                // Hapus SizedBox pembungkus PageView
                controller: _pageController,
                itemCount: totalPages,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                  double newProgress = (_currentPage + 1) / totalPages;
                  _progressController.animateTo(
                    newProgress,
                    curve: Curves.easeInOut,
                  );
                },
                itemBuilder: (context, index) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Image.asset(
                      illustrationPaths[index],
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: Center(
                            child: Text(
                              'Gagal memuat gambar\n(${illustrationPaths[index]})',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(color: Colors.red),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),

            // --- Spasi antara Carousel dan Card ---
            // SizedBox(height: 10), // Hapus atau kurangi spasi tetap ini jika perlu

            // --- Konten Card Putih di Bawah (Tinggi Tetap) ---
            Container(
              height: bottomCardHeight, // Tinggi tetap
              width: screenSize.width * 0.9, // Lebar 90%
              margin: const EdgeInsets.only(
                  top: 10, bottom: 15), // Tambah margin atas & bawah sedikit
              padding: const EdgeInsets.symmetric(
                  horizontal: 30.0,
                  vertical: 30.0), // Sesuaikan padding internal jika perlu
              decoration: BoxDecoration(
                  // Style card (sama)
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    )
                  ]),
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween, // Konten merapat atas-bawah
                children: <Widget>[
                  // --- Teks Judul dan Deskripsi ---
                  // Gunakan Flexible agar teks bisa menyusut jika terlalu panjang
                  // untuk tinggi card yang tersedia (meskipun jarang terjadi di sini)
                  Flexible(
                    fit: FlexFit.loose, // Bisa lebih kecil dari ruang yang ada
                    child: SingleChildScrollView(
                      // Agar teks panjang tetap bisa discroll DI DALAM card
                      physics:
                          const BouncingScrollPhysics(), // Efek scroll halus
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            titles[_currentPage],
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 21, // Sedikit lebih kecil mungkin?
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 12), // Sedikit kurangi jarak
                          Text(
                            descriptions[_currentPage],
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 16.5, // Sedikit lebih kecil mungkin?
                              color: Colors.grey[600],
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // --- Indikator dan Tombol Next ---
                  Padding(
                    // Beri sedikit padding agar tidak terlalu mepet bawah
                    padding: const EdgeInsets.only(top: 15.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        // Indikator Dots
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(totalPages, (index) {
                            return _buildPageIndicator(index == _currentPage);
                          }),
                        ),

                        // Tombol Next dengan Arc Progress
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Progress Arc
                              AnimatedBuilder(
                                animation: _progressController,
                                builder: (context, child) {
                                  return CustomPaint(
                                    size: const Size(60, 60),
                                    painter: _ProgressArcPainter(
                                      progress: _progressController.value,
                                      color: Colors.blue.shade100,
                                      strokeWidth: 4.0,
                                    ),
                                  );
                                },
                              ),
                              // Tombol Biru
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                    color: Colors.blue[700],
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(0.3),
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      )
                                    ]),
                                child: IconButton(
                                  icon: const Icon(Icons.arrow_forward,
                                      color: Colors.white),
                                  onPressed: () {
                                    if (_currentPage < totalPages - 1) {
                                      _pageController.nextPage(
                                        duration:
                                            const Duration(milliseconds: 400),
                                        curve: Curves.easeInOut,
                                      );
                                    } else {
                                      print('Navigasi ke Login Screen');
                                      _completeOnboardingAndNavigate();
                                    }
                                  },
                                  iconSize: 24,
                                  padding: EdgeInsets.zero,
                                  splashRadius: 25,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Hapus Spacer dan SizedBox bawah, biarkan Column mengatur
          ],
        ),
      ),
    );
  }
}

// --- Class _ProgressArcPainter (Tetap Sama) ---
class _ProgressArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _ProgressArcPainter({
    required this.progress,
    required this.color,
    this.strokeWidth = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double center = size.width / 2;
    final double radius = center - strokeWidth / 2;
    final Offset centerOffset = Offset(center, center);
    final Rect rect = Rect.fromCircle(center: centerOffset, radius: radius);

    const double startAngle = -math.pi / 2;
    final double sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(covariant _ProgressArcPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        color != oldDelegate.color ||
        strokeWidth != oldDelegate.strokeWidth;
  }
}
