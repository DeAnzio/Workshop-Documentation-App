import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:anzioworkshopapp/services/backend_service.dart';
import 'package:anzioworkshopapp/services/currency_service.dart';
import 'package:anzioworkshopapp/services/timezone_service.dart';

class PrintNotaPage extends StatefulWidget {
  final Map<String, dynamic> order;

  const PrintNotaPage({super.key, required this.order});

  @override
  State<PrintNotaPage> createState() => _PrintNotaPageState();
}

class _PrintNotaPageState extends State<PrintNotaPage> {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _loadingDetails = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _spareparts = [];
  double _sparepartTotal = 0.0;
  
  // Technician preferences
  String _preferredCurrency = 'IDR';
  String _preferredTimezone = 'WIB';
  
  // Converted values for display
  double _convertedEstimasi = 0.0;
  double _convertedBiayaAkhir = 0.0;
  double _convertedSparepartTotal = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadDetailsWithPreferences();
  }

  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _notificationsPlugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );
  }

  Future<void> _loadDetailsWithPreferences() async {
    setState(() {
      _loadingDetails = true;
      _errorMessage = null;
    });

    try {
      // Load technician preferences
      final technicianId = await BackendService.getCurrentTechnicianId();
      if (technicianId != null) {
        final technicianData = await BackendService.fetchTechnicianById(technicianId);
        if (technicianData != null) {
          _preferredCurrency = technicianData['currency']?.toString() ?? 'IDR';
          _preferredTimezone = technicianData['preferred_time']?.toString() ?? 'WIB';
        }
      }

      // Load spare parts
      final orderId = widget.order['id']?.toString() ?? '';
      var parts = await BackendService.fetchServiceSpareparts(orderId);
      var total = await BackendService.fetchServiceSparepartsTotal(orderId);
      
      // Convert values to preferred currency
      final orderCurrency = widget.order['currency']?.toString() ?? 'IDR';
      final estimasiBiaya = (widget.order['estimasi_biaya'] is num)
          ? (widget.order['estimasi_biaya'] as num).toDouble()
          : 0.0;
      final biayaAkhir = (widget.order['biaya_akhir'] is num)
          ? (widget.order['biaya_akhir'] as num).toDouble()
          : 0.0;

      _convertedEstimasi = await _convertCurrencyIfNeeded(estimasiBiaya, orderCurrency);
      _convertedBiayaAkhir = await _convertCurrencyIfNeeded(biayaAkhir, orderCurrency);
      _convertedSparepartTotal = await _convertCurrencyIfNeeded(total, orderCurrency);
      
      // Convert spare parts pricing to preferred currency
      for (var part in parts) {
        final harga = (part['harga'] is num) ? (part['harga'] as num).toDouble() : 0.0;
        part['harga_converted'] = await _convertCurrencyIfNeeded(harga, orderCurrency);
      }
      
      if (!mounted) return;
      setState(() {
        _spareparts = parts;
        _sparepartTotal = total;
        _loadingDetails = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDetails = false;
        _errorMessage = 'Gagal memuat rincian nota: $e';
      });
    }
  }

  Future<void> _savePdfToDownloads() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (Platform.isAndroid) {
        final permissionStatus = await Permission.storage.request();
        if (!permissionStatus.isGranted && !permissionStatus.isLimited) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Izin penyimpanan diperlukan untuk menyimpan nota'),
            ),
          );
          return;
        }
      }

      final bytes = await _generatePdfBytes(PdfPageFormat.a4);
      final directory = await _resolveDownloadsDirectory();
      final fileName = 'nota_${widget.order['nomor_tiket'] ?? 'service'}.pdf';
      final filePath = p.join(directory.path, fileName);
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      await _showDownloadNotification(fileName, filePath);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nota tersimpan di folder Download: $fileName'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan nota: $e')),
      );
    }
  }

  Future<Directory> _resolveDownloadsDirectory() async {
    if (Platform.isAndroid) {
      final defaultDownloads = Directory('/storage/emulated/0/Download');
      if (await defaultDownloads.exists()) {
        return defaultDownloads;
      }

      final external = await getExternalStorageDirectory();
      if (external != null) {
        final fallback = Directory(p.join(external.path, 'Download'));
        await fallback.create(recursive: true);
        return fallback;
      }
    }

    return await getApplicationDocumentsDirectory();
  }

  Future<void> _showDownloadNotification(String title, String filePath) async {
    const androidChannel = AndroidNotificationDetails(
      'download_channel',
      'Download Nota',
      channelDescription: 'Notifikasi ketika nota service telah tersimpan',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'Nota Disimpan',
    );

    final notificationDetails = NotificationDetails(
      android: androidChannel,
      iOS: const DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      id: 0,
      title: 'Nota telah diunduh',
      body: 'File nota telah tersimpan di folder Download',
      notificationDetails: notificationDetails,
      payload: filePath,
    );
  }

  String _formatDateTime(String? rawValue, {String timezone = 'WIB'}) {
    if (rawValue == null || rawValue.isEmpty) return '-';
    final parsed = DateTime.tryParse(rawValue);
    if (parsed == null) return rawValue;
    
    // Convert to technician's preferred timezone
    try {
      final convertedTime = TimeZoneService.convertToZone(timezone, parsed);
      return '${convertedTime.day.toString().padLeft(2, '0')}/${convertedTime.month.toString().padLeft(2, '0')}/${convertedTime.year} ${convertedTime.hour.toString().padLeft(2, '0')}:${convertedTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      // Fallback if timezone conversion fails
      return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year} ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
    }
  }

  String _formatCurrency(double value, String currencyCode) {
    return CurrencyService.formatCurrency(value, currencyCode);
  }

  Future<double> _convertCurrencyIfNeeded(double value, String sourceCurrency) async {
    if (sourceCurrency == _preferredCurrency) {
      return value;
    }
    try {
      return await CurrencyService.convertCurrency(value, sourceCurrency, _preferredCurrency);
    } catch (e) {
      debugPrint('Currency conversion error: $e');
      return value;
    }
  }

  pw.Widget _buildOrderDetails() {
    final customer = widget.order['customers'] as Map<String, dynamic>?;
    final customerName = customer?['nama']?.toString() ?? '-';
    final customerPhone = customer?['no_hp']?.toString() ?? '-';
    final customerAddress = customer?['alamat']?.toString() ?? '-';
    final ticketNumber = widget.order['nomor_tiket']?.toString() ?? '-';
    final jenisPerangkat = widget.order['jenis_perangkat']?.toString() ?? '-';
    final merekModel = widget.order['merek_model']?.toString() ?? '-';
    final keluhan = widget.order['keluhan']?.toString() ?? '-';
    final diagnosa = widget.order['diagnosa']?.toString() ?? '-';
    final jenisService = widget.order['jenis_service']?.toString() ?? '-';
    final statusService = widget.order['status_service']?.toString() ?? '-';
    final tanggal = _formatDateTime(widget.order['tgl_masuk']?.toString(), timezone: _preferredTimezone);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Nota Pengerjaan Service', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text('Nomor Tiket: $ticketNumber', style: pw.TextStyle(fontSize: 14)),
        pw.Text('Tanggal Masuk: $tanggal', style: pw.TextStyle(fontSize: 14)),
        pw.SizedBox(height: 12),
        pw.Text('Customer', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.Text('Nama: $customerName'),
        pw.Text('No. HP: $customerPhone'),
        pw.Text('Alamat: $customerAddress'),
        pw.SizedBox(height: 12),
        pw.Text('Detail Perangkat', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.Text('Jenis Perangkat: $jenisPerangkat'),
        pw.Text('Merek/Model: $merekModel'),
        pw.Text('Jenis Service: $jenisService'),
        pw.Text('Status Service: $statusService'),
        pw.Text('Keluhan: $keluhan'),
        pw.Text('Diagnosa: $diagnosa'),
        pw.SizedBox(height: 12),
      ],
    );
  }

  pw.Widget _buildSparepartSection(String orderCurrency) {
    if (_spareparts.isEmpty) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Sparepart', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Tidak ada sparepart yang tercatat.'),
        ],
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Sparepart', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: ['Nama', 'Kode', 'Qty', 'Harga', 'Total'],
          data: _spareparts.map((part) {
            final qty = part['qty'] ?? 0;
            final hargaConverted = (part['harga_converted'] is num) 
                ? (part['harga_converted'] as num).toDouble() 
                : 0.0;
            final total = (qty is num ? qty.toInt() : 0) * hargaConverted;
            return [
              part['nama']?.toString() ?? '-',
              part['kode']?.toString() ?? '-',
              qty.toString(),
              _formatCurrency(hargaConverted, _preferredCurrency),
              _formatCurrency(total, _preferredCurrency),
            ];
          }).toList(),
          border: pw.TableBorder.all(width: 0.5),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellAlignment: pw.Alignment.centerLeft,
          headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text('Total Sparepart: ${_formatCurrency(_convertedSparepartTotal, _preferredCurrency)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Future<Uint8List> _generatePdfBytes(PdfPageFormat format) async {
    final pdf = pw.Document();
    final orderCurrency = widget.order['currency']?.toString() ?? 'IDR';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return [
            _buildOrderDetails(),
            _buildSparepartSection(orderCurrency),
            pw.SizedBox(height: 12),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Estimasi Biaya:'),
                pw.Text(_formatCurrency(_convertedEstimasi, _preferredCurrency)),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Biaya Akhir:'),
                pw.Text(_formatCurrency(_convertedBiayaAkhir, _preferredCurrency)),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total Nota:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(
                  _formatCurrency(_convertedSparepartTotal + _convertedBiayaAkhir, _preferredCurrency),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Text('Terima kasih telah menggunakan layanan kami.', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
          ];
        },
      ),
    );

    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    final ticketNumber = widget.order['nomor_tiket']?.toString() ?? 'Nota';

    return Scaffold(
      appBar: AppBar(
        title: Text('Preview Nota - $ticketNumber'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _savePdfToDownloads,
            tooltip: 'Simpan ke Download',
          ),
        ],
      ),
      body: _loadingDetails
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : PdfPreview(
                  build: (format) => _generatePdfBytes(format),
                  allowSharing: true,
                  canChangePageFormat: false,
                  initialPageFormat: PdfPageFormat.a4,
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _savePdfToDownloads,
        icon: const Icon(Icons.download),
        label: const Text('Simpan Nota'),
      ),
    );
  }
}
