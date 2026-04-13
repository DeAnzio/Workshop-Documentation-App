import 'dart:async';

import 'package:flutter/material.dart';
import 'package:anzioworkshopapp/services/supabase_service.dart';
import 'package:anzioworkshopapp/screens/utils/biometric_help.dart';

class SessionVerificationPage extends StatefulWidget {
  const SessionVerificationPage({super.key});

  @override
  State<SessionVerificationPage> createState() =>
      _SessionVerificationPageState();
}

class _SessionVerificationPageState extends State<SessionVerificationPage> {
  String _enteredPin = '';
  bool _loading = false;
  String? _errorMessage;
  String? _technicianId;
  bool _fingerprintAvailable = false;
  bool _faceIdAvailable = false;
  DateTime? _pinLockedUntil;
  Timer? _lockTimer;
  int _pinAttempts = 0; // Local counter for PIN attempts in current session

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final techId = await SupabaseService.getTechnicianIdWithoutSessionCheck();
      if (techId == null) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      _technicianId = techId;

      // Check available biometrics
      final biometrics = await BiometricHelper.getAvailableBiometrics();
      final fingerprintEnabled = await BiometricHelper.isFingerPrintEnabled(
        techId,
      );
      final faceIdEnabled = await BiometricHelper.isFaceIdEnabled(techId);
      final genericBiometricEnabled = await BiometricHelper.isBiometricEnabled(techId);

      final hasFingerprintBio = biometrics.any((b) => b.toString().contains('fingerprint'));
      final hasFaceBio = biometrics.any((b) => b.toString().contains('face'));
      final hasAnyBio = biometrics.isNotEmpty;

      setState(() {
        _fingerprintAvailable = hasFingerprintBio && fingerprintEnabled;
        _faceIdAvailable = hasFaceBio && faceIdEnabled;
        
        // Jika tidak ada pilihan spesifik tapi ada biometric generic dan diaktifkan
        if (!_fingerprintAvailable && !_faceIdAvailable && hasAnyBio && genericBiometricEnabled) {
          _fingerprintAvailable = true; // Gunakan slot fingerprint untuk generic
        } else if (!_fingerprintAvailable && !_faceIdAvailable && hasAnyBio) {
          // Jika ada biometric tapi belum diaktifkan, tampilkan saja sebagai opsi
          _fingerprintAvailable = true;
        }
      });

      // Auto-try biometric if available
      if (_fingerprintAvailable || _faceIdAvailable) {
        await Future.delayed(const Duration(milliseconds: 500));
        await _authenticateWithBiometric();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
    }
  }

  Future<void> _authenticateWithBiometric() async {
    if (_fingerprintAvailable || _faceIdAvailable) {
      final authenticated = await BiometricHelper.authenticate(
        reason: 'Verify your identity to continue',
      );

      if (authenticated) {
        // Refresh session
        await SupabaseService.refreshSession();
        await SupabaseService.setAppLockRequired(false);
        if (!mounted) return;

        await _showPopup('Authentication Successful', 'Biometric authentication succeeded.');

        // Navigate back to home
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        if (!mounted) return;
        await _showPopup('Authentication Failed', 'Biometric verification failed. Please try again or use PIN.');
      }
    }
  }

  Future<void> _verifyPIN() async {
    if (_enteredPin.isEmpty) {
      await _showPopup('PIN Required', 'Please enter your PIN before verifying.');
      return;
    }

    if (_technicianId == null) return;

    if (_isPinLocked) {
      await _showPopup(
        'Account Locked',
        'Too many failed attempts. Please try again in $_lockSecondsRemaining seconds.',
      );
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final isValid = await BiometricHelper.verifyPIN(
        _technicianId!,
        _enteredPin,
      );

      if (isValid) {
        // Reset attempts on successful verification
        _pinAttempts = 0;
        _pinLockedUntil = null;
        
        // Refresh session
        await SupabaseService.refreshSession();
        await SupabaseService.setAppLockRequired(false);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN verified successfully')),
        );

        // Navigate back to home
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // Increment local attempt counter
        _pinAttempts++;
        print('Local PIN attempts: $_pinAttempts');
        
        setState(() {
          _loading = false;
          _enteredPin = '';
        });

        // Check if 3 attempts reached locally
        if (_pinAttempts >= 3) {
          print('3 failed attempts reached, locking account locally');
          // Lock account locally for 30 seconds
          setState(() {
            _pinLockedUntil = DateTime.now().add(const Duration(seconds: 30));
          });
          _startLockTimer();
          
          await _showPopup(
            'Account Locked',
            'Too many failed attempts. Please try again in $_lockSecondsRemaining seconds.',
          );
        } else {
          final attemptsLeft = 3 - _pinAttempts;
          await _showPopup(
            'Invalid PIN',
            'The PIN you entered is incorrect. You have $attemptsLeft attempts left before account lockout.',
          );
        }
      }
    } catch (e) {
      setState(() {
        _loading = false;
      });
      await _showPopup('Verification Error', 'Error verifying PIN: $e');
    }
  }

  void _addPinDigit(String digit) {
    if (_enteredPin.length >= 6) return;
    setState(() {
      _enteredPin += digit;
      _errorMessage = null;
    });
    // Auto-verify when PIN reaches 6 digits
    if (_enteredPin.length == 6) {
      Future.delayed(const Duration(milliseconds: 300), _verifyPIN);
    }
  }

  void _deletePinDigit() {
    if (_enteredPin.isEmpty) return;
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  bool get _isPinLocked {
    return _pinLockedUntil != null && DateTime.now().isBefore(_pinLockedUntil!);
  }

  int get _lockSecondsRemaining {
    if (_pinLockedUntil == null) return 0;
    final remaining = _pinLockedUntil!.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  void _startLockTimer() {
    _cancelLockTimer();
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      if (!_isPinLocked) {
        _cancelLockTimer();
        setState(() {
          _pinLockedUntil = null;
          _errorMessage = null;
        });
        return;
      }
      setState(() {});
    });
  }

  void _cancelLockTimer() {
    _lockTimer?.cancel();
    _lockTimer = null;
  }

  Future<void> _showPopup(String title, String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildPinPad() {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['bio', '0', '<'],
    ];

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((key) {
              if (key == 'bio') {
                if (!(_fingerprintAvailable || _faceIdAvailable)) {
                  return const SizedBox(width: 72, height: 60);
                }
                return ElevatedButton(
                  onPressed: _authenticateWithBiometric,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: const CircleBorder(),
                    fixedSize: const Size(72, 60),
                  ),
                  child: Icon(
                    _faceIdAvailable ? Icons.face_retouching_natural : Icons.fingerprint,
                    color: const Color(0xFF1E4DB7),
                    size: 28,
                  ),
                );
              }

              return ElevatedButton(
                onPressed: key == '<'
                    ? _deletePinDigit
                    : () => _addPinDigit(key),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: const CircleBorder(),
                  fixedSize: const Size(72, 60),
                ),
                child: key == '<'
                    ? const Icon(
                        Icons.backspace_outlined,
                        color: Color(0xFF1E4DB7),
                      )
                    : Text(
                        key,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E4DB7),
                        ),
                      ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Scaffold(
        backgroundColor: const Color(0xFF1E4DB7),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                const Text(
                  'Your session has expired',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please verify your PIN to continue',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 32),

                // Error message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                    ),
                  ),

                // PIN pad
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E4DB7),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Enter your PIN',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(6, (index) {
                          final filled = index < _enteredPin.length;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: filled ? Colors.white : Colors.white24,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),
                      _buildPinPad(),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (_isPinLocked)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Account Locked',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try again in $_lockSecondsRemaining seconds',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // Logout option
                TextButton(
                  onPressed: () async {
                    await SupabaseService.signOut();
                    if (!mounted) return;
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  child: const Text('Logout instead'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cancelLockTimer();
    super.dispose();
  }
}
