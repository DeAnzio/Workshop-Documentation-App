import 'package:flutter/material.dart';
import 'package:anzioworkshopapp/screens/operation/ai_llm/askmechat_page.dart';
import 'package:anzioworkshopapp/screens/operation/ai_llm/askmelens_page.dart';

class AskMenu extends StatelessWidget {
  const AskMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'AskMe AI Menu',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF080E1A),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AskMe()),
                );
              },
              child: const Text('AI Chat'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AskMeLens()),
                );
              },
              child: const Text('AI Lens - Identifikasi Part'),
            ),
          ],
        ),
      ),
    );
  }
}