import 'package:flutter/material.dart';

import 'models/question.dart';
import 'services/trivia_service.dart';

void main() {
  runApp(const TriviaShowdownApp());
}

class TriviaShowdownApp extends StatelessWidget {
  final TriviaService? service;
  const TriviaShowdownApp({super.key, this.service});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'API-to-Cloud Trivia Showdown',
      theme: ThemeData(primarySwatch: Colors.deepOrange),
      home: TriviaShowdownScreen(service: service ?? TriviaService()),
    );
  }
}

class TriviaShowdownScreen extends StatefulWidget {
  final TriviaService service;
  const TriviaShowdownScreen({super.key, required this.service});

  @override
  State<TriviaShowdownScreen> createState() => _TriviaShowdownScreenState();
}

class _TriviaShowdownScreenState extends State<TriviaShowdownScreen> {
  List<Question> _questions = [];
  bool _isLoading = true;
  String _error = '';
  int _currentIndex = 0;
  int _score = 0;
  bool _answered = false;
  String? _selectedOption;
  bool _isSynced = false;
  bool _isSyncing = false;
  int _roundId = 0;

  @override
  void initState() {
    super.initState();
    _loadTriviaData();
  }

  Future<void> _loadTriviaData() async {
    final roundId = _roundId;
    try {
      final questions = await widget.service.fetchQuestions();
      if (!mounted || roundId != _roundId) return;
      setState(() {
        _questions = questions;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || roundId != _roundId) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _answerQuestion(String option) {
    if (_answered) return; // only the first answer counts
    setState(() {
      _answered = true;
      _selectedOption = option;
      if (option == _questions[_currentIndex].correctAnswer) {
        _score++;
      }
    });
  }

  void _nextQuestion() {
    setState(() {
      if (_currentIndex < _questions.length - 1) {
        _currentIndex++;
        _answered = false;
        _selectedOption = null;
      } else {
        _currentIndex++; // shows the results screen
      }
    });
  }

  /// SIMULATION ONLY: no network request is sent. The delay stands in for
  /// the time a real POST to a leaderboard server would take.
  Future<void> _syncScoreToCloud() async {
    if (_isSyncing || _isSynced) return;
    final roundId = _roundId;
    final payload = {'score': _score, 'total': _questions.length};
    setState(() => _isSyncing = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted || roundId != _roundId) return;
    setState(() {
      _isSyncing = false;
      _isSynced = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Simulated sync complete; no backend request was sent. Payload: $payload',
        ),
      ),
    );
  }

  /// Used by both Play Again and Retry.
  void _restart() {
    _roundId++;
    setState(() {
      _isLoading = true;
      _error = '';
      _currentIndex = 0;
      _score = 0;
      _answered = false;
      _selectedOption = null;
      _isSynced = false;
      _isSyncing = false;
    });
    _loadTriviaData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cloud Trivia Showdown: API Edition')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error.isNotEmpty
                ? _buildError()
                : _currentIndex >= _questions.length
                    ? _buildResults()
                    : _buildQuestion(),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _error,
            key: const Key('errorText'),
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: _restart, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Showdown Complete!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Final Score: $_score / ${_questions.length}',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 24),
          if (!_isSynced)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: _isSyncing ? null : _syncScoreToCloud,
              icon: const Icon(Icons.cloud_upload),
              label: Text(_isSyncing ? 'Simulating sync...' : 'Simulate Score Sync'),
            )
          else
            const Text(
              '✓ Sync Simulation Complete',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          const SizedBox(height: 16),
          TextButton(onPressed: _restart, child: const Text('Play Again')),
        ],
      ),
    );
  }

  Widget _buildQuestion() {
    final question = _questions[_currentIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: (_currentIndex + 1) / _questions.length,
          backgroundColor: Colors.orange.shade100,
          color: Colors.deepOrange,
        ),
        const SizedBox(height: 16),
        Text(
          'Question ${_currentIndex + 1} of ${_questions.length}',
          style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(question.questionText, style: const TextStyle(fontSize: 18)),
          ),
        ),
        const SizedBox(height: 20),
        ...question.options.map((opt) {
          Color btnColor = Colors.white;
          if (_answered) {
            if (opt == question.correctAnswer) {
              btnColor = Colors.green.shade200;
            } else if (opt == _selectedOption) {
              btnColor = Colors.red.shade200;
            }
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: btnColor,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () => _answerQuestion(opt),
              child: Text(opt, style: const TextStyle(fontSize: 16)),
            ),
          );
        }),
        const Spacer(),
        if (_answered)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _nextQuestion,
            child: Text(
              _currentIndex < _questions.length - 1
                  ? 'Next Question →'
                  : 'View Final Score',
            ),
          ),
      ],
    );
  }
}
