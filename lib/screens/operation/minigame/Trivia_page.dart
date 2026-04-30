import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TriviaPage extends StatefulWidget {
  const TriviaPage({super.key});

  @override
  State<TriviaPage> createState() => _TriviaPageState();
}

class _TriviaPageState extends State<TriviaPage> {
  bool _loading = false;
  bool _error = false;
  String _errorMessage = '';
  int _currentIndex = 0;
  int _score = 0;
  bool _answered = false;
  String? _selectedAnswer;
  List<TriviaQuestion> _questions = [];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _startTrivia() async {
    await _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    setState(() {
      _loading = true;
      _error = false;
      _errorMessage = '';
      _questions = [];
      _currentIndex = 0;
      _score = 0;
      _answered = false;
      _selectedAnswer = null;
    });

    try {
      final uri = Uri.parse(
        'https://opentdb.com/api.php?amount=10&category=18&encode=base64',
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final Map<String, dynamic> jsonData = json.decode(response.body);
      if (jsonData['response_code'] != 0) {
        throw Exception('TriviaDB returned code ${jsonData['response_code']}');
      }

      final results = (jsonData['results'] as List<dynamic>?) ?? [];
      if (results.isEmpty) {
        throw Exception('No questions received');
      }

      final questions = results.map((item) {
        final question = _decodeBase64(item['question'] as String);
        final correctAnswer = _decodeBase64(item['correct_answer'] as String);
        final incorrectAnswers = (item['incorrect_answers'] as List<dynamic>)
            .map((value) => _decodeBase64(value as String))
            .toList();
        final options = [...incorrectAnswers, correctAnswer]..shuffle();

        return TriviaQuestion(
          question: question,
          options: options,
          correctAnswer: correctAnswer,
          type: item['type'] as String? ?? 'multiple',
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _questions = questions;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  String _decodeBase64(String value) {
    try {
      return utf8.decode(base64.decode(value));
    } catch (_) {
      return value;
    }
  }

  void _selectAnswer(String answer) {
    if (_answered) return;
    final current = _questions[_currentIndex];
    setState(() {
      _answered = true;
      _selectedAnswer = answer;
      if (answer == current.correctAnswer) {
        _score += 1;
      }
    });
  }

  void _nextQuestion() {
    if (_currentIndex + 1 >= _questions.length) {
      _showFinalScore();
      return;
    }

    setState(() {
      _currentIndex += 1;
      _answered = false;
      _selectedAnswer = null;
    });
  }

  void _showFinalScore() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Skor Akhir'),
          content: Text('Kamu memperoleh $_score dari ${_questions.length} soal.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _startTrivia();
              },
              child: const Text('Main Lagi'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Trivia Quiz',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF080E1A),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Terjadi kesalahan saat memuat soal.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.black54),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: _startTrivia,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color.fromARGB(255, 26, 41, 67),
                                  minimumSize: const Size(160, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Muat Ulang'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : _questions.isEmpty
                    ? Center(
                        child: ElevatedButton(
                          onPressed: _startTrivia,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromARGB(255, 26, 41, 67),
                            minimumSize: const Size(200, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Mulai Trivia'),
                        ),
                      )
                    : _buildQuestionView(),
      ),
    );
  }

  Widget _buildQuestionView() {
    final question = _questions[_currentIndex];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Chip(
                label: Text(
                  'Soal ${_currentIndex + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                backgroundColor: Colors.blue.shade50,
              ),
              Chip(
                label: Text(
                  'Skor: $_score',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                backgroundColor: Colors.green.shade50,
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: (_currentIndex + 1) / _questions.length,
            minHeight: 8,
            color: const Color.fromARGB(255, 26, 41, 67),
            backgroundColor: Colors.grey.shade300,
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.question_answer,
                          color: Color.fromARGB(255, 26, 41, 67)),
                      const SizedBox(width: 8),
                      Text(
                        question.type == 'boolean'
                            ? 'Benar / Salah'
                            : 'Pilihan Ganda',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    question.question,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: question.options.length,
              padding: EdgeInsets.zero,
              itemBuilder: (context, index) {
                final option = question.options[index];
                final isCorrect = option == question.correctAnswer;
                final isSelected = option == _selectedAnswer;
                Color backgroundColor = Colors.white;
                Color textColor = Colors.black87;
                BorderSide borderSide = const BorderSide(color: Colors.black12);
                if (_answered) {
                  if (isSelected) {
                    backgroundColor =
                        isCorrect ? Colors.green.shade200 : Colors.red.shade200;
                    textColor = Colors.black87;
                  } else if (isCorrect) {
                    backgroundColor = Colors.green.shade100;
                  }
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: ElevatedButton(
                    onPressed: () => _selectAnswer(option),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: backgroundColor,
                      foregroundColor: textColor,
                      elevation: 0,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                          vertical: 18, horizontal: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: borderSide,
                      ),
                    ),
                    child: Text(
                      option,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _answered ? _nextQuestion : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 26, 41, 67),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              _currentIndex + 1 < _questions.length ? 'Berikutnya' : 'Selesai',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class TriviaQuestion {
  final String question;
  final List<String> options;
  final String correctAnswer;
  final String type;

  TriviaQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.type,
  });
}
