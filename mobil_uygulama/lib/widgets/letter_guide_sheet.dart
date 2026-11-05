import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_theme.dart';
import '../providers/app_state.dart';
import '../screens/recognition_screen.dart';

class LetterGuideSheet extends StatelessWidget {
  final String letter;

  const LetterGuideSheet({super.key, required this.letter});

  static void show(BuildContext context, String letter) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.midBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => LetterGuideSheet(letter: letter),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppState.instance;
    final guide = appState.getGuide(letter);
    final learned = appState.isLearned(letter);

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
                    colors: [AppTheme.warmOrange, AppTheme.warmRed],
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
                          color: AppTheme.warmGold,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${guide.handCount} El İşareti',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppTheme.warmGold,
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
                      learned ? AppTheme.successGreen : Colors.white70,
                  side: BorderSide(
                    color: learned ? AppTheme.successGreen : Colors.white24,
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  appState.toggleLetterLearned(letter);
                  Navigator.pop(context);
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
                    backgroundColor: AppTheme.warmOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecognitionScreen(targetLetter: letter),
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
  }
}
