import 'package:flutter/material.dart';
import 'package:anzioworkshopapp/screens/operation/printnota.dart';
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
  List<Map<String, dynamic>> _filteredHistory = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterHistory);
    _loadHistory();
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterHistory);
    _searchController.dispose();
    super.dispose();
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
      if (!mounted) return;
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
        _filterHistory();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = 'Gagal memuat riwayat: $e';
      });
    }
  }

  void _filterHistory() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      _filteredHistory = List<Map<String, dynamic>>.from(_history);
    } else {
      _filteredHistory = _history.where((item) {
        final id = item['id']?.toString().toLowerCase() ?? '';
        final ticket = item['nomor_tiket']?.toString().toLowerCase() ?? '';
        final customerData = item['customers'];
        String nama = '';
        String noHp = '';
        if (customerData is Map<String, dynamic>) {
          nama = customerData['nama']?.toString().toLowerCase() ?? '';
          noHp = customerData['no_hp']?.toString().toLowerCase() ?? '';
        } else if (customerData is List && customerData.isNotEmpty) {
          final customer = Map<String, dynamic>.from(customerData.first as Map);
          nama = customer['nama']?.toString().toLowerCase() ?? '';
          noHp = customer['no_hp']?.toString().toLowerCase() ?? '';
        }
        return id.contains(query) ||
            ticket.contains(query) ||
            nama.contains(query) ||
            noHp.contains(query);
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'History Tiket',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF080E1A),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Cari UUID, Nama Customer, atau No HP',
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _filterHistory();
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (_) => setState(_filterHistory),
                  ),
                ),
                Expanded(
                  child: _history.isEmpty
                      ? const Center(child: Text('Belum ada riwayat service.'))
                      : _filteredHistory.isEmpty
                          ? const Center(child: Text('Tidak ada tiket yang cocok.'))
                          : RefreshIndicator(
                              onRefresh: _loadHistory,
                              child: ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: _filteredHistory.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final item = _filteredHistory[index];
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
                                          const SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              ElevatedButton.icon(
                                                onPressed: (status.toLowerCase() == 'selesai' || status.toLowerCase() == 'ambil')
                                                    ? () {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (_) => PrintNotaPage(order: item),
                                                          ),
                                                        );
                                                      }
                                                    : null,
                                                icon: const Icon(Icons.receipt_long),
                                                label: const Text('Cetak Nota'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),
    );
  }
}
