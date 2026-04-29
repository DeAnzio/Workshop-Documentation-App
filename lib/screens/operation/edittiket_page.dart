import 'package:flutter/material.dart';
import 'package:anzioworkshopapp/services/currency_service.dart';
import 'package:anzioworkshopapp/services/backend_service.dart';
import 'package:anzioworkshopapp/widgets/currency_widgets.dart';

class EditTiketPage extends StatefulWidget {
  final Map<String, dynamic> tiketData;

  const EditTiketPage({super.key, required this.tiketData});

  @override
  State<EditTiketPage> createState() => _EditTiketPageState();
}

class _EditTiketPageState extends State<EditTiketPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  // Controllers
  late TextEditingController _kondisiFisikController;
  late TextEditingController _kelengkapanController;
  late TextEditingController _diagnosaController;
  late TextEditingController _estimasiBiayaController;
  late TextEditingController _biayaAkhirController;
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
    _estimasiBiayaController = TextEditingController(
      text: widget.tiketData['estimasi_biaya']?.toString() ?? '',
    );
    _biayaAkhirController = TextEditingController(
      text: widget.tiketData['biaya_akhir']?.toString() ?? '',
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
        estimasiBiaya: _estimasiBiayaController.text.isNotEmpty
            ? double.tryParse(_estimasiBiayaController.text)
            : null,
        biayaAkhir: _biayaAkhirController.text.isNotEmpty
            ? double.tryParse(_biayaAkhirController.text)
            : null,
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

                    // Currency Selector
                    const Text(
                      'Mata Uang',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CurrencySelector(
                      selectedCurrency: _selectedCurrency,
                      onCurrencyChanged: (currency) {
                        setState(() {
                          _selectedCurrency = currency;
                        });
                      },
                      showFlag: true,
                    ),
                    const SizedBox(height: 16),

                    // Estimasi Biaya
                    TextFormField(
                      controller: _estimasiBiayaController,
                      decoration: InputDecoration(
                        labelText: 'Estimasi Biaya ($_selectedCurrency)',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.attach_money),
                        prefixText: CurrencyService.getCurrencySymbol(
                          _selectedCurrency,
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    // Biaya Akhir
                    TextFormField(
                      controller: _biayaAkhirController,
                      decoration: InputDecoration(
                        labelText: 'Biaya Akhir ($_selectedCurrency)',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.monetization_on),
                        prefixText: CurrencyService.getCurrencySymbol(
                          _selectedCurrency,
                        ),
                      ),
                      keyboardType: TextInputType.number,
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
    _estimasiBiayaController.dispose();
    _biayaAkhirController.dispose();
    _keluhanController.dispose();
    super.dispose();
  }
}

