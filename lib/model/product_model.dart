// lib/model/product_model.dart
class Product {
  final int? id; // ID Lokal (Primary Key Autoincrement)
  final int? serverId; // ID dari Server (Nullable, Unique di DB)
  final int idPengguna;
  final String?
      gambarProduk; // Path gambar LOKAL atau URL online? Konsistensi penting
  final String namaProduk;
  final String kodeProduk;
  final int jumlahProduk;
  final double hargaModal;
  final double hargaJual;
  final DateTime? createdAt; // Diubah ke DateTime?
  final DateTime? updatedAt; // Diubah ke DateTime?
  // Sync Fields
  final String? syncStatus; // 'new', 'updated', 'deleted', 'synced'
  final bool isDeleted;
  final DateTime? deletedAt; // Diubah ke DateTime?

  Product({
    this.id,
    this.serverId, // Tambah serverId
    required this.idPengguna,
    this.gambarProduk,
    required this.namaProduk,
    required this.kodeProduk,
    required this.jumlahProduk,
    required this.hargaModal,
    required this.hargaJual,
    this.createdAt,
    this.updatedAt,
    // Sync Fields
    this.syncStatus = 'synced', // Default synced
    this.isDeleted = false, // Default false
    this.deletedAt,
  });

  // Konversi dari Map (data DB Lokal) ke Object Product
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      serverId: map['server_id'] as int?, // Baca server_id
      idPengguna: map['id_pengguna'] as int,
      gambarProduk: map['gambar_produk'] as String?,
      namaProduk:
          map['nama_produk'] as String? ?? 'Tanpa Nama', // Default jika null
      kodeProduk: map['kode_produk'] as String? ?? '', // Default jika null
      jumlahProduk: (map['jumlah_produk'] as num?)?.toInt() ?? 0,
      hargaModal: (map['harga_modal'] as num?)?.toDouble() ?? 0.0,
      hargaJual: (map['harga_jual'] as num?)?.toDouble() ?? 0.0,
      // Parse timestamps
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'] as String),
      updatedAt: map['updated_at'] == null
          ? null
          : DateTime.tryParse(map['updated_at'] as String),
      // Sync fields
      syncStatus: map['sync_status'] as String? ?? 'synced',
      isDeleted:
          (map['is_deleted'] as int? ?? 0) == 1, // Konversi dari integer 0/1
      deletedAt: map['deleted_at'] == null
          ? null
          : DateTime.tryParse(map['deleted_at'] as String),
    );
  }

  // Konversi dari Object Product ke Map (untuk DB Lokal & API)
  Map<String, dynamic> toMap() {
    return {
      // ID Lokal tidak dimasukkan di sini, dihandle DB Helper
      'server_id': serverId, // Sertakan server_id
      'id_pengguna': idPengguna,
      'gambar_produk': gambarProduk,
      'nama_produk': namaProduk,
      'kode_produk': kodeProduk,
      'jumlah_produk': jumlahProduk,
      'harga_modal': hargaModal,
      'harga_jual': hargaJual,
      'created_at': createdAt?.toIso8601String(), // Format ke String ISO
      'updated_at': updatedAt?.toIso8601String(), // Format ke String ISO
      // Kolom sync diatur oleh DB Helper saat operasi lokal
      'sync_status':
          syncStatus, // Sertakan untuk debug atau insertOrReplace dari API
      'is_deleted': isDeleted ? 1 : 0, // Konversi ke Integer 0/1
      'deleted_at': deletedAt?.toIso8601String(), // Format ke String ISO
    };
  }

  // Salin objek dengan beberapa perubahan
  Product copyWith({
    int? id,
    int? serverId,
    int? idPengguna,
    String? gambarProduk,
    String? namaProduk,
    String? kodeProduk,
    int? jumlahProduk,
    double? hargaModal,
    double? hargaJual,
    DateTime? createdAt, // Ubah ke DateTime?
    DateTime? updatedAt, // Ubah ke DateTime?
    String? syncStatus,
    bool? isDeleted,
    DateTime? deletedAt,
    bool setDeletedAtNull = false,
    bool setGambarProdukNull = false,
  }) {
    return Product(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      idPengguna: idPengguna ?? this.idPengguna,
      gambarProduk:
          setGambarProdukNull ? null : gambarProduk ?? this.gambarProduk,
      namaProduk: namaProduk ?? this.namaProduk,
      kodeProduk: kodeProduk ?? this.kodeProduk,
      jumlahProduk: jumlahProduk ?? this.jumlahProduk,
      hargaModal: hargaModal ?? this.hargaModal,
      hargaJual: hargaJual ?? this.hargaJual,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: setDeletedAtNull ? null : deletedAt ?? this.deletedAt,
    );
  }

  @override
  String toString() {
    return 'Product{id: $id, serverId: $serverId, nama: $namaProduk, sync: $syncStatus, deleted: $isDeleted}';
  }
}
