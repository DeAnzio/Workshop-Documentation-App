import 'package:flutter/material.dart';
import 'package:anzioworkshopapp/services/backend_service.dart';

class KesanPesanPage extends StatefulWidget {
  const KesanPesanPage({super.key});

  @override
  State<KesanPesanPage> createState() => _KesanPesanPageState();
}

class _KesanPesanPageState extends State<KesanPesanPage> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = true;
  String _savedFeedback = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFeedback();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadFeedback() async {
    final technicianId = await BackendService.getCurrentTechnicianId();
    if (technicianId == null) {
      setState(() {
        _error = 'Teknisi belum login.';
        _isLoading = false;
      });
      return;
    }

    final data = await BackendService.fetchTechnicianById(technicianId);
    setState(() {
      _savedFeedback = data?['kesanpesan']?.toString() ?? '';
      _controller.text = _savedFeedback;
      _isLoading = false;
    });
  }

  Future<void> _saveFeedback() async {
    final technicianId = await BackendService.getCurrentTechnicianId();
    if (technicianId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Teknisi belum login.')));
      return;
    }

    final feedback = _controller.text.trim();
    if (feedback.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Isi kolom kesan dan pesan terlebih dahulu.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final saved = await BackendService.saveTechnicianFeedback(
      technicianId,
      feedback,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (saved) {
        _savedFeedback = feedback;
        _error = null;
      } else {
        _error = 'Gagal menyimpan kesan dan pesan. Coba lagi.';
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Kesan dan pesan berhasil disimpan.'
              : 'Gagal menyimpan kesan dan pesan.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kesan & Pesan')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    maxLines: 5,
                    maxLength: 1000,
                    decoration: InputDecoration(
                      labelText: 'Kesan & Pesan',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _saveFeedback,
                    child: const Text('Simpan'),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Sudah tersimpan:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _savedFeedback.isEmpty
                      ? const Text('Belum ada kesan dan pesan yang tersimpan.')
                      : Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            _savedFeedback,
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
      ),
    );
  }
}
