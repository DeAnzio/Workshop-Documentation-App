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
      if (!mounted) return;
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
          .from('CustomerData')
          .select()
          .eq('id_technician', techId)
          .order('id', ascending: false);

      final list = List<Map<String, dynamic>>.from(
        (res as List<dynamic>).map((item) => Map<String, dynamic>.from(item as Map)),
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
                          final nama = item['nama_pelanggan']?.toString() ?? '-';
                          final jenis = item['jenis_device']?.toString() ?? '-';
                          final merek = item['merek_model']?.toString() ?? '-';
                          final service = item['service_type']?.toString() ?? '-';
                          final noHp = item['no_hp']?.toString() ?? '-';
                          final catatan = item['catatan']?.toString() ?? '';

                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(nama, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  Text('No. HP: $noHp'),
                                  const SizedBox(height: 4),
                                  Text('Device: $jenis'),
                                  const SizedBox(height: 4),
                                  Text('Merek/Model: $merek'),
                                  const SizedBox(height: 4),
                                  Text('Service: $service'),
                                  if (catatan.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text('Catatan: $catatan'),
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
