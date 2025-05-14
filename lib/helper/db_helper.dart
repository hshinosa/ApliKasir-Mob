import 'dart:convert'; // Untuk jsonEncode/Decode
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

// Impor model (Pastikan path ini benar dan model sudah diupdate)
import '../model/user_model.dart';
import '../model/product_model.dart';
import '../model/transaction_model.dart';
import '../model/customer_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;
  // Beri nama unik jika ingin reset total saat upgrade besar
  static const String dbName = 'aplikasir_mobile_v6_sync.db';
  static const int dbVersion = 6; // Versi dengan sync_status & soft delete

  DatabaseHelper._privateConstructor();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, dbName);
    print("Database path: $path");
    return await openDatabase(
      path,
      version: dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      // Aktifkan foreign key constraint jika diperlukan
      // onConfigure: (db) async {
      //   await db.execute('PRAGMA foreign_keys = ON');
      // },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    print("Creating database tables version $version...");
    await _createUsersTable(db);
    await _createProductsTable(db);
    await _createCustomersTable(db);
    await _createTransactionsTable(db);
    print("All initial tables created with latest schema (v$version).");
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print("Upgrading database from version $oldVersion to $newVersion");
    var batch = db.batch();

    // Contoh Migrasi dari v5 ke v6 (Tambahkan migrasi sebelumnya jika perlu)
    if (oldVersion < 6) {
      print("Applying upgrades for v5 to v6 (Adding sync columns)...");
      // Products
      try {
        batch.execute(
            'ALTER TABLE products ADD COLUMN sync_status TEXT DEFAULT \'synced\'');
        print("  Added sync_status to products.");
      } catch (e) {
        print("  Col sync_status likely exists in products.");
      }
      try {
        batch.execute(
            'ALTER TABLE products ADD COLUMN is_deleted INTEGER DEFAULT 0');
        print("  Added is_deleted to products.");
      } catch (e) {
        print("  Col is_deleted likely exists in products.");
      }
      try {
        batch.execute('ALTER TABLE products ADD COLUMN deleted_at TEXT NULL');
        print("  Added deleted_at to products.");
      } catch (e) {
        print("  Col deleted_at likely exists in products.");
      }
      // Customers
      try {
        batch.execute(
            'ALTER TABLE customers ADD COLUMN sync_status TEXT DEFAULT \'synced\'');
        print("  Added sync_status to customers.");
      } catch (e) {
        print("  Col sync_status likely exists in customers.");
      }
      try {
        batch.execute(
            'ALTER TABLE customers ADD COLUMN is_deleted INTEGER DEFAULT 0');
        print("  Added is_deleted to customers.");
      } catch (e) {
        print("  Col is_deleted likely exists in customers.");
      }
      try {
        batch.execute('ALTER TABLE customers ADD COLUMN deleted_at TEXT NULL');
        print("  Added deleted_at to customers.");
      } catch (e) {
        print("  Col deleted_at likely exists in customers.");
      }
      try {
        batch.execute('ALTER TABLE customers ADD COLUMN updated_at TEXT NULL');
        print("  Added updated_at to customers.");
      } catch (e) {
        print("  Col updated_at likely exists in customers.");
      } // Pastikan ada updated_at
      // Transactions
      try {
        batch.execute(
            'ALTER TABLE transactions ADD COLUMN sync_status TEXT DEFAULT \'synced\'');
        print("  Added sync_status to transactions.");
      } catch (e) {
        print("  Col sync_status likely exists in transactions.");
      }
      try {
        batch.execute(
            'ALTER TABLE transactions ADD COLUMN is_deleted INTEGER DEFAULT 0');
        print("  Added is_deleted to transactions.");
      } catch (e) {
        print("  Col is_deleted likely exists in transactions.");
      }
      try {
        batch.execute(
            'ALTER TABLE transactions ADD COLUMN deleted_at TEXT NULL');
        print("  Added deleted_at to transactions.");
      } catch (e) {
        print("  Col deleted_at likely exists in transactions.");
      }
      try {
        batch.execute(
            'ALTER TABLE transactions ADD COLUMN created_at TEXT NULL');
        print("  Added created_at to transactions.");
      } catch (e) {
        print("  Col created_at likely exists in transactions.");
      } // Pastikan ada created_at
      try {
        batch.execute(
            'ALTER TABLE transactions ADD COLUMN updated_at TEXT NULL');
        print("  Added updated_at to transactions.");
      } catch (e) {
        print("  Col updated_at likely exists in transactions.");
      } // Pastikan ada updated_at
    }

    try {
      await batch.commit(noResult: true);
      print("Batch upgrade commit successful.");
    } catch (e) {
      print("Error committing batch upgrade: $e");
    }

    // Recreate users table jika upgrade dari < v4
    if (oldVersion < 4) {
      // Asumsi v4 adalah versi SEBELUM user direcreate
      print("Recreating users table (upgrade from v < 4)...");
      try {
        await db.execute('DROP TABLE IF EXISTS users_old'); // Backup jika perlu
        await db.execute('ALTER TABLE users RENAME TO users_old');
      } catch (e) {
        print("Could not rename old users table: $e");
      }
      try {
        await _createUsersTable(db);
        print("Recreated 'users' table.");
        // Migrasi data lama jika perlu (kompleks)
        // await db.execute('INSERT INTO users (id, name, ...) SELECT id, name, ... FROM users_old');
        // await db.execute('DROP TABLE users_old');
      } catch (e) {
        print("Error recreating users table after upgrade: $e");
      }
    }

    print("Database upgrade process finished.");
  }

  // --- Skema Tabel (v6) ---
  Future<void> _createUsersTable(Database db) async {
    // ID dari server, bukan autoincrement lokal
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        phoneNumber TEXT UNIQUE NOT NULL,
        storeName TEXT NOT NULL,
        storeAddress TEXT NOT NULL,
        passwordHash TEXT NOT NULL,
        profileImagePath TEXT NULL,
        created_at TEXT,
        updated_at TEXT,
        last_sync_time TEXT
      )
    ''');
    print("Table 'users' created.");
  }

  Future<void> _createProductsTable(Database db) async {
    await db.execute('''
      CREATE TABLE products(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER UNIQUE, -- ID dari server (opsional, untuk mapping)
        id_pengguna INTEGER NOT NULL,
        nama_produk TEXT NOT NULL,
        kode_produk TEXT,
        jumlah_produk INTEGER NOT NULL DEFAULT 0,
        harga_modal REAL NOT NULL DEFAULT 0.0,
        harga_jual REAL NOT NULL DEFAULT 0.0,
        gambar_produk TEXT,
        created_at TEXT,
        updated_at TEXT,
        sync_status TEXT DEFAULT 'synced', -- 'new', 'updated', 'deleted', 'synced'
        is_deleted INTEGER DEFAULT 0,     -- 0 = false, 1 = true
        deleted_at TEXT NULL,
        FOREIGN KEY (id_pengguna) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    print("Table 'products' created (v6 schema).");
  }

  Future<void> _createCustomersTable(Database db) async {
    await db.execute('''
      CREATE TABLE customers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER UNIQUE, -- ID dari server (opsional)
        id_pengguna INTEGER NOT NULL,
        nama_pelanggan TEXT NOT NULL,
        nomor_telepon TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        sync_status TEXT DEFAULT 'synced',
        is_deleted INTEGER DEFAULT 0,
        deleted_at TEXT NULL,
        FOREIGN KEY (id_pengguna) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    print("Table 'customers' created (v6 schema).");
  }

  Future<void> _createTransactionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER UNIQUE, -- ID dari server (opsional)
        id_pengguna INTEGER NOT NULL,
        tanggal_transaksi TEXT NOT NULL,
        total_belanja REAL NOT NULL,
        total_modal REAL NOT NULL,
        metode_pembayaran TEXT NOT NULL,
        status_pembayaran TEXT NOT NULL,
        id_pelanggan INTEGER,
        detail_items TEXT NOT NULL,
        jumlah_bayar REAL NULL,
        jumlah_kembali REAL NULL,
        id_transaksi_hutang INTEGER NULL,
        created_at TEXT,
        updated_at TEXT,
        sync_status TEXT DEFAULT 'synced',
        is_deleted INTEGER DEFAULT 0,
        deleted_at TEXT NULL,
        FOREIGN KEY (id_pengguna) REFERENCES users(id) ON DELETE CASCADE,
        -- Merujuk ke ID LOKAL pelanggan (jika pakai autoincrement lokal)
        FOREIGN KEY (id_pelanggan) REFERENCES customers(id) ON DELETE SET NULL
        -- Jika id_pelanggan merujuk ke server_id customer, perlu penyesuaian
        -- FOREIGN KEY (id_transaksi_hutang) REFERENCES transactions(id) ON DELETE SET NULL
      )
    ''');
    print("Table 'transactions' created (v6 schema).");
  }

  // --- User CRUD ---
  Future<int> insertOrReplaceUser(User user) async {
    final db = await database;
    final userMap = user.toMapWithTimestamps(); // Fungsi baru di model?

    if (user.id == null) {
      print("Error: Trying to insert/replace user without an ID from server.");
      return 0; // Gagal
    }

    // Pastikan ID ada di map untuk replace
    userMap['id'] = user.id;
    // Password hash tidak disimpan/diupdate dari sini
    userMap.remove('passwordHash');

    print("Inserting/Replacing local user data for ID: ${user.id}");
    try {
      // ID di tabel users adalah primary key dari server, bukan autoincrement
      int result = await db.insert(
        'users',
        userMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print("Local user insert/replace result (ID: ${user.id}): $result");
      return result; // Mengembalikan row ID atau jumlah row terpengaruh
    } catch (e) {
      print("Error in insertOrReplaceUser: $e");
      throw Exception("Failed to save local user data: ${e.toString()}");
    }
  }

  Future<User?> getUserById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('users',
        columns: [
          'id',
          'name',
          'email',
          'phoneNumber',
          'storeName',
          'storeAddress',
          'profileImagePath',
          'created_at',
          'updated_at',
          'last_sync_time'
        ],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1);
    if (maps.isNotEmpty) {
      // Tambahkan passwordHash dummy jika model memerlukannya
      var userMap = Map<String, dynamic>.from(maps.first);
      userMap['passwordHash'] =
          ''; // Atau ambil dari secure storage jika ada offline auth
      return User.fromMap(userMap);
    }
    return null;
  }

  // --- Product CRUD Lokal (Sync-Aware) ---

  Future<int> insertProductLocal(Product product) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final productMap = product.toMap(); // Gunakan toMap dasar
    productMap.remove('id'); // Hapus ID jika ada (karena autoincrement lokal)
    productMap['created_at'] = now;
    productMap['updated_at'] = now;
    productMap['sync_status'] = 'new';
    productMap['is_deleted'] = 0;
    productMap.remove('server_id'); // Hapus server_id jika ada di map
    productMap.remove('deleted_at');
    productMap.remove('syncStatus'); // Hapus key model jika ada
    productMap.remove('isDeleted'); // Hapus key model jika ada
    productMap.remove('deletedAt'); // Hapus key model jika ada

    try {
      int localId = await db.insert('products', productMap,
          conflictAlgorithm: ConflictAlgorithm.fail);
      print("Inserted local product (ID: $localId) with sync_status 'new'.");
      return localId;
    } catch (e) {
      print("Error inserting local product: $e");
      if (e is DatabaseException && e.isUniqueConstraintError()) {
        throw Exception(
            "Local DB: Kode produk '${product.kodeProduk}' sudah ada.");
      }
      throw Exception("Gagal menambahkan produk lokal.");
    }
  }

  Future<int> updateProductLocal(Product product) async {
    if (product.id == null)
      throw ArgumentError("Local Product ID null for update.");
    final db = await database;
    final now = DateTime.now().toIso8601String();

    String currentSyncStatus = 'synced';
    final currentProductData = await db.query('products',
        columns: ['sync_status'], where: 'id = ?', whereArgs: [product.id]);
    if (currentProductData.isNotEmpty) {
      currentSyncStatus =
          currentProductData.first['sync_status'] as String? ?? 'synced';
    }

    final productMap = product.toMap();
    productMap.remove('id'); // Jangan update ID lokal
    productMap.remove('created_at');
    productMap.remove('server_id');
    productMap.remove('syncStatus');
    productMap.remove('isDeleted');
    productMap.remove('deletedAt');
    productMap['updated_at'] = now;
    productMap['sync_status'] =
        (currentSyncStatus == 'new') ? 'new' : 'updated';
    productMap['is_deleted'] = 0; // Pastikan tidak terhapus
    productMap['deleted_at'] = null; // Hapus timestamp delete

    try {
      int rowsAffected = await db.update('products', productMap,
          where: 'id = ? AND id_pengguna = ?',
          whereArgs: [product.id, product.idPengguna],
          conflictAlgorithm: ConflictAlgorithm.fail);
      print(
          "Updated local product (ID: ${product.id}), sync_status set to '${productMap['sync_status']}'. Rows affected: $rowsAffected");
      return rowsAffected;
    } catch (e) {
      print("Error updating local product: $e");
      if (e is DatabaseException && e.isUniqueConstraintError()) {
        throw Exception(
            "Local DB: Kode produk '${product.kodeProduk}' mungkin sudah digunakan.");
      }
      throw Exception("Gagal memperbarui produk lokal.");
    }
  }

  Future<int> softDeleteProductLocal(int id, int userId) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    try {
      int rowsAffected = await db.update(
        'products',
        {
          'is_deleted': 1,
          'deleted_at': now,
          'sync_status': 'deleted',
          'updated_at': now
        },
        where: 'id = ? AND id_pengguna = ? AND is_deleted = 0',
        whereArgs: [id, userId],
      );
      print(
          "Soft deleted local product (ID: $id), sync_status set to 'deleted'. Rows affected: $rowsAffected");
      return rowsAffected;
    } catch (e) {
      print("Error soft deleting product: $e");
      throw Exception("Gagal menghapus produk lokal.");
    }
  }

  // --- Customer CRUD Lokal (Sync-Aware) - Implementasi Serupa ---
  Future<int> insertCustomerLocal(Customer customer) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final customerMap = customer.toMap();
    customerMap.remove('id');
    customerMap['created_at'] = now;
    customerMap['updated_at'] = now;
    customerMap['sync_status'] = 'new';
    customerMap['is_deleted'] = 0;
    customerMap.remove('server_id');
    customerMap.remove('deleted_at');
    customerMap.remove('syncStatus');
    customerMap.remove('isDeleted');
    customerMap.remove('deletedAt');

    try {
      int localId = await db.insert('customers', customerMap,
          conflictAlgorithm: ConflictAlgorithm.fail);
      print("Inserted local customer (ID: $localId) with sync_status 'new'.");
      return localId;
    } catch (e) {
      print("Error inserting local customer: $e");
      throw Exception("Gagal menambahkan pelanggan lokal.");
    }
  }

  Future<int> updateCustomerLocal(Customer customer) async {
    if (customer.id == null)
      throw ArgumentError("Local Customer ID null for update.");
    final db = await database;
    final now = DateTime.now().toIso8601String();

    String currentSyncStatus = 'synced';
    final currentData = await db.query('customers',
        columns: ['sync_status'], where: 'id = ?', whereArgs: [customer.id]);
    if (currentData.isNotEmpty)
      currentSyncStatus =
          currentData.first['sync_status'] as String? ?? 'synced';

    final customerMap = customer.toMap();
    customerMap.remove('id');
    customerMap.remove('created_at');
    customerMap.remove('server_id');
    customerMap.remove('syncStatus');
    customerMap.remove('isDeleted');
    customerMap.remove('deletedAt');
    customerMap['updated_at'] = now;
    customerMap['sync_status'] =
        (currentSyncStatus == 'new') ? 'new' : 'updated';
    customerMap['is_deleted'] = 0;
    customerMap['deleted_at'] = null;

    try {
      int rowsAffected = await db.update('customers', customerMap,
          where: 'id = ? AND id_pengguna = ?',
          whereArgs: [customer.id, customer.idPengguna]);
      print(
          "Updated local customer (ID: ${customer.id}), sync_status set to '${customerMap['sync_status']}'. Rows affected: $rowsAffected");
      return rowsAffected;
    } catch (e) {
      print("Error updating local customer: $e");
      throw Exception("Gagal memperbarui pelanggan lokal.");
    }
  }

  Future<int> softDeleteCustomerLocal(int id, int userId) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    try {
      int rowsAffected = await db.update(
          'customers',
          {
            'is_deleted': 1,
            'deleted_at': now,
            'sync_status': 'deleted',
            'updated_at': now
          },
          where: 'id = ? AND id_pengguna = ? AND is_deleted = 0',
          whereArgs: [id, userId]);
      print(
          "Soft deleted local customer (ID: $id), sync_status set to 'deleted'. Rows affected: $rowsAffected");
      return rowsAffected;
    } catch (e) {
      print("Error soft deleting customer: $e");
      throw Exception("Gagal menghapus pelanggan lokal.");
    }
  }

  // --- Transaction CRUD Lokal (Sync-Aware) - Implementasi Serupa ---
  Future<int> insertTransactionLocal(TransactionModel transaction) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    Map<String, dynamic> transactionMap = transaction.toMap();
    transactionMap.remove('id');
    transactionMap['created_at'] = now;
    transactionMap['updated_at'] = now;
    transactionMap['sync_status'] = 'new';
    transactionMap['is_deleted'] = 0;
    transactionMap.remove('server_id');
    transactionMap.remove('deleted_at');
    transactionMap.remove('syncStatus');
    transactionMap.remove('isDeleted');
    transactionMap.remove('deletedAt');
    transactionMap['detail_items'] = jsonEncode(transaction.detailItems);

    // Transaksi DB untuk insert dan update stok/status hutang lama
    try {
      int? newTxId;
      await db.transaction((txn) async {
        newTxId = await txn.insert('transactions', transactionMap,
            conflictAlgorithm: ConflictAlgorithm.fail);

        if (!transaction.metodePembayaran.startsWith('Pembayaran Kredit')) {
          // Update stok produk
          for (var item in transaction.detailItems) {
            String currentProdSyncStatus = 'synced';
            final pData = await txn.query('products',
                columns: ['sync_status'],
                where: 'id = ?',
                whereArgs: [item['product_id']]);
            if (pData.isNotEmpty)
              currentProdSyncStatus =
                  pData.first['sync_status'] as String? ?? 'synced';
            final newProdSyncStatus =
                (currentProdSyncStatus == 'new') ? 'new' : 'updated';

            await txn.rawUpdate(
                'UPDATE products SET jumlah_produk = jumlah_produk - ?, updated_at = ?, sync_status = ? WHERE id = ? AND jumlah_produk >= ?',
                [
                  item['quantity'],
                  now,
                  newProdSyncStatus,
                  item['product_id'],
                  item['quantity']
                ]);
            // TODO: Tambahkan pengecekan affectedRows untuk stock update di sini jika perlu
          }
        } else if (transaction.idTransaksiHutang != null) {
          // Update status hutang lama menjadi 'Lunas' dan 'updated'
          String currentDebtSyncStatus = 'synced';
          final dData = await txn.query('transactions',
              columns: ['sync_status'],
              where: 'id = ?',
              whereArgs: [transaction.idTransaksiHutang]);
          if (dData.isNotEmpty)
            currentDebtSyncStatus =
                dData.first['sync_status'] as String? ?? 'synced';
          final newDebtSyncStatus =
              (currentDebtSyncStatus == 'new') ? 'new' : 'updated';

          await txn.update(
              'transactions',
              {
                'status_pembayaran': 'Lunas',
                'updated_at': now,
                'sync_status': newDebtSyncStatus
              },
              where: 'id = ?',
              whereArgs: [transaction.idTransaksiHutang]);
        }
      });
      if (newTxId != null) {
        print(
            "Inserted local transaction (ID: $newTxId) with sync_status 'new'.");
        return newTxId!;
      } else {
        throw Exception("Transaction insert failed within DB transaction.");
      }
    } catch (e) {
      print("Error inserting local transaction with stock/debt update: $e");
      throw Exception("Gagal menyimpan transaksi lokal: ${e.toString()}");
    }
  }

  // Update status lokal (misal saat bayar hutang via UI lokal sebelum sync)
  Future<int> updateTransactionStatusLocal(
      int transactionId, String newStatus) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    String currentSyncStatus = 'synced';
    final currentData = await db.query('transactions',
        columns: ['sync_status'], where: 'id = ?', whereArgs: [transactionId]);
    if (currentData.isNotEmpty)
      currentSyncStatus =
          currentData.first['sync_status'] as String? ?? 'synced';
    final newSyncStatus = (currentSyncStatus == 'new') ? 'new' : 'updated';

    print(
        "Updating local transaction $transactionId status to '$newStatus', sync_status to '$newSyncStatus'");
    try {
      return await db.update(
        'transactions',
        {
          'status_pembayaran': newStatus,
          'sync_status': newSyncStatus,
          'updated_at': now
        },
        where: 'id = ?',
        whereArgs: [transactionId],
      );
    } catch (e) {
      print("Error updating local transaction status: $e");
      throw Exception("Gagal update status transaksi lokal.");
    }
  }

  // Soft delete lokal (hati-hati dengan implikasi stok)
  Future<int> softDeleteTransactionLocal(int id, int userId) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    print(
        "Warning: Soft deleting transaction $id. Stock adjustments NOT handled automatically.");
    try {
      int rowsAffected = await db.update(
          'transactions',
          {
            'is_deleted': 1,
            'deleted_at': now,
            'sync_status': 'deleted',
            'updated_at': now
          },
          where: 'id = ? AND id_pengguna = ? AND is_deleted = 0',
          whereArgs: [id, userId]);
      print(
          "Soft deleted local transaction (ID: $id), sync_status set to 'deleted'. Rows affected: $rowsAffected");
      return rowsAffected;
    } catch (e) {
      print("Error soft deleting transaction: $e");
      throw Exception("Gagal menghapus transaksi lokal.");
    }
  }

  // --- Get Data (Filter is_deleted) ---
  Future<List<Product>> getProductsByUserId(int userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('products',
        where: 'id_pengguna = ? AND is_deleted = 0', // <-- Filter is_deleted
        whereArgs: [userId],
        orderBy: 'nama_produk ASC');
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  Future<List<Customer>> getCustomersByUserId(int userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('customers',
        where: 'id_pengguna = ? AND is_deleted = 0', // <-- Filter is_deleted
        whereArgs: [userId],
        orderBy: 'nama_pelanggan ASC');
    return List.generate(maps.length, (i) => Customer.fromMap(maps[i]));
  }

  Future<List<TransactionModel>> getTransactionsByUserId(int userId,
      {DateTime? startDate, DateTime? endDate}) async {
    final db = await database;
    String whereClause = 'id_pengguna = ? AND is_deleted = 0'; // <-- Filter
    List<dynamic> whereArgs = [userId];
    // Filter tanggal
    if (startDate != null && endDate != null) {
      /* ... logika sama ... */
    } else if (startDate != null) {/* ... logika sama ... */}

    final List<Map<String, dynamic>> maps = await db.query('transactions',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'tanggal_transaksi DESC');

    // Parsing JSON
    List<TransactionModel> transactions = [];
    for (var map in maps) {/* ... parsing sama ... */}
    return transactions;
  }

  Future<TransactionModel?> getTransactionById(int transactionId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('transactions',
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [transactionId],
        limit: 1); // <-- Filter
    if (maps.isNotEmpty) {/* ... parsing sama ... */}
    return null;
  }

  // Get Outstanding Credits (Filter is_deleted)
  Future<List<TransactionModel>> getOutstandingCreditTransactions(
      int userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where:
          'id_pengguna = ? AND metode_pembayaran = ? AND status_pembayaran = ? AND id_pelanggan IS NOT NULL AND is_deleted = 0', // <-- Filter
      whereArgs: [userId, 'Kredit', 'Belum Lunas'],
      orderBy: 'tanggal_transaksi DESC',
    );
    // ... (Parsing sama) ...
    List<TransactionModel> transactions = [];
    /* ... */ return transactions;
  }

  // Get Transactions by Customer ID (Filter is_deleted)
  Future<List<TransactionModel>> getTransactionsByCustomerId(
      int customerId, int userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where:
          'id_pengguna = ? AND id_pelanggan = ? AND is_deleted = 0', // <-- Filter
      whereArgs: [userId, customerId],
      orderBy: 'tanggal_transaksi DESC',
    );
    // ... (Parsing sama) ...
    List<TransactionModel> transactions = [];
    /* ... */ return transactions;
  }

  // --- Fungsi untuk Sinkronisasi ---

  Future<List<Product>> getProductsForSync(DateTime? lastSync) async {
    final db = await database;
    // Ambil semua yang statusnya bukan 'synced'
    // Atau yang updated_at nya lebih baru dari lastSync? (mungkin lebih efisien)
    // Pendekatan status lebih mudah dikelola di awal.
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'sync_status != ?',
      whereArgs: ['synced'],
    );
    print("Found ${maps.length} products to sync.");
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  Future<List<Customer>> getCustomersForSync(DateTime? lastSync) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'customers',
      where: 'sync_status != ?',
      whereArgs: ['synced'],
    );
    print("Found ${maps.length} customers to sync.");
    return List.generate(maps.length, (i) => Customer.fromMap(maps[i]));
  }

  Future<List<TransactionModel>> getTransactionsForSync(
      DateTime? lastSync) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'sync_status != ?',
      whereArgs: ['synced'],
    );
    print("Found ${maps.length} transactions to sync.");
    List<TransactionModel> transactions = [];
    for (var map in maps) {
      Map<String, dynamic> mutableMap = Map<String, dynamic>.from(map);
      mutableMap['detail_items'] =
          _parseDetailItems(mutableMap['detail_items'], mutableMap['id']);
      try {
        transactions.add(TransactionModel.fromMap(mutableMap));
      } catch (e) {
        print(
            "Error creating TransactionModel for sync from map: $map - Error: $e");
      }
    }
    return transactions;
  }

  // Fungsi Insert/Replace dari API (Jalankan dalam Transaction!)
  Future<int> insertOrReplaceProductFromApi(
      DatabaseExecutor txn, Product product) async {
    final productMap = product.toMap();
    // Gunakan server_id dari API sebagai acuan jika ada kolom server_id
    // Jika tidak ada kolom server_id, kita harus mengandalkan conflict replace pada ID lokal
    // yang mungkin tidak ada jika item baru dari server.
    // Pilihan:
    // 1. Tambah server_id ke skema lokal (seperti contoh di _createProductsTable)
    // 2. Coba cari berdasarkan kode produk + user ID? (jika kode unik)
    // 3. Andalkan `conflictAlgorithm: ConflictAlgorithm.replace` pada PRIMARY KEY LOKAL
    //    jika kita bisa MAPPING server ID ke local ID (misal saat upload sukses). Ini kompleks.

    // Pendekatan dengan kolom server_id (Asumsi sudah ditambahkan di skema)
    productMap['server_id'] = product.serverId; // Asumsi model punya serverId
    productMap.remove('id'); // Hapus ID lokal

    // Set status dan timestamp
    productMap['sync_status'] = 'synced';
    productMap['updated_at'] = product.updatedAt?.toIso8601String() ??
        DateTime.now().toIso8601String();
    productMap['created_at'] ??=
        product.createdAt?.toIso8601String() ?? productMap['updated_at'];
    productMap['is_deleted'] = product.isDeleted ? 1 : 0;
    productMap['deleted_at'] = product.deletedAt?.toIso8601String();
    // Hapus field model yg tidak sesuai kolom DB
    productMap.remove('syncStatus');
    productMap.remove('isDeleted');
    productMap.remove('deletedAt');

    try {
      // Coba update berdasarkan server_id dulu
      int rowsAffected = await txn.update('products', productMap,
          where: 'server_id = ? AND id_pengguna = ?',
          whereArgs: [product.serverId, product.idPengguna]);

      // Jika tidak ada yg terupdate (item baru dari server), lakukan insert
      if (rowsAffected == 0) {
        productMap.remove(
            'server_id'); // Hapus server_id dari map SEBELUM insert ke kolom biasa
        // Masukkan server_id ke kolomnya
        productMap['server_id'] = product.serverId;
        // Jika menggunakan ID lokal autoincrement, biarkan DB yg generate ID lokal
        // return await txn.insert('products', productMap, conflictAlgorithm: ConflictAlgorithm.ignore); // Ignore jika ada konflik lain?

        // Jika skema lokal tidak pakai autoincrement dan pakai ID server:
        productMap['id'] = product.serverId; // Gunakan ID server sbg ID lokal
        return await txn.insert('products', productMap,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      print(
          "Applied server product change (ID server: ${product.serverId}). Rows affected: $rowsAffected");
      return rowsAffected;
    } catch (e) {
      print(
          "Error in insertOrReplaceProductFromApi (Server ID: ${product.serverId}): $e");
      throw e; // Rethrow agar transaksi bisa di-rollback
    }
  }

  // Implementasi insertOrReplaceCustomerFromApi & insertOrReplaceTransactionFromApi dengan logika serupa (gunakan server_id jika ada)
  Future<int> insertOrReplaceCustomerFromApi(
      DatabaseExecutor txn, Customer customer) async {
    final map = customer.toMap();
    map['server_id'] = customer.serverId;
    map.remove('id');
    map['sync_status'] = 'synced';
    map['updated_at'] = customer.updatedAt?.toIso8601String() ??
        DateTime.now().toIso8601String();
    map['created_at'] ??=
        customer.createdAt.toIso8601String(); // Gunakan created at server
    map['is_deleted'] = customer.isDeleted ? 1 : 0;
    map['deleted_at'] = customer.deletedAt?.toIso8601String();
    map.remove('syncStatus');
    map.remove('isDeleted');
    map.remove('deletedAt');

    try {
      int rowsAffected = await txn.update('customers', map,
          where: 'server_id = ? AND id_pengguna = ?',
          whereArgs: [customer.serverId, customer.idPengguna]);
      if (rowsAffected == 0) {
        map.remove('server_id');
        map['server_id'] = customer.serverId; // Tambahkan lagi
        // Jika ID lokal auto inc
        // return await txn.insert('customers', map, conflictAlgorithm: ConflictAlgorithm.ignore);
        // Jika ID lokal = ID server
        map['id'] = customer.serverId;
        return await txn.insert('customers', map,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      print(
          "Applied server customer change (ID server: ${customer.serverId}). Rows affected: $rowsAffected");
      return rowsAffected;
    } catch (e) {
      print(
          "Error in insertOrReplaceCustomerFromApi (Server ID: ${customer.serverId}): $e");
      throw e;
    }
  }

  Future<int> insertOrReplaceTransactionFromApi(
      DatabaseExecutor txn, TransactionModel transaction) async {
    final map = transaction.toMap();
    map['server_id'] = transaction.serverId;
    map.remove('id');
    map['sync_status'] = 'synced';
    map['updated_at'] = transaction.updatedAt?.toIso8601String() ??
        DateTime.now().toIso8601String();
    map['created_at'] ??=
        transaction.createdAt?.toIso8601String() ?? map['updated_at'];
    map['is_deleted'] = transaction.isDeleted ? 1 : 0;
    map['deleted_at'] = transaction.deletedAt?.toIso8601String();
    map['detail_items'] =
        jsonEncode(transaction.detailItems); // Pastikan string
    map.remove('syncStatus');
    map.remove('isDeleted');
    map.remove('deletedAt');

    try {
      int rowsAffected = await txn.update('transactions', map,
          where: 'server_id = ? AND id_pengguna = ?',
          whereArgs: [transaction.serverId, transaction.idPengguna]);
      if (rowsAffected == 0) {
        map.remove('server_id');
        map['server_id'] = transaction.serverId;
        // Jika ID lokal auto inc
        // return await txn.insert('transactions', map, conflictAlgorithm: ConflictAlgorithm.ignore);
        // Jika ID lokal = ID server
        map['id'] = transaction.serverId;
        return await txn.insert('transactions', map,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      print(
          "Applied server transaction change (ID server: ${transaction.serverId}). Rows affected: $rowsAffected");
      return rowsAffected;
    } catch (e) {
      print(
          "Error in insertOrReplaceTransactionFromApi (Server ID: ${transaction.serverId}): $e");
      throw e;
    }
  }

  // Fungsi Delete Permanen dari Lokal (Jalankan dalam Transaction!)
  Future<int> deleteProductLocalFromServer(
      DatabaseExecutor txn, int serverId) async {
    // Hapus berdasarkan server_id jika ada, atau fallback ke ID jika serverId tidak dipakai
    print("Deleting local product permanently matching server ID: $serverId");
    try {
      // Hapus gambar terkait DULU sebelum hapus record DB
      final productMaps = await txn.query('products',
          columns: ['id', 'gambar_produk'],
          where: 'server_id = ?',
          whereArgs: [serverId]);
      for (var pMap in productMaps) {
        if (pMap['gambar_produk'] != null &&
            (pMap['gambar_produk'] as String).isNotEmpty) {
          final imgFile = File(pMap['gambar_produk'] as String);
          try {
            if (await imgFile.exists()) {
              await imgFile.delete();
              print("Deleted local image file: ${pMap['gambar_produk']}");
            }
          } catch (e) {
            print("Error deleting img file $e");
          }
        }
      }
      // Hapus record DB
      return await txn
          .delete('products', where: 'server_id = ?', whereArgs: [serverId]);
    } catch (e) {
      print(
          "Error deleting local product permanently (Server ID: $serverId): $e");
      throw Exception("Gagal menghapus produk permanen.");
    }
  }
  // Implementasi deleteCustomerLocalFromServer & deleteTransactionLocalFromServer serupa

  Future<int> deleteCustomerLocalFromServer(
      DatabaseExecutor txn, int serverId) async {
    print("Deleting local customer permanently matching server ID: $serverId");
    try {
      return await txn
          .delete('customers', where: 'server_id = ?', whereArgs: [serverId]);
    } catch (e) {
      print(
          "Error deleting local customer permanently (Server ID: $serverId): $e");
      throw Exception("Gagal menghapus pelanggan permanen.");
    }
  }

  Future<int> deleteTransactionLocalFromServer(
      DatabaseExecutor txn, int serverId) async {
    print(
        "Deleting local transaction permanently matching server ID: $serverId");
    try {
      return await txn.delete('transactions',
          where: 'server_id = ?', whereArgs: [serverId]);
    } catch (e) {
      print(
          "Error deleting local transaction permanently (Server ID: $serverId): $e");
      throw Exception("Gagal menghapus transaksi permanen.");
    }
  }

  // Tandai item lokal sebagai sudah sinkron / Hapus item yg di-delete
  Future<void> markSyncedItems(Map<String, dynamic> uploadedChanges) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    int updateCount = 0;
    int deleteCount = 0;

    // Helper untuk batch update/delete
    void batchUpdateStatus(String table, List items) {
      for (var itemMap in items) {
        if (itemMap['local_id'] != null) {
          batch.update(table, {'sync_status': 'synced', 'updated_at': now},
              where: 'id = ?', whereArgs: [itemMap['local_id']]);
          updateCount++;
        }
      }
    }

    void batchDelete(String table, List<int> ids) {
      if (ids.isNotEmpty) {
        // Hapus gambar dulu untuk produk sebelum delete record
        if (table == 'products') {
          // Kita perlu query path gambar SEBELUM dimasukkan ke batch delete
          // Ini membuat batch kurang efisien, mungkin perlu loop biasa
          // Atau modifikasi `deleteProductLocalFromServer` agar bisa dipanggil di sini
          print(
              "Physical deletion of products marked 'deleted' needs image handling outside batch or revised logic.");
          // Untuk sementara, hanya delete record:
          batch.delete(table,
              where: 'id IN (${List.filled(ids.length, '?').join(',')})',
              whereArgs: ids);
          deleteCount += ids.length;
        } else {
          batch.delete(table,
              where: 'id IN (${List.filled(ids.length, '?').join(',')})',
              whereArgs: ids);
          deleteCount += ids.length;
        }
      }
    }

    // Terapkan batch
    batchUpdateStatus('products', uploadedChanges['newProducts'] ?? []);
    batchUpdateStatus('products', uploadedChanges['updatedProducts'] ?? []);
    batchDelete('products', uploadedChanges['deletedProductIds'] ?? []);

    batchUpdateStatus('customers', uploadedChanges['newCustomers'] ?? []);
    batchUpdateStatus('customers', uploadedChanges['updatedCustomers'] ?? []);
    batchDelete('customers', uploadedChanges['deletedCustomerIds'] ?? []);

    batchUpdateStatus('transactions', uploadedChanges['newTransactions'] ?? []);
    // batchUpdateStatus('transactions', uploadedChanges['updatedTransactions'] ?? []); // Jika ada
    batchDelete('transactions', uploadedChanges['deletedTransactionIds'] ?? []);

    try {
      await batch.commit(noResult: true);
      print(
          "Local sync statuses updated ($updateCount items) / items deleted ($deleteCount items).");
    } catch (e) {
      print("Error marking synced items: $e");
      // Pertimbangkan mekanisme retry atau logging error persisten
    }
  }

  // --- Lainnya ---
  List<Map<String, dynamic>> _parseDetailItems(
      dynamic detailItemsJson, int? transactionId) {
    List<Map<String, dynamic>> items = [];
    if (detailItemsJson != null &&
        detailItemsJson is String &&
        detailItemsJson.isNotEmpty) {
      // Check not empty
      try {
        var decoded = jsonDecode(detailItemsJson);
        if (decoded is List) {
          items = List<Map<String, dynamic>>.from(decoded.map((item) {
            if (item is Map) {
              try {
                return Map<String, dynamic>.from(item);
              } catch (e) {
                /* log */ return <String, dynamic>{};
              }
            } else {
              /* log */ return <String, dynamic>{};
            }
          }));
        } else {/* log */}
      } catch (e) {/* log */}
    } else if (detailItemsJson != null && detailItemsJson is List) {
      // Handle jika sudah List<Map>
      items = List<Map<String, dynamic>>.from(detailItemsJson.map((item) {
        if (item is Map) {
          try {
            return Map<String, dynamic>.from(item);
          } catch (e) {
            /* log */ return <String, dynamic>{};
          }
        } else {
          /* log */ return <String, dynamic>{};
        }
      }));
    } else if (detailItemsJson != null) {/* log type mismatch */}
    return items;
  }

  Future<void> close() async {
    final db = await instance.database;
    if (db.isOpen) {
      await db.close();
      _database = null;
      print("Database closed.");
    }
  }

} // --- Akhir DatabaseHelper ---
