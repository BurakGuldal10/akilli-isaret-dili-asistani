import 'package:flutter/foundation.dart';
import '../models/letter_info.dart';

/// Uygulama genelinde öğrenilen harfleri, sunucu adresini ve istatistikleri yöneten durum sağlayıcısı
class AppState extends ChangeNotifier {
  static final AppState instance = AppState._internal();
  AppState._internal();

  final Set<String> _learnedLetters = {};
  int _quizScore = 0;
  int _totalPracticeCount = 0;
  bool _useFrontCamera = true;

  String _serverUrl = const String.fromEnvironment(
    'SERVER_URL',
    defaultValue: kIsWeb ? 'http://localhost:5000' : 'http://172.20.10.3:5000',
  );

  Set<String> get learnedLetters => Set.unmodifiable(_learnedLetters);
  int get learnedCount => _learnedLetters.length;
  double get progressRatio => _learnedLetters.length / LetterInfo.alphabets.length;
  int get quizScore => _quizScore;
  int get totalPracticeCount => _totalPracticeCount;
  bool get useFrontCamera => _useFrontCamera;
  String get serverUrl => _serverUrl;

  bool isLearned(String letter) => _learnedLetters.contains(letter);

  LetterInfo getGuide(String letter) {
    return LetterInfo.guides[letter] ??
        LetterInfo(
          letter: letter,
          handCount: 1,
          tip: 'Elinizi kamera çerçevesinin ortasında net görünecek şekilde tutun.',
        );
  }

  void markLetterLearned(String letter) {
    _totalPracticeCount++;
    _learnedLetters.add(letter);
    notifyListeners();
  }

  void toggleLetterLearned(String letter) {
    if (_learnedLetters.contains(letter)) {
      _learnedLetters.remove(letter);
    } else {
      _learnedLetters.add(letter);
    }
    notifyListeners();
  }

  void addQuizPoints(int points) {
    _quizScore += points;
    notifyListeners();
  }

  void setServerUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isNotEmpty && trimmed != _serverUrl) {
      _serverUrl = trimmed;
      notifyListeners();
    }
  }

  void setUseFrontCamera(bool value) {
    if (_useFrontCamera != value) {
      _useFrontCamera = value;
      notifyListeners();
    }
  }

  void resetProgress() {
    _learnedLetters.clear();
    _quizScore = 0;
    _totalPracticeCount = 0;
    notifyListeners();
  }
}
