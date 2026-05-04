import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:anzioworkshopapp/services/backend_service.dart';
import 'package:anzioworkshopapp/services/currency_service.dart';
import 'package:anzioworkshopapp/services/timezone_service.dart';
import 'package:anzioworkshopapp/screens/security/moresecure_page.dart';
import 'package:anzioworkshopapp/widgets/currency_widgets.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  bool _loading = true;
  String? _errorMessage;
  Map<String, dynamic>? _technicianData;

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  XFile? _selectedImage;
  String _selectedCurrency = 'IDR';
  String _selectedTimeZone = 'WIB';
  Timer? _timeRefreshTimer;

  // Stats
  int _totalCompletedTickets = 0;
  double _totalRevenue = 0.0;
  bool _statsLoading = false;

  List<String> get _timeZones => [
        'WIB',
        'WITA',
        'WIT',
        'London',
        'UTC',
        'New York',
        'Tokyo',
      ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final valid = await BackendService.validateSession();
    if (!mounted) return;
    if (!valid) {
      final sessionExpired = await BackendService.isSessionExpired;
      Navigator.pushReplacementNamed(context, sessionExpired ? '/verify' : '/login');
      return;
    }

    final techId = await BackendService.getCurrentTechnicianId();
    if (!mounted) return;
    if (techId == null) {
      setState(() {
        _loading = false;
        _errorMessage = 'Pengguna tidak terautentikasi.';
      });
      return;
    }

    try {
      final data = await BackendService.fetchTechnicianById(techId);
      if (data == null) {
        throw Exception('Technician not found');
      }

      setState(() {
        _technicianData = data;
        _nameController.text = data['name'] ?? '';
        _phoneController.text = data['no_hp'] ?? '';
        _selectedCurrency = data['currency']?.toString() ?? 'IDR';
        final savedTimeZone = data['preferred_time']?.toString();
        _selectedTimeZone = (savedTimeZone != null && TimeZoneService.isValidTimeZone(savedTimeZone))
            ? savedTimeZone
            : 'WIB';
        //_securityEnabled = data['security_enabled'] ?? false;
        _loading = false;
      });
      await _loadStats(techId);
      _startTimeRefresh();
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = 'Gagal memuat profil: $e';
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final techId = await BackendService.getCurrentTechnicianId();
    if (techId == null) {
      setState(() {
        _loading = false;
        _errorMessage = 'Pengguna tidak terautentikasi.';
      });
      return;
    }

    try {
      String? photoUrl;
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        final fileName =
            'profile_${techId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        photoUrl = await BackendService.uploadProfileAvatar(bytes, fileName);
      }

      final updateData = {
        'name': _nameController.text,
        'no_hp': _phoneController.text,
        //'security_enabled': _securityEnabled,
      };

      if (photoUrl != null) {
        updateData['avatar_url'] = photoUrl;
      }

      final success = await BackendService.updateTechnicianProfile(
        techId,
        name: _nameController.text,
        phoneNumber: _phoneController.text,
        profilePhotoUrl: photoUrl,
        preferredTime: _selectedTimeZone,
        currency: _selectedCurrency,
      );

      if (!success) {
        throw Exception('Failed to update profile');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil berhasil diperbarui')),
      );

      // Reload profile
      await _loadProfile();
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = 'Gagal menyimpan profil: $e';
      });
    }
  }

  Future<void> _loadStats(String technicianId) async {
    setState(() {
      _statsLoading = true;
    });

    try {
      // Fetch all service orders (including completed) for this technician
      final orders = await BackendService.fetchServiceOrdersForTechnician(
        technicianId,
        excludeFinished: false,
      );

      int completedCount = 0;
      double totalRevenue = 0.0;

      for (final order in orders) {
        final status = order['status_service']?.toString() ?? '';
        if (status == 'selesai') {
          completedCount++;
          final biayaAkhir = (order['biaya_akhir'] as num?)?.toDouble() ?? 0.0;
          final orderCurrency = order['currency']?.toString() ?? 'IDR';
          
          // Convert to technician's preferred currency if different
          if (orderCurrency != _selectedCurrency && biayaAkhir > 0) {
            final convertedAmount = await CurrencyService.convertCurrency(
              biayaAkhir,
              orderCurrency,
              _selectedCurrency,
            );
            totalRevenue += convertedAmount;
          } else {
            totalRevenue += biayaAkhir;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _totalCompletedTickets = completedCount;
        _totalRevenue = totalRevenue;
        _statsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statsLoading = false;
      });
      print('Error loading stats: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  Future<void> _exportDatabaseDebug() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final exportedFile = await BackendService.exportDatabase();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Database diekspor ke: ${exportedFile.path}'),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal mengekspor database: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  void _setSelectedCurrency(String currency) {
    setState(() {
      _selectedCurrency = currency;
    });
  }

  void _startTimeRefresh() {
    _timeRefreshTimer?.cancel();
    _timeRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  void _setSelectedTimeZone(String value) {
    setState(() {
      _selectedTimeZone = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Profile',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF080E1A),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Profile Photo
                    GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 60,
                        backgroundImage: _selectedImage != null
                            ? FileImage(File(_selectedImage!.path))
                            : (_technicianData?['avatar_url'] != null
                                  ? ((_technicianData!['avatar_url'] as String)
                                          .startsWith('/') ||
                                      (_technicianData!['avatar_url'] as String)
                                          .startsWith('file://')
                                      ? FileImage(File(
                                          (_technicianData!['avatar_url'] as String)
                                              .replaceFirst('file://', ''),
                                        ))
                                      : NetworkImage(
                                          _technicianData!['avatar_url'],
                                        ))
                                  : null),
                        child:
                            _selectedImage == null &&
                                _technicianData?['avatar_url'] == null
                            ? const Icon(Icons.camera_alt, size: 40)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _pickImage,
                      child: const Text('Ubah Foto Profile'),
                    ),
                    const SizedBox(height: 24),

                    // Name Field
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Nama tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Phone Field
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Nomor Teknisi',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),

                    // Stats Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _statsLoading
                            ? const Center(child: CircularProgressIndicator())
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Statistik Pekerjaan',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      Column(
                                        children: [
                                          Text(
                                            _totalCompletedTickets.toString(),
                                            style: const TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                              color: Color.fromARGB(255, 26, 41, 67),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'Tiket Selesai',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        children: [
                                          Text(
                                            CurrencyService.formatCurrency(_totalRevenue, _selectedCurrency),
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Color.fromARGB(255, 26, 41, 67),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Total Pendapatan ($_selectedCurrency)',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Card(
                      child: ListTile(
                        title: const Text('Pengamanan Tambahan'),
                        subtitle: const Text(
                          'Atur PIN atau biometrik untuk masuk',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MoreSecurePage(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Preferensi Mata Uang',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            CurrencySelector(
                              selectedCurrency: _selectedCurrency,
                              onCurrencyChanged: _setSelectedCurrency,
                              showFlag: true,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text('Contoh 1000 $_selectedCurrency = '),
                                Expanded(
                                  child: CurrencyConverter(
                                    baseAmount: 1000,
                                    baseCurrency: _selectedCurrency,
                                    targetCurrency: _selectedCurrency == 'IDR' ? 'USD' : 'IDR',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Zona Waktu',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _selectedTimeZone,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                              items: _timeZones.map((zone) {
                                return DropdownMenuItem<String>(
                                  value: zone,
                                  child: Text(TimeZoneService.zoneLabel(zone)),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  _setSelectedTimeZone(value);
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Waktu sekarang: ${TimeZoneService.formatZoneTime(_selectedTimeZone)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Debug export database
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _exportDatabaseDebug,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                        ),
                        child: const Text('Export Database Debug'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        child: const Text('Simpan Perubahan'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _timeRefreshTimer?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
