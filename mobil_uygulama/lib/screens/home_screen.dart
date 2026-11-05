import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_theme.dart';
import '../models/letter_info.dart';
import '../providers/app_state.dart';
import '../widgets/letter_card.dart';
import '../widgets/letter_guide_sheet.dart';
import 'recognition_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AppState _appState = AppState.instance;
  String _selectedFilter = 'Tümü';

  List<String> get _filteredLetters {
    return LetterInfo.alphabets.where((letter) {
      final guide = _appState.getGuide(letter);
      if (_selectedFilter == 'Tek El') return guide.handCount == 1;
      if (_selectedFilter == 'Çift El') return guide.handCount == 2;
      if (_selectedFilter == 'Öğrenilenler') return _appState.isLearned(letter);
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final learnedCount = _appState.learnedCount;
    final totalCount = LetterInfo.alphabets.length;
    final percent = (_appState.progressRatio * 100).round();
    final letters = _filteredLetters;

    return LayoutBuilder(
      builder: (context, constraints) {
        final int crossAxisCount = constraints.maxWidth > 900
            ? 7
            : (constraints.maxWidth > 600 ? 5 : 4);

        return Column(
          children: [
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
                            colors: [AppTheme.warmOrange, AppTheme.warmRed],
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
                              'Harfe dokunarak kamerada pratik yap veya (ⓘ) ikonuna dokunarak ipucunu gör',
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
                                  color: AppTheme.warmGold,
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
                                color: AppTheme.successGreen,
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
                              AppTheme.successGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
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
                            selectedColor: AppTheme.warmOrange,
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
                          return LetterCard(
                            letter: letter,
                            handCount: guide.handCount,
                            isLearned: isLearned,
                            gradient:
                                AppTheme.getCardGradient(index, isLearned),
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
                                LetterGuideSheet.show(context, letter),
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
