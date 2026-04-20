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
  static const String _persistentLoginKey = 'persistent_login';
  static const String _sessionExpiredKey = 'session_expired';
  static const String _appLockRequiredKey = 'app_lock_required';
  static const Duration _sessionDuration = Duration(hours: 24);

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

  /// Check if session has expired (but user still has persistent login)
  static Future<bool> get isSessionExpired async {
    final valid = await isSessionValid;
    final persistent = await hasPersistentLogin;
    return !valid && persistent;
  }

  /// Check if user has persistent login (was logged in before)
  static Future<bool> get hasPersistentLogin async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_persistentLoginKey) ?? false;
  }

  /// Check if app lock is required after closing/backgrounding the app
  static Future<bool> get isAppLockRequired async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_appLockRequiredKey) ?? false;
  }

  /// Set whether app lock is required
  static Future<void> setAppLockRequired(bool required) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appLockRequiredKey, required);
  }

  /// Check if user is logged in and session has not expired
  static Future<bool> get isLoggedIn async {
    final valid = await isSessionValid;
    if (!valid) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_currentUserIdKey);
  }

  /// Get technician ID without session validation (for re-authentication)
  static Future<String?> getTechnicianIdWithoutSessionCheck() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentUserIdKey);
  }

  /// Refresh session expiry without clearing user data
  static Future<void> refreshSession() async {
    final expiry = DateTime.now().add(_sessionDuration);
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      _saveSessionExpiry(expiry),
      prefs.setBool(_sessionExpiredKey, false),
      prefs.setBool(_appLockRequiredKey, false),
    ]);
    print('Session refreshed, expires at $expiry');
  }

  /// Mark session as expired for verification
  static Future<void> markSessionExpired() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sessionExpiredKey, true);
  }

  /// Check if session is marked as expired
  static Future<bool> checkSessionExpired() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_sessionExpiredKey) ?? false;
  }

  /// Make sure session is valid, otherwise mark for re-authentication
  static Future<bool> validateSession() async {
    final valid = await isSessionValid;
    if (!valid) {
      // Don't signOut, just prepare for re-authentication
      await markSessionExpired();
      return false;
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
        prefs.setBool(_persistentLoginKey, true),
        prefs.setBool(_sessionExpiredKey, false),
        prefs.setBool(_appLockRequiredKey, false),
      ]);
      await _saveSessionExpiry(expiry);

      print('Login successful for user: $email, session expires at $expiry');
      return true;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  /// Logout - clear session and persistent login from local storage
  static Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_currentUserIdKey),
        prefs.remove(_currentUserEmailKey),
        prefs.remove(_currentUserNameKey),
        prefs.remove(_sessionExpiryKey),
        prefs.remove(_persistentLoginKey),
        prefs.remove(_sessionExpiredKey),
        prefs.remove(_appLockRequiredKey),
      ]);
      print('Logout successful');
    } catch (e) {
      print('Logout error: $e');
    }
  }

  /// Clear session expiry but keep persistent login (for session timeout)
  static Future<void> clearSessionOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_sessionExpiryKey),
        prefs.setBool(_sessionExpiredKey, true),
        prefs.setBool(_appLockRequiredKey, true),
      ]);
      print('Session cleared for re-authentication');
    } catch (e) {
      print('Clear session error: $e');
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

  /// Fetch technician row by id
  static Future<Map<String, dynamic>?> fetchTechnicianById(
    String id,
  ) async {
    try {
      final res = await Supabase.instance.client
          .from('technicians')
          .select()
          .eq('id', id)
          .limit(1)
          .maybeSingle();
      if (res == null) return null;
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      print('Fetch technician by id error: $e');
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

  /// Update service order
  static Future<bool> updateServiceOrder(
    String serviceOrderId, {
    String? statusService,
    String? diagnosa,
    double? biayaAkhir,
    String? statusBayar,
    String? jenisService,
    double? estimasiBiaya,
    String? prioritas,
    String? kondisiFisik,
    String? kelengkapan,
    String? keluhan,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (statusService != null) updateData['status_service'] = statusService;
      if (diagnosa != null) updateData['diagnosa'] = diagnosa;
      if (biayaAkhir != null) updateData['biaya_akhir'] = biayaAkhir;
      if (statusBayar != null) updateData['status_bayar'] = statusBayar;
      if (jenisService != null) updateData['jenis_service'] = jenisService;
      if (estimasiBiaya != null) updateData['estimasi_biaya'] = estimasiBiaya;
      if (prioritas != null) updateData['prioritas'] = prioritas;
      if (kondisiFisik != null) updateData['kondisi_fisik'] = kondisiFisik;
      if (kelengkapan != null) updateData['kelengkapan'] = kelengkapan;
      if (keluhan != null) updateData['keluhan'] = keluhan;

      await Supabase.instance.client
          .from('service_orders')
          .update(updateData)
          .eq('id', serviceOrderId);

      print('Service order updated: $serviceOrderId');
      return true;
    } catch (e) {
      print('Update service order failed: $e');
      return false;
    }
  }

  /// Delete service order
  static Future<bool> deleteServiceOrder(String serviceOrderId) async {
    try {
      await Supabase.instance.client
          .from('service_orders')
          .delete()
          .eq('id', serviceOrderId);

      print('Service order deleted: $serviceOrderId');
      return true;
    } catch (e) {
      print('Delete service order failed: $e');
      return false;
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

  static String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  static DateTime? _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is DateTime) return timestamp.toUtc();
    if (timestamp is String) {
      try {
        return DateTime.parse(timestamp).toUtc();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static Future<bool> _updateTechnicianPinState(
    String technicianId, {
    String? pinHash,
    bool clearPinHash = false,
    int? pinAttempts,
    bool clearPinAttempts = false,
    DateTime? pinLockedUntil,
    bool clearPinLockedUntil = false,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (clearPinHash) {
        updateData['pin_hash'] = null;
      } else if (pinHash != null) {
        updateData['pin_hash'] = pinHash;
      }
      if (clearPinAttempts) {
        updateData['pin_attempts'] = 0;
      } else if (pinAttempts != null) {
        updateData['pin_attempts'] = pinAttempts;
      }
      if (clearPinLockedUntil) {
        updateData['pin_locked_until'] = null;
      } else if (pinLockedUntil != null) {
        updateData['pin_locked_until'] = pinLockedUntil.toUtc().toIso8601String();
      }

      if (updateData.isEmpty) return true;

      print('Updating technician PIN state: $updateData');
      final res = await Supabase.instance.client
          .from('technicians')
          .update(updateData)
          .eq('id', technicianId);

      try {
        final map = res as Map<String, dynamic>;
        if (map.containsKey('error') && map['error'] != null) {
          print('Update technician PIN state error: ${map['error']}');
          return false;
        }
      } catch (_) {}

      print('PIN state updated successfully');
      return true;
    } catch (e) {
      print('Update technician PIN state failed: $e');
      return false;
    }
  }

  static Future<bool> saveTechnicianPin(
    String technicianId,
    String pin,
  ) async {
    try {
      final pinHash = _hashPin(pin);

      final success = await _updateTechnicianPinState(
        technicianId,
        pinHash: pinHash,
        pinAttempts: 0,
        clearPinAttempts: true,
        clearPinLockedUntil: true,
      );

      return success;
    } catch (e) {
      print('Save technician PIN failed: $e');
      return false;
    }
  }

  static Future<String?> getTechnicianPinHash(String technicianId) async {
    try {
      final res = await Supabase.instance.client
          .from('technicians')
          .select('pin_hash')
          .eq('id', technicianId)
          .single();

      final map = Map<String, dynamic>.from(res as Map);
      return map['pin_hash'] as String?;
    } catch (e) {
      print('Get technician PIN hash failed: $e');
      return null;
    }
  }

  static Future<bool> _resetPinAttempts(String technicianId) async {
    return await _updateTechnicianPinState(
      technicianId,
      pinAttempts: 0,
      clearPinLockedUntil: true,
    );
  }

  static Future<bool> _recordFailedPinAttempt(String technicianId) async {
    try {
      print('Recording failed PIN attempt for technician: $technicianId');
      final res = await Supabase.instance.client
          .from('technicians')
          .select('pin_attempts, pin_locked_until')
          .eq('id', technicianId)
          .single();

      final map = Map<String, dynamic>.from(res as Map);
      final currentAttempts = (map['pin_attempts'] as int?) ?? 0;
      final nextAttempts = currentAttempts + 1;
      print('Current attempts: $currentAttempts, next attempts: $nextAttempts');

      if (nextAttempts >= 3) {
        final lockedUntil = DateTime.now().toUtc().add(const Duration(seconds: 30));
        print('Locking PIN until: $lockedUntil');
        final success = await _updateTechnicianPinState(
          technicianId,
          pinAttempts: 0,
          pinLockedUntil: lockedUntil,
        );
        if (success) {
          print('PIN locked successfully');
        } else {
          print('Failed to lock PIN');
        }
        return success;
      }

      final success = await _updateTechnicianPinState(
        technicianId,
        pinAttempts: nextAttempts,
      );
      if (success) {
        print('PIN attempts updated successfully');
      } else {
        print('Failed to update PIN attempts');
      }
      return success;
    } catch (e) {
      print('Record failed PIN attempt failed: $e');
      // If columns don't exist, try to add them or notify user
      if (e.toString().contains('pin_attempts') || e.toString().contains('pin_locked_until')) {
        print('PIN attempt/lock columns may not exist in database. Please add them to the technicians table.');
      }
      return false;
    }
  }

  static Future<DateTime?> getTechnicianPinLockExpiration(String technicianId) async {
    try {
      print('Getting PIN lock expiration for technician: $technicianId');
      final res = await Supabase.instance.client
          .from('technicians')
          .select('pin_locked_until')
          .eq('id', technicianId)
          .single();

      final map = Map<String, dynamic>.from(res as Map);
      final timestamp = _parseTimestamp(map['pin_locked_until']);
      print('PIN locked until from DB: $timestamp');
      return timestamp;
    } catch (e) {
      print('Get technician PIN lock expiration failed: $e');
      return null;
    }
  }

  static Future<bool> isTechnicianPinLocked(String technicianId) async {
    final lockedUntil = await getTechnicianPinLockExpiration(technicianId);
    return lockedUntil != null && DateTime.now().toUtc().isBefore(lockedUntil);
  }

  static Future<int> getTechnicianPinLockRemainingSeconds(
    String technicianId,
  ) async {
    final lockedUntil = await getTechnicianPinLockExpiration(technicianId);
    if (lockedUntil == null) return 0;
    final remaining = lockedUntil.difference(DateTime.now().toUtc()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  static Future<bool> verifyTechnicianPin(
    String technicianId,
    String pin,
  ) async {
    try {
      print('Verifying PIN for technician: $technicianId');
      final lockedUntil = await getTechnicianPinLockExpiration(technicianId);
      print('PIN locked until: $lockedUntil');
      if (lockedUntil != null && DateTime.now().toUtc().isBefore(lockedUntil)) {
        print('PIN is currently locked');
        return false;
      }

      final storedHash = await getTechnicianPinHash(technicianId);
      if (storedHash == null || storedHash.isEmpty) {
        print('No PIN hash stored');
        return false;
      }
      final pinHash = _hashPin(pin);
      final isValid = storedHash == pinHash;
      print('PIN valid: $isValid');
      if (isValid) {
        await _resetPinAttempts(technicianId);
        return true;
      }

      await _recordFailedPinAttempt(technicianId);
      return false;
    } catch (e) {
      print('Verify technician PIN failed: $e');
      return false;
    }
  }

  static Future<bool> lockTechnicianPin(
    String technicianId,
    DateTime lockedUntil,
  ) async {
    try {
      print('Locking technician PIN until: $lockedUntil');
      final success = await _updateTechnicianPinState(
        technicianId,
        pinLockedUntil: lockedUntil,
      );
      if (success) {
        print('PIN locked successfully');
      } else {
        print('Failed to lock PIN');
      }
      return success;
    } catch (e) {
      print('Lock technician PIN failed: $e');
      return false;
    }
  }

  static Future<bool> clearTechnicianPin(String technicianId) async {
    try {
      final success = await _updateTechnicianPinState(
        technicianId,
        clearPinHash: true,
        clearPinAttempts: true,
        clearPinLockedUntil: true,
      );
      return success;
    } catch (e) {
      print('Clear technician PIN failed: $e');
      return false;
    }
  }

  static Future<bool> isTechnicianPinSet(String technicianId) async {
    try {
      final pinHash = await getTechnicianPinHash(technicianId);
      return pinHash != null && pinHash.isNotEmpty;
    } catch (e) {
      print('Is technician PIN set failed: $e');
      return false;
    }
  }
}
