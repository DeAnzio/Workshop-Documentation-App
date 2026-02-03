import 'package:flutter/material.dart';
import 'package:anzioworkshopapp/inputdata.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Coba-Coba Flutter',
      home: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Anzio WorkShop',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
              letterSpacing: 1.5,
            ),
          ),
          backgroundColor: const Color.fromARGB(255, 26, 41, 67),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,  // Posisi di tengah vertikal
            children: [
              Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const Inputdata(),
                        ),
                      );
                    },
                    child: const Text('Add Service'),
                  );
                },
              ),
              const SizedBox(height: 10),  // Jarak antar button
              ElevatedButton(
                onPressed: () {
                  // Aksi button 2
                  print('Button 2 ditekan');
                },
                child: const Text('History'),
              ),
              const SizedBox(height: 10),  // Jarak antar button
            ],
          ),
        ),
      ),
    );
  }
}