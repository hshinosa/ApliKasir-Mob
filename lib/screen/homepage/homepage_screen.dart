// screen/homepage/homepage_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:io'; // Untuk File gambar produk
import 'dart:async'; // Import async (meskipun tidak dipakai timer lagi)

// --- Impor Layar Tab ---
import 'package:aplikasir_mobile/screen/history/history_screen.dart';
import 'package:aplikasir_mobile/screen/manage/manage_screen.dart';
import 'package:aplikasir_mobile/screen/profile/profile_screen.dart';
import 'package:aplikasir_mobile/screen/checkout/checkout_screen.dart'; // Import CheckoutScreen

// --- Impor untuk data produk ---
import 'package:aplikasir_mobile/model/product_model.dart';
import 'package:aplikasir_mobile/helper/db_helper.dart';

class HomePage extends StatefulWidget {
  final int userId;
  const HomePage({super.key, required this.userId});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  // === State Beranda ===
  final TextEditingController _searchHomeController = TextEditingController();
  final NumberFormat currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  List<Product> _homeAllProducts = [];
  List<Product> _homeFilteredProducts = [];
  bool _homeIsLoading = true;
  String _homeErrorMessage = '';
  bool _sortAscending = true;
  final Map<int, int> _checkoutCart = {};

  // === State Bottom Nav ===
  final List<GlobalKey> _navItemKeys = List.generate(4, (_) => GlobalKey());
  final GlobalKey _bottomAppBarKey = GlobalKey();
  double _indicatorLeftOffset = 10.0;
  static const double desiredIndicatorWidth = 35.0;
  static const double indicatorHeight = 4.0;
  final List<String> _appBarTitles = ['ApliKasir', 'Riwayat', 'Kelola', 'Akun'];
  late List<Widget> _screenOptions;

  @override
  void initState() {
    super.initState();
    print("HomePage initState - User ID: ${widget.userId}");

    _screenOptions = List.filled(4, Container());
    _updateScreenOptions();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHomeProducts();
      _updateIndicatorPositionSafe();
    });
    _searchHomeController.addListener(_filterHomeProducts);
  }

  // --- Snackbar Helpers ---
  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    if (ScaffoldMessenger.maybeOf(context) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      print("Snackbar Error: ScaffoldMessenger not found.");
    }
  }

  void _showInfoSnackbar(String message,
      {Duration duration = const Duration(seconds: 2)}) {
    if (!mounted) return;
    if (ScaffoldMessenger.maybeOf(context) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: duration,
        ),
      );
    } else {
      print("Snackbar Info: ScaffoldMessenger not found.");
    }
  }
  // --- End Snackbar Helpers ---

  @override
  void dispose() {
    print("HomePage dispose");
    _searchHomeController.removeListener(_filterHomeProducts);
    _searchHomeController.dispose();
    super.dispose();
  }

  void _changeTab(int index) {
    if (index >= 0 &&
        index < _screenOptions.length &&
        index != _selectedIndex) {
      setState(() {
        _selectedIndex = index;
        if (index != 0) {
          _checkoutCart.clear();
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateIndicatorPositionSafe();
      });
    }
  }

  void _updateScreenOptions() {
    _screenOptions[0] = _HomeProductView(
      key: const ValueKey('homeProductView'),
      userId: widget.userId,
      isLoading: _homeIsLoading,
      errorMessage: _homeErrorMessage,
      allProducts: _homeAllProducts,
      filteredProducts: _homeFilteredProducts,
      checkoutCart: _checkoutCart,
      searchController: _searchHomeController,
      sortAscending: _sortAscending,
      onRefresh: _loadHomeProducts,
      onSortToggle: () {
        if (mounted) {
          setState(() {
            _sortAscending = !_sortAscending;
            _sortHomeProducts();
          });
        }
      },
      onQuantityChanged: _updateCheckoutQuantity,
      currencyFormatter: currencyFormatter,
    );

    if (_screenOptions[1] is Container) {
      _screenOptions[1] = RiwayatScreen(userId: widget.userId);
      _screenOptions[2] = ManageScreen(userId: widget.userId);
      _screenOptions[3] = AccountScreen(userId: widget.userId);
    }
  }

  void _updateCheckoutQuantity(int productId, int newQuantity) {
    if (!mounted) return;

    final product = _homeAllProducts.firstWhere((p) => p.id == productId,
        orElse: () => Product(
            idPengguna: -1,
            namaProduk: 'N/A',
            kodeProduk: '',
            jumlahProduk: -1,
            hargaModal: 0,
            hargaJual: 0));

    if (product.jumlahProduk == -1) {
      print("Error: Product ID $productId not found for cart update.");
      return;
    }

    if (newQuantity > product.jumlahProduk) {
      _showErrorSnackbar(
          'Stok ${product.namaProduk} tidak mencukupi (tersisa ${product.jumlahProduk}).');
      return;
    }

    setState(() {
      if (newQuantity > 0) {
        _checkoutCart[productId] = newQuantity;
      } else {
        _checkoutCart.remove(productId);
      }
      print("Cart updated: $_checkoutCart");
    });
  }

  Future<void> _loadHomeProducts() async {
    print("HomePage: Loading home products...");
    if (!mounted) return;
    if (_homeIsLoading && _homeAllProducts.isNotEmpty) {
      print("Load skipped: Already loading or has data.");
      return;
    }

    setState(() {
      _homeIsLoading = true;
      _homeErrorMessage = '';
    });

    try {
      final products =
          await DatabaseHelper.instance.getProductsByUserId(widget.userId);
      print("HomePage: Fetched ${products.length} products.");
      if (!mounted) return;

      setState(() {
        _homeAllProducts = products;
        _homeFilteredProducts = List.from(_homeAllProducts);
        _sortHomeProducts();
        _homeIsLoading = false;
        _homeErrorMessage = '';
      });
    } catch (e, stacktrace) {
      print("HomePage: Error loading products: $e\n$stacktrace");
      if (!mounted) return;
      setState(() {
        _homeErrorMessage = 'Gagal memuat produk: ${e.toString()}';
        _homeIsLoading = false;
        _homeAllProducts = [];
        _homeFilteredProducts = [];
      });
    }
  }

  void _filterHomeProducts() {
    if (!mounted) return;
    final query = _searchHomeController.text.toLowerCase().trim();
    print("Filtering products with query: '$query'");
    setState(() {
      if (query.isEmpty) {
        _homeFilteredProducts = List.from(_homeAllProducts);
      } else {
        _homeFilteredProducts = _homeAllProducts.where((product) {
          final nameLower = product.namaProduk.toLowerCase();
          final codeLower = product.kodeProduk.toLowerCase();
          return nameLower.contains(query) || codeLower.contains(query);
        }).toList();
      }
      _sortHomeProducts();
    });
  }

  void _sortHomeProducts() {
    if (_homeFilteredProducts.isEmpty) return;
    print("Sorting products ${_sortAscending ? 'A-Z' : 'Z-A'}");
    _homeFilteredProducts.sort((a, b) {
      int comparison =
          a.namaProduk.toLowerCase().compareTo(b.namaProduk.toLowerCase());
      return _sortAscending ? comparison : -comparison;
    });
  }

  void _proceedToCheckout() {
    if (_checkoutCart.isEmpty) {
      if (!mounted) return;
      _showInfoSnackbar('Keranjang checkout masih kosong.');
      return;
    }

    List<Product> productsInCart = [];
    List<int> missingProductIds = [];

    _checkoutCart.forEach((productId, quantity) {
      try {
        final product = _homeAllProducts.firstWhere((p) => p.id == productId);
        if (quantity > product.jumlahProduk) {
          print(
              "Checkout Error: Stock for ${product.namaProduk} changed. Required: $quantity, Available: ${product.jumlahProduk}");
          missingProductIds.add(productId);
          _showErrorSnackbar('Stok ${product.namaProduk} tidak cukup!');
        } else {
          productsInCart.add(product);
        }
      } catch (e) {
        print(
            "Error: Product ID $productId from cart not found in product list during checkout!");
        missingProductIds.add(productId);
        setState(() => _checkoutCart.remove(productId));
      }
    });

    if (missingProductIds.isNotEmpty) {
      _showErrorSnackbar(
          "Beberapa produk tidak tersedia atau stok berubah. Periksa keranjang Anda.");
      setState(() {});
      return;
    }

    if (productsInCart.isNotEmpty) {
      print(
          "Navigating to Checkout with ${productsInCart.length} product types.");
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CheckoutScreen(
            cartQuantities: Map.from(_checkoutCart),
            cartProducts: productsInCart,
            userId: widget.userId,
          ),
        ),
      ).then((transactionCompleted) {
        if (transactionCompleted == true && mounted) {
          setState(() {
            _checkoutCart.clear();
          });
          _loadHomeProducts();
        }
      });
    } else {
      _showErrorSnackbar("Keranjang kosong atau produk tidak valid.");
    }
  }

  // --- Bottom Nav Item ---
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
  // --- End Bottom Nav Item ---

  // --- Helper: Menghitung Posisi Indikator ---
  void _updateIndicatorPositionSafe() {
    final selectedKey = _navItemKeys[_selectedIndex];
    final appBarKeyContext = _bottomAppBarKey.currentContext;
    const double horizontalAdjustment = 1.0;

    if (selectedKey.currentContext != null && appBarKeyContext != null) {
      try {
        // Tambahkan try-catch untuk keamanan renderbox
        final RenderBox itemRenderBox =
            selectedKey.currentContext!.findRenderObject() as RenderBox;
        final RenderBox appBarRenderBox =
            appBarKeyContext.findRenderObject() as RenderBox;

        // Periksa apakah render box masih valid
        if (!itemRenderBox.attached || !appBarRenderBox.attached) {
          print("Warning: RenderBox is not attached during indicator update.");
          return;
        }

        final Offset itemOffsetInAppBar = appBarRenderBox
            .globalToLocal(itemRenderBox.localToGlobal(Offset.zero));
        final double itemWidth = itemRenderBox.size.width;
        final double centeredLeft =
            itemOffsetInAppBar.dx + (itemWidth - desiredIndicatorWidth) / 4.5;
        final double adjustedLeft = centeredLeft + horizontalAdjustment;

        if (mounted && (adjustedLeft - _indicatorLeftOffset).abs() > 0.1) {
          setState(() {
            _indicatorLeftOffset = adjustedLeft;
          });
        } else if (mounted &&
            _indicatorLeftOffset == 10.0 &&
            adjustedLeft != 10.0) {
          setState(() {
            _indicatorLeftOffset = adjustedLeft;
          });
        }
      } catch (e) {
        print("Error calculating indicator position: $e");
        // Mungkin panggil lagi setelah delay jika error terkait renderbox belum siap
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _updateIndicatorPositionSafe();
        });
      }
    } else {
      // Log kondisi spesifik kenapa konteks null
      if (!mounted) return; // Jangan lakukan apa pun jika sudah di-dispose
      String reason = "";
      if (appBarKeyContext == null) reason += "BottomAppBar context is null. ";
      if (_selectedIndex >= _navItemKeys.length ||
          _navItemKeys[_selectedIndex].currentContext == null) {
        reason += "Selected nav item (index $_selectedIndex) context is null.";
      }
      print("Warning: Could not get RenderBox context. Reason: $reason");

      // Coba panggil lagi setelah delay, mungkin render box belum siap
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updateIndicatorPositionSafe();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double bottomAppBarHeight = MediaQuery.of(context).size.height * 0.1;
    print("HomePage build running...");

    _updateScreenOptions();

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
                heroTag: 'scanFAB',
                onPressed: () {
                  _showInfoSnackbar('Fitur Scan belum diimplementasikan.');
                  print("Scan FAB pressed (Placeholder)");
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
              visible: _selectedIndex == 0 && _checkoutCart.isNotEmpty,
              child: FloatingActionButton.extended(
                heroTag: 'checkoutFAB',
                onPressed: _proceedToCheckout,
                backgroundColor: Colors.green.shade600,
                icon: const Icon(Icons.shopping_cart_checkout,
                    color: Colors.white),
                label: Text(
                    'Checkout (${_checkoutCart.values.fold(0, (sum, item) => sum + item)})',
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
              top: -5,
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
} // End _HomePageState

// ======================================================
// === WIDGET UNTUK KONTEN TAB BERANDA (PRODUK LIST) ===
// ======================================================
class _HomeProductView extends StatelessWidget {
  final int userId;
  final bool isLoading;
  final String errorMessage;
  final List<Product> allProducts;
  final List<Product> filteredProducts;
  final Map<int, int> checkoutCart;
  final TextEditingController searchController;
  final bool sortAscending;
  final Future<void> Function() onRefresh;
  final VoidCallback onSortToggle;
  final Function(int productId, int newQuantity) onQuantityChanged;
  final NumberFormat currencyFormatter;

  const _HomeProductView({
    Key? key,
    required this.userId,
    required this.isLoading,
    required this.errorMessage,
    required this.allProducts,
    required this.filteredProducts,
    required this.checkoutCart,
    required this.searchController,
    required this.sortAscending,
    required this.onRefresh,
    required this.onSortToggle,
    required this.onQuantityChanged,
    required this.currencyFormatter,
  }) : super(key: key);

  // --- Helper: Build Product Card (Using User Provided Version) ---
  Widget _buildHomeProductCard(Product product) {
    // Removed context parameter as it wasn't used inside
    // Ambil kuantitas dari cart, default 0 jika tidak ada
    final int currentQuantity =
        product.id != null ? (checkoutCart[product.id!] ?? 0) : 0;
    final bool isSelected =
        currentQuantity > 0; // Dianggap terpilih jika kuantitas > 0

    ImageProvider? productImage;
    if (product.gambarProduk != null && product.gambarProduk!.isNotEmpty) {
      try {
        final imageFile = File(product.gambarProduk!);
        if (imageFile.existsSync()) {
          // --- FIX: Hapus 'key' dari FileImage ---
          // productImage = FileImage(imageFile, key: ValueKey(product.gambarProduk!)); // <-- SALAH
          productImage = FileImage(imageFile); // <-- BENAR
          // --- END FIX ---
        } else {
          print(
              "Warning: Image file not found at path: ${product.gambarProduk}");
          productImage = null;
        }
      } catch (e) {
        print("Error creating FileImage for ${product.gambarProduk}: $e");
        productImage = null;
      }
    }

    return Card(
      // Gunakan Card sebagai dasar
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8), // Adjusted margin
      elevation: isSelected ? 3.0 : 1.5, // Sedikit elevasi
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(
            // Beri border jika terpilih
            color: isSelected ? Colors.blue.shade300 : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1.0,
          )),
      color: Colors.white, // Simplified background color
      surfaceTintColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12.0), // Adjusted padding
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.center, // Align vertically center
          children: [
            // Gambar
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Container(
                width: 65, height: 65, // Adjusted size
                color: Colors.grey.shade200,
                child: productImage != null
                    ? Image(
                        // --- FIX: Tambahkan 'key' di sini, pada widget Image ---
                        key: ValueKey(product.id.toString() +
                            (product.gambarProduk ??
                                '')), // Lebih baik gunakan ID + path
                        // --- END FIX ---
                        image: productImage,
                        width: 65,
                        height: 65,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) {
                          print("Error displaying image in card: $e");
                          return Icon(Icons.broken_image,
                              color: Colors.grey[400], size: 30);
                        })
                    : Icon(Icons.inventory_2_outlined,
                        color: Colors.grey[400], size: 35),
              ),
            ),
            const SizedBox(width: 12),
            // Info Produk & Harga
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center, // Center vertically
              children: [
                Text(
                  product.namaProduk,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 15.0), // Adjusted size
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2), // Adjusted spacing
                Text('Kode: ${product.kodeProduk}',
                    style: GoogleFonts.poppins(
                        fontSize: 11.0,
                        color: Colors.grey.shade600)), // Adjusted size
                const SizedBox(height: 4), // Adjusted spacing
                Text(currencyFormatter.format(product.hargaJual),
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.0, // Adjusted size
                        color: Colors.green.shade700)),
              ],
            )),
            // Kontrol Kuantitas & Stok
            Column(
                mainAxisAlignment:
                    MainAxisAlignment.center, // Center vertically
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Teks Stok
                  Text('Stok: ${product.jumlahProduk}',
                      style: GoogleFonts.poppins(
                          fontSize: 11.0, // Adjusted size
                          color: product.jumlahProduk <= 0
                              ? Colors.red.shade700
                              : (product.jumlahProduk <= 5
                                  ? Colors.orange.shade800
                                  : Colors.black54), // Added warning color
                          fontWeight: product.jumlahProduk <= 5
                              ? FontWeight.w600
                              : FontWeight.normal)),
                  const SizedBox(height: 8), // Adjusted spacing
                  // --- FIX: Call _buildQuantityControl with NAMED arguments ---
                  _buildQuantityControl(
                    productId: product.id,
                    currentQuantity: currentQuantity,
                    maxStock: product.jumlahProduk,
                    onQuantityChanged: onQuantityChanged, // Pass the callback
                  ),
                  // --- END FIX ---
                ]),
          ],
        ),
      ),
    );
  }
  // --- End Helper: Build Product Card ---

  // --- Helper: Build Price Column (Removed as it's unused according to error) ---
  // Widget _buildPriceColumn(String label, double price, NumberFormat formatter) { ... }
  // --- End Helper: Build Price Column ---

  // --- Helper: Quantity Control Widget ---
  Widget _buildQuantityControl({
    required int? productId,
    required int currentQuantity,
    required int maxStock,
    required Function(int productId, int newQuantity) onQuantityChanged,
  }) {
    if (productId == null) return const SizedBox(height: 32);

    if (currentQuantity <= 0) {
      return SizedBox(
        height: 32,
        child: OutlinedButton.icon(
          onPressed:
              maxStock <= 0 ? null : () => onQuantityChanged(productId, 1),
          icon: Icon(Icons.add,
              size: 18,
              color: maxStock <= 0 ? Colors.grey : Colors.blue.shade700),
          label: Text('Tambah',
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: maxStock <= 0 ? Colors.grey : Colors.blue.shade700)),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.blue.shade700,
            side: BorderSide(
                color: maxStock <= 0
                    ? Colors.grey.shade300
                    : Colors.blue.shade600),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      );
    } else {
      return Container(
        height: 32,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => onQuantityChanged(productId, currentQuantity - 1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                child: Icon(Icons.remove, size: 18, color: Colors.red.shade700),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              constraints: const BoxConstraints(minWidth: 24),
              child: Text(
                currentQuantity.toString(),
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            InkWell(
              onTap: currentQuantity >= maxStock
                  ? null
                  : () => onQuantityChanged(productId, currentQuantity + 1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                child: Icon(
                  Icons.add,
                  size: 18,
                  color: currentQuantity >= maxStock
                      ? Colors.grey
                      : Colors.green.shade700,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
  // --- End Helper: Quantity Control Widget ---

  @override
  Widget build(BuildContext context) {
    print(
        "_HomeProductView build - isLoading: $isLoading, filtered: ${filteredProducts.length}");
    return Column(
      children: [
        SizedBox(height: 10),
        // --- Search Bar & Filter ---
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 10.0),
          child: Row(children: [
            // Search Field
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10.0),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 4,
                          offset: Offset(0, 1))
                    ]),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari produk (nama/kode)',
                    hintStyle: GoogleFonts.poppins(
                        color: Colors.grey.shade500,
                        fontSize: MediaQuery.of(context).size.width * 0.035),
                    prefixIcon: Icon(Icons.search,
                        color: Colors.grey.shade600,
                        size: MediaQuery.of(context).size.width * 0.06),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear,
                                color: Colors.grey.shade500,
                                size: MediaQuery.of(context).size.width * 0.06),
                            onPressed: () {
                              searchController.clear();
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 14.0, horizontal: 5),
                    isDense: true,
                  ),
                  style: GoogleFonts.poppins(
                      fontSize: MediaQuery.of(context).size.width * 0.015,
                      color: Colors.black87),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Sort Button
            InkWell(
              onTap: onSortToggle,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: MediaQuery.of(context).size.width * 0.12,
                width: MediaQuery.of(context).size.width * 0.12,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10.0),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 4,
                          offset: Offset(0, 1))
                    ]),
                child: Tooltip(
                  message: sortAscending ? 'Urutkan Z-A' : 'Urutkan A-Z',
                  child: Icon(
                    sortAscending ? Icons.sort_by_alpha : Icons.sort_by_alpha,
                    color: Colors.blue.shade700,
                    size: 24,
                  ),
                ),
              ),
            ),
          ]),
        ),
        // --- Product List ---
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage.isNotEmpty
                  ? Center(
                      child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline,
                                  color: Colors.red, size: 40),
                              const SizedBox(height: 10),
                              Text(errorMessage,
                                  style: GoogleFonts.poppins(
                                      color: Colors.red.shade700, fontSize: 15),
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 15),
                              ElevatedButton.icon(
                                  onPressed: onRefresh,
                                  icon: Icon(Icons.refresh),
                                  label: Text("Coba Lagi")),
                            ],
                          )))
                  : allProducts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.storefront_outlined,
                                  color: Colors.grey.shade400, size: 50),
                              const SizedBox(height: 10),
                              Text('Belum ada produk ditambahkan.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                      color: Colors.grey.shade500,
                                      fontSize:
                                          MediaQuery.of(context).size.width *
                                              0.045)),
                              Text('Tambahkan melalui menu Kelola.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                      color: Colors.grey.shade500,
                                      fontSize:
                                          MediaQuery.of(context).size.width *
                                              0.035)),
                              const SizedBox(height: 15),
                              ElevatedButton.icon(
                                  onPressed: onRefresh,
                                  icon: Icon(Icons.refresh),
                                  label: Text("Muat Ulang"))
                            ],
                          ),
                        )
                      : filteredProducts.isEmpty
                          ? Center(
                              child: Text(
                              'Produk "${searchController.text}" tidak ditemukan.',
                              style: GoogleFonts.poppins(
                                  color: Colors.grey.shade500, fontSize: 15),
                              textAlign: TextAlign.center,
                            ))
                          : RefreshIndicator(
                              onRefresh: onRefresh,
                              child: ListView.builder(
                                // Use builder
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding:
                                    const EdgeInsets.only(bottom: 90, top: 5),
                                itemCount: filteredProducts.length,
                                itemBuilder: (context, index) {
                                  // Pass product to the build method
                                  return _buildHomeProductCard(
                                      filteredProducts[index]);
                                },
                              ),
                            ),
        ),
      ],
    );
  }
} // End _HomeProductView
