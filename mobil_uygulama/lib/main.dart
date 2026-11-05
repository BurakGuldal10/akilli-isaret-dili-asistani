import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_state.dart';
import 'recognition_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Akıllı İşaret Dili Asistanı',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        textTheme: GoogleFonts.poppinsTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

/// 4 Ana Sekmeli Uygulama İskeleti (Adım 1)
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  final AppState _appState = AppState.instance;

  @override
  void initState() {
    super.initState();
    _appState.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _appState.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomeScreen(),
      const _ComingSoonTab(
        icon: Icons.edit_note_rounded,
        title: 'Serbest Kelime Yazma Modu',
        subtitle:
            'Kameraya sırayla harfleri göstererek kelime ve cümle oluşturacağınız ekran (Adım 3\'te aktifleşecek).',
        badgeText: 'Adım 3',
      ),
      _ComingSoonTab(
        icon: Icons.emoji_events_rounded,
        title: 'Kendini Test Et (Quiz Modu)',
        subtitle:
            'Rastgele sorulan harf ve kelimeleri kameraya doğru göstererek puan toplayacağınız yarışma ekranı (Adım 4\'te aktifleşecek).',
        badgeText: 'Adım 4 • Puan: ${_appState.quizScore}',
      ),
      const SettingsAndProfileTab(),
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
              Color(0xFF0F3460),
              Color(0xFF1A1A2E),
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: IndexedStack(
            index: _selectedIndex,
            children: pages,
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF121629),
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (idx) => setState(() => _selectedIndex = idx),
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFFFF6B35),
          unselectedItemColor: Colors.white54,
          selectedLabelStyle: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontSize: 11,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_rounded),
              label: 'Öğren',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.translate_rounded),
              label: 'Kelime Yaz',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.quiz_rounded),
              label: 'Quiz',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.tune_rounded),
              label: 'Ayarlar',
            ),
          ],
        ),
      ),
    );
  }
}

/// 1. SEKME: Harf Öğrenme, Filtreleme ve İlerleme Takibi Ekranı
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AppState _appState = AppState.instance;
  String _selectedFilter = 'Tümü'; // 'Tümü', 'Tek El', 'Çift El', 'Öğrenilenler'

  List<String> get _filteredLetters {
    return AppState.alphabets.where((letter) {
      final guide = _appState.getGuide(letter);
      if (_selectedFilter == 'Tek El') return guide.handCount == 1;
      if (_selectedFilter == 'Çift El') return guide.handCount == 2;
      if (_selectedFilter == 'Öğrenilenler') return _appState.isLearned(letter);
      return true;
    }).toList();
  }

  List<Color> _getCardGradient(int index, bool isLearned) {
    if (isLearned) {
      return [const Color(0xFF1B998B), const Color(0xFF2ECC71)];
    }
    final warmColors = [
      [const Color(0xFFFF6B35), const Color(0xFFFF8E53)],
      [const Color(0xFFE63946), const Color(0xFFFF6B6B)],
      [const Color(0xFFF4A261), const Color(0xFFE9C46A)],
      [const Color(0xFFD62828), const Color(0xFFE85D04)],
      [const Color(0xFFFF9F1C), const Color(0xFFFFBF69)],
      [const Color(0xFFCB4335), const Color(0xFFEB6840)],
    ];
    return warmColors[index % warmColors.length];
  }

  void _showLetterGuideSheet(BuildContext context, String letter) {
    final guide = _appState.getGuide(letter);
    final learned = _appState.isLearned(letter);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B35), Color(0xFFE63946)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      letter,
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$letter Harfi Nasıl Yapılır?',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              guide.handCount == 1
                                  ? Icons.back_hand_rounded
                                  : Icons.sign_language_rounded,
                              size: 15,
                              color: const Color(0xFFFF9F1C),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${guide.handCount} El İşareti',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: const Color(0xFFFF9F1C),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  guide.tip,
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          learned ? const Color(0xFF2ECC71) : Colors.white70,
                      side: BorderSide(
                        color: learned
                            ? const Color(0xFF2ECC71)
                            : Colors.white24,
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      _appState.toggleLetterLearned(letter);
                      Navigator.pop(ctx);
                    },
                    icon: Icon(
                      learned
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked,
                      size: 18,
                    ),
                    label: Text(
                      learned ? 'Öğrenildi' : 'Öğrenildi İşaretle',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B35),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                RecognitionScreen(targetLetter: letter),
                          ),
                        );
                      },
                      icon: const Icon(Icons.videocam_rounded, size: 20),
                      label: Text(
                        'Kamerada Dene',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final learnedCount = _appState.learnedCount;
    final totalCount = AppState.alphabets.length;
    final percent = (_appState.progressRatio * 100).round();
    final letters = _filteredLetters;

    return LayoutBuilder(
      builder: (context, constraints) {
        final int crossAxisCount = constraints.maxWidth > 900
            ? 7
            : (constraints.maxWidth > 600 ? 5 : 4);

        return Column(
          children: [
            // ÜST BAŞLIK & İLERLEME KARTI
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B35), Color(0xFFE63946)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.sign_language,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Türk İşaret Dili (TİD)',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Harfe dokunarak kamerada pratik yap veya basılı tutarak ipucunu gör',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // İlerleme Durumu Kartı
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.workspace_premium_rounded,
                                  color: Color(0xFFFF9F1C),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Öğrenme İlerlemesi',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '$learnedCount / $totalCount Harf (%$percent)',
                              style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2ECC71),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _appState.progressRatio,
                            minHeight: 8,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF2ECC71),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Filtre Seçenekleri
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        'Tümü',
                        'Tek El',
                        'Çift El',
                        'Öğrenilenler',
                      ].map((filter) {
                        final isSelected = _selectedFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(filter),
                            selected: isSelected,
                            onSelected: (_) =>
                                setState(() => _selectedFilter = filter),
                            selectedColor: const Color(0xFFFF6B35),
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.08),
                            labelStyle: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: Colors.white,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // ALFABE GRID LİSTESİ
            Expanded(
              child: letters.isEmpty
                  ? Center(
                      child: Text(
                        'Bu filtrede henüz harf bulunmuyor.',
                        style: GoogleFonts.poppins(color: Colors.white60),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: letters.length,
                        itemBuilder: (context, index) {
                          final letter = letters[index];
                          final isLearned = _appState.isLearned(letter);
                          final guide = _appState.getGuide(letter);
                          return _LetterCard(
                            letter: letter,
                            handCount: guide.handCount,
                            isLearned: isLearned,
                            gradient: _getCardGradient(index, isLearned),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      RecognitionScreen(targetLetter: letter),
                                ),
                              );
                            },
                            onInfoTap: () =>
                                _showLetterGuideSheet(context, letter),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _LetterCard extends StatelessWidget {
  final String letter;
  final int handCount;
  final bool isLearned;
  final List<Color> gradient;
  final VoidCallback onTap;
  final VoidCallback onInfoTap;

  const _LetterCard({
    required this.letter,
    required this.handCount,
    required this.isLearned,
    required this.gradient,
    required this.onTap,
    required this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onInfoTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Sol üst: Tek el / Çift el etiketi
            Positioned(
              top: 6,
              left: 7,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$handCount El',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // Sağ üst: Öğrenildi rozeti veya İpucu butonu
            Positioned(
              top: 4,
              right: 4,
              child: InkWell(
                onTap: onInfoTap,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    isLearned
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ),

            // Merkez Harf
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    letter,
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isLearned ? 'Tamamlandı' : 'Pratik Yap',
                      style: GoogleFonts.poppins(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 4. SEKME: Ayarlar, Sunucu Bağlantısı ve İstatistikler
class SettingsAndProfileTab extends StatefulWidget {
  const SettingsAndProfileTab({super.key});

  @override
  State<SettingsAndProfileTab> createState() => _SettingsAndProfileTabState();
}

class _SettingsAndProfileTabState extends State<SettingsAndProfileTab> {
  final AppState _appState = AppState.instance;
  late TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: _appState.serverUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profil & Uygulama Ayarları',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Öğrenme istatistiklerinizi görüntüleyin ve sunucu bağlantısını yapılandırın.',
            style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.white70),
          ),
          const SizedBox(height: 20),

          // İstatistik Kartları
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Öğrenilen Harf',
                  value: '${_appState.learnedCount} / 29',
                  color: const Color(0xFF2ECC71),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.emoji_events_outlined,
                  label: 'Quiz Puanı',
                  value: '${_appState.quizScore}',
                  color: const Color(0xFFFF9F1C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Sunucu Bağlantı Ayarı
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.dns_rounded, color: Color(0xFFFF6B35)),
                    const SizedBox(width: 8),
                    Text(
                      'Python API Sunucu Adresi',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _urlController,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'http://192.168.1.x:5000',
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      _appState.setServerUrl(_urlController.text);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sunucu adresi kaydedildi!'),
                          backgroundColor: Color(0xFF2ECC71),
                        ),
                      );
                    },
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: Text(
                      'Sunucu Adresini Kaydet',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Kamera Yönü Seçimi
          SwitchListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            tileColor: Colors.white.withValues(alpha: 0.06),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            activeThumbColor: const Color(0xFFFF6B35),
            title: Text(
              'Ön Kamerayı Kullan',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              _appState.useFrontCamera
                  ? 'Selfie (Ön) kamera aktif'
                  : 'Arka kamera aktif',
              style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12),
            ),
            value: _appState.useFrontCamera,
            onChanged: (val) => _appState.setUseFrontCamera(val),
          ),
          const SizedBox(height: 16),

          // İlerlemeyi Sıfırla
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE63946),
                side: const BorderSide(color: Color(0xFFE63946)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                _appState.resetProgress();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Öğrenme ilerlemesi sıfırlandı.'),
                  ),
                );
              },
              icon: const Icon(Icons.restart_alt_rounded),
              label: Text(
                'Öğrenme İlerlemesini Sıfırla',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badgeText;

  const _ComingSoonTab({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 54, color: const Color(0xFFFF6B35)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9F1C).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badgeText,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFF9F1C),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.white70,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
