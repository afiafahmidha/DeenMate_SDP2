import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/deen_minimal_loader.dart';

/// An interactive preview screen to showcase DeenMate's ultra-minimal aesthetic loading states
/// across Light Mode, Dark Mode, sizes, and overlay modes.
class LoadingShowcaseScreen extends StatefulWidget {
  const LoadingShowcaseScreen({super.key});

  @override
  State<LoadingShowcaseScreen> createState() => _LoadingShowcaseScreenState();
}

class _LoadingShowcaseScreenState extends State<LoadingShowcaseScreen> {
  bool _isDark = false;
  bool _showCrescent = true;

  @override
  Widget build(BuildContext context) {
    final bg = _isDark ? const Color(0xFF090E14) : const Color(0xFFF8FAFC);
    final cardSurface = _isDark ? const Color(0xFF111823) : Colors.white;
    final textPrimary = _isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F1E2E);
    final textMuted = _isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = _isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'AESTHETIC LOADER',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 3.0,
            color: textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: _isDark ? 'Switch to Bright Mode' : 'Switch to Dark Mode',
            icon: Icon(
              _isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: textPrimary,
            ),
            onPressed: () => setState(() => _isDark = !_isDark),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Theme Mode indicator chip
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _isDark
                      ? const Color(0xFF2DD4BF).withValues(alpha: 0.12)
                      : const Color(0xFF0F1E2E).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: _isDark
                        ? const Color(0xFF2DD4BF).withValues(alpha: 0.3)
                        : const Color(0xFF0F1E2E).withValues(alpha: 0.15),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  _isDark ? '🌙 DARK MODE (OLED OBSIDIAN)' : '☀️ BRIGHT MODE (SLATE PORCELAIN)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                    color: _isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F1E2E),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Hero Display: Borderless Loading State
            Text(
              'BORDERLESS LOADING STATE',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.5,
                color: textMuted,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: DeenMinimalLoadingCard(
                message: 'সবর করুন • LOADING',
                loaderSize: 56.0,
                isDarkMode: _isDark,
              ),
            ),
            const SizedBox(height: 40),

            // Sizes section
            Text(
              'RESPONSIVE SIZES',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.5,
                color: textMuted,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 0.8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSizeItem(
                    label: 'INLINE (28px)',
                    size: 28,
                    isDark: _isDark,
                    textMuted: textMuted,
                    showCrescent: false,
                  ),
                  _buildSizeItem(
                    label: 'STANDARD (48px)',
                    size: 48,
                    isDark: _isDark,
                    textMuted: textMuted,
                    showCrescent: _showCrescent,
                  ),
                  _buildSizeItem(
                    label: 'HERO (76px)',
                    size: 76,
                    isDark: _isDark,
                    textMuted: textMuted,
                    showCrescent: _showCrescent,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Interactive Controls
            Text(
              'CONTROLS & OVERLAY TEST',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.5,
                color: textMuted,
              ),
            ),
            const SizedBox(height: 12),

            // Toggle Crescent switch
            SwitchListTile.adaptive(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              title: Text(
                'Show Minimalist Crescent',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                'Toggles the whisper-thin crescent in center',
                style: TextStyle(color: textMuted, fontSize: 12),
              ),
              value: _showCrescent,
              activeThumbColor: const Color(0xFF2DD4BF),
              onChanged: (v) => setState(() => _showCrescent = v),
            ),

            const SizedBox(height: 16),

            // Trigger Overlay button
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: textPrimary,
                  side: BorderSide(
                    color: _isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F1E2E),
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.blur_on_rounded, size: 20),
                label: Text(
                  'TEST FULLSCREEN OVERLAY (3s)',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    fontSize: 12,
                  ),
                ),
                onPressed: () {
                  DeenLoading.show(
                    context,
                    message: 'অনুগ্রহ করে অপেক্ষা করুন',
                    isDarkMode: _isDark,
                  );
                  Future.delayed(const Duration(seconds: 3), () {
                    DeenLoading.hide();
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSizeItem({
    required String label,
    required double size,
    required bool isDark,
    required Color textMuted,
    required bool showCrescent,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DeenMinimalLoader(
          size: size,
          isDarkMode: isDark,
          showCrescent: showCrescent,
        ),
        const SizedBox(height: 14),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            color: textMuted,
          ),
        ),
      ],
    );
  }
}

