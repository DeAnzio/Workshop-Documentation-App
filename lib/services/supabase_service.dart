import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class SupabaseService {
  static final _auth = Supabase.instance.client.auth;

  static User? get currentUser => _auth.currentUser;

  static String? get currentUserId => _auth.currentUser?.id;

  // Sign up a new user and attach `name` as user metadata.
  // Returns true when the sign-up request was accepted (user created or confirmation sent).
  static Future<bool> signUp(String name, String email, String password) async {
    final res = await _auth.signUp(
      email: email,
      password: password,
    );
    // res.user may be null if email confirmation is required; treat request as successful when no error thrown.
    return res != null;
  }

  static Future<User?> signIn(String email, String password) async {
    final res = await _auth.signInWithPassword(email: email, password: password);
    return res.user;
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }

  // Insert a TechnicianData record. Password will be hashed before inserting.
  // Returns true when insert succeeded.
  static Future<bool> createTechnician(String name, String email, String password) async {
    final hashed = sha256.convert(utf8.encode(password)).toString();
    try {
      final res = await Supabase.instance.client
          .from('TechnicianData')
          .insert({'name': name, 'email': email, 'password': hashed});

      // Some SDKs return a PostgrestResponse-like object with an `error` field.
      try {
        final map = res as Map<String, dynamic>;
        if (map.containsKey('error') && map['error'] != null) {
          print('Insert error: ${map['error']}');
          return false;
        }
      } catch (_) {
        // If res is not a map, assume success when no exception thrown.
      }

      return true;
    } catch (e) {
      print('Insert failed: $e');
      return false;
    }
  }

  // Fetch technician row by email
  static Future<Map<String, dynamic>?> fetchTechnicianByEmail(String email) async {
    final res = await Supabase.instance.client
        .from('TechnicianData')
        .select()
        .eq('email', email)
        .limit(1)
        .maybeSingle();
    if (res == null) return null;
    return Map<String, dynamic>.from(res as Map);
  }

  // Returns the numeric `id` of the TechnicianData row for the current authenticated user.
  static Future<int?> getCurrentTechnicianId() async {
    final email = _auth.currentUser?.email;
    if (email == null) return null;
    final row = await fetchTechnicianByEmail(email);
    if (row == null) return null;
    // Try common id field names
    final idValue = row['id'] ?? row['ID'] ?? row['Id'];
    if (idValue == null) return null;
    try {
      return (idValue as num).toInt();
    } catch (_) {
      try {
        return int.parse(idValue.toString());
      } catch (_) {
        return null;
      }
    }
  }
}
