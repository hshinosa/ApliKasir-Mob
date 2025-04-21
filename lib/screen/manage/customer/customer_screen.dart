// screen/manage/customer/customer_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aplikasir_mobile/model/customer_model.dart'; // Impor model
import 'package:aplikasir_mobile/helper/db_helper.dart'; // Impor DBHelper
import 'package:aplikasir_mobile/model/user_model.dart'; // Impor model User
import 'package:aplikasir_mobile/utils/auth_utils.dart'; // Impor auth utils

class CustomerScreen extends StatefulWidget {
  final int userId; // ID pengguna untuk fetch data

  const CustomerScreen({super.key, required this.userId});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Customer> _allCustomers = [];
  List<Customer> _filteredCustomers = [];
  bool _isLoading = true;
  String _errorMessage = '';

  // Warna & Style umum
  final Color _primaryColor = Colors.blue.shade700;
  final Color _iconColor = Colors.blue.shade600; // Warna ikon di list
  final Color _iconBgColor =
      Colors.blue.shade50; // Warna background ikon di list
  bool _sortAscending = true;

  // --- Konstanta Gaya Dialog (Diadaptasi dari _logout) ---
  final ShapeBorder _dialogShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(15.0),
  );
  final EdgeInsets _dialogActionsPadding =
      const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0);
  final TextStyle _dialogTitleStyle = GoogleFonts.poppins(
    fontWeight: FontWeight.w600,
    fontSize: 18.0,
    color: Colors.blue.shade800, // Gunakan warna primer
  );
  final TextStyle _dialogContentStyle = GoogleFonts.poppins(
    fontSize: 14.0,
    color: Colors.grey.shade700,
    height: 1.4,
  );
  // Gaya untuk Tombol Batal standar
  ButtonStyle _cancelButtonStyle(BuildContext context) => TextButton.styleFrom(
        foregroundColor: Colors.grey.shade600,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
            side: BorderSide(color: Colors.grey.shade300)),
      );
  // Gaya untuk Tombol Aksi Utama (Merah untuk Hapus/Logout)
  ButtonStyle _dangerActionButtonStyle(BuildContext context) =>
      TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.red.shade600,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        elevation: 2,
      );
  // Gaya untuk Tombol Aksi Utama (Biru untuk Simpan/Konfirmasi)
  ButtonStyle _primaryActionButtonStyle(BuildContext context) =>
      ElevatedButton.styleFrom(
        backgroundColor: _primaryColor, // Warna primer
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8), // Sesuaikan jika perlu
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        elevation: 2,
      );
  // --- Akhir Konstanta Gaya Dialog ---

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _searchController.addListener(_filterCustomers);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterCustomers);
    _searchController.dispose();
    super.dispose();
  }

  // --- Fungsi Load Pelanggan ---
  Future<void> _loadCustomers() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final customers =
          await DatabaseHelper.instance.getCustomersByUserId(widget.userId);
      if (!mounted) return;
      setState(() {
        _allCustomers = customers;
        _filteredCustomers = customers;
        _isLoading = false;
        _sortCustomers(); // <-- Panggil sort setelah load
      });
    } catch (e) {
      print("Error loading customers: $e");
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat pelanggan: ${e.toString()}';
      });
    }
  }

  // --- Fungsi Sortir Pelanggan ---
  void _sortCustomers() {
    if (_filteredCustomers.isEmpty) return;
    print("Sorting customers ${_sortAscending ? 'A-Z' : 'Z-A'}");
    setState(() {
      // Perlu setState karena urutan list berubah
      _filteredCustomers.sort((a, b) {
        int comparison = a.namaPelanggan
            .toLowerCase()
            .compareTo(b.namaPelanggan.toLowerCase());
        return _sortAscending ? comparison : -comparison;
      });
    });
  }
  // --- Akhir Fungsi Sortir --

  // --- Fungsi Filter Pelanggan ---
  void _filterCustomers() {
    final query = _searchController.text.toLowerCase().trim();
    if (!mounted) return;
    setState(() {
      if (query.isEmpty) {
        _filteredCustomers = _allCustomers;
      } else {
        _filteredCustomers = _allCustomers.where((customer) {
          // Cari berdasarkan nama atau nomor telepon
          final nameLower = customer.namaPelanggan.toLowerCase();
          final phoneLower = customer.nomorTelepon?.toLowerCase() ?? '';
          return nameLower.contains(query) || phoneLower.contains(query);
        }).toList();
      }
    });
  }

  // --- Helper Snackbar ---
  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // --- Dialog Tambah/Edit Pelanggan ---
  Future<Customer?> _showAddEditCustomerDialog(
      {Customer? existingCustomer}) async {
    // ... (setup controller, formkey, isSaving SAMA) ...
    final bool isEdit = existingCustomer != null;
    final nameController =
        TextEditingController(text: existingCustomer?.namaPelanggan ?? '');
    final phoneController =
        TextEditingController(text: existingCustomer?.nomorTelepon ?? '');
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    if (!mounted) return null;

    return await showDialog<Customer>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        // Gunakan dialogContext
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              // --- Terapkan Gaya ---
              backgroundColor: Colors.white,
              shape: _dialogShape,
              elevation: 5.0,
              title: Text(isEdit ? "Edit Pelanggan" : "Tambah Pelanggan Baru",
                  style: _dialogTitleStyle), // Gaya judul
              actionsPadding: _dialogActionsPadding, // Padding aksi
              // --- Akhir Terapkan Gaya ---

              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Instruksi opsional
                    // Text("Masukkan detail pelanggan:", style: _dialogContentStyle.copyWith(fontSize: 13)),
                    // const SizedBox(height: 10),
                    TextFormField(
                      controller: nameController,
                      /* ... dekorasi sama ... */ decoration: InputDecoration(
                        labelText: "Nama Pelanggan",
                        hintText: "Masukkan nama lengkap",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      style: GoogleFonts.poppins(),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Nama tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: phoneController,
                      /* ... dekorasi sama ... */ decoration: InputDecoration(
                        labelText: "Nomor Telepon (Opsional)",
                        hintText: "Contoh: 0812xxxx",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                      keyboardType: TextInputType.phone,
                      style: GoogleFonts.poppins(),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                // Tombol Batal (Gunakan Style)
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(
                          dialogContext, null), // Gunakan dialogContext
                  style: _cancelButtonStyle(context), // Terapkan gaya batal
                  child: Text('Batal',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500, fontSize: 14)),
                ),
                // Tombol Simpan/Tambah (Gunakan Style)
                ElevatedButton.icon(
                  icon: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Icon(isEdit ? Icons.save_alt : Icons.add),
                  label: Text(
                      isSaving
                          ? "Menyimpan..."
                          : (isEdit ? "Simpan" : "Tambah"),
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14)), // Sesuaikan style teks
                  style: _primaryActionButtonStyle(context).copyWith(
                    // Terapkan gaya primer
                    padding: MaterialStateProperty.all(
                        const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8)), // Sesuaikan padding jika perlu
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          /* ... logika simpan/update SAMA ... */ if (formKey
                              .currentState!
                              .validate()) {
                            setDialogState(() => isSaving = true);
                            try {
                              final newCustomerData = Customer(
                                  id: existingCustomer?.id,
                                  idPengguna: widget.userId,
                                  namaPelanggan: nameController.text.trim(),
                                  nomorTelepon:
                                      phoneController.text.trim().isEmpty
                                          ? null
                                          : phoneController.text.trim(),
                                  createdAt: existingCustomer?.createdAt ??
                                      DateTime.now());
                              if (isEdit) {
                                await DatabaseHelper.instance
                                    .updateCustomer(newCustomerData);
                                if (!mounted) return;
                                _showSnackbar(
                                    "Pelanggan '${newCustomerData.namaPelanggan}' berhasil diperbarui.");
                                Navigator.pop(dialogContext, newCustomerData);
                              } else {
                                final generatedId = await DatabaseHelper
                                    .instance
                                    .insertCustomer(newCustomerData);
                                final savedCustomer = Customer(
                                    id: generatedId,
                                    idPengguna: newCustomerData.idPengguna,
                                    namaPelanggan:
                                        newCustomerData.namaPelanggan,
                                    nomorTelepon: newCustomerData.nomorTelepon,
                                    createdAt: newCustomerData.createdAt);
                                if (!mounted) return;
                                _showSnackbar(
                                    "Pelanggan '${savedCustomer.namaPelanggan}' berhasil ditambahkan.");
                                Navigator.pop(dialogContext, savedCustomer);
                              }
                            } catch (e) {
                              print("Error saving/updating customer: $e");
                              if (!mounted) return;
                              _showSnackbar("Gagal menyimpan: ${e.toString()}",
                                  isError: true);
                            } finally {
                              if (mounted)
                                setDialogState(() => isSaving = false);
                            }
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Dialog Opsi Edit/Hapus ---
  Future<void> _showEditDeleteOptionsDialog(Customer customer) async {
    if (!mounted) return;
    final result = await showModalBottomSheet<String>(
        context: context,
        shape: const RoundedRectangleBorder(
          // Sudut atas melengkung
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
        ),
        builder: (BuildContext context) {
          return Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading: Icon(Icons.edit_outlined, color: _primaryColor),
                  title: Text('Edit Pelanggan', style: GoogleFonts.poppins()),
                  onTap: () => Navigator.pop(context, 'edit'),
                ),
                ListTile(
                  leading:
                      Icon(Icons.delete_outline, color: Colors.red.shade700),
                  title: Text('Hapus Pelanggan',
                      style: GoogleFonts.poppins(color: Colors.red.shade700)),
                  onTap: () => Navigator.pop(context, 'delete'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  // Tombol Batal
                  child: Text('Batal',
                      style: GoogleFonts.poppins(color: Colors.grey.shade600)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        });

    // Handle hasil pilihan dari bottom sheet
    if (result == 'edit') {
      final updatedCustomer =
          await _showAddEditCustomerDialog(existingCustomer: customer);
      if (updatedCustomer != null) {
        _loadCustomers();
      } // Reload jika ada perubahan
    } else if (result == 'delete') {
      _confirmDeleteCustomer(customer); // Panggil konfirmasi hapus
    }
  }

  Future<void> _confirmDeleteCustomer(Customer customer) async {
    if (!mounted) return;
    final confirmDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Lebih aman set ke false
      builder: (BuildContext dialogContext) {
        // Gunakan dialogContext
        return AlertDialog(
          // --- Terapkan Gaya ---
          backgroundColor: Colors.white,
          shape: _dialogShape,
          elevation: 5.0,
          title: Text('Konfirmasi Hapus', style: _dialogTitleStyle),
          actionsPadding: _dialogActionsPadding,
          // --- Akhir Terapkan Gaya ---

          content: Text(
            // Gunakan style konten
            'Yakin ingin menghapus pelanggan "${customer.namaPelanggan}"?\nTransaksi terkait tidak akan dihapus.',
            style: _dialogContentStyle,
          ),
          actions: [
            TextButton(
              // Tombol Batal (Gunakan Style)
              onPressed: () => Navigator.pop(dialogContext, false),
              style: _cancelButtonStyle(context),
              child: Text('Batal',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500, fontSize: 14)),
            ),
            TextButton(
              // Tombol Hapus (Gunakan Style Bahaya)
              onPressed: () => Navigator.pop(dialogContext, true),
              style: _dangerActionButtonStyle(
                  context), // Terapkan gaya bahaya (merah)
              child: Text(
                'Ya, Hapus',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      // ... (Logika panggil dialog password SAMA) ...
      if (!mounted) return;
      final passwordConfirmed = await _showPasswordConfirmationDialog();
      if (passwordConfirmed == true) {
        try {
          setState(() => _isLoading = true);
          await DatabaseHelper.instance
              .deleteCustomer(customer.id!, widget.userId);
          if (!mounted) return;
          _showSnackbar(
              'Pelanggan "${customer.namaPelanggan}" berhasil dihapus.',
              isError: false);
          _loadCustomers();
        } catch (e) {
          print("Error deleting customer after password confirmation: $e");
          if (!mounted) return;
          _showSnackbar('Gagal menghapus pelanggan: ${e.toString()}',
              isError: true);
          setState(() => _isLoading = false);
        }
      } else {
        if (mounted)
          _showSnackbar('Penghapusan dibatalkan (password salah/batal).',
              isError: true);
      }
    }
  }

  // --- Dialog Konfirmasi Password (Terapkan Gaya) ---
  Future<bool?> _showPasswordConfirmationDialog() async {
    // ... (setup controller, key, state SAMA) ...
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    bool obscurePassword = true;
    String? errorMessage;

    return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(builder: (context, setDialogState) {
            return AlertDialog(
              // --- Terapkan Gaya ---
              backgroundColor: Colors.white,
              shape: _dialogShape,
              elevation: 5.0,
              title: Text('Konfirmasi Password', style: _dialogTitleStyle),
              actionsPadding: _dialogActionsPadding,
              // --- Akhir Terapkan Gaya ---

              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Gunakan style konten untuk instruksi
                    Text("Masukkan password Anda untuk melanjutkan:",
                        style: _dialogContentStyle.copyWith(
                            fontSize: 13)), // Sedikit lebih kecil
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      /* ... dekorasi sama ... */ decoration: InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.lock_outline),
                        errorText: errorMessage,
                        suffixIcon: IconButton(
                          icon: Icon(obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () {
                            setDialogState(
                                () => obscurePassword = !obscurePassword);
                          },
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Password tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  // Tombol Batal (Gunakan Style)
                  onPressed: isLoading
                      ? null
                      : () => Navigator.pop(dialogContext, false),
                  style: _cancelButtonStyle(context),
                  child: Text('Batal',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500, fontSize: 14)),
                ),
                ElevatedButton(
                  // Tombol Konfirmasi (Gunakan Style Primer)
                  onPressed: isLoading
                      ? null
                      : () async {
                          /* ... logika verifikasi password SAMA ... */ if (formKey
                              .currentState!
                              .validate()) {
                            setDialogState(() {
                              isLoading = true;
                              errorMessage = null;
                            });
                            bool passwordMatch =
                                await _verifyPassword(passwordController.text);
                            setDialogState(() => isLoading = false);
                            if (passwordMatch) {
                              if (!context.mounted) return;
                              Navigator.pop(dialogContext, true);
                            } else {
                              setDialogState(
                                  () => errorMessage = 'Password salah.');
                            }
                          }
                        },
                  style: _primaryActionButtonStyle(context).copyWith(
                    padding: MaterialStateProperty.all(
                        const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8)),
                  ), // Terapkan gaya primer
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text('Konfirmasi',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ],
            );
          });
        });
  }

  // --- Fungsi Verifikasi Password (Menggunakan auth_utils) ---
  Future<bool> _verifyPassword(String enteredPassword) async {
    try {
      // 1. Ambil data user yang sedang login
      User? currentUser =
          await DatabaseHelper.instance.getUserById(widget.userId);
      if (currentUser == null) {
        print("Error: Cannot verify password, current user data not found.");
        _showSnackbar("Gagal memverifikasi: Data pengguna tidak ditemukan.",
            isError: true); // Beri feedback
        return false;
      }

      // --- PERBAIKAN VERIFIKASI ---
      // 2. Gunakan fungsi verifyPassword dari auth_utils.dart
      //    Pastikan field di currentUser yang menyimpan hash sesuai
      //    (misalnya currentUser.passwordHash)
      //    Jika nama fieldnya beda (misal: currentUser.password), ganti di bawah ini.
      bool isMatch = verifyPassword(enteredPassword, currentUser.passwordHash);
      // --- AKHIR PERBAIKAN VERIFIKASI ---

      print("Password verification result: $isMatch"); // Debug
      return isMatch;
    } catch (e) {
      print("Error verifying password: $e");
      _showSnackbar("Terjadi kesalahan saat verifikasi password.",
          isError: true); // Beri feedback
      return false;
    }
  }
  // --- Akhir Fungsi Verifikasi Password ---

  // --- Helper: Membangun Item Pelanggan ---
  Widget _buildCustomerListItem(Customer customer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      padding: const EdgeInsets.symmetric(
          vertical: 8.0), // Padding vertikal lebih kecil
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          // Gunakan CircleAvatar untuk ikon
          backgroundColor: _iconBgColor,
          radius: 25, // Ukuran avatar
          child: Icon(Icons.person_outline, color: _iconColor, size: 26),
        ),
        title: Text(
          customer.namaPelanggan,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle:
            customer.nomorTelepon != null && customer.nomorTelepon!.isNotEmpty
                ? Text(
                    customer.nomorTelepon!,
                    style: GoogleFonts.poppins(
                        fontSize: 12.5, color: Colors.grey.shade600),
                  )
                : Text(
                    '- Tanpa nomor telepon -',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                        fontStyle: FontStyle.italic),
                  ),
        trailing: IconButton(
          // Tombol Opsi (Edit/Hapus)
          icon: Icon(Icons.more_vert, color: Colors.grey.shade500),
          tooltip: 'Opsi',
          onPressed: () =>
              _showEditDeleteOptionsDialog(customer), // Panggil dialog opsi
        ),
        onTap: () {
          // Aksi jika ingin detail saat list item di tap (misal riwayat hutang)
          print("Tapped customer: ${customer.namaPelanggan}");
          // TODO: Navigasi ke detail pelanggan jika perlu
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pelanggan',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: _primaryColor)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shadowColor: Colors.black26,
        foregroundColor: _primaryColor,
        elevation: 1.0,
        centerTitle: true,
        actions: [
          // Tombol Tambah di AppBar
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Tambah Pelanggan',
            onPressed: () async {
              final newCustomer =
                  await _showAddEditCustomerDialog(); // Panggil dialog tambah
              if (newCustomer != null) {
                _loadCustomers(); // Reload jika berhasil tambah
              }
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF7F8FC),
      body: Column(
        children: [
          // --- Search Bar & Filter ---
          Padding(
            padding: const EdgeInsets.fromLTRB(
                16.0, 16.0, 16.0, 10.0), // Sesuaikan padding jika perlu
            child: Row(children: [
              // Search Field (Menggunakan Container)
              Expanded(
                child: Container(
                  height: 48, // Tinggi konsisten
                  decoration: BoxDecoration(
                      color: Colors.white, // Background putih
                      borderRadius:
                          BorderRadius.circular(10.0), // Radius konsisten
                      boxShadow: [
                        // Shadow konsisten
                        BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 4,
                            offset: Offset(0, 1))
                      ]),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari Nama / No. Telp', // Ganti hint text
                      hintStyle: GoogleFonts.poppins(
                          color: Colors.grey.shade500, fontSize: 14),
                      prefixIcon: Icon(Icons.search,
                          color: Colors.grey.shade600, size: 22), // Ikon search
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              // Tombol clear
                              icon: Icon(Icons.clear,
                                  color: Colors.grey.shade500, size: 20),
                              onPressed: () {
                                _searchController.clear();
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            )
                          : null,
                      border:
                          InputBorder.none, // Tanpa border TextField internal
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 14.0,
                          horizontal: 5), // Sesuaikan padding content
                      isDense: true,
                    ),
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: Colors.black87),
                  ),
                ),
              ),
              const SizedBox(width: 10), // Jarak ke tombol filter
              // Tombol Filter/Sort (Gunakan Container dan InkWell)
              InkWell(
                // --- MODIFIKASI onTap ---
                onTap: () {
                  setState(() {
                    _sortAscending = !_sortAscending; // Toggle urutan
                    _sortCustomers(); // Panggil fungsi sortir
                  });
                },
                // --- AKHIR MODIFIKASI onTap ---
                borderRadius: BorderRadius.circular(10), // Efek ripple
                child: Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(/* ... decoration sama ... */),
                  child: Tooltip(
                    // --- MODIFIKASI Tooltip & Icon ---
                    message: _sortAscending
                        ? 'Urutkan Z-A'
                        : 'Urutkan A-Z', // Pesan dinamis
                    child: Icon(
                      Icons.sort_by_alpha, // Gunakan ikon ini saja
                      color: _primaryColor,
                      size: 24,
                    ),
                    // --- AKHIR MODIFIKASI Tooltip & Icon ---
                  ),
                ),
              ),
            ]),
          ),

          // --- Daftar Pelanggan ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(_errorMessage,
                                style: GoogleFonts.poppins(color: Colors.red),
                                textAlign: TextAlign.center)))
                    : _allCustomers.isEmpty // Cek data asli
                        ? Center(
                            child: Text(
                              'Belum ada pelanggan.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                  color: Colors.grey.shade500),
                            ),
                          )
                        : _filteredCustomers.isEmpty // Cek hasil filter
                            ? Center(
                                child: Text(
                                  'Pelanggan "${_searchController.text}" tidak ditemukan.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                      color: Colors.grey.shade500),
                                ),
                              )
                            : RefreshIndicator(
                                // Tambahkan refresh
                                onRefresh: _loadCustomers,
                                child: ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                      16.0, 8.0, 16.0, 16.0), // Padding list
                                  itemCount: _filteredCustomers.length,
                                  itemBuilder: (context, index) {
                                    return _buildCustomerListItem(
                                        _filteredCustomers[index]);
                                  },
                                ),
                              ),
          ),
        ],
      ),
    );
  }
}
