import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late String _ticketCurrency;
  String _selectedCurrency = 'IDR'; // Default currency

  final int _maxKondisiFisikLength = 500;
  final int _maxKelengkapanLength = 500;
  final int _maxDiagnosaLength = 1000;
  final int _maxKeluhanLength = 1000;
  final int _maxNominalInputLength = 15;

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

  String _formatCurrency(double value) {
    return CurrencyService.formatCurrency(value, _selectedCurrency);
  }

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadInitialData();
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
    _ticketCurrency = widget.tiketData['currency']?.toString() ?? 'IDR';
    _selectedCurrency = _ticketCurrency;
  }

  Future<void> _loadInitialData() async {
    await _loadTechnicianCurrency();
    await _loadPhotos();
    await _loadSpareparts();
  }

  Future<void> _loadTechnicianCurrency() async {
    try {
      final techId = await BackendService.getCurrentTechnicianId();
      if (techId != null) {
        final techData = await BackendService.fetchTechnicianById(techId);
        if (techData != null && mounted) {
          final techCurrency = techData['currency']?.toString();
          if (techCurrency != null) {
            final originalCurrency = _ticketCurrency;
            setState(() {
              _selectedCurrency = techCurrency;
            });
            if (originalCurrency != techCurrency) {
              await _convertTicketValues(originalCurrency, techCurrency);
            }
          }
        }
      }
    } catch (e) {
      // Fallback to ticket currency or default if loading fails
      if (mounted) {
        setState(() {
          _selectedCurrency = widget.tiketData['currency'] ?? 'IDR';
        });
      }
      debugPrint('Error loading technician currency: $e');
    }
  }

  Future<void> _convertTicketValues(
    String fromCurrency,
    String toCurrency,
  ) async {
    if (fromCurrency == toCurrency) return;

    final currentBiayaJasa = double.tryParse(_biayaJasaController.text) ?? 0.0;
    final convertedBiayaJasa = await CurrencyService.convertCurrency(
      currentBiayaJasa,
      fromCurrency,
      toCurrency,
    );

    for (final sparepart in _spareparts) {
      final harga = (sparepart['harga'] as num?)?.toDouble() ?? 0.0;
      final convertedHarga = await CurrencyService.convertCurrency(
        harga,
        fromCurrency,
        toCurrency,
      );
      sparepart['harga'] = convertedHarga;
    }

    if (!mounted) return;
    setState(() {
      _biayaJasaController.text = _formatCurrency(convertedBiayaJasa);
      _selectedCurrency = toCurrency;
    });
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

    if (_selectedCurrency != _ticketCurrency) {
      await _convertTicketValues(_ticketCurrency, _selectedCurrency);
    }

    if (_biayaJasaController.text.isEmpty) {
      final biayaAkhir =
          double.tryParse(widget.tiketData['biaya_akhir']?.toString() ?? '') ??
              0.0;
      final jasaFromExisting = biayaAkhir - _calculateSparepartTotal();
      if (jasaFromExisting > 0) {
        _biayaJasaController.text = _formatCurrency(jasaFromExisting);
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
    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 600,
                  maxHeight: MediaQuery.of(dialogContext).size.height * 0.85,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Tambah Sparepart',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        try {
                                          final pickedUrl = await _pickAttachmentImage(
                                            ImageSource.camera,
                                            'sparepart_${widget.tiketData['id'] ?? 'unknown'}',
                                          );
                                          if (pickedUrl != null) {
                                            dialogSetState(() {
                                              selectedPhotoUrl = pickedUrl;
                                            });
                                          }
                                        } catch (e) {
                                          debugPrint('Error picking camera image: $e');
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
                                        try {
                                          final pickedUrl = await _pickAttachmentImage(
                                            ImageSource.gallery,
                                            'sparepart_${widget.tiketData['id'] ?? 'unknown'}',
                                          );
                                          if (pickedUrl != null) {
                                            dialogSetState(() {
                                              selectedPhotoUrl = pickedUrl;
                                            });
                                          }
                                        } catch (e) {
                                          debugPrint('Error picking gallery image: $e');
                                        }
                                      },
                                      icon: const Icon(Icons.photo_library),
                                      label: const Text('Galeri'),
                                    ),
                                  ),
                                ],
                              ),
                              if (selectedPhotoUrl != null) const SizedBox(height: 16),
                              if (selectedPhotoUrl != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    File(selectedPhotoUrl!),
                                    width: double.infinity,
                                    height: 250,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[300],
                                        height: 250,
                                        child: const Center(
                                          child: Icon(Icons.broken_image),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              if (selectedPhotoUrl != null) const SizedBox(height: 16),
                              TextFormField(
                                controller: namaController,
                                decoration: const InputDecoration(
                                  labelText: 'Nama Sparepart',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: kodeController,
                                decoration: const InputDecoration(
                                  labelText: 'Kode Sparepart',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: qtyController,
                                      decoration: const InputDecoration(
                                        labelText: 'Qty',
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      controller: hargaController,
                                      decoration: const InputDecoration(
                                        labelText: 'Harga',
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                            },
                            child: const Text('Batal'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              final nama = namaController.text.trim();
                              final kode = kodeController.text.trim();
                              final qty = int.tryParse(qtyController.text.trim()) ?? 0;
                              final harga =
                                  double.tryParse(hargaController.text.trim()) ?? 0.0;
                              if (nama.isEmpty || qty <= 0 || harga <= 0) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Isi semua field sparepart dengan benar.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              Navigator.of(dialogContext).pop();
                              _addSparepart(
                                nama,
                                kode,
                                qty,
                                harga,
                                photoUrl: selectedPhotoUrl,
                              );
                            },
                            child: const Text('Simpan'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
        titleTextStyle: const TextStyle(color: Colors.white),
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
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(_maxKondisiFisikLength),
                      ],
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
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(_maxKelengkapanLength),
                      ],
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
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(_maxKeluhanLength),
                      ],
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
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(_maxDiagnosaLength),
                      ],
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
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(_maxNominalInputLength),
                      ],
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
                                    leading: sparepartPhotoPath.isNotEmpty &&
                                            File(sparepartPhotoPath).existsSync()
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Image.file(
                                              File(sparepartPhotoPath),
                                              width: 48,
                                              height: 48,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return const SizedBox(
                                                  width: 48,
                                                  height: 48,
                                                  child: Icon(
                                                    Icons.broken_image,
                                                    color: Colors.grey,
                                                  ),
                                                );
                                              },
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
                                      'Kode: ${sparepart['kode'] ?? '-'} • Qty: $qty • Harga: ${CurrencyService.formatCurrency(harga, _selectedCurrency)}',
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          CurrencyService.formatCurrency(qty * harga, _selectedCurrency),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
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
                              CurrencyService.formatCurrency(_calculateSparepartTotal(), _selectedCurrency),
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
                                  CurrencyService.formatCurrency(_biayaJasaValue(), _selectedCurrency),
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
                                  CurrencyService.formatCurrency(_calculateSparepartTotal(), _selectedCurrency),
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
                                  CurrencyService.formatCurrency(_calculateBiayaAkhir(), _selectedCurrency),
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
