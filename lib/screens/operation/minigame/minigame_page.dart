import 'package:flutter/material.dart';

class MiniGamePage extends StatelessWidget {
  const MiniGamePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Mini Games',
          style: TextStyle(color: Color.fromARGB(255, 255, 255, 255)),
        ),
        backgroundColor: const Color(0xFF080E1A),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Pilih Game',
                style: TextStyle(
                  color: Color.fromARGB(255, 106, 139, 179),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: const Color.fromARGB(255, 26, 41, 67),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.quiz),
                label: const Text('Trivia Game', style: TextStyle(color: Color.fromARGB(255, 233, 239, 246)),),
                onPressed: () {
                  Navigator.pushNamed(context, '/trivia');
                },
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: const Color.fromARGB(255, 26, 41, 67),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.sports_esports),
                label: const Text('AI Shooter', style: TextStyle(color: Color.fromARGB(255, 233, 239, 246)),),
                onPressed: () {
                  Navigator.pushNamed(context, '/space-shooter');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
