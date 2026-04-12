import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:anzioworkshopapp/services/supabase_service.dart';

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
          .from('service_orders')
          .select('*, customers(*)')
          .eq('technician_id', techId)
          .order('tgl_masuk', ascending: false);

      final list = List<Map<String, dynamic>>.from(
        (res as List<dynamic>).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
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
                separatorBuilder: (_, __) => const SizedBox(height: 12),
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
