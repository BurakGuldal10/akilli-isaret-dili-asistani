import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_theme.dart';
import '../models/letter_info.dart';
import '../providers/app_state.dart';
import 'recognition_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AppState _appState = AppState.instance;
  late PageController _pageController;
  final ScrollController _stripScrollController = ScrollController();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.86);
    _appState.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _appState.removeListener(_onStateChanged);
    _pageController.dispose();
    _stripScrollController.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  void _goToPage(int index) {
    if (index < 0 || index >= LetterInfo.alphabets.length) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollStripTo(int index) {
    if (!_stripScrollController.hasClients) return;
    final double targetOffset = (index * 48.0) - 120.0;
    _stripScrollController.animateTo(
      targetOffset.clamp(
        0.0,
        _stripScrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final letters = LetterInfo.alphabets;
    final currentLetter = letters[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF111526),
      body: SafeArea(
        child: Column(
          children: [
            // 1. SADE ÜST BAR (Başlık + İlerleme Rozeti + Ayarlar)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
              child: Row(
                children: [
                  Text(
                    'İşaret Dili Rehberi',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.successGreen,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_appState.learnedCount} / ${letters.length}',
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.successGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Ayarlar',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            // 2. YATAY HIZLI HARF ŞERİDİ
            SizedBox(
              height: 46,
              child: ListView.builder(
                controller: _stripScrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: letters.length,
                itemBuilder: (context, index) {
                  final letter = letters[index];
                  final isSelected = index == _currentIndex;
                  final isLearned = _appState.isLearned(letter);

                  return GestureDetector(
                    onTap: () => _goToPage(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 40,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.warmOrange
                            : (isLearned
                                ? AppTheme.successGreen.withValues(alpha: 0.18)
                                : Colors.white.withValues(alpha: 0.06)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.warmOrange
                              : (isLearned
                                  ? AppTheme.successGreen.withValues(alpha: 0.5)
                                  : Colors.transparent),
                        ),
                      ),
                      child: Text(
                        letter,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // 3. BÜYÜK KAYDIRMALI HARF KARTI (FLASHCARD)
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: letters.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                  _scrollStripTo(index);
                },
                itemBuilder: (context, index) {
                  final letter = letters[index];
                  final guide = _appState.getGuide(letter);
                  final isLearned = _appState.isLearned(letter);
                  final isCurrent = index == _currentIndex;

                  return AnimatedScale(
                    scale: isCurrent ? 1.0 : 0.93,
                    duration: const Duration(milliseconds: 250),
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B223C),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: isLearned
                              ? AppTheme.successGreen.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.08),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Kart Üst Bilgisi (Sıra & El Sayısı)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      guide.handCount == 1
                                          ? Icons.back_hand_outlined
                                          : Icons.sign_language_outlined,
                                      size: 16,
                                      color: AppTheme.warmGold,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${guide.handCount} El İşareti',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.warmGold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () =>
                                    _appState.toggleLetterLearned(letter),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isLearned
                                        ? AppTheme.successGreen
                                            .withValues(alpha: 0.18)
                                        : Colors.white.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isLearned
                                            ? Icons.check_circle_rounded
                                            : Icons.circle_outlined,
                                        size: 16,
                                        color: isLearned
                                            ? AppTheme.successGreen
                                            : Colors.white54,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isLearned ? 'Öğrenildi' : 'İşaretle',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: isLearned
                                              ? AppTheme.successGreen
                                              : Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const Spacer(),

                          // Büyük Harf Görünümü
                          Container(
                            width: 130,
                            height: 130,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: isLearned
                                    ? [
                                        const Color(0xFF1B998B),
                                        AppTheme.successGreen,
                                      ]
                                    : [
                                        AppTheme.warmOrange,
                                        AppTheme.warmRed,
                                      ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (isLearned
                                          ? AppTheme.successGreen
                                          : AppTheme.warmOrange)
                                      .withValues(alpha: 0.3),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Text(
                              letter,
                              style: GoogleFonts.poppins(
                                fontSize: 64,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),

                          const Spacer(),

                          // Nasıl Yapılır Açıklama Kutusu
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'NASIL YAPILIR?',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                    color: Colors.white54,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  guide.tip,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha: 0.92),
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Önceki / Sonraki Gezinme Satırı
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton.icon(
                                onPressed: index > 0
                                    ? () => _goToPage(index - 1)
                                    : null,
                                icon: const Icon(
                                  Icons.chevron_left_rounded,
                                  size: 20,
                                ),
                                label: Text(
                                  'Önceki',
                                  style: GoogleFonts.poppins(fontSize: 12.5),
                                ),
                              ),
                              Text(
                                '${index + 1} / ${letters.length}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.white38,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: index < letters.length - 1
                                    ? () => _goToPage(index + 1)
                                    : null,
                                icon: Text(
                                  'Sonraki',
                                  style: GoogleFonts.poppins(fontSize: 12.5),
                                ),
                                label: const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // 4. ALTTA TEK VE NET AKSİYON BUTONU ("Kamerada Dene")
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.warmOrange,
                    foregroundColor: Colors.white,
                    elevation: 6,
                    shadowColor: AppTheme.warmOrange.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            RecognitionScreen(targetLetter: currentLetter),
                      ),
                    );
                  },
                  icon: const Icon(Icons.videocam_rounded, size: 24),
                  label: Text(
                    '$currentLetter Harfini Kamerada Dene',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
