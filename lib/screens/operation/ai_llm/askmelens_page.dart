import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'description_page.dart';

class AskMeLens extends StatefulWidget {
  const AskMeLens({super.key});

  @override
  State<AskMeLens> createState() => _AskMeLensState();
}

class _AskMeLensState extends State<AskMeLens> {
  List<CameraDescription>? cameras;
  CameraController? controller;
  bool isInitialized = false;
  bool isAnalyzing = false;
  bool isTorchOn = false;

  String get apiKey => dotenv.env['GOOGLE_API_KEY'] ?? '';

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  Future<void> initializeCamera() async {
    cameras = await availableCameras();
    if (cameras!.isNotEmpty) {
      controller = CameraController(cameras![0], ResolutionPreset.medium);
      await controller!.initialize();
      setState(() {
        isInitialized = true;
      });
    }
  }

  Future<void> captureAndAnalyze() async {
    if (!isInitialized || controller == null) return;

    setState(() {
      isAnalyzing = true;
    });

    try {
      final XFile file = await controller!.takePicture();
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      final url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=$apiKey",
      );

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "systemInstruction": {
            "parts": [
              {
                "text": """Kamu adalah asisten untuk mengidentifikasi part komputer dan laptop dari gambar.
                Berikan identifikasi yang akurat: nama part, deskripsi, dan fungsi utama.
                Jika bukan part komputer/laptop, katakan bahwa gambar tidak mengandung part yang dikenali."""
              }
            ]
          },
          "contents": [
            {
              "parts": [
                {
                  "text": "Identifikasi part PC atau laptop dari gambar ini. Berikan nama part, deskripsi singkat, dan fungsi utamanya."
                },
                {
                  "inlineData": {
                    "mimeType": "image/jpeg",
                    "data": base64Image
                  }
                }
              ]
            }
          ],
          "generationConfig": {"temperature": 0.1, "maxOutputTokens": 500},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String reply = data["candidates"]?[0]?["content"]?["parts"]?[0]?["text"] ?? "Tidak dapat mengidentifikasi part.";
        
        setState(() {
          isAnalyzing = false;
        });
        
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DescriptionPage(description: reply),
            ),
          );
        }
      } else {
        String errorMessage = "Error ${response.statusCode}: ${response.body}";
        setState(() {
          isAnalyzing = false;
        });
        
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DescriptionPage(description: errorMessage),
            ),
          );
        }
      }
    } catch (e) {
      String errorMessage = "Error: $e";
      setState(() {
        isAnalyzing = false;
      });
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DescriptionPage(description: errorMessage),
          ),
        );
      }
    }
  }

  Future<void> toggleFlash() async {
    if (!isInitialized || controller == null) return;

    try {
      final newMode = isTorchOn ? FlashMode.off : FlashMode.torch;
      await controller!.setFlashMode(newMode);
      setState(() {
        isTorchOn = !isTorchOn;
      });
    } catch (e) {
      // Some devices may not support torch mode; ignore failures gracefully.
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'AI Lens - Identifikasi Part',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF080E1A),
      ),
      body: Column(
        children: [
          Expanded(
            child: isInitialized
                ? CameraPreview(controller!)
                : const Center(child: CircularProgressIndicator()),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isAnalyzing ? null : captureAndAnalyze,
                        child: isAnalyzing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Ambil Foto & Identifikasi'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: isInitialized ? toggleFlash : null,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isTorchOn ? const Color(0xFF080E1A) : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isTorchOn ? Icons.flash_on : Icons.flash_off,
                          color: isTorchOn ? Colors.white : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isTorchOn ? 'Flash menyala' : 'Flash mati',
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}