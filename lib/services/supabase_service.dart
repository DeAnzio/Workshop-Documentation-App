import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SupabaseService {
  // Session storage keys
  static const String _currentUserIdKey = 'current_user_id';
  static const String _currentUserEmailKey = 'current_user_email';
  static const String _currentUserNameKey = 'current_user_name';
  static const String _sessionExpiryKey = 'session_expiry';

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
  static Future<bool> createTechnician(String name, String email, String password) async {
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      print('Registration failed: all fields required');
      return false;
    }

    final hashed = sha256.convert(utf8.encode(password)).toString();
    try {
      final res = await Supabase.instance.client
          .from('TechnicianData')
          .insert({'name': name, 'email': email, 'password': hashed});

      // Check for error response
      try {
        final map = res as Map<String, dynamic>;
        if (map.containsKey('error') && map['error'] != null) {
          print('Insert error: ${map['error']}');
          return false;
        }
      } catch (_) {
        // If res is not a map, assume success when no exception thrown
      }

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
      // Fetch technician from database by email
      final row = await fetchTechnicianByEmail(email);
      if (row == null) {
        print('Login failed: user not found');
        return false;
      }

      // Hash input password and compare with stored hash
      final hashedInput = sha256.convert(utf8.encode(password)).toString();
      final storedHash = row['password'] ?? '';

      if (hashedInput != storedHash) {
        print('Login failed: incorrect password');
        return false;
      }

      // Login successful - save session to local storage
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
  static Future<Map<String, dynamic>?> fetchTechnicianByEmail(String email) async {
    try {
      final res = await Supabase.instance.client
          .from('TechnicianData')
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

  /// Get technician ID for current authenticated user
  static Future<int?> getCurrentTechnicianId() async {
    final userId = await currentUserId;
    if (userId == null) {
      print('getCurrentTechnicianId: no user logged in');
      return null;
    }

    try {
      return int.parse(userId);
    } catch (_) {
      print('getCurrentTechnicianId: invalid user id format');
      return null;
    }
  }

  /// Insert customer data record into CustomerData table
  static Future<bool> insertCustomerData({
    required String namaPelanggan,
    required String noHp,
    required String jenisDevice,
    required String merekModel,
    required String serviceType,
    required String catatan,
    required String password,
    required int technicianId,
  }) async {
    try {
      final res = await Supabase.instance.client
          .from('CustomerData')
          .insert({
            'nama_pelanggan': namaPelanggan,
            'no_hp': noHp,
            'jenis_device': jenisDevice,
            'merek_model': merekModel,
            'service_type': serviceType,
            'catatan': catatan,
            'password': password,
            'id_technician': technicianId,
          });

      // Check for error response
      try {
        final map = res as Map<String, dynamic>;
        if (map.containsKey('error') && map['error'] != null) {
          print('Insert customer data error: ${map['error']}');
          return false;
        }
      } catch (_) {
        // If res is not a map, assume success when no exception thrown
      }

      print('Customer data inserted successfully');
      return true;
    } catch (e) {
      print('Insert customer data failed: $e');
      return false;
    }
  }
}
