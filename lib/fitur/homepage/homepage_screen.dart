// lib/fitur/homepage/homepage_screen.dart
import 'package:aplikasir_mobile/fitur/checkout/providers/checkout_providers.dart';
import 'package:aplikasir_mobile/model/product_model.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart'; // Import Provider

// --- Impor Layar Tab ---
import '../history/screens/history_screen.dart'; // Sesuaikan path
import '../history/providers/history_provider.dart'; // Provider untuk history
import '../manage/manage_screen.dart'; // Sesuaikan path
import '../profile/screens/profile_screen.dart'; // Sesuaikan path
import '../checkout/screens/checkout_screen.dart'; // Sesuaikan path

// --- Impor Provider & Screen Baru ---
import 'providers/homepage_provider.dart'; // Provider baru
import 'screens/home_product_list_screen.dart'; // Screen baru untuk list produk

// Hapus import model/db_helper dari sini jika tidak digunakan langsung
// import '../../../model/product_model.dart';
// import '../../../helper/db_helper.dart';

class HomePage extends StatefulWidget {
  final int userId;
  const HomePage({super.key, required this.userId});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  // State & logika produk pindah ke HomepageProvider
  final List<GlobalKey> _navItemKeys = List.generate(4, (_) => GlobalKey());
  final GlobalKey _bottomAppBarKey = GlobalKey();
  double _indicatorLeftOffset = 10.0; // Posisi awal indikator
  static const double desiredIndicatorWidth = 35.0;
  static const double indicatorHeight = 4.0;
  // Judul AppBar tetap di sini
  final List<String> _appBarTitles = ['ApliKasir', 'Riwayat', 'Kelola', 'Akun'];

  // Screen options akan diupdate dengan provider
  late List<Widget> _screenOptions;

  @override
  void initState() {
    super.initState();
    print("HomePage initState - User ID: ${widget.userId}");

    // _screenOptions sekarang hanya menginisialisasi kerangka
    _screenOptions = [
      // Tab 0: Beranda (akan diisi dengan HomeProductListScreen via provider)
      Container(),
      // Tab 1: Riwayat (dibungkus provider sendiri)
      ChangeNotifierProvider<HistoryProvider>(
        create: (_) => HistoryProvider(userId: widget.userId),
        child: const HistoryScreen(),
      ),
      // Tab 2: Kelola
      ManageScreen(userId: widget.userId),
      // Tab 3: Akun
      AccountScreen(userId: widget.userId),
    ];

    _updateScreenOptions(); // Panggil setelah _screenOptions diinisialisasi

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateIndicatorPositionSafe(); // Untuk indikator BottomNav
    });
    // _searchHomeController & listenernya pindah ke HomeProductListScreen
  }

  @override
  void dispose() {
    print("HomePage dispose");
    // Hapus dispose search controller dari sini
    super.dispose();
  }

  void _showInfoSnackbar(String message,
      {Duration duration = const Duration(seconds: 2)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void _changeTab(int index) {
    if (index >= 0 &&
        index < _screenOptions.length &&
        index != _selectedIndex) {
      setState(() {
        _selectedIndex = index;
      });
      // Jika pindah dari tab Beranda, clear cart (opsional)
      if (_selectedIndex != 0 &&
          context.read<HomepageProvider>().checkoutCart.isNotEmpty) {
        context.read<HomepageProvider>().clearCheckoutCart();
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateIndicatorPositionSafe();
      });
    }
  }

  void _updateScreenOptions() {
    // Tab 0: Beranda (dengan providernya)
    _screenOptions[0] = ChangeNotifierProvider<HomepageProvider>(
      // Key diperlukan jika widget tree berubah dan provider harus re-create
      key: ValueKey('homepageProvider_${widget.userId}'),
      create: (_) => HomepageProvider(userId: widget.userId),
      child: const HomeProductListScreen(),
    );
    // Screen lain sudah diinisialisasi di initState
  }

  void _proceedToCheckout() {
    final homepageProvider = context.read<HomepageProvider>(); // Baca provider
    if (homepageProvider.checkoutCart.isEmpty) {
      _showInfoSnackbar('Keranjang checkout masih kosong.');
      return;
    }

    // Dapatkan produk yang ada di keranjang dari provider
    List<Product> productsInCart = homepageProvider.productsInCart;
    // Validasi stok lagi tepat sebelum checkout
    bool stockSufficient = true;
    for (var product in productsInCart) {
      final cartQty = homepageProvider.checkoutCart[product.id];
      if (cartQty != null && cartQty > product.jumlahProduk) {
        _showErrorSnackbar(
            'Stok ${product.namaProduk} tidak cukup (tersisa ${product.jumlahProduk}). Checkout dibatalkan.');
        stockSufficient = false;
        // Optional: Refresh data produk dari provider
        homepageProvider.loadHomeProducts();
        break;
      }
    }
    if (!stockSufficient) return;

    if (productsInCart.isNotEmpty && mounted) {
      print(
          "Navigating to Checkout with ${productsInCart.length} product types. Cart: ${homepageProvider.checkoutCart}");
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => ChangeNotifierProvider<CheckoutProvider>(
            create: (_) => CheckoutProvider(
              userId: widget.userId,
              initialCartQuantities: Map.from(homepageProvider.checkoutCart),
              initialCartProducts: List.from(productsInCart),
            ),
            child: const CheckoutScreen(),
          ),
        ),
      ).then((_) {
        // Dijalankan setelah CheckoutScreen ditutup (pop)
        if (mounted) {
          // Selalu refresh produk dan bersihkan keranjang di HomePage setelah kembali dari checkout
          // Tidak peduli hasil checkoutnya, karena bisa jadi user batal
          // Provider Checkout harusnya handle sendiri untuk tidak lanjut jika dibatalkan.
          print(
              "Returned from checkout. Clearing cart and reloading products.");
          homepageProvider.clearCheckoutCart();
          homepageProvider.loadHomeProducts();
        }
      });
    } else {
      _showErrorSnackbar("Keranjang kosong atau produk tidak valid.");
    }
  }

  Widget _buildBottomNavItem({
    required GlobalKey itemKey,
    required IconData selectedIcon,
    required IconData unselectedIcon,
    required String label,
    required int index,
  }) {
    bool isSelected = _selectedIndex == index;
    Color itemColor = isSelected ? Colors.blue.shade700 : Colors.grey.shade600;
    return Expanded(
      key: itemKey,
      child: InkWell(
        onTap: () => _changeTab(index),
        splashColor: Colors.blue.withOpacity(0.1),
        highlightColor: Colors.blue.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isSelected ? selectedIcon : unselectedIcon,
                  color: itemColor, size: 25),
              Padding(
                padding: const EdgeInsets.only(top: 3.0),
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                      color: itemColor,
                      fontSize: 11.5,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _updateIndicatorPositionSafe() {
    // Kode sama seperti sebelumnya
    final selectedKey = _navItemKeys[_selectedIndex];
    final appBarKeyContext = _bottomAppBarKey.currentContext;
    const double horizontalAdjustment = 1.0;

    if (selectedKey.currentContext != null && appBarKeyContext != null) {
      try {
        final RenderBox itemRenderBox =
            selectedKey.currentContext!.findRenderObject() as RenderBox;
        final RenderBox appBarRenderBox =
            appBarKeyContext.findRenderObject() as RenderBox;

        if (!itemRenderBox.attached || !appBarRenderBox.attached) {
          print("Warning: RenderBox is not attached during indicator update.");
          return;
        }

        final Offset itemOffsetInAppBar = appBarRenderBox
            .globalToLocal(itemRenderBox.localToGlobal(Offset.zero));
        final double itemWidth = itemRenderBox.size.width;
        // Adjustment factor to truly center. Experiment with 4.0 to 5.0
        final double centeredLeft =
            itemOffsetInAppBar.dx + (itemWidth - desiredIndicatorWidth) / 4.5;
        final double adjustedLeft = centeredLeft + horizontalAdjustment;

        if (mounted && (adjustedLeft - _indicatorLeftOffset).abs() > 0.1) {
          // Threshold to prevent rapid small updates
          setState(() => _indicatorLeftOffset = adjustedLeft);
        } else if (mounted &&
            _indicatorLeftOffset == 10.0 &&
            adjustedLeft != 10.0) {
          // Initial position update if not default
          setState(() => _indicatorLeftOffset = adjustedLeft);
        }
      } catch (e) {
        print("Error calculating indicator position: $e");
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _updateIndicatorPositionSafe();
          });
        }
      }
    } else {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _updateIndicatorPositionSafe();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Gunakan context.watch untuk mendapatkan HomepageProvider di widget ini jika diperlukan
    // Khususnya untuk FAB Checkout
    final homepageProvider =
        _selectedIndex == 0 ? context.watch<HomepageProvider>() : null;

    final double bottomAppBarHeight = MediaQuery.of(context).size.height * 0.1;

    return Scaffold(
      appBar: AppBar(
        title: _selectedIndex == 0
            ? Image.asset('assets/images/logo_utama.png',
                height: MediaQuery.of(context).size.width * 0.085,
                fit: BoxFit.contain)
            : Text(_appBarTitles[_selectedIndex],
                style: GoogleFonts.poppins(
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 24)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue.shade800,
        elevation: 2.5,
        shadowColor: Colors.black26,
        surfaceTintColor: Colors.white,
        automaticallyImplyLeading: false,
        titleSpacing: 20.0,
      ),
      backgroundColor: const Color(0xFFF7F8FC),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screenOptions,
      ),
      floatingActionButton: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            bottom: 20.0,
            left: 30.0,
            child: Visibility(
              visible: _selectedIndex == 0,
              child: FloatingActionButton.extended(
                heroTag: 'scanFAB_homepage',
                onPressed: () {
                  _showInfoSnackbar('Fitur Scan belum diimplementasikan.');
                },
                backgroundColor: Colors.blue.shade600,
                icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                label: Text('Scan',
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                elevation: 4.0,
              ),
            ),
          ),
          Positioned(
            bottom: 20.0,
            right: 30.0,
            child: Visibility(
              // Dapatkan visibility dan label dari provider jika _selectedIndex == 0
              visible: _selectedIndex == 0 &&
                  (homepageProvider?.checkoutCart.isNotEmpty ?? false),
              child: FloatingActionButton.extended(
                heroTag: 'checkoutFAB_homepage',
                onPressed: _proceedToCheckout,
                backgroundColor: Colors.green.shade600,
                icon: const Icon(Icons.shopping_cart_checkout,
                    color: Colors.white),
                label: Text(
                    // Dapatkan jumlah item dari provider jika _selectedIndex == 0
                    'Checkout (${homepageProvider?.totalCartItems ?? 0})',
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                elevation: 4.0,
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: BottomAppBar(
        key: _bottomAppBarKey,
        elevation: 15.0,
        shadowColor: Colors.black26,
        color: Colors.white,
        surfaceTintColor: Colors.white,
        height: bottomAppBarHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  _buildBottomNavItem(
                      itemKey: _navItemKeys[0],
                      selectedIcon: Icons.home_filled,
                      unselectedIcon: Icons.home_outlined,
                      label: 'Beranda',
                      index: 0),
                  _buildBottomNavItem(
                      itemKey: _navItemKeys[1],
                      selectedIcon: Icons.history,
                      unselectedIcon: Icons.history_outlined,
                      label: 'Riwayat',
                      index: 1),
                  _buildBottomNavItem(
                      itemKey: _navItemKeys[2],
                      selectedIcon: Icons.dashboard_customize,
                      unselectedIcon: Icons.dashboard_customize_outlined,
                      label: 'Kelola',
                      index: 2),
                  _buildBottomNavItem(
                      itemKey: _navItemKeys[3],
                      selectedIcon: Icons.person,
                      unselectedIcon: Icons.person_outline,
                      label: 'Akun',
                      index: 3),
                ],
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              left: _indicatorLeftOffset,
              top: -5, // Slight offset above the bottom bar
              width: desiredIndicatorWidth,
              height: indicatorHeight,
              child: Container(
                decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    borderRadius: BorderRadius.circular(indicatorHeight / 2),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 3,
                          offset: Offset(0, 1))
                    ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
