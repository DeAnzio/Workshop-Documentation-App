import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:anzioworkshopapp/screens/utils/biometric_help.dart';
import 'package:anzioworkshopapp/services/supabase_service.dart';

class MoreSecurePage extends StatefulWidget {
  const MoreSecurePage({super.key});

  @override
  State<MoreSecurePage> createState() => _MoreSecurePageState();
}

class _MoreSecurePageState extends State<MoreSecurePage> {
  bool _loading = true;
  String? _errorMessage;
  String? _technicianId;

  // Biometric status
  bool _fingerprintEnabled = false;
  bool _faceIdEnabled = false;
  bool _genericBiometricEnabled = false;
  bool _pinSet = false;

  // Available biometrics
  List<BiometricType> _availableBiometrics = [];

  // PIN controllers
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  bool _pinVisible = false;
  bool _confirmPinVisible = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final techId = await SupabaseService.getCurrentTechnicianId();
      if (techId == null) {
        setState(() {
          _loading = false;
          _errorMessage = 'Pengguna tidak terautentikasi';
        });
        return;
      }

      _technicianId = techId;

      // Get available biometrics
      final biometrics = await BiometricHelper.getAvailableBiometrics();
      _availableBiometrics = biometrics;

      // Get current status
      final fingerprintEnabled = await BiometricHelper.isFingerPrintEnabled(
        techId,
      );
      final faceIdEnabled = await BiometricHelper.isFaceIdEnabled(techId);
      final genericBiometricEnabled = await BiometricHelper.isBiometricEnabled(
        techId,
      );
      final pinSet = await BiometricHelper.isPINSet(techId);

      setState(() {
        _fingerprintEnabled = fingerprintEnabled;
        _faceIdEnabled = faceIdEnabled;
        _genericBiometricEnabled = genericBiometricEnabled;
        _pinSet = pinSet;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  Future<void> _toggleFingerprint(bool value) async {
    if (_technicianId == null) return;

    try {
      if (value) {
        // Test fingerprint authentication
        final authenticated = await BiometricHelper.authenticate(
          reason: 'Enable fingerprint authentication',
        );

        if (authenticated) {
          await BiometricHelper.enableFingerprint(_technicianId!);
          setState(() {
            _fingerprintEnabled = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fingerprint enabled successfully')),
          );
        }
      } else {
        await BiometricHelper.disableFingerprint(_technicianId!);
        setState(() {
          _fingerprintEnabled = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Fingerprint disabled')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _toggleFaceId(bool value) async {
    if (_technicianId == null) return;

    try {
      if (value) {
        // Test face ID authentication
        final authenticated = await BiometricHelper.authenticate(
          reason: 'Enable Face ID authentication',
        );

        if (authenticated) {
          await BiometricHelper.enableFaceId(_technicianId!);
          setState(() {
            _faceIdEnabled = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Face ID enabled successfully')),
          );
        }
      } else {
        await BiometricHelper.disableFaceId(_technicianId!);
        setState(() {
          _faceIdEnabled = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Face ID disabled')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _toggleGenericBiometric(bool value) async {
    if (_technicianId == null) return;

    try {
      if (value) {
        final authenticated = await BiometricHelper.authenticate(
          reason: 'Enable biometric authentication',
        );

        if (authenticated) {
          await BiometricHelper.enableBiometric(_technicianId!);
          setState(() {
            _genericBiometricEnabled = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometric enabled successfully')),
          );
        }
      } else {
        await BiometricHelper.disableBiometric(_technicianId!);
        setState(() {
          _genericBiometricEnabled = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Biometric disabled')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _setupPIN() async {
    if (_pinController.text.isEmpty || _confirmPinController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter PIN in both fields')),
      );
      return;
    }

    if (_pinController.text != _confirmPinController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('PINs do not match')));
      return;
    }

    if (_pinController.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN must be at least 4 digits')),
      );
      return;
    }

    try {
      await BiometricHelper.savePIN(_technicianId!, _pinController.text);
      setState(() {
        _pinSet = true;
      });
      _pinController.clear();
      _confirmPinController.clear();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('PIN set successfully')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error setting PIN: $e')));
    }
  }

  Future<void> _removePIN() async {
    try {
      await BiometricHelper.clearPIN(_technicianId!);
      setState(() {
        _pinSet = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('PIN removed')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error removing PIN: $e')));
    }
  }

  void _showPINDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Set PIN'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: _pinController,
                  obscureText: !_pinVisible,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: 'PIN',
                    counterText: '',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _pinVisible ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _pinVisible = !_pinVisible;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPinController,
                  obscureText: !_confirmPinVisible,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: 'Confirm PIN',
                    counterText: '',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _confirmPinVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _confirmPinVisible = !_confirmPinVisible;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _setupPIN();
                Navigator.pop(context);
              },
              child: const Text('Set PIN'),
            ),
          ],
        ),
      ),
    );
  }

  String _biometricTypeLabel(BiometricType type) {
    switch (type) {
      case BiometricType.fingerprint:
        return 'Fingerprint';
      case BiometricType.face:
        return 'Face ID';
      case BiometricType.iris:
        return 'Iris';
      case BiometricType.strong:
        return 'Strong biometric';
      case BiometricType.weak:
        return 'Weak biometric';
      default:
        return type.toString().split('.').last;
    }
  }

  bool get _hasExplicitBiometricOption {
    return _availableBiometrics.contains(BiometricType.fingerprint) ||
        _availableBiometrics.contains(BiometricType.face);
  }

  bool get _hasAnyBiometric => _availableBiometrics.isNotEmpty;

  bool get _showGenericBiometricOption {
    return _hasAnyBiometric && !_hasExplicitBiometricOption;
  }

  String get _availableBiometricLabel {
    return _availableBiometrics.map(_biometricTypeLabel).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Additional Security'),
        backgroundColor: const Color.fromARGB(255, 26, 41, 67),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Biometric Authentication',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Fingerprint
                  if (_availableBiometrics.contains(BiometricType.fingerprint))
                    Card(
                      child: SwitchListTile(
                        title: const Text('Fingerprint'),
                        subtitle: const Text('Use fingerprint to authenticate'),
                        value: _fingerprintEnabled,
                        onChanged: _toggleFingerprint,
                      ),
                    ),

                  // Face ID
                  if (_availableBiometrics.contains(BiometricType.face))
                    Card(
                      child: SwitchListTile(
                        title: const Text('Face ID'),
                        subtitle: const Text(
                          'Use face recognition to authenticate',
                        ),
                        value: _faceIdEnabled,
                        onChanged: _toggleFaceId,
                      ),
                    ),

                  if (_showGenericBiometricOption)
                    Card(
                      child: SwitchListTile(
                        title: const Text('Biometric Authentication'),
                        subtitle: Text(
                          'Use available biometric: $_availableBiometricLabel',
                        ),
                        value: _genericBiometricEnabled,
                        onChanged: _toggleGenericBiometric,
                      ),
                    ),

                  if (!_hasAnyBiometric)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Biometrik tidak tersedia atau belum terdaftar di perangkat ini. '
                          'Silakan aktifkan biometrik pada pengaturan perangkat.',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),
                  const Text(
                    'PIN Protection',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // PIN Status
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'PIN Status',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _pinSet ? 'PIN is set' : 'No PIN set',
                                    style: TextStyle(
                                      color: _pinSet
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                              if (_pinSet)
                                ElevatedButton(
                                  onPressed: _removePIN,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  child: const Text('Remove PIN'),
                                )
                              else
                                ElevatedButton(
                                  onPressed: _showPINDialog,
                                  child: const Text('Set PIN'),
                                ),
                            ],
                          ),
                          if (!_pinSet) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'Set a 4-6 digit PIN to add additional protection',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }
}
