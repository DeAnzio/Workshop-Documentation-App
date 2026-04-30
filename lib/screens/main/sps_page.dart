import 'package:flutter/material.dart';
import 'package:anzioworkshopapp/screens/utils/Location_help.dart';

class SpsPage extends StatefulWidget {
  const SpsPage({super.key});

  @override
  State<SpsPage> createState() => _SpsPageState();
}

class _SpsPageState extends State<SpsPage> {
  bool _isLoading = false;
  String? _currentLocation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Cari Sparepart Shop',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF080E1A),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cari Computer Sparepart Shop Terdekat',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Current location display
            if (_currentLocation != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Lokasi: $_currentLocation',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _getCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Dapatkan Lokasi'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_currentLocation == null || _isLoading)
                        ? null
                        : _searchNearbyStores,
                    icon: const Icon(Icons.search),
                    label: const Text('Cari Toko'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Loading indicator
            if (_isLoading)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Membuka Google Maps...'),
                  ],
                ),
              )
            else ...[
              const Center(
                child: Text(
                  'Tekan "Cari Toko" untuk mencari toko sparepart komputer terdekat di Google Maps',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current location with GPS and permission checks
      final currentLocation = await LocationHelp.getCurrentLocationWithChecks(
        context,
      );

      if (currentLocation == null) {
        // Location retrieval was cancelled or failed
        return;
      }

      // Get address from coordinates
      final address = await LocationHelp.getAddressFromCoordinates(
        currentLocation,
      );

      setState(() {
        _currentLocation = address;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lokasi berhasil didapatkan')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mendapatkan lokasi: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _searchNearbyStores() async {
    if (_currentLocation == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Open Google Maps with search for computer spare parts stores
      await LocationHelp.searchNearbyComputerStores(context);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Membuka Google Maps untuk pencarian toko sparepart'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mencari toko: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

