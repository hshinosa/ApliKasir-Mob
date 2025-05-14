// lib/fitur/manage/customer/providers/customer_provider.dart
import 'package:flutter/material.dart';
import 'package:aplikasir_mobile/model/customer_model.dart';
import 'package:aplikasir_mobile/helper/db_helper.dart';
import 'package:aplikasir_mobile/model/user_model.dart';     // Untuk User
import 'package:aplikasir_mobile/utils/auth_utils.dart';
import 'package:google_fonts/google_fonts.dart';    // Untuk verifyPassword

class CustomerProvider extends ChangeNotifier {
  final int userId;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<Customer> _allCustomers = [];
  List<Customer> _filteredCustomers = [];
  bool _isLoading = true;
  String _errorMessage = '';
  bool _sortAscending = true; // Default A-Z
  String _searchQuery = '';

  // Getters
  List<Customer> get filteredCustomers => _filteredCustomers;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  bool get sortAscending => _sortAscending;
  String get searchQuery => _searchQuery;

  CustomerProvider({required this.userId}) {
    loadCustomers();
  }

  Future<void> loadCustomers() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _allCustomers = await _dbHelper.getCustomersByUserId(userId);
      _applyFiltersAndSort();
    } catch (e) {
      _errorMessage = 'Gagal memuat pelanggan: ${e.toString()}';
      _allCustomers = [];
      _filteredCustomers = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase().trim();
    _applyFiltersAndSort();
  }

  void toggleSortOrder() {
    _sortAscending = !_sortAscending;
    _applyFiltersAndSort();
  }

  void _applyFiltersAndSort() {
    List<Customer> tempFiltered = _allCustomers;

    if (_searchQuery.isNotEmpty) {
      tempFiltered = tempFiltered.where((customer) {
        final nameLower = customer.namaPelanggan.toLowerCase();
        final phoneLower = customer.nomorTelepon?.toLowerCase() ?? '';
        return nameLower.contains(_searchQuery) || phoneLower.contains(_searchQuery);
      }).toList();
    }

    tempFiltered.sort((a, b) {
      int comparison = a.namaPelanggan.toLowerCase().compareTo(b.namaPelanggan.toLowerCase());
      return _sortAscending ? comparison : -comparison;
    });

    _filteredCustomers = tempFiltered;
    notifyListeners();
  }

  // --- CRUD Operations ---
  Future<Customer?> addOrUpdateCustomer(
      BuildContext context, // Diperlukan untuk password dialog
      {Customer? existingCustomer,
      required String name,
      String? phone}) async {
    _isLoading = true; // Bisa jadi ada loading UI di dialog
    _errorMessage = '';
    notifyListeners();

    try {
      Customer customerToSave;
      if (existingCustomer != null) { // Update
        customerToSave = existingCustomer.copyWith(
          namaPelanggan: name.trim(),
          nomorTelepon: phone?.trim().isEmpty ?? true ? null : phone!.trim(),
          updatedAt: DateTime.now(), // Set updatedAt
          syncStatus: (existingCustomer.syncStatus == 'new') ? 'new' : 'updated', // Jaga status 'new'
        );
        await _dbHelper.updateCustomerLocal(customerToSave);
      } else { // Add
        customerToSave = Customer(
          idPengguna: userId,
          namaPelanggan: name.trim(),
          nomorTelepon: phone?.trim().isEmpty ?? true ? null : phone!.trim(),
          createdAt: DateTime.now(),
          syncStatus: 'new', // Baru dibuat, status 'new'
        );
        final generatedId = await _dbHelper.insertCustomerLocal(customerToSave);
        customerToSave = customerToSave.copyWith(id: generatedId); // Ambil ID lokal
      }
      await loadCustomers(); // Reload list
      notifyListeners();
      return customerToSave; // Kembalikan customer yang disimpan/diupdate
    } catch (e) {
      _errorMessage = "Gagal menyimpan pelanggan: ${e.toString()}";
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteCustomer(BuildContext context, Customer customer) async {
    if (customer.id == null) {
      _errorMessage = "ID Pelanggan tidak valid untuk dihapus.";
      notifyListeners();
      return false;
    }
     _isLoading = true;
     _errorMessage = '';
     notifyListeners();

    // --- Konfirmasi Password ---
    // Asumsi fungsi _showPasswordConfirmationDialog dan _verifyPassword
    // sudah ada atau diadaptasi dan bisa diakses di sini (misal di AuthUtils)
    final bool? passwordConfirmed = await _showPasswordConfirmationDialog(context);

    if (passwordConfirmed != true) {
       _isLoading = false;
       notifyListeners();
       if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Penghapusan dibatalkan (password salah/batal).'), backgroundColor: Colors.orange),
          );
       }
       return false;
    }
    // --- Akhir Konfirmasi Password ---

    try {
      await _dbHelper.softDeleteCustomerLocal(customer.id!, userId);
      await loadCustomers(); // Reload list
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = "Gagal menghapus pelanggan: ${e.toString()}";
      notifyListeners();
      return false;
    } finally {
       _isLoading = false;
       notifyListeners();
    }
  }

   // --- Dialog Konfirmasi Password (Adaptasi) ---
  Future<bool?> _showPasswordConfirmationDialog(BuildContext context) async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool dialogIsLoading = false; // Loading spesifik untuk dialog
    bool obscurePassword = true;
    String? dialogErrorMessage;

    // --- Ambil Gaya Dialog dari Tema atau Definisikan Lokal ---
    final ShapeBorder dialogShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0));
    final EdgeInsets dialogActionsPadding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0);
    final TextStyle dialogTitleStyle = GoogleFonts.poppins(
      fontWeight: FontWeight.w600, fontSize: 18.0, color: Theme.of(context).primaryColorDark,
    );
    final TextStyle dialogContentStyle = GoogleFonts.poppins(fontSize: 14.0, color: Colors.grey.shade700, height: 1.4);
    ButtonStyle cancelButtonStyle() => TextButton.styleFrom(
          foregroundColor: Colors.grey.shade600,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
              side: BorderSide(color: Colors.grey.shade300)),
        );
    ButtonStyle primaryActionButtonStyle() => ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          elevation: 2,
        );
    // ---

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) { // context DI DALAM builder adalah untuk dialog
          return AlertDialog(
            shape: dialogShape,
            title: Text('Konfirmasi Password', style: dialogTitleStyle),
            actionsPadding: dialogActionsPadding,
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Masukkan password Anda untuk melanjutkan:", style: dialogContentStyle),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.lock_outline),
                      errorText: dialogErrorMessage,
                      suffixIcon: IconButton(
                        icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                      ),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Password tidak boleh kosong' : null,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: dialogIsLoading ? null : () => Navigator.pop(dialogContext, false),
                style: cancelButtonStyle(),
                child: Text('Batal', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
              ),
              ElevatedButton(
                onPressed: dialogIsLoading ? null : () async {
                  if (formKey.currentState!.validate()) {
                    setDialogState(() { dialogIsLoading = true; dialogErrorMessage = null; });
                    bool passwordMatch = await _verifyPassword(passwordController.text);
                    setDialogState(() => dialogIsLoading = false);
                    if (passwordMatch) {
                       if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                    } else {
                      setDialogState(() => dialogErrorMessage = 'Password salah.');
                    }
                  }
                },
                style: primaryActionButtonStyle(),
                child: dialogIsLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Konfirmasi', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ],
          );
        });
      },
    );
  }

  Future<bool> _verifyPassword(String enteredPassword) async {
    try {
      User? currentUser = await _dbHelper.getUserById(userId);
      if (currentUser == null) return false;
      return verifyPassword(enteredPassword, currentUser.passwordHash);
    } catch (e) {
      print("Error verifying password in provider: $e");
      return false;
    }
  }
}