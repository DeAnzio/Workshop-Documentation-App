import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AskMe extends StatefulWidget {
  const AskMe({super.key});

  @override
  State<AskMe> createState() => _AskMeState();
}

class _AskMeState extends State<AskMe> {
  final TextEditingController controller = TextEditingController();

  String get apiKey => dotenv.env['GOOGLE_API_KEY'] ?? '';

  List<Map<String, String>> messages = [
    {"role": "assistant", "content": "Halo! Gemini siap bantu kamu 🚀"},
  ];

  bool isLoading = false;

  Future<void> sendMessage() async {
    if (controller.text.trim().isEmpty) return;
    if (apiKey.isEmpty) {
      setState(() {
        messages.add({
          "role": "assistant",
          "content":
              "API key tidak ditemukan. Silakan atur GOOGLE_API_KEY di file .env.",
        });
      });
      return;
    }

    String userText = controller.text;

    setState(() {
      messages.add({"role": "user", "content": userText});
      isLoading = true;
    });

    controller.clear();

    try {
      final url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=$apiKey",
      );

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [
            {
              "role": "user",
              "parts": [
                {"text": userText},
              ],
            },
          ],
          "generationConfig": {"temperature": 0.1, "maxOutputTokens": 1000},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        String reply =
            data["candidates"]?[0]?["content"]?["parts"]?[0]?["text"] ??
            "AI tidak memberi respon";

        setState(() {
          messages.add({"role": "assistant", "content": reply});
        });
      } else {
        setState(() {
          messages.add({
            "role": "assistant",
            "content": "Error ${response.statusCode}\n${response.body}",
          });
        });
      }
    } catch (e) {
      setState(() {
        messages.add({"role": "assistant", "content": "Error: $e"});
      });
    }

    setState(() {
      isLoading = false;
    });
  }

  Widget buildMessage(Map<String, String> msg) {
    final isUser = msg["role"] == "user";

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          msg["content"] ?? "",
          style: TextStyle(color: isUser ? Colors.white : Colors.black),
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Widget buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: "Tulis pertanyaan...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.blue),
            onPressed: sendMessage,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget buildHeader() {
    return AppBar(
      iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'AI Chat',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF080E1A),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildHeader(),
      body: Column(
        children: [
          Expanded(
            child: ListView(children: messages.map(buildMessage).toList()),
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            ),
          buildInputArea(),
        ],
      ),
    );
  }
}
