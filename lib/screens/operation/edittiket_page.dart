import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:anzioworkshopapp/services/currency_service.dart';
import 'package:anzioworkshopapp/services/backend_service.dart';
import 'package:image_picker/image_picker.dart';

class EditTiketPage extends StatefulWidget {
  final Map<String, dynamic> tiketData;

  const EditTiketPage({super.key, required this.tiketData});

  @override
  State<EditTiketPage> createState() => _EditTiketPageState();
}

class _EditTiketPageState extends State<EditTiketPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  // Camera
  final ImagePicker _picker = ImagePicker();
  bool _photoLoading = false;
  List<Map<String, dynamic>> _photoList = [];

  // Sparepart logging
  bool _sparepartLoading = false;
  List<Map<String, dynamic>> _spareparts = [];

  // Controllers
  late TextEditingController _kondisiFisikController;
  late TextEditingController _kelengkapanController;
  late TextEditingController _diagnosaController;
  late TextEditingController _biayaJasaController;
  late TextEditingController _keluhanController;

  String? _statusService;
  String? _statusBayar;
  String? _jenisService;
  String? _prioritas;
  String _selectedCurrency = 'IDR'; // Default currency

  final List<String> _statusServiceList = [
    'masuk',
    'proses',
    'selesai',
    'ambil',
  ];
  final List<String> _statusBayarList = ['belum', 'lunas', 'dp'];
  final List<String> _jenisServiceList = [
    'Instalasi',
    'Perbaikan',
    'Upgrade',
    'Maintenance',
  ];
  final List<String> _prioritasList = ['normal', 'urgent', 'express'];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadPhotos();
    _loadSpareparts();
  }

  void _initializeControllers() {
    _kondisiFisikController = TextEditingController(
      text: widget.tiketData['kondisi_fisik'] ?? '',
    );
    _kelengkapanController = TextEditingController(
      text: widget.tiketData['kelengkapan'] ?? '',
    );
    _diagnosaController = TextEditingController(
      text: widget.tiketData['diagnosa'] ?? '',
    );
    _biayaJasaController = TextEditingController(
      text: widget.tiketData['estimasi_biaya']?.toString() ?? '',
    );
    _keluhanController = TextEditingController(
      text: widget.tiketData['keluhan'] ?? '',
    );

    _statusService = widget.tiketData['status_service'] ?? 'masuk';
    _statusBayar = widget.tiketData['status_bayar'] ?? 'belum';
    _jenisService = widget.tiketData['jenis_service'] ?? '';
    _prioritas = widget.tiketData['prioritas'] ?? 'normal';
    _selectedCurrency = widget.tiketData['currency'] ?? 'IDR';
  }

  Future<void> _loadPhotos() async {
    final tiketId = widget.tiketData['id']?.toString();
    if (tiketId == null) {
      return;
    }
    setState(() {
      _photoLoading = true;
    });
    final photos = await BackendService.getServicePhotos(tiketId);
    if (!mounted) return;
    setState(() {
      _photoList = photos;
      _photoLoading = false;
    });
  }

  Future<String?> _pickAttachmentImage(
    ImageSource source,
    String filePrefix,
  ) async {
    final image = await _picker.pickImage(source: source, imageQuality: 80);
    if (image == null) return null;

    final bytes = await image.readAsBytes();
    final fileName = '${filePrefix}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    return await BackendService.uploadImage(bytes, fileName);
  }

  Future<void> _pickPhoto([ImageSource source = ImageSource.camera]) async {
    final tiketId = widget.tiketData['id']?.toString();
    if (tiketId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tiket ID tidak tersedia.')));
      return;
    }

    final savedPath = await _pickAttachmentImage(source, 'tiket_$tiketId');
    if (savedPath == null) return;

    setState(() {
      _photoLoading = true;
    });

    try {
      await BackendService.insertServicePhoto(tiketId, savedPath);
      await _loadPhotos();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto dokumentasi berhasil disimpan.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saat menyimpan foto: $e')));
    }

    if (!mounted) return;
    setState(() {
      _photoLoading = false;
    });
  }

  Future<void> _loadSpareparts() async {
    final tiketId = widget.tiketData['id']?.toString();
    if (tiketId == null) return;
    setState(() {
      _sparepartLoading = true;
    });
    final spareparts = await BackendService.fetchServiceSpareparts(tiketId);
    if (!mounted) return;
    setState(() {
      _spareparts = spareparts;
      _sparepartLoading = false;
    });

    if (_biayaJasaController.text.isEmpty) {
      final biayaAkhir =
          double.tryParse(widget.tiketData['biaya_akhir']?.toString() ?? '') ??
          0.0;
      final jasaFromExisting = biayaAkhir - _calculateSparepartTotal();
      if (jasaFromExisting > 0) {
        _biayaJasaController.text = jasaFromExisting.toStringAsFixed(0);
      }
    }
  }

  double _calculateSparepartTotal() {
    return _spareparts.fold(0.0, (total, item) {
      final qty = (item['qty'] as num?)?.toDouble() ?? 0.0;
      final harga = (item['harga'] as num?)?.toDouble() ?? 0.0;
      return total + qty * harga;
    });
  }

  Future<void> _showAddSparepartDialog() async {
    final namaController = TextEditingController();
    final kodeController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    final hargaController = TextEditingController();
    String? selectedPhotoUrl;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              title: const Text('Tambah Sparepart'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selectedPhotoUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(selectedPhotoUrl!),
                          width: double.infinity,
                          height: 140,
                          fit: BoxFit.cover,
                        ),
                      ),
                    if (selectedPhotoUrl != null) const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final pickedUrl = await _pickAttachmentImage(
                                ImageSource.camera,
                                'sparepart_${widget.tiketData['id'] ?? 'unknown'}',
                              );
                              if (pickedUrl != null) {
                                dialogSetState(() {
                                  selectedPhotoUrl = pickedUrl;
                                });
                              }
                            },
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Kamera'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final pickedUrl = await _pickAttachmentImage(
                                ImageSource.gallery,
                                'sparepart_${widget.tiketData['id'] ?? 'unknown'}',
                              );
                              if (pickedUrl != null) {
                                dialogSetState(() {
                                  selectedPhotoUrl = pickedUrl;
                                });
                              }
                            },
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Galeri'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: namaController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Sparepart',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: kodeController,
                      decoration: const InputDecoration(
                        labelText: 'Kode Sparepart',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: qtyController,
                      decoration: const InputDecoration(labelText: 'Qty'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: hargaController,
                      decoration: const InputDecoration(labelText: 'Harga'),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final nama = namaController.text.trim();
                    final qty = int.tryParse(qtyController.text.trim()) ?? 0;
                    final harga =
                        double.tryParse(hargaController.text.trim()) ?? 0.0;
                    if (nama.isEmpty || qty <= 0 || harga <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Isi semua field sparepart dengan benar.',
                          ),
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).pop();
                    _addSparepart(
                      nama,
                      kodeController.text.trim(),
                      qty,
                      harga,
                      photoUrl: selectedPhotoUrl,
                    );
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addSparepart(
    String nama,
    String kode,
    int qty,
    double harga, {
    String? photoUrl,
  }) async {
    final tiketId = widget.tiketData['id']?.toString();
    if (tiketId == null) return;

    setState(() {
      _sparepartLoading = true;
    });

    final insertedId = await BackendService.insertServiceSparepart(
      tiketId,
      nama: nama,
      kode: kode,
      qty: qty,
      harga: harga,
      photoUrl: photoUrl,
    );

    if (insertedId != null) {
      await _loadSpareparts();
      setState(() {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sparepart berhasil ditambahkan.')),
      );
    } else {
      setState(() {
        _sparepartLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menambahkan sparepart.')),
      );
    }
  }

  Future<void> _showEditSparepartDialog(Map<String, dynamic> sparepart) async {
    final namaController = TextEditingController(
      text: sparepart['nama']?.toString() ?? '',
    );
    final kodeController = TextEditingController(
      text: sparepart['kode']?.toString() ?? '',
    );
    final qtyController = TextEditingController(
      text: (sparepart['qty'] as num?)?.toString() ?? '1',
    );
    final hargaController = TextEditingController(
      text: (sparepart['harga'] as num?)?.toString() ?? '0',
    );
    String? selectedPhotoUrl = sparepart['photo_url']?.toString();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              title: const Text('Edit Sparepart'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selectedPhotoUrl?.isNotEmpty == true)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(selectedPhotoUrl!),
                          width: double.infinity,
                          height: 140,
                          fit: BoxFit.cover,
                        ),
                      ),
                    if (selectedPhotoUrl?.isNotEmpty == true)
                      const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final pickedUrl = await _pickAttachmentImage(
                                ImageSource.camera,
                                'sparepart_${widget.tiketData['id'] ?? 'unknown'}',
                              );
                              if (pickedUrl != null) {
                                dialogSetState(() {
                                  selectedPhotoUrl = pickedUrl;
                                });
                              }
                            },
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Kamera'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final pickedUrl = await _pickAttachmentImage(
                                ImageSource.gallery,
                                'sparepart_${widget.tiketData['id'] ?? 'unknown'}',
                              );
                              if (pickedUrl != null) {
                                dialogSetState(() {
                                  selectedPhotoUrl = pickedUrl;
                                });
                              }
                            },
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Galeri'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: namaController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Sparepart',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: kodeController,
                      decoration: const InputDecoration(
                        labelText: 'Kode Sparepart',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: qtyController,
                      decoration: const InputDecoration(labelText: 'Qty'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: hargaController,
                      decoration: const InputDecoration(labelText: 'Harga'),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _confirmDeleteSparepart(sparepart['id']?.toString() ?? '');
                  },
                  child: const Text(
                    'Hapus',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final nama = namaController.text.trim();
                    final qty = int.tryParse(qtyController.text.trim()) ?? 0;
                    final harga =
                        double.tryParse(hargaController.text.trim()) ?? 0.0;
                    if (nama.isEmpty || qty <= 0 || harga <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Isi semua field sparepart dengan benar.',
                          ),
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).pop();
                    _updateSparepart(
                      sparepart['id']?.toString() ?? '',
                      nama: nama,
                      kode: kodeController.text.trim(),
                      qty: qty,
                      harga: harga,
                      photoUrl: selectedPhotoUrl,
                    );
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteSparepart(String sparepartId) async {
    if (sparepartId.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus Sparepart'),
          content: const Text('Yakin ingin menghapus sparepart ini?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Hapus', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await _deleteSparepart(sparepartId);
    }
  }

  Future<void> _updateSparepart(
    String sparepartId, {
    required String nama,
    String? kode,
    required int qty,
    required double harga,
    String? photoUrl,
  }) async {
    if (sparepartId.isEmpty) return;
    setState(() {
      _sparepartLoading = true;
    });
    final messenger = ScaffoldMessenger.of(context);
    final updated = await BackendService.updateServiceSparepart(
      sparepartId,
      nama: nama,
      kode: kode,
      qty: qty,
      harga: harga,
      photoUrl: photoUrl,
    );
    if (!mounted) return;
    if (updated) {
      await _loadSpareparts();
      setState(() {});
      messenger.showSnackBar(
        const SnackBar(content: Text('Sparepart berhasil diperbarui.')),
      );
    } else {
      setState(() {
        _sparepartLoading = false;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal memperbarui sparepart.')),
      );
    }
  }

  Future<void> _deleteSparepart(String sparepartId) async {
    if (sparepartId.isEmpty) return;
    setState(() {
      _sparepartLoading = true;
    });
    final messenger = ScaffoldMessenger.of(context);
    final deleted = await BackendService.deleteServiceSparepart(sparepartId);
    if (!mounted) return;
    if (deleted) {
      await _loadSpareparts();
      setState(() {});
      messenger.showSnackBar(
        const SnackBar(content: Text('Sparepart berhasil dihapus.')),
      );
    } else {
      setState(() {
        _sparepartLoading = false;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal menghapus sparepart.')),
      );
    }
  }

  double _biayaJasaValue() {
    return double.tryParse(_biayaJasaController.text) ?? 0.0;
  }

  double _calculateBiayaAkhir() {
    return _biayaJasaValue() + _calculateSparepartTotal();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
    });

    try {
      final tiketId = widget.tiketData['id']?.toString();
      if (tiketId == null) {
        throw Exception('Tiket ID tidak ditemukan');
      }

      final success = await BackendService.updateServiceOrder(
        tiketId,
        statusService: _statusService,
        statusBayar: _statusBayar,
        jenisService: _jenisService,
        prioritas: _prioritas,
        kondisiFisik: _kondisiFisikController.text,
        kelengkapan: _kelengkapanController.text,
        diagnosa: _diagnosaController.text,
        estimasiBiaya: _biayaJasaValue(),
        biayaAkhir: _calculateBiayaAkhir(),
        keluhan: _keluhanController.text,
        currency: _selectedCurrency,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tiket berhasil diperbarui')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memperbarui tiket')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tiketNo = widget.tiketData['nomor_tiket']?.toString() ?? '-';

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Tiket - $tiketNo'),
        backgroundColor: const Color.fromARGB(255, 26, 41, 67),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info Dasar (Read-Only)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Informasi Dasar',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            Text('No. Tiket: $tiketNo'),
                            Text(
                              'Device: ${widget.tiketData['jenis_perangkat'] ?? '-'}',
                            ),
                            Text(
                              'Merek: ${widget.tiketData['merek_model'] ?? '-'}',
                            ),
                            Text(
                              'Tanggal Masuk: ${widget.tiketData['tgl_masuk']?.toString().split('T').first ?? '-'}',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Status Service
                    DropdownButtonFormField<String>(
                      initialValue: _statusService,
                      decoration: const InputDecoration(
                        labelText: 'Status Servis',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.info),
                      ),
                      items: _statusServiceList.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _statusService = newValue;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Status servis harus dipilih';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Jenis Service
                    DropdownButtonFormField<String>(
                      initialValue: _jenisService,
                      decoration: const InputDecoration(
                        labelText: 'Jenis Servis',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.build),
                      ),
                      items: _jenisServiceList.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _jenisService = newValue;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Prioritas
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
                    ),
                    const SizedBox(height: 16),

                    // Kondisi Fisik
                    TextFormField(
                      controller: _kondisiFisikController,
                      decoration: const InputDecoration(
                        labelText: 'Kondisi Fisik',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.visibility),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    // Kelengkapan
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

                    // Keluhan / Catatan
                    TextFormField(
                      controller: _keluhanController,
                      decoration: const InputDecoration(
                        labelText: 'Keluhan / Catatan',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.note),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // Diagnosa
                    TextFormField(
                      controller: _diagnosaController,
                      decoration: const InputDecoration(
                        labelText: 'Diagnosa',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.medical_information),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // Biaya Jasa
                    TextFormField(
                      controller: _biayaJasaController,
                      decoration: InputDecoration(
                        labelText: 'Biaya Jasa ($_selectedCurrency)',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.handyman),
                        prefixText: CurrencyService.getCurrencySymbol(
                          _selectedCurrency,
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),

                    // Dokumentasi Foto
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Dokumentasi Foto',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _photoLoading
                                      ? null
                                      : () => _pickPhoto(ImageSource.camera),
                                  icon: const Icon(Icons.camera_alt),
                                  label: const Text('Ambil Foto'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color.fromARGB(255, 26, 41, 67),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: _photoLoading
                                      ? null
                                      : () => _pickPhoto(ImageSource.gallery),
                                  icon: const Icon(Icons.photo_library),
                                  label: const Text('Galeri'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color.fromARGB(255, 26, 41, 67),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _photoLoading
                                ? const Center(child: CircularProgressIndicator())
                                : _photoList.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8.0),
                                    child: Text('Belum ada foto dokumentasi.'),
                                  )
                                : Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _photoList.map((photo) {
                                      final path = photo['photo_url']?.toString() ?? '';
                                      return GestureDetector(
                                        onTap: () {
                                          if (path.isEmpty) return;
                                          showDialog(
                                            context: context,
                                            builder: (context) => Dialog(
                                              child: Image.file(File(path)),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          width: 100,
                                          height: 100,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.grey.shade300),
                                            image: path.isNotEmpty
                                                ? DecorationImage(
                                                    image: FileImage(File(path)),
                                                    fit: BoxFit.cover,
                                                  )
                                                : null,
                                          ),
                                          child: path.isEmpty
                                              ? const Center(child: Icon(Icons.broken_image))
                                              : null,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sparepart Logging
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Sparepart',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _showAddSparepartDialog,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Tambah Sparepart'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color.fromARGB(
                                      255,
                                      26,
                                      41,
                                      67,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_sparepartLoading)
                              const Center(child: CircularProgressIndicator())
                            else if (_spareparts.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Text('Belum ada sparepart terdaftar.'),
                              )
                            else
                              Column(
                                children: _spareparts.map((sparepart) {
                                  final qty =
                                      (sparepart['qty'] as num?)?.toInt() ?? 0;
                                  final harga =
                                      (sparepart['harga'] as num?)
                                          ?.toDouble() ??
                                      0.0;
                                  final sparepartPhotoPath =
                                      sparepart['photo_url']?.toString() ?? '';
                                  return ListTile(
                                    leading: sparepartPhotoPath.isNotEmpty
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Image.file(
                                              File(sparepartPhotoPath),
                                              width: 48,
                                              height: 48,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.build,
                                            color: Color.fromARGB(
                                              255,
                                              26,
                                              41,
                                              67,
                                            ),
                                          ),
                                    title: Text(sparepart['nama'] ?? '-'),
                                    subtitle: Text(
                                      'Kode: ${sparepart['kode'] ?? '-'} • Qty: $qty • Harga: ${CurrencyService.getCurrencySymbol(_selectedCurrency)}${harga.toStringAsFixed(0)}',
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${CurrencyService.getCurrencySymbol(_selectedCurrency)}${(qty * harga).toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            color: Color.fromARGB(
                                              255,
                                              26,
                                              41,
                                              67,
                                            ),
                                          ),
                                          onPressed: () =>
                                              _showEditSparepartDialog(
                                                sparepart,
                                              ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          onPressed: () =>
                                              _confirmDeleteSparepart(
                                                sparepart['id']?.toString() ??
                                                    '',
                                              ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            const SizedBox(height: 12),
                            Text(
                              'Total Sparepart: ${CurrencyService.getCurrencySymbol(_selectedCurrency)}${_calculateSparepartTotal().toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Biaya Akhir
                    Card(
                      color: Colors.blueGrey.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Biaya Akhir',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Jumlah Biaya Jasa'),
                                Text(
                                  '${CurrencyService.getCurrencySymbol(_selectedCurrency)}${_biayaJasaValue().toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Sparepart'),
                                Text(
                                  '${CurrencyService.getCurrencySymbol(_selectedCurrency)}${_calculateSparepartTotal().toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24, thickness: 1.2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Biaya Akhir',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${CurrencyService.getCurrencySymbol(_selectedCurrency)}${_calculateBiayaAkhir().toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Status Pembayaran
                    DropdownButtonFormField<String>(
                      initialValue: _statusBayar,
                      decoration: const InputDecoration(
                        labelText: 'Status Pembayaran',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.payment),
                      ),
                      items: _statusBayarList.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _statusBayar = newValue;
                        });
                      },
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(
                            255,
                            26,
                            41,
                            67,
                          ),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text(
                          'Simpan Perubahan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
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
    _kondisiFisikController.dispose();
    _kelengkapanController.dispose();
    _diagnosaController.dispose();
    _biayaJasaController.dispose();
    _keluhanController.dispose();
    super.dispose();
  }
}
