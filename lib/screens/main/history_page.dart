import 'package:flutter/material.dart';
import 'package:anzioworkshopapp/services/backend_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool _loading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
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
      final list = await BackendService.fetchServiceOrdersForTechnician(
        techId,
        excludeFinished: false,
      );

      setState(() {
        _history = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = 'Gagal memuat riwayat: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        backgroundColor: const Color.fromARGB(255, 26, 41, 67),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : _history.isEmpty
          ? const Center(child: Text('Belum ada riwayat service.'))
          : RefreshIndicator(
              onRefresh: _loadHistory,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _history.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = _history[index];
                  final customerData = item['customers'];
                  String nama = '-';
                  String noHp = '-';

                  if (customerData is Map<String, dynamic>) {
                    nama = customerData['nama']?.toString() ?? '-';
                    noHp = customerData['no_hp']?.toString() ?? '-';
                  } else if (customerData is List && customerData.isNotEmpty) {
                    final customer = Map<String, dynamic>.from(
                      customerData.first as Map,
                    );
                    nama = customer['nama']?.toString() ?? '-';
                    noHp = customer['no_hp']?.toString() ?? '-';
                  }

                  final ticket = item['nomor_tiket']?.toString() ?? '-';
                  final jenis = item['jenis_perangkat']?.toString() ?? '-';
                  final merek = item['merek_model']?.toString() ?? '-';
                  final service = item['jenis_service']?.toString() ?? '-';
                  final status = item['status_service']?.toString() ?? '-';
                  final catatan = item['keluhan']?.toString() ?? '';
                  final tglMasuk = item['tgl_masuk']?.toString() ?? '-';

                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ticket,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Nama: $nama'),
                          Text('No. HP: $noHp'),
                          Text('Device: $jenis'),
                          Text('Merek/Model: $merek'),
                          Text('Jenis Service: $service'),
                          Text('Status: $status'),
                          Text('Masuk: $tglMasuk'),
                          if (catatan.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text('Keluhan: $catatan'),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
