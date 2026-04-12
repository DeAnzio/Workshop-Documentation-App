import 'package:flutter/material.dart';
import 'package:anzioworkshopapp/services/supabase_service.dart';
import 'package:anzioworkshopapp/screens/utils/moresecure_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

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

    final valid = await SupabaseService.validateSession();
    if (!mounted) return;
    if (!valid) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final techId = await SupabaseService.getCurrentTechnicianId();
    if (!mounted) return;
    if (techId == null) {
      setState(() {
        _loading = false;
        _errorMessage = 'Pengguna tidak terautentikasi.';
      });
      return;
    }

    try {
      final res = await Supabase.instance.client
          .from('technicians')
          .select()
          .eq('id', techId)
          .single();

      final data = Map<String, dynamic>.from(res as Map);
      setState(() {
        _technicianData = data;
        _nameController.text = data['name'] ?? '';
        _phoneController.text = data['no_hp'] ?? '';
        //_securityEnabled = data['security_enabled'] ?? false;
        _loading = false;
      });
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

    final techId = await SupabaseService.getCurrentTechnicianId();
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
        photoUrl = await SupabaseService.uploadProfileAvatar(bytes, fileName);
      }

      final updateData = {
        'name': _nameController.text,
        'no_hp': _phoneController.text,
        //'security_enabled': _securityEnabled,
      };

      if (photoUrl != null) {
        updateData['avatar_url'] = photoUrl;
      }

      final success = await SupabaseService.updateTechnicianProfile(
        techId,
        name: _nameController.text,
        phoneNumber: _phoneController.text,
        profilePhotoUrl: photoUrl,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: const Color.fromARGB(255, 26, 41, 67),
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
                                  ? NetworkImage(_technicianData!['avatar_url'])
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
                    const SizedBox(height: 24),

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
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
