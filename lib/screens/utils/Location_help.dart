import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationHelp {
  LocationHelp._();

  static Future<bool> checkAndRequestLocationService(
    BuildContext context,
  ) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('GPS Tidak Aktif'),
                content: const Text(
                  'Untuk menggunakan fitur lokasi, GPS pada perangkat Anda harus diaktifkan. '
                  'Apakah Anda ingin membuka pengaturan untuk mengaktifkan GPS?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Batal'),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.of(context).pop(true);
                      // Buka pengaturan lokasi
                      await Geolocator.openLocationSettings();
                    },
                    child: const Text('Buka Pengaturan'),
                  ),
                ],
              );
            },
          ) ??
          false;
    }
    return true;
  }

  static Future<bool> checkAndRequestLocationPermission(
    BuildContext context,
  ) async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (permission == LocationPermission.deniedForever) {
        // Tampilkan dialog untuk membuka pengaturan aplikasi
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Izin Lokasi Diperlukan'),
              content: const Text(
                'Aplikasi memerlukan izin lokasi untuk berfungsi dengan baik. '
                'Silakan buka pengaturan aplikasi dan berikan izin lokasi.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await Geolocator.openAppSettings();
                  },
                  child: const Text('Buka Pengaturan'),
                ),
              ],
            );
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Izin lokasi diperlukan untuk fitur ini'),
          ),
        );
      }
      return false;
    }
    return true;
  }

  static Future<LatLng?> getCurrentLocationWithChecks(
    BuildContext context,
  ) async {
    // Cek apakah GPS aktif
    final gpsEnabled = await checkAndRequestLocationService(context);
    if (!gpsEnabled) {
      return null;
    }

    // Cek dan minta izin lokasi
    final permissionGranted = await checkAndRequestLocationPermission(context);
    if (!permissionGranted) {
      return null;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mendapatkan lokasi: $e')));
      return null;
    }
  }

  static Future<String> getAddressFromCoordinates(LatLng coordinates) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        coordinates.latitude,
        coordinates.longitude,
      );

      if (placemarks.isEmpty) {
        return '${coordinates.latitude}, ${coordinates.longitude}';
      }

      final place = placemarks.first;
      final parts = [
        place.street,
        place.subLocality,
        place.locality,
        place.subAdministrativeArea,
        place.administrativeArea,
        place.postalCode,
      ];
      final address = parts
          .where((element) => element != null && element.isNotEmpty)
          .join(', ');

      return address.isNotEmpty
          ? address
          : '${coordinates.latitude}, ${coordinates.longitude}';
    } catch (_) {
      return '${coordinates.latitude}, ${coordinates.longitude}';
    }
  }

  static Future<String?> openLocationPicker(
    BuildContext context,
    String initialAddress,
  ) async {
    // Try to get current location, fallback to default Jakarta coordinates
    LatLng initialCenter = const LatLng(-6.200000, 106.816666);
    try {
      final currentLocation = await getCurrentLocationWithChecks(context);
      if (currentLocation != null) {
        initialCenter = currentLocation;
      }
    } catch (_) {
      // Use default coordinates if location retrieval fails
    }

    LatLng selectedPoint = initialCenter;
    String selectedAddress = initialAddress.isNotEmpty
        ? initialAddress
        : 'Tap di peta untuk menjatuhkan pin';
    bool isAddressLoading = false;

    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Pilih Lokasi Pelanggan'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.maxFinite,
                  height: 320,
                  child: FlutterMap(
                    options: MapOptions(
                      center: initialCenter,
                      zoom: 14,
                      onTap: (tapPos, latlng) async {
                        setState(() {
                          selectedPoint = latlng;
                          isAddressLoading = true;
                        });
                        final address = await getAddressFromCoordinates(latlng);
                        setState(() {
                          selectedAddress = address;
                          isAddressLoading = false;
                        });
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c'],
                        userAgentPackageName: 'com.anzioworkshopapp',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            width: 40,
                            height: 40,
                            point: selectedPoint,
                            builder: (context) => const Icon(
                              Icons.location_pin,
                              size: 40,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (isAddressLoading)
                  const CircularProgressIndicator()
                else
                  Text(
                    selectedAddress,
                    style: const TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(selectedAddress),
                child: const Text('Pilih Lokasi'),
              ),
            ],
          );
        },
      ),
    );
  }

  static Future<void> openInGoogleMaps(
    String address,
    BuildContext context,
  ) async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': address,
    });

    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka Google Maps.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal membuka Google Maps: $e')));
    }
  }

  static Future<void> searchNearbyComputerStores(BuildContext context) async {
    try {
      final uri = Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': 'toko sparepart komputer near me',
      });

      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka Google Maps.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mencari toko sparepart: $e')),
      );
    }
  }
}
