import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anzioworkshopapp/services/backend_service.dart';

class BiometricHelper {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Get available biometrics on device
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      print('Error getting available biometrics: $e');
      return [];
    }
  }

  /// Check if biometric authentication is available
  static Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } catch (e) {
      print('Error checking biometrics availability: $e');
      return false;
    }
  }

  /// Check if device supports biometric
  static Future<bool> deviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      print('Error checking device support: $e');
      return false;
    }
  }

  /// Authenticate using biometric
  static Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      print('Biometric authentication error: $e');
      return false;
    }
  }

  /// Enable fingerprint
  static Future<void> enableFingerprint(String technicianId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('fingerprint_enabled_$technicianId', true);
    } catch (e) {
      print('Error enabling fingerprint: $e');
    }
  }

  /// Disable fingerprint
  static Future<void> disableFingerprint(String technicianId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('fingerprint_enabled_$technicianId', false);
    } catch (e) {
      print('Error disabling fingerprint: $e');
    }
  }

  /// Check if fingerprint is enabled
  static Future<bool> isFingerPrintEnabled(String technicianId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('fingerprint_enabled_$technicianId') ?? false;
    } catch (e) {
      print('Error checking fingerprint status: $e');
      return false;
    }
  }

  /// Enable Face ID
  static Future<void> enableFaceId(String technicianId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('faceid_enabled_$technicianId', true);
    } catch (e) {
      print('Error enabling face ID: $e');
    }
  }

  /// Disable Face ID
  static Future<void> disableFaceId(String technicianId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('faceid_enabled_$technicianId', false);
    } catch (e) {
      print('Error disabling face ID: $e');
    }
  }

  /// Check if Face ID is enabled
  static Future<bool> isFaceIdEnabled(String technicianId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('faceid_enabled_$technicianId') ?? false;
    } catch (e) {
      print('Error checking Face ID status: $e');
      return false;
    }
  }

  /// Enable generic biometric authentication
  static Future<void> enableBiometric(String technicianId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled_$technicianId', true);
    } catch (e) {
      print('Error enabling biometric: $e');
    }
  }

  /// Disable generic biometric authentication
  static Future<void> disableBiometric(String technicianId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled_$technicianId', false);
    } catch (e) {
      print('Error disabling biometric: $e');
    }
  }

  /// Check if generic biometric authentication is enabled
  static Future<bool> isBiometricEnabled(String technicianId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('biometric_enabled_$technicianId') ?? false;
    } catch (e) {
      print('Error checking biometric status: $e');
      return false;
    }
  }

  /// Save PIN to database as hashed value
  static Future<void> savePIN(String technicianId, String pin) async {
    try {
      await BackendService.saveTechnicianPin(technicianId, pin);
    } catch (e) {
      print('Error saving PIN: $e');
    }
  }

  /// Get hashed PIN from database
  static Future<String?> getPIN(String technicianId) async {
    try {
      return await BackendService.getTechnicianPinHash(technicianId);
    } catch (e) {
      print('Error getting PIN: $e');
      return null;
    }
  }

  /// Verify PIN against database hash
  static Future<bool> verifyPIN(String technicianId, String pin) async {
    try {
      return await BackendService.verifyTechnicianPin(technicianId, pin);
    } catch (e) {
      print('Error verifying PIN: $e');
      return false;
    }
  }

  /// Check if PIN is currently locked
  static Future<bool> isPINLocked(String technicianId) async {
    try {
      return await BackendService.isTechnicianPinLocked(technicianId);
    } catch (e) {
      print('Error checking PIN lock status: $e');
      return false;
    }
  }

  /// Get remaining PIN lock duration in seconds
  static Future<int> getPINLockRemainingSeconds(String technicianId) async {
    try {
      return await BackendService.getTechnicianPinLockRemainingSeconds(
        technicianId,
      );
    } catch (e) {
      print('Error getting PIN lock remaining seconds: $e');
      return 0;
    }
  }

  /// Clear PIN from database
  static Future<void> clearPIN(String technicianId) async {
    try {
      await BackendService.clearTechnicianPin(technicianId);
    } catch (e) {
      print('Error clearing PIN: $e');
    }
  }

  /// Check if PIN is set in database
  static Future<bool> isPINSet(String technicianId) async {
    try {
      return await BackendService.isTechnicianPinSet(technicianId);
    } catch (e) {
      print('Error checking PIN status: $e');
      return false;
    }
  }
}
