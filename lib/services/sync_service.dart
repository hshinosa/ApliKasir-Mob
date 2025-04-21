// lib/services/sync_service.dart
import 'dart:convert';
import 'package:flutter/material.dart'; // Untuk BuildContext
import 'package:shared_preferences/shared_preferences.dart';
import 'api_services.dart'; // Pastikan path ini benar
import '../helper/db_helper.dart';
// Impor model yang sudah diupdate
import '../model/product_model.dart';
import '../model/customer_model.dart';
import '../model/transaction_model.dart';

class SyncService {
  final ApiService _apiService = ApiService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  static bool _isSyncing = false; // Static flag

  Future<DateTime?> getLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestampString = prefs.getString('lastSyncTimestamp');
      return timestampString != null
          ? DateTime.tryParse(timestampString)
          : null;
    } catch (e) {
      print("SyncService Error getting last sync time: $e");
      return null;
    }
  }

  Future<void> setLastSyncTime(DateTime timestamp) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastSyncTimestamp', timestamp.toIso8601String());
      print(
          "SyncService: New Last Sync Time saved: ${timestamp.toIso8601String()}");
    } catch (e) {
      print("SyncService Error setting last sync time: $e");
    }
  }

  Future<Map<String, dynamic>> _getLocalChanges(DateTime? lastSyncTime) async {
    final Map<String, dynamic> changes = {
      'newProducts': [],
      'updatedProducts': [],
      'deletedProductIds': [],
      'newCustomers': [],
      'updatedCustomers': [],
      'deletedCustomerIds': [],
      'newTransactions': [],
      'deletedTransactionIds': [],
    };

    try {
      // --- Products ---
      final productsToSync = await _dbHelper.getProductsForSync(lastSyncTime);
      for (var p in productsToSync) {
        final map = p.toMap(); // Gunakan toMap dasar
        map['local_id'] = p.id; // ID lokal penting untuk markSyncedItems
        map['created_at'] = p.createdAt; // Kirim timestamp lokal
        map['updated_at'] = p.updatedAt; // Kirim timestamp lokal
        map['is_deleted'] = p.isDeleted; // Kirim status delete

        if (p.syncStatus == 'new')
          changes['newProducts']!.add(map);
        else if (p.syncStatus == 'updated')
          changes['updatedProducts']!.add(map);
        else if (p.syncStatus == 'deleted' && p.id != null)
          changes['deletedProductIds']!.add(p.id!);
      }

      // --- Customers ---
      final customersToSync = await _dbHelper.getCustomersForSync(lastSyncTime);
      for (var c in customersToSync) {
        final map = c.toMap();
        map['local_id'] = c.id;
        map['created_at'] =
            c.createdAt.toIso8601String(); // Pastikan format ISO
        map['updated_at'] = c.updatedAt?.toIso8601String(); // Handle nullable
        map['is_deleted'] = c.isDeleted;

        if (c.syncStatus == 'new')
          changes['newCustomers']!.add(map);
        else if (c.syncStatus == 'updated')
          changes['updatedCustomers']!.add(map);
        else if (c.syncStatus == 'deleted' && c.id != null)
          changes['deletedCustomerIds']!.add(c.id!);
      }

      // --- Transactions ---
      final transactionsToSync =
          await _dbHelper.getTransactionsForSync(lastSyncTime);
      for (var t in transactionsToSync) {
        final map = t.toMap();
        map['local_id'] = t.id;
        map['created_at'] = t.createdAt?.toIso8601String();
        map['updated_at'] = t.updatedAt?.toIso8601String();
        map['detail_items'] = jsonEncode(t.detailItems); // Encode detail items
        map['is_deleted'] = t.isDeleted;

        if (t.syncStatus == 'new')
          changes['newTransactions']!.add(map);
        // else if (t.syncStatus == 'updated') changes['updatedTransactions']!.add(map); // Jika ada update transaksi
        else if (t.syncStatus == 'deleted' && t.id != null)
          changes['deletedTransactionIds']!.add(t.id!);
      }

      print("SyncService: Local changes prepared: "
          "P(N${changes['newProducts']?.length}/U${changes['updatedProducts']?.length}/D${changes['deletedProductIds']?.length}), "
          "C(N${changes['newCustomers']?.length}/U${changes['updatedCustomers']?.length}/D${changes['deletedCustomerIds']?.length}), "
          "T(N${changes['newTransactions']?.length}/D${changes['deletedTransactionIds']?.length})");
    } catch (e) {
      print("SyncService Error preparing local changes: $e");
      // Mengembalikan map kosong jika error agar sync tetap bisa mencoba download
    }
    return changes;
  }

  Future<void> _applyServerChanges(Map<String, dynamic>? serverChanges) async {
    if (serverChanges == null || serverChanges.isEmpty) {
      print("SyncService: No server changes to apply.");
      return;
    }
    print("SyncService: Applying server changes...");
    final db = await _dbHelper.database;

    try {
      await db.transaction((txn) async {
        int appliedNewProd = 0, appliedUpdProd = 0, appliedDelProd = 0;
        int appliedNewCust = 0, appliedUpdCust = 0, appliedDelCust = 0;
        int appliedNewTx = 0, appliedDelTx = 0;

        // --- Products ---
        for (var pData in serverChanges['newProducts'] ?? []) {
          try {
            await _dbHelper.insertOrReplaceProductFromApi(
                txn, Product.fromMap(pData));
            appliedNewProd++;
          } catch (e) {
            print(
                " SyncService Error applying new product ${pData['id'] ?? pData['server_id']}: $e");
          } // Gunakan server_id jika ID null
        }
        for (var pData in serverChanges['updatedProducts'] ?? []) {
          try {
            await _dbHelper.insertOrReplaceProductFromApi(
                txn, Product.fromMap(pData));
            appliedUpdProd++;
          } catch (e) {
            print(
                " SyncService Error applying updated product ${pData['id'] ?? pData['server_id']}: $e");
          }
        }
        for (int serverId in serverChanges['deletedProductIds'] ?? []) {
          try {
            await _dbHelper.deleteProductLocalFromServer(txn, serverId);
            appliedDelProd++;
          } catch (e) {
            print(
                " SyncService Error applying deleted product serverId $serverId: $e");
          }
        }

        // --- Customers ---
        for (var cData in serverChanges['newCustomers'] ?? []) {
          try {
            await _dbHelper.insertOrReplaceCustomerFromApi(
                txn, Customer.fromMap(cData));
            appliedNewCust++;
          } catch (e) {
            print(
                " SyncService Error applying new customer ${cData['id'] ?? cData['server_id']}: $e");
          }
        }
        for (var cData in serverChanges['updatedCustomers'] ?? []) {
          try {
            await _dbHelper.insertOrReplaceCustomerFromApi(
                txn, Customer.fromMap(cData));
            appliedUpdCust++;
          } catch (e) {
            print(
                " SyncService Error applying updated customer ${cData['id'] ?? cData['server_id']}: $e");
          }
        }
        for (int serverId in serverChanges['deletedCustomerIds'] ?? []) {
          try {
            await _dbHelper.deleteCustomerLocalFromServer(txn, serverId);
            appliedDelCust++;
          } catch (e) {
            print(
                " SyncService Error applying deleted customer serverId $serverId: $e");
          }
        }

        // --- Transactions ---
        for (var tData in serverChanges['newTransactions'] ?? []) {
          try {
            if (tData['detail_items'] is String) {
              try {
                tData['detail_items'] = jsonDecode(tData['detail_items']);
              } catch (_) {
                tData['detail_items'] = [];
              }
            } else if (tData['detail_items'] is! List) {
              tData['detail_items'] = [];
            }
            await _dbHelper.insertOrReplaceTransactionFromApi(
                txn, TransactionModel.fromMap(tData));
            appliedNewTx++;
          } catch (e) {
            print(
                " SyncService Error applying new transaction ${tData['id'] ?? tData['server_id']}: $e");
          }
        }
        // Handle updated/deleted transactions jika ada
        for (int serverId in serverChanges['deletedTransactionIds'] ?? []) {
          try {
            await _dbHelper.deleteTransactionLocalFromServer(txn, serverId);
            appliedDelTx++;
          } catch (e) {
            print(
                " SyncService Error applying deleted transaction serverId $serverId: $e");
          }
        }

        print("SyncService: Server changes applied summary: "
            "Prod(N$appliedNewProd/U$appliedUpdProd/D$appliedDelProd), "
            "Cust(N$appliedNewCust/U$appliedUpdCust/D$appliedDelCust), "
            "Tx(N$appliedNewTx/D$appliedDelTx)");
      });
      print(
          "SyncService: Database transaction for applying server changes committed.");
    } catch (e) {
      print(
          "SyncService Error during DB transaction for applying server changes: $e");
      throw Exception("Failed to apply server changes locally: $e");
    }
  }

  Future<bool> performSync() async {
    if (_isSyncing) {
      print("SyncService: Sync already in progress.");
      return false;
    }
    _isSyncing = true;
    print("SyncService: Starting synchronization...");
    bool success = false;

    try {
      final lastSync = await getLastSyncTime();
      print(
          "SyncService: Client Last Sync Time: ${lastSync?.toIso8601String()}");

      final localChanges = await _getLocalChanges(lastSync);

      // Panggil API
      final syncResponse = await _apiService.synchronize(
          lastSync?.toIso8601String(), localChanges);

      // Proses response server
      final serverChanges = syncResponse['serverChanges'];
      final newServerTimestampString = syncResponse['newServerTimestamp'];

      if (newServerTimestampString == null) {
        throw Exception(
            "SyncService Error: Server did not return a new sync timestamp.");
      }
      final newServerTimestamp = DateTime.parse(newServerTimestampString);

      // Terapkan perubahan server ke DB lokal
      if (serverChanges != null && serverChanges is Map<String, dynamic>) {
        await _applyServerChanges(serverChanges);
      } else {
        print("SyncService: No valid server changes received in response.");
      }

      // Tandai item lokal yang DIKIRIM sebagai synced/deleted
      await _dbHelper.markSyncedItems(localChanges);

      // Simpan timestamp sync terakhir yang sukses
      await setLastSyncTime(newServerTimestamp);

      print(
          "SyncService: Synchronization finished successfully at ${newServerTimestamp.toIso8601String()}");
      success = true;
    } catch (e) {
      print("SyncService: Synchronization failed: $e");
      if (e is Exception) print("SyncService Error details: ${e.toString()}");
      success = false;
    } finally {
      _isSyncing = false;
      print(
          "SyncService: Sync process finished. Result: ${success ? 'Success' : 'Failure'}");
    }
    return success;
  }

  Future<void> triggerSync(
      {bool showSnackbar = false, BuildContext? context}) async {
    if (showSnackbar && (context == null || !context.mounted)) {
      print("SyncService Warning: Cannot show snackbar, context is invalid.");
      showSnackbar = false;
    }

    final result = await performSync(); // Tunggu hasilnya

    // Tampilkan snackbar HANYA jika diminta dan context valid
    if (showSnackbar && context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result
            ? 'Sinkronisasi data berhasil!'
            : 'Sinkronisasi data gagal. Coba lagi nanti.'),
        backgroundColor: result ? Colors.green.shade600 : Colors.redAccent,
        duration: Duration(seconds: result ? 2 : 4), // Lebih lama jika gagal
      ));
    }
  }
} // --- Akhir SyncService ---
