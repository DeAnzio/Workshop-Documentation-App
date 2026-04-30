import 'dart:io';

import 'package:flutter/material.dart';
import 'package:anzioworkshopapp/services/backend_service.dart';
import 'package:anzioworkshopapp/screens/operation/inputtiket_page.dart';

class HomeScaffold extends StatefulWidget {
  const HomeScaffold({super.key});

  @override
  State<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends State<HomeScaffold> {
  int _selectedIndex = 0;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final userId = await BackendService.currentUserId;
    if (userId != null) {
      final technicianData = await BackendService.fetchTechnicianById(userId);
      if (technicianData != null && technicianData['avatar_url'] != null) {
        setState(() {
          _avatarUrl = technicianData['avatar_url'];
        });
      }
    }
  }

  Future<void> _logout(BuildContext context) async {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);

                try {
                  await BackendService.signOut();

                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Logged out successfully')),
                  );

                  // Navigate back to login immediately
                  Navigator.pushReplacementNamed(context, '/login');
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Logout error: $e')));
                }
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _onItemTapped(int index) async {
    setState(() {
      _selectedIndex = index;
    });
    switch (index) {
      case 0:
        // Profil
        await Navigator.pushNamed(context, '/profile');
        await _loadAvatar();
        break;
      case 1:
        // Kesan dan Pesan
        await Navigator.pushNamed(context, '/kesan-pesan');
        await _loadAvatar();
        break;
      case 2:
        // Logout
        _logout(context);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Inputdata()),
                );
              },
              child: const Text('Input Tiket'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/list-tiket');
              },
              child: const Text('Lihat Tiket'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/history');
              },
              child: const Text('History'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/sps-locator');
              },
              child: const Text('SPS Locator'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/askme');
              },
              child: const Text('Chatbot'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/minigame');
              },
              child: const Text('Mini Games'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: CircleAvatar(
              backgroundImage: _avatarUrl != null
                  ? (_avatarUrl!.startsWith('/') ||
                                _avatarUrl!.startsWith('file://')
                            ? FileImage(
                                File(_avatarUrl!.replaceFirst('file://', '')),
                              )
                            : NetworkImage(_avatarUrl!))
                        as ImageProvider?
                  : null,
              radius: 15,
              child: _avatarUrl == null
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
            label: 'Profil',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.feedback),
            label: 'Kesan Pesan',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.logout),
            label: 'Logout',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}
