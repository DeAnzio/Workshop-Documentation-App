import 'package:flutter/material.dart';
import 'package:anzioworkshopapp/screens/utils/Location_help.dart';
import 'package:anzioworkshopapp/services/backend_service.dart';
import 'package:anzioworkshopapp/screens/operation/edittiket_page.dart';

class ListTiketPage extends StatefulWidget {
  const ListTiketPage({super.key});

  @override
  State<ListTiketPage> createState() => _ListTiketPageState();
}

class _ListTiketPageState extends State<ListTiketPage> {
  bool _loading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _tiketList = [];
  List<Map<String, dynamic>> _filteredTiketList = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterTiketList);
    _loadTiket();
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterTiketList);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTiket() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final valid = await BackendService.validateSession();
    if (!mounted) return;
    if (!valid) {
      final sessionExpired = await BackendService.isSessionExpired;
      Navigator.pushReplacementNamed(
        context,
        sessionExpired ? '/verify' : '/login',
      );
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
        excludeFinished: true,
      );

      setState(() {
        _tiketList = list;
        _filterTiketList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = 'Gagal memuat tiket: $e';
      });
    }
  }

  Future<void> _deleteTiket(String tiketId) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Hapus Tiket'),
          content: const Text('Apakah Anda yakin ingin menghapus tiket ini?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  final success = await BackendService.deleteServiceOrder(
                    tiketId,
                  );
                  if (!mounted) return;
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tiket berhasil dihapus')),
                    );
                    await _loadTiket();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Gagal menghapus tiket')),
                    );
                  }
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Hapus', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _filterTiketList() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      _filteredTiketList = List<Map<String, dynamic>>.from(_tiketList);
    } else {
      _filteredTiketList = _tiketList.where((item) {
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
        title: const Text('Daftar Tiket'),
        backgroundColor: const Color.fromARGB(255, 26, 41, 67),
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
                                  _filterTiketList();
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (_) => setState(_filterTiketList),
                  ),
                ),
                Expanded(
                  child: _tiketList.isEmpty
                      ? const Center(child: Text('Belum ada tiket.'))
                      : _filteredTiketList.isEmpty
                          ? const Center(child: Text('Tidak ada tiket yang cocok.'))
                          : RefreshIndicator(
                              onRefresh: _loadTiket,
                              child: ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: _filteredTiketList.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final item = _filteredTiketList[index];
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

                                  final tiketId = item['id']?.toString() ?? '';
                                  final ticket = item['nomor_tiket']?.toString() ?? '-';
                                  final jenis = item['jenis_perangkat']?.toString() ?? '-';
                                  final merek = item['merek_model']?.toString() ?? '-';
                                  final service = item['jenis_service']?.toString() ?? '-';
                                  final status = item['status_service']?.toString() ?? '-';
                                  final catatan = item['keluhan']?.toString() ?? '';
                                  final tglMasuk = item['tgl_masuk']?.toString() ?? '-';
                                  final alamat = customerData is Map<String, dynamic>
                                      ? customerData['alamat']?.toString() ?? ''
                                      : customerData is List && customerData.isNotEmpty
                                          ? (customerData.first['alamat']?.toString() ?? '')
                                          : '';

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
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                ticket,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.edit,
                                                      color: Colors.blue,
                                                    ),
                                                    onPressed: () async {
                                                      final result = await Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) =>
                                                              EditTiketPage(tiketData: item),
                                                        ),
                                                      );
                                                      if (result == true) {
                                                        await _loadTiket();
                                                      }
                                                    },
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.delete,
                                                      color: Colors.red,
                                                    ),
                                                    onPressed: () => _deleteTiket(tiketId),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text('Nama: $nama'),
                                          Text('No. HP: $noHp'),
                                          Text('Device: $jenis'),
                                          Text('Merek/Model: $merek'),
                                          Text('Jenis Service: $service'),
                                          Text('Status: $status'),
                                          Text('Masuk: $tglMasuk'),
                                          if (alamat.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Expanded(child: Text('Alamat: $alamat')),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.map,
                                                    color: Colors.blue,
                                                  ),
                                                  tooltip: 'Buka di Google Maps',
                                                  onPressed: () {
                                                    LocationHelp.openInGoogleMaps(
                                                      alamat,
                                                      context,
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ],
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
                ),
              ],
            ),
    );
  }
}

