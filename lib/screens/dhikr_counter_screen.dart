import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/auth_header.dart'; // AppColors
import '../services/notification_service.dart';

/// ===== DHIKR COUNTER SCREEN (full tabbed app) =====
/// Push like the other planner pages:
///   Navigator.of(context).push(
///     MaterialPageRoute(builder: (_) => DhikrCounterScreen(isDarkMode: _isDarkMode)),
///   );
class DhikrCounterScreen extends StatefulWidget {
  final bool isDarkMode;
  const DhikrCounterScreen({super.key, this.isDarkMode = false});

  @override
  State<DhikrCounterScreen> createState() => _DhikrCounterScreenState();
}

// ===== DHIKR PRESET DATA =====
class _DhikrPreset {
  final String name;
  final String arabic;
  final String translit;
  final String meaning;
  final String virtue;
  final int target;
  final IconData icon;
  const _DhikrPreset({
    required this.name,
    required this.arabic,
    required this.translit,
    required this.meaning,
    required this.virtue,
    required this.target,
    required this.icon,
  });
}

const List<_DhikrPreset> _presets = [
  _DhikrPreset(
    name: 'SubhanAllah',
    arabic: 'سُبْحَانَ اللّٰهِ',
    translit: 'SubhanAllah',
    meaning: 'Glory be to Allah',
    virtue: 'A word light on the tongue, heavy on the scale, and beloved to Allah — as described in an authentic hadith.',
    target: 33,
    icon: Icons.star_rounded,
  ),
  _DhikrPreset(
    name: 'Alhamdulillah',
    arabic: 'الْحَمْدُ لِلّٰهِ',
    translit: 'Alhamdulillah',
    meaning: 'All praise is due to Allah',
    virtue: 'The Prophet (PBUH) taught that gratitude expressed this way fills the scale of good deeds.',
    target: 33,
    icon: Icons.favorite_rounded,
  ),
  _DhikrPreset(
    name: 'Allahu Akbar',
    arabic: 'اللّٰهُ أَكْبَرُ',
    translit: 'Allahu Akbar',
    meaning: 'Allah is the Greatest',
    virtue: 'A declaration recited in prayer, on Eid, and in daily remembrance to affirm Allah\'s supremacy.',
    target: 34,
    icon: Icons.mosque_rounded,
  ),
  _DhikrPreset(
    name: 'Astaghfirullah',
    arabic: 'أَسْتَغْفِرُ اللّٰهَ',
    translit: 'Astaghfirullah',
    meaning: 'I seek forgiveness from Allah',
    virtue: 'The Prophet (PBUH) himself sought forgiveness many times a day, modeling constant repentance.',
    target: 100,
    icon: Icons.wb_twilight_rounded,
  ),
  _DhikrPreset(
    name: 'La ilaha illallah',
    arabic: 'لَا إِلٰهَ إِلَّا اللّٰهُ',
    translit: 'La ilaha illallah',
    meaning: 'There is no god but Allah',
    virtue: 'Known as the best form of remembrance — the core statement of Islamic monotheism.',
    target: 100,
    icon: Icons.nights_stay_rounded,
  ),
];

const List<_DhikrPreset> _tasbihFatimahSequence = [
  _DhikrPreset(
    name: 'SubhanAllah', arabic: 'سُبْحَانَ اللّٰهِ', translit: 'SubhanAllah',
    meaning: 'Glory be to Allah', virtue: 'Part of the Tasbih taught by the Prophet (PBUH) to his daughter Fatimah (RA).',
    target: 33, icon: Icons.star_rounded,
  ),
  _DhikrPreset(
    name: 'Alhamdulillah', arabic: 'الْحَمْدُ لِلّٰهِ', translit: 'Alhamdulillah',
    meaning: 'All praise is due to Allah', virtue: 'The second third of the Tasbih of Fatimah (RA).',
    target: 33, icon: Icons.favorite_rounded,
  ),
  _DhikrPreset(
    name: 'Allahu Akbar', arabic: 'اللّٰهُ أَكْبَرُ', translit: 'Allahu Akbar',
    meaning: 'Allah is the Greatest', virtue: 'Completes the 100-count routine recommended before sleeping.',
    target: 34, icon: Icons.mosque_rounded,
  ),
];

// ===== ADHKAR COLLECTION DATA (Morning & Evening) =====
class _AdhkarItem {
  final String title;
  final String fullArabic;
  final String transliteration;
  final String fullMeaning;
  final String virtue;
  final int recommendedCount;
  const _AdhkarItem({
    required this.title,
    required this.fullArabic,
    required this.transliteration,
    required this.fullMeaning,
    required this.virtue,
    required this.recommendedCount,
  });
}

const List<_AdhkarItem> _morningAdhkar = [
  _AdhkarItem(
    title: 'Morning Declaration of Trust',
    fullArabic: 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلّٰهِ، وَالْحَمْدُ لِلّٰهِ، لَا إِلٰهَ إِلَّا اللّٰهُ وَحْدَهُ لَا شَرِيكَ لَهُ',
    transliteration: 'Asbahna wa asbahal-mulku lillah, walhamdu lillah, la ilaha illallahu wahdahu la sharika lah',
    fullMeaning:
        'We have entered a new morning, and with it all dominion belongs to Allah alone. All praise is for Him. There is no god worthy of worship except Allah, who has no partner. This short declaration, recited upon waking, affirms that everything — our day, our sustenance, our safety — rests entirely in Allah\'s hands.',
    virtue: 'A short declaration of trust recited upon waking, affirming Allah\'s complete ownership of all things.',
    recommendedCount: 1,
  ),
  _AdhkarItem(
    title: 'Ayat al-Kursi',
    fullArabic:
        'اللّٰهُ لَا إِلٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَن ذَا الَّذِي يَشْفَعُ عِندَهُ إِلَّا بِإِذْنِهِ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ',
    transliteration:
        'Allahu la ilaha illa huwal hayyul qayyum, la ta\'khudhuhu sinatuw wala nawm, lahu ma fis-samawati wama fil-ard, man dhal-ladhi yashfa\'u \'indahu illa bi-idhnih, ya\'lamu ma bayna aydihim wama khalfahum, wala yuhituna bishay\'im-min \'ilmihi illa bima sha\', wasi\'a kursiyyuhus-samawati wal-ard, wala ya\'uduhu hifzuhuma, wa huwal \'aliyyul \'azim',
    fullMeaning:
        'This is the Verse of the Throne, Surah Al-Baqarah 2:255. It describes Allah as the Ever-Living, the Sustainer of all existence — never overtaken by drowsiness or sleep. Everything in the heavens and the earth belongs to Him, and no one can intercede with Him except by His permission. His knowledge encompasses all that has happened and all that will come, while creation grasps only what He allows them to know. His authority extends over the heavens and the earth without any burden to Him in preserving them, for He is the Most High, the Most Great. It is one of the most frequently recited verses for protection, both morning and evening.',
    virtue: 'Widely reported to offer protection when recited morning and evening.',
    recommendedCount: 1,
  ),
  _AdhkarItem(
    title: 'The Three Quls',
    fullArabic:
        'قُلْ هُوَ اللّٰهُ أَحَدٌ ۝ اللّٰهُ الصَّمَدُ ۝ لَمْ يَلِدْ وَلَمْ يُولَدْ ۝ وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ\n\nقُلْ أَعُوذُ بِرَبِّ الْفَلَقِ ۝ مِن شَرِّ مَا خَلَقَ ۝ وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ ۝ وَمِن شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ ۝ وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ\n\nقُلْ أَعُوذُ بِرَبِّ النَّاسِ ۝ مَلِكِ النَّاسِ ۝ إِلٰهِ النَّاسِ ۝ مِن شَرِّ الْوَسْوَاسِ الْخَنَّاسِ ۝ الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ ۝ مِنَ الْجِنَّةِ وَالنَّاسِ',
    transliteration:
        'Qul huwallahu ahad, Allahus-samad, lam yalid wa lam yulad, wa lam yakul-lahu kufuwan ahad.\n\nQul a\'udhu birabbil-falaq, min sharri ma khalaq, wa min sharri ghasiqin idha waqab, wa min sharrin-naffathati fil-\'uqad, wa min sharri hasidin idha hasad.\n\nQul a\'udhu birabbin-nas, malikin-nas, ilahin-nas, min sharril-waswasil-khannas, alladhi yuwaswisu fi sudurin-nas, minal-jinnati wan-nas',
    fullMeaning:
        'These are the three short chapters — Al-Ikhlas, Al-Falaq, and An-Nas. Al-Ikhlas declares Allah\'s complete oneness: He is Allah, the One, the Self-Sufficient, who was not born and does not give birth, and nothing compares to Him. Al-Falaq and An-Nas are both prayers of refuge — asking Allah\'s protection from the evil of what He has created, from the darkness of night, from harmful influences, from envy, and from the whispers that trouble the heart, whether from unseen sources or from people. Reciting these three chapters three times each is a well-known Sunnah practice, especially in the morning and evening.',
    virtue: 'Reciting these three short chapters three times each morning is a well-known Sunnah practice.',
    recommendedCount: 3,
  ),
  _AdhkarItem(
    title: 'Sayyid al-Istighfar (Master of Seeking Forgiveness)',
    fullArabic:
        'اللّٰهُمَّ أَنْتَ رَبِّي لَا إِلٰهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَىٰ عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ',
    transliteration:
        'Allahumma anta rabbi la ilaha illa ant, khalaqtani wa ana \'abduk, wa ana \'ala \'ahdika wa wa\'dika mastata\'t, a\'udhu bika min sharri ma sana\'t, abu\'u laka bini\'matika \'alayya wa abu\'u bidhanbi faghfir li fa innahu la yaghfirudh-dhunuba illa ant',
    fullMeaning:
        'This dua is considered the most comprehensive form of seeking forgiveness. It begins by acknowledging Allah as one\'s Lord, with no god besides Him — the One who created the person, who remains His servant, striving to honor his covenant and promise to the best of his ability. It seeks refuge from the harm of one\'s own actions, openly admits Allah\'s countless favors, confesses one\'s sins, and asks for forgiveness, recognizing that no one forgives sins except Allah. A well-known hadith describes reciting this with full conviction in the morning as granting entry to Paradise if one passes away that same day.',
    virtue: 'Reciting it with certainty in the morning is described as granting entry to Paradise if one passes away that day.',
    recommendedCount: 1,
  ),
];

const List<_AdhkarItem> _eveningAdhkar = [
  _AdhkarItem(
    title: 'Evening Declaration of Trust',
    fullArabic: 'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلّٰهِ، وَالْحَمْدُ لِلّٰهِ، لَا إِلٰهَ إِلَّا اللّٰهُ وَحْدَهُ لَا شَرِيكَ لَهُ',
    transliteration: 'Amsayna wa amsal-mulku lillah, walhamdu lillah, la ilaha illallahu wahdahu la sharika lah',
    fullMeaning:
        'We have entered the evening, and with it all dominion belongs to Allah alone. All praise is for Him. There is no god worthy of worship except Allah, who has no partner. This is the evening counterpart to the morning declaration, affirming trust in Allah as the day closes.',
    virtue: 'The evening counterpart to the morning declaration of trust in Allah\'s dominion.',
    recommendedCount: 1,
  ),
  _AdhkarItem(
    title: 'Ayat al-Kursi',
    fullArabic:
        'اللّٰهُ لَا إِلٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَن ذَا الَّذِي يَشْفَعُ عِندَهُ إِلَّا بِإِذْنِهِ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ',
    transliteration:
        'Allahu la ilaha illa huwal hayyul qayyum, la ta\'khudhuhu sinatuw wala nawm, lahu ma fis-samawati wama fil-ard, man dhal-ladhi yashfa\'u \'indahu illa bi-idhnih, ya\'lamu ma bayna aydihim wama khalfahum, wala yuhituna bishay\'im-min \'ilmihi illa bima sha\', wasi\'a kursiyyuhus-samawati wal-ard, wala ya\'uduhu hifzuhuma, wa huwal \'aliyyul \'azim',
    fullMeaning:
        'This is the Verse of the Throne, Surah Al-Baqarah 2:255. It describes Allah as the Ever-Living, the Sustainer of all existence — never overtaken by drowsiness or sleep. Everything in the heavens and the earth belongs to Him, and no one can intercede with Him except by His permission. His knowledge encompasses all that has happened and all that will come, while creation grasps only what He allows them to know. His authority extends over the heavens and the earth without any burden to Him in preserving them, for He is the Most High, the Most Great. Recited in the evening, it is a source of protection through the night.',
    virtue: 'Recited in the evening for protection through the night.',
    recommendedCount: 1,
  ),
  _AdhkarItem(
    title: 'Protection Dua (Bismillah)',
    fullArabic: 'بِسْمِ اللّٰهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ',
    transliteration: 'Bismillahil-ladhi la yadhurru ma\'a ismihi shay\'un fil-ardi wa la fis-sama\'i wa huwas-sami\'ul \'alim',
    fullMeaning:
        'In the name of Allah, with whose name nothing on earth or in the heavens can cause harm, and He is the All-Hearing, the All-Knowing. This short but powerful dua is recited three times in the evening as protection through the night, drawing on the completeness of Allah\'s name as a shield against harm.',
    virtue: 'Recited three times in the evening as protection until morning.',
    recommendedCount: 3,
  ),
  _AdhkarItem(
    title: 'Seeking Refuge from Evil',
    fullArabic: 'أَعُوذُ بِكَلِمَاتِ اللّٰهِ التَّامَّاتِ مِن شَرِّ مَا خَلَقَ',
    transliteration: 'A\'udhu bikalimatillahit-tammati min sharri ma khalaq',
    fullMeaning:
        'I seek refuge in the perfect, complete words of Allah from the evil of everything He has created. This short protective dua is recommended for evening remembrance, especially when settling in for the night, as a means of seeking Allah\'s protection from any harm in one\'s surroundings.',
    virtue: 'A short protective dua recommended for evening remembrance, especially when settling for the night.',
    recommendedCount: 3,
  ),
];

// ===== ACHIEVEMENT BADGE DATA =====
class _Badge {
  final String title;
  final String description;
  final IconData icon;
  final int threshold;
  final String type;
  const _Badge({required this.title, required this.description, required this.icon, required this.threshold, required this.type});
}

const List<_Badge> _badges = [
  _Badge(title: '100 Dhikr', description: 'Recite 100 dhikr in total', icon: Icons.emoji_events_rounded, threshold: 100, type: 'lifetime'),
  _Badge(title: '1,000 Dhikr Completed', description: 'Recite 1,000 dhikr in total', icon: Icons.military_tech_rounded, threshold: 1000, type: 'lifetime'),
  _Badge(title: '5,000 Dhikr', description: 'Recite 5,000 dhikr in total', icon: Icons.workspace_premium_rounded, threshold: 5000, type: 'lifetime'),
  _Badge(title: '3-Day Streak', description: 'Count dhikr 3 days in a row', icon: Icons.local_fire_department_rounded, threshold: 3, type: 'streak'),
  _Badge(title: '7-Day Streak', description: 'Count dhikr 7 days in a row', icon: Icons.local_fire_department_rounded, threshold: 7, type: 'streak'),
  _Badge(title: '30-Day Consistency', description: 'Count dhikr 30 days in a row', icon: Icons.verified_rounded, threshold: 30, type: 'streak'),
];

class _DhikrCounterScreenState extends State<DhikrCounterScreen> with TickerProviderStateMixin {
  int _tab = 0;
  static const _tabLabels = ['Counter', 'Adhkar', 'Stats', 'Reminders'];
  static const _tabIcons = [
    Icons.touch_app_rounded,
    Icons.menu_book_rounded,
    Icons.analytics_rounded,
    Icons.notifications_rounded,
  ];

  int _selectedPresetIndex = 0;
  int _count = 0;
  int _customTarget = 100;

  bool _isSequenceMode = false;
  int _sequencePhase = 0;

  int _todayTotal = 0;
  int _lifetimeTotal = 0;
  int _currentStreak = 0;
  bool _showHint = true;

  bool _showMorningAdhkar = true;

  final Map<String, bool> _reminders = {
    'Morning Adhkar': false,
    'Evening Adhkar': false,
  };
  final Map<String, TimeOfDay> _reminderTimes = {
    'Morning Adhkar': const TimeOfDay(hour: 7, minute: 0),
    'Evening Adhkar': const TimeOfDay(hour: 18, minute: 0),
  };

  late AnimationController _tapPulseController;
  late AnimationController _breathController;
  Timer? _dbWriteTimer;

  // ===== THEME HELPERS =====
  bool get _dark => widget.isDarkMode || Theme.of(context).brightness == Brightness.dark;
  Color _pageBg() => _dark ? Colors.black : const Color(0xFFF4F6F7);
  Color _letterboxBg() => _dark ? Colors.black : const Color(0xFFE8E8E8);
  Color _cardBg() => _dark ? Colors.black : Colors.white;
  Color _cardBorder() => _dark ? Colors.white.withValues(alpha: 0.16) : AppColors.navyBlue.withValues(alpha: 0.08);
  Color _primaryText() => _dark ? Colors.white : AppColors.navyBlue;
  Color _secondaryText({double alpha = 0.55}) =>
      _dark ? Colors.white.withValues(alpha: alpha + 0.05) : AppColors.navyBlue.withValues(alpha: alpha);
  Color _iconTint() => _dark ? Colors.white.withValues(alpha: 0.6) : AppColors.navyBlue.withValues(alpha: 0.6);
  Color _tabBarBg() => _dark ? const Color(0xFF14181D) : Colors.white;

  _DhikrPreset get _activePreset {
    if (_isSequenceMode) return _tasbihFatimahSequence[_sequencePhase];
    if (_selectedPresetIndex < _presets.length) return _presets[_selectedPresetIndex];
    return _DhikrPreset(
      name: 'Custom',
      arabic: '',
      translit: 'Custom Dhikr',
      meaning: 'Your own count target',
      virtue: 'Use this for any dhikr not listed above, with your own repetition goal.',
      target: _customTarget,
      icon: Icons.tune_rounded,
    );
  }

  @override
  void initState() {
    super.initState();
    _tapPulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _breathController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat(reverse: true);
    _loadStats();
    _loadReminderSettings();
  }

  @override
  void dispose() {
    _dbWriteTimer?.cancel();
    _syncDhikrToFirestore();
    _tapPulseController.dispose();
    _breathController.dispose();
    super.dispose();
  }

  String get _todayKey => 'dhikr_daily_${DateFormat('yyyyMMdd').format(DateTime.now())}';

  int _calculateStreak(SharedPreferences prefs) {
    int streak = 0;
    DateTime day = DateTime.now();
    while (true) {
      final key = 'dhikr_daily_${DateFormat('yyyyMMdd').format(day)}';
      final val = prefs.getInt(key) ?? 0;
      if (val > 0) {
        streak++;
        day = day.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    int today = prefs.getInt(_todayKey) ?? 0;
    int lifetime = prefs.getInt('dhikr_lifetime_total') ?? 0;
    final hintDismissed = prefs.getBool('dhikr_hint_dismissed') ?? false;

    int streak = _calculateStreak(prefs);

    if (mounted) {
      setState(() {
        _todayTotal = today;
        _lifetimeTotal = lifetime;
        _currentStreak = streak;
        _showHint = !hintDismissed;
      });
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data();
          if (data != null && data['dhikr'] != null) {
            final dhikrMap = data['dhikr'] as Map<String, dynamic>;
            final remoteLifetime = dhikrMap['lifetimeTotal'] as int? ?? 0;
            final remoteDailyHistory = dhikrMap['dailyHistory'] as Map<String, dynamic>?;
            final remotePresetsDaily = dhikrMap['presetsDaily'] as Map<String, dynamic>?;
            final remotePresetsLifetime = dhikrMap['presetsLifetime'] as Map<String, dynamic>?;

            if (remoteLifetime > lifetime) {
              lifetime = remoteLifetime;
              await prefs.setInt('dhikr_lifetime_total', remoteLifetime);
            }

            if (remoteDailyHistory != null) {
              for (final entry in remoteDailyHistory.entries) {
                final dateKey = entry.key;
                final count = entry.value as int? ?? 0;
                final key = 'dhikr_daily_$dateKey';
                final localCount = prefs.getInt(key) ?? 0;
                if (count > localCount) {
                  await prefs.setInt(key, count);
                  if (dateKey == DateFormat('yyyyMMdd').format(DateTime.now())) {
                    today = count;
                  }
                }
              }
            }

            if (remotePresetsDaily != null) {
              for (final dateEntry in remotePresetsDaily.entries) {
                final dateKey = dateEntry.key;
                final breakdown = dateEntry.value as Map<String, dynamic>;
                for (final presetEntry in breakdown.entries) {
                  final presetKey = presetEntry.key;
                  final count = presetEntry.value as int? ?? 0;
                  final key = 'dhikr_daily_${dateKey}_$presetKey';
                  final localCount = prefs.getInt(key) ?? 0;
                  if (count > localCount) {
                    await prefs.setInt(key, count);
                  }
                }
              }
            }

            if (remotePresetsLifetime != null) {
              for (final entry in remotePresetsLifetime.entries) {
                final presetKey = entry.key;
                final count = entry.value as int? ?? 0;
                final key = 'dhikr_lifetime_$presetKey';
                final localCount = prefs.getInt(key) ?? 0;
                if (count > localCount) {
                  await prefs.setInt(key, count);
                }
              }
            }

            streak = _calculateStreak(prefs);

            if (mounted) {
              setState(() {
                _todayTotal = today;
                _lifetimeTotal = lifetime;
                _currentStreak = streak;
              });
            }
          }
        }
      } catch (e) {
        debugPrint("Error fetching Dhikr counts from Firestore: $e");
      }
    }
  }

  Future<void> _syncDhikrToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final lifetimeTotal = prefs.getInt('dhikr_lifetime_total') ?? 0;

    final Map<String, int> dailyHistory = {};
    final Map<String, Map<String, int>> presetsDaily = {};

    final now = DateTime.now();
    for (int i = 0; i < 30; i++) {
      final day = now.subtract(Duration(days: i));
      final dateKey = DateFormat('yyyyMMdd').format(day);
      final key = 'dhikr_daily_$dateKey';
      final val = prefs.getInt(key) ?? 0;
      if (val > 0) {
        dailyHistory[dateKey] = val;

        final Map<String, int> breakdown = {};
        for (final preset in [..._presets, const _DhikrPreset(name: 'Custom', arabic: '', translit: '', meaning: '', virtue: '', target: 0, icon: Icons.tune_rounded)]) {
          final presetKey = preset.name.replaceAll(' ', '_');
          final todayPresetKey = '${key}_$presetKey';
          final count = prefs.getInt(todayPresetKey) ?? 0;
          if (count > 0) {
            breakdown[presetKey] = count;
          }
        }
        if (breakdown.isNotEmpty) {
          presetsDaily[dateKey] = breakdown;
        }
      }
    }

    final Map<String, int> presetsLifetime = {};
    for (final preset in [..._presets, const _DhikrPreset(name: 'Custom', arabic: '', translit: '', meaning: '', virtue: '', target: 0, icon: Icons.tune_rounded)]) {
      final presetKey = preset.name.replaceAll(' ', '_');
      final key = 'dhikr_lifetime_$presetKey';
      final count = prefs.getInt(key) ?? 0;
      if (count > 0) {
        presetsLifetime[presetKey] = count;
      }
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'dhikr': {
          'lifetimeTotal': lifetimeTotal,
          'dailyHistory': dailyHistory,
          'presetsDaily': presetsDaily,
          'presetsLifetime': presetsLifetime,
          'lastUpdated': FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error syncing Dhikr counts to Firestore: $e");
    }
  }

  Future<void> _loadReminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    for (final type in _reminderTimes.keys) {
      final key = type.replaceAll(' ', '_');
      final storedMinutes = prefs.getInt('dhikr_reminder_time_$key');
      final enabled = prefs.getBool('dhikr_reminder_enabled_$key') ?? false;
      if (storedMinutes != null) {
        _reminderTimes[type] = TimeOfDay(hour: storedMinutes ~/ 60, minute: storedMinutes % 60);
      }
      _reminders[type] = enabled;
    }
    if (mounted) setState(() {});
  }

  Future<void> _dismissHint() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dhikr_hint_dismissed', true);
    setState(() => _showHint = false);
  }

  Future<void> _persistTap() async {
    final prefs = await SharedPreferences.getInstance();
    final today = (prefs.getInt(_todayKey) ?? 0) + 1;
    final lifetime = (prefs.getInt('dhikr_lifetime_total') ?? 0) + 1;
    await prefs.setInt(_todayKey, today);
    await prefs.setInt('dhikr_lifetime_total', lifetime);

    final String presetKey = _activePreset.name.replaceAll(' ', '_');
    final String todayPresetKey = '${_todayKey}_$presetKey';
    await prefs.setInt(todayPresetKey, (prefs.getInt(todayPresetKey) ?? 0) + 1);

    final String lifetimePresetKey = 'dhikr_lifetime_$presetKey';
    await prefs.setInt(lifetimePresetKey, (prefs.getInt(lifetimePresetKey) ?? 0) + 1);

    if (!mounted) return;
    setState(() {
      _todayTotal = today;
      _lifetimeTotal = lifetime;
      if (_currentStreak == 0) _currentStreak = 1;
    });

    _dbWriteTimer?.cancel();
    _dbWriteTimer = Timer(const Duration(milliseconds: 1500), () {
      _syncDhikrToFirestore();
    });
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    _tapPulseController.forward(from: 0);
    if (_showHint) _dismissHint();

    setState(() => _count++);
    _persistTap();

    if (_count >= _activePreset.target) {
      HapticFeedback.mediumImpact();
      if (_isSequenceMode && _sequencePhase < _tasbihFatimahSequence.length - 1) {
        setState(() {
          _sequencePhase++;
          _count = 0;
        });
        _showSnack('${_tasbihFatimahSequence[_sequencePhase - 1].name} complete! Next: ${_tasbihFatimahSequence[_sequencePhase].name}');
      } else if (_isSequenceMode) {
        _showSnack('Tasbih Fatimah complete! 🌙 May Allah accept your dhikr.');
        setState(() {
          _isSequenceMode = false;
          _sequencePhase = 0;
          _count = 0;
        });
      } else {
        _showSnack('${_activePreset.name} target reached! 🎉');
        setState(() => _count = 0);
      }
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: GoogleFonts.inter(fontSize: 13)),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: AppColors.navyBlue,
      ),
    );
  }

  void _resetCounter() {
    setState(() {
      _count = 0;
      if (_isSequenceMode) _sequencePhase = 0;
    });
  }

  void _selectPreset(int index) {
    setState(() {
      _isSequenceMode = false;
      _selectedPresetIndex = index;
      _count = 0;
    });
  }

  void _startTasbihFatimah() {
    setState(() {
      _isSequenceMode = true;
      _sequencePhase = 0;
      _count = 0;
    });
  }

  void _editCustomTarget() {
    final ctrl = TextEditingController(text: _customTarget.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg(),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Set Custom Target', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _primaryText())),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: GoogleFonts.inter(color: _primaryText()),
          decoration: InputDecoration(
            hintText: 'e.g. 500',
            hintStyle: GoogleFonts.inter(color: _secondaryText()),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.placeholder))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.navyBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              final val = int.tryParse(ctrl.text);
              if (val != null && val > 0) {
                setState(() {
                  _customTarget = val;
                  _selectedPresetIndex = _presets.length;
                  _isSequenceMode = false;
                  _count = 0;
                });
              }
              Navigator.pop(context);
            },
            child: Text('Save', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ===== REMINDER TIME CUSTOMIZATION =====
  Future<void> _pickReminderTime(String type) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _reminderTimes[type] ?? const TimeOfDay(hour: 7, minute: 0),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.navyBlue)),
        child: child!,
      ),
    );
    if (picked == null) return;

    setState(() => _reminderTimes[type] = picked);
    final prefs = await SharedPreferences.getInstance();
    final key = type.replaceAll(' ', '_');
    await prefs.setInt('dhikr_reminder_time_$key', picked.hour * 60 + picked.minute);
    _showSnack('⏰ Time saved: ${picked.format(context)}. Turn the switch on to activate it.');

    if (_reminders[type] == true) {
      await _scheduleReminder(type);
    }
  }

  Future<void> _scheduleReminder(String type) async {
    final time = _reminderTimes[type]!;
    final now = DateTime.now();
    DateTime scheduled = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));
    final int id = 3000 + type.hashCode % 1000;
    final bool isMorning = type == 'Morning Adhkar';
    await NotificationService.instance.scheduleCustomNotification(
      id: id,
      title: isMorning ? 'Morning Adhkar Reminder' : 'Evening Adhkar Reminder',
      body: isMorning
          ? 'Time for your morning remembrance — a few minutes of dhikr to start the day.'
          : 'Time for your evening remembrance — close the day with dhikr.',
      scheduledTime: scheduled,
      category: 'dhikr',
      targetRoute: '/dhikr',
    );
  }

  Future<void> _toggleReminder(String type) async {
    final bool current = _reminders[type] ?? false;
    final bool newState = !current;
    setState(() => _reminders[type] = newState);

    final prefs = await SharedPreferences.getInstance();
    final key = type.replaceAll(' ', '_');
    await prefs.setBool('dhikr_reminder_enabled_$key', newState);

    if (newState) {
      await _scheduleReminder(type);
      _showSnack('🔔 $type reminder set for ${_reminderTimes[type]!.format(context)}');
    } else {
      _showSnack('🔕 $type reminder disabled');
    }
  }

@override
  Widget build(BuildContext context) {
    return Container(
      color: _letterboxBg(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Scaffold(
            backgroundColor: _pageBg(),
body: SafeArea(
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 12),
                    _buildTabBar(),
                    Expanded(
                      child: _buildTabContent(),
                    ),
                  ],
                ),
              ),
          ),
        ),
      ),
    );
  }

  // ===== HEADER =====
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: _primaryText(), size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: _dark
                  ? null
                  : const LinearGradient(colors: [AppColors.navyBlue, Color(0xFF1D3550)]),
              color: _dark ? Colors.white.withValues(alpha: 0.15) : null,
              borderRadius: BorderRadius.circular(14),
              border: _dark ? Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1) : null,
            ),
            child: const Icon(Icons.fingerprint_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dhikr Counter', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryText())),
                Text('Remember Allah, in every moment', style: GoogleFonts.inter(fontSize: 11, color: _secondaryText())),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final cardBg = _dark ? const Color(0xFF1E1E1E) : Colors.white;

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
                            : (_dark ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.4))),
                    const SizedBox(height: 2),
                    Text(_tabLabels[i],
                        style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: active
                                ? Colors.white
                                : (_dark ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.4)))),
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
        return _buildCounterTab();
      case 1:
        return _buildAdhkarTab();
      case 2:
        return _buildStatsHistoryTab();
      case 3:
        return _buildRemindersAchievementsTab();
      default:
        return _buildCounterTab();
    }
  }

  Widget _sectionLabel(String title, IconData icon) {
    return Row(
      children: [
        Container(width: 4, height: 16, decoration: BoxDecoration(color: AppColors.navyBlue, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Icon(icon, size: 15, color: _iconTint()),
        const SizedBox(width: 5),
        Text(title, style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.bold, color: _primaryText())),
      ],
    );
  }

   // TAB 1: COUNTER
 
  Widget _buildCounterTab() {
    return ListView(
      key: const ValueKey('CounterTab'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (_showHint) _buildHintCard(),
        if (_showHint) const SizedBox(height: 16),
        _buildMeaningCard(),
        const SizedBox(height: 24),
        _buildCounterCircle(),
        const SizedBox(height: 8),
        Center(
          child: Text('👆 Tap the circle above to count',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _secondaryText(alpha: 0.4))),
        ),
        const SizedBox(height: 18),
        _buildCounterActions(),
        const SizedBox(height: 26),
        _sectionLabel('Choose a Dhikr to Count', Icons.touch_app_rounded),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 12),
          child: Text('Tap a card below to switch what you\'re counting.',
              style: GoogleFonts.inter(fontSize: 11.5, color: _secondaryText(alpha: 0.45))),
        ),
        _buildPresetList(),
      ],
    );
  }

  Widget _buildHintCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.midTeal.withValues(alpha: _dark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.midTeal.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_rounded, color: AppColors.midTeal, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'How it works: pick a Dhikr below, then tap the big circle once per repetition. It fills up as you go and celebrates when you hit the target!',
              style: GoogleFonts.inter(fontSize: 11.5, color: _secondaryText(alpha: 0.75), height: 1.5),
            ),
          ),
          GestureDetector(onTap: _dismissHint, child: Icon(Icons.close_rounded, size: 16, color: _secondaryText(alpha: 0.4))),
        ],
      ),
    );
  }

  Widget _buildMeaningCard() {
    final preset = _activePreset;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.navyBlue, Color(0xFF1D3550)]),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: AppColors.navyBlue.withValues(alpha: 0.22), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  _isSequenceMode ? 'Tasbih Fatimah — Phase ${_sequencePhase + 1}/3' : 'Now Counting',
                  style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
              Icon(preset.icon, color: Colors.white.withValues(alpha: 0.7), size: 20),
            ],
          ),
          const SizedBox(height: 14),
          if (preset.arabic.isNotEmpty)
            Text(preset.arabic, textAlign: TextAlign.right, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: Colors.white, height: 1.6)),
          if (preset.arabic.isNotEmpty) const SizedBox(height: 8),
          Text(preset.translit, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(preset.meaning, style: GoogleFonts.inter(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.75))),
          if (preset.virtue.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_stories_rounded, color: Colors.white70, size: 14),
                  const SizedBox(width: 6),
                  Expanded(child: Text(preset.virtue, style: GoogleFonts.inter(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.8), height: 1.4))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCounterCircle() {
    final target = _activePreset.target;
    final progress = target > 0 ? (_count / target).clamp(0.0, 1.0) : 0.0;

    return Center(
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedBuilder(
          animation: Listenable.merge([_tapPulseController, _breathController]),
          builder: (context, child) {
            final tapScale = 1.0 - (_tapPulseController.value * 0.05);
            final breathGlow = 0.15 + (_breathController.value * 0.15);
            return Transform.scale(
              scale: tapScale,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppColors.midTeal.withValues(alpha: breathGlow), blurRadius: 40, spreadRadius: 6)],
                ),
                child: child,
              ),
            );
          },
          child: SizedBox(
            width: 220,
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 220,
                  height: 220,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 11,
                    backgroundColor: _dark ? Colors.white.withValues(alpha: 0.10) : AppColors.navyBlue.withValues(alpha: 0.07),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.midTeal),
                  ),
                ),
                Container(
                  width: 178,
                  height: 178,
                  decoration: BoxDecoration(
                    color: _cardBg(),
                    shape: BoxShape.circle,
                    border: _dark ? Border.all(color: Colors.white.withValues(alpha: 0.16), width: 1.2) : null,
                    boxShadow: [
                      BoxShadow(
                        color: _dark ? Colors.black.withValues(alpha: 0.5) : AppColors.navyBlue.withValues(alpha: 0.1),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.touch_app_rounded, size: 16, color: AppColors.midTeal.withValues(alpha: 0.5)),
                      const SizedBox(height: 4),
                      Text('$_count', style: GoogleFonts.poppins(fontSize: 46, fontWeight: FontWeight.bold, color: _primaryText())),
                      Text('of $target', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _secondaryText(alpha: 0.45))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCounterActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _actionChip(icon: Icons.refresh_rounded, label: 'Reset', onTap: _resetCounter),
        const SizedBox(width: 10),
        _actionChip(icon: Icons.auto_awesome_rounded, label: 'Tasbih Fatimah', onTap: _startTasbihFatimah, highlighted: _isSequenceMode),
        const SizedBox(width: 10),
        _actionChip(icon: Icons.tune_rounded, label: 'Custom', onTap: _editCustomTarget),
      ],
    );
  }

  Widget _actionChip({required IconData icon, required String label, required VoidCallback onTap, bool highlighted = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: highlighted ? AppColors.midTeal.withValues(alpha: 0.15) : _cardBg(),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: highlighted ? AppColors.midTeal : _cardBorder()),
          boxShadow: highlighted || _dark
              ? []
              : [BoxShadow(color: AppColors.navyBlue.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: highlighted ? AppColors.midTeal : _iconTint()),
            const SizedBox(width: 5),
            Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: highlighted ? AppColors.midTeal : _secondaryText(alpha: 0.7))),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetList() {
    final bool customSelected = !_isSequenceMode && _selectedPresetIndex == _presets.length;
    return Column(
      children: [
        ...List.generate(_presets.length, (i) {
          final preset = _presets[i];
          final selected = !_isSequenceMode && _selectedPresetIndex == i;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => _selectPreset(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: selected ? AppColors.navyBlue : _cardBg(),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: selected ? AppColors.navyBlue : _cardBorder(), width: selected ? 2 : 1),
                  boxShadow: [
                    BoxShadow(
                      color: _dark
                          ? Colors.black.withValues(alpha: selected ? 0.3 : 0.4)
                          : AppColors.navyBlue.withValues(alpha: selected ? 0.15 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: selected ? Colors.white.withValues(alpha: 0.15) : AppColors.midTeal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: Icon(preset.icon, color: selected ? Colors.white : AppColors.midTeal, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(preset.name, style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: selected ? Colors.white : _primaryText())),
                          const SizedBox(height: 2),
                          Text(preset.meaning, style: GoogleFonts.inter(fontSize: 10.5, color: selected ? Colors.white.withValues(alpha: 0.65) : _secondaryText(alpha: 0.45))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: selected ? Colors.white.withValues(alpha: 0.15) : (_dark ? Colors.white.withValues(alpha: 0.1) : AppColors.navyBlue.withValues(alpha: 0.06)), borderRadius: BorderRadius.circular(10)),
                      child: Text('${preset.target}x', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: selected ? Colors.white : _primaryText())),
                    ),
                    if (selected) ...[const SizedBox(width: 8), const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20)],
                  ],
                ),
              ),
            ),
          );
        }),
        GestureDetector(
          onTap: _editCustomTarget,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: customSelected ? AppColors.navyBlue : _cardBg(),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: customSelected ? AppColors.navyBlue : _cardBorder(), width: customSelected ? 2 : 1),
              boxShadow: [
                BoxShadow(
                  color: _dark
                      ? Colors.black.withValues(alpha: customSelected ? 0.3 : 0.4)
                      : AppColors.navyBlue.withValues(alpha: customSelected ? 0.15 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: customSelected ? Colors.white.withValues(alpha: 0.15) : AppColors.coralOrange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.tune_rounded, color: customSelected ? Colors.white : AppColors.coralOrange, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Custom Target', style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: customSelected ? Colors.white : _primaryText())),
                      const SizedBox(height: 2),
                      Text(customSelected ? 'Currently active — tap to change' : 'Set your own count target',
                          style: GoogleFonts.inter(fontSize: 10.5, color: customSelected ? Colors.white.withValues(alpha: 0.65) : _secondaryText(alpha: 0.45))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: customSelected ? Colors.white.withValues(alpha: 0.15) : (_dark ? Colors.white.withValues(alpha: 0.1) : AppColors.navyBlue.withValues(alpha: 0.06)), borderRadius: BorderRadius.circular(10)),
                  child: Text('${_customTarget}x', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: customSelected ? Colors.white : _primaryText())),
                ),
                if (customSelected) ...[const SizedBox(width: 8), const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20)],
              ],
            ),
          ),
        ),
      ],
    );
  }

  
  // TAB 2: ADHKAR COLLECTIONS (Morning & Evening)
  
  Widget _buildAdhkarTab() {
    final list = _showMorningAdhkar ? _morningAdhkar : _eveningAdhkar;
    return ListView(
      key: const ValueKey('AdhkarTab'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: _dark ? Colors.white.withValues(alpha: 0.08) : AppColors.navyBlue.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showMorningAdhkar = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(color: _showMorningAdhkar ? AppColors.navyBlue : Colors.transparent, borderRadius: BorderRadius.circular(11)),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wb_sunny_rounded, size: 15, color: _showMorningAdhkar ? Colors.white : _secondaryText(alpha: 0.5)),
                        const SizedBox(width: 6),
                        Text('Morning', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w700, color: _showMorningAdhkar ? Colors.white : _secondaryText(alpha: 0.5))),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showMorningAdhkar = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(color: !_showMorningAdhkar ? AppColors.navyBlue : Colors.transparent, borderRadius: BorderRadius.circular(11)),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.nights_stay_rounded, size: 15, color: !_showMorningAdhkar ? Colors.white : _secondaryText(alpha: 0.5)),
                        const SizedBox(width: 6),
                        Text('Evening', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w700, color: !_showMorningAdhkar ? Colors.white : _secondaryText(alpha: 0.5))),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ...list.map((item) => GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => _AdhkarDetailPage(item: item, isDarkMode: _dark)),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _cardBg(),
                  borderRadius: BorderRadius.circular(18),
                  border: _dark ? Border.all(color: Colors.white.withValues(alpha: 0.14)) : null,
                  boxShadow: _dark
                      ? []
                      : [BoxShadow(color: AppColors.navyBlue.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title, style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: _primaryText())),
                          const SizedBox(height: 4),
                          Text(item.transliteration, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 10.5, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600, color: AppColors.midTeal)),
                          const SizedBox(height: 4),
                          Text(item.fullMeaning, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 11.5, color: _secondaryText(alpha: 0.55), height: 1.4)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.repeat_rounded, size: 12, color: _secondaryText(alpha: 0.4)),
                              const SizedBox(width: 4),
                              Text('Recommended: ${item.recommendedCount}x', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: _secondaryText(alpha: 0.4))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: AppColors.midTeal.withValues(alpha: _dark ? 0.18 : 0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.midTeal, size: 12),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  // TAB 3: STATS & HISTORY

  Widget _buildStatsHistoryTab() {
    return ListView(
      key: const ValueKey('StatsTab'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _sectionLabel("Today's Progress", Icons.today_rounded),
        const SizedBox(height: 12),
        _buildStatsRow(),
        const SizedBox(height: 24),
        _sectionLabel('Last 7 Days', Icons.history_rounded),
        const SizedBox(height: 12),
        _buildHistoryList(),
        const SizedBox(height: 24),
        _buildRewardCard(),
      ],
    );
  }

  Widget _buildRewardCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1C3A27), AppColors.navyBlue]),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: AppColors.navyBlue.withValues(alpha: 0.2), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: const Icon(Icons.spa_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text('The Reward of Dhikr', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Allah says He remembers whoever remembers Him — and that in the gathering of angels, He mentions that person by name.',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.9), height: 1.6, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 8),
          Text('— based on Surah Al-Baqarah 2:152 and a well-known Hadith Qudsi',
              style: GoogleFonts.inter(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.6))),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
            child: Text(
              'Every SubhanAllah, Alhamdulillah, and Allahu Akbar is a small deed with a reward far greater than its size — a gentle, steady way to fill your scale of good deeds each day.',
              style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.85), height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _statCard(icon: Icons.today_rounded, label: 'Today', value: '$_todayTotal', color: AppColors.navyBlue, onTap: _showTodayDetails)),
        const SizedBox(width: 10),
        Expanded(child: _statCard(icon: Icons.local_fire_department_rounded, label: 'Streak', value: '$_currentStreak d', color: AppColors.coralOrange, onTap: _showStreakDetails)),
        const SizedBox(width: 10),
        Expanded(child: _statCard(icon: Icons.all_inclusive_rounded, label: 'Lifetime', value: '$_lifetimeTotal', color: AppColors.midTeal, onTap: _showLifetimeDetails)),
      ],
    );
  }

  Widget _statCard({required IconData icon, required String label, required String value, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color.withValues(alpha: _dark ? 0.16 : 0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: _dark ? 0.35 : 0.2))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(icon, color: color, size: 18), Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.4), size: 16)]),
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.inter(fontSize: 10.5, color: _secondaryText(alpha: 0.5))),
            const SizedBox(height: 2),
            Text(value, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: _primaryText())),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    return FutureBuilder<List<MapEntry<String, int>>>(
      future: _get7DayHistory(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator()));
        }
        final data = snapshot.data!;
        final maxVal = data.map((e) => e.value).fold<int>(0, (a, b) => a > b ? a : b);
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardBg(),
            borderRadius: BorderRadius.circular(18),
            border: _dark ? Border.all(color: Colors.white.withValues(alpha: 0.14)) : null,
            boxShadow: _dark ? [] : [BoxShadow(color: AppColors.navyBlue.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Column(
            children: data.map((e) {
              final fraction = maxVal > 0 ? e.value / maxVal : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(width: 70, child: Text(e.key, style: GoogleFonts.inter(fontSize: 11, color: _secondaryText(alpha: 0.6)))),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: fraction,
                          minHeight: 10,
                          backgroundColor: _dark ? Colors.white.withValues(alpha: 0.1) : AppColors.navyBlue.withValues(alpha: 0.06),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.midTeal),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(width: 32, child: Text('${e.value}', textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.bold, color: _primaryText()))),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<List<MapEntry<String, int>>> _get7DayHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<MapEntry<String, int>> result = [];
    DateTime day = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final key = 'dhikr_daily_${DateFormat('yyyyMMdd').format(day)}';
      final count = prefs.getInt(key) ?? 0;
      final label = i == 0 ? 'Today' : DateFormat('EEE').format(day);
      result.add(MapEntry(label, count));
      day = day.subtract(const Duration(days: 1));
    }
    return result.reversed.toList();
  }

  
  // TAB 4: REMINDERS & ACHIEVEMENTS
  
  Widget _buildRemindersAchievementsTab() {
    return ListView(
      key: const ValueKey('RemindersTab'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _sectionLabel('Smart Reminders', Icons.notifications_active_rounded),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 12),
          child: Text('Tap the time to customize it, then use the switch to turn it on.',
              style: GoogleFonts.inter(fontSize: 11.5, color: _secondaryText(alpha: 0.45))),
        ),
        _buildReminderTile(type: 'Morning Adhkar', icon: Icons.wb_sunny_rounded),
        const SizedBox(height: 10),
        _buildReminderTile(type: 'Evening Adhkar', icon: Icons.nights_stay_rounded),
        const SizedBox(height: 26),
        _sectionLabel('Achievements', Icons.emoji_events_rounded),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 12),
          child: Text('Unlocked automatically as you keep counting.', style: GoogleFonts.inter(fontSize: 11.5, color: _secondaryText(alpha: 0.45))),
        ),
        _buildAchievementsGrid(),
      ],
    );
  }

  Widget _buildReminderTile({required String type, required IconData icon}) {
    final bool active = _reminders[type] ?? false;
    final TimeOfDay time = _reminderTimes[type]!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg(),
        borderRadius: BorderRadius.circular(16),
        border: _dark ? Border.all(color: Colors.white.withValues(alpha: 0.14)) : null,
        boxShadow: _dark ? [] : [BoxShadow(color: AppColors.navyBlue.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: _dark ? Colors.white.withValues(alpha: 0.10) : AppColors.navyBlue.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: _primaryText(), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: _primaryText())),
                const SizedBox(height: 3),
                GestureDetector(
                  onTap: () => _pickReminderTime(type),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.midTeal.withValues(alpha: _dark ? 0.18 : 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time_rounded, size: 12, color: AppColors.midTeal),
                        const SizedBox(width: 4),
                        Text(time.format(context), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.midTeal)),
                        const SizedBox(width: 3),
                        const Icon(Icons.edit_rounded, size: 10, color: AppColors.midTeal),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: active,
            onChanged: (_) => _toggleReminder(type),
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.midTeal,
            inactiveTrackColor: _dark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFE0E0E0),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsGrid() {
    return FutureBuilder<Map<String, int>>(
      future: _getAchievementProgress(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
        final lifetime = snapshot.data!['lifetime'] ?? 0;
        final streak = snapshot.data!['streak'] ?? 0;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.95),
          itemCount: _badges.length,
          itemBuilder: (context, index) {
            final badge = _badges[index];
            final current = badge.type == 'lifetime' ? lifetime : streak;
            final unlocked = current >= badge.threshold;
            final progress = (current / badge.threshold).clamp(0.0, 1.0);

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: unlocked ? AppColors.midTeal.withValues(alpha: _dark ? 0.16 : 0.08) : _cardBg(),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: unlocked ? AppColors.midTeal.withValues(alpha: 0.3) : _cardBorder()),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: unlocked ? AppColors.midTeal.withValues(alpha: 0.15) : (_dark ? Colors.white.withValues(alpha: 0.08) : AppColors.navyBlue.withValues(alpha: 0.06)), shape: BoxShape.circle),
                    child: Icon(badge.icon, color: unlocked ? AppColors.midTeal : _secondaryText(alpha: 0.35), size: 20),
                  ),
                  const SizedBox(height: 10),
                  Text(badge.title, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: unlocked ? _primaryText() : _secondaryText(alpha: 0.5))),
                  const SizedBox(height: 4),
                  Text(badge.description, style: GoogleFonts.inter(fontSize: 9.5, color: _secondaryText(alpha: 0.4)), maxLines: 2),
                  const Spacer(),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: _dark ? Colors.white.withValues(alpha: 0.1) : AppColors.navyBlue.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation<Color>(unlocked ? AppColors.midTeal : _secondaryText(alpha: 0.25)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(unlocked ? 'Unlocked!' : '$current / ${badge.threshold}',
                      style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w600, color: unlocked ? AppColors.midTeal : _secondaryText(alpha: 0.4))),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<Map<String, int>> _getAchievementProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final lifetime = prefs.getInt('dhikr_lifetime_total') ?? 0;
    return {'lifetime': lifetime, 'streak': _currentStreak};
  }

  // ===== DETAIL POPUPS (small card, blurred backdrop) =====
  void _showTodayDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final List<MapEntry<String, int>> breakdown = [];
    for (final preset in [..._presets, const _DhikrPreset(name: 'Custom', arabic: '', translit: '', meaning: '', virtue: '', target: 0, icon: Icons.tune_rounded)]) {
      final key = '${_todayKey}_${preset.name.replaceAll(' ', '_')}';
      final count = prefs.getInt(key) ?? 0;
      if (count > 0) breakdown.add(MapEntry(preset.name, count));
    }
    if (!mounted) return;
    _showDetailSheet(
      title: "Today's Dhikr",
      subtitle: DateFormat('EEEE, MMMM d').format(DateTime.now()),
      icon: Icons.today_rounded,
      color: AppColors.navyBlue,
      rows: breakdown.isEmpty ? [const MapEntry('No dhikr counted yet today', 0)] : breakdown,
      totalLabel: 'Total today',
      totalValue: _todayTotal,
    );
  }

  void _showStreakDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final List<MapEntry<String, int>> lastDays = [];
    DateTime day = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final key = 'dhikr_daily_${DateFormat('yyyyMMdd').format(day)}';
      final count = prefs.getInt(key) ?? 0;
      final label = i == 0 ? 'Today' : DateFormat('EEE, MMM d').format(day);
      lastDays.add(MapEntry(label, count));
      day = day.subtract(const Duration(days: 1));
    }
    if (!mounted) return;
    _showDetailSheet(
      title: 'Your Streak',
      subtitle: _currentStreak > 0 ? '$_currentStreak day${_currentStreak == 1 ? '' : 's'} in a row 🔥' : 'Start today to begin a streak!',
      icon: Icons.local_fire_department_rounded,
      color: AppColors.coralOrange,
      rows: lastDays,
      totalLabel: 'Current streak',
      totalValue: _currentStreak,
      totalSuffix: ' days',
    );
  }

  void _showLifetimeDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final List<MapEntry<String, int>> breakdown = [];
    for (final preset in _presets) {
      final key = 'dhikr_lifetime_${preset.name.replaceAll(' ', '_')}';
      final count = prefs.getInt(key) ?? 0;
      if (count > 0) breakdown.add(MapEntry(preset.name, count));
    }
    final customCount = prefs.getInt('dhikr_lifetime_Custom') ?? 0;
    if (customCount > 0) breakdown.add(MapEntry('Custom', customCount));

    if (!mounted) return;
    _showDetailSheet(
      title: 'Lifetime Dhikr',
      subtitle: 'Everything you\'ve counted since you started',
      icon: Icons.all_inclusive_rounded,
      color: AppColors.midTeal,
      rows: breakdown.isEmpty ? [const MapEntry('No history yet', 0)] : breakdown,
      totalLabel: 'Grand total',
      totalValue: _lifetimeTotal,
    );
  }

  void _showDetailSheet({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<MapEntry<String, int>> rows,
    required String totalLabel,
    required int totalValue,
    String totalSuffix = '',
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim, secondaryAnim, child) {
        return BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 6 * anim.value, sigmaY: 6 * anim.value),
          child: FadeTransition(
            opacity: anim,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1.0).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: Container(
                color: Colors.black.withValues(alpha: 0.25 * anim.value),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _cardBg(),
                          borderRadius: BorderRadius.circular(24),
                          border: _dark ? Border.all(color: Colors.white.withValues(alpha: 0.16)) : null,
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: _dark ? 0.5 : 0.15), blurRadius: 30, offset: const Offset(0, 12))],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: color.withValues(alpha: _dark ? 0.18 : 0.1), borderRadius: BorderRadius.circular(12)),
                                  child: Icon(icon, color: color, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: _primaryText())),
                                      Text(subtitle, style: GoogleFonts.inter(fontSize: 10.5, color: _secondaryText(alpha: 0.5))),
                                    ],
                                  ),
                                ),
                                GestureDetector(onTap: () => Navigator.pop(context), child: Icon(Icons.close_rounded, size: 18, color: _secondaryText(alpha: 0.4))),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ...rows.map((r) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 5),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(child: Text(r.key, style: GoogleFonts.inter(fontSize: 12.5, color: _secondaryText(alpha: 0.75)))),
                                      if (r.value > 0) Text('${r.value}', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: _primaryText())),
                                    ],
                                  ),
                                )),
                            Divider(height: 22, color: _dark ? Colors.white.withValues(alpha: 0.14) : null),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              decoration: BoxDecoration(color: color.withValues(alpha: _dark ? 0.18 : 0.08), borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(totalLabel, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _primaryText())),
                                  Text('$totalValue$totalSuffix', style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.bold, color: color)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ===== ADHKAR DETAIL PAGE =====
class _AdhkarDetailPage extends StatelessWidget {
  final _AdhkarItem item;
  final bool isDarkMode;
  const _AdhkarDetailPage({required this.item, this.isDarkMode = false});

  bool _dark(BuildContext context) => isDarkMode || Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final dark = _dark(context);
    final Color primaryText = dark ? Colors.white : AppColors.navyBlue;
    final Color secondaryText = dark ? Colors.white.withValues(alpha: 0.65) : AppColors.navyBlue.withValues(alpha: 0.8);
    final Color cardBg = dark ? Colors.black : Colors.white;
    final Color cardBorder = dark ? Colors.white.withValues(alpha: 0.16) : AppColors.navyBlue.withValues(alpha: 0.08);

    return Container(
      color: dark ? Colors.black : const Color(0xFFE8E8E8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Scaffold(
            backgroundColor: dark ? Colors.black : const Color(0xFFF7F7F5),
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back_ios_new_rounded, color: primaryText, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Text(item.title, style: GoogleFonts.poppins(fontSize: 15.5, fontWeight: FontWeight.bold, color: primaryText)),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      children: [
                        // Arabic text card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.navyBlue, Color(0xFF1D3550)]),
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [BoxShadow(color: AppColors.navyBlue.withValues(alpha: 0.2), blurRadius: 18, offset: const Offset(0, 8))],
                          ),
                          child: Text(
                            item.fullArabic,
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white, height: 2.0),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Transliteration
                        Row(
                          children: [
                            const Icon(Icons.record_voice_over_rounded, size: 16, color: AppColors.coralOrange),
                            const SizedBox(width: 6),
                            Text('How to Pronounce', style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: primaryText)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.coralOrange.withValues(alpha: dark ? 0.12 : 0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.coralOrange.withValues(alpha: dark ? 0.35 : 0.2)),
                          ),
                          child: Text(item.transliteration, style: GoogleFonts.inter(fontSize: 13, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600, color: secondaryText, height: 1.7)),
                        ),
                        const SizedBox(height: 20),
                        // English meaning
                        Row(
                          children: [
                            const Icon(Icons.translate_rounded, size: 16, color: AppColors.midTeal),
                            const SizedBox(width: 6),
                            Text('English Meaning', style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: primaryText)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: dark ? Border.all(color: cardBorder) : null,
                            boxShadow: dark ? [] : [BoxShadow(color: AppColors.navyBlue.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
                          ),
                          child: Text(item.fullMeaning, style: GoogleFonts.inter(fontSize: 13.5, color: secondaryText, height: 1.7)),
                        ),
                        const SizedBox(height: 20),
                        // Virtue
                        Row(
                          children: [
                            const Icon(Icons.auto_stories_rounded, size: 16, color: AppColors.coralOrange),
                            const SizedBox(width: 6),
                            Text('Virtue', style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: primaryText)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: AppColors.coralOrange.withValues(alpha: dark ? 0.14 : 0.08), borderRadius: BorderRadius.circular(16)),
                          child: Text(item.virtue, style: GoogleFonts.inter(fontSize: 12.5, color: secondaryText.withValues(alpha: dark ? 0.85 : 0.7), height: 1.6)),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: dark ? Colors.white.withValues(alpha: 0.10) : AppColors.navyBlue.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.repeat_rounded, size: 13, color: secondaryText.withValues(alpha: dark ? 0.7 : 0.5)),
                              const SizedBox(width: 5),
                              Text('Recommended: ${item.recommendedCount}x', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: secondaryText.withValues(alpha: dark ? 0.8 : 0.6))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}