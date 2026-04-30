import 'dart:io';

import 'package:flutter/material.dart';
import 'package:anzioworkshopapp/screens/utils/Location_help.dart';
import 'package:anzioworkshopapp/services/currency_service.dart';
import 'package:anzioworkshopapp/services/backend_service.dart';
import 'package:anzioworkshopapp/widgets/currency_widgets.dart';
import 'package:image_picker/image_picker.dart';

class Inputdata extends StatelessWidget {
  const Inputdata({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Coba-Coba Flutter',
      home: const InputDataPelanggan(),
    );
  }
}

class InputDataPelanggan extends StatefulWidget {
  const InputDataPelanggan({super.key});

  @override
  State<InputDataPelanggan> createState() => _InputDataPelangganState();
}

class _InputDataPelangganState extends State<InputDataPelanggan> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _selectedImages = [];

  // Controllers untuk text field
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _nohpController = TextEditingController();
  final TextEditingController _alamatController = TextEditingController();
  final TextEditingController _merekModelController = TextEditingController();
  final TextEditingController _serialNumberController = TextEditingController();
  final TextEditingController _kondisiFisikController = TextEditingController();
  final TextEditingController _kelengkapanController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _catatanController = TextEditingController();
  final TextEditingController _estimasiBiayaController =
      TextEditingController();
  final TextEditingController _nominalDpController = TextEditingController();
  bool _isFetchingLocation = false;

  // Variabel untuk dropdown
  String? _jenisDevice;
  String? _serviceType;
  String? _prioritas;
  String _selectedCurrency = 'IDR'; // Default currency

  // List pilihan untuk dropdown
  final List<String> _jenisDeviceList = [
    'Laptop',
    'PC',
    'Smartphone',
    'Tablet',
  ];
  final List<String> _serviceTypeList = [
    'Instalasi',
    'Perbaikan',
    'Upgrade',
    'Maintenance',
  ];
  final List<String> _prioritasList = ['normal', 'urgent', 'express'];

  double _parseNumericInput(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9\-,\.]'), '').replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0.0;
  }

  Future<void> _setSelectedCurrency(String newCurrency) async {
    final oldCurrency = _selectedCurrency;
    if (newCurrency == oldCurrency) return;

    final biaya = _estimasiBiayaController.text.isNotEmpty
        ? _parseNumericInput(_estimasiBiayaController.text)
        : 0.0;
    final dp = _nominalDpController.text.isNotEmpty
        ? _parseNumericInput(_nominalDpController.text)
        : 0.0;

    final convertedBiaya = biaya > 0
        ? await CurrencyService.convertCurrency(biaya, oldCurrency, newCurrency)
        : 0.0;
    final convertedDp = dp > 0
        ? await CurrencyService.convertCurrency(dp, oldCurrency, newCurrency)
        : 0.0;

    if (!mounted) return;
    setState(() {
      _selectedCurrency = newCurrency;
      _estimasiBiayaController.text = biaya > 0
          ? convertedBiaya.toStringAsFixed(2)
          : _estimasiBiayaController.text;
      _nominalDpController.text = dp > 0
          ? convertedDp.toStringAsFixed(2)
          : _nominalDpController.text;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Input Data Pelanggan',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
            letterSpacing: 1.5,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 26, 41, 67),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Nama Pelanggan
              TextFormField(
                controller: _namaController,
                decoration: const InputDecoration(
                  labelText: 'Nama Pelanggan',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nama pelanggan harus diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 2. No. HP
              TextFormField(
                controller: _nohpController,
                decoration: const InputDecoration(
                  labelText: 'No. HP',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'No. HP harus diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 3. Alamat
              TextFormField(
                controller: _alamatController,
                decoration: InputDecoration(
                  labelText: 'Alamat',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.location_on),
                  suffixIcon: IconButton(
                    icon: _isFetchingLocation
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.map),
                    tooltip: 'Pilih lokasi dengan menjatuhkan pin di peta',
                    onPressed: _isFetchingLocation ? null : _showLocationPicker,
                  ),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // 4. Jenis Device (Dropdown)
              DropdownButtonFormField<String>(
                initialValue: _jenisDevice,
                decoration: const InputDecoration(
                  labelText: 'Jenis Device',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.devices),
                ),
                items: _jenisDeviceList.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _jenisDevice = newValue;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Jenis device harus dipilih';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 4. Merek & Model
              TextFormField(
                controller: _merekModelController,
                decoration: const InputDecoration(
                  labelText: 'Merek & Model',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.smartphone),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Merek & Model harus diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 5. Serial Number
              TextFormField(
                controller: _serialNumberController,
                decoration: const InputDecoration(
                  labelText: 'Serial Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.confirmation_num),
                ),
              ),
              const SizedBox(height: 16),

              // 6. Kondisi Fisik
              TextFormField(
                controller: _kondisiFisikController,
                decoration: const InputDecoration(
                  labelText: 'Kondisi Fisik',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.build),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // 7. Kelengkapan
              TextFormField(
                controller: _kelengkapanController,
                decoration: const InputDecoration(
                  labelText: 'Kelengkapan',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // 8. Password/PIN Device
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password / PIN Device',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),

              // 9. Input Foto
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickImageFromCamera,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Ambil Foto'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickImages,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Pilih Galeri'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Display selected images
              if (_selectedImages.isNotEmpty) ...[
                const Text(
                  'Foto yang dipilih:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(_selectedImages[index].path),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: -8,
                            right: 0,
                            child: IconButton(
                              icon: const Icon(
                                Icons.remove_circle,
                                color: Colors.red,
                              ),
                              onPressed: () => _removeImage(index),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 10. Service Type (Dropdown)
              DropdownButtonFormField<String>(
                initialValue: _serviceType,
                decoration: const InputDecoration(
                  labelText: 'Service Type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.build),
                ),
                items: _serviceTypeList.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _serviceType = newValue;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Service type harus dipilih';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 11. Prioritas (Dropdown)
              DropdownButtonFormField<String>(
                initialValue: _prioritas,
                decoration: const InputDecoration(
                  labelText: 'Prioritas',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.priority_high),
                ),
                items: _prioritasList.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _prioritas = newValue;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Prioritas harus dipilih';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Currency Selector
              const Text(
                'Mata Uang',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              CurrencySelector(
                selectedCurrency: _selectedCurrency,
                onCurrencyChanged: (currency) {
                  _setSelectedCurrency(currency);
                },
                showFlag: true,
              ),
              const SizedBox(height: 16),

              // 12. Biaya Jasa
              TextFormField(
                controller: _estimasiBiayaController,
                decoration: InputDecoration(
                  labelText: 'Biaya Jasa ($_selectedCurrency)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.payments),
                  prefixText: CurrencyService.getCurrencySymbol(
                    _selectedCurrency,
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // 13. Nominal DP
              TextFormField(
                controller: _nominalDpController,
                decoration: InputDecoration(
                  labelText: 'Nominal DP ($_selectedCurrency)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.monetization_on),
                  prefixText: CurrencyService.getCurrencySymbol(
                    _selectedCurrency,
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // 14. Catatan / Keluhan
              TextFormField(
                controller: _catatanController,
                decoration: const InputDecoration(
                  labelText: 'Keluhan / Catatan',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 24),

              // Button Submit
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    // Proses data jika validasi berhasil
                    await _simpanDataKeDatabse();
                  }
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: const Color.fromARGB(255, 26, 41, 67),
                ),
                child: const Text(
                  'SIMPAN DATA',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Fungsi untuk menyimpan data ke database
  Future<void> _simpanDataKeDatabse() async {
    try {
      // Get technician id from session
      final techId = await BackendService.getCurrentTechnicianId();
      if (techId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: User not authenticated')),
        );
        return;
      }

      // Insert customer data and get service order ID
      final serviceOrderId = await BackendService.insertCustomerData(
        namaPelanggan: _namaController.text,
        noHp: _nohpController.text,
        alamat: _alamatController.text.isNotEmpty
            ? _alamatController.text
            : null,
        jenisDevice: _jenisDevice ?? '',
        merekModel: _merekModelController.text,
        serialNumber: _serialNumberController.text.isNotEmpty
            ? _serialNumberController.text
            : null,
        kondisiFisik: _kondisiFisikController.text.isNotEmpty
            ? _kondisiFisikController.text
            : null,
        kelengkapan: _kelengkapanController.text.isNotEmpty
            ? _kelengkapanController.text
            : null,
        password: _passwordController.text,
        keluhan: _catatanController.text,
        serviceType: _serviceType ?? '',
        prioritas: _prioritas ?? 'normal',
        estimasiBiaya: _estimasiBiayaController.text.isNotEmpty
            ? double.tryParse(_estimasiBiayaController.text)
            : null,
        nominalDp: _nominalDpController.text.isNotEmpty
            ? double.tryParse(_nominalDpController.text)
            : null,
        technicianId: techId,
        currency: _selectedCurrency,
      );

      if (serviceOrderId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Gagal menyimpan data')));
        return;
      }

      // Upload selected images
      if (_selectedImages.isNotEmpty) {
        for (var image in _selectedImages) {
          final bytes = await image.readAsBytes();
          final fileName =
              '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
          final photoUrl = await BackendService.uploadImage(bytes, fileName);
          if (photoUrl != null) {
            await BackendService.insertServicePhoto(serviceOrderId, photoUrl);
          }
        }
      }

      if (!mounted) return;

      // Tampilkan pesan sukses
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Data berhasil disimpan!')));

      // Clear form setelah berhasil
      _clearForm();
    } catch (e) {
      // Tampilkan pesan error
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan data: $e')));
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _nohpController.dispose();
    _alamatController.dispose();
    _merekModelController.dispose();
    _serialNumberController.dispose();
    _kondisiFisikController.dispose();
    _kelengkapanController.dispose();
    _passwordController.dispose();
    _catatanController.dispose();
    _estimasiBiayaController.dispose();
    _nominalDpController.dispose();
    super.dispose();
  }

  // Fungsi untuk mengambil foto dari kamera
  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() {
          _selectedImages.add(image);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image from camera: $e')),
      );
    }
  }

  // Fungsi untuk memilih foto dari galeri
  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking images: $e')));
    }
  }

  // Fungsi untuk menghapus foto yang dipilih
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _showLocationPicker() async {
    setState(() {
      _isFetchingLocation = true;
    });

    final selectedAddress = await LocationHelp.openLocationPicker(
      context,
      _alamatController.text,
    );

    if (selectedAddress != null) {
      setState(() {
        _alamatController.text = selectedAddress;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alamat berhasil diisi dari peta.')),
      );
    }

    if (!mounted) return;
    setState(() {
      _isFetchingLocation = false;
    });
  }

  // Fungsi untuk clear semua form
  void _clearForm() {
    _namaController.clear();
    _nohpController.clear();
    _alamatController.clear();
    _merekModelController.clear();
    _serialNumberController.clear();
    _kondisiFisikController.clear();
    _kelengkapanController.clear();
    _passwordController.clear();
    _catatanController.clear();
    _estimasiBiayaController.clear();
    _nominalDpController.clear();
    setState(() {
      _jenisDevice = null;
      _serviceType = null;
      _prioritas = null;
      _selectedImages.clear();
    });
  }
}
