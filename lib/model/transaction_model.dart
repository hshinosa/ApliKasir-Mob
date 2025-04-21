// lib/model/transaction_model.dart
import 'dart:convert';

class TransactionModel {
  final int? id; // ID Lokal
  final int? serverId; // ID Server
  final int idPengguna;
  final DateTime tanggalTransaksi; // Wajib ada
  final double totalBelanja;
  final double totalModal;
  final String metodePembayaran;
  final String statusPembayaran;
  final int? idPelanggan; // Merujuk ke ID LOKAL customer
  final List<Map<String, dynamic>> detailItems;
  final double? jumlahBayar;
  final double? jumlahKembali;
  final int? idTransaksiHutang; // Merujuk ke ID LOKAL transaction
  final DateTime? createdAt; // Nullable
  final DateTime? updatedAt; // Nullable
  // Sync Fields
  final String? syncStatus;
  final bool isDeleted;
  final DateTime? deletedAt;

  TransactionModel({
    this.id,
    this.serverId,
    required this.idPengguna,
    required this.tanggalTransaksi,
    required this.totalBelanja,
    required this.totalModal,
    required this.metodePembayaran,
    required this.statusPembayaran,
    this.idPelanggan,
    required this.detailItems,
    this.jumlahBayar,
    this.jumlahKembali,
    this.idTransaksiHutang,
    this.createdAt,
    this.updatedAt,
    this.syncStatus = 'synced',
    this.isDeleted = false,
    this.deletedAt,
  });

  // Konversi dari Map (DB Lokal) ke Object TransactionModel
  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    List<Map<String, dynamic>> items = [];
    // Parsing detailItems (SAMA seperti di db_helper)
    if (map['detail_items'] is String &&
        (map['detail_items'] as String).isNotEmpty) {
      try {
        var decoded = jsonDecode(map['detail_items']);
        if (decoded is List) {
          items = List<Map<String, dynamic>>.from(
              decoded.map((item) => Map<String, dynamic>.from(item)));
        }
      } catch (e) {/* Log error parsing */}
    } else if (map['detail_items'] is List) {
      // Handle jika sudah jadi List
      items = List<Map<String, dynamic>>.from(
          map['detail_items'].map((item) => Map<String, dynamic>.from(item)));
    }

    return TransactionModel(
      id: map['id'] as int?,
      serverId: map['server_id'] as int?,
      idPengguna: map['id_pengguna'] as int,
      tanggalTransaksi: map['tanggal_transaksi'] == null
          ? DateTime.now() // Default jika null (seharusnya tidak terjadi)
          : DateTime.parse(map['tanggal_transaksi'] as String),
      totalBelanja: (map['total_belanja'] as num?)?.toDouble() ?? 0.0,
      totalModal: (map['total_modal'] as num?)?.toDouble() ?? 0.0,
      metodePembayaran: map['metode_pembayaran'] as String? ?? 'Unknown',
      statusPembayaran: map['status_pembayaran'] as String? ?? 'Unknown',
      idPelanggan: map['id_pelanggan'] as int?,
      detailItems: items,
      jumlahBayar: (map['jumlah_bayar'] as num?)?.toDouble(),
      jumlahKembali: (map['jumlah_kembali'] as num?)?.toDouble(),
      idTransaksiHutang: map['id_transaksi_hutang'] as int?,
      // Parse timestamps
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'] as String),
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

  // Konversi ke Map (untuk DB Lokal & API)
  Map<String, dynamic> toMap() {
    return {
      // ID lokal tidak disertakan
      'server_id': serverId,
      'id_pengguna': idPengguna,
      'tanggal_transaksi': tanggalTransaksi.toIso8601String(),
      'total_belanja': totalBelanja,
      'total_modal': totalModal,
      'metode_pembayaran': metodePembayaran,
      'status_pembayaran': statusPembayaran,
      'id_pelanggan': idPelanggan,
      // detail_items TIDAK di-encode di sini, biarkan DB helper
      'detail_items': detailItems,
      'jumlah_bayar': jumlahBayar,
      'jumlah_kembali': jumlahKembali,
      'id_transaksi_hutang': idTransaksiHutang,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      // Sync status diatur DB Helper
      'sync_status': syncStatus,
      'is_deleted': isDeleted ? 1 : 0,
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'TransactionModel{id: $id, serverId: $serverId, date: $tanggalTransaksi, method: $metodePembayaran, sync: $syncStatus, deleted: $isDeleted}';
  }

  // copyWith
  TransactionModel copyWith({
    int? id,
    int? serverId,
    int? idPengguna,
    DateTime? tanggalTransaksi,
    double? totalBelanja,
    double? totalModal,
    String? metodePembayaran,
    String? statusPembayaran,
    int? idPelanggan,
    List<Map<String, dynamic>>? detailItems,
    double? jumlahBayar,
    double? jumlahKembali,
    int? idTransaksiHutang,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? syncStatus,
    bool? isDeleted,
    DateTime? deletedAt,
    bool setDeletedAtNull = false,
    bool setIdPelangganNull = false,
    bool setIdTransaksiHutangNull = false,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      idPengguna: idPengguna ?? this.idPengguna,
      tanggalTransaksi: tanggalTransaksi ?? this.tanggalTransaksi,
      totalBelanja: totalBelanja ?? this.totalBelanja,
      totalModal: totalModal ?? this.totalModal,
      metodePembayaran: metodePembayaran ?? this.metodePembayaran,
      statusPembayaran: statusPembayaran ?? this.statusPembayaran,
      idPelanggan: setIdPelangganNull ? null : idPelanggan ?? this.idPelanggan,
      detailItems: detailItems ??
          List<Map<String, dynamic>>.from(this.detailItems.map(
              (item) => Map<String, dynamic>.from(item))), // Deep copy list map
      jumlahBayar: jumlahBayar ?? this.jumlahBayar,
      jumlahKembali: jumlahKembali ?? this.jumlahKembali,
      idTransaksiHutang: setIdTransaksiHutangNull
          ? null
          : idTransaksiHutang ?? this.idTransaksiHutang,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: setDeletedAtNull ? null : deletedAt ?? this.deletedAt,
    );
  }
}
