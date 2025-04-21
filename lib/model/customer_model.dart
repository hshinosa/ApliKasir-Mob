// lib/model/customer_model.dart
class Customer {
  final int? id; // ID Lokal
  final int? serverId; // ID Server
  final int idPengguna;
  final String namaPelanggan;
  final String? nomorTelepon;
  final DateTime createdAt; // Wajib ada saat dibuat
  final DateTime? updatedAt; // Nullable
  // Sync Fields
  final String? syncStatus;
  final bool isDeleted;
  final DateTime? deletedAt;

  Customer({
    this.id,
    this.serverId,
    required this.idPengguna,
    required this.namaPelanggan,
    this.nomorTelepon,
    required this.createdAt, // Buat required karena not null di DB v6
    this.updatedAt,
    this.syncStatus = 'synced',
    this.isDeleted = false,
    this.deletedAt,
  });

  // Konversi dari Map (DB Lokal) ke Object Customer
  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as int?,
      serverId: map['server_id'] as int?,
      idPengguna: map['id_pengguna'] as int,
      namaPelanggan: map['nama_pelanggan'] as String? ?? 'Tanpa Nama',
      nomorTelepon: map['nomor_telepon'] as String?,
      // Parse timestamps (handle null)
      createdAt: map['created_at'] == null
          ? DateTime
              .now() // Default jika null (seharusnya tidak terjadi krn NOT NULL di DB)
          : DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] == null
          ? null
          : DateTime.tryParse(map['updated_at'] as String),
      // Sync fields
      syncStatus: map['sync_status'] as String? ?? 'synced',
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      deletedAt: map['deleted_at'] == null
          ? null
          : DateTime.tryParse(map['deleted_at'] as String),
    );
  }

  // Konversi Customer object ke Map object (untuk DB Lokal & API)
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      // ID lokal tidak disertakan
      'server_id': serverId,
      'id_pengguna': idPengguna,
      'nama_pelanggan': namaPelanggan,
      'nomor_telepon': nomorTelepon,
      'created_at': createdAt.toIso8601String(), // Format ke String ISO
      'updated_at': updatedAt?.toIso8601String(), // Format ke String ISO
      // Sync status diatur DB Helper
      'sync_status': syncStatus,
      'is_deleted': isDeleted ? 1 : 0,
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'Customer{id: $id, serverId: $serverId, nama: $namaPelanggan, sync: $syncStatus, deleted: $isDeleted}';
  }

  // copyWith
  Customer copyWith({
    int? id,
    int? serverId,
    int? idPengguna,
    String? namaPelanggan,
    String? nomorTelepon,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? syncStatus,
    bool? isDeleted,
    DateTime? deletedAt,
    bool setDeletedAtNull = false,
    bool setNomorTeleponNull = false, // Contoh flag spesifik
  }) {
    return Customer(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      idPengguna: idPengguna ?? this.idPengguna,
      namaPelanggan: namaPelanggan ?? this.namaPelanggan,
      nomorTelepon:
          setNomorTeleponNull ? null : nomorTelepon ?? this.nomorTelepon,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: setDeletedAtNull ? null : deletedAt ?? this.deletedAt,
    );
  }
}
