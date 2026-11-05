import 'package:flutter/foundation.dart';

/// Her harf için Türk İşaret Dili (TİD) ipucu ve el sayısı bilgisi
class LetterInfo {
  final String letter;
  final int handCount; // 1 veya 2 el
  final String tip;

  const LetterInfo({
    required this.letter,
    required this.handCount,
    required this.tip,
  });
}

/// Uygulama genelinde öğrenilen harfleri, sunucu adresini ve istatistikleri yöneten durum sınıfı
class AppState extends ChangeNotifier {
  static final AppState instance = AppState._internal();
  AppState._internal();

  static const List<String> alphabets = [
    'A', 'B', 'C', 'Ç', 'D', 'E', 'F', 'G', 'Ğ', 'H',
    'I', 'İ', 'J', 'K', 'L', 'M', 'N', 'O', 'Ö', 'P',
    'R', 'S', 'Ş', 'T', 'U', 'Ü', 'V', 'Y', 'Z'
  ];

  static const Map<String, LetterInfo> letterGuides = {
    'A': LetterInfo(letter: 'A', handCount: 2, tip: 'İki elin işaret parmakları çatı gibi birleştirilir, başparmaklar yatay tutulur.'),
    'B': LetterInfo(letter: 'B', handCount: 2, tip: 'İki elin parmakları daire yaparak gözlük gibi birleştirilir.'),
    'C': LetterInfo(letter: 'C', handCount: 1, tip: 'Başparmak ve işaret parmağıyla C harfi kavisi oluşturulur.'),
    'Ç': LetterInfo(letter: 'Ç', handCount: 1, tip: 'C işareti yapılırken el hafifçe aşağı-yukarı hareket ettirilir veya nokta gösterilir.'),
    'D': LetterInfo(letter: 'D', handCount: 2, tip: 'Bir elin işaret parmağı dik tutulur, diğer elin iki parmağıyla yarım daire yapılır.'),
    'E': LetterInfo(letter: 'E', handCount: 2, tip: 'Bir elin üç parmağı yatay uzatılır, diğer el dikey olarak kenarına yaslanır.'),
    'F': LetterInfo(letter: 'F', handCount: 2, tip: 'Bir elin işaret parmağı dik, diğer elin iki parmağı yatay olarak üst kısmına konur.'),
    'G': LetterInfo(letter: 'G', handCount: 2, tip: 'Yumruk yapılan iki el üst üste gelecek şekilde konumlandırılır.'),
    'Ğ': LetterInfo(letter: 'Ğ', handCount: 2, tip: 'G harfi pozisyonunda üstteki el hafifçe hareket ettirilir.'),
    'H': LetterInfo(letter: 'H', handCount: 2, tip: 'İki elin işaret parmakları dik, başparmaklar ortada birbirine değecek şekilde tutulur.'),
    'I': LetterInfo(letter: 'I', handCount: 1, tip: 'İşaret parmağı yukarı doğru dik olarak uzatılır, diğer parmaklar kapatılır.'),
    'İ': LetterInfo(letter: 'İ', handCount: 1, tip: 'İşaret parmağı dik tutulurken nokta hareketi belirtilir.'),
    'J': LetterInfo(letter: 'J', handCount: 1, tip: 'İşaret veya serçe parmakla havada J kavisi çizilir.'),
    'K': LetterInfo(letter: 'K', handCount: 2, tip: 'Bir elin işaret parmağı dik tutulur, diğer elin iki parmağı açılı olarak ortasına değdirilir.'),
    'L': LetterInfo(letter: 'L', handCount: 1, tip: 'Başparmak ve işaret parmağı 90 derece açıyla L şekli oluşturur.'),
    'M': LetterInfo(letter: 'M', handCount: 2, tip: 'İki elin üçer parmağı aşağı/karşıya bakacak şekilde yan yana getirilir.'),
    'N': LetterInfo(letter: 'N', handCount: 2, tip: 'İki elin ikişer parmağı yan yana getirilerek N formu oluşturulur.'),
    'O': LetterInfo(letter: 'O', handCount: 1, tip: 'Parmak uçları başparmakla birleştirilerek tam bir daire (O) yapılır.'),
    'Ö': LetterInfo(letter: 'Ö', handCount: 1, tip: 'O harfi yapılırken nokta vurgusu eklenir.'),
    'P': LetterInfo(letter: 'P', handCount: 2, tip: 'Bir elin işaret parmağı dik tutulur, diğer elin parmaklarıyla üst kısmında halka yapılır.'),
    'R': LetterInfo(letter: 'R', handCount: 2, tip: 'P harfine benzer şekilde ikinci elin parmağı aşağı doğru uzatılır.'),
    'S': LetterInfo(letter: 'S', handCount: 2, tip: 'İki el C şeklinde kıvrılarak ters yönlü S kıvrımı oluşturacak şekilde üst üste tutulur.'),
    'Ş': LetterInfo(letter: 'Ş', handCount: 2, tip: 'S harfi pozisyonu alınarak nokta hareketi yapılır.'),
    'T': LetterInfo(letter: 'T', handCount: 2, tip: 'Bir elin işaret parmağı dikey, diğer elin işaret parmağı onun üstüne yatay konarak T yapılır.'),
    'U': LetterInfo(letter: 'U', handCount: 1, tip: 'Başparmak ve işaret parmağı yukarı bakacak şekilde U açıklığı oluşturur.'),
    'Ü': LetterInfo(letter: 'Ü', handCount: 1, tip: 'U işareti yapılırken nokta vurgusu gösterilir.'),
    'V': LetterInfo(letter: 'V', handCount: 1, tip: 'İşaret ve orta parmak açılarak V (zafer) işareti yapılır.'),
    'Y': LetterInfo(letter: 'Y', handCount: 2, tip: 'Bir el V şeklinde açılır, diğer elin işaret parmağı alt birleşim noktasına konur.'),
    'Z': LetterInfo(letter: 'Z', handCount: 2, tip: 'Ellerle Z harfinin köşeli zikzak formu oluşturulur.'),
  };

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
  double get progressRatio => _learnedLetters.length / alphabets.length;
  int get quizScore => _quizScore;
  int get totalPracticeCount => _totalPracticeCount;
  bool get useFrontCamera => _useFrontCamera;
  String get serverUrl => _serverUrl;

  bool isLearned(String letter) => _learnedLetters.contains(letter);

  LetterInfo getGuide(String letter) {
    return letterGuides[letter] ??
        LetterInfo(
          letter: letter,
          handCount: 1,
          tip: 'Elinizi kamera çerçevesinin ortasında net görünecek şekilde tutun.',
        );
  }

  void markLetterLearned(String letter) {
    _totalPracticeCount++;
    if (_learnedLetters.add(letter)) {
      notifyListeners();
    } else {
      notifyListeners();
    }
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
