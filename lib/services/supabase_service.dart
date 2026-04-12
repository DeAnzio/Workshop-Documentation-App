import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';

class SupabaseService {
  // Session storage keys
  static const String _currentUserIdKey = 'current_user_id';
  static const String _currentUserEmailKey = 'current_user_email';
  static const String _currentUserNameKey = 'current_user_name';
  static const String _sessionExpiryKey = 'session_expiry';

  static const Duration _sessionDuration = Duration(hours: 2);

  /// Get current logged-in user ID from local storage
  static Future<String?> get currentUserId async {
    if (!await validateSession()) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentUserIdKey);
  }

  /// Get current logged-in user email from local storage
  static Future<String?> get currentUserEmail async {
    if (!await validateSession()) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentUserEmailKey);
  }

  /// Get current logged-in user name from local storage
  static Future<String?> get currentUserName async {
    if (!await validateSession()) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentUserNameKey);
  }

  /// Get session expiry date from local storage
  static Future<DateTime?> get _sessionExpiry async {
    final prefs = await SharedPreferences.getInstance();
    final expiryMillis = prefs.getInt(_sessionExpiryKey);
    if (expiryMillis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(expiryMillis);
  }

  static Future<void> _saveSessionExpiry(DateTime expiry) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sessionExpiryKey, expiry.millisecondsSinceEpoch);
  }

  /// Check whether the current session is still valid
  static Future<bool> get isSessionValid async {
    final expiry = await _sessionExpiry;
    if (expiry == null) return false;
    return DateTime.now().isBefore(expiry);
  }

  /// Check if user is logged in and session has not expired
  static Future<bool> get isLoggedIn async {
    final valid = await isSessionValid;
    if (!valid) {
      await signOut();
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_currentUserIdKey);
  }

  /// Make sure session is valid, otherwise clear it
  static Future<bool> validateSession() async {
    final valid = await isSessionValid;
    if (!valid) {
      await signOut();
    }
    return valid;
  }

  /// Register new technician with manual password hashing
  /// Returns true when registration succeeded
  static Future<bool> createTechnician(
    String name,
    String email,
    String password,
  ) async {
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      print('Registration failed: all fields required');
      return false;
    }

    final hashed = sha256.convert(utf8.encode(password)).toString();
    try {
      final res = await Supabase.instance.client.from('technicians').insert({
        'name': name,
        'email': email,
        'password': hashed,
      });

      try {
        final map = res as Map<String, dynamic>;
        if (map.containsKey('error') && map['error'] != null) {
          print('Insert error: ${map['error']}');
          return false;
        }
      } catch (_) {}

      return true;
    } catch (e) {
      print('Registration failed: $e');
      return false;
    }
  }

  /// Manual login - hash password and verify against database
  /// Returns true when login succeeded
  static Future<bool> signIn(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      print('Login failed: email and password required');
      return false;
    }

    try {
      final row = await fetchTechnicianByEmail(email);
      if (row == null) {
        print('Login failed: user not found');
        return false;
      }

      final hashedInput = sha256.convert(utf8.encode(password)).toString();
      final storedHash = row['password'] ?? '';

      if (hashedInput != storedHash) {
        print('Login failed: incorrect password');
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      final userId = row['id'].toString();
      final userName = row['name'] ?? 'Unknown';
      final expiry = DateTime.now().add(_sessionDuration);

      await Future.wait([
        prefs.setString(_currentUserIdKey, userId),
        prefs.setString(_currentUserEmailKey, email),
        prefs.setString(_currentUserNameKey, userName),
      ]);
      await _saveSessionExpiry(expiry);

      print('Login successful for user: $email, session expires at $expiry');
      return true;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  /// Logout - clear session from local storage
  static Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_currentUserIdKey),
        prefs.remove(_currentUserEmailKey),
        prefs.remove(_currentUserNameKey),
        prefs.remove(_sessionExpiryKey),
      ]);
      print('Logout successful');
    } catch (e) {
      print('Logout error: $e');
    }
  }

  /// Fetch technician row by email
  static Future<Map<String, dynamic>?> fetchTechnicianByEmail(
    String email,
  ) async {
    try {
      final res = await Supabase.instance.client
          .from('technicians')
          .select()
          .eq('email', email)
          .limit(1)
          .maybeSingle();
      if (res == null) return null;
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      print('Fetch technician error: $e');
      return null;
    }
  }

  /// Fetch customer row by phone
  static Future<Map<String, dynamic>?> fetchCustomerByPhone(
    String phone,
  ) async {
    try {
      final res = await Supabase.instance.client
          .from('customers')
          .select()
          .eq('no_hp', phone)
          .limit(1)
          .maybeSingle();
      if (res == null) return null;
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      print('Fetch customer error: $e');
      return null;
    }
  }

  /// Fetch customer row by id
  static Future<Map<String, dynamic>?> fetchCustomerById(String id) async {
    try {
      final res = await Supabase.instance.client
          .from('customers')
          .select()
          .eq('id', id)
          .limit(1)
          .maybeSingle();
      if (res == null) return null;
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      print('Fetch customer by id error: $e');
      return null;
    }
  }

  /// Create or reuse customer record based on phone number
  static Future<String?> createCustomer(
    String nama,
    String noHp, {
    String? alamat,
  }) async {
    try {
      final existing = await fetchCustomerByPhone(noHp);
      if (existing != null) {
        return existing['id']?.toString();
      }

      final res = await Supabase.instance.client
          .from('customers')
          .insert({'nama': nama, 'no_hp': noHp, 'alamat': alamat})
          .select()
          .maybeSingle();

      if (res == null) return null;
      final map = Map<String, dynamic>.from(res as Map);
      return map['id']?.toString();
    } catch (e) {
      print('Create customer failed: $e');
      return null;
    }
  }

  static String _generateTicketNumber() {
    final now = DateTime.now();
    final datePart =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final randomPart = now.millisecondsSinceEpoch.toString().substring(8);
    return 'SRV-$datePart-$randomPart';
  }

  /// Insert service order for a customer and technician
  static Future<String?> insertServiceOrder({
    required String customerId,
    required String technicianId,
    required String jenisDevice,
    required String merekModel,
    String? serialNumber,
    String? kondisiFisik,
    String? kelengkapan,
    required String passwordPin,
    required String keluhan,
    String? jenisService,
    String prioritas = 'normal',
    double? estimasiBiaya,
    double? nominalDp,
  }) async {
    try {
      final ticket = _generateTicketNumber();

      final res = await Supabase.instance.client
          .from('service_orders')
          .insert({
            'nomor_tiket': ticket,
            'customer_id': customerId,
            'technician_id': technicianId,
            'jenis_perangkat': jenisDevice,
            'merek_model': merekModel,
            'serial_number': serialNumber,
            'kondisi_fisik': kondisiFisik,
            'kelengkapan': kelengkapan,
            'password_pin': passwordPin,
            'keluhan': keluhan,
            'diagnosa': null,
            'jenis_service': jenisService,
            'prioritas': prioritas,
            'estimasi_biaya': estimasiBiaya,
            'biaya_akhir': null,
            'status_bayar': 'belum',
            'nominal_dp': nominalDp,
            'status_service': 'masuk',
          })
          .select()
          .single();

      if (res == null) return null;
      final map = Map<String, dynamic>.from(res as Map);
      return map['id']?.toString();
    } catch (e) {
      print('Insert service order failed: $e');
      return null;
    }
  }

  /// Insert customer and service order records
  static Future<String?> insertCustomerData({
    required String namaPelanggan,
    required String noHp,
    String? alamat,
    required String jenisDevice,
    required String merekModel,
    String? serialNumber,
    String? kondisiFisik,
    String? kelengkapan,
    required String password,
    required String keluhan,
    required String serviceType,
    String prioritas = 'normal',
    double? estimasiBiaya,
    double? nominalDp,
    required String technicianId,
  }) async {
    try {
      final customerId = await createCustomer(
        namaPelanggan,
        noHp,
        alamat: alamat,
      );
      if (customerId == null) {
        print('Insert customer data failed: unable to create customer');
        return null;
      }

      final serviceOrderId = await insertServiceOrder(
        customerId: customerId,
        technicianId: technicianId,
        jenisDevice: jenisDevice,
        merekModel: merekModel,
        serialNumber: serialNumber,
        kondisiFisik: kondisiFisik,
        kelengkapan: kelengkapan,
        passwordPin: password,
        keluhan: keluhan,
        jenisService: serviceType,
        prioritas: prioritas,
        estimasiBiaya: estimasiBiaya,
        nominalDp: nominalDp,
      );

      if (serviceOrderId == null) {
        print('Insert customer data failed: unable to create service order');
      }
      return serviceOrderId;
    } catch (e) {
      print('Insert customer data failed: $e');
      return null;
    }
  }

  /// Get technician ID for current authenticated user
  static Future<String?> getCurrentTechnicianId() async {
    final userId = await currentUserId;
    if (userId == null) {
      print('getCurrentTechnicianId: no user logged in');
      return null;
    }
    return userId;
  }

  /// Upload image to Supabase storage and return the public URL
  static Future<String?> uploadImage(
    Uint8List imageBytes,
    String fileName,
  ) async {
    try {
      final filePath = 'service_photos/$fileName';
      await Supabase.instance.client.storage
          .from('service-photos') // Supabase storage bucket name
          .uploadBinary(filePath, imageBytes);

      final publicUrl = Supabase.instance.client.storage
          .from('service-photos')
          .getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      print('Upload image failed: $e');
      return null;
    }
  }

  /// Upload profile avatar to Supabase storage and return the public URL
  static Future<String?> uploadProfileAvatar(
    Uint8List imageBytes,
    String fileName,
  ) async {
    try {
      final filePath = 'avatars/$fileName';
      await Supabase.instance.client.storage
          .from('avatars') // Avatar bucket
          .uploadBinary(filePath, imageBytes);

      final publicUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      print('Upload profile avatar failed: $e');
      return null;
    }
  }

  /// Insert photo record into service_photos table
  static Future<bool> insertServicePhoto(
    String serviceOrderId,
    String photoUrl,
  ) async {
    print(
      'Inserting service photo: serviceOrderId=$serviceOrderId, photoUrl=$photoUrl',
    );
    try {
      final res = await Supabase.instance.client.from('service_photos').insert({
        'service_order_id': serviceOrderId,
        'photo_url': photoUrl,
      });

      print('Insert result: $res');

      try {
        final map = res as Map<String, dynamic>;
        if (map.containsKey('error') && map['error'] != null) {
          print('Insert service photo error: ${map['error']}');
          return false;
        }
      } catch (_) {}

      return true;
    } catch (e) {
      print('Insert service photo failed: $e');
      return false;
    }
  }

  /// Get photos for a service order
  static Future<List<Map<String, dynamic>>> getServicePhotos(
    String serviceOrderId,
  ) async {
    try {
      final res = await Supabase.instance.client
          .from('service_photos')
          .select()
          .eq('service_order_id', serviceOrderId);

      if (res == null) return [];
      final list = res as List<dynamic>;
      return list
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (e) {
      print('Get service photos failed: $e');
      return [];
    }
  }

  /// Update technician profile
  static Future<bool> updateTechnicianProfile(
    String technicianId, {
    String? name,
    String? phoneNumber,
    String? profilePhotoUrl,
    bool? securityEnabled,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (name != null) updateData['name'] = name;
      if (phoneNumber != null) updateData['no_hp'] = phoneNumber;
      if (profilePhotoUrl != null) updateData['avatar_url'] = profilePhotoUrl;
      //if (securityEnabled != null)
        //updateData['security_enabled'] = securityEnabled;

      final res = await Supabase.instance.client
          .from('technicians')
          .update(updateData)
          .eq('id', technicianId);

      try {
        final map = res as Map<String, dynamic>;
        if (map.containsKey('error') && map['error'] != null) {
          print('Update technician profile error: ${map['error']}');
          return false;
        }
      } catch (_) {}

      return true;
    } catch (e) {
      print('Update technician profile failed: $e');
      return false;
    }
  }
}
