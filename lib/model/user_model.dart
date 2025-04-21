// lib/model/user_model.dart
class User {
  final int? id; // ID dari server (Primary Key di DB Lokal juga)
  final String name;
  final String email;
  final String phoneNumber;
  final String storeName;
  final String storeAddress;
  final String passwordHash; // Hash terakhir (disimpan lokal untuk offline?)
  final String?
      profileImagePath; // URL dari Firebase atau path lokal lama? (Konsistensi penting)
  // Timestamps dari Server
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastSyncTime; // Kapan user ini terakhir sync data DARI server

  User({
    required this.id, // ID dari server wajib ada setelah login/register
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.storeName,
    required this.storeAddress,
    required this.passwordHash, // Tetap simpan hash?
    this.profileImagePath,
    this.createdAt,
    this.updatedAt,
    this.lastSyncTime,
  });

  // Convert User object to Map for DB LOCAL insertion/replacement
  Map<String, dynamic> toMap() {
    return {
      'id': id, // Sertakan ID server sebagai primary key lokal
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'storeName': storeName,
      'storeAddress': storeAddress,
      'passwordHash': passwordHash, // Simpan hash jika perlu
      'profileImagePath': profileImagePath,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'last_sync_time': lastSyncTime?.toIso8601String(),
    };
  }

  // Digunakan untuk update LOKAL (ID ada di WHERE clause)
  Map<String, dynamic> toMapWithoutId() {
    return {
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'storeName': storeName,
      'storeAddress': storeAddress,
      'passwordHash': passwordHash,
      'profileImagePath': profileImagePath,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'last_sync_time': lastSyncTime?.toIso8601String(),
    };
  }

  // Convert Map from LOCAL DB to User object
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int?, // Pastikan ID dibaca
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      storeName: map['storeName'] as String? ?? '',
      storeAddress: map['storeAddress'] as String? ?? '',
      passwordHash: map['passwordHash'] as String? ?? '', // Baca hash jika ada
      profileImagePath: map['profileImagePath'] as String?,
      // Parse timestamps
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'] as String),
      updatedAt: map['updated_at'] == null
          ? null
          : DateTime.tryParse(map['updated_at'] as String),
      lastSyncTime: map['last_sync_time'] == null
          ? null
          : DateTime.tryParse(map['last_sync_time'] as String),
    );
  }

  @override
  String toString() {
    return 'User{id: $id, name: $name, email: $email, phoneNumber: $phoneNumber, storeName: $storeName, storeAddress: $storeAddress, profileImagePath: $profileImagePath, createdAt: $createdAt, updatedAt: $updatedAt}';
  }

  // copyWith (opsional, tapi berguna)
  User copyWith({
    int? id,
    String? name,
    String? email,
    String? phoneNumber,
    String? storeName,
    String? storeAddress,
    String? passwordHash,
    String? profileImagePath,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastSyncTime,
    bool setProfileImagePathNull = false,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      storeName: storeName ?? this.storeName,
      storeAddress: storeAddress ?? this.storeAddress,
      passwordHash: passwordHash ?? this.passwordHash,
      profileImagePath: setProfileImagePathNull
          ? null
          : profileImagePath ?? this.profileImagePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }

  toMapWithTimestamps() {}
}
