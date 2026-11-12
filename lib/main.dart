import 'package:flutter/material.dart';

import 'models/question.dart';
import 'services/trivia_service.dart';

void main() {
  runApp(const TriviaApp());
}

class TriviaApp extends StatelessWidget {
  final TriviaService? service;
  const TriviaApp({super.key, this.service});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trivia Showdown',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: TriviaScreen(service: service ?? TriviaService()),
    );
  }
}

enum LoadState { loading, ready, error }

class TriviaScreen extends StatefulWidget {
  final TriviaService service;
  const TriviaScreen({super.key, required this.service});

  @override
  State<TriviaScreen> createState() => _TriviaScreenState();
}

class _TriviaScreenState extends State<TriviaScreen> {
  LoadState _state = LoadState.loading;
  String _errorMessage = '';
  List<Question> _questions = [];
  int _currentIndex = 0;
  int _score = 0;
  String? _selectedAnswer;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _loadTriviaData();
  }

  Future<void> _loadTriviaData() async {
    setState(() {
      _state = LoadState.loading;
      _errorMessage = '';
    });
    try {
      final questions = await widget.service.fetchQuestions();
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _currentIndex = 0;
        _score = 0;
        _selectedAnswer = null;
        _finished = false;
        _state = LoadState.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _state = LoadState.error;
      });
    }
  }

  void _answerQuestion(String answer) {
    if (_selectedAnswer != null) return; // only the first tap counts
    setState(() {
      _selectedAnswer = answer;
      if (answer == _questions[_currentIndex].correctAnswer) _score++;
    });
  }

  void _nextQuestion() {
    setState(() {
      if (_currentIndex < _questions.length - 1) {
        _currentIndex++;
        _selectedAnswer = null;
      } else {
        _finished = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trivia Showdown'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case LoadState.loading:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Fetching questions...'),
            ],
          ),
        );
      case LoadState.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 56, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                _errorMessage,
                key: const Key('errorText'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadTriviaData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        );
      case LoadState.ready:
        return _finished
            ? ResultsView(
                score: _score,
                total: _questions.length,
                onReplay: _loadTriviaData,
              )
            : _buildQuestion();
    }
  }

  Widget _buildQuestion() {
    final q = _questions[_currentIndex];
    final answered = _selectedAnswer != null;
    final isLast = _currentIndex == _questions.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Question ${_currentIndex + 1} of ${_questions.length}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('Score: $_score', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (_currentIndex + (answered ? 1 : 0)) / _questions.length,
        ),
        const SizedBox(height: 24),
        Text(
          q.questionText,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 24),
        Expanded(
          child: ListView(
            children: q.options.map((option) {
              Color? bg;
              Color? fg;
              if (answered) {
                if (option == q.correctAnswer) {
                  bg = Colors.green;
                  fg = Colors.white;
                } else if (option == _selectedAnswer) {
                  bg = Colors.red;
                  fg = Colors.white;
                }
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: bg,
                    foregroundColor: fg,
                    disabledBackgroundColor: bg,
                    disabledForegroundColor: fg,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  ),
                  onPressed: answered ? null : () => _answerQuestion(option),
                  child: Text(option, textAlign: TextAlign.center),
                ),
              );
            }).toList(),
          ),
        ),
        if (answered) ...[
          Text(
            _selectedAnswer == q.correctAnswer
                ? 'Correct!'
                : 'Wrong. The answer was: ${q.correctAnswer}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _selectedAnswer == q.correctAnswer ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _nextQuestion,
            child: Text(isLast ? 'See Results' : 'Next Question'),
          ),
        ],
      ],
    );
  }
}

class ResultsView extends StatefulWidget {
  final int score;
  final int total;
  final VoidCallback onReplay;

  const ResultsView({
    super.key,
    required this.score,
    required this.total,
    required this.onReplay,
  });

  @override
  State<ResultsView> createState() => _ResultsViewState();
}

class _ResultsViewState extends State<ResultsView> {
  bool _syncing = false;
  bool _synced = false;

  /// SIMULATION ONLY: no network request is sent. The delay stands in for
  /// the latency of a real POST to a leaderboard endpoint.
  Future<void> _syncScoreToCloud() async {
    setState(() => _syncing = true);
    final payload = {
      'score': widget.score,
      'total': widget.total,
      'submittedAt': DateTime.now().toIso8601String(),
    };
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _syncing = false;
      _synced = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Simulated sync complete (no backend request sent). Payload: $payload',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events, size: 72, color: Colors.amber),
          const SizedBox(height: 12),
          Text('Round Complete!', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Final Score: ${widget.score} / ${widget.total}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: (_syncing || _synced) ? null : _syncScoreToCloud,
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_synced ? Icons.check : Icons.cloud_upload),
            label: Text(
              _synced
                  ? 'Synced (Simulated)'
                  : _syncing
                      ? 'Syncing...'
                      : 'Sync Score to Leaderboard (Simulated)',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Classroom simulation: no data is sent to a server.',
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: widget.onReplay,
            icon: const Icon(Icons.replay),
            label: const Text('Play Again'),
          ),
        ],
      ),
    );
  }
}
