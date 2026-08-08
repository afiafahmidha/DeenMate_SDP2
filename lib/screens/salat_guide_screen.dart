import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../widgets/auth_header.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  SALAT GUIDE SCREEN — DeenMate
// ═══════════════════════════════════════════════════════════════════════════

class SalatGuideScreen extends StatefulWidget {
  final bool isDarkMode;
  const SalatGuideScreen({super.key, this.isDarkMode = false});

  @override
  State<SalatGuideScreen> createState() => _SalatGuideScreenState();
}

class _SalatGuideScreenState extends State<SalatGuideScreen>
    with TickerProviderStateMixin {
  int _tab = 0;
  static const _tabLabels = ['Guide', 'Wudu', 'Steps', 'Rules', 'Other', 'Mistakes', 'Qibla'];
  static const _tabIcons = [
    Icons.menu_book_rounded,
    Icons.water_drop_rounded,
    Icons.list_rounded,
    Icons.gavel_rounded,
    Icons.more_horiz_rounded,
    Icons.warning_rounded,
    Icons.place_rounded,
  ];
  bool _isDark = false;

  // Star positions for dashboard-style dark mode twinkling background
  final List<_StarConfig> _stars = [
    _StarConfig(topFraction: 0.03, leftFraction: 0.08, size: 5, delayMs: 200),
    _StarConfig(topFraction: 0.07, leftFraction: 0.85, size: 6, delayMs: 500),
    _StarConfig(topFraction: 0.12, leftFraction: 0.45, size: 4, delayMs: 800),
    _StarConfig(topFraction: 0.18, leftFraction: 0.72, size: 5, delayMs: 300),
    _StarConfig(topFraction: 0.24, leftFraction: 0.15, size: 4, delayMs: 600),
    _StarConfig(topFraction: 0.30, leftFraction: 0.92, size: 6, delayMs: 100),
    _StarConfig(topFraction: 0.38, leftFraction: 0.55, size: 5, delayMs: 700),
    _StarConfig(topFraction: 0.46, leftFraction: 0.05, size: 4, delayMs: 400),
    _StarConfig(topFraction: 0.54, leftFraction: 0.78, size: 5, delayMs: 900),
    _StarConfig(topFraction: 0.62, leftFraction: 0.30, size: 4, delayMs: 150),
    _StarConfig(topFraction: 0.70, leftFraction: 0.88, size: 6, delayMs: 450),
    _StarConfig(topFraction: 0.78, leftFraction: 0.12, size: 4, delayMs: 750),
    _StarConfig(topFraction: 0.86, leftFraction: 0.65, size: 5, delayMs: 350),
  ];

  @override
  void initState() {
    super.initState();
    _isDark = widget.isDarkMode;
  }

  @override
  void dispose() {
    super.dispose();
  }

  Color get _bg => _isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
  Color get _text => _isDark ? Colors.white : AppColors.navyBlue;
  Color get _subText => _isDark ? Colors.white60 : Colors.grey.shade600;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _isDark ? const Color(0xFF000000) : const Color(0xFFE0E4EA),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Scaffold(
            backgroundColor: _bg,
            body: SafeArea(
              child: Stack(
                children: [
                  // Dashboard-style background in dark mode
                  if (_isDark) ...[
                    // Same texture as dashboard
                    Positioned.fill(
                      child: CustomPaint(painter: _SalatTexturePainter()),
                    ),
                    // Exact same 4-point gold stars as dashboard
                    ..._stars.map((s) => _SalatTwinklingStar(
                          topFraction: s.topFraction,
                          leftFraction: s.leftFraction,
                          size: s.size,
                          delayMs: s.delayMs,
                        )),
                  ],

                  // Main UI Content
Column(
	                     children: [
	                       _buildHeader(),
	                       const SizedBox(height: 12),
	                       _buildTabBar(),
                      Expanded(
                        child: _buildTabContent(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: _text, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
gradient: _isDark
                   ? null
                   : const LinearGradient(colors: [AppColors.navyBlue, Color(0xFF1D3550)]),
              color: _isDark ? Colors.white.withValues(alpha: 0.15) : null,
              borderRadius: BorderRadius.circular(14),
              border: _isDark ? Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1) : null,
            ),
            child: const Icon(Icons.mosque_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Salat Guide',
                    style: GoogleFonts.poppins(
                        color: _text, fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Complete guide according to Sunnah',
                    style: GoogleFonts.inter(color: _subText, fontSize: 11)),
              ],
            ),
          ),
          
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final cardBg = _isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: List.generate(_tabLabels.length, (i) {
          final active = i == _tab;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: active ? AppColors.navyBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(_tabIcons[i],
                        size: 16,
                        color: active
                            ? Colors.white
                            : (_isDark ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.4))),
                    const SizedBox(height: 2),
                    Text(_tabLabels[i],
                        style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: active
                                ? Colors.white
                                : (_isDark ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.4)))),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_tab) {
      case 0:
        return _SalatGuideTab(isDark: _isDark);
      case 1:
        return _WuduGuideTab(isDark: _isDark);
      case 2:
        return _SalatStepsTab(isDark: _isDark);
      case 3:
        return _RulesTab(isDark: _isDark);
      case 4:
        return _OtherSalatsTab(isDark: _isDark);
      case 5:
        return _CommonMistakesTab(isDark: _isDark);
      case 6:
        return _QiblaTab(isDark: _isDark);
      default:
        return _SalatGuideTab(isDark: _isDark);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  WUDU GUIDE TAB
// ═══════════════════════════════════════════════════════════════════════════

class _WuduGuideTab extends StatefulWidget {
  final bool isDark;
  const _WuduGuideTab({required this.isDark});

  @override
  State<_WuduGuideTab> createState() => _WuduGuideTabState();
}

class _WuduGuideTabState extends State<_WuduGuideTab> {
  int _currentStep = 0;
  late PageController _pageCtrl;

  final List<Map<String, dynamic>> _wuduSteps = [
    {
      'step': 1,
      'titleEn': 'Make Intention (Niyyah) & Bismillah',
      'titleAr': 'النية والتسمية',
      'descEn': 'Begin by making the intention in your heart to purify yourself for Allah. Say Bismillah before starting.',
      'arabicPhrase': 'بِسْمِ اللهِ الرَّحْمَنِ الرَّحِيمِ',
      'pronunciation': 'Bismillahir-Rahmanir-Raheem',
      'translation': 'In the name of Allah, the Most Gracious, the Most Merciful.',
      'image': 'assets/images/salat/wudu/12.png',
      'imageDark': 'assets/images/salat/wudu/12_2.png',
      'hadithArabic': 'لا وُضُوءَ لِمَنْ لَمْ يَذْكُرِ اسْمَ اللَّهِ عَلَيْهِ',
      'hadithEnglish': 'There is no wudu for the one who does not mention the name of Allah upon it.',
      'ref': 'Sunan Abu Dawood 101, Sunan Ibn Majah 399',
    },
    {
      'step': 2,
      'titleEn': 'Wash Both Hands 3 Times',
      'titleAr': 'غسل الكفين',
      'descEn': 'Wash your hands up to the wrists three times, starting with the right hand. Pass wet fingers through each other (Khallil).',
      'arabicPhrase': '',
      'pronunciation': '',
      'translation': '',
      'image': 'assets/images/salat/wudu/1.png',
      'hadithArabic': 'إِذَا تَوَضَّأْتَ فَخَلِّلْ بَيْنَ أَصَابِعِ يَدَيْكَ وَرِجْلَيْكَ',
      'hadithEnglish': 'When you perform wudu, wash between the fingers of your hands and toes.',
      'ref': 'Jami\' at-Tirmidhi 39, Sunan Abu Dawood 142',
    },
    {
      'step': 3,
      'titleEn': 'Rinse Mouth (Madmadah) 3 Times',
      'titleAr': 'المضمضة',
      'descEn': 'Take water into your mouth using your right hand, swirl it around thoroughly, and spit it out 3 times. Miswak is highly recommended.',
      'arabicPhrase': '',
      'pronunciation': '',
      'translation': '',
      'image': 'assets/images/salat/wudu/2.png',
      'hadithArabic': 'لَوْلا أَنْ أَشُقَّ عَلَى أُمَّتِي لأَمَرْتُهُمْ بِالسِّوَاكِ مَعَ كُلِّ وُضُوءٍ',
      'hadithEnglish': 'Were it not that I would overburden my nation, I would have ordered them to use the miswak with every wudu.',
      'ref': 'Sahih al-Bukhari 887, Sahih Muslim 252',
    },
    {
      'step': 4,
      'titleEn': 'Sniff Water into Nose 3 Times',
      'titleAr': 'الاستنشاق والاستنثار',
      'descEn': 'Sniff water into nostrils with the right hand, then blow it out using the left hand 3 times.',
      'arabicPhrase': '',
      'pronunciation': '',
      'translation': '',
      'image': 'assets/images/salat/wudu/3.png',
      'hadithArabic': 'وَبَالِغْ فِي الاسْتِنْشَاقِ إِلاَّ أَنْ تَكُونَ صَائِمًا',
      'hadithEnglish': 'Sniff water deeply into your nostrils unless you are fasting.',
      'ref': 'Sunan Abu Dawood 142, Jami\' at-Tirmidhi 788',
    },
    {
      'step': 5,
      'titleEn': 'Wash the Face 3 Times',
      'titleAr': 'غسل الوجه',
      'descEn': 'Wash the face 3 times from hairline to chin, and ear to ear. Men with thick beards should run wet fingers through beard.',
      'arabicPhrase': '',
      'pronunciation': '',
      'translation': '',
      'image': 'assets/images/salat/wudu/6.png',
      'hadithArabic': 'يَا أَيُّهَا الَّذِينَ آمَنُوا إِذَا قُمْتُمْ إِلَى الصَّلاةِ فَاغْسِلُوا وُجُوهَكُمْ',
      'hadithEnglish': 'O you who have believed, when you rise to perform prayer, wash your faces...',
      'ref': 'Surah Al-Ma\'idah (5:6)',
    },
    {
      'step': 6,
      'titleEn': 'Wash Arms to Elbows 3 Times',
      'titleAr': 'غسل اليدين إلى المرفقين',
      'descEn': 'Wash right arm from fingertips to including the elbow 3 times, then repeat for the left arm.',
      'arabicPhrase': '',
      'pronunciation': '',
      'translation': '',
      'image': 'assets/images/salat/wudu/7.png',
      'hadithArabic': 'وَأَيْدِيَكُمْ إِلَى الْمَرَافِقِ',
      'hadithEnglish': '...and your hands and forearms up to the elbows.',
      'ref': 'Surah Al-Ma\'idah (5:6)',
    },
    {
      'step': 7,
      'titleEn': 'Wipe Head (Masah) Once',
      'titleAr': 'مسح الرأس',
      'descEn': 'Wet hands and wipe over your entire head once — moving from front hairline to the back of the neck, and back to front.',
      'arabicPhrase': '',
      'pronunciation': '',
      'translation': '',
      'image': 'assets/images/salat/wudu/8.png',
      'hadithArabic': 'مَسَحَ رَسُولُ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ بِرَأْسِهِ فَأَقْبَلَ بِيَدَيْهِ وَأَدْبَرَ',
      'hadithEnglish': 'The Messenger of Allah ﷺ wiped his head starting from the front to the back of his neck and back to where he started.',
      'ref': 'Sahih al-Bukhari 185, Sahih Muslim 235',
    },
    {
      'step': 8,
      'titleEn': 'Wipe Both Ears (Inside & Outside)',
      'titleAr': 'مسح الأذنين',
      'descEn': 'With the wet hands, insert index fingers into ear canals and wipe the outer ears with thumbs simultaneously.',
      'arabicPhrase': '',
      'pronunciation': '',
      'translation': '',
      'image': 'assets/images/salat/wudu/9.png',
      'hadithArabic': 'الأُذُنَانِ مِنَ الرَّأْسِ',
      'hadithEnglish': 'The two ears are considered part of the head.',
      'ref': 'Sunan Ibn Majah 443, Sunan Abu Dawood 134',
    },
    {
      'step': 9,
      'titleEn': 'Wash Feet to Ankles 3 Times',
      'titleAr': 'غسل القدمين إلى الكعبين',
      'descEn': 'Wash right foot up to and including ankles 3 times, washing between toes with pinky finger, then left foot.',
      'arabicPhrase': '',
      'pronunciation': '',
      'translation': '',
      'image': 'assets/images/salat/wudu/11.png',
      'hadithArabic': 'وَيْلٌ لِلأَعْقَابِ مِنَ النَّارِ',
      'hadithEnglish': 'Woe to the heels from the Hellfire! [Ensure ankles & heels are fully washed].',
      'ref': 'Sahih al-Bukhari 165, Sahih Muslim 241',
    },
    {
      'step': 10,
      'titleEn': 'Du\'a After Completing Wudu',
      'titleAr': 'الدعاء بعد الوضوء',
      'descEn': 'Look towards the sky and recite this authentic supplication to open the 8 gates of Paradise.',
      'arabicPhrase': 'أَشْهَدُ أَنْ لا إِلَهَ إِلاَّ اللَّهُ وَحْدَهُ لا شَرِيكَ لَهُ وَأَشْهَدُ أَنَّ مُحَمَّدًا عَبْدُهُ وَرَسُولُهُ\nاللَّهُمَّ اجْعَلْنِي مِنَ التَّوَّابِينَ وَاجْعَلْنِي مِنَ الْمُتَطَهِّرِينَ',
      'pronunciation': 'Ash-hadu alla ilaha illallahu wahdahu la shareeka lahu, wa ash-hadu anna Muhammadan \'abduhu wa rasooluh. Allahummaj-\'alnee minat-tawwabeena waj-\'alnee minal-mutatahhireen.',
      'translation': 'I bear witness that there is no deity worthy of worship except Allah alone without partner, and I bear witness that Muhammad is His slave and Messenger. O Allah, make me among those who repent and make me among those who purify themselves.',
      'image': 'assets/images/salat/wudu/12_3.png',
      'imageDark': 'assets/images/salat/wudu/12_4.png',
      'hadithArabic': 'فُتِحَتْ لَهُ أَبْوَابُ الْجَنَّةِ الثَّمَانِيَةُ يَدْخُلُ مِنْ أَيِّهَا شَاءَ',
      'hadithEnglish': 'The eight gates of Paradise will be opened for him to enter through whichever he wishes.',
      'ref': 'Sahih Muslim 234, Jami\' at-Tirmidhi 55',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? Colors.white : AppColors.navyBlue;
    final subColor = widget.isDark ? Colors.white60 : Colors.grey.shade600;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          icon: Icons.water_drop_rounded,
          iconColor: AppColors.midTeal,
          title: 'Purification (Wudu)',
          subtitle: 'Obligatory before every Salat',
          isDark: widget.isDark,
        ),
        const SizedBox(height: 10),
        _QuranRefCard(
          isDark: widget.isDark,
          arabicText: 'يَا أَيُّهَا الَّذِينَ آمَنُوا إِذَا قُمْتُمْ إِلَى الصَّلاةِ فَاغْسِلُوا وُجُوهَكُمْ وَأَيْدِيَكُمْ إِلَى الْمَرَافِقِ وَامْسَحُوا بِرُءُوسِكُمْ وَأَرْجُلَكُمْ إِلَى الْكَعْبَيْنِ',
          englishText: 'O you who have believed, when you rise to perform prayer, wash your faces and your forearms to the elbows and wipe over your heads and wash your feet to the ankles.',
          reference: "Surah Al-Ma'idah (5:6)",
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Step ${_currentStep + 1} of ${_wuduSteps.length}',
                style: GoogleFonts.poppins(
                    color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
            Text('Swipe →',
                style: GoogleFonts.inter(color: subColor, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / _wuduSteps.length,
            minHeight: 5,
            backgroundColor: widget.isDark ? Colors.white12 : Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.midTeal),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 440,
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: _wuduSteps.length,
            onPageChanged: (i) => setState(() => _currentStep = i),
            itemBuilder: (context, i) => _StepCard(
              step: _wuduSteps[i],
              isDark: widget.isDark,
              accentColor: AppColors.midTeal,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _DotIndicator(current: _currentStep, total: _wuduSteps.length, color: AppColors.midTeal, isDark: widget.isDark),
        const SizedBox(height: 10),
        _NavButtons(isDark: widget.isDark, currentStep: _currentStep, totalSteps: _wuduSteps.length, pageCtrl: _pageCtrl),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SALAT STEPS TAB
// ═══════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════
//  SALAT GUIDE TAB — Prayer Types + Full Schedule + Comparison
// ═══════════════════════════════════════════════════════════════════════════

class _SalatGuideTab extends StatelessWidget {
  final bool isDark;
  const _SalatGuideTab({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : AppColors.navyBlue;
    final subColor = isDark ? Colors.white60 : Colors.grey.shade600;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          icon: Icons.mosque_rounded,
          iconColor: isDark ? AppColors.midTeal : AppColors.navyBlue,
          title: 'Salat Guide',
          subtitle: 'Prayer types, schedules & authentic evidence',
          isDark: isDark,
        ),
        const SizedBox(height: 10),
        _QuranRefCard(
          isDark: isDark,
          arabicText: 'أَقِمِ الصَّلاةَ لِدُلُوكِ الشَّمْسِ إِلَى غَسَقِ اللَّيْلِ وَقُرْآنَ الْفَجْرِ إِنَّ قُرْآنَ الْفَجْرِ كَانَ مَشْهُودًا',
          englishText: 'Establish prayer from the decline of the sun until the darkness of the night and the Quran of dawn. Indeed, the recitation of dawn is ever witnessed.',
          reference: 'Surah Al-Isra (17:78)',
        ),
        const SizedBox(height: 14),
        // ── Prayer type legend ──────────────────────────────────────
        _CardBox(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardTitle(text: 'Types of Salah & Evidence', isDark: isDark),
              const SizedBox(height: 12),
              _PrayerTypeLegend(
                isDark: isDark, label: 'Fard — Obligatory', arabic: 'الفريضة',
                color: AppColors.navyBlue,
                description: 'Commanded directly by Allah. Skipping without valid excuse is a major sin. Praying in congregation for men earns 27× reward.',
                quranHadith: 'Quran 2:43 — "And establish prayer and give zakah..." | Hadith: "Islam is built on five..." (Bukhari 8)',
              ),
              _PrayerTypeLegend(
                isDark: isDark, label: 'Sunnah Muakkadah', arabic: 'السنة المؤكدة',
                color: AppColors.midTeal,
                description: 'Strongly emphasized Sunnah the Prophet ﷺ habitually prayed and rarely left. Highly recommended.',
                quranHadith: 'Hadith: "Whoever prays 12 rak\'ah daily (Sunnah), Allah builds for him a house in Jannah." (Muslim 728)',
              ),
              _PrayerTypeLegend(
                isDark: isDark, label: 'Sunnah Ghayr Muakkadah', arabic: 'السنة غير المؤكدة',
                color: AppColors.dustyBlueTeal,
                description: 'Voluntary Sunnah prayed intermittently by the Prophet ﷺ. Praiseworthy with great reward, no sin if left.',
                quranHadith: 'Hadith: "May Allah have mercy on the one who prays 4 rak\'ah before Asr." (Tirmidhi 430)',
              ),
              _PrayerTypeLegend(
                isDark: isDark, label: 'Nafl — Voluntary', arabic: 'النافلة',
                color: AppColors.coralOrange,
                description: 'Voluntary prayers performed for extra reward. They compensate for any deficiencies in Fard prayers on Qiyamah.',
                quranHadith: 'Hadith Qudsi: "My servant continues to draw near to Me with voluntary prayers until I love him." (Bukhari 6502)',
              ),
              _PrayerTypeLegend(
                isDark: isDark, label: 'Witr — Necessary', arabic: 'الوتر',
                color: const Color(0xFFB89445),
                description: 'Wajib (Hanafi) or strongly emphasized Sunnah (other schools). Prayed as the final odd prayer of the night.',
                quranHadith: 'Hadith: "Make Witr your last prayer at night." (Bukhari 998) | "Allah is Witr and loves Witr." (Tirmidhi 453)',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // ── Full per-Waqt breakdown ─────────────────────────────────
        _CardBox(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardTitle(text: "Complete Rak'ah Schedule", isDark: isDark),
              Text('All daily prayers for each waqt (time)', style: GoogleFonts.inter(color: subColor, fontSize: 11)),
              const SizedBox(height: 14),
              _WaqtPrayerCard(
                isDark: isDark, waqtName: 'Fajr', waqtAr: 'الفجر',
                waqtIcon: Icons.wb_twilight_rounded, totalRakaat: 4,
                rows: const [
                  _PrayerRow(type: 'Sunnah Muakkadah', typeColor: AppColors.midTeal, rakaat: 2, note: 'Before Fard — "Two rak\'ah of Fajr are better than the world and all it contains" (Muslim 725)'),
                  _PrayerRow(type: 'Fard', typeColor: AppColors.navyBlue, rakaat: 2, note: 'Obligatory — recited aloud by Imam in congregation'),
                ],
              ),
              const SizedBox(height: 10),
              _WaqtPrayerCard(
                isDark: isDark, waqtName: 'Dhuhr', waqtAr: 'الظهر',
                waqtIcon: Icons.wb_sunny_rounded, totalRakaat: 12,
                rows: const [
                  _PrayerRow(type: 'Sunnah Muakkadah', typeColor: AppColors.midTeal, rakaat: 4, note: 'Before Fard — "Whoever maintains 4 rak\'ah before and after Dhuhr, Allah forbids the fire from touching him" (Tirmidhi 428)'),
                  _PrayerRow(type: 'Fard', typeColor: AppColors.navyBlue, rakaat: 4, note: 'Obligatory — recited silently'),
                  _PrayerRow(type: 'Sunnah Muakkadah', typeColor: AppColors.midTeal, rakaat: 2, note: 'After Fard — strongly emphasized'),
                  _PrayerRow(type: 'Nafl', typeColor: AppColors.coralOrange, rakaat: 2, note: 'Optional after Sunnah for extra reward'),
                ],
              ),
              const SizedBox(height: 10),
              _WaqtPrayerCard(
                isDark: isDark, waqtName: 'Asr', waqtAr: 'العصر',
                waqtIcon: Icons.wb_cloudy_rounded, totalRakaat: 8,
                rows: const [
                  _PrayerRow(type: 'Sunnah Ghayr Muakkadah', typeColor: AppColors.dustyBlueTeal, rakaat: 4, note: 'Before Fard — "May Allah have mercy on the one who prays 4 rak\'ah before Asr" (Tirmidhi 430)'),
                  _PrayerRow(type: 'Fard', typeColor: AppColors.navyBlue, rakaat: 4, note: 'Obligatory — the "middle prayer" (Quran 2:238)'),
                ],
              ),
              const SizedBox(height: 10),
              _WaqtPrayerCard(
                isDark: isDark, waqtName: 'Maghrib', waqtAr: 'المغرب',
                waqtIcon: Icons.nightlight_round, totalRakaat: 9,
                rows: const [
                  _PrayerRow(type: 'Fard', typeColor: AppColors.navyBlue, rakaat: 3, note: 'Obligatory — recited aloud in first 2 rak\'ah'),
                  _PrayerRow(type: 'Sunnah Muakkadah', typeColor: AppColors.midTeal, rakaat: 2, note: 'After Fard — strongly emphasized by the Prophet ﷺ'),
                  _PrayerRow(type: 'Nafl (Awwaabeen)', typeColor: AppColors.coralOrange, rakaat: 4, note: 'Optional 4–6 Nafl after Maghrib = Awwaabeen prayer (Tirmidhi 435)'),
                ],
              ),
              const SizedBox(height: 10),
              _WaqtPrayerCard(
                isDark: isDark, waqtName: 'Isha', waqtAr: 'العشاء',
                waqtIcon: Icons.nightlight_round, totalRakaat: 15,
                rows: const [
                  _PrayerRow(type: 'Sunnah Ghayr Muakkadah', typeColor: AppColors.dustyBlueTeal, rakaat: 4, note: 'Before Fard — voluntary before obligatory prayer'),
                  _PrayerRow(type: 'Fard', typeColor: AppColors.navyBlue, rakaat: 4, note: 'Obligatory — recited aloud in first 2 rak\'ah'),
                  _PrayerRow(type: 'Sunnah Muakkadah', typeColor: AppColors.midTeal, rakaat: 2, note: 'After Fard — strongly emphasized'),
                  _PrayerRow(type: 'Nafl', typeColor: AppColors.coralOrange, rakaat: 2, note: 'Optional voluntary prayers'),
                  _PrayerRow(type: 'Witr', typeColor: Color(0xFFB89445), rakaat: 3, note: 'Wajib / Strongly emphasized — prayed as final night prayer before sleep (Bukhari 998)'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // ── Fard vs Sunnah comparison ───────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDark ? null : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.midTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.compare_arrows_rounded, color: AppColors.midTeal, size: 16),
                ),
                const SizedBox(width: 8),
                Text('Key Differences & Rules', style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
              ]),
              const SizedBox(height: 12),
              _DiffRow(isDark: isDark, label: 'Fard (Obligatory)', desc: 'Commanded directly by Allah. Omission without valid excuse is a major sin. Requires full concentration. Congregational prayer for men carries 27× reward.'),
              _DiffRow(isDark: isDark, label: 'Sunnah (Prophetic)', desc: 'Same physical method as Fard. Intention specifies Sunnah (e.g. "2 rak\'ah Sunnah of Fajr"). Muakkadah is close to obligatory, Ghayr Muakkadah is voluntary.'),
              _DiffRow(isDark: isDark, label: 'Nafl (Voluntary)', desc: 'Purely optional 2 rak\'ah units prayed anytime outside forbidden hours. Multiplies good deeds and fills gaps in Fard prayers on Judgment Day.'),
              _DiffRow(isDark: isDark, label: 'Witr (Night Concluder)', desc: 'Unique 3 rak\'ah structure ending with Dua Qunoot. Should be the final prayer before sleeping.'),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SALAT STEPS TAB
// ═══════════════════════════════════════════════════════════════════════════

class _SalatStepsTab extends StatefulWidget {
  final bool isDark;
  const _SalatStepsTab({required this.isDark});
  @override
  State<_SalatStepsTab> createState() => _SalatStepsTabState();
}

class _SalatStepsTabState extends State<_SalatStepsTab> {
  int _currentStep = 0;
  late PageController _pageCtrl;

  final List<Map<String, dynamic>> _steps = [
    {
      'step': 1,
      'position': 'Standing',
      'positionAr': 'القيام',
      'titleEn': 'Make Niyyah (Intention)',
      'titleAr': 'النية',
      'descEn': 'Stand upright facing Qibla. Intend in your heart which prayer you are about to perform for Allah.',
      'arabicPhrase': '',
      'pronunciation': '',
      'translation': '',
      'image': 'assets/images/salat/salat_steps/1.png',
      'hadithArabic': 'إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ وَإِنَّمَا لِكُلِّ امْرِئٍ مَا نَوَى',
      'hadithEnglish': 'Actions are according to intentions, and every person will get what he intended.',
      'ref': 'Sahih al-Bukhari 1, Sahih Muslim 1907',
    },
    {
      'step': 2,
      'position': 'Standing',
      'positionAr': 'تكبيرة الإحرام',
      'titleEn': 'Takbiratul Ihram',
      'titleAr': 'تكبيرة الإحرام',
      'descEn': 'Raise both hands to shoulders or ears with palms facing Qibla and say "Allahu Akbar".',
      'arabicPhrase': 'اللَّهُ أَكْبَرُ',
      'pronunciation': 'Allahu Akbar',
      'translation': 'Allah is the Greatest.',
      'image': 'assets/images/salat/salat_steps/2.png',
      'hadithArabic': 'مِفْتَاحُ الصَّلاةِ الطُّهُورُ وَتَحْرِيمُهَا التَّكْبِيرُ وَتَحْلِيلُهَا التَّسْلِيمُ',
      'hadithEnglish': 'The key to prayer is purification, its opening is Takbir, and its closing is Tasleem.',
      'ref': 'Sunan Abu Dawood 61, Jami\' at-Tirmidhi 3',
    },
    {
      'step': 3,
      'position': 'Standing',
      'positionAr': 'القيام',
      'titleEn': 'Place Hands Over Chest & Opening Du\'a',
      'titleAr': 'دعاء الاستفتاح',
      'descEn': 'Place right hand over left wrist on chest. Focus gaze on prostration spot. Recite opening Du\'a (Istiftah).',
      'arabicPhrase': 'سُبْحَانَكَ اللَّهُمَّ وَبِحَمْدِكَ وَتَبَارَكَ اسْمُكَ وَتَعَالَى جَدُّكَ وَلا إِلَهَ غَيْرُكَ',
      'pronunciation': 'Subhanakal-lahumma wa bihamdika wa tabarakasmuka wa ta\'ala jadduka wa la ilaha ghayruk.',
      'translation': 'How perfect You are, O Allah, and I praise You. Blessed is Your Name and Exalted is Your Majesty. There is no deity worthy of worship except You.',
      'image': 'assets/images/salat/salat_steps/3.png',
      'hadithArabic': 'كَانَ رَسُولُ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ إِذَا اسْتَفْتَحَ الصَّلاةَ قَالَ سُبْحَانَكَ اللَّهُمَّ...',
      'hadithEnglish': 'When the Messenger of Allah ﷺ started his prayer, he would say: Subhanakal-lahumma...',
      'ref': 'Sunan Abu Dawood 775, Jami\' at-Tirmidhi 243',
    },
    {
      'step': 4,
      'position': 'Standing — Recitation',
      'positionAr': 'قراءة الفاتحة',
      'titleEn': 'Recite Surah Al-Fatiha (Obligatory)',
      'titleAr': 'قراءة الفاتحة',
      'descEn': 'Recite Ta\'awwudh, Bismillah, then Surah Al-Fatiha. It is a pillar (Rukn) in every single rak\'ah.',
      'arabicPhrase': 'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ ۝ الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ ۝ الرَّحْمَنِ الرَّحِيمِ ۝ مَالِكِ يَوْمِ الدِّينِ ۝ إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ ۝ اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ ۝ صِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ الْمَغْضُوبِ عَلَيْهِمْ وَلا الضَّالِّينَ',
      'pronunciation': 'Bismillahir-Rahmanir-Raheem. Alhamdu lillahi Rabbil-\'alameen. Ar-Rahmanir-Raheem. Maliki Yawmid-Deen. Iyyaaka na\'budu wa iyyaaka nasta\'een. Ihdinas-siratal-mustaqeem. Siratal-latheena an\'amta \'alayhim, ghayril-maghdoobi \'alayhim walad-daalleen.',
      'translation': 'In the name of Allah, Most Gracious, Most Merciful. All praise is to Allah, Lord of the worlds. The Most Gracious, Most Merciful. Master of the Day of Judgement. You alone we worship and You alone we ask for help. Guide us to the straight path. The path of those You have blessed, not of those who have earned Your anger, nor of those who have gone astray.',
      'image': 'assets/images/salat/salat_steps/3.png',
      'hadithArabic': 'لا صَلاةَ لِمَنْ لَمْ يَقْرَأْ بِفَاتِحَةِ الْكِتَابِ',
      'hadithEnglish': 'There is no prayer for the one who does not recite the Opening of the Book (Al-Fatiha).',
      'ref': 'Sahih al-Bukhari 756, Sahih Muslim 394',
    },
    {
      'step': 5,
      'position': 'Ruku — Bowing',
      'positionAr': 'الركوع',
      'titleEn': 'Perform Ruku (Bowing)',
      'titleAr': 'الركوع',
      'descEn': 'Say Allahu Akbar, bow down keeping back level and straight, hands grasping knees. Recite Tasbih 3 times.',
      'arabicPhrase': 'سُبْحَانَ رَبِّيَ الْعَظِيمِ',
      'pronunciation': 'Subhana Rabbiyal-\'Adheem (3 times)',
      'translation': 'How perfect is my Lord, the Magnificent.',
      'image': 'assets/images/salat/salat_steps/4.png',
      'image2': 'assets/images/salat/salat_steps/5.png',
      'label1': 'Front View',
      'label2': 'Side View',
      'hadithArabic': 'فَأَمَّا الرُّكُوعُ فَعَظِّمُوا فِيهِ الرَّبَّ عَزَّ وَجَلَّ',
      'hadithEnglish': 'As for bowing, glorify the Lord Almighty in it.',
      'ref': 'Sahih Muslim 479',
    },
    {
      'step': 6,
      'position': 'Standing (I\'tidal)',
      'positionAr': 'الاعتدال',
      'titleEn': 'Rise From Ruku (I\'tidal)',
      'titleAr': 'الاعتدال بعد الركوع',
      'descEn': 'Rise up while saying "Sami\' Allahu liman hamidah". Once standing straight, say "Rabbana wa lakal hamd".',
      'arabicPhrase': 'سَمِعَ اللَّهُ لِمَنْ حَمِدَهُ \n رَبَّنَا وَلَكَ الْحَمْدُ',
      'pronunciation': 'Sami\'Allahu liman hamidah. \n Rabbana wa lakal-hamd.',
      'translation': 'Allah hears the one who praises Him. \n Our Lord, to You is all praise.',
      'image': 'assets/images/salat/salat_steps/1.png',
      'hadithArabic': 'إِذَا قَالَ الإِمَامُ سَمِعَ اللَّهُ لِمَنْ حَمِدَهُ فَقُولُوا رَبَّنَا وَلَكَ الْحَمْدُ',
      'hadithEnglish': 'When the Imam says Sami\' Allahu liman hamidah, say: Rabbana wa lakal-hamd.',
      'ref': 'Sahih al-Bukhari 796, Sahih Muslim 404',
    },
    {
      'step': 7,
      'position': 'Sujud — Prostration',
      'positionAr': 'السجود الأول',
      'titleEn': 'First Sujud (Prostration)',
      'titleAr': 'السجود',
      'descEn': 'Say Allahu Akbar and prostrate. 7 body parts must touch ground: forehead+nose, 2 palms, 2 knees, 2 toes.',
      'arabicPhrase': 'سُبْحَانَ رَبِّيَ الأَعْلَى',
      'pronunciation': 'Subhana Rabbiyal-A\'la (3 times)',
      'translation': 'How perfect is my Lord, the Most High.',
      'image': 'assets/images/salat/salat_steps/6.png',
      'image2': 'assets/images/salat/salat_steps/7.png',
      'label1': 'Back View',
      'label2': 'Side View',
      'hadithArabic': 'أُمِرْتُ أَنْ أَسْجُدَ عَلَى سَبْعَةِ أَعْظُمٍ: عَلَى الْجَبْهَةِ وَأَشَارَ بِيَدِهِ عَلَى أَنْفِهِ، وَالْيَدَيْنِ، وَالرُّكْبَتَيْنِ، وَأَطْرَافِ الْقَدَمَيْنِ',
      'hadithEnglish': 'I was commanded to prostrate on seven bones: the forehead (pointing to his nose), the two hands, two knees, and toes of both feet.',
      'ref': 'Sahih al-Bukhari 812, Sahih Muslim 490',
    },
    {
      'step': 8,
      'position': 'Sitting (Jalsa)',
      'positionAr': 'الجلسة بين السجدتين',
      'titleEn': 'Sitting Between Sujud',
      'titleAr': 'الجلسة',
      'descEn': 'Rise from sujud saying Allahu Akbar. Sit upright on left foot with right foot erect. Recite forgiveness du\'a.',
      'arabicPhrase': 'رَبِّ اغْفِرْ لِي ، رَبِّ اغْفِرْ لِي',
      'pronunciation': 'Rabbigh-fir lee, Rabbigh-fir lee.',
      'translation': 'O my Lord, forgive me. O my Lord, forgive me.',
      'image': 'assets/images/salat/salat_steps/8.png',
      'image2': 'assets/images/salat/salat_steps/9.png',
      'label1': 'Front View',
      'label2': 'Back View',
      'hadithArabic': 'كَانَ يَقُولُ بَيْنَ السَّجْدَتَيْنِ: رَبِّ اغْفِرْ لِي ، رَبِّ اغْفِرْ لِي',
      'hadithEnglish': 'The Prophet ﷺ used to say between the two prostrations: Rabbigh-fir lee...',
      'ref': 'Sunan Ibn Majah 897, Sunan Abu Dawood 874',
    },
    {
      'step': 9,
      'position': 'Sujud — Prostration',
      'positionAr': 'السجود الثاني',
      'titleEn': 'Second Sujud',
      'titleAr': 'السجود الثاني',
      'descEn': 'Say Allahu Akbar and perform second prostration identically. Repeat Tasbih 3 times. This completes 1 rak\'ah.',
      'arabicPhrase': 'سُبْحَانَ رَبِّيَ الأَعْلَى',
      'pronunciation': 'Subhana Rabbiyal-A\'la (3 times)',
      'translation': 'How perfect is my Lord, the Most High.',
      'image': 'assets/images/salat/salat_steps/7.png',
      'image2': 'assets/images/salat/salat_steps/6.png',
      'label1': 'Side View',
      'label2': 'Back View',
      'hadithArabic': 'ثُمَّ يَسْجُدُ الثَّانِيَةَ مِثْلَ الأُولَى',
      'hadithEnglish': 'Then he performs the second prostration just like the first.',
      'ref': 'Sahih al-Bukhari 789',
    },
    {
      'step': 10,
      'position': 'Sitting (Tashahud)',
      'positionAr': 'التشهد الأول',
      'titleEn': 'Tashahud (Sitting after 2nd Rak\'ah)',
      'titleAr': 'التشهد',
      'descEn': 'Sit on left foot after 2nd rak\'ah. Raise right index finger pointing to Qibla and recite Tashahud.',
      'arabicPhrase': 'التَّحِيَّاتُ لِلَّهِ وَالصَّلَوَاتُ وَالطَّيِّبَاتُ ، السَّلامُ عَلَيْكَ أَيُّهَا النَّبِيُّ وَرَحْمَةُ اللَّهِ وَبَرَكَاتُهُ ، السَّلامُ عَلَيْنَا وَعَلَى عِبَادِ اللَّهِ الصَّالِحِينَ ، أَشْهَدُ أَنْ لا إِلَهَ إِلاَّ اللَّهُ وَأَشْهَدُ أَنَّ مُحَمَّدًا عَبْدُهُ وَرَسُولُهُ',
      'pronunciation': 'At-Tahiyyatu lillahi was-salawatu wat-tayyibat. As-salamu \'alayka ayyuhan-Nabiyyu wa rahmatullahi wa barakatuh. As-salamu \'alayna wa \'ala \'ibadillahis-saliheen. Ash-hadu alla ilaha illallahu wa ash-hadu anna Muhammadan \'abduhu wa rasooluh.',
      'translation': 'All compliments, prayers, and pure words are due to Allah. Peace be upon you, O Prophet, and the mercy of Allah and His blessings. Peace be upon us and upon the righteous servants of Allah. I bear witness that there is no deity except Allah, and I bear witness that Muhammad is His slave and Messenger.',
      'image': 'assets/images/salat/salat_steps/10.png',
      'hadithArabic': 'إِذَا جَلَسْتُمْ فِي كُلِّ رَكْعَتَيْنِ فَقُولُوا التَّحِيَّاتُ لِلَّهِ...',
      'hadithEnglish': 'When you sit at the end of every two rak\'ah, say: At-Tahiyyatu lillahi...',
      'ref': 'Sahih al-Bukhari 831, Sahih Muslim 402',
    },
    {
      'step': 11,
      'position': 'Sitting — Final',
      'positionAr': 'الصلاة الإبراهيمية',
      'titleEn': 'Darood Ibrahim (Final Tashahud)',
      'titleAr': 'الصلاة الإبراهيمية',
      'descEn': 'In the final rak\'ah, after Tashahud, send blessings upon Prophet Muhammad ﷺ and Prophet Ibrahim AS.',
      'arabicPhrase': 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ كَمَا صَلَّيْتَ عَلَى إِبْرَاهِيمَ وَعَلَى آلِ إِبْرَاهِيمَ إِنَّكَ حَمِيدٌ مَجِيدٌ ، اللَّهُمَّ بَارِكْ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ كَمَا بَارَكْتَ عَلَى إِبْرَاهِيمَ وَعَلَى آلِ إِبْرَاهِيمَ إِنَّكَ حَمِيدٌ مَجِيدٌ',
      'pronunciation': 'Allahumma salli \'ala Muhammadin wa \'ala ali Muhammad, kama sallayta \'ala Ibraheema wa \'ala ali Ibraheem, innaka Hameedun Majeed. Allahumma barik \'ala Muhammadin wa \'ala ali Muhammad, kama barakta \'ala Ibraheema wa \'ala ali Ibraheem, innaka Hameedun Majeed.',
      'translation': 'O Allah, send prayers upon Muhammad and upon the family of Muhammad, as You sent prayers upon Ibrahim and the family of Ibrahim. Indeed, You are Praiseworthy and Full of Glory. O Allah, bless Muhammad and the family of Muhammad, as You blessed Ibrahim and the family of Ibrahim...',
      'image': 'assets/images/salat/salat_steps/8.png',
      'hadithArabic': 'قُولُوا اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ...',
      'hadithEnglish': 'Say: O Allah, send prayers upon Muhammad...',
      'ref': 'Sahih al-Bukhari 3370, Sahih Muslim 406',
    },
    {
      'step': 12,
      'position': 'Tasleem',
      'positionAr': 'التسليم',
      'titleEn': 'Tasleem — Conclude Prayer',
      'titleAr': 'التسليم',
      'descEn': 'Turn your head right saying "Assalamu \'alaykum wa rahmatullah", then turn left saying it again.',
      'arabicPhrase': 'السَّلامُ عَلَيْكُمْ وَرَحْمَةُ اللَّهِ',
      'pronunciation': 'As-salamu \'alaykum wa rahmatullah.',
      'translation': 'Peace and mercy of Allah be upon you.',
      'image': 'assets/images/salat/salat_steps/11.png',
      'image2': 'assets/images/salat/salat_steps/12.png',
      'label1': 'Right Salam ←',
      'label2': '→ Left Salam', 
      'hadithArabic': 'كَانَ يُسَلِّمُ عَنْ يَمِينِهِ وَعَنْ يَسَارِهِ حَتَّى يُرَى بَيَاضُ خَدِّهِ',
      'hadithEnglish': 'He ﷺ used to give tasleem to his right and left until the whiteness of his cheek could be seen.',
      'ref': 'Sahih Muslim 582, Sunan Abu Dawood 996',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? Colors.white : AppColors.navyBlue;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              _SectionHeader(
                icon: Icons.mosque_rounded,
                iconColor: AppColors.navyBlue,
                title: 'Prayer Steps',
                subtitle: 'Step-by-step according to authentic Sunnah',
                isDark: widget.isDark,
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Step ${_currentStep + 1} of ${_steps.length}',
                    style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const Spacer(),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.navyBlue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _steps[_currentStep]['position'],
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / _steps.length,
                  minHeight: 5,
                  backgroundColor: widget.isDark ? Colors.white12 : Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.navyBlue),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: _steps.length,
            onPageChanged: (i) => setState(() => _currentStep = i),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _StepCard(step: _steps[i], isDark: widget.isDark, accentColor: AppColors.navyBlue),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Column(
            children: [
              _DotIndicator(current: _currentStep, total: _steps.length, color: AppColors.navyBlue, isDark: widget.isDark),
              const SizedBox(height: 8),
              _NavButtons(isDark: widget.isDark, currentStep: _currentStep, totalSteps: _steps.length, pageCtrl: _pageCtrl),
            ],
          ),
        ),
      ],
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════
//  SHARED STEP CARD WIDGET (Solid Light Sky Blue Background for Image!)
// ═══════════════════════════════════════════════════════════════════════════

class _StepCard extends StatelessWidget {
  final Map<String, dynamic> step;
  final bool isDark;
  final Color accentColor;
  const _StepCard({required this.step, required this.isDark, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final String imagePath = (isDark && step.containsKey('imageDark') && (step['imageDark'] as String).isNotEmpty)
        ? step['imageDark'] as String
        : step['image'] as String;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: isDark
            ? Border.all(color: Colors.white.withValues(alpha: 0.16))
            : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          // Image container — sky blue in light, elegant dark gradient in dark mode
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: Container(
                decoration: BoxDecoration(
                  gradient: isDark
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF0D2137),
                            Color(0xFF1A3A52),
                            Color(0xFF0D2137),
                          ],
                        )
                      : const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFBAE6FD), // sky blue top
                            Color(0xFFE0F2FE), // lighter at bottom
                          ],
                        ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Single or dual image layout
                    if (step.containsKey('image2') && (step['image2'] as String).isNotEmpty)
                      // Side-by-side dual image
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.fromLTRB(10, 28, 4, 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: isDark ? 0.07 : 0.35),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.all(6),
                              child: _SafeImage(path: step['image'] as String, height: 120),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.fromLTRB(4, 28, 10, 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: isDark ? 0.07 : 0.35),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.all(6),
                              child: Transform.scale(
                                scale: 1.10,
                                child: _SafeImage(path: step['image2'] as String, height: 120),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      // Single image centered
                      Center(child: _SafeImage(path: imagePath, height: 155)),
                    // Step badge
                    Positioned(
                      top: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(16)),
                        child: Text('Step ${step['step']}', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ),
                    if (step.containsKey('positionAr') && (step['positionAr'] as String).isNotEmpty)
                      Positioned(
                        top: 8, right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppColors.navyBlue.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(10)),
                          child: Text(step['positionAr'], style: GoogleFonts.scheherazadeNew(color: Colors.white, fontSize: 12)),
                        ),
                      ),
                    // Dual image label when two images shown
                    if (step.containsKey('image2') && (step['image2'] as String).isNotEmpty)
                      Positioned(
                        bottom: 6,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _ImageLabel(
                              text: step.containsKey('label1') ? step['label1'] as String : 'View 1',
                              isDark: isDark,
                            ),
                            _ImageLabel(
                              text: step.containsKey('label2') ? step['label2'] as String : 'View 2',
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Scrollable details area
          Expanded(
            flex: 6,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(step['titleEn'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : AppColors.navyBlue))),
                      if (step.containsKey('titleAr') && (step['titleAr'] as String).isNotEmpty)
                        Text(step['titleAr'], style: GoogleFonts.scheherazadeNew(fontSize: 14, color: accentColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(step['descEn'], style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white70 : Colors.grey.shade700, height: 1.4)),
                  
                  if ((step['arabicPhrase'] as String).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.midTeal : AppColors.navyBlue).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: (isDark ? AppColors.midTeal : AppColors.navyBlue).withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(step['arabicPhrase'], textAlign: TextAlign.right, style: GoogleFonts.scheherazadeNew(fontSize: 16, color: isDark ? Colors.white : accentColor, height: 1.7)),
                          if ((step['pronunciation'] as String).isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Icon(Icons.record_voice_over_rounded, size: 12, color: isDark ? Colors.white54 : AppColors.navyBlue),
                              const SizedBox(width: 4),
                              Expanded(child: Text(step['pronunciation'], style: GoogleFonts.inter(fontSize: 10.5, color: isDark ? Colors.white70 : AppColors.navyBlue, fontWeight: FontWeight.w600, height: 1.3))),
                            ]),
                          ],
                          if ((step['translation'] as String).isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Icon(Icons.translate_rounded, size: 12, color: isDark ? Colors.white38 : Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Expanded(child: Text(step['translation'], style: GoogleFonts.inter(fontSize: 10, color: isDark ? Colors.white60 : Colors.grey.shade700, fontStyle: FontStyle.italic, height: 1.3))),
                            ]),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // Full Hadith Citation Box
                  if (step.containsKey('hadithArabic') && (step['hadithArabic'] as String).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.coralOrange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.coralOrange.withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_stories_rounded, size: 12, color: AppColors.coralOrange),
                              const SizedBox(width: 4),
                              Expanded(child: Text(step['ref'], style: GoogleFonts.inter(fontSize: 10, color: AppColors.coralOrange, fontWeight: FontWeight.bold))),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(step['hadithArabic'], textAlign: TextAlign.right, style: GoogleFonts.scheherazadeNew(fontSize: 14, color: isDark ? Colors.white : AppColors.navyBlue)),
                          const SizedBox(height: 2),
                          Text('"${step['hadithEnglish']}"', style: GoogleFonts.inter(fontSize: 10, color: isDark ? Colors.white70 : Colors.grey.shade700, fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════
//  RULES TAB
// ═══════════════════════════════════════════════════════════════════════════

class _RulesTab extends StatelessWidget {
  final bool isDark;
  const _RulesTab({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : AppColors.navyBlue;
    final subColor = isDark ? Colors.white60 : Colors.grey.shade600;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          icon: Icons.verified_rounded,
          iconColor: AppColors.midTeal,
          title: 'Conditions Before Prayer',
          subtitle: 'Prerequisites that must be fulfilled',
          isDark: isDark,
        ),
        const SizedBox(height: 10),
        _QuranRefCard(
          isDark: isDark,
          arabicText: 'حَافِظُوا عَلَى الصَّلَوَاتِ وَالصَّلاةِ الْوُسْطَى وَقُومُوا لِلَّهِ قَانِتِينَ',
          englishText: 'Maintain with care the [obligatory] prayers and [in particular] the middle prayer and stand before Allah devoutly obedient.',
          reference: 'Surah Al-Baqarah (2:238)',
        ),
        const SizedBox(height: 14),
        _RuleSectionCard(
          isDark: isDark,
          icon: Icons.water_drop_rounded,
          title: 'Purification (Taharah)',
          titleAr: 'الطهارة',
          color: AppColors.midTeal,
          bullets: const [
            'Body, clothes, and place of prayer must be free from filth (najasah)',
            'Wudu is required for every prayer unless tayammum is performed',
            'Ghusl is required after major ritual impurity (janabah)',
          ],
          hadithArabic: 'لَا تُقْبَلُ صَلَاةُ أَحَدِكُمْ إِذَا أَحْدَثَ حَتَّى يَتَوَضَّأَ',
          hadithEnglish: 'The prayer of none of you will be accepted if he breaks wudu until he performs it again.',
          hadithRef: 'Quran 5:6 & Sahih al-Bukhari 135',
        ),
        const SizedBox(height: 14),
        _RuleSectionCard(
          isDark: isDark,
          icon: Icons.accessibility_new_rounded,
          title: 'Covering the Awrah',
          titleAr: 'ستر العورة',
          color: AppColors.navyBlue,
          bullets: const [
            'Men: navel to below the knee must be covered',
            'Women: entire body except face and hands in prayer',
            'Clothing must not be transparent or overly tight',
          ],
          hadithArabic: 'لا يَقْبَلُ اللَّهُ صَلاةَ حَائِضٍ إِلاَّ بِخِمَارٍ',
          hadithEnglish: 'Allah does not accept the prayer of an adult woman unless she wears a veil.',
          hadithRef: 'Sahih Abu Dawood 641, Quran 7:31',
        ),
        const SizedBox(height: 14),
        _RuleSectionCard(
          isDark: isDark,
          icon: Icons.explore_rounded,
          title: 'Facing the Qibla',
          titleAr: 'استقبال القبلة',
          color: AppColors.midTeal,
          bullets: const [
            "Face direction of Ka'bah in Makkah",
            'If Qibla is unknown after best effort, prayer is still valid',
            'Slight deviation is forgiven if genuine effort was made to face it',
          ],
        ),
        const SizedBox(height: 14),
        _RuleSectionCard(
          isDark: isDark,
          icon: Icons.access_time_filled_rounded,
          title: 'Prayer Time Must Have Entered',
          titleAr: 'دخول الوقت',
          color: AppColors.navyBlue,
          bullets: const [
            'Each prayer has a fixed prescribed time — praying before time is not valid',
            'Fajr: true dawn until sunrise',
            'Dhuhr: sun decline until Asr time',
            'Asr: until sun turns orange/yellow',
            'Maghrib: sunset until twilight disappears',
            'Isha: twilight disappears until midnight',
          ],
          hadithArabic: 'إِنَّ لِلصَّلاةِ أَوَّلاً وَآخِرًا',
          hadithEnglish: 'Indeed, prayer has a beginning time and an ending time.',
          hadithRef: 'Quran 4:103',
        ),
        const SizedBox(height: 14),
        // ── Pillars of Prayer (Arkan) ─────────────────────────────
        _CardBox(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.coralOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.flag_rounded, color: AppColors.coralOrange, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pillars of Prayer (Arkan)',
                            style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('Obligatory acts — if missed, prayer is invalid',
                            style: GoogleFonts.inter(color: subColor, fontSize: 10.5)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...[
                'Intention (Niyyah)',
                'Standing (Qiyam) if able — Quran 2:238',
                'Opening Takbir: "Allahu Akbar" — Sahih al-Bukhari 700',
                "Recitation of Surah Al-Fatiha in every rak'ah — Sahih al-Bukhari 756",
                'Ruku (bowing) — Quran 22:77',
                "Rising from Ruku (I'tidal) — Sahih Muslim 498",
                "Two Sujud (prostrations) per rak'ah — Sahih al-Bukhari 812",
                'Final Tashahud — Sahih al-Bukhari 831',
                'Tasleem to conclude — Sahih Muslim 582',
                "Tranquility (Tuma'ninah) in every pillar — Sahih al-Bukhari 793",
                'Performing prayer in correct order',
              ].asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 15,
                          height: 15,
                          decoration: const BoxDecoration(color: AppColors.coralOrange, shape: BoxShape.circle),
                          child: Center(
                            child: Text('${e.key + 1}',
                                style: GoogleFonts.poppins(color: Colors.white, fontSize: 7.5, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(e.value,
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: isDark ? Colors.white70 : Colors.grey.shade800, height: 1.4)),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // ── Sunnah Acts Within Prayer ─────────────────────────────
        _CardBox(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.midTeal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.radio_button_unchecked_rounded, color: AppColors.midTeal, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sunnah Acts Within Prayer',
                            style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('Highly recommended acts', style: GoogleFonts.inter(color: subColor, fontSize: 10.5)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._bulletList(const [
                "Opening du'a (Dua al-Istiftah) after first Takbir",
                "Seeking refuge from Shaytan (Ta'awwudh) before Fatiha",
                'Saying Ameen after Fatiha',
                "Reciting additional surahs after Fatiha (in first two rak'ah)",
                "Raising hands (Raf' al-Yadayn) at Takbir, Ruku, and rising from Ruku",
                'Looking down at place of prostration',
                'Keeping back straight/flat in ruku',
                "Extending Sujud du'a with personal supplications",
                'Reciting Salawat (Darood Ibrahim) in every Tashahud',
                'Post-prayer dhikr: 33× SubhanAllah, 33× Alhamdulillah, 33× Allahu Akbar',
              ], AppColors.midTeal, isDark),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // ── Things That Invalidate Prayer (Mubtilat) ──────────────
        _CardBox(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.cancel_rounded, color: Colors.red.shade400, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Things That Invalidate Prayer (Mubtilat)',
                            style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('If any occur, prayer must be restarted',
                            style: GoogleFonts.inter(color: subColor, fontSize: 10.5)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._bulletList(const [
                'Intentional speech (other than remembrance of Allah) — Sahih Muslim 537',
                'Excessive unnecessary movement',
                'Breaking wudu (passing wind, etc.)',
                'Laughing audibly',
                'Leaving out any Rukn (pillar) intentionally',
                'Intentionally eating or drinking',
                'Turning chest away from Qibla without necessity',
              ], Colors.red.shade400, isDark),
              const SizedBox(height: 10),
              _HadithCard(
                isDark: isDark,
                arabicText: 'صَلُّوا كَمَا رَأَيْتُمُونِي أُصَلِّي',
                englishText: 'Pray as you have seen me praying.',
                reference: 'Sahih al-Bukhari 631 — Prophet Muhammad ﷺ',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  List<Widget> _bulletList(List<String> items, Color dotColor, bool isDark) {
    return items
        .map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                        width: 6, height: 6, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(t,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: isDark ? Colors.white70 : Colors.grey.shade800, height: 1.4)),
                  ),
                ],
              ),
            ))
        .toList();
  }
}

class _RuleSectionCard extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String title, titleAr;
  final Color color;
  final List<String> bullets;
  final String? hadithArabic, hadithEnglish, hadithRef;

  const _RuleSectionCard({
    required this.isDark,
    required this.icon,
    required this.title,
    required this.titleAr,
    required this.color,
    required this.bullets,
    this.hadithArabic,
    this.hadithEnglish,
    this.hadithRef,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : AppColors.navyBlue;
    final subColor = isDark ? Colors.white70 : Colors.grey.shade700;
    final headerColor = AppColors.navyBlue;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.10) : AppColors.navyBlue.withValues(alpha: 0.18)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: Icon(icon, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                Text(titleAr, style: GoogleFonts.scheherazadeNew(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...bullets.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.midTeal, shape: BoxShape.circle)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(t, style: GoogleFonts.inter(fontSize: 12, color: subColor, height: 1.4))),
                        ],
                      ),
                    )),
                if (hadithArabic != null && hadithArabic!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.midTeal.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.midTeal.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(hadithArabic!,
                            textAlign: TextAlign.right,
                            style: GoogleFonts.scheherazadeNew(fontSize: 15, color: textColor, height: 1.6)),
                        const SizedBox(height: 6),
                        Text('"$hadithEnglish"',
                            style: GoogleFonts.inter(fontSize: 11, color: subColor, fontStyle: FontStyle.italic, height: 1.4)),
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.menu_book_rounded, size: 11, color: AppColors.midTeal),
                          const SizedBox(width: 4),
                          Expanded(
                              child: Text(hadithRef ?? '',
                                  style: GoogleFonts.inter(fontSize: 10, color: AppColors.midTeal, fontStyle: FontStyle.italic))),
                        ]),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}



// ═══════════════════════════════════════════════════════════════════════════
//  OTHER SALATS TAB
// ═══════════════════════════════════════════════════════════════════════════

class _OtherSalatsTab extends StatelessWidget {
  final bool isDark;
  const _OtherSalatsTab({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          icon: Icons.auto_awesome_rounded,
          iconColor: AppColors.navyBlue,
          title: 'Special & Voluntary Salats',
          subtitle: 'Tahajjud, Qasr, Istikhara, Jummah, Janazah & more',
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        // 1. Tahajjud (Night Prayer)
        _SpecialPrayerCard(
          isDark: isDark,
          icon: Icons.nights_stay_rounded,
          title: 'Tahajjud (Night Vigil Prayer)',
          titleAr: 'صلاة التهجد',
          color: AppColors.navyBlue,
          quranText: 'وَمِنَ اللَّيْلِ فَتَهَجَّدْ بِهِ نَافِلَةً لَّكَ عَسَىٰ أَن يَبْعَثَكَ رَبُّكَ مَقَامًا مَّحْمُودًا',
          quranRef: 'Surah Al-Isra (17:79)',
          quranEn: 'And from [part of] the night, pray with it as additional [worship] for you; it may be that your Lord will raise you to a praised station.',
          hadithText: 'أَفْضَلُ الصَّلَاةِ بَعْدَ الْفَرِيضَةِ صَلَاةُ اللَّيْلِ',
          hadithEn: 'The most virtuous prayer after the obligatory prayer is the night prayer.',
          hadithRef: 'Sahih Muslim 1163',
          steps: [
            'Set an alarm for the last third of the night — approximately 90 minutes before Fajr. The Prophet ﷺ said the Lord descends to the lowest heaven in this time.',
            'Wake up, make wudu with calm intention, and face the Qibla',
            'Begin with 2 light rak\'ah to open the prayer (as the Prophet ﷺ did, reciting short surahs to awaken the body)',
            'Then pray in sets of 2 rak\'ah — you may pray 2, 4, 6, 8 or up to 12 rak\'ah total',
            'In each rak\'ah: recite long Quranic passages slowly and with reflection — do not rush',
            'Perform slow, prolonged Ruku saying "Subhana Rabbiyyal-Adheem" many times',
            'Rise, then go into long Sujud saying "Subhana Rabbiyyal-A\'la" extensively — this is when you are closest to Allah',
            'Between the two Sajdahs, make sincere du\'a in Arabic or your own language',
            'Conclude with Witr: pray 1 or 3 rak\'ah. In the final rak\'ah before ruku recite Qunoot du\'a',
            'After Witr, sit and make heartfelt du\'a and Istighfar until Fajr time'
          ],
        ),
        const SizedBox(height: 14),
        // 2. Qasr & Jam' (Traveler Prayer)
        _SpecialPrayerCard(
          isDark: isDark,
          icon: Icons.flight_takeoff_rounded,
          title: 'Qasr (Shortened Traveler Prayer)',
          titleAr: 'صلاة القصر والجمع',
          color: AppColors.midTeal,
          quranText: 'وَإِذَا ضَرَبْتُمْ فِي الْأَرْضِ فَلَيْسَ عَلَيْكُمْ جُنَاحٌ أَن تَقْصُرُوا مِنَ الصَّلَاةِ',
          quranRef: 'Surah An-Nisa (4:101)',
          quranEn: 'And when you travel throughout the land, there is no blame upon you for shortening the prayer...',
          hadithText: 'صَدَقَةٌ تصَدَّقَ اللَّهُ بِهَا عَلَيْكُمْ فَاقْبَلُوا صَدَقَتَهُ',
          hadithEn: 'It is a charity that Allah has bestowed upon you, so accept His charity.',
          hadithRef: 'Sahih Muslim 686',
          steps: [
            'CONDITION — Travel distance must be approximately 80 km (48 miles) or more from your city boundary',
            'CONDITION — You must be in a state of travel (musafir); once you reach your destination or intend to stay 4+ days, Qasr ends',
            'QASR — Shorten 4-rak\'ah Fard prayers to 2 rak\'ah: Dhuhr becomes 2, Asr becomes 2, Isha becomes 2',
            'NOT SHORTENED — Fajr (2 rak\'ah) and Maghrib (3 rak\'ah) always remain the same',
            'SUNNAH during travel — The Prophet ﷺ would sometimes pray Sunnah prayers during travel and sometimes omit them; it is permissible to leave Sunnah Rawatib while traveling',
            'JAM\' TAQDEEM (combining early) — Pray Dhuhr and Asr together at Dhuhr time, OR Maghrib and Isha together at Maghrib time',
            'JAM\' TA\'KHEER (combining late) — Delay Dhuhr and pray it with Asr at Asr time, OR delay Maghrib and pray it with Isha at Isha time',
            'When combining, make Niyyah (intention) for Jam\' before or during the first prayer',
            'It is Sunnah to announce the Adhan for the first prayer and Iqamah for both when combining'
          ],
        ),
        const SizedBox(height: 14),
        // 3. Salatul Istikhara
        _SpecialPrayerCard(
          isDark: isDark,
          icon: Icons.psychology_rounded,
          title: 'Salatul Istikhara (Guidance Prayer)',
          titleAr: 'صلاة الاستخارة',
          color: AppColors.dustyBlueTeal,
          quranText: 'وَشَاوِرْهُمْ فِي الْأَمْرِ ۖ فَإِذَا عَزَمْتَ فَتَوَكَّلْ عَلَى اللَّهِ',
          quranRef: 'Surah Ali \'Imran (3:159)',
          quranEn: 'And consult them in the matter. And when you have decided, then rely upon Allah.',
          hadithText: 'كَانَ رَسُولُ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ يُعَلِّمُنَا الِاسْتِخَارَةَ فِي الْأُمُورِ كُلِّهَا كَمَا يُعَلِّمُنَا السُّورَةَ مِنَ الْقُرْآنِ',
          hadithEn: 'The Messenger of Allah ﷺ used to teach us Istikhara in all matters just as he taught us a Surah of the Quran.',
          hadithRef: 'Sahih al-Bukhari 1166',
          steps: [
            'Ensure you are in a state of wudu and ritual purity',
            'Choose any permitted time — avoid the three forbidden times (sunrise, midday zenith, sunset)',
            'Make sincere Niyyah (intention) for 2 rak\'ah Nafl Salatul Istikhara',
            '1st Rak\'ah: After Al-Fatiha, recite Surah Al-Kafirun (recommended by scholars)',
            '2nd Rak\'ah: After Al-Fatiha, recite Surah Al-Ikhlas (recommended)',
            'Complete the prayer fully with Tashahhud and Tasleem',
            'Immediately after Tasleem, while still sitting, recite the Du\'a of Istikhara',
            'In the du\'a, when you reach the words "haadhal-amr" (this matter), pause and name your specific decision in your heart',
            'Do NOT wait for a dream — proceed with whichever option your heart inclines toward after sincere du\'a',
            'Repeat the prayer over multiple days if needed. Trust that Allah will make the good option easy and the harmful one difficult'
          ],
          extraDua: 'اللَّهُمَّ إِنِّي أَسْتَخِيرُكَ بِعِلْمِكَ وَأَسْتَقْدِرُكَ بِقُدْرَتِكَ وَأَسْأَلُكَ مِنْ فَضْلِكَ الْعَظِيمِ ، فَإِنَّكَ تَقْدِرُ وَلا أَقْدِرُ وَتَعْلَمُ وَلا أَعْلَمُ وَأَنْتَ عَلامُ الْغُيُوبِ ، اللَّهُمَّ إِنْ كُنْتَ تَعْلَمُ أَنَّ هَذَا الأَمْرَ خَيْرٌ لِي فِي دِينِي وَمَعَاشِي وَعَاقِبَةِ أَمْرِي فَاقْدُرْهُ لِي وَيَسِّرْهُ لِي ثُمَّ بَارِكْ لِي فِيهِ ، وَإِنْ كُنْتَ تَعْلَمُ أَنَّ هَذَا الأَمْرَ شَرٌّ لِي فِي دِينِي وَمَعَاشِي وَعَاقِبَةِ أَمْرِي فَاصْرِفْهُ عَنِّي وَاصْرِفْنِي عَنْهُ وَاقْدُرْ لِيَ الْخَيْرَ حَيْثُ كَانَ ثُمَّ أَرْضِنِي بِهِ',
          extraDuaPronunciation: 'Allahumma innee astakheeruka bi \'ilmika wa astaqdiruka bi qudratika wa as\'aluka min fadlikal-\'adheem, fa innaka taqdiru wa la aqdir, wa ta\'lamu wa la a\'lam, wa anta \'allamul-ghuyoob. Allahumma in kunta ta\'lamu anna hadhal-amra khayrun li fi deeni wa ma\'ashi wa \'aqibati amri faqdurhu li wa yassirhu li thumma barik li fihi, wa in kunta ta\'lamu anna hadhal-amra sharrun li fi deeni wa ma\'ashi wa \'aqibati amri fasrifhu \'annee wasrifnee \'anhu waqdur liyal-khayra haythu kana thumma ardinee bih.',
          extraDuaEn: 'O Allah, I seek Your guidance through Your knowledge, and I seek ability through Your power, and I ask You from Your great favor. You are able while I am not, and You know while I do not, and You are the Knower of the unseen. O Allah, if You know that this matter is good for me in my religion, my livelihood, and the outcome of my affairs, then ordain it for me, make it easy for me, and bless me in it. And if You know that this matter is bad for me in my religion, my livelihood, and the outcome of my affairs, then turn it away from me and turn me away from it, and ordain for me what is good wherever it may be, and make me content with it.',
          extraDuaRef: 'Sahih al-Bukhari 1166',
        ),
        const SizedBox(height: 14),
        // 4. Salatul Hajat
        _SpecialPrayerCard(
          isDark: isDark,
          icon: Icons.favorite_rounded,
          title: 'Salatul Hajat (Prayer of Need)',
          titleAr: 'صلاة الحاجة',
          color: AppColors.navyBlue,
          quranText: 'وَاسْتَعِينُوا بِالصَّبْرِ وَالصَّلَاةِ',
          quranRef: 'Surah Al-Baqarah (2:45)',
          quranEn: 'And seek help through patience and prayer...',
          hadithText: 'مَنْ كَانَتْ لَهُ إِلَى اللَّهِ حَاجَةٌ أَوْ إِلَى أَحَدٍ مِنْ بَنِي آدَمَ فَلْيَتَوَضَّأْ وَلْيُحْسِنِ الْوُضُوءَ ثُمَّ لِيُصَلِّ رَكْعَتَيْنِ',
          hadithEn: 'Whoever has a need from Allah or from any human being, let him perform wudu thoroughly and pray two rak\'ah.',
          hadithRef: 'Jami\' at-Tirmidhi 479, Sunan Ibn Majah 1384',
          steps: [
            'Perform thorough, careful wudu as the Hadith specifically says "yuḥsin al-wudu" (perfect the wudu)',
            'Find a quiet place and face the Qibla with absolute sincerity and humility',
            'Make Niyyah for 2 rak\'ah Nafl Salatul Hajat',
            '1st Rak\'ah: Recite Al-Fatiha + any Surah (Surah Al-Kafirun is recommended)',
            '2nd Rak\'ah: Recite Al-Fatiha + Surah Al-Ikhlas. Complete with full Ruku and Sujud',
            'After Tasleem, first praise and glorify Allah (say Subhanallah, Alhamdulillah, Allahu Akbar)',
            'Then recite Salawat (Darood Ibrahim) upon the Prophet ﷺ',
            'Now make sincere du\'a stating your need clearly to Allah with full conviction He will answer',
            'The Prophet ﷺ taught a specific Du\'a: "La ilaha illa Allahul-Haleemul-Kareem, subhanallahi Rabbil-\'arshil-\'adheem..." before asking your need',
            'Repeat this salah regularly when facing a difficulty — do not be hasty in expecting the answer'
          ],
        ),
        const SizedBox(height: 14),
        // 5. Salatul Tawbah
        _SpecialPrayerCard(
          isDark: isDark,
          icon: Icons.cleaning_services_rounded,
          title: 'Salatul Tawbah (Repentance Prayer)',
          titleAr: 'صلاة التوبة',
          color: AppColors.navyBlue,
          quranText: 'وَتُوبُوا إِلَى اللَّهِ جَمِيعًا أَيُّهَ الْمُؤْمِنُونَ لَعَلَّكُمْ تُفْلِحُونَ',
          quranRef: 'Surah An-Nur (24:31)',
          quranEn: 'And turn to Allah in repentance, all of you, O believers, that you might succeed.',
          hadithText: 'مَا مِنْ عَبْدٍ يُذْنِبُ ذَنْبًا فَيُحْسِنُ الطُّهُورَ ثُمَّ يَقُومُ فَيُصَلِّي رَكْعَتَيْنِ ثُمَّ يَسْتَغْفِرُ اللَّهَ إِلَّا غَفَرَ اللَّهُ لَهُ',
          hadithEn: 'There is no servant who commits a sin, then purifies himself well, stands and prays two rak\'ah, then asks Allah for forgiveness, except that Allah forgives him.',
          hadithRef: 'Sunan Abu Dawood 1521, Jami\' at-Tirmidhi 406',
          steps: [
            'As soon as you sin, immediately feel remorse and turn to Allah — do not delay',
            'Perform wudu carefully; wudu itself washes away minor sins as water flows over each limb',
            'Pray 2 rak\'ah alone in private, with your heart fully present and broken before Allah',
            '1st Rak\'ah: Recite Al-Fatiha + Surah Al-Kafirun (renouncing sin)',
            '2nd Rak\'ah: Recite Al-Fatiha + Surah Al-Ikhlas. Complete with full sincerity',
            'In Sujud: Stay long and weep or try to weep — say "Rabbi inni dhalamtu nafsi" (My Lord, I have wronged myself)',
            'After Tasleem: Recite Istighfar abundantly — "Astaghfirullaha wa atoobu ilayh" at least 70 times',
            'Make a firm, sincere, heartfelt resolution (Azm) to NEVER return to that sin',
            'If the sin involved wronging another person, seek their forgiveness and make restitution',
            'THREE conditions of valid Tawbah: (1) Stop the sin, (2) Feel genuine remorse, (3) Resolve never to return'
          ],
        ),
        const SizedBox(height: 14),
        // 6. Salatul Ishraq & Duha
        _SpecialPrayerCard(
          isDark: isDark,
          icon: Icons.wb_sunny_rounded,
          title: 'Ishraq & Duha (Forenoon Prayer)',
          titleAr: 'صلاة الإشراق والضحى',
          color: AppColors.navyBlue,
          quranText: 'إِنَّا سَخَّرْنَا الْجِبَالَ مَعَهُ يُسَبِّحْنَ بِالْعَشِيِّ وَالْإِشْرَاقِ',
          quranRef: 'Surah Sad (38:18)',
          quranEn: 'Indeed, We subjected the mountains to praise with him in the evening and at sunrise.',
          hadithText: 'يُصْبِحُ عَلَى كُلِّ سُلَامَى مِنْ أَحَدِكُمْ صَدَقَةٌ... وَيُجْزِئُ مِنْ ذَلِكَ رَكْعَتَانِ يَرْكَعُهُمَا مِنَ الضحَى',
          hadithEn: 'Every joint of your body owes charity each day... two rak\'ah of Duha prayer suffices for all of them.',
          hadithRef: 'Sahih Muslim 720',
          steps: [
            'ISHRAQ TIME — Approximately 15-20 minutes after sunrise (when the sun has risen about a spear\'s height)',
            'ISHRAQ METHOD — Sit in your place of Fajr prayer doing Dhikr from Fajr until Ishraq time. Then pray 2 rak\'ah. The Prophet ﷺ said this earns the reward of a complete Hajj and Umrah',
            'DUHA TIME — From about 20 minutes after sunrise until approximately 15 minutes before the Dhuhr Adhan',
            'DUHA RAKAAT — Minimum is 2 rak\'ah. You may pray 4, 6, 8, or up to 12 rak\'ah in pairs of 2',
            '1st Rak\'ah of each pair: Al-Fatiha + Surah Ash-Shams or any Surah',
            '2nd Rak\'ah of each pair: Al-Fatiha + Surah Ad-Duha or any Surah',
            'Each set of 2 is completed with full Ruku, Sujud, Tashahhud, and Tasleem',
            'Du\'a of Duha: "Allahumma innad-duha duhauk, wal-baha\'a baha\'uk..." (ask Allah for sustenance and blessings)',
            'Reward: 360 sadaqahs (charities) are fulfilled for your joints each day, two rak\'ah of Duha suffice for all'
          ],
        ),
        const SizedBox(height: 14),
        // 7. Salatul Kusuf & Khusuf (Eclipse)
        _SpecialPrayerCard(
          isDark: isDark,
          icon: Icons.brightness_medium_rounded,
          title: 'Kusuf & Khusuf (Eclipse Prayer)',
          titleAr: 'صلاة الكسوف والخسوف',
          color: AppColors.navyBlue,
          quranText: 'وَمِنْ آيَاتِهِ اللَّيْلُ وَالنَّهَارُ وَالشَّمْسُ وَالْقَمَرُ ۚ لَا تَسْجُدُوا لِلشَّمْسِ وَلَا لِلْقَمَرِ',
          quranRef: 'Surah Fussilat (41:37)',
          quranEn: 'And among His signs are the night and day and the sun and moon. Do not prostrate to the sun or moon, but prostrate to Allah...',
          hadithText: 'إِنَّ الشَّمْسَ وَالْقَمَرَ آيَتَانِ مِنْ آيَاتِ اللَّهِ لَا يَخْسِفَانِ لِمَوْتِ أَحَدٍ... فَإِذَا رَأَيْتُمُوهُمَا فَادْعُوا اللَّهَ وَصَلُّوا',
          hadithEn: 'The sun and moon are two signs of Allah... when you see an eclipse, invoke Allah and pray.',
          hadithRef: 'Sahih al-Bukhari 1040, Sahih Muslim 901',
          steps: [
            'Kusuf = Solar Eclipse | Khusuf = Lunar Eclipse. Both are prayed the same way',
            'Adhan is NOT called — instead announce "Assalatu Jami\'ah" (prayer in congregation)',
            'Pray in congregation in the masjid or pray individually at home',
            '1st RAK\'AH — Stand and recite a LONG portion of Quran (e.g., Surah Al-Baqarah or similar)',
            '1st RAK\'AH — Go into Ruku and stay for a VERY LONG time saying "Subhana Rabbiyyal-Adheem"',
            '1st RAK\'AH — Rise from Ruku (I\'tidal), then recite ANOTHER long Quranic passage',
            '1st RAK\'AH — Go into a 2nd Ruku (also long), then rise, then perform 2 prolonged Sujuds',
            '2nd RAK\'AH — Repeat the same: 2 long Qiyam, 2 long Ruku, and 2 long Sujud',
            'After prayer the Imam delivers a Khutbah urging Dhikr, Istighfar, sadaqah, and freeing slaves (if applicable)',
            'Continue prayer until the eclipse fully clears. The Prophet ﷺ prayed until the eclipse ended'
          ],
        ),
        const SizedBox(height: 14),
        // 8. Salatul Istisqa (Rain)
        _SpecialPrayerCard(
          isDark: isDark,
          icon: Icons.water_drop_rounded,
          title: 'Salatul Istisqa (Rain Prayer)',
          titleAr: 'صلاة الاستسقاء',
          color: AppColors.dustyBlueTeal,
          quranText: 'فَقُلْتُ اسْتَغْفِرُوا رَبَّكُمْ إِنَّهُ كَانَ غَفَّارًا ۝ يُرْسِلِ السَّمَاءَ عَلَيْكُم مِّدْرَارًا',
          quranRef: 'Surah Nuh (71:10-11)',
          quranEn: 'And I said: Ask forgiveness of your Lord. Indeed, He is ever a Perpetual Forgiver. He will send rain from the sky upon you in abundance.',
          hadithText: 'خَرَجَ النَّبِيُّ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ مُتَبَذِّلاً مُتَوَاضِعًا مُتَضَرِّعًا حَتَّى أَتَى الْمُصَلَّى فَصَلَّى رَكْعَتَيْنِ',
          hadithEn: 'The Prophet ﷺ went out humbly, modestly, and beseechingly until he reached the musalla and prayed two rak\'ah.',
          hadithRef: 'Jami\' at-Tirmidhi 558, Sunan Abu Dawood 1165',
          steps: [
            'WHEN — Performed during a drought or severe water shortage by community decision',
            'PREPARATION — People should repent, give sadaqah, fast, and reconcile disputes before the day',
            'GATHERING — People go out to the open musalla (prayer ground) humbly and in plain dress',
            'ORDER — Imam leads 2 rak\'ah with extra Takbirs like Eid: 7 Takbirs in 1st rak\'ah, 5 in 2nd rak\'ah (after opening Takbir)',
            '1st RAK\'AH — After Opening Takbir + 6 additional Takbirs, recite Al-Fatiha + Surah Al-A\'la',
            '2nd RAK\'AH — After rising, say 5 additional Takbirs then recite Al-Fatiha + Surah Al-Ghashiyah',
            'KHUTBAH — The Imam delivers TWO khutbahs after the prayer, facing the people',
            'REVERSAL — Imam turns his cloak inside out as a symbol of hoping Allah will turn the situation around (Tawheel al-Rida)',
            'DU\'A — Imam turns to face the Qibla and makes earnest, prolonged du\'a for rain with hands raised high',
            'People respond with Ameen loudly. If rain comes before the prayer, the prayer may still be offered in gratitude'
          ],
        ),
        const SizedBox(height: 14),
        // 9. Jummah
        _SpecialPrayerCard(
          isDark: isDark,
          icon: Icons.mosque_rounded,
          title: 'Jummah (Friday Prayer)',
          titleAr: 'صلاة الجمعة',
          color: AppColors.navyBlue,
          quranText: 'يَا أَيُّهَا الَّذِينَ آمَنُوا إِذَا نُودِيَ لِلصَّلاةِ مِنْ يَوْمِ الْجُمُعَةِ فَاسْعَوْا إِلَى ذِكْرِ اللَّهِ وَذَرُوا الْبَيْعَ',
          quranRef: "Surah Al-Jumu'ah (62:9)",
          quranEn: 'O you who have believed, when the adhan is called for the prayer on the day of Jumu\'ah, then proceed to the remembrance of Allah and leave trade.',
          hadithText: 'مَنِ اغْتَسَلَ يَوْمَ الْجُمُعَةِ غُسْلَ الْجَنَابَةِ ثُمَّ رَاحَ فَكَأَنَّمَا قَرَّبَ بَدَنَةً',
          hadithEn: 'Whoever performs Ghusl on Friday like the Ghusl for janabah, then goes early — it is as if he sacrificed a camel.',
          hadithRef: 'Sahih al-Bukhari 881, Sahih Muslim 850',
          steps: [
            'MORNING PREP — Perform full Ghusl (bath) like Janabah Ghusl specifically for Jummah. Cut nails, apply fragrance/oud, wear your best/cleanest white clothes, use miswak',
            'EARLY ARRIVAL — Go to the masjid as early as possible after Fajr. Every hour of early arrival earns angel-recorded reward. The first hour = sacrificing a camel, 2nd = cow, 3rd = ram, 4th = chicken, 5th = egg',
            'ENTERING MOSQUE — Pray Tahiyyatul Masjid (2 rak\'ah greeting) upon entering. Do NOT sit without praying them even if the Imam is on the Minbar',
            'SUNNAH BEFORE — After Tahiyyatul Masjid, pray 4 rak\'ah Sunnah (in pairs of 2) before the Khutbah begins',
            'DURING KHUTBAH — When the Adhan is called and Imam ascends the Minbar, ALL talk becomes haram. Listen silently and attentively. Even telling someone "be quiet" is a sin',
            'FARD PRAYER — Pray 2 rak\'ah Fard Jummah prayer in congregation behind the Imam. This replaces Dhuhr for that day',
            'SUNNAH AFTER — Pray 4 rak\'ah Sunnah Muakkadah after the Fard at the mosque. If you pray at home, pray 2 rak\'ah instead',
            'SURAH AL-KAHF — Recite or listen to Surah Al-Kahf on Friday. It provides light between two Fridays and protects from Dajjal',
            'SPECIAL HOUR — There is a hidden blessed hour on Friday (likely the last hour before Maghrib) where any du\'a is accepted. Make extra du\'a in that time',
            'SALAWAT — Send abundant blessings on the Prophet ﷺ throughout Friday — "Whoever sends 80 salawat on Friday, 80 years of sins are forgiven" (Abu Dawood)'
          ],
        ),
        const SizedBox(height: 14),
        // 10. Janazah
        _SpecialPrayerCard(
          isDark: isDark,
          icon: Icons.volunteer_activism_rounded,
          title: 'Janazah (Funeral Prayer)',
          titleAr: 'صلاة الجنازة',
          color: AppColors.navyBlue,
          quranText: 'كُلُّ نَفْسٍ ذَائِقَةُ الْمَوْتِ',
          quranRef: 'Surah Ali \'Imran (3:185)',
          quranEn: 'Every soul shall taste death...',
          hadithText: 'مَنْ صَلَّى عَلَى جَنَازَةٍ فَلَهُ قِيرَاطٌ ، وَمَنْ تَبِعَهَا حَتَّى تُدْفَنَ فَلَهُ قِيرَاطَانِ',
          hadithEn: 'Whoever prays the funeral prayer will have one Qirat of reward, and whoever follows it until burial will have two Qirats.',
          hadithRef: 'Sahih al-Bukhari 1325, Sahih Muslim 945',
          steps: [
            'NO Ruku, NO Sujud, NO Adhan, NO Iqamah — Janazah is performed entirely standing',
            'ROWS — Form 3 or more rows (odd number is preferred). The more people who pray, the greater the benefit for the deceased',
            'POSITION — Imam stands at the head of a male deceased or at the middle of a female deceased',
            '1st TAKBIR — Raise hands to earlobes and say "Allahu Akbar". Fold hands on chest. Recite Thana ("Subhanakallahumma wa bihamdik...") then recite Surah Al-Fatiha silently',
            '2nd TAKBIR — Say "Allahu Akbar" (hands may be raised or left). Recite the full Darood Ibrahim: "Allahumma salli \'ala Muhammadin wa \'ala aali Muhammadin..."',
            '3rd TAKBIR — Say "Allahu Akbar". Recite Du\'a for the deceased: "Allahummaghfir lahu warhamhu wa \'afihi wa\'fu \'anhu..." (see Du\'a box below). Make it sincere and personal',
            '4th TAKBIR — Say "Allahu Akbar". Pause briefly and silently (some scholars say recite short du\'a or Fatiha again)',
            'TASLEEM — Give Salam to the right: "Assalamu Alaykum wa Rahmatullah" then to the left',
            'NOTE — If the deceased is a child: modify the du\'a to "Allahummaj\'alhu lana faratan..." (O Allah make him/her an intercessor for us)',
            'IMPORTANCE — The Prophet ﷺ said: "If 100 Muslims pray Janazah interceding for someone, their intercession is accepted" (Sahih Muslim 947)'
          ],
          extraDua: 'اللَّهُمَّ اغْفِرْ لَهُ وَارْحَمْهُ وَعَافِهِ وَاعْفُ عَنْهُ وَأَكْرِمْ نُزُلَهُ وَوَسِّعْ مُدْخَلَهُ وَاغْسِلْهُ بِالْمَاءِ وَالثَّلْجِ وَالْبَرَدِ',
          extraDuaPronunciation: 'Allahummagh-fir lahu war-hamhu wa \'afihi wa\'fu \'anhu, wa akrim nuzulahu wa wassi\' mudkhalahu, waghsilhu bil-ma\'i wath-thalji wal-barad.',
          extraDuaEn: 'O Allah, forgive him and have mercy on him, grant him safety and pardon him, honor his reception and expand his entry...',
          extraDuaRef: 'Sahih Muslim 963',
        ),
        const SizedBox(height: 14),
        // 11. Eid
        _SpecialPrayerCard(
          isDark: isDark,
          icon: Icons.festival_rounded,
          title: 'Eid Prayer (Fitr & Adha)',
          titleAr: 'صلاة العيدين',
          color: AppColors.navyBlue,
          quranText: 'فَصَلِّ لِرَبِّكَ وَانْحَرْ',
          quranRef: 'Surah Al-Kawthar (108:2)',
          quranEn: 'So pray to your Lord and sacrifice [to Him alone].',
          hadithText: 'كَانَ رَسُولُ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ يَخْرُجُ يَوْمَ الْفِطْرِ وَالأَضْحَى إِلَى الْمُصَلَّى',
          hadithEn: 'The Messenger of Allah ﷺ used to go out on the day of Eid al-Fitr and Eid al-Adha to the open musalla.',
          hadithRef: 'Sahih al-Bukhari 956, Sahih Muslim 889',
          steps: [
            'PREPARATION — Take a full Ghusl, wear best/newest clothes, apply fragrance. Eat odd number of dates before Eid al-Fitr. For Eid al-Adha, do NOT eat until after prayer (eat from Qurbani sacrifice)',
            'NO ADHAN, NO IQAMAH — Eid prayer begins directly when the Imam says the first Takbir',
            'WALK TO OPEN GROUND — Go to the open Eidgah (musalla). Take one route and return via a different route, following the Sunnah',
            '1st RAK\'AH — Opening Takbir (Takbiratul Ihram): raise hands to earlobes, say "Allahu Akbar", fold hands on chest, recite Thana quietly',
            '1st RAK\'AH — 6 additional Takbirs: raise hands and say "Allahu Akbar" each time. Between EACH Takbir, recite the Tahmid du\'a (see Du\'a box below). Hands hang at sides between Takbirs',
            '1st RAK\'AH — After all 6 Takbirs, fold hands. Imam recites Al-Fatiha aloud + Surah Al-A\'la (or Surah Qaf). Then complete Ruku and 2 Sujuds as normal',
            '2nd RAK\'AH — Stand for 2nd rak\'ah. Say 5 additional Takbirs (raise hands, "Allahu Akbar", lower hands, recite Tahmid — 5 times)',
            '2nd RAK\'AH — After 5 Takbirs, fold hands. Imam recites Al-Fatiha + Surah Al-Ghashiyah (or Surah Al-Qamar). Complete Ruku, 2 Sujuds, Tashahhud, Tasleem',
            'KHUTBAH — After prayer (NOT before like Jummah), Imam delivers TWO khutbahs. Respond with Ameen to du\'as',
            'EID GREETING — Say: "Taqabbalallahu minna wa minkum" (May Allah accept from us and from you) — the Sahabah greeted each other with this (Fathul-Bari)',
            'EID TAKBEER — Keep reciting: "Allahu Akbar, Allahu Akbar, La ilaha illallah, Allahu Akbar, Allahu Akbar wa lillahil-hamd" throughout the day'
          ],
          extraDua: 'سُبْحَانَ اللَّهِ وَالْحَمْدُ لِلَّهِ وَلَا إِلَهَ إِلَّا اللَّهُ وَاللَّهُ أَكْبَرُ',
          extraDuaPronunciation: 'Subhaanallahi wal-hamdulillaahi wa laa ilaaha illallaahu wallaahu akbar',
          extraDuaEn: 'Glory be to Allah, all praise is for Allah, there is no god worthy of worship except Allah, and Allah is the Greatest — this is the Tahmid recited between each additional Takbir in Eid prayer',
          extraDuaRef: 'Ibn Hibban 2841, Musnad Ahmad — taught by Ibn Mas\'ud (ra)',
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _SpecialPrayerCard extends StatefulWidget {
  final bool isDark;
  final IconData icon;
  final String title, titleAr, quranText, quranRef, quranEn;
  final String hadithText, hadithEn, hadithRef;
  final List<String> steps;
  final String? extraDua, extraDuaPronunciation, extraDuaEn, extraDuaRef;
  final Color color;

  const _SpecialPrayerCard({
    required this.isDark, required this.icon, required this.title, required this.titleAr,
    required this.color, required this.quranText, required this.quranRef, required this.quranEn,
    required this.hadithText, required this.hadithEn, required this.hadithRef, required this.steps,
    this.extraDua, this.extraDuaPronunciation, this.extraDuaEn, this.extraDuaRef,
  });

  @override
  State<_SpecialPrayerCard> createState() => _SpecialPrayerCardState();
}

class _SpecialPrayerCardState extends State<_SpecialPrayerCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? Colors.white : AppColors.navyBlue;
    final subColor = widget.isDark ? Colors.white60 : Colors.grey.shade600;

    // Use navyBlue for dark headers, dustyBlueTeal accent for alternation — unified theme
    final headerColor = widget.isDark
        ? Colors.black
        : AppColors.navyBlue;
    final accentColor = widget.isDark ? AppColors.dustyBlueTeal : AppColors.navyBlue;

    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: widget.isDark
                ? Colors.white.withValues(alpha: 0.10)
                : AppColors.navyBlue.withValues(alpha: 0.18)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.vertical(top: const Radius.circular(14), bottom: _expanded ? Radius.zero : const Radius.circular(14)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: headerColor,
                borderRadius: BorderRadius.vertical(top: const Radius.circular(14), bottom: _expanded ? Radius.zero : const Radius.circular(14)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: Icon(widget.icon, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(widget.titleAr, style: GoogleFonts.scheherazadeNew(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                  Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 20),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(children: [
                                Icon(Icons.book_rounded, color: accentColor, size: 13),
                                const SizedBox(width: 5),
                                Text('Quran Reference', style: GoogleFonts.inter(color: accentColor, fontWeight: FontWeight.bold, fontSize: 11)),
                              ]),
                              const SizedBox(height: 5),
                              Text(widget.quranText, textAlign: TextAlign.right, style: GoogleFonts.scheherazadeNew(fontSize: 15, color: textColor, height: 1.7)),
                              const SizedBox(height: 4),
                              Text(widget.quranEn, style: GoogleFonts.inter(fontSize: 11, color: subColor, fontStyle: FontStyle.italic, height: 1.4)),
                              const SizedBox(height: 3),
                              Align(alignment: Alignment.centerRight, child: Text(widget.quranRef, style: GoogleFonts.inter(fontSize: 10, color: accentColor, fontWeight: FontWeight.bold))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _HadithCard(isDark: widget.isDark, arabicText: widget.hadithText, englishText: widget.hadithEn, reference: widget.hadithRef),
                        const SizedBox(height: 8),
                        Text('How to Perform', style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold, fontSize: 12.5)),
                        const SizedBox(height: 5),
                        ...widget.steps.asMap().entries.map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 15,
                                    height: 15,
                                    decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                                    child: Center(child: Text('${e.key + 1}', style: GoogleFonts.poppins(color: Colors.white, fontSize: 7.5, fontWeight: FontWeight.bold))),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(e.value, style: GoogleFonts.inter(fontSize: 11.5, color: subColor, height: 1.4))),
                                ],
                              ),
                            )),
                        if (widget.extraDua != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.dustyBlueTeal.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.dustyBlueTeal.withValues(alpha: 0.25)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(children: [
                                  const Icon(Icons.record_voice_over_rounded, color: AppColors.dustyBlueTeal, size: 13),
                                  const SizedBox(width: 5),
                                  Text("Du'a", style: GoogleFonts.inter(color: AppColors.dustyBlueTeal, fontWeight: FontWeight.bold, fontSize: 11)),
                                ]),
                                const SizedBox(height: 5),
                                Text(widget.extraDua!, textAlign: TextAlign.right, style: GoogleFonts.scheherazadeNew(fontSize: 15, color: textColor, height: 1.7)),
                                if (widget.extraDuaPronunciation != null) ...[
                                  const SizedBox(height: 4),
                                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    const Icon(Icons.volume_up_rounded, size: 12, color: AppColors.dustyBlueTeal),
                                    const SizedBox(width: 4),
                                    Expanded(child: Text(widget.extraDuaPronunciation!, style: GoogleFonts.inter(fontSize: 10.5, color: widget.isDark ? Colors.white70 : AppColors.navyBlue, fontWeight: FontWeight.w600, height: 1.3))),
                                  ]),
                                ],
                                const SizedBox(height: 4),
                                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Icon(Icons.translate_rounded, size: 12, color: widget.isDark ? Colors.white38 : Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Expanded(child: Text(widget.extraDuaEn!, style: GoogleFonts.inter(fontSize: 10, color: subColor, fontStyle: FontStyle.italic, height: 1.3))),
                                ]),
                                const SizedBox(height: 3),
                                Text(widget.extraDuaRef!, style: GoogleFonts.inter(fontSize: 10, color: AppColors.dustyBlueTeal, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  COMMON MISTAKES TAB
// ═══════════════════════════════════════════════════════════════════════════

class _CommonMistakesTab extends StatelessWidget {
  final bool isDark;
  const _CommonMistakesTab({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : AppColors.navyBlue;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(icon: Icons.warning_amber_rounded, iconColor: AppColors.coralOrange, title: 'Common Mistakes in Salat', subtitle: 'According to authentic Sunnah', isDark: isDark),
        const SizedBox(height: 10),
        _MistakeItem(
          isDark: isDark,
          title: "Rushing without Tranquility (Tuma'ninah)",
          desc: "Rushing through ruku or sujud without pausing is a major mistake. The Prophet ﷺ told a man who rushed: 'Go back and pray, for you did not pray.'",
          ref: 'Sahih al-Bukhari 793, Sahih Muslim 397',
          hadithArabic: 'ارْجِعْ فَصَلِّ فَإِنَّكَ لَمْ تُصَلِّ',
          hadithEnglish: 'Go back and pray, for you have not prayed.',
          severity: 'Critical',
        ),
        _MistakeItem(
          isDark: isDark,
          title: 'Not Keeping Back Flat in Ruku',
          desc: 'The back must be flat like a table in ruku. Bending partially without completing ruku compromises the pillar.',
          ref: 'Sahih al-Bukhari 828',
          hadithArabic: 'كَانَ رَسُولُ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ إِذَا رَكَعَ لَمْ يُشْخِصْ رَأْسَهُ وَلَمْ يُصَوِّبْهُ وَلَكِنْ بَيْنَ ذَلِكَ',
          hadithEnglish: 'When the Messenger of Allah ﷺ bowed, he neither raised his head nor lowered it too much, but kept it level in between.',
          severity: 'Critical',
        ),
        _MistakeItem(
          isDark: isDark,
          title: "Not Straightening Fully After Ruku (I'tidal)",
          desc: "Rising completely upright from ruku is a Rukn. Going down to sujud before standing fully upright invalidates prayer.",
          ref: 'Sahih Muslim 498',
          hadithArabic: 'ثُمَّ يَرْفَعُ رَأْسَهُ حَتَّى يَرْجِعَ كُلُّ عَظْمٍ إِلَى مَوْضِعِهِ',
          hadithEnglish: 'Then he raised his head until every bone returned to its place.',
          severity: 'Critical',
        ),
        _MistakeItem(
          isDark: isDark,
          title: 'Nose Not Touching the Ground in Sujud',
          desc: 'Both forehead AND nose must touch the ground. Raising the feet or nose off the ground invalidates prostration.',
          ref: 'Sahih al-Bukhari 812',
          hadithArabic: 'أُمِرْتُ أَنْ أَسْجُدَ عَلَى سَبْعَةِ أَعْظُمٍ',
          hadithEnglish: 'I was commanded to prostrate on seven bones [including the nose].',
          severity: 'Critical',
        ),
        _MistakeItem(
          isDark: isDark,
          title: 'Verbalizing the Intention (Niyyah)',
          desc: 'Saying "Nawaytu an usalli..." aloud before prayer has no basis in Sunnah. The intention is strictly in the heart.',
          ref: "Ibn al-Qayyim, Zad al-Ma'ad",
          hadithArabic: 'إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ',
          hadithEnglish: 'Actions are by intention [which is in the heart].',
          severity: 'Innovation',
        ),
        _MistakeItem(
          isDark: isDark,
          title: 'Eyes Looking Upward or Around',
          desc: "The Prophet warned against looking up or away during prayer. Gaze must remain focused on prostration spot.",
          ref: 'Sahih al-Bukhari 750',
          hadithArabic: 'لَيَنْتَهِيَنَّ أَقْوَامٌ يَرْفَعُونَ أَبْصَارَهُمْ إِلَى السَّمَاءِ فِي الصَّلاةِ أَوْ لا تَرْجِعُ إِلَيْهِمْ',
          hadithEnglish: 'People must stop looking up at the sky during prayer, or their sight will not return to them.',
          severity: 'Disliked',
        ),
        _MistakeItem(
          isDark: isDark,
          title: 'Crossing in Front of a Praying Person',
          desc: 'Crossing directly in front of someone in prayer is a severe sin unless behind a Sutrah (barrier).',
          ref: 'Sahih al-Bukhari 510',
          hadithArabic: 'لَوْ يَعْلَمُ الْمَارُّ بَيْنَ يَدَيِ الْمُصَلِّي مَاذَا عَلَيْهِ لَكَانَ أَنْ يَقِفَ أَرْبَعِينَ خَيْرًا لَهُ مِنْ أَنْ يَمُرَّ بَيْنَ يَدَيْهِ',
          hadithEnglish: 'If the one who passes in front of a praying person knew what burden was upon him, waiting 40 would be better for him than passing.',
          severity: 'Serious Sin',
        ),
        _MistakeItem(
          isDark: isDark,
          title: 'Praying Without Valid Wudu',
          desc: 'Prayer without valid wudu is completely unaccepted.',
          ref: 'Sahih al-Bukhari 135',
          hadithArabic: 'لا تُقْبَلُ صَلاةٌ بِغَيْرِ طُهُورٍ',
          hadithEnglish: 'No prayer is accepted without purification.',
          severity: 'Invalid',
        ),
        const SizedBox(height: 16),
        _SectionHeader(icon: Icons.psychology_rounded, iconColor: AppColors.midTeal, title: 'Common Misconceptions', subtitle: 'Clarified with evidence', isDark: isDark),
        const SizedBox(height: 8),
        ...[
          {'q': 'Does Wudu break by touching a woman?', 'a': 'No. Touching a woman without sexual desire does not break wudu according to authentic Sunnah.', 'ref': 'Sunan al-Daraqutni, verified by al-Albani'},
          {'q': 'Must I repeat prayer if my mind wandered?', 'a': "No. Involuntary thoughts do not invalidate prayer, though reward is lost proportional to inattention. Strive for Khushoo'.", 'ref': 'Sahih al-Bukhari'},
          {'q': 'Is it mandatory to pray in Arabic?', 'a': "Yes — the prescribed recitation of Surah Al-Fatiha and Takbirs must be in Arabic. Personal du'a in sujud may be in any language.", 'ref': "Scholarly consensus (Ijma')"},
          {'q': 'Can I pray sitting if I cannot stand?', 'a': "Yes. If unable to stand due to illness/injury, pray sitting. If unable to sit, pray lying down.", 'ref': 'Sahih al-Bukhari 1117 — "Pray standing; if you cannot, then sitting..."'},
        ].map((item) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.black : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: isDark
                    ? Border.all(color: Colors.white.withValues(alpha: 0.16))
                    : null,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.help_outline_rounded, color: AppColors.midTeal, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item['q']!, style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold, fontSize: 12))),
                  ]),
                  const SizedBox(height: 4),
                  Text(item['a']!, style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white70 : Colors.grey.shade700, height: 1.4)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.auto_stories_rounded, size: 11, color: AppColors.coralOrange),
                    const SizedBox(width: 4),
                    Expanded(child: Text(item['ref']!, style: GoogleFonts.inter(fontSize: 10, color: AppColors.coralOrange, fontStyle: FontStyle.italic))),
                  ]),
                ],
              ),
            )),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _MistakeItem extends StatelessWidget {
  final bool isDark;
  final String title, desc, ref, severity;
  final String? hadithArabic, hadithEnglish;

  const _MistakeItem({
    required this.isDark, required this.title, required this.desc, required this.ref,
    required this.severity, this.hadithArabic, this.hadithEnglish,
  });

  Color get _color {
    switch (severity) {
      case 'Critical':
      case 'Invalid':
        return Colors.red.shade400;
      case 'Serious Sin':
        return Colors.deepOrange.shade400;
      case 'Innovation':
        return Colors.purple.shade400;
      case 'Disliked':
        return Colors.amber.shade700;
      default:
        return AppColors.midTeal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.16)
                : Colors.transparent),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(title, style: GoogleFonts.poppins(color: isDark ? Colors.white : AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 12))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: _color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Text(severity, style: GoogleFonts.inter(color: _color, fontSize: 9, fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 4),
          Text(desc, style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white70 : Colors.grey.shade700, height: 1.4)),
          if (hadithArabic != null && hadithArabic!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(hadithArabic!, textAlign: TextAlign.right, style: GoogleFonts.scheherazadeNew(fontSize: 14, color: isDark ? Colors.white : AppColors.navyBlue)),
                  if (hadithEnglish != null)
                    Text('"${hadithEnglish!}"', style: GoogleFonts.inter(fontSize: 10, color: isDark ? Colors.white70 : Colors.grey.shade700, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.menu_book_rounded, size: 11, color: _color),
            const SizedBox(width: 4),
            Expanded(child: Text(ref, style: GoogleFonts.inter(fontSize: 10, color: _color, fontStyle: FontStyle.italic))),
          ]),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  QIBLA TAB
// ═══════════════════════════════════════════════════════════════════════════

class _QiblaTab extends StatefulWidget {
  final bool isDark;
  const _QiblaTab({required this.isDark});
  @override
  State<_QiblaTab> createState() => _QiblaTabState();
}

class _QiblaTabState extends State<_QiblaTab> {
  double _compassHeading = 0.0;
  double _qiblaAngle = 0.0;
  bool _isLoading = true;
  String _locationText = 'Locating...';
  String _statusText = '';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _getLocation();
    _startCompass();
  }

  Future<void> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() { _hasError = true; _statusText = 'Location services disabled. Enable GPS.'; _isLoading = false; _calculateQiblaAngle(23.8103, 90.4125); });
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() { _hasError = true; _statusText = 'Location permission denied. Showing default (Dhaka).'; _isLoading = false; _calculateQiblaAngle(23.8103, 90.4125); _locationText = 'Dhaka, Bangladesh (default)'; });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      _calculateQiblaAngle(pos.latitude, pos.longitude);
      setState(() { _locationText = '${pos.latitude.toStringAsFixed(4)}°, ${pos.longitude.toStringAsFixed(4)}°'; _isLoading = false; _statusText = 'Qibla direction calculated ✓'; _hasError = false; });
    } catch (e) {
      _calculateQiblaAngle(23.8103, 90.4125);
      setState(() { _hasError = false; _locationText = 'Dhaka, Bangladesh (default)'; _isLoading = false; _statusText = 'Using default location'; });
    }
  }

  void _calculateQiblaAngle(double lat, double lng) {
    const kaabaLat = 21.4225;
    const kaabaLng = 39.8262;
    final dLng = _toRad(kaabaLng - lng);
    final lat1 = _toRad(lat);
    final lat2 = _toRad(kaabaLat);
    final x = math.sin(dLng) * math.cos(lat2);
    final y = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    final angle = math.atan2(x, y);
    setState(() => _qiblaAngle = (_toDeg(angle) + 360) % 360);
  }

  double _toRad(double deg) => deg * math.pi / 180;
  double _toDeg(double rad) => rad * 180 / math.pi;

  void _startCompass() {
    magnetometerEventStream().listen((MagnetometerEvent event) {
      if (!mounted) return;
      final heading = (math.atan2(-event.x, event.y) * 180 / math.pi + 360) % 360;
      setState(() => _compassHeading = heading);
    });
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? Colors.white : AppColors.navyBlue;
    final subColor = widget.isDark ? Colors.white60 : Colors.grey.shade600;
    final turnRequired = ((_qiblaAngle - _compassHeading + 360) % 360);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(icon: Icons.explore_rounded, iconColor: AppColors.midTeal, title: "Qibla Finder", subtitle: "Real-time compass pointing to Al-Masjid al-Haram", isDark: widget.isDark),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isDark ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: widget.isDark
                ? Border.all(color: Colors.white.withValues(alpha: 0.16))
                : null,
          ),
          child: Row(
            children: [
              Icon(_hasError ? Icons.location_off_rounded : (_isLoading ? Icons.my_location_rounded : Icons.location_on_rounded), color: _hasError ? AppColors.coralOrange : AppColors.midTeal, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_isLoading ? 'Getting location...' : _locationText, style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w600, fontSize: 12)),
                    if (_statusText.isNotEmpty) Text(_statusText, style: GoogleFonts.inter(color: _hasError ? AppColors.coralOrange : AppColors.midTeal, fontSize: 10)),
                  ],
                ),
              ),
              if (!_isLoading)
                TextButton(onPressed: () { setState(() => _isLoading = true); _init(); }, child: Text('Refresh', style: GoogleFonts.inter(color: AppColors.navyBlue, fontSize: 11))),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_isLoading)
          const Center(child: CircularProgressIndicator(color: AppColors.navyBlue))
        else
          Center(
            child: SizedBox(
              width: 270,
              height: 270,
              child: CustomPaint(
                painter: _QiblaCompassPainter(isDark: widget.isDark, compassHeading: _compassHeading, qiblaAngle: _qiblaAngle),
              ),
            ),
          ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.isDark ? Colors.black : AppColors.navyBlue,
            borderRadius: BorderRadius.circular(16),
            border: widget.isDark
                ? Border.all(color: Colors.white.withValues(alpha: 0.16))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _CompassStat(label: 'Qibla Bearing', value: '${_qiblaAngle.toStringAsFixed(1)}°', icon: Icons.explore_rounded),
              Container(width: 1, height: 36, color: Colors.white24),
              _CompassStat(label: 'Device Heading', value: '${_compassHeading.toStringAsFixed(1)}°', icon: Icons.navigation_rounded),
              Container(width: 1, height: 36, color: Colors.white24),
              _CompassStat(label: 'Turn Device', value: '${turnRequired.toStringAsFixed(0)}°', icon: Icons.mosque_rounded),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.midTeal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.midTeal.withValues(alpha: 0.3))),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.midTeal, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text("Hold your phone flat and rotate until the green Ka'bah needle points straight up. Ensure device is kept away from strong magnetic fields.", style: GoogleFonts.inter(color: subColor, fontSize: 11, height: 1.4))),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _QuranRefCard(isDark: widget.isDark, arabicText: 'وَمِنْ حَيْثُ خَرَجْتَ فَوَلِّ وَجْهَكَ شَطْرَ الْمَسْجِدِ الْحَرَامِ', englishText: 'And from wherever you go out [for prayer], turn your face toward Al-Masjid al-Haram.', reference: 'Surah Al-Baqarah (2:150)'),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _CompassStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _CompassStat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icon, color: Colors.white70, size: 16),
      const SizedBox(height: 3),
      Text(value, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      Text(label, style: GoogleFonts.inter(color: Colors.white60, fontSize: 9)),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  CUSTOM PAINTERS & HELPER CLASSES
// ═══════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════
//  DASHBOARD-IDENTICAL STAR & TEXTURE PAINTERS
// ═══════════════════════════════════════════════════════════════════════════

class _StarConfig {
  final double topFraction;
  final double leftFraction;
  final double size;
  final int delayMs;
  _StarConfig({required this.topFraction, required this.leftFraction, required this.size, required this.delayMs});
}

/// Exact same star widget as _DashboardTwinklingStar
class _SalatTwinklingStar extends StatefulWidget {
  final double topFraction, leftFraction, size;
  final int delayMs;

  const _SalatTwinklingStar({
    required this.topFraction,
    required this.leftFraction,
    required this.size,
    required this.delayMs,
  });

  @override
  State<_SalatTwinklingStar> createState() => _SalatTwinklingStarState();
}

class _SalatTwinklingStarState extends State<_SalatTwinklingStar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _opacity = Tween<double>(begin: 0.25, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _timer = Timer(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: FractionalOffset(widget.leftFraction, widget.topFraction),
      child: AnimatedBuilder(
        animation: _opacity,
        builder: (context, child) {
          return Opacity(
            opacity: _opacity.value,
            // Exact same 4-point CustomPaint star as dashboard
            child: CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _SalatStarPainter(),
            ),
          );
        },
      ),
    );
  }
}

/// 4-point gold star — identical to _DashboardStarPainter
class _SalatStarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFE082).withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rx = size.width / 2;
    final ry = size.height / 2;
    path.moveTo(cx, cy - ry);
    path.quadraticBezierTo(cx, cy, cx + rx, cy);
    path.quadraticBezierTo(cx, cy, cx, cy + ry);
    path.quadraticBezierTo(cx, cy, cx - rx, cy);
    path.quadraticBezierTo(cx, cy, cx, cy - ry);
    path.close();
    canvas.drawPath(path, paint);
    canvas.drawCircle(
      Offset(cx, cy),
      size.width * 0.12,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Exact same geometric texture as _DashboardTexturePainter
class _SalatTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.navyBlue.withValues(alpha: 0.015)
      ..strokeWidth = 0.4
      ..style = PaintingStyle.stroke;
    const double gridWidth = 16.0;
    final int rows = (size.height / gridWidth).ceil() + 1;
    final int cols = (size.width / gridWidth).ceil() + 1;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final double x = c * gridWidth;
        final double y = r * gridWidth;
        canvas.drawRect(
          Rect.fromLTWH(x - gridWidth / 2, y - gridWidth / 2, gridWidth, gridWidth),
          paint,
        );
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(math.pi / 4);
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: gridWidth, height: gridWidth),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _QiblaCompassPainter extends CustomPainter {
  final bool isDark;
  final double compassHeading, qiblaAngle;
  const _QiblaCompassPainter({required this.isDark, required this.compassHeading, required this.qiblaAngle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer ring
    canvas.drawCircle(center, radius, Paint()..shader = RadialGradient(colors: [AppColors.navyBlue.withValues(alpha: 0.3), AppColors.navyBlue]).createShader(Rect.fromCircle(center: center, radius: radius)));

    // Tick marks
    for (int i = 0; i < 72; i++) {
      final angle = i * 5 * math.pi / 180;
      final inner = radius - (i % 2 == 0 ? 12 : 7);
      canvas.drawLine(
        Offset(center.dx + (radius - 2) * math.sin(angle), center.dy - (radius - 2) * math.cos(angle)),
        Offset(center.dx + inner * math.sin(angle), center.dy - inner * math.cos(angle)),
        Paint()..color = (i % 18 == 0 ? Colors.white : Colors.white.withValues(alpha: 0.35))..strokeWidth = (i % 18 == 0 ? 2.0 : 1.2)..strokeCap = StrokeCap.round,
      );
    }

    // Inner face — pure black in dark mode
    canvas.drawCircle(center, radius - 18, Paint()..color = (isDark ? Colors.black : const Color(0xFFF0F4FA)));
    canvas.drawCircle(center, radius - 22, Paint()..color = AppColors.midTeal.withValues(alpha: 0.3)..style = PaintingStyle.stroke..strokeWidth = 2);

    // Cardinal labels
    void drawLabel(String label, double angleDeg, {bool isNorth = false}) {
      final a = (angleDeg - compassHeading) * math.pi / 180;
      final d = radius - 40;
      final pos = Offset(center.dx + d * math.sin(a), center.dy - d * math.cos(a));
      final style = GoogleFonts.poppins(color: isNorth ? Colors.red.shade400 : (isDark ? Colors.white : AppColors.navyBlue), fontWeight: FontWeight.bold, fontSize: 13);
      final tp = TextPainter(text: TextSpan(text: label, style: style), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
    drawLabel('N', 0, isNorth: true);
    drawLabel('E', 90);
    drawLabel('S', 180);
    drawLabel('W', 270);

    // Cross hair
    final crossPaint = Paint()..color = (isDark ? Colors.white : AppColors.navyBlue).withValues(alpha: 0.1)..strokeWidth = 0.8;
    canvas.drawLine(Offset(center.dx, center.dy - radius + 22), Offset(center.dx, center.dy + radius - 22), crossPaint);
    canvas.drawLine(Offset(center.dx - radius + 22, center.dy), Offset(center.dx + radius - 22, center.dy), crossPaint);

    // Qibla needle (Coral Orange as requested by user)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    final relativeQibla = (qiblaAngle - compassHeading) * math.pi / 180;
    canvas.rotate(relativeQibla);
    
    // Needle Body - Coral Orange
    final needlePath = Path()
      ..moveTo(0, -(radius - 52))
      ..lineTo(8, -10)
      ..lineTo(0, -4)
      ..lineTo(-8, -10)
      ..close();
    canvas.drawPath(needlePath, Paint()..color = AppColors.coralOrange);

    // Opposite tail - Navy Blue / Muted
    final tailPath = Path()
      ..moveTo(0, radius - 52)
      ..lineTo(6, 10)
      ..lineTo(0, 4)
      ..lineTo(-6, 10)
      ..close();
    canvas.drawPath(tailPath, Paint()..color = isDark ? Colors.white38 : AppColors.navyBlue.withValues(alpha: 0.4));

    // Kaaba icon badge at top of needle
    final kaabaOffset = Offset(0, -(radius - 58));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: kaabaOffset, width: 16, height: 16),
        const Radius.circular(3),
      ),
      Paint()..color = AppColors.navyBlue,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: kaabaOffset, width: 16, height: 16),
        const Radius.circular(3),
      ),
      Paint()..color = AppColors.coralOrange..style = PaintingStyle.stroke..strokeWidth = 1.5,
    );
    // Gold band on Kaaba badge
    canvas.drawLine(
      Offset(kaabaOffset.dx - 8, kaabaOffset.dy - 3),
      Offset(kaabaOffset.dx + 8, kaabaOffset.dy - 3),
      Paint()..color = const Color(0xFFFFD700)..strokeWidth = 2,
    );

    canvas.restore();

    // Center pivot point
    canvas.drawCircle(center, 9, Paint()..color = AppColors.navyBlue);
    canvas.drawCircle(center, 6, Paint()..color = AppColors.coralOrange);
    canvas.drawCircle(center, 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_QiblaCompassPainter old) => old.compassHeading != compassHeading || old.qiblaAngle != qiblaAngle || old.isDark != isDark;
}

// ═══════════════════════════════════════════════════════════════════════════
//  SHARED WIDGET HELPERS
// ═══════════════════════════════════════════════════════════════════════════

class _DotIndicator extends StatelessWidget {
  final int current, total;
  final Color color;
  final bool isDark;
  const _DotIndicator({required this.current, required this.total, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: current == i ? 18 : 6,
        height: 6,
        decoration: BoxDecoration(color: current == i ? color : (isDark ? Colors.white24 : Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
      )),
    );
  }
}

class _NavButtons extends StatelessWidget {
  final bool isDark;
  final int currentStep, totalSteps;
  final PageController pageCtrl;
  const _NavButtons({required this.isDark, required this.currentStep, required this.totalSteps, required this.pageCtrl});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: currentStep > 0 ? () => pageCtrl.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut) : null,
            icon: const Icon(Icons.chevron_left_rounded),
            label: const Text('Previous'),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? Colors.white : AppColors.navyBlue,
              side: BorderSide(color: isDark ? Colors.white38 : AppColors.navyBlue.withValues(alpha: 0.3)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: currentStep < totalSteps - 1 ? () => pageCtrl.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut) : null,
            icon: const Icon(Icons.chevron_right_rounded),
            label: const Text('Next Step'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.midTeal : AppColors.navyBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final bool isDark;
  const _SectionHeader({required this.icon, required this.iconColor, required this.title, required this.subtitle, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.poppins(color: isDark ? Colors.white : AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 15)),
              Text(subtitle, style: GoogleFonts.inter(color: isDark ? Colors.white54 : Colors.grey.shade600, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuranRefCard extends StatelessWidget {
  final bool isDark;
  final String arabicText, englishText, reference;
  const _QuranRefCard({required this.isDark, required this.arabicText, required this.englishText, required this.reference});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.16)
                : AppColors.navyBlue.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: isDark ? AppColors.midTeal : AppColors.navyBlue, borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.book_rounded, color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text('Quran', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                ])),
            const SizedBox(width: 8),
            Expanded(child: Text(reference, style: GoogleFonts.inter(color: isDark ? AppColors.midTeal : AppColors.navyBlue, fontWeight: FontWeight.w600, fontSize: 11))),
          ]),
          const SizedBox(height: 8),
          Text(arabicText, textAlign: TextAlign.right, style: GoogleFonts.scheherazadeNew(fontSize: 16, color: isDark ? Colors.white : AppColors.navyBlue, height: 1.7)),
          const Divider(height: 12),
          Text(englishText, style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white70 : Colors.grey.shade700, fontStyle: FontStyle.italic, height: 1.4)),
        ],
      ),
    );
  }
}

class _HadithCard extends StatelessWidget {
  final bool isDark;
  final String arabicText, englishText, reference;
  const _HadithCard({required this.isDark, required this.arabicText, required this.englishText, required this.reference});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.16)
                : AppColors.coralOrange.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.coralOrange, borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text('Hadith', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                ])),
            const SizedBox(width: 8),
            Expanded(child: Text(reference, style: GoogleFonts.inter(color: AppColors.coralOrange, fontWeight: FontWeight.w600, fontSize: 11))),
          ]),
          const SizedBox(height: 8),
          Text(arabicText, textAlign: TextAlign.right, style: GoogleFonts.scheherazadeNew(fontSize: 15, color: isDark ? Colors.white : AppColors.navyBlue, height: 1.6)),
          const Divider(height: 12),
          Text(englishText, style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white70 : Colors.grey.shade700, fontStyle: FontStyle.italic, height: 1.4)),
        ],
      ),
    );
  }
}





class _SafeImage extends StatelessWidget {
  final String path;
  final double height;
  const _SafeImage({required this.path, required this.height});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      path,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_rounded, color: AppColors.navyBlue.withValues(alpha: 0.4), size: 64),
          const SizedBox(height: 4),
          Text(
            path.split('/').last.replaceAll('.png', '').replaceAll('_', ' '),
            style: GoogleFonts.inter(color: AppColors.navyBlue.withValues(alpha: 0.4), fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ImageLabel extends StatelessWidget {
  final String text;
  final bool isDark;
  const _ImageLabel({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.12)
            : AppColors.navyBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white60 : AppColors.navyBlue.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// PRAYER TYPE LEGEND WIDGET
// ══════════════════════════════════════════════════════════════

class _PrayerTypeLegend extends StatelessWidget {
  final bool isDark;
  final String label;
  final String arabic;
  final Color color;
  final String description;
  final String quranHadith;

  const _PrayerTypeLegend({
    required this.isDark,
    required this.label,
    required this.arabic,
    required this.color,
    required this.description,
    required this.quranHadith,
  });

  @override
  Widget build(BuildContext context) {
    // Navy is too low-contrast on the dark guide cards. Use the same teal
    // accent as the rest of the dark Salat experience instead.
    final accent = isDark && color == AppColors.navyBlue
        ? AppColors.midTeal
        : color;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withValues(alpha: 0.3) : accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.3 : 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 10.5,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                arabic,
                style: GoogleFonts.scheherazadeNew(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : AppColors.navyBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 11,
              height: 1.4,
              color: isDark ? Colors.white70 : Colors.grey.shade800,
            ),
          ),
          if (quranHadith.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_stories_rounded, size: 12, color: accent),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    quranHadith,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: isDark ? accent.withValues(alpha: 0.9) : accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// PRAYER ROW DATA CLASS
// ══════════════════════════════════════════════════════════════

class _PrayerRow {
  final String type;
  final Color typeColor;
  final int rakaat;
  final String note;
  const _PrayerRow({
    required this.type,
    required this.typeColor,
    required this.rakaat,
    required this.note,
  });
}

// ══════════════════════════════════════════════════════════════
// WAQT PRAYER CARD WIDGET
// ══════════════════════════════════════════════════════════════

class _WaqtPrayerCard extends StatelessWidget {
  final bool isDark;
  final String waqtName;
  final String waqtAr;
  final IconData waqtIcon;
  final int totalRakaat;
  final List<_PrayerRow> rows;
  const _WaqtPrayerCard({
    required this.isDark,
    required this.waqtName,
    required this.waqtAr,
    required this.waqtIcon,
    required this.totalRakaat,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : AppColors.navyBlue;
    final subColor = isDark ? Colors.white60 : Colors.grey.shade600;
    Color rowAccent(Color color) =>
        isDark && color == AppColors.navyBlue ? AppColors.midTeal : color;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.black : const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.16) : AppColors.navyBlue.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.black : AppColors.navyBlue.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(waqtIcon, size: 18, color: isDark ? AppColors.midTeal : AppColors.navyBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Text(waqtName,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: textColor)),
                      const SizedBox(width: 6),
                      Text(waqtAr,
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: subColor)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.midTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Total: $totalRakaat rak\'ah',
                    style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.midTeal),
                  ),
                ),
              ],
            ),
          ),
          // Rows
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: rows.asMap().entries.map((entry) {
                final row = entry.value;
                final accent = rowAccent(row.typeColor);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rakaat badge
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            '${row.rakaat}',
                            style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: accent),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: accent.withValues(alpha: 0.25)),
                                ),
                                child: Text(
                                  row.type,
                                  style: GoogleFonts.poppins(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: accent),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 3),
                            Text(
                              row.note,
                              style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  color: subColor,
                                  height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// DIFF ROW WIDGET (Fard vs Sunnah explanation)
// ══════════════════════════════════════════════════════════════

class _DiffRow extends StatelessWidget {
  final bool isDark;
  final String label;
  final String desc;
  const _DiffRow({required this.isDark, required this.label, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.navyBlue.withValues(alpha: isDark ? 0.3 : 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.navyBlue),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: GoogleFonts.inter(
                fontSize: 11,
                height: 1.4,
                color: isDark ? Colors.white70 : Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// CARD BOX & CARD TITLE HELPERS
// ══════════════════════════════════════════════════════════════

class _CardBox extends StatelessWidget {
  final bool isDark;
  final Widget child;
  const _CardBox({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.16)
              : AppColors.navyBlue.withValues(alpha: 0.2),
        ),
      ),
      child: child,
    );
  }
}

class _CardTitle extends StatelessWidget {
  final String text;
  final bool isDark;
  const _CardTitle({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        color: isDark ? Colors.white : AppColors.navyBlue,
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
    );
  }
}
