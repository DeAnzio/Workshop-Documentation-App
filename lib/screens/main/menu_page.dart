import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:anzioworkshopapp/services/backend_service.dart';
import 'package:anzioworkshopapp/services/timezone_service.dart';
import 'package:anzioworkshopapp/screens/operation/inputtiket_page.dart';

class MenuItemData {
  final String emoji;
  final String title;
  final String description;
  final String badge;
  final Color accentColor;
  final Color bgColor;
  final Color cardColor;
  final Color badgeTextColor;
  final VoidCallback? onTap;

  const MenuItemData({
    required this.emoji,
    required this.title,
    required this.description,
    required this.badge,
    required this.accentColor,
    required this.bgColor,
    required this.cardColor,
    required this.badgeTextColor,
    this.onTap,
  });
}

class HomeScaffold extends StatefulWidget {
  const HomeScaffold({super.key});

  @override
  State<HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends State<HomeScaffold> {
  int _selectedIndex = 0;
  String? _avatarUrl;
  String? _technicianName;
  String _preferredTimeZone = 'WIB';
  int _unfinishedTicketCount = 0;
  Timer? _liveTimeTimer;

  String get _currentTime => TimeZoneService.formatZoneTime(_preferredTimeZone);

  List<MenuItemData> get _menuItems => [
        MenuItemData(
          emoji: '🎟️',
          title: 'Input Tiket',
          description: 'Catat tiket baru masuk',
          badge: 'Buat Baru',
          accentColor: const Color(0xFF00C6A2),
          bgColor: const Color(0xFF00C6A2).withOpacity(0.12),
          cardColor: const Color(0xFF111C30),
          badgeTextColor: const Color(0xFF00C6A2),
          onTap: () async {
            await Navigator.pushNamed(context, '/input-tiket');
            await _loadProfileSummary();
          },
        ),
        MenuItemData(
          emoji: '📋',
          title: 'Lihat Tiket',
          description: 'Monitor tiket aktif',
          badge: '$_unfinishedTicketCount Aktif',
          accentColor: const Color(0xFF0077FF),
          bgColor: const Color(0xFF0077FF).withOpacity(0.12),
          cardColor: const Color(0xFF111C30),
          badgeTextColor: const Color(0xFF0077FF),
          onTap: () async {
            await Navigator.pushNamed(context, '/list-tiket');
            await _loadProfileSummary();
          },
        ),
        MenuItemData(
          emoji: '🗂️',
          title: 'History',
          description: 'Riwayat tiket selesai',
          badge: 'Riwayat',
          accentColor: const Color(0xFFF5A623),
          bgColor: const Color(0xFFF5A623).withOpacity(0.12),
          cardColor: const Color(0xFF111C30),
          badgeTextColor: const Color(0xFFF5A623),
          onTap: () async {
            await Navigator.pushNamed(context, '/history');
            await _loadProfileSummary();
          },
        ),
        MenuItemData(
          emoji: '🤖',
          title: 'AskMe AI',
          description: 'Asisten cerdas teknisi',
          badge: 'Chat AI',
          accentColor: const Color(0xFF8B5CF6),
          bgColor: const Color(0xFF8B5CF6).withOpacity(0.12),
          cardColor: const Color(0xFF111C30),
          badgeTextColor: const Color(0xFFA78BFA),
          onTap: () async {
            await Navigator.pushNamed(context, '/askme');
            await _loadProfileSummary();
          },
        ),
        MenuItemData(
          emoji: '📍',
          title: 'SPS Locator',
          description: 'Temukan lokasi Spare Part Store terdekat',
          badge: '',
          accentColor: const Color(0xFFF06060),
          bgColor: const Color(0xFFF06060).withOpacity(0.12),
          cardColor: const Color(0xFF111C30),
          badgeTextColor: const Color(0xFFF87171),
          onTap: () async {
            await Navigator.pushNamed(context, '/sps-locator');
            await _loadProfileSummary();
          },
        ),
        MenuItemData(
          emoji: '🎮',
          title: 'Minigame',
          description: 'Hiburan saat istirahat',
          badge: '2 Game',
          accentColor: const Color(0xFF3DD68C),
          bgColor: const Color(0xFF3DD68C).withOpacity(0.12),
          cardColor: const Color(0xFF111C30),
          badgeTextColor: const Color(0xFF3DD68C),
          onTap: () async {
            await Navigator.pushNamed(context, '/minigame');
            await _loadProfileSummary();
          },
        ),
      ];

  @override
  void initState() {
    super.initState();
    _loadProfileSummary();
    _liveTimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _liveTimeTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProfileSummary() async {
    final userId = await BackendService.currentUserId;
    if (userId == null) return;

    final technicianData = await BackendService.fetchTechnicianById(userId);
    final unfinishedOrders =
        await BackendService.fetchServiceOrdersForTechnician(userId);

    if (!mounted) return;

    if (technicianData != null) {
      final savedTimeZone = technicianData['preferred_time']?.toString();
      final selectedTimeZone = (savedTimeZone != null && TimeZoneService.isValidTimeZone(savedTimeZone))
          ? savedTimeZone
          : 'WIB';
      setState(() {
        _avatarUrl = technicianData['avatar_url']?.toString();
        _technicianName = technicianData['name']?.toString() ?? 'Teknisi';
        _preferredTimeZone = selectedTimeZone;
        _unfinishedTicketCount = unfinishedOrders.length;
      });
    } else {
      setState(() {
        _unfinishedTicketCount = unfinishedOrders.length;
      });
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
        await _loadProfileSummary();
        break;
      case 1:
        // Kesan dan Pesan
        await Navigator.pushNamed(context, '/kesan-pesan');
        await _loadProfileSummary();
        break;
      case 2:
        // Logout
        _logout(context);
        break;
    }
  }

  Widget _buildStatCard({
    required String icon,
    required String label,
    required String value,
    required Color valueColor,
    required Color iconBg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Color.fromARGB(255, 60, 89, 100),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 16))),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Colors.white.withOpacity(0.4),
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  Widget _buildMenuCard(MenuItemData item) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: item.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 0.5,
          ),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 16,
              right: 16,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: item.accentColor,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(2),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: item.bgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        item.emoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.description,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.45),
                      height: 1.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: item.accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      item.badge,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: item.badgeTextColor,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080E1A),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: const Color(0xFF111C30),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selamat datang,',
                            style: TextStyle(
                              fontSize: 12,
                              color: const Color.fromARGB(255, 231, 236, 242).withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                _technicianName ?? 'Teknisi',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFFFFFFF),
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(width: 4),
                              
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: '🎫',
                          label: 'Tiket Aktif',
                          value: _unfinishedTicketCount.toString(),
                          valueColor: const Color(0xFF00C6A2),
                          iconBg: const Color(0xFF00C6A2).withOpacity(0.15),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatCard(
                          icon: '🕐',
                          label: 'Waktu sekarang',
                          value: _currentTime,
                          valueColor: const Color(0xFF3B82F6),
                          iconBg: const Color(0xFF0077FF).withOpacity(0.15),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _buildSectionLabel('Menu Utama'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.05,
                    ),
                    itemCount: _menuItems.length,
                    itemBuilder: (context, index) => _buildMenuCard(_menuItems[index]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF111C30),
        showSelectedLabels: true,
        showUnselectedLabels: true,
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
            label: 'Profile',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.feedback),
            label: 'Kesan Pesan',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.logout),
            label: 'Logout',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.white70,
        onTap: _onItemTapped,
      ),
    );
  }
}
