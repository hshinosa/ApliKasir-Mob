// lib/fitur/manage/customer/customer_screen.dart
import 'package:aplikasir_mobile/fitur/manage/customer/providers/customer_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:aplikasir_mobile/model/customer_model.dart'; // Impor model
// import 'package:aplikasir_mobile/helper/db_helper.dart'; // Tidak perlu jika Provider handle DB

class CustomerScreen extends StatelessWidget {
  // Ubah jadi StatelessWidget
  final int userId;
  const CustomerScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    // Sediakan Provider untuk subtree ini
    return ChangeNotifierProvider(
      create: (_) => CustomerProvider(userId: userId),
      child: const _CustomerScreenContent(),
    );
  }
}

class _CustomerScreenContent extends StatefulWidget {
  // Tidak perlu userId di sini, diambil dari Provider jika dibutuhkan nanti
  const _CustomerScreenContent({super.key});

  @override
  State<_CustomerScreenContent> createState() => _CustomerScreenContentState();
}

class _CustomerScreenContentState extends State<_CustomerScreenContent> {
  final TextEditingController _searchController = TextEditingController();
  // State UI (_allCustomers, _isLoading, dll) pindah ke Provider

  // Warna & Style (bisa tetap di sini atau jadi Theme)
  final Color _primaryColor = Colors.blue.shade700;
  final Color _iconColor = Colors.blue.shade600;
  final Color _iconBgColor = Colors.blue.shade50;

  // --- Konstanta Gaya Dialog (ambil dari Provider atau definisikan di sini) ---
  // (Ini bisa ditaruh di Theme atau utility class agar tidak duplikasi)
  final ShapeBorder _dialogShape =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0));
  final EdgeInsets _dialogActionsPadding =
      const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0);

  TextStyle _dialogTitleStyle(BuildContext context) => GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        fontSize: 18.0,
        color: Theme.of(context).colorScheme.primary,
      );
  TextStyle _dialogContentStyle(BuildContext context) => GoogleFonts.poppins(
        fontSize: 14.0,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        height: 1.4,
      );
  ButtonStyle _cancelButtonStyle(BuildContext context) => TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
            side: BorderSide(color: Theme.of(context).dividerColor)),
      );
  ButtonStyle _dangerActionButtonStyle(BuildContext context) =>
      TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Theme.of(context).colorScheme.error,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        elevation: 2,
      );
  ButtonStyle _primaryActionButtonStyle(BuildContext context) =>
      ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        elevation: 2,
      );
  // --- Akhir Gaya Dialog ---

  @override
  void initState() {
    super.initState();
    // Data akan dimuat oleh Provider saat diinisialisasi
    _searchController.addListener(() {
      // Panggil setSearchQuery di Provider
      context.read<CustomerProvider>().setSearchQuery(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Fungsi Load dan Filter pindah ke Provider

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

  // --- Dialog Tambah/Edit Pelanggan (MEMANGGIL PROVIDER) ---
  Future<void> _showAddEditCustomerDialog(
      BuildContext scaffContext, CustomerProvider provider,
      {Customer? existingCustomer}) async {
    final bool isEdit = existingCustomer != null;
    final nameController =
        TextEditingController(text: existingCustomer?.namaPelanggan ?? '');
    final phoneController =
        TextEditingController(text: existingCustomer?.nomorTelepon ?? '');
    final formKey = GlobalKey<FormState>();
    bool isSavingInDialog = false; // Loading spesifik untuk dialog

    final Customer? savedCustomer = await showDialog<Customer>(
      context: scaffContext, // Gunakan context dari parameter
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
            // StatefulBuilder untuk update UI dialog (loading)
            builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: _dialogShape,
            elevation: 5.0,
            title: Text(isEdit ? "Edit Pelanggan" : "Tambah Pelanggan",
                style: _dialogTitleStyle(context)),
            actionsPadding: _dialogActionsPadding,
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                        labelText: "Nama Pelanggan",
                        hintText: "Nama lengkap",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.person_outline)),
                    style: GoogleFonts.poppins(),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Nama tidak boleh kosong'
                        : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: phoneController,
                    decoration: InputDecoration(
                        labelText: "Nomor Telepon (Opsional)",
                        hintText: "Contoh: 0812xxxx",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.phone_outlined)),
                    keyboardType: TextInputType.phone,
                    style: GoogleFonts.poppins(),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: isSavingInDialog
                    ? null
                    : () => Navigator.pop(dialogContext, null),
                style: _cancelButtonStyle(dialogContext),
                child: Text('Batal',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
              ),
              ElevatedButton.icon(
                icon: isSavingInDialog
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Icon(isEdit ? Icons.save_alt : Icons.add),
                label: Text(
                    isSavingInDialog
                        ? "Menyimpan..."
                        : (isEdit ? "Simpan" : "Tambah"),
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                style: _primaryActionButtonStyle(dialogContext),
                onPressed: isSavingInDialog
                    ? null
                    : () async {
                        if (formKey.currentState!.validate()) {
                          setDialogState(() => isSavingInDialog = true);
                          final result = await provider.addOrUpdateCustomer(
                            scaffContext, // Kirim context utama (dari build) untuk password dialog
                            existingCustomer: existingCustomer,
                            name: nameController.text,
                            phone: phoneController.text,
                          );
                          setDialogState(() => isSavingInDialog =
                              false); // Hentikan loading setelah selesai
                          if (result != null && dialogContext.mounted) {
                            // Pengecekan mounted
                            Navigator.pop(
                                dialogContext, result); // Kirim hasil kembali
                            _showSnackbar(
                                "Pelanggan '${result.namaPelanggan}' berhasil ${isEdit ? 'diperbarui' : 'ditambahkan'}.",
                                isError: false);
                          } else if (provider.errorMessage.isNotEmpty &&
                              dialogContext.mounted) {
                            _showSnackbar(provider.errorMessage, isError: true);
                            // Jangan tutup dialog jika error, biarkan user coba lagi atau batal
                          }
                        }
                      },
              ),
            ],
          );
        });
      },
    );
    // Setelah dialog ditutup, tidak perlu load manual, provider sudah handle di addOrUpdateCustomer
  }

  // --- Dialog Opsi Edit/Hapus (MEMANGGIL PROVIDER) ---
  Future<void> _showEditDeleteOptionsDialog(BuildContext scaffContext,
      CustomerProvider provider, Customer customer) async {
    final result = await showModalBottomSheet<String>(
      context: scaffContext, // Gunakan context dari parameter
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.0))),
      builder: (BuildContext context) {
        // Context baru untuk bottom sheet
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.edit_outlined, color: _primaryColor),
                title: Text('Edit Pelanggan', style: GoogleFonts.poppins()),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
              ListTile(
                leading: Icon(Icons.delete_outline,
                    color: Theme.of(scaffContext).colorScheme.error),
                title: Text('Hapus Pelanggan',
                    style: GoogleFonts.poppins(
                        color: Theme.of(scaffContext).colorScheme.error)),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
              const SizedBox(height: 10),
              TextButton(
                child: Text('Batal',
                    style: GoogleFonts.poppins(color: Colors.grey.shade600)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );

    if (result == 'edit') {
      // Panggil dialog edit dengan context dan provider
      await _showAddEditCustomerDialog(scaffContext, provider,
          existingCustomer: customer);
    } else if (result == 'delete') {
      final success = await provider.deleteCustomer(scaffContext, customer);
      if (success && scaffContext.mounted) {
        // scaffContext masih mounted?
        _showSnackbar(
            'Pelanggan "${customer.namaPelanggan}" berhasil dihapus.');
      } else if (!success &&
          provider.errorMessage.isNotEmpty &&
          scaffContext.mounted) {
        _showSnackbar(provider.errorMessage, isError: true);
      }
    }
  }

  // Helper Widget untuk List Item (bisa tetap di sini)
  Widget _buildCustomerListItem(
      Customer customer, CustomerProvider provider, BuildContext itemContext) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
            backgroundColor: _iconBgColor,
            radius: 25,
            child: Icon(Icons.person_outline, color: _iconColor, size: 26)),
        title: Text(customer.namaPelanggan,
            style:
                GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: customer.nomorTelepon != null &&
                customer.nomorTelepon!.isNotEmpty
            ? Text(customer.nomorTelepon!,
                style: GoogleFonts.poppins(
                    fontSize: 12.5, color: Colors.grey.shade600))
            : Text('- Tanpa nomor telepon -',
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade400,
                    fontStyle: FontStyle.italic)),
        trailing: IconButton(
          icon: Icon(Icons.more_vert, color: Colors.grey.shade500),
          tooltip: 'Opsi',
          onPressed: () =>
              _showEditDeleteOptionsDialog(itemContext, provider, customer),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ambil instance CustomerProvider
    final customerProvider = context.watch<CustomerProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Kelola Pelanggan',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: _primaryColor)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shadowColor: Colors.black26,
        foregroundColor: _primaryColor,
        elevation: 1.0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Tambah Pelanggan',
            // Panggil _showAddEditCustomerDialog dengan BuildContext dari Scaffold
            onPressed: () =>
                _showAddEditCustomerDialog(context, customerProvider),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF7F8FC),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 10.0),
            child: Row(children: [
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
                            offset: const Offset(0, 1))
                      ]),
                  child: TextField(
                    controller: _searchController,
                    // onChanged akan memanggil provider
                    onChanged: (query) =>
                        customerProvider.setSearchQuery(query),
                    decoration: InputDecoration(
                      hintText: 'Cari Nama / No. Telp',
                      hintStyle: GoogleFonts.poppins(
                          color: Colors.grey.shade500, fontSize: 14),
                      prefixIcon: Icon(Icons.search,
                          color: Colors.grey.shade600, size: 22),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear,
                                  color: Colors.grey.shade500, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                customerProvider
                                    .setSearchQuery(''); // Reset di provider
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
                        fontSize: 14, color: Colors.black87),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: () =>
                    customerProvider.toggleSortOrder(), // Panggil dari provider
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10.0),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 1))
                      ]),
                  child: Tooltip(
                    message: customerProvider.sortAscending
                        ? 'Urutkan Z-A'
                        : 'Urutkan A-Z',
                    child: Icon(Icons.sort_by_alpha,
                        color: _primaryColor, size: 24),
                  ),
                ),
              ),
            ]),
          ),
          Expanded(
            child: customerProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : customerProvider.errorMessage.isNotEmpty
                    ? Center(
                        child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(customerProvider.errorMessage,
                                style: GoogleFonts.poppins(color: Colors.red),
                                textAlign: TextAlign.center)))
                    // : customerProvider.allCustomers.isEmpty // Cek data asli (sebelum filter)
                    //     ? Center(child: Text('Belum ada pelanggan.', textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.grey.shade500)))
                    : customerProvider.filteredCustomers.isEmpty
                        ? Center(
                            child: Text(
                              _searchController.text.isEmpty &&
                                      customerProvider.searchQuery
                                          .isEmpty // Tambahan kondisi jika filter dan search query kosong
                                  ? 'Belum ada pelanggan terdaftar.'
                                  : 'Pelanggan "${_searchController.text}" tidak ditemukan.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                  color: Colors.grey.shade500),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => customerProvider.loadCustomers(),
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                  16.0, 8.0, 16.0, 16.0),
                              itemCount:
                                  customerProvider.filteredCustomers.length,
                              itemBuilder: (context, index) {
                                // Berikan context item untuk dialog yang dipanggil dari item
                                return _buildCustomerListItem(
                                    customerProvider.filteredCustomers[index],
                                    customerProvider,
                                    context);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
