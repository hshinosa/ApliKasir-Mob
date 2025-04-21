// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
// Impor model jika diperlukan untuk return type
import '../model/user_model.dart';
import '../model/product_model.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';

class ApiService {
  // Helper untuk mendapatkan token
  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs
        .getString('accessToken'); // Kunci 'accessToken' harus konsisten
  }

  // Helper untuk membuat header standar
  Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
    };
    if (includeAuth) {
      final token = await _getAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  // --- Auth Endpoints ---
  Future<Map<String, dynamic>> login(String identifier, String password) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/login'),
      headers: await _getHeaders(includeAuth: false),
      body: jsonEncode(<String, String>{
        'identifier': identifier,
        'password': password,
      }),
    );
    final responseBody = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return responseBody; // Berisi { message, accessToken, user }
    } else {
      throw Exception(responseBody['message'] ?? 'Login failed');
    }
  }

  Future<Map<String, dynamic>> register(
      Map<String, String> textData, File? imageFile) async {
    var request = http.MultipartRequest(
        'POST', Uri.parse('${ApiConfig.baseUrl}/auth/register'));

    // Tambahkan field teks
    request.fields.addAll(textData);

    // Tambahkan file gambar jika ada
    if (imageFile != null && await imageFile.exists()) {
      // Dapatkan tipe MIME
      String? mimeType = lookupMimeType(imageFile.path);
      MediaType? contentType;
      if (mimeType != null) {
        contentType = MediaType.parse(mimeType); // Buat objek MediaType
        print("Detected MIME type: $mimeType");
      } else {
        print(
            "Warning: Could not detect MIME type for ${imageFile.path}. Sending without explicit content type.");
        // Anda bisa set default jika perlu, misal image/jpeg
        // contentType = MediaType('image', 'jpeg');
      }

      request.files.add(await http.MultipartFile.fromPath(
        'profileImage',
        imageFile.path,
        contentType: contentType, // <-- Tambahkan contentType
      ));
      print("Adding image with content type: ${contentType?.toString()}");
    } else {
      print("No profile image provided.");
    }

    // Kirim request
    try {
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      final responseBody = jsonDecode(response.body);
      print("Registration response status: ${streamedResponse.statusCode}");
      print("Registration response body: ${response.body}");
      if (streamedResponse.statusCode == 201) {
        return responseBody;
      } else {
        throw Exception(responseBody['message'] ?? 'Registration failed');
      }
    } catch (e) {
      print("Error sending registration request: $e");
      throw Exception("Error during registration network call: $e");
    }
  }

  // --- Product Endpoints ---
  Future<List<Product>> getProducts() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/products'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      // Penting: Sesuaikan konversi dari Map API ke Product Model
      return body.map((dynamic item) => Product.fromMap(item)).toList();
    } else {
      throw Exception(
          jsonDecode(response.body)['message'] ?? 'Failed to load products');
    }
  }

  Future<Map<String, dynamic>> createProduct(Product product) async {
    // Konversi Product model ke Map yang sesuai dengan body API
    // Harga mungkin perlu dikirim sebagai double/number, bukan string format
    final Map<String, dynamic> productData = {
      "nama_produk": product.namaProduk,
      "kode_produk": product.kodeProduk,
      "jumlah_produk": product.jumlahProduk,
      "harga_modal": product.hargaModal, // Pastikan double
      "harga_jual": product.hargaJual, // Pastikan double
      "gambar_produk": product
          .gambarProduk // Path gambar mungkin perlu dihandle berbeda (upload?)
    };

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/products'),
      headers: await _getHeaders(),
      body: jsonEncode(productData),
    );
    final responseBody = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return responseBody; // { message, productId }
    } else {
      throw Exception(responseBody['message'] ?? 'Failed to create product');
    }
  }

  Future<Map<String, dynamic>> updateProduct(
      int productId, Product product) async {
    final Map<String, dynamic> productData = {
      "nama_produk": product.namaProduk,
      "kode_produk": product.kodeProduk,
      "jumlah_produk": product.jumlahProduk,
      "harga_modal": product.hargaModal,
      "harga_jual": product.hargaJual,
      "gambar_produk": product.gambarProduk
    };
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/products/$productId'),
      headers: await _getHeaders(),
      body: jsonEncode(productData),
    );
    final responseBody = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return responseBody; // { message }
    } else {
      throw Exception(responseBody['message'] ?? 'Failed to update product');
    }
  }

  Future<Map<String, dynamic>> deleteProduct(int productId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/products/$productId'),
      headers: await _getHeaders(),
    );
    final responseBody = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return responseBody; // { message }
    } else {
      throw Exception(responseBody['message'] ?? 'Failed to delete product');
    }
  }

  // --- Tambahkan endpoint untuk Customer, Transaction, User Profile, Sync ---
  // Contoh Sync:
  Future<Map<String, dynamic>> synchronize(
      String? lastSyncTimeIso, Map<String, dynamic> localChanges) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/sync'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'clientLastSyncTime':
            lastSyncTimeIso, // Kirim sebagai ISO String atau null
        'localChanges': localChanges,
      }),
    );
    final responseBody = jsonDecode(response.body);
    if (response.statusCode == 200) {
      // Response: { message, newServerTimestamp, serverChanges }
      return responseBody;
    } else {
      print("Sync Error Response Body: ${response.body}");
      throw Exception(responseBody['message'] ?? 'Synchronization failed');
    }
  }

  Future<User> getUserProfile() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/user/profile'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return User.fromMap(jsonDecode(response.body));
    } else {
      throw Exception(jsonDecode(response.body)['message'] ??
          'Failed to load user profile');
    }
  }

  Future<Map<String, dynamic>> updateUserProfile(
      Map<String, dynamic> updateData, File? newImageFile) async {
    var request = http.MultipartRequest(
        'PUT', Uri.parse('${ApiConfig.baseUrl}/user/profile'));

    // Tambahkan header otentikasi
    final token = await _getAccessToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.headers['Accept'] = 'application/json';
    // Tidak perlu Content-Type untuk multipart

    // Tambahkan field teks (konversi nilai non-string jika perlu)
    updateData.forEach((key, value) {
      if (value != null) {
        // Hanya kirim field yg tidak null
        request.fields[key] = value.toString();
      }
    });

    // Tambahkan file gambar jika ada
    if (newImageFile != null && await newImageFile.exists()) {
      request.files.add(await http.MultipartFile.fromPath(
          'profileImage', // Nama field harus konsisten
          newImageFile.path));
      print("Adding new image to profile update request: ${newImageFile.path}");
    }

    try {
      print("Sending profile update request...");
      var streamedResponse = await request.send();
      print("Profile update response status: ${streamedResponse.statusCode}");

      var response = await http.Response.fromStream(streamedResponse);
      final responseBody = jsonDecode(response.body);
      print("Profile update response body: ${response.body}");

      if (streamedResponse.statusCode == 200) {
        return responseBody; // { message, user }
      } else {
        throw Exception(responseBody['message'] ??
            'Profile update failed with status ${streamedResponse.statusCode}');
      }
    } catch (e) {
      print("Error sending profile update request: $e");
      throw Exception(
          "Error during profile update network call: ${e.toString()}");
    }
  }

  // ... (Implementasi endpoint lain: createCustomer, getCustomers, updateCustomer, deleteCustomer,
  //      createTransaction, getTransactions, getTransactionById, updateTransactionStatus)
}
