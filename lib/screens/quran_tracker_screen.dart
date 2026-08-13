import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/auth_header.dart'; // AppColors

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS & STRUCTS
// ─────────────────────────────────────────────────────────────────────────────

class SurahInfo {
  final int id;
  final String name;
  final String englishName;
  final int totalAyahs;
  final String type; // Makki or Madani
  final int startJuz;

  const SurahInfo(this.id, this.name, this.englishName, this.totalAyahs, this.type, this.startJuz);
}

class AyahContent {
  final int number;
  final String arabic;
  final String banglaTranslation;
  final String englishTranslation;
  final String banglaExplanation;
  final String englishExplanation;
  final int? page;

  const AyahContent({
    required this.number,
    required this.arabic,
    required this.banglaTranslation,
    required this.englishTranslation,
    required this.banglaExplanation,
    required this.englishExplanation,
    this.page,
  });
}

class DailyVerse {
  final String arabic;
  final String bangla;
  final String english;
  final String reference;
  final String explanation;

  const DailyVerse({
    required this.arabic,
    required this.bangla,
    required this.english,
    required this.reference,
    required this.explanation,
  });
}

class HadithWazifa {
  final String title;
  final String recitationCount;
  final String benefitBangla;
  final String benefitEnglish;
  final String hadithReference;
  final String targetDay;
  final int? surahId;
  final String? arabicText;
  final String? banglaPronunciation;
  final String? banglaTranslation;
  final String? readingRules;

  const HadithWazifa({
    required this.title,
    required this.recitationCount,
    required this.benefitBangla,
    required this.benefitEnglish,
    required this.hadithReference,
    required this.targetDay,
    this.surahId,
    this.arabicText,
    this.banglaPronunciation,
    this.banglaTranslation,
    this.readingRules,
  });
}

class CustomWazifa {
  final String title;
  final String? benefitBangla;
  final String? benefitEnglish;
  final String? arabicText;
  final String? banglaPronunciation;
  final String? banglaTranslation;
  final String? readingRules;

  CustomWazifa({
    required this.title,
    this.benefitBangla,
    this.benefitEnglish,
    this.arabicText,
    this.banglaPronunciation,
    this.banglaTranslation,
    this.readingRules,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'benefitBangla': benefitBangla,
    'benefitEnglish': benefitEnglish,
    'arabicText': arabicText,
    'banglaPronunciation': banglaPronunciation,
    'banglaTranslation': banglaTranslation,
    'readingRules': readingRules,
  };

  factory CustomWazifa.fromJson(Map<String, dynamic> json) => CustomWazifa(
    title: json['title'] as String,
    benefitBangla: json['benefitBangla'] as String?,
    benefitEnglish: json['benefitEnglish'] as String?,
    arabicText: json['arabicText'] as String?,
    banglaPronunciation: json['banglaPronunciation'] as String?,
    banglaTranslation: json['banglaTranslation'] as String?,
    readingRules: json['readingRules'] as String?,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// QURAN TRACKER & SPIRITUAL ENGINE
// ─────────────────────────────────────────────────────────────────────────────

class QuranTrackerScreen extends StatefulWidget {
  const QuranTrackerScreen({super.key});

  @override
  State<QuranTrackerScreen> createState() => _QuranTrackerScreenState();
}

class _QuranTrackerScreenState extends State<QuranTrackerScreen> {
  // Bottom Navigation Index: 0=Home, 1=Quran, 2=Progress, 3=Wazifa, 4=More
  int _bottomNavIndex = 0;

  // Active Reader View State (null means showing Surah List in Quran Tab)
  int? _activeReaderSurahId;
  int _activeReaderAyahIndex = 1;
  bool _isLoadingSurah = false;
  List<AyahContent> _loadedAyahs = [];

  // Tafsir cache keyed by verse_key e.g. '1:2' -> tafsir text
  final Map<String, String> _engTafsirCache = {}; // Tafsir Ibn Kathir
  final Map<String, String> _bnTafsirCache = {};  // Tafsir Ahsanul Bayaan

  // Active More view navigation
  String? _activeMoreSubView; // null, 'hifz', 'bookmarks', 'daily_ayah', 'stats', 'settings'

  // 114 Surah Details
  static const List<SurahInfo> _surahList = [
    SurahInfo(1, 'Al-Fatihah', 'The Opening', 7, 'Makki', 1),
    SurahInfo(2, 'Al-Baqarah', 'The Cow', 286, 'Madani', 1),
    SurahInfo(3, 'Ali \'Imran', 'Family of Imran', 200, 'Madani', 3),
    SurahInfo(4, 'An-Nisa', 'The Women', 176, 'Madani', 4),
    SurahInfo(5, 'Al-Ma\'idah', 'The Table Spread', 120, 'Madani', 6),
    SurahInfo(6, 'Al-An\'am', 'The Cattle', 165, 'Makki', 7),
    SurahInfo(7, 'Al-A\'raf', 'The Heights', 206, 'Makki', 8),
    SurahInfo(8, 'Al-Anfal', 'The Spoils of War', 75, 'Madani', 9),
    SurahInfo(9, 'At-Tawbah', 'The Repentance', 129, 'Madani', 10),
    SurahInfo(10, 'Yunus', 'Jonah', 109, 'Makki', 11),
    SurahInfo(11, 'Hud', 'Hud', 123, 'Makki', 11),
    SurahInfo(12, 'Yusuf', 'Joseph', 111, 'Makki', 12),
    SurahInfo(13, 'Ar-Ra\'d', 'The Thunder', 43, 'Madani', 13),
    SurahInfo(14, 'Ibrahim', 'Abraham', 52, 'Makki', 13),
    SurahInfo(15, 'Al-Hijr', 'The Rocky Tract', 99, 'Makki', 14),
    SurahInfo(16, 'An-Nahl', 'The Bee', 128, 'Makki', 14),
    SurahInfo(17, 'Al-Isra', 'The Night Journey', 111, 'Makki', 15),
    SurahInfo(18, 'Al-Kahf', 'The Cave', 110, 'Makki', 15),
    SurahInfo(19, 'Maryam', 'Mary', 98, 'Makki', 16),
    SurahInfo(20, 'Ta-Ha', 'Ta-Ha', 135, 'Makki', 16),
    SurahInfo(21, 'Al-Anbiya', 'The Prophets', 112, 'Makki', 17),
    SurahInfo(22, 'Al-Hajj', 'The Pilgrimage', 78, 'Madani', 17),
    SurahInfo(23, 'Al-Mu\'minun', 'The Believers', 118, 'Makki', 18),
    SurahInfo(24, 'An-Nur', 'The Light', 64, 'Madani', 18),
    SurahInfo(25, 'Al-Furqan', 'The Criterion', 77, 'Makki', 18),
    SurahInfo(26, 'Ash-Shu\'ara', 'The Poets', 227, 'Makki', 19),
    SurahInfo(27, 'An-Naml', 'The Ant', 93, 'Makki', 19),
    SurahInfo(28, 'Al-Qasas', 'The Stories', 88, 'Makki', 20),
    SurahInfo(29, 'Al-\'Ankabut', 'The Spider', 69, 'Makki', 20),
    SurahInfo(30, 'Ar-Rum', 'The Romans', 60, 'Makki', 21),
    SurahInfo(31, 'Luqman', 'Luqman', 34, 'Makki', 21),
    SurahInfo(32, 'As-Sajdah', 'The Prostration', 30, 'Makki', 21),
    SurahInfo(33, 'Al-Ahzab', 'The Combined Forces', 73, 'Madani', 21),
    SurahInfo(34, 'Saba', 'Sheba', 54, 'Makki', 22),
    SurahInfo(35, 'Fatir', 'The Originator', 45, 'Makki', 22),
    SurahInfo(36, 'Ya-Sin', 'Ya-Sin', 83, 'Makki', 22),
    SurahInfo(37, 'As-Saffat', 'Those Who Set The Ranks', 182, 'Makki', 23),
    SurahInfo(38, 'Sad', 'Sad', 88, 'Makki', 23),
    SurahInfo(39, 'Az-Zumar', 'The Troops', 75, 'Makki', 23),
    SurahInfo(40, 'Ghafir', 'The Forgiver', 85, 'Makki', 24),
    SurahInfo(41, 'Fussilat', 'Explained In Detail', 54, 'Makki', 24),
    SurahInfo(42, 'Ash-Shura', 'The Consultation', 53, 'Makki', 25),
    SurahInfo(43, 'Az-Zukhruf', 'The Ornaments of Gold', 89, 'Makki', 25),
    SurahInfo(44, 'Ad-Dukhan', 'The Smoke', 59, 'Makki', 25),
    SurahInfo(45, 'Al-Jathiyah', 'The Crouching', 37, 'Makki', 25),
    SurahInfo(46, 'Al-Ahqaf', 'The Wind-Curved Sandhills', 35, 'Makki', 26),
    SurahInfo(47, 'Muhammad', 'Muhammad', 38, 'Madani', 26),
    SurahInfo(48, 'Al-Fath', 'The Victory', 29, 'Madani', 26),
    SurahInfo(49, 'Al-Hujurat', 'The Dwellings', 18, 'Madani', 26),
    SurahInfo(50, 'Qaf', 'Qaf', 45, 'Makki', 26),
    SurahInfo(51, 'Adh-Dhariyat', 'The Winnowing Winds', 60, 'Makki', 26),
    SurahInfo(52, 'At-Tur', 'The Mount', 49, 'Makki', 27),
    SurahInfo(53, 'An-Najm', 'The Star', 62, 'Makki', 27),
    SurahInfo(54, 'Al-Qamar', 'The Moon', 55, 'Makki', 27),
    SurahInfo(55, 'Ar-Rahman', 'The Beneficent', 78, 'Madani', 27),
    SurahInfo(56, 'Al-Waqi\'ah', 'The Inevitable', 96, 'Makki', 27),
    SurahInfo(57, 'Al-Hadid', 'The Iron', 29, 'Madani', 27),
    SurahInfo(58, 'Al-Mujadilah', 'The Pleading Woman', 22, 'Madani', 28),
    SurahInfo(59, 'Al-Hashr', 'The Exile', 24, 'Madani', 28),
    SurahInfo(60, 'Al-Mumtahanah', 'The Examining Woman', 13, 'Madani', 28),
    SurahInfo(61, 'As-Saff', 'The Ranks', 14, 'Madani', 28),
    SurahInfo(62, 'Al-Jumu\'ah', 'The Congregation', 11, 'Madani', 28),
    SurahInfo(63, 'Al-Munafiqun', 'The Hypocrites', 11, 'Madani', 28),
    SurahInfo(64, 'At-Taghabun', 'The Mutual Disillusion', 18, 'Madani', 28),
    SurahInfo(65, 'At-Talaq', 'The Divorce', 12, 'Madani', 28),
    SurahInfo(66, 'At-Tahrim', 'The Prohibition', 12, 'Madani', 28),
    SurahInfo(67, 'Al-Mulk', 'The Sovereignty', 30, 'Makki', 29),
    SurahInfo(68, 'Al-Qalam', 'The Pen', 52, 'Makki', 29),
    SurahInfo(69, 'Al-Haqqah', 'The Indubitable', 52, 'Makki', 29),
    SurahInfo(70, 'Al-Ma\'arij', 'The Ascending Stairways', 44, 'Makki', 29),
    SurahInfo(71, 'Nuh', 'Noah', 28, 'Makki', 29),
    SurahInfo(72, 'Al-Jinn', 'The Jinn', 28, 'Makki', 29),
    SurahInfo(73, 'Al-Muzzammil', 'The Enshrouded One', 20, 'Makki', 29),
    SurahInfo(74, 'Al-Muddaththir', 'The Cloaked One', 56, 'Makki', 29),
    SurahInfo(75, 'Al-Qiyamah', 'The Resurrection', 40, 'Makki', 29),
    SurahInfo(76, 'Al-Insan', 'Man', 31, 'Madani', 29),
    SurahInfo(77, 'Al-Mursalat', 'Those Sent Forth', 50, 'Makki', 29),
    SurahInfo(78, 'An-Naba\'', 'The Great News', 40, 'Makki', 30),
    SurahInfo(79, 'An-Nazi\'at', 'Those Who Pull Out', 46, 'Makki', 30),
    SurahInfo(80, '‘Abasa', 'He Frowned', 42, 'Makki', 30),
    SurahInfo(81, 'At-Takwir', 'The Overthrowing', 29, 'Makki', 30),
    SurahInfo(82, 'Al-Infitar', 'The Cleaving', 19, 'Makki', 30),
    SurahInfo(83, 'Al-Mutaffifin', 'The Defrauders', 36, 'Makki', 30),
    SurahInfo(84, 'Al-Inshiqaq', 'The Splitting Open', 25, 'Makki', 30),
    SurahInfo(85, 'Al-Buruj', 'The Mansions of the Stars', 22, 'Makki', 30),
    SurahInfo(86, 'At-Tariq', 'The Night-Comer', 17, 'Makki', 30),
    SurahInfo(87, 'Al-A\'la', 'The Most High', 19, 'Makki', 30),
    SurahInfo(88, 'Al-Ghashiyah', 'The Overwhelming', 26, 'Makki', 30),
    SurahInfo(89, 'Al-Fajr', 'The Dawn', 30, 'Makki', 30),
    SurahInfo(90, 'Al-Balad', 'The City', 20, 'Makki', 30),
    SurahInfo(91, 'Ash-Shams', 'The Sun', 15, 'Makki', 30),
    SurahInfo(92, 'Al-Lail', 'The Night', 21, 'Makki', 30),
    SurahInfo(93, 'Ad-Duha', 'The Morning Hours', 11, 'Makki', 30),
    SurahInfo(94, 'Ash-Sharh', 'The Consolation', 8, 'Makki', 30),
    SurahInfo(95, 'At-Tin', 'The Fig', 8, 'Makki', 30),
    SurahInfo(96, 'Al-\'Alaq', 'The Cling', 19, 'Makki', 30),
    SurahInfo(97, 'Al-Qadr', 'The Power', 5, 'Makki', 30),
    SurahInfo(98, 'Al-Bayyinah', 'The Clear Evidence', 8, 'Madani', 30),
    SurahInfo(99, 'Az-Zalzalah', 'The Earthquake', 8, 'Madani', 30),
    SurahInfo(100, 'Al-\'Adiyat', 'The Courser', 11, 'Makki', 30),
    SurahInfo(101, 'Al-Qari\'ah', 'The Calamity', 11, 'Makki', 30),
    SurahInfo(102, 'At-Takathur', 'The Rivalry in World Increase', 8, 'Makki', 30),
    SurahInfo(103, 'Al-\'Asr', 'The Declining Day', 3, 'Makki', 30),
    SurahInfo(104, 'Al-Humazah', 'The Traducer', 9, 'Makki', 30),
    SurahInfo(105, 'Al-Fil', 'The Elephant', 5, 'Makki', 30),
    SurahInfo(106, 'Quraish', 'Quraish', 4, 'Makki', 30),
    SurahInfo(107, 'Al-Ma\'un', 'The Small Kindnesses', 7, 'Makki', 30),
    SurahInfo(108, 'Al-Kauthar', 'The Abundance', 3, 'Makki', 30),
    SurahInfo(109, 'Al-Kafirun', 'The Disbelievers', 6, 'Makki', 30),
    SurahInfo(110, 'An-Nasr', 'The Divine Support', 3, 'Madani', 30),
    SurahInfo(111, 'Al-Masad', 'The Palm Fiber', 5, 'Makki', 30),
    SurahInfo(112, 'Al-Ikhlas', 'The Sincerity', 4, 'Makki', 30),
    SurahInfo(113, 'Al-Falaq', 'The Daybreak', 5, 'Makki', 30),
    SurahInfo(114, 'An-Nas', 'Mankind', 6, 'Makki', 30),
  ];

  // Dynamic Daily Spiritual Verses Database (Focus: Akhirah, Salah, Quran benefits)
  static const List<DailyVerse> _dailyVersesDb = [
    DailyVerse(
      arabic: 'قَدْ أَفْلَحَ الْمُؤْمِنُونَ * الَّذِينَ هُمْ فِي صَلَاتِهِمْ خَاشِعُونَ',
      bangla: '“নিশ্চয় মুমিনগণ সফলকাম হয়ে গেছে, যারা নিজেদের নামাজে বিনয়ী ও নম্র।”',
      english: '“Successful indeed are the believers: those who are humble in their prayers.”',
      reference: 'Surah Al-Mu\'minun (23:1-2)',
      explanation: 'নামাজে খুশু-খুযু বা বিনয় বজায় রাখা আখিরাতে মহাসাফল্য লাভের অন্যতম চাবিকাঠি। নামাজের প্রতিটি রুকু-সেজদায় আল্লাহর প্রতি পূর্ণ একাগ্রতা প্রকাশ করতে হবে।',
    ),
    DailyVerse(
      arabic: 'وَأَقِيمُوا الصَّلَاةَ وَآتُوا الزَّكَاةَ وَارْكَعُوا مَعَ الرَّاكِعِينَ',
      bangla: '“আর সালাত কায়েম কর, যাকাত দাও এবং রুকুকারীদের সাথে রুকু কর।”',
      english: '“And establish prayer and give zakah and bow with those who bow in worship.”',
      reference: 'Surah Al-Baqarah (2:43)',
      explanation: 'নামাজ জামায়াতে আদায়ের জন্য আল্লাহ আদেশ দিচ্ছেন। এটি মুসলিম সমাজে ঐক্য ও আধ্যাত্মিক সংযোগ বৃদ্ধি করে।',
    ),
    DailyVerse(
      arabic: 'لَقَدْ كُنْتَ فِي غَفْلَةٍ مِنْ هَٰذَا فَكَشَفْنَا عَنْكَ غِطَاءَكَ فَبَصَرُكَ الْيَوْمَ حَدِيدٌ',
      bangla: '“তুমি তো এই দিনটি সম্পর্কে উদাসীন ছিলে, এখন তোমার সামনে থেকে পর্দা সরিয়ে দিয়েছি, ফলে আজ তোমার দৃষ্টি অত্যন্ত তীক্ষ্ণ।”',
      english: '“You were heedless of this; now we have removed your veil, and your sight today is sharp.”',
      reference: 'Surah Qaf (50:22)',
      explanation: 'মানুষ দুনিয়ার মোহে পড়ে আখিরাতকে ভুলে থাকে। কিন্তু মৃত্যুর সাথে সাথেই চোখের পর্দা খুলে যাবে এবং আখিরাতের মহাসত্য সামনে উপস্থিত হবে।',
    ),
    DailyVerse(
      arabic: 'فَخَلَفَ مِنْ بَعْدِهِمْ خَلْفٌ أَضَاعُوا الصَّلَاةَ وَاتَّبَعُوا الشَّهَوَاتِ ۖ فَسَوْفَ يَلْقَوْنَ غَيًّا',
      bangla: '“অতঃপর তাদের পরে আসলো এমন এক অপদার্থ স্থলাভিষিক্ত দল যারা সালাত নষ্ট করল এবং কুপ্রবৃত্তির অনুসরণ করল; সুতরাং তারা শীঘ্রই ধ্বংসের সম্মুখীন হবে।”',
      english: '“But there came after them successors who neglected prayer and pursued desires; so they are going to meet evil.”',
      reference: 'Surah Maryam (19:59)',
      explanation: 'সালাত বা নামাজ বর্জন করা এবং প্রবৃত্তির দাসত্ব করার শাস্তি হিসেবে জাহান্নামের ধ্বংস অবধারিত। তাই নামাজ সময়মত আদায়ে যত্নবান হোন।',
    ),
    DailyVerse(
      arabic: 'اتْلُ مَا أُوحِيَ إِلَيْكَ مِنَ الْكِتَابِ وَأَقِيمُوا الصَّلَاةَ ۖ إِنَّ الصَّلَاةَ تَنْهَىٰ عَنِ الْفَحْشَاءِ وَالْمُنْكَرِ',
      bangla: '“আপনার প্রতি যে কিতাব প্রত্যাদেশ করা হয়েছে তা পাঠ করুন এবং সালাত কায়েম করুন। নিশ্চয়ই সালাত অশ্লীল ও মন্দ কাজ থেকে বিরত রাখে।”',
      english: '“Recite what has been revealed to you of the Book and establish prayer. Indeed, prayer prohibits immorality and wrongdoing.”',
      reference: 'Surah Al-Ankabut (29:45)',
      explanation: 'কুরআন তিলাওয়াত ও নামাজ আদায়ের মাধ্যমে মানুষের হৃদয় পবিত্র হয়, যা তাকে সমস্ত অনৈতিক ও খারাপ কাজ থেকে দূরে সরিয়ে রাখে।',
    ),
    DailyVerse(
      arabic: 'مَنْ عَمِلَ صَالِحًا فَلِنَفْسِهِ ۖ وَمَنْ أَسَاءَ فَعَلَيْهَا ۖ ثُمَّ إِلَىٰ رَبِّكُمْ تُرْجَعُونَ',
      bangla: '“যে সৎকর্ম করবে সে নিজের উপকারের জন্যই তা করবে, আর যে মন্দ কাজ করবে তা তার উপরই বর্তাবে। অতঃপর তোমরা তোমাদের প্রতিপালকের কাছে প্রত্যাবর্তিত হবে।”',
      english: '“Whoever does a good deed - it is for himself; and whoever does evil - it is against the same. Then to your Lord you will be returned.”',
      reference: 'Surah Al-Jathiyah (45:15)',
      explanation: 'দুনিয়ার প্রতিটি কাজের হিসাব দিতে হবে আল্লাহর দরবারে। সৎ কাজ মুমিনের পরকালের পুঁজি।',
    ),
    DailyVerse(
      arabic: 'فَاقْرَأُوا مَا تَيَسَّرَ مِنَ الْقُرْآنِ ۚ أَقِيمُوا الصَّلَاةَ وَآتُوا الزَّكَاةَ',
      bangla: '“অতএব তোমরা কুরআন থেকে যতটুকু সহজ ততটুকু পাঠ কর, সালাত কায়েম কর এবং যাকাত দাও।”',
      english: '“So recite what is easy from the Quran and establish prayer and give zakah.”',
      reference: 'Surah Al-Muzzammil (73:20)',
      explanation: 'প্রতিদিন কুরআন তিলাওয়াতের প্রতি তাগিদ দেওয়া হয়েছে। এটি আল্লাহর সাথে মুমিনের সরাসরি কথোপকথন ও হৃদয়কে সতেজ করার মাধ্যম।',
    ),
  ];

  // HADITH VIRTUES SYSTEM DATA
  static const List<HadithWazifa> _hadithWazifaList = [
    // 7 Days Weekly Surahs
    HadithWazifa(
      title: 'শনিবার: সূরা ফাতাহ (Surah Al-Fath)',
      recitationCount: '১ বার (1 Time)',
      benefitBangla: 'মক্কা বিজয়ের সমপরিমাণ সওয়াব লাভ হয় এবং সকল কাজে ও রিজিক অর্জনে আল্লাহর তরফ থেকে বিজয় আসে।',
      benefitEnglish: 'Secures success, victory in challenges, and expansion of sustenance.',
      hadithReference: 'সহীহ বুখারী ও সুনানে তিরমিযী',
      targetDay: 'শনিবার (Saturday)',
      surahId: 48,
    ),
    HadithWazifa(
      title: 'রবিবার: সূরা লোকমান (Surah Luqman)',
      recitationCount: '১ বার (1 Time)',
      benefitBangla: 'তিলাওয়াতকারীর অন্তরে প্রজ্ঞা (হিকমত), তাকওয়া ও আল্লাহর প্রতি অবিচল ঈমান জাগ্রত হয়।',
      benefitEnglish: 'Instills wisdom, devotion, and firm belief in the heart of the reciter.',
      hadithReference: 'তাফসীরে ইবনে কাসীর',
      targetDay: 'রবিবার (Sunday)',
      surahId: 31,
    ),
    HadithWazifa(
      title: 'সোমবার: সূরা ওয়াক্বিয়াহ (Surah Al-Waqi\'ah)',
      recitationCount: '১ বার (1 Time)',
      benefitBangla: 'সোমবার বা প্রতি রাতে সূরা ওয়াক্বিয়াহ তিলাওয়াত করলে কখনো অভাব-অনটন বা দারিদ্র্য স্পর্শ করবে না।',
      benefitEnglish: 'Protects the household from poverty and ensures abundance of sustenance.',
      hadithReference: 'বায়হাকী (শুআবুল ঈমান)',
      targetDay: 'সোমবার (Monday)',
      surahId: 56,
    ),
    HadithWazifa(
      title: 'মঙ্গলবার: সূরা আর-রহমান (Surah Ar-Rahman)',
      recitationCount: '১ বার (1 Time)',
      benefitBangla: 'কিয়ামতের দিন সূরাটি তিলাওয়াতকারীর জন্য সুপারিশকারী হিসেবে দাঁড়াবে এবং আল্লাহর রহমত লাভ হবে।',
      benefitEnglish: 'Attracts Divine mercy and will intercede for its reciter on the Day of Judgment.',
      hadithReference: 'সুনানে তিরমিযী',
      targetDay: 'মঙ্গলবার (Tuesday)',
      surahId: 55,
    ),
    HadithWazifa(
      title: 'বুধবার: সূরা ইয়াসীন (Surah Ya-Sin)',
      recitationCount: '১ বার (1 Time)',
      benefitBangla: 'সূরা ইয়াসীন কুরআনের হৃদয়। সকালে বা বুধবারে পাঠ করলে সারাদিনের সমস্ত জাগতিক প্রয়োজন পূরণ হয় ও গুনাহ মাফ হয়।',
      benefitEnglish: 'The heart of the Quran. Recitation fulfills needs and expiates sins.',
      hadithReference: 'তিরমিযী (২৮৮৭), দারেমী',
      targetDay: 'বুধবার (Wednesday)',
      surahId: 36,
    ),
    HadithWazifa(
      title: 'বৃহস্পতিবার: সূরা আদ-দুখান (Surah Ad-Dukhan)',
      recitationCount: '১ বার (1 Time)',
      benefitBangla: 'জুমার রাতে (বৃহস্পতিবার রাতে) এই সূরা তিলাওয়াতকারীর জন্য ৭০ হাজার ফেরেশতা সকাল পর্যন্ত ক্ষমা প্রার্থনা করে।',
      benefitEnglish: 'Recited on Thursday night/Friday eve, 70,000 angels pray for the reciter\'s forgiveness till morning.',
      hadithReference: 'সুনানে তিরমিযী (২৮৮৯)',
      targetDay: 'বৃহস্পতিবার (Thursday)',
      surahId: 44,
    ),
    HadithWazifa(
      title: 'শুক্রবার: সূরা কাহাফ (Surah Al-Kahf)',
      recitationCount: '১ বার (1 Time)',
      benefitBangla: 'জুমার দিন সূরা কাহাফ তিলাওয়াত করলে এক জুমা থেকে অপর জুমা পর্যন্ত তার জন্য নূর প্রজ্বলিত থাকে ও দাজ্জালের ফেতনা থেকে রক্ষা পায়।',
      benefitEnglish: 'Provides a light of guidance from one Friday to the next and protects from Dajjal\'s trial.',
      hadithReference: 'নাসায়ী ও আল-হাকেম',
      targetDay: 'শুক্রবার (Friday)',
      surahId: 18,
    ),
    // Daily Surahs
    HadithWazifa(
      title: 'সূরা মূলক (Surah Al-Mulk)',
      recitationCount: '১ বার (1 Time)',
      benefitBangla: 'প্রতি রাতে ঘুমানোর আগে তিলাওয়াত করলে কবরের আযাব থেকে মুক্তি লাভ হয় এবং আল্লাহর ক্ষমা না পাওয়া পর্যন্ত সুপারিশ করতে থাকে।',
      benefitEnglish: 'Recited before sleeping, it protects from the punishment of the grave and intercedes for forgiveness.',
      hadithReference: 'তিরমিযী (২৮৯১), আবু দাউদ (১৪০০)',
      targetDay: 'প্রতি রাতে (Every Night)',
      surahId: 67,
    ),
    HadithWazifa(
      title: 'সূরা সাজদাহ (Surah As-Sajdah)',
      recitationCount: '১ বার (1 Time)',
      benefitBangla: 'প্রতি রাতে ঘুমানোর আগে পড়া সুন্নাহ। রাসূলুল্লাহ (সা.) এ সূরা না পড়ে ঘুমাতেন না।',
      benefitEnglish: 'A sunnah to recite before sleeping. The Prophet (PBUH) would not sleep without reciting it.',
      hadithReference: 'তিরমিযী (২৯০১), মুসনাদে আহমাদ',
      targetDay: 'প্রতি রাতে (Every Night)',
      surahId: 32,
    ),
    // Core Prayers & Duas
    HadithWazifa(
      title: 'আয়াতুল কুরসী (Ayatul Kursi)',
      recitationCount: '১ বার (1 Time)',
      benefitBangla: 'প্রতি ফরজ সালাতের পর পাঠ করলে জান্নাতে প্রবেশের পথে মৃত্যু ছাড়া আর কোনো বাধা থাকে না।',
      benefitEnglish: 'Recited after every obligatory prayer, nothing stands between the servant and Paradise except death.',
      hadithReference: 'সুনানে নাসায়ী (৯৯২৮)',
      targetDay: 'প্রতি সালাত শেষে (After Obligatory Salah)',
      arabicText: 'اللَّهُ لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ مَنْ ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلَّا بِإِذْنِهِ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ وَلَا يُحِيطُونَ بِشَيْءٍ مِنْ عِلْمِهِ إِلَّا بِمَا شَاءَ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ وَلَا يَئُودُهُ حِفْظُهُمَا وَهُوَ الْعَلِيُّ الْعَظِيمُ',
      banglaPronunciation: 'আল্লাহু লা ইলাহা ইল্লা হুয়াল হাইয়্যুল কাইয়্যুম। লা তা\'খুযুহু সিনাতুন ওয়ালা নাউম। লাহু মা ফিস সামাওয়াতি ওয়ামা ফিল আরদ। মান যাল্লাযী ইয়াশফাউ ইনদাহু ইল্লা বিইযনিহ। ইয়া\'লামু মা বাইনা আইদীহিম ওয়ামা খালফাহুম। ওয়ালা ইউহীতূনা বিশাইয়্যিম মিন ইলমিহী ইল্লা বিমা শা-আ। ওয়াসিআ কুরসিইয়্যুহুস সামাওয়াতি ওয়াল আরদ, ওয়ালা ইয়াউদুহু হিফযুহুমা ওয়া হুয়াল আলীইয়্যুল আযীম।',
      banglaTranslation: 'আল্লাহ, তিনি ছাড়া কোনো সত্য উপাস্য নেই, তিনি চিরঞ্জীব, সর্বসত্তার ধারক। তাঁকে তন্দ্রা ও নিদ্রা স্পর্শ করে না। আসমান ও যমীনে যা কিছু আছে সবকিছু তাঁরই। কে সে, যে তাঁর অনুমতি ছাড়া তাঁর নিকট সুপারিশ করবে? তাদের সামনে ও পিছনে যা কিছু আছে তা তিনি জানেন। আর তাঁর ইচ্ছাধীন জ্ঞান ছাড়া অন্য কোনো কিছুর ওপর তারা কর্তৃত্ব করতে পারে না। তাঁর রাজত্ব আসমান ও যমীনব্যাপী পরিব্যাপ্ত। আর এ দুটির রক্ষণাবেক্ষণ তাঁকে ক্লান্ত করে না। তিনি পরম উচ্চ, মহীয়ান।',
      readingRules: 'প্রতি ফরজ সালাত শেষে এবং সকালে ও সন্ধ্যায় ঘুম থেকে উঠে ও ঘুমানোর আগে ১ বার করে পড়বেন।',
    ),
    HadithWazifa(
      title: 'সূরা হাশরের শেষ ৩ আয়াত (Al-Hashr Last 3 Ayahs)',
      recitationCount: '১ বার (1 Time)',
      benefitBangla: 'সকালে ও সন্ধ্যায় পাঠ করলে ৭০ হাজার ফেরেশতা দিন বা রাত শেষ হওয়া পর্যন্ত তার জন্য রহমত ও মাগফিরাতের দোয়া করে।',
      benefitEnglish: 'Reciting in the morning or evening prompts 70,000 angels to pray for your mercy until night/day breaks.',
      hadithReference: 'সুনানে তিরমিযী (২৯২২)',
      targetDay: 'সকাল ও সন্ধ্যা (Morning & Evening)',
      arabicText: 'هُوَ اللَّهُ الَّذِي لَا إِلَهَ إِلَّا هُوَ عَالِمُ الْغَيْبِ وَالشَّهَادَةِ هُوَ الرَّحْمَنُ الرَّحِيمُ ۝ هُوَ اللَّهُ الَّذِي لَا إِلَهَ إِلَّا هُوَ الْمَلِكُ الْقُدُّوسُ السَّلَامُ الْمُؤْمِنُ الْمُهَيْمِنُ الْعَزِيزُ الْجَبَّارُ الْمُتَكَبِّরُ سُبْحَانَ اللَّهِ عَمَّا يُشْرِكُونَ ۝ هُوَ اللَّهُ الْخَالِقُ الْبَارِئُ الْمُصَوِّرُ لَهُ الْأَسْمَاءُ الْحُسْنَى يُسَبِّحُ لَهُ مَا فِي السَّمَاوَاتِ وَالْأَرْضِ وَهُوَ الْعَزِيزُ الْحَكِيمُ ۝',
      banglaPronunciation: 'হুওয়াল্লাহুল্লাযী লা ইলাহা ইল্লা হুওয়া, আলিমুল গাইবি ওয়াশ শাহাদাহ, হুওয়ার রাহমানুর রাহীম। হুওয়াল্লাহুল্লাযী লা ইলাহা ইল্লা হুওয়া, আল-মালিকুল কুদ্দূসুস সালামুল মু\'মিনুল মুহাইমিনুল আযীযুল জাব্বারুল মুতাকাব্বির, সুবহানাল্লাহি আম্মা ইউশরিকূন। হুওয়াল্লাহুল খালিকুল বারীউল মুসাওয়িরু লাহুল আসমাউল হুসনা, ইউসাব্বিহু লাহু মা ফিস সামাওয়াতি ওয়াল আরদ্ব, ওয়া হুওয়াল আযীযুল হাকীম।',
      banglaTranslation: 'তিনিই আল্লাহ, যিনি ছাড়া কোনো ইলাহ নেই; তিনি দৃশ্য ও অদৃশ্যের পরিজ্ঞাত, তিনি পরম দয়াময়, পরম দয়ালু। তিনিই আল্লাহ, যিনি ছাড়া কোনো ইলাহ নেই; তিনিই একমাত্র মালিক, অতি পবিত্র, পরম শান্তিদানকারী, নিরাপত্তা বিধানকারী, রক্ষক, পরাক্রমশালী, মহিমান্বিত, সর্বশ্রেষ্ঠ। তারা যে শরীক করে আল্লাহ তা থেকে পবিত্র। তিনিই আল্লাহ, সৃষ্টিকর্তা, উদ্ভাবক, রূপদানকারী, উত্তম নামসমূহ তাঁরই। আসমান ও যমীনে যা কিছু আছে সবই তাঁর পবিত্রতা ঘোষণা করে। তিনি পরাক্রমশালী, প্রজ্ঞাময়।',
      readingRules: 'সকালে ফজরের পর এবং সন্ধ্যায় মাগরিবের পর শুরু করার আগে "আউযুবিল্লাহিস সামীইল আলীমি মিনাশ শায়তানির রাজীম" ৩ বার পাঠ করে এই ৩টি আয়াত ১ বার তিলাওয়াত করবেন।',
    ),
    HadithWazifa(
      title: 'আহাদনামা (Ahad Nama)',
      recitationCount: '১ বার (1 Time)',
      benefitBangla: 'আল্লাহর তাওহীদের বিশেষ অঙ্গীকারনামা। নিয়মিত পাঠে ঈমানী দৃঢ়তা অর্জিত হয় এবং শেষ নিঃশ্বাস ঈমানের সাথে হওয়ার আশা থাকে।',
      benefitEnglish: 'A powerful testament of faith. Reading it regularly helps secure true belief at the time of death.',
      hadithReference: 'ওযীফা ও দোয়া গ্রন্থ',
      targetDay: 'দৈনন্দিন (Daily)',
      arabicText: 'اللَّهُمَّ فَاطِرَ السَّمَاوَاتِ وَالْأَرْضِ عَالِمَ الْغَيْبِ وَالشَّهَادَةِ أَنْتَ الرَّحْمَنُ الرَّحِيمُ أَعْهَدُ إِلَيْكَ فِي هَذِهِ الْحَيَاةِ الدُّنْيَا أَنِّي أَشْهَدُ أَنْ لَا إِلَهَ إِلَّا أَنْتَ وَحْدَكَ لَا شَرِيكَ لَكَ وَأَنَّ مُحَمَّدًا عَبْدُكَ وَرَسُولُكَ فَلَا تَكِلْنِي إِلَى نَفْسِي فَإِنَّكَ إِنْ تَكِلْنِي إِلَى نَفْسِي تُقَرِّبْنِي مِنَ الشَّرِّ وَتُبَاعِدْنِي مِنَ الْخَيْرِ وَإِنِّي لَا أَثِقُ إِلَّا بِرَحْمَتِكَ فَاجْعَلْ لِي عِنْدَكَ عَهْدًا تُؤَدِّيهِ إِلَيَّ يَوْمَ الْقِيَامَةِ إِنَّكَ لَا تُخْلِفُ الْمِيعَادَ',
      banglaPronunciation: 'আল্লাহুম্মা ফাতিরাস সামাওয়াতি ওয়াল আরদ্বি আলিমাল গাইবি ওয়াশ শাহাদাতিল আনতার রহমানুর রাহীমু আ’হাদু ইলাইকা ফী হাযিহিল হায়াতিদ দুনইয়া আন্নী আশহাদু আল লা ইলাহা ইল্লা আনতা ওয়াহদাকা লা শারীকা লাকা ওয়া আন্না মুহাম্মাদান আবদুকা ওয়া রাসূলুকা ফালা তাকিলনী ইলা নাফসী ফাইন্নাকা ইন তাকিলনী ইলা নাফসী তুর্ক্বারিবনী মিনাশ শাররি ওয়াতুবা’ইদনী মিনাল খাইরি ওয়া ইন্নী লা আছিকু ইল্লা বিরাহমাতিকা ফাজ’আল লী ইনদাকা আহদান তুয়াদ্দীহি ইলাইয়া ইয়াওমাল ক্বিয়ামাতিন ইন্নাকা লা তুখলিফুল মী’আদ।',
      banglaTranslation: 'হে আল্লাহ! আসমান ও যমীনের সৃষ্টিকর্তা, দৃশ্য ও অদৃশ্যের পরিজ্ঞাত, আপনি পরম দয়াময় ও দয়ালু। এই পার্থিব জীবনে আমি আপনার কাছে অঙ্গীকার করছি যে, আমি সাক্ষ্য দিচ্ছি আপনি ব্যতীত কোনো উপাস্য নেই, আপনি একক, আপনার কোনো শরীক নেই এবং মুহাম্মদ (সা.) আপনার বান্দা ও রাসূল। অতএব আপনি আমাকে আমার নিজের ওপর ছেড়ে দেবেন না। কেননা আপনি যদি আমাকে আমার নিজের ওপর ছেড়ে দেন, তবে তা আমাকে মন্দের নিকটবর্তী করবে এবং কল্যাণ থেকে দূরে সরিয়ে দেবে। নিশ্চয়ই আমি আপনার রহমত ছাড়া অন্য কিছুর ওপর ভরসা করি না। সুতরাং আমার জন্য আপনার নিকট এমন একটি অঙ্গীকারনামা রাখুন যা আপনি কিয়ামতের দিন আমাকে পূরণ করে দেবেন। নিশ্চয়ই আপনি ওয়াদা খেলাফ করেন না।',
      readingRules: 'প্রতিদিন সকাল অথবা সন্ধ্যায় ইবাদত শেষে ১ বার পরম ভক্তি সহকারে পাঠ করবেন।',
    ),
    HadithWazifa(
      title: 'সাইয়্যেদুল ইস্তেগফার (Sayyidul Istighfar)',
      recitationCount: '১ বার (1 Time)',
      benefitBangla: 'তওবা ও ইস্তেগফারের শ্রেষ্ঠ দোয়া। সকালে পাঠ করে সন্ধ্যায় মারা গেলে অথবা সন্ধ্যায় পাঠ করে সকালে মারা গেলে সে জান্নাতী হবে।',
      benefitEnglish: 'The master supplication for seeking forgiveness. Reading it guarantees Paradise if deceased that day/night.',
      hadithReference: 'সহীহ বুখারী (৬৩০৬)',
      targetDay: 'সকাল ও সন্ধ্যা (Morning & Evening)',
      arabicText: 'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ خَلَقْتَنِي وَأَنَا عَبْدُكَ وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ وَأَبُوءُ لَكِ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ',
      banglaPronunciation: 'আল্লাহুম্মা আনতা রাব্বী লা ইলাহা ইল্লা আনতা খালাকতানি ওয়া আনা আবদুকা ওয়া আনা আলা আহদিকা ওয়া ওয়াদিকা মাসতাতাতু আউযুবিকা মিন শাররি মা সানাতু আবূউ লাকা বিনিমাতিকা আলাইয়্যা ওয়া আবূউ লাকা বিযাম্বী ফাগফিরলী ফাইন্নাহু লা ইয়াগফিরুয যুনূবা ইল্লা আনতা।',
      banglaTranslation: 'হে আল্লাহ! আপনি আমার প্রতিপালক। আপনি ছাড়া কোনো ইলাহ নেই। আপনি আমাকে সৃষ্টি করেছেন এবং আমি আপনার বান্দা। আর আমি আমার সাধ্যমতো আপনার অঙ্গীকার ও প্রতিশ্রুতির ওপর কায়েম আছি। আমি আমার কৃতকর্মের অনিষ্ট থেকে আপনার আশ্রয় চাচ্ছি। আমার ওপর আপনার যে নেয়ামত রয়েছে তা আমি স্বীকার করছি এবং আমি আমার গুনাহসমূহ স্বীকার করছি। অতএব আপনি আমাকে ক্ষমা করে দিন। কারণ আপনি ছাড়া গুনাহসমূহ ক্ষমা করার আর কেউ নেই।',
      readingRules: 'প্রতিদিন সকালে ফজরের পর এবং সন্ধ্যায় মাগরিবের পর ১ বার করে পাঠ করবেন।',
    ),
    HadithWazifa(
      title: 'দরুদে তাজ (Darood-e-Taj)',
      recitationCount: '১ বার (1 Time)',
      benefitBangla: 'রাসূলুল্লাহ (সা.)-এর প্রতি পরম ভালোবাসার প্রকাশ ও স্বপ্নযোগে তাঁর জিয়ারত নসিব হওয়া এবং বালা-মুসিবত দূর হওয়ার চমৎকার দরুদ।',
      benefitEnglish: 'Expresses deep love for the Prophet (PBUH) and is highly valued for peace of mind.',
      hadithReference: 'বুজুর্গদের পরীক্ষিত আমল',
      targetDay: 'দৈনন্দিন (Daily / Friday)',
      arabicText: 'اللَّهُمَّ صَلِّ عَلَى سَيِّدِنَا وَمَوْلَانَا مُحَمَّدٍ صَاحِبِ التَّاجِ وَالْمِعْرَاجِ وَالْبُرَاقِ وَالْعَلَمِ ۝ دَافِعِ الْبَلَاءِ وَالْوَبَاءِ وَالْقَحْطِ وَالْمَرَضِ وَالْأَلَمِ ۝ اِسْمُهُ مَكْتُوبٌ مَّرْفُوعٌ مَّشْفُوعٌ مَّنْقُوشٌ فِي اللَّوْحِ وَالْقَلَمِ ۝ شَمْسِ الضُّحَى بَدْرِ الدُّجَى صَدْرِ الْعُلَى نُورِ الْهُدَى كَهْفِ الْوَرَى مِصْبَاحِ الظُّلَمِ ۝ جَمِيلِ الشِّيَمِ شَفِيعِ الْأُمَمِ صَاحِبِ الْجُودِ وَالْكَرَمِ ۝ وَعَلَى آلِهِ وَصَحْبِهِ وَسَلِّمْ',
      banglaPronunciation: 'আল্লাহুম্মা সাল্লি আলা সাইয়্যিদিনা ওয়া মাওলানা মুহাম্মাদিন সাহেবিত তাজি ওয়াল মি\'রাজি ওয়াল বুরাক্বি ওয়াল আলাম। দাফি\'ইল বালাই ওয়াল ওয়াবাই ওয়াল ক্বাহত্বি ওয়াল মারাদ্ধি ওয়াল আলাম। ইসমুহু মাকতুবুম মারফুউম মাশফুউম মানকুশুন ফিল লাওহি ওয়াল ক্বালাম। শামসিদ দুহা বাদ্রিদ দুজা সাদরিল উলা নূরিল হুদা কাহফিল ওয়ারা মিসবাহিজ জুলাম। জামিলিশ শিয়ামি শাফিইইল উমামি সাহেবিল জুদি ওয়াল কারাম। ওয়া আলা আলিহি ওয়া সাহবিহি ওয়া সাল্লিম।',
      banglaTranslation: 'হে আল্লাহ! আপনি দরুদ বর্ষণ করুন আমাদের সর্দার ও আমাদের অভিভাবক হযরত মুহাম্মদ (সা.)-এর ওপর, যিনি মুকুট, মিরাজ, বোরাক ও পতাকার অধিকারী। যিনি বিপদ-আপদ, মহামারী, দুর্ভিক্ষ, রোগ এবং বেদনা দূরকারী। যাঁর নাম সমাদৃত, সম্মানিত, আল্লাহর দরবারে সুপারিশকৃত এবং লাওহে মাহফুজে লিপিবদ্ধ। যিনি উজ্জ্বল সূর্য, অন্ধকার রাতের পূর্ণিমার চাঁদ, উচ্চাসনের অধিকারী, হিদায়াতের আলো, সৃষ্টির আশ্রয়স্থল এবং অন্ধকারের প্রদীপ। যিনি অতি সুন্দর চরিত্রের অধিকারী, উম্মতের সুপারিশকারী এবং দান ও দয়ার আধার। এবং তাঁর পরিবার ও সাহাবীগণের ওপর সালাম বর্ষণ করুন।',
      readingRules: 'প্রতিদিন সকাল অথবা সন্ধ্যায় ও জুমার দিনে বিশেষভাবে ১ বার পাঠ করবেন।',
    ),
    HadithWazifa(
      title: 'দরuদে তুনাজ্জিনা (Darood-e-Tunjina)',
      recitationCount: '৩ বার (3 Times)',
      benefitBangla: 'যেকোনো কঠিন বিপদ-আপদ, মহামারী ও মারাত্মক রোগ থেকে মুক্তি লাভ করার জন্য অত্যন্ত প্রভাবশালী ও পরীক্ষিত দরুদ শরীফ।',
      benefitEnglish: 'Known as the prayer of salvation from all types of worries, diseases, and calamities.',
      hadithReference: 'বিপদ ও মুসিবত মুক্তির দরুদ',
      targetDay: 'দৈনন্দিন (Daily / In Hardship)',
      arabicText: 'اللَّهُمَّ صَلِّ عَلَى سَيِّدِنَا مُحَمَّدٍ صَلَاةً تُنْجِينَا بِهَا مِنْ جَمِيعِ الْأَهْوَالِ وَالْآفَاتِ وَتَقْضِي لَنَا بِهَا جَمِيعَ الْحَاجَاتِ وَتُطَهِّرُنَا بِهَا مِنْ جَمِيعِ السَّيِّئَاتِ وَتَرْفَعُنَا بِهَا عِنْدَكَ أَعْلَى الدَّرَجَاتِ وَتُبَلِّغُنَا بِهَا أَقْصَى الْغَايَاتِ مِنْ جَمِيعِ الْخَيْرَاتِ فِي الْحَيَاةِ وَبَعْدَ الْمَمَاتِ',
      banglaPronunciation: 'আল্লাহুম্মা সাল্লি আলা সাইয়্যিদিনা মুহাম্মাদিন সালাতান তুনজিনা বিহা মিন জামি\'ইল আহওয়ালি ওয়াল আফাত। ওয়া তাক্বদ্বি লনা বিহা জামি\'আল হাজাত। ওয়া তুত্বাহহিরুনা বিহা মিন জামি\'ইস সায়্যিআত। ওয়া তারফাউনা বিহা ইনদাকা আ\'লাদ দারাজাত। ওয়া তুবাল্লিগুনা বিহা আক্বসাল গায়াত। মিন জামি\'ইল খাইরাতি ফিল হায়াতি ওয়া বা\'দাল মামাত।',
      banglaTranslation: 'হে আল্লাহ! আমাদের সর্দার হযরত মুহাম্মদ (সা.)-এর ওপর এমন রহমত নাযিল করুন, যার বরকতে আপনি আমাদের সকল ভয়ভীতি ও বিপদ-আপদ থেকে মুক্তি দেবেন, আমাদের সকল প্রয়োজন পূরণ করবেন, আমাদের সকল পাপ থেকে পবিত্র করবেন, আপনার নিকট আমাদেরকে উচ্চ মর্যাদায় উন্নীত করবেন এবং ইহকাল ও পরকালে আমাদের সকল প্রকার কল্যাণের শেষ সীমানায় পৌঁছে দেবেন।',
      readingRules: 'যেকোনো বিপদে অথবা দৈনন্দিন ইবাদত শেষে ৩ বার পাঠ করবেন।',
    ),
    HadithWazifa(
      title: 'সাত মঞ্জিল (Manzil / 33 Ayats)',
      recitationCount: '১ বার (1 Time)',
      benefitBangla: 'জিন-শয়তানের আছর, জাদুটোনা, শত্রুর কুদৃষ্টি এবং শারীরিক-মানসিক রোগ থেকে মহান আল্লাহ নিরাপদে রাখেন।',
      benefitEnglish: 'Protects against black magic, jinns, evil eyes, and psychological harms.',
      hadithReference: 'মুসনাদে আহমাদ ও সুনানে ইবনে মাজাহ',
      targetDay: 'দৈনন্দিন (Daily)',
      readingRules: 'কুরআন মজীদের ৩৩টি বিশেষ আয়াতের সমষ্টিকে "মঞ্জিল" বলা হয়। ঘরের সকলের সুরক্ষায় প্রতিদিন সকালে অন্তত ১ বার বাড়ির কেউ তিলাওয়াত করা বা বাজানো উত্তম।',
    ),
    HadithWazifa(
      title: 'হিজবুল বাহার (Hizbul Bahr)',
      recitationCount: '১ বার (1 Time)',
      benefitBangla: 'ইমাম আবুল হাসান আশ-শাযিলী (রহ.) কর্তৃক সংকলিত। কঠিন বিপদ ও শত্রুর হাত থেকে বাঁচতে এবং নিরাপদ ভ্রমণের জন্য অত্যন্ত পরীক্ষিত।',
      benefitEnglish: 'Highly tested spiritual protective supplication for journeys and heavy distress.',
      hadithReference: 'বুজুর্গদের পরীক্ষিত আমল',
      targetDay: 'দৈনন্দিন (Daily)',
      readingRules: 'যেকোনো কঠিন কাজ সহজ করতে অথবা নিরাপদ সফরের উদ্দেশ্যে এই দোয়াটি প্রতিদিন ১ বার ভক্তি সহকারে পাঠ করবেন।',
    ),
  ];

  // RESET Default Starting States (0 Completed metrics for a clean starting experience)
  int _currentStreak = 0;
  int _longestStreak = 0;
  int _targetDailyAyahs = 208;
  int _completedAyahsToday = 0;
  int _khatmTotalJuzCompleted = 0;
  String _khatmEstimatedCompletion = 'Not Configured';
  int _khatmTargetDays = 30; // Planner target
  Set<String> _readAyahsToday = {};
  Set<String> _readAyahsAllTime = {};

  // Continue Reading Reference
  int _continueSurahId = 1; // Al-Fatihah
  int _continuePage = 1;
  int _continueAyah = 1;

  int _getSurahTotalPages(int surahId, int totalAyahs) {
    if (surahId == 1) return 1;
    if (surahId == 2) return 48;
    if (surahId == 3) return 27;
    if (surahId == 4) return 30;
    if (surahId == 5) return 22;
    if (surahId == 6) return 23;
    if (surahId == 7) return 28;
    if (surahId == 8) return 10;
    if (surahId == 9) return 21;
    if (surahId == 10) return 11;
    if (surahId == 11) return 12;
    if (surahId == 12) return 12;
    if (surahId == 13) return 6;
    if (surahId == 14) return 7;
    if (surahId == 15) return 5;
    if (surahId == 16) return 15;
    if (surahId == 17) return 12;
    if (surahId == 18) return 12;
    if (surahId == 19) return 7;
    if (surahId == 20) return 10;
    if (surahId == 21) return 10;
    if (surahId == 22) return 10;
    if (surahId == 23) return 8;
    if (surahId == 24) return 10;
    if (surahId == 25) return 6;
    if (surahId == 26) return 11;
    if (surahId == 27) return 9;
    if (surahId == 28) return 11;
    if (surahId == 29) return 7;
    if (surahId == 30) return 6;
    if (surahId == 31) return 4;
    if (surahId == 32) return 3;
    if (surahId == 33) return 9;
    if (surahId == 34) return 6;
    if (surahId == 35) return 6;
    if (surahId == 36) return 6;
    if (surahId == 37) return 7;
    if (surahId == 38) return 5;
    if (surahId == 39) return 8;
    if (surahId == 40) return 9;
    if (surahId == 41) return 6;
    if (surahId == 42) return 6;
    if (surahId == 43) return 7;
    if (surahId == 44) return 3;
    if (surahId == 45) return 4;
    if (surahId == 46) return 5;
    if (surahId == 47) return 4;
    if (surahId == 48) return 4;
    if (surahId == 49) return 2;
    if (surahId == 50) return 3;
    if (surahId == 51) return 3;
    if (surahId == 52) return 2;
    if (surahId == 53) return 3;
    if (surahId == 54) return 3;
    if (surahId == 55) return 3;
    if (surahId == 56) return 3;
    if (surahId == 57) return 4;
    if (surahId == 58) return 3;
    if (surahId == 59) return 3;
    if (surahId == 60) return 2;
    if (surahId == 61) return 1;
    if (surahId == 62) return 1;
    if (surahId == 63) return 1;
    if (surahId == 64) return 2;
    if (surahId == 65) return 2;
    if (surahId == 66) return 2;
    if (surahId == 67) return 2;
    if (surahId == 68) return 2;
    if (surahId == 69) return 2;
    if (surahId == 70) return 2;
    if (surahId == 71) return 1;
    if (surahId == 72) return 2;
    if (surahId == 73) return 1;
    if (surahId == 74) return 2;
    if (surahId == 75) return 1;
    if (surahId == 76) return 2;
    if (surahId == 77) return 2;
    if (surahId >= 78 && surahId <= 80) return 2;
    return 1;
  }

  double _calculatePagesCompleted(int surahId, int currentAyahIndex) {
    final surah = _surahList.firstWhere((e) => e.id == surahId);
    final totalPages = _getSurahTotalPages(surahId, surah.totalAyahs);
    if (surah.totalAyahs <= 0) return 0.0;
    return (currentAyahIndex / surah.totalAyahs) * totalPages;
  }

  int _getSurahStartPage(int surahId) {
    if (surahId == 1) return 1;
    if (surahId == 2) return 2;
    if (surahId == 3) return 50;
    if (surahId == 4) return 77;
    if (surahId == 5) return 106;
    if (surahId == 6) return 128;
    if (surahId == 7) return 151;
    if (surahId == 8) return 177;
    if (surahId == 9) return 187;
    if (surahId == 10) return 208;
    if (surahId == 11) return 221;
    if (surahId == 12) return 235;
    if (surahId == 13) return 249;
    if (surahId == 14) return 255;
    if (surahId == 15) return 262;
    if (surahId == 16) return 267;
    if (surahId == 17) return 282;
    if (surahId == 18) return 293;
    if (surahId == 19) return 305;
    if (surahId == 20) return 312;
    if (surahId == 21) return 322;
    if (surahId == 22) return 332;
    if (surahId == 23) return 342;
    if (surahId == 24) return 350;
    if (surahId == 25) return 359;
    if (surahId == 26) return 367;
    if (surahId == 27) return 377;
    if (surahId == 28) return 385;
    if (surahId == 29) return 396;
    if (surahId == 30) return 404;
    if (surahId == 31) return 411;
    if (surahId == 32) return 415;
    if (surahId == 33) return 418;
    if (surahId == 34) return 428;
    if (surahId == 35) return 434;
    if (surahId == 36) return 440;
    if (surahId == 37) return 446;
    if (surahId == 38) return 453;
    if (surahId == 39) return 458;
    if (surahId == 40) return 467;
    if (surahId == 41) return 477;
    if (surahId == 42) return 483;
    if (surahId == 43) return 489;
    if (surahId == 44) return 496;
    if (surahId == 45) return 499;
    if (surahId == 46) return 502;
    if (surahId == 47) return 507;
    if (surahId == 48) return 511;
    if (surahId == 49) return 515;
    if (surahId == 50) return 518;
    if (surahId == 51) return 520;
    if (surahId == 52) return 523;
    if (surahId == 53) return 526;
    if (surahId == 54) return 528;
    if (surahId == 55) return 531;
    if (surahId == 56) return 534;
    if (surahId == 57) return 537;
    if (surahId == 58) return 542;
    if (surahId == 59) return 545;
    if (surahId == 60) return 549;
    if (surahId == 61) return 551;
    if (surahId == 62) return 553;
    if (surahId == 63) return 554;
    if (surahId == 64) return 556;
    if (surahId == 65) return 558;
    if (surahId == 66) return 560;
    if (surahId == 67) return 562;
    if (surahId == 68) return 564;
    if (surahId == 69) return 566;
    if (surahId == 70) return 568;
    if (surahId == 71) return 570;
    if (surahId == 72) return 572;
    if (surahId == 73) return 574;
    if (surahId == 74) return 575;
    if (surahId == 75) return 577;
    if (surahId == 76) return 578;
    if (surahId == 77) return 580;
    if (surahId == 78) return 582;
    if (surahId == 79) return 583;
    if (surahId == 80) return 585;
    if (surahId == 81) return 586;
    if (surahId == 82) return 587;
    if (surahId == 83) return 587;
    if (surahId == 84) return 589;
    if (surahId == 85) return 590;
    if (surahId == 86) return 591;
    if (surahId == 87) return 591;
    if (surahId == 88) return 592;
    if (surahId == 89) return 593;
    if (surahId == 90) return 594;
    if (surahId == 91) return 595;
    if (surahId == 92) return 595;
    if (surahId == 93) return 596;
    if (surahId == 94) return 596;
    if (surahId == 95) return 597;
    if (surahId == 96) return 597;
    if (surahId == 97) return 598;
    if (surahId == 98) return 598;
    if (surahId == 99) return 599;
    if (surahId == 100) return 599;
    if (surahId == 101) return 600;
    if (surahId == 102) return 600;
    if (surahId == 103) return 601;
    if (surahId == 104) return 601;
    if (surahId == 105) return 601;
    if (surahId == 106) return 602;
    if (surahId == 107) return 602;
    if (surahId == 108) return 602;
    if (surahId == 109) return 603;
    if (surahId == 110) return 603;
    if (surahId == 111) return 603;
    if (surahId == 112) return 604;
    if (surahId == 113) return 604;
    if (surahId == 114) return 604;
    return 1;
  }

  // Search Filter
  String _searchQuery = '';
  final bool _ramadanMode = false;

  // Wazifa Custom checks state
  final Map<String, List<CustomWazifa>> _wazifaSupplications = {
    'Morning': [
      CustomWazifa(
        title: 'আয়াতুল কুরসী (Ayatul Kursi)',
        arabicText: 'اللَّهُ لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ مَنْ ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلَّا بِإِذْنِهِ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ وَلَا يُحِيطُونَ بِشَيْءٍ مِنْ عِلْمِهِ إِلَّا بِمَا شَاءَ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ وَلَا يَئُودُهُ حِفْظُهُمَا وَهُوَ الْعَلِيُّ الْعَظِيمُ',
        banglaPronunciation: 'আল্লাহু লা ইলাহা ইল্লা হুয়াল হাইয়্যুল কাইয়্যুম। লা তা\'খুযুহু সিনাতুন ওয়ালা নাউম। লাহু মা ফিস সামাওয়াতি ওয়ামা ফিল আরদ। মান যাল্লাযী ইয়াশফাউ ইনদাহু ইল্লা বিইযনিহ। ইয়া\'লামু মা বাইনা আইদীহিম ওয়ামা খালফাহুম। ওয়ালা ইউহীতূনা বিশাইয়্যিম মিন ইলমিহী ইল্লা বিমা শা-আ। ওয়াসিআ কুরসিইয়্যুহুস সামাওয়াতি ওয়াল আরদ, ওয়ালা ইয়াউদুহু হিফযুহুমা ওয়া হুয়াল আলীইয়্যুল আযীম।',
        banglaTranslation: 'আল্লাহ, তিনি ছাড়া কোনো সত্য উপাস্য নেই, তিনি চিরঞ্জীব, সর্বসত্তার ধারক। তাঁকে তন্দ্রা ও নিদ্রা স্পর্শ করে না। আসমান ও যমীনে যা কিছু আছে সবকিছু তাঁরই। কে সে, যে তাঁর অনুমতি ছাড়া তাঁর নিকট সুপারিশ করবে? তাদের সামনে ও পিছনে যা কিছু আছে তা তিনি জানেন। আর তাঁর ইচ্ছাধীন জ্ঞান ছাড়া অন্য কোনো কিছুর ওপর তারা কর্তৃত্ব করতে পারে না। তাঁর রাজত্ব আসমান ও যমীনব্যাপী পরিব্যাপ্ত। আর এ দুটির রক্ষণাবেক্ষণ তাঁকে ক্লান্ত করে না। তিনি পরম উচ্চ, মহীয়ান।',
        readingRules: 'সকালে ১ বার পাঠ করলে সারাদিন শয়তানের অনিষ্ট থেকে নিরাপদে থাকা যায়।',
      ),
      CustomWazifa(
        title: 'সূরা ইখলাস, ফালাক, নাস (৩ বার)',
        arabicText: 'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ ۝ قُلْ هُوَ اللَّهُ أَحَدٌ... ۝ قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ... ۝ قُلْ أَعُوذُ بِرَبِّ النَّاسِ... ۝',
        banglaPronunciation: 'কুল হুওয়াল্লাহু আহাদ... কুল আউযু বিরাব্বিল ফালাক... কুল আউযু বিরাব্বিন নাস...',
        banglaTranslation: 'বলুন, তিনিই আল্লাহ একক... বলুন, আমি আশ্রয় প্রার্থনা করছি উষার প্রতিপালকের... বলুন, আমি আশ্রয় প্রার্থনা করছি মানুষের প্রতিপালকের...',
        readingRules: 'ফজর সালাতের পর এই ৩টি সূরা ৩ বার করে পাঠ করবেন, যা সারাদিনের সব অনিষ্ট থেকে সুরক্ষায় যথেষ্ট হবে।',
      ),
      CustomWazifa(
        title: 'সূরা হাশরের শেষ ৩ আয়াত',
        arabicText: 'هُوَ اللَّهُ الَّذِي لَا إِلَهَ إِلَّا هُوَ عَالِمُ الْغَيْبِ وَالشَّهَادَةِ هُوَ الرَّحْمَنُ الرَّحِيمُ ۝ هُوَ اللَّهُ الَّذِي لَا إِلَهَ إِلَّا هُوَ الْمَلِكُ الْقُدُّوسُ السَّلَامُ الْمُؤْمِنُ الْمُهَيْمِنُ الْعَزِيزُ الْجَبَّارُ الْمُتَكَبِّরُ سُبْحَانَ اللَّهِ عَمَّا يُشْرِكُونَ ۝ هُوَ اللَّهُ الْخَالِقُ الْبَارِئُ الْمُصَوِّرُ لَهُ الْأَسْمَاءُ الْحُসْنَى يُসَبِّحُ لَهُ مَا فِي السَّمَاوَاتِ وَالْأَرْضِ وَهُوَ الْعَزِيزُ الْحَكِيمُ ۝',
        banglaPronunciation: 'হুওয়াল্লাহুল্লাযী লা ইলাহা ইল্লা হুওয়া, আলিমুল গাইби ওয়াশ শাহাদাহ, হুওয়ার রাহমানুর রাহীম...',
        banglaTranslation: 'তিনিই আল্লাহ, যিনি ছাড়া কোনো ইলাহ নেই; তিনি দৃশ্য ও অদৃশ্যের পরিজ্ঞাত, তিনি পরম دয়াময়, পরম দয়ালু...',
        readingRules: 'সকালে ৩ বার "আউযুবিল্লাহিস সামীইল আলীমি মিনাশ শায়তানির রাজীম" পাঠ করে এই আয়াতসমূহ ১ বার পড়বেন।',
      ),
      CustomWazifa(
        title: 'সাইয়্যেদুল ইস্তেগফার',
        arabicText: 'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ خَلَقْتَنِي وَأَنَا عَبْدُكَ وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ وَأَبُوءُ لَكِ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ',
        banglaPronunciation: 'আল্লাহুম্মা আনতা রাব্বী লা ইলাহা ইল্লা আনতা খালাকতানি ওয়া আনা আবদুকা ওয়া আনা আলা আহদিকা ওয়া ওয়াদিকা মাসতাতাতু আউযুবিকা মিন শাররি মা সানাতু আবূউ লাকা বিনিমাতিকা আলাইয়্যা ওয়া আবূউ লাকা বিযাম্বী ফাগফিরলী ফাইন্নাহু লা ইয়াগফিরুয যুনূবা ইল্লা আনতা।',
        banglaTranslation: 'হে আল্লাহ! আপনি আমার প্রতিপালক। আপনি ছাড়া কোনো ইলাহ নেই। আপনি আমাকে সৃষ্টি করেছেন এবং আমি আপনার বান্দা...',
        readingRules: 'সকালে ১ বার পাঠ করলে এবং ওইদিন মারা গেলে সে জান্নাতী হবে।',
      ),
      CustomWazifa(
        title: 'সকালের দোয়া ও ইস্তিগফার',
        arabicText: 'اللَّهُمَّ بِكَ أَصْبَحْنَا وَبِكَ أَمْسَيْنَا وَبِكَ نَحْيَا وَبِكَ نَمُوتُ وَإِلَيْكَ النُّشُورُ',
        banglaPronunciation: 'আল্লাহুম্মা বিকা আসবাহনা ওয়া বিকা আমসাইনা ওয়া বিকা নাহইয়া ওয়া বিকা নামূতু ওয়া ইলাইকান নুশূর।',
        banglaTranslation: 'হে আল্লাহ! আপনার অনুগ্রহেই আমরা সকালে উপনীত হয়েছি এবং আপনার অনুগ্রহেই আমরা সন্ধ্যায় উপনীত হই, আপনার অনুগ্রহেই আমরা জীবন ধারণ করি এবং আপনার হুকুমেই আমরা মৃত্যুবরণ করি। আর আপনার দিকেই আমাদের পুনরুত্থান।',
        readingRules: 'ফজর শেষে সকালে ১ বার পাঠ করা সুন্নাত।',
      ),
    ],
    'Evening': [
      CustomWazifa(
        title: 'আয়াতুল কুরসী (Ayatul Kursi)',
        arabicText: 'اللَّهُ لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُwُمُ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ...',
        banglaPronunciation: 'আল্লাহু লা ইলাহা ইল্লা হুয়াল হাইয়্যুল কাইয়্যুম...',
        banglaTranslation: 'আল্লাহ, তিনি ছাড়া কোনো সত্য উপাস্য নেই, তিনি চিরঞ্জীব, সর্বসত্তার ধারক...',
        readingRules: 'সন্ধ্যায় পাঠ করলে সারা রাত জিন ও শয়তানের অনিষ্ট থেকে নিরাপদ থাকা যায়।',
      ),
      CustomWazifa(
        title: 'সূরা ইখলাস, ফালাক, নাস (৩ বার)',
        arabicText: 'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ ۝ قُلْ هُوَ اللَّهُ أَحَدٌ... ۝ قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ... ۝ قُلْ أَعُوذُ بِرَبِّ النَّاسِ... ۝',
        banglaPronunciation: 'কুল হুওয়াল্লাহু আহাদ... কুল আউযু বিরাব্বিল ফালাক... কুল আউযু বিরাব্বিন নাস...',
        banglaTranslation: 'বলুন, তিনিই আল্লাহ একক... বলুন, আমি আশ্রয় প্রার্থনা করছি উষার প্রতিপালকের...',
        readingRules: 'মাগরিবের পর এই ৩টি সূরা ৩ বার করে পাঠ করবেন।',
      ),
      CustomWazifa(
        title: 'সূরা হাশরের শেষ ৩ আয়াত',
        arabicText: 'هُوَ اللَّهُ الَّذِي لَا إِلَهَ إِلَّا هُوَ عَالِمُ الْغَيْبِ وَالشَّهَادَةِ...',
        banglaPronunciation: 'হুওয়াল্লাহুল্লাযী লা ইলাহা ইল্লা হুওয়া...',
        banglaTranslation: 'তিনিই আল্লাহ, যিনি ছাড়া কোনো ইলাহ নেই; তিনি দৃশ্য ও অদৃশ্যের পরিজ্ঞাত...',
        readingRules: 'সন্ধ্যায় মাগরিবের পর ৩ বার "আউযুবিল্লাহিস সামীইল আলীমি..." পাঠ করে এই আয়াতসমূহ ১ বার পড়বেন।',
      ),
      CustomWazifa(
        title: 'সন্ধ্যার দোয়া ও ইস্তিগফার',
        arabicText: 'اللَّهُمَّ بِكَ أَمْسَيْنَا وَبِكَ أَصْبَحْنَا وَبِكَ نَحْيَا وَبِكَ نَمُوتُ وَإِلَيْكَ الْمَصِيرُ',
        banglaPronunciation: 'আল্লাহুম্মা বিকা আমসাইনা ওয়া বিকা আসবাহনা ওয়া বিকা নাহইয়া ওয়া বিকা নামূতু ওয়া ইলাইকাল মাছীর।',
        banglaTranslation: 'হে আল্লাহ! আপনার অনুগ্রহেই আমরা সন্ধ্যায় উপনীত হয়েছি এবং আপনার অনুগ্রহেই সকালে উপনীত হয়েছি, আপনার অনুগ্রহেই আমরা জীবন ধারণ করি এবং আপনার হুকুমেই আমরা মৃত্যুবরণ করি। আর আপনার দিকেই আমাদের প্রত্যাবর্তন।',
        readingRules: 'সন্ধ্যায় ১ বার পাঠ করা সুন্নাত।',
      ),
      CustomWazifa(
        title: 'দরুদে তুনাজ্জিনা (৩ বার)',
        arabicText: 'اللَّهُمَّ صَلِّ عَلَى سَيِّدِنَا مُحَمَّدٍ صَلَاةً تُنْجِينَا بِهَا مِنْ جَمِيعِ الْأَهْوَالِ وَالْآفَاتِ...',
        banglaPronunciation: 'আল্লাহুম্মা সাল্লি আলা সাইয়্যিদিনা মুহাম্মাদিন সালাতান তুনজিনা...',
        banglaTranslation: 'হে আল্লাহ! আমাদের সর্দার হযরত মুহাম্মদ (সা.)-এর ওপর এমন রহমত নাযিল করুন, যার বরকতে আপনি আমাদের সকল ভয়ভীতি ও বিপদ-আপদ থেকে মুক্তি দেবেন...',
        readingRules: 'সন্ধ্যায় ও সালাত শেষে ৩ বার পাঠ অত্যন্ত ফজিলতপূর্ণ।',
      ),
    ],
    'Before Sleep': [
      CustomWazifa(
        title: 'সূরা মূলক (Surah Al-Mulk)',
        benefitBangla: 'সূরা মূলক কবরের আযাব থেকে মুক্তি দান করে।',
        benefitEnglish: 'Protects from the punishment of the grave.',
        readingRules: 'কুরআন ট্যাবে গিয়ে সূরা ৬৭ (Al-Mulk) তিলাওয়াত করুন।',
      ),
      CustomWazifa(
        title: 'সূরা সাজদাহ (Surah As-Sajdah)',
        benefitBangla: 'ঘুমানোর আগে সূরা সাজদাহ পাঠ করা সুন্নাত।',
        benefitEnglish: 'Reciting Surah As-Sajdah before sleeping is a recommended sunnah.',
        readingRules: 'কুরআন ট্যাবে গিয়ে সূরা ৩২ (As-Sajdah) তিলাওয়াত করুন।',
      ),
      CustomWazifa(
        title: 'সূরা বাকারার শেষ ২ আয়াত',
        arabicText: 'آمَنَ الرَّسُولُ بِمَا أُنْزِلَ إِلَيْهِ مِنْ رَبِّهِ وَالْمُؤْمِنُونَ...',
        banglaPronunciation: 'আমানার রাসূলু বিমা উনযিলা ইলাইহি মির রব্বিহী ওয়াল মু\'মিনূন...',
        banglaTranslation: 'রাসূল বিশ্বাস রাখেন ওই সমস্ত বিষয়ের ওপর যা তাঁর প্রতিপালকের পক্ষ থেকে অবতীর্ণ হয়েছে এবং মুমিনগণও...',
        readingRules: 'রাতে এই আয়াত দুটি পাঠ করলে তা সমস্ত অনিষ্ট থেকে বাঁচার জন্য যথেষ্ট হয়।',
      ),
      CustomWazifa(
        title: 'সূরা কাফিরুন',
        arabicText: 'قُلْ يَا أَيُّهَا الْكَافِرُونَ ۝ لَا أَعْبُدُ مَا تَعْبُدُونَ ۝ وَلَا أَنْتُمْ عَابِدُونَ مَا أَعْبُدُ ۝ وَلَا أَنَا عَابِدٌ مَا عَبَدْتُمْ ۝ وَلَا أَنْتُمْ عَابِدُونَ مَا أَعْبُدُ ۝ لَكُمْ دِينُكُمْ وَلِيَ دِينِ ۝',
        banglaPronunciation: 'কুল ইয়া আইয়্যুহাল কাফিরূন। লা আ\'বুদু মা তা\'বুদূন। ওয়ালা আনতুম আবিদূনা মা আ\'বুদ। ওয়ালা আনা আবিদুম মা আবাদতখন। ওয়ালা আনতুম আবিদূনা মা আ\'বুদ। লাকুম দীনুকুম ওয়ালি ইয়াদীন।',
        banglaTranslation: 'বলুন, হে কাফেরকুল! আমি তার এবাদত করি না যার এবাদত তোমরা কর। এবং তোমরাও তাঁর এবাদতকারী নও যাঁর এবাদত আমি করি। এবং আমি এবাদতকারী নই যার এবাদত তোমরা করেছ। এবং তোমরা তাঁর এবাদতকারী নও যার এবাদত আমি করি। তোমাদের দ্বীন তোমাদের জন্য, আমার দ্বীন আমার জন্য।',
        readingRules: 'ঘুমানোর আগে পাঠ করলে শিরক থেকে মুক্ত থাকা যায়।',
      ),
      CustomWazifa(
        title: 'ঘুমানোর দোয়া ও ইস্তিগফার',
        arabicText: 'بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا',
        banglaPronunciation: 'বিইসমিকা আল্লাহুম্মা আমূতু ওয়া আহইয়া।',
        banglaTranslation: 'হে আল্লাহ! আপনারই নামে আমি মৃত্যুবরণ করি (ঘুমাই) এবং জীবিত হই (জাগি)।',
        readingRules: 'ডান কাতে শুয়ে ১ বার পাঠ করবেন।',
      ),
    ],
    'After Salah': [
      CustomWazifa(
        title: 'আয়াতুল কুরসী (Ayatul Kursi)',
        arabicText: 'اللَّهُ لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ...',
        banglaPronunciation: 'আল্লাহু লা ইলাহা ইল্লা হুয়াল হাইয়্যুল কাইয়্যুম...',
        banglaTranslation: 'আল্লাহ, তিনি ছাড়া কোনো সত্য উপাস্য নেই, তিনি চিরঞ্জীব, সর্বসত্তার ধারক...',
        readingRules: 'প্রতি ফরজ সালাত শেষে ১ বার পাঠ করবেন। জান্নাতে যাওয়ার মাধ্যম।',
      ),
      CustomWazifa(
        title: 'তাসবীহ ফাতেমী (৩৩ বার করে)',
        arabicText: 'سُبْحَانَ اللَّهِ (৩৩ বার), الْحَمْدُ لِلَّهِ (৩৩ বার), اللَّهُ أَكْبَرُ (৩৪ বার)',
        banglaPronunciation: 'সুবহানাল্লাহ, আলহামদুলিল্লাহ, আল্লাহু আকবার',
        banglaTranslation: 'আল্লাহ অতি পবিত্র, সকল প্রশংসা আল্লাহর, আল্লাহ সর্বশ্রেষ্ঠ।',
        readingRules: 'সালাতের পর সুবহানাল্লাহ ৩৩ বার, আলহামদুলিল্লাহ ৩৩ বার ও আল্লাহু আকবার ৩৪ বার পাঠ করবেন।',
      ),
      CustomWazifa(
        title: 'আস্তাগফিরুল্লাহ ও দোয়া',
        arabicText: 'أَسْتَغْفِرُ اللَّهَ',
        banglaPronunciation: 'আস্তাগফিরুল্লাহ (৩ বার)',
        banglaTranslation: 'আমি আল্লাহর নিকট ক্ষমা প্রার্থনা করছি।',
        readingRules: 'সালাতের সালাম ফেরানোর পর ৩ বার পাঠ করবেন।',
      ),
      CustomWazifa(
        title: 'সূরা ইখলাস, ফালাক, নাস',
        arabicText: 'قُلْ هُوَ اللَّهُ أَحَدٌ... قُل... قُل...',
        banglaPronunciation: 'কুল হুওয়াল্লাহু أَحَدٌ... কুল আউযু... কুল আউযু...',
        banglaTranslation: 'বলুন, তিনিই আল্লাহ একক...',
        readingRules: 'প্রতি ফরজ সালাত শেষে এই তিনটি সূরা ১ বার করে পাঠ করবেন।',
      ),
    ],
  };
  
  // Completed states mapped by "Category_Supplication" -> bool
  final Map<String, bool> _completedWazifas = {};
  final Map<String, bool> _completedHadithWazifas = {};

  // Bookmarks & Notes (Reset empty)
  final List<Map<String, String>> _bookmarks = [];
  final List<Map<String, String>> _reflections = [];

  // Dynamic Hifz Visual Quran Map state
  Set<int> _memorizedSurahIds = {};

  // Settings state
  double _arabicFontSize = 24.0;
  bool _showBanglaTranslation = true;
  bool _showEnglishTranslation = true;
  bool _isDarkMode = false;
  bool _readingReminderEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  void _showWheelPagePickerModal(BuildContext context, Color cardBg, Color themeText) {
    int tempAyah = _activeReaderAyahIndex.clamp(1, _loadedAyahs.isEmpty ? 1 : _loadedAyahs.length);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final modalBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
            return Container(
              height: 310,
              decoration: BoxDecoration(
                color: modalBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 16)
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.placeholder.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Fixed Header Row with Expanded title to prevent overflow
                  Row(
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.placeholder, fontSize: 13)),
                      ),
                      Expanded(
                        child: Text(
                          'Jump to Ayah',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: themeText),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.midTeal,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _activeReaderAyahIndex = tempAyah;
                          });
                        },
                        child: Text('Jump', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Ayah Scrollable Wheel
                  Expanded(
                    child: CupertinoPicker(
                      itemExtent: 44,
                      scrollController: FixedExtentScrollController(
                        initialItem: (tempAyah - 1).clamp(0, _loadedAyahs.isEmpty ? 0 : _loadedAyahs.length - 1),
                      ),
                      onSelectedItemChanged: (index) {
                        setModalState(() {
                          tempAyah = index + 1;
                        });
                      },
                      children: List.generate(_loadedAyahs.length, (idx) {
                        final num = idx + 1;
                        final isSelected = num == tempAyah;
                        return Center(
                          child: Text(
                            'Ayah $num',
                            style: GoogleFonts.poppins(
                              fontSize: isSelected ? 17 : 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? AppColors.midTeal : themeText.withValues(alpha: 0.6),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Strip HTML tags returned by quran.com tafsir API
  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll(RegExp(r' {2,}'), ' ')
        .trim();
  }

  String _cleanBismillahPrefix(String text, int surahId) {
    if (surahId == 1 || surahId == 9) return text;
    
    // Split text into words and check if first 4 words correspond to Bismillah
    final words = text.trim().split(RegExp(r'\s+'));
    if (words.length >= 4) {
      final joined = words.take(4).join(' ');
      final cleanJoined = joined.replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0671]'), '');
      if (cleanJoined.contains('بسم') && (cleanJoined.contains('الرحمن') || cleanJoined.contains('الرحمن')) && cleanJoined.contains('الرحيم')) {
        return words.skip(4).join(' ').trim();
      }
    }
    
    // Fallback: search for keywords
    final endKeywords = ['الرَّحِيمِ', 'ٱلرَّحِيمِ', 'الرَّحِيْمِ', 'الرَّحِيم', 'ٱلرَّحِيم', 'الرحيم'];
    for (final keyword in endKeywords) {
      final idx = text.indexOf(keyword);
      if (idx != -1 && idx < 80) {
        return text.substring(idx + keyword.length).trim();
      }
    }
    return text;
  }

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _currentStreak = prefs.getInt('quran_tracker_streak') ?? 0;
        _longestStreak = prefs.getInt('quran_longest_streak') ?? 0;
        
        _completedAyahsToday = prefs.getInt('quran_completed_ayahs_today') ?? 0;
        _targetDailyAyahs = prefs.getInt('quran_target_daily_ayahs') ?? 208;

        _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
        
        final fontVal = prefs.get('quran_settings_font_size');
        if (fontVal is double) {
          _arabicFontSize = fontVal;
        } else if (fontVal is int) {
          _arabicFontSize = fontVal.toDouble();
        } else {
          _arabicFontSize = 24.0;
        }

        _continueSurahId = prefs.getInt('quran_continue_surah') ?? 1;
        _continuePage = prefs.getInt('quran_continue_page') ?? 1;
        _continueAyah = prefs.getInt('quran_continue_ayah') ?? 1;

        // Load read sets
        final todayReadStr = prefs.getString('quran_read_ayahs_today');
        if (todayReadStr != null) {
          final List<dynamic> decoded = jsonDecode(todayReadStr);
          _readAyahsToday = decoded.map((e) => e.toString()).toSet();
        } else {
          _readAyahsToday = {};
        }

        final allTimeReadStr = prefs.getString('quran_read_ayahs_all_time');
        if (allTimeReadStr != null) {
          final List<dynamic> decoded = jsonDecode(allTimeReadStr);
          _readAyahsAllTime = decoded.map((e) => e.toString()).toSet();
        } else {
          _readAyahsAllTime = {};
        }

        // Recalculate Juz completed based on unique all-time read Ayahs
        _khatmTotalJuzCompleted = ((_readAyahsAllTime.length / 6236.0) * 30).floor();
        if (_khatmTotalJuzCompleted > 30) _khatmTotalJuzCompleted = 30;

        // Daily carry-over/deficit rollover logic
        final String? lastSavedDate = prefs.getString('quran_last_saved_date');
        final String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

        if (lastSavedDate != null && lastSavedDate != todayDate) {
          int excess = _completedAyahsToday - _targetDailyAyahs;
          if (excess > 0) {
            _completedAyahsToday = excess; // extra ayahs read yesterday carry over as progress today
          } else {
            int deficit = _targetDailyAyahs - _completedAyahsToday;
            _targetDailyAyahs += deficit;  // deficit ayahs yesterday add to target today
            _completedAyahsToday = 0;
          }
          _readAyahsToday.clear(); // reset daily read set for the new day
          prefs.setString('quran_read_ayahs_today', jsonEncode(_readAyahsToday.toList()));
          prefs.setInt('quran_completed_ayahs_today', _completedAyahsToday);
          prefs.setInt('quran_target_daily_ayahs', _targetDailyAyahs);
        }
        prefs.setString('quran_last_saved_date', todayDate);

        // Load custom wazifa lists
        for (final cat in _wazifaSupplications.keys) {
          final listStr = prefs.getString('quran_wazifa_supps_$cat');
          if (listStr != null) {
            final List<dynamic> decoded = jsonDecode(listStr);
            _wazifaSupplications[cat] = decoded.map((e) {
              if (e is Map) {
                return CustomWazifa.fromJson(Map<String, dynamic>.from(e));
              } else {
                return CustomWazifa(title: e.toString());
              }
            }).toList();
          }
        }

        // Load wazifa check states
        final checkStr = prefs.getString('quran_wazifa_checks');
        if (checkStr != null) {
          final Map<String, dynamic> decoded = jsonDecode(checkStr);
          decoded.forEach((key, val) {
            _completedWazifas[key] = val as bool;
          });
        }

        final checkHadithStr = prefs.getString('quran_hadith_wazifa_checks');
        if (checkHadithStr != null) {
          final Map<String, dynamic> decoded = jsonDecode(checkHadithStr);
          decoded.forEach((key, val) {
            _completedHadithWazifas[key] = val as bool;
          });
        }

        // Load bookmarks & reflections
        final bookmarkStr = prefs.getString('quran_bookmarks_json');
        if (bookmarkStr != null) {
          final List<dynamic> decoded = jsonDecode(bookmarkStr);
          _bookmarks.clear();
          for (final item in decoded) {
            _bookmarks.add(Map<String, String>.from(item));
          }
        }

        final reflectionsStr = prefs.getString('quran_reflections_json');
        if (reflectionsStr != null) {
          final List<dynamic> decoded = jsonDecode(reflectionsStr);
          _reflections.clear();
          for (final item in decoded) {
            _reflections.add(Map<String, String>.from(item));
          }
        }

        // Load Hifz memorized Surah IDs
        final hifzStr = prefs.getString('quran_hifz_memorized_ids');
        if (hifzStr != null) {
          final List<dynamic> decoded = jsonDecode(hifzStr);
          _memorizedSurahIds = decoded.map((e) => e as int).toSet();
        }
      });
    } catch (e) {
      debugPrint("Error loading state from SharedPreferences: $e");
    }
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('quran_tracker_streak', _currentStreak);
    await prefs.setInt('quran_longest_streak', _longestStreak);
    await prefs.setInt('quran_completed_ayahs_today', _completedAyahsToday);
    await prefs.setInt('quran_target_daily_ayahs', _targetDailyAyahs);
    await prefs.setInt('quran_khatm_juz_completed', _khatmTotalJuzCompleted);
    await prefs.setBool('is_dark_mode', _isDarkMode);
    await prefs.setDouble('quran_settings_font_size', _arabicFontSize);

    await prefs.setInt('quran_continue_surah', _continueSurahId);
    await prefs.setInt('quran_continue_page', _continuePage);
    await prefs.setInt('quran_continue_ayah', _continueAyah);

    await prefs.setString('quran_read_ayahs_today', jsonEncode(_readAyahsToday.toList()));
    await prefs.setString('quran_read_ayahs_all_time', jsonEncode(_readAyahsAllTime.toList()));

    await prefs.setString('quran_last_saved_date', DateFormat('yyyy-MM-dd').format(DateTime.now()));

    for (final cat in _wazifaSupplications.keys) {
      await prefs.setString(
        'quran_wazifa_supps_$cat',
        jsonEncode(_wazifaSupplications[cat]?.map((e) => e.toJson()).toList()),
      );
    }

    await prefs.setString('quran_wazifa_checks', jsonEncode(_completedWazifas));
    await prefs.setString('quran_hadith_wazifa_checks', jsonEncode(_completedHadithWazifas));
    await prefs.setString('quran_bookmarks_json', jsonEncode(_bookmarks));
    await prefs.setString('quran_reflections_json', jsonEncode(_reflections));
    await prefs.setString('quran_hifz_memorized_ids', jsonEncode(_memorizedSurahIds.toList()));
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // SAFE GENERATOR
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> _loadSurahData(int surahId, int totalAyahs) async {
    setState(() {
      _isLoadingSurah = true;
      _loadedAyahs = [];
    });

    try {
      final arabicUri    = Uri.parse('https://api.alquran.cloud/v1/surah/$surahId');
      final banglaUri    = Uri.parse('https://api.alquran.cloud/v1/surah/$surahId/bn.bengali');
      final englishUri   = Uri.parse('https://api.alquran.cloud/v1/surah/$surahId/en.sahih');
      // Tafsir Ibn Kathir (id=169, English) & Tafsir Abu Bakr Zakaria / Ibn Kathir (id=166, Bangla)
      // Pass per_page=300 to fetch ALL verses in the Surah (default per_page=10 truncates after verse 10)
      final engTafsirUri = Uri.parse('https://api.quran.com/api/v4/tafsirs/169/by_chapter/$surahId?per_page=300');
      final bnTafsirUri  = Uri.parse('https://api.quran.com/api/v4/tafsirs/166/by_chapter/$surahId?per_page=300');

      final responses = await Future.wait([
        http.get(arabicUri).timeout(const Duration(seconds: 8)),
        http.get(banglaUri).timeout(const Duration(seconds: 8)),
        http.get(englishUri).timeout(const Duration(seconds: 8)),
        http.get(engTafsirUri, headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 10)),
        http.get(bnTafsirUri,  headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 10)),
      ]);

      if (responses[0].statusCode == 200 &&
          responses[1].statusCode == 200 &&
          responses[2].statusCode == 200) {
        final arabicJson  = jsonDecode(responses[0].body);
        final banglaJson  = jsonDecode(responses[1].body);
        final englishJson = jsonDecode(responses[2].body);

        final List<dynamic> arabicAyahs  = arabicJson['data']['ayahs'];
        final List<dynamic> banglaAyahs  = banglaJson['data']['ayahs'];
        final List<dynamic> englishAyahs = englishJson['data']['ayahs'];

        // Populate tafsir caches from quran.com
        if (responses[3].statusCode == 200) {
          try {
            final List<dynamic> items = (jsonDecode(responses[3].body))['tafsirs'] ?? [];
            for (final t in items) {
              final k = t['verse_key']?.toString() ?? '';
              final v = t['text']?.toString() ?? '';
              if (k.isNotEmpty) _engTafsirCache[k] = _stripHtml(v);
            }
          } catch (_) {}
        }
        if (responses[4].statusCode == 200) {
          try {
            final List<dynamic> items = (jsonDecode(responses[4].body))['tafsirs'] ?? [];
            for (final t in items) {
              final k = t['verse_key']?.toString() ?? '';
              final v = t['text']?.toString() ?? '';
              if (k.isNotEmpty) _bnTafsirCache[k] = _stripHtml(v);
            }
          } catch (_) {}
        }

        final List<AyahContent> fetchedList = [];
        for (int i = 0; i < arabicAyahs.length; i++) {
          final rawArabic   = arabicAyahs[i]['text'] ?? '';
          final cleanArabic = i == 0 ? _cleanBismillahPrefix(rawArabic, surahId) : rawArabic;
          final ayahNum     = arabicAyahs[i]['numberInSurah'] ?? (i + 1);
          final verseKey    = '$surahId:$ayahNum';

          // Extract Bangla Tafsir with fallback to previous grouped ayah if empty
          String bnExplanation = _bnTafsirCache[verseKey] ?? '';
          if (bnExplanation.isEmpty) {
            for (int prev = ayahNum - 1; prev >= 1; prev--) {
              final prevKey = '$surahId:$prev';
              final prevText = _bnTafsirCache[prevKey] ?? '';
              if (prevText.isNotEmpty) {
                bnExplanation = prevText;
                break;
              }
            }
          }

          // Extract English Tafsir with fallback to previous grouped ayah if empty
          String engExplanation = _engTafsirCache[verseKey] ?? '';
          if (engExplanation.isEmpty) {
            for (int prev = ayahNum - 1; prev >= 1; prev--) {
              final prevKey = '$surahId:$prev';
              final prevText = _engTafsirCache[prevKey] ?? '';
              if (prevText.isNotEmpty) {
                engExplanation = prevText;
                break;
              }
            }
          }

          fetchedList.add(AyahContent(
            number: ayahNum,
            arabic: cleanArabic,
            banglaTranslation: banglaAyahs[i]['text'] ?? '',
            englishTranslation: englishAyahs[i]['text'] ?? '',
            banglaExplanation: bnExplanation,
            englishExplanation: engExplanation,
            page: arabicAyahs[i]['page'],
          ));
        }

        setState(() {
          _loadedAyahs = fetchedList;
          _isLoadingSurah = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('Quran API load error: $e');
    }

    // Offline / timeout fallback
    setState(() {
      _loadedAyahs = _generateSurahContent(surahId, totalAyahs);
      _isLoadingSurah = false;
    });
  }

  List<AyahContent> _generateSurahContent(int surahId, int totalAyahs) {
    if (_realQuranText.containsKey(surahId)) {
      final list = _realQuranText[surahId]!;
      if (list.length == totalAyahs) {
        return List.generate(list.length, (idx) {
          final item = list[idx];
          final startPage = _getSurahStartPage(surahId);
          final offset = (idx / list.length) * _getSurahTotalPages(surahId, totalAyahs);
          final pageVal = (startPage + offset.toInt()).clamp(1, 604);
          
          if (idx == 0) {
            return AyahContent(
              number: item.number,
              arabic: _cleanBismillahPrefix(item.arabic, surahId),
              banglaTranslation: item.banglaTranslation,
              englishTranslation: item.englishTranslation,
              banglaExplanation: item.banglaExplanation,
              englishExplanation: item.englishExplanation,
              page: pageVal,
            );
          }
          return AyahContent(
            number: item.number,
            arabic: item.arabic,
            banglaTranslation: item.banglaTranslation,
            englishTranslation: item.englishTranslation,
            banglaExplanation: item.banglaExplanation,
            englishExplanation: item.englishExplanation,
            page: pageVal,
          );
        });
      }
    }

    final surah = _surahList.firstWhere((e) => e.id == surahId);
    return List.generate(totalAyahs, (i) {
      final ayahNum = i + 1;
      final startPage = _getSurahStartPage(surahId);
      final offset = (i / totalAyahs) * _getSurahTotalPages(surahId, totalAyahs);
      final pageVal = (startPage + offset.toInt()).clamp(1, 604);

      return AyahContent(
        number: ayahNum,
        arabic: 'وَإِذْ قَالَ رَبُّكَ لِلْمَلَائِكَةِ إِنِّي جَاعِلٌ فِي الْأَرْضِ خَلِيفَةً ($ayahNum)',
        banglaTranslation: '${surah.name} এর $ayahNum নং আয়াতের বাংলা অনুবাদ। মুমিনদের জন্য রয়েছে এতে কল্যাণ।',
        englishTranslation: 'This is the English translation of Surah ${surah.englishName} Ayah $ayahNum.',
        banglaExplanation: 'আয়াতটির তাফসিরে বর্ণিত হয়েছে যে আল্লাহ মুমিনদের সর্বদা সৎ পথে চলার নির্দেশনা দিয়েছেন।',
        englishExplanation: 'Tafsir confirms Allah\'s call to all believers to remain firm on the path of truth and justice.',
        page: pageVal,
      );
    });
  }



  // ─────────────────────────────────────────────────────────────────────────────


  // ─────────────────────────────────────────────────────────────────────────────
  // BASE STRUCTURE
  // ─────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final themeBg = _isDarkMode ? const Color(0xFF121212) : const Color(0xFFF7F7F5);
    final themeText = _isDarkMode ? Colors.white : AppColors.navyBlue;
    final cardBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    return Theme(
      data: ThemeData(
        brightness: _isDarkMode ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: themeBg,
      ),
      child: Container(
           color: _isDarkMode ? const Color(0xFF000000) : const Color(0xFFE8E8E8),
      child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Scaffold(
              backgroundColor: themeBg,
              body: SafeArea(
                child: Column(
                  children: [
                    _buildTopHeader(themeText),
                    const SizedBox(height: 12),
                    _buildTabBar(),
                    Expanded(child: _buildActiveTabContent(cardBg, themeText)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader(Color themeText) {
    final subtextColor = _isDarkMode ? Colors.white70 : AppColors.navyBlue.withValues(alpha: 0.55);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: themeText, size: 20),
            onPressed: () {
              if (_activeReaderSurahId != null) {
                setState(() => _activeReaderSurahId = null);
              } else if (_activeMoreSubView != null) {
                setState(() => _activeMoreSubView = null);
              } else {
                Navigator.pop(context);
              }
            },
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _isDarkMode ? const Color(0xFF2C2C2C) : AppColors.navyBlue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.star_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quran Journey',
                  style: GoogleFonts.poppins(fontSize: 15.5, fontWeight: FontWeight.bold, color: themeText),
                ),
                Text(
                  'Track your recitation & progress',
                  style: GoogleFonts.inter(fontSize: 11, color: subtextColor),
                ),
              ],
            ),
          ),
          if (_ramadanMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.coralOrange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Ramadan Mode',
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.coralOrange),
              ),
            ),
        ],
      ),
    );
  }

  static const _tabLabels = ['Home', 'Quran', 'Progress', 'Wazifa', 'More'];
  static const _tabIcons = [
    Icons.home_rounded,
    Icons.menu_book_rounded,
    Icons.trending_up_rounded,
    Icons.auto_awesome_rounded,
    Icons.more_horiz_rounded,
  ];

  Widget _buildTabBar() {
    final cardBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: List.generate(_tabLabels.length, (index) {
          final isSelected = _bottomNavIndex == index;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _bottomNavIndex = index;
                  if (index != 1) {
                    _activeReaderSurahId = null;
                  }
                  if (index != 4) {
                    _activeMoreSubView = null;
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.navyBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _tabIcons[index],
                      size: 16,
                      color: isSelected
                          ? Colors.white
                          : (_isDarkMode
                              ? Colors.white54
                              : AppColors.navyBlue.withValues(alpha: 0.4)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _tabLabels[index],
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : (_isDarkMode
                                ? Colors.white54
                                : AppColors.navyBlue.withValues(alpha: 0.4)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildActiveTabContent(Color cardBg, Color themeText) {
    switch (_bottomNavIndex) {
      case 0:
        return _buildHomeTab(cardBg, themeText);
      case 1:
        if (_activeReaderSurahId != null) {
          return _buildQuranReaderView(cardBg, themeText);
        }
        return _buildSurahListView(cardBg, themeText);
      case 2:
        return _buildProgressTabView(cardBg, themeText);
      case 3:
        return _buildWazifaTabView(cardBg, themeText);
      case 4:
        return _buildMoreTabView(cardBg, themeText);
      default:
        return const SizedBox.shrink();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // VIEW 1: HOME (DASHBOARD) WITH DYNAMIC ROTATION DAILY VERSES
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildHomeTab(Color cardBg, Color themeText) {
    final continueSurahName = _surahList.firstWhere((e) => e.id == _continueSurahId).name;

    int totalTodayWazifas = 0;
    int completedTodayWazifas = 0;
    _wazifaSupplications.forEach((cat, list) {
      for (final w in list) {
        totalTodayWazifas++;
        if (_completedWazifas['${cat}_${w.title}'] ?? false) {
          completedTodayWazifas++;
        }
      }
    });

    // Dynamic rotation daily verses based on current day of the month/year
    final verseIndex = DateTime.now().day % _dailyVersesDb.length;
    final dailyVerse = _dailyVersesDb[verseIndex];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Text(
            'Assalamu Alaikum, Akhi 🌿',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: themeText),
          ),
          const SizedBox(height: 14),

          if (_completedAyahsToday >= _targetDailyAyahs) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.midTeal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.midTeal.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded, color: AppColors.midTeal, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You already completed your daily target! 🌟 Extra verses read will carry over to tomorrow.',
                      style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.midTeal),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Continue Reading Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.navyBlue, Color(0xFF1D3557)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Continue Reading', style: GoogleFonts.inter(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(continueSurahName, style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Ayah $_continueAyah', style: GoogleFonts.inter(color: Colors.white60, fontSize: 11)),
                  ],
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.midTeal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    setState(() {
                      _activeReaderSurahId = _continueSurahId;
                      _activeReaderAyahIndex = _continueAyah;
                      _bottomNavIndex = 1;
                    });
                    _loadSurahData(_continueSurahId, _surahList.firstWhere((e) => e.id == _continueSurahId).totalAyahs);
                  },
                  child: Text('Continue', style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Streak & Goals Row
          Row(
            children: [
              Expanded(
                child: _buildHomeMiniCard(
                  cardBg,
                  Icons.local_fire_department_rounded,
                  AppColors.coralOrange,
                  'Reading Streak',
                  '$_currentStreak Days',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHomeMiniCard(
                  cardBg,
                  Icons.star_rounded,
                  AppColors.midTeal,
                  'Target Today',
                  '$_completedAyahsToday / $_targetDailyAyahs Ayahs',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Daily Progress Indicator Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Today\'s Goal Progress', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: themeText)),
                    Text('${_targetDailyAyahs > 0 ? ((_completedAyahsToday / _targetDailyAyahs) * 100).toInt().clamp(0, 100) : 0}%', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _targetDailyAyahs > 0 ? (_completedAyahsToday / _targetDailyAyahs).toDouble().clamp(0.0, 1.0) : 0.0,
                    minHeight: 10,
                    backgroundColor: Colors.grey.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation(AppColors.midTeal),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Khatm Completion', style: GoogleFonts.inter(color: AppColors.placeholder, fontSize: 10)),
                        Text('$_khatmTotalJuzCompleted / 30 Juz', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: themeText)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Estimated Target Date', style: GoogleFonts.inter(color: AppColors.placeholder, fontSize: 10)),
                        Text(_khatmEstimatedCompletion, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: themeText)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Supplication card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.spa_rounded, color: AppColors.midTeal, size: 20),
                        const SizedBox(width: 8),
                        Text('Supplication Tracker', style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: themeText)),
                      ],
                    ),
                    Text('$completedTodayWazifas / $totalTodayWazifas Completed', style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Maintain your daily wazifa checklist. Track custom Azkars and prayer formulas.', style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.placeholder)),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.navyBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () => setState(() => _bottomNavIndex = 3),
                  child: Text('Complete Wazifas', style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Dashboard Hifz Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bookmark_added_rounded, color: AppColors.coralOrange, size: 20),
                        const SizedBox(width: 8),
                        Text('Hifz Memorization Progress', style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: themeText)),
                      ],
                    ),
                    Text('${_memorizedSurahIds.length} Surahs', style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.coralOrange)),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Track your Quran memorization goals via the interactive Hifz Quran Map.', style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.placeholder)),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.navyBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () => setState(() {
                    _bottomNavIndex = 4;
                    _activeMoreSubView = 'hifz';
                  }),
                  child: Text('Open Hifz Dashboard', style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Daily Ayah Inspiration Card (Akhirah/Salah Focused Rotating Reminders)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.wb_sunny_rounded, color: AppColors.coralOrange, size: 18),
                        const SizedBox(width: 8),
                        Text('Daily Verse (Remembrance)', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  dailyVerse.arabic,
                  style: GoogleFonts.amiri(fontSize: 20, fontWeight: FontWeight.bold, height: 1.6),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 10),
                Text(
                  dailyVerse.bangla,
                  style: GoogleFonts.inter(fontSize: 12.5, fontStyle: FontStyle.italic, color: themeText, height: 1.45),
                ),
                const SizedBox(height: 6),
                Text(
                  dailyVerse.english,
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.placeholder, height: 1.4),
                ),
                const SizedBox(height: 8),
                Text(
                  dailyVerse.reference,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.placeholder.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: 10),
                TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: () => setState(() {
                    _bottomNavIndex = 4;
                    _activeMoreSubView = 'daily_ayah';
                  }),
                  child: Text('Read Full Explanation & Reflect →', style: GoogleFonts.poppins(fontSize: 11.5, color: AppColors.midTeal, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHomeMiniCard(Color cardBg, IconData icon, Color iconColor, String title, String val) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 10, color: AppColors.placeholder)),
                const SizedBox(height: 2),
                Text(val, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // VIEW 2: SURAH LIST (SEARCH & SELECT)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildSurahListView(Color cardBg, Color themeText) {
    final filteredSurahs = _surahList.where((element) {
      final nameLower = element.name.toLowerCase();
      final engLower = element.englishName.toLowerCase();
      final queryLower = _searchQuery.toLowerCase();
      return nameLower.contains(queryLower) || engLower.contains(queryLower);
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search Surah...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: cardBg,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: filteredSurahs.length,
              itemBuilder: (ctx, index) {
                final surah = filteredSurahs[index];
                return Card(
                  color: cardBg,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.midTeal.withValues(alpha: 0.1),
                      child: Text('${surah.id}', style: GoogleFonts.poppins(color: AppColors.midTeal, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    title: Text(surah.name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: themeText, fontSize: 13.5)),
                    subtitle: Text('${surah.totalAyahs} Ayahs • ${surah.type}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.placeholder)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.placeholder),
                    onTap: () {
                      setState(() {
                        _activeReaderSurahId = surah.id;
                        _activeReaderAyahIndex = 1;
                      });
                      _loadSurahData(surah.id, surah.totalAyahs);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // VIEW 3: QURAN READER VIEW WITH MEMORIZATION SYNC BUTTON
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildQuranReaderView(Color cardBg, Color themeText) {
    if (_isLoadingSurah) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.midTeal),
            const SizedBox(height: 16),
            Text(
              'Fetching verses from Holy Quran API...',
              style: GoogleFonts.poppins(color: AppColors.midTeal, fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            Text(
              'Please wait a moment',
              style: GoogleFonts.inter(color: AppColors.placeholder, fontSize: 11.5),
            ),
          ],
        ),
      );
    }

    final surah = _surahList.firstWhere((e) => e.id == _activeReaderSurahId);
    if (_loadedAyahs.isEmpty) {
      return Center(
        child: Text('No Quran data loaded.', style: TextStyle(color: themeText)),
      );
    }

    // Guard Index bounds
    if (_activeReaderAyahIndex > _loadedAyahs.length) {
      _activeReaderAyahIndex = _loadedAyahs.length;
    }
    if (_activeReaderAyahIndex < 1) {
      _activeReaderAyahIndex = 1;
    }

    final currentAyah = _loadedAyahs[_activeReaderAyahIndex - 1];
    final isBookmarked = _bookmarks.any((b) => b['surah'] == surah.name && b['ayah'] == '${currentAyah.number}');
    final isSurahMemorized = _memorizedSurahIds.contains(surah.id);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${surah.id}. ${surah.name}',
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: themeText),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: AppColors.coralOrange),
                    onPressed: () {
                      setState(() {
                        if (isBookmarked) {
                          _bookmarks.removeWhere((b) => b['surah'] == surah.name && b['ayah'] == '${currentAyah.number}');
                        } else {
                          _bookmarks.add({'surah': surah.name, 'ayah': '${currentAyah.number}', 'name': '${surah.name} Ayah ${currentAyah.number}'});
                        }
                        _saveState();
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.note_add_outlined, color: AppColors.midTeal),
                    onPressed: () {
                      _showAddReflectionDialog(surah.name, currentAyah.number);
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Memorization switch inside Quran Reader
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSurahMemorized ? AppColors.midTeal.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isSurahMemorized ? '✓ Memorized in Hifz Map' : 'Not marked as memorized',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: isSurahMemorized ? AppColors.midTeal : AppColors.placeholder),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (isSurahMemorized) {
                        _memorizedSurahIds.remove(surah.id);
                      } else {
                        _memorizedSurahIds.add(surah.id);
                      }
                      _saveState();
                    });
                  },
                  child: Text(
                    isSurahMemorized ? 'Mark Not Done' : 'Mark Memorized',
                    style: GoogleFonts.poppins(fontSize: 11.5, color: isSurahMemorized ? Colors.red : AppColors.midTeal, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Card(
                color: cardBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_activeReaderAyahIndex == 1 && surah.id != 9) ...[
                        Text(
                          'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.amiri(
                            fontSize: _arabicFontSize + 2,
                            fontWeight: FontWeight.bold,
                            color: AppColors.midTeal,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        currentAyah.arabic,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.amiri(
                          fontSize: _arabicFontSize,
                          fontWeight: FontWeight.bold,
                          height: 1.8,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Divider(height: 1),
                      const SizedBox(height: 16),

                      if (_showBanglaTranslation) ...[
                        Text(
                          'বাংলা অনুবাদ',
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.midTeal),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentAyah.banglaTranslation,
                          style: GoogleFonts.inter(fontSize: 13, height: 1.45, color: themeText),
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (_showEnglishTranslation) ...[
                        Text(
                          'English Translation',
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.midTeal),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentAyah.englishTranslation,
                          style: GoogleFonts.inter(fontSize: 13, height: 1.45, color: themeText),
                        ),
                        const SizedBox(height: 16),
                      ],

                      const Divider(height: 1),
                      const SizedBox(height: 16),

                      // Tafsir section — follows translation toggle state
                      if (_showBanglaTranslation && currentAyah.banglaExplanation.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.coralOrange.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.coralOrange.withValues(alpha: 0.20)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.coralOrange,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'তাফসির ইবনে কাসীর (আবু বকর জাকারিয়া)',
                                  style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                currentAyah.banglaExplanation,
                                style: GoogleFonts.inter(fontSize: 12.5, color: _isDarkMode ? Colors.white70 : AppColors.navyBlue.withValues(alpha: 0.82), height: 1.55),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      if (_showEnglishTranslation && currentAyah.englishExplanation.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.midTeal.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.midTeal.withValues(alpha: 0.20)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.midTeal,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Tafsir Ibn Kathir',
                                  style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                currentAyah.englishExplanation,
                                style: GoogleFonts.inter(fontSize: 12.5, color: _isDarkMode ? Colors.white70 : AppColors.navyBlue.withValues(alpha: 0.82), height: 1.55),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],

                      if (!_showBanglaTranslation && !_showEnglishTranslation)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Enable Bangla or English translation in Settings to see Tafsir.',
                            style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.placeholder, fontStyle: FontStyle.italic),
                          ),
                        ),

                      if (currentAyah.banglaExplanation.isEmpty && currentAyah.englishExplanation.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Tafsir not available for this verse in offline mode.',
                            style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.placeholder, fontStyle: FontStyle.italic),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: _activeReaderAyahIndex > 1
                    ? () => setState(() => _activeReaderAyahIndex--)
                    : null,
                child: Text('← Previous', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              GestureDetector(
                onTap: () => _showWheelPagePickerModal(context, cardBg, themeText),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.midTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.midTeal.withValues(alpha: 0.30)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.unfold_more_rounded, size: 16, color: AppColors.midTeal),
                      const SizedBox(width: 4),
                      Text(
                        'Ayah $_activeReaderAyahIndex / ${_loadedAyahs.length}',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.midTeal),
                      ),
                    ],
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navyBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  setState(() {
                    if (_activeReaderAyahIndex < _loadedAyahs.length) {
                      _activeReaderAyahIndex++;
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Completed Surah ${surah.name}!')),
                      );
                      return;
                    }
                    _continueSurahId = surah.id;
                    _continueAyah = _activeReaderAyahIndex;

                    final currentAyahObj = _loadedAyahs[_activeReaderAyahIndex - 1];
                    if (currentAyahObj.page != null) {
                      _continuePage = currentAyahObj.page!;
                    } else {
                      final startPage = _getSurahStartPage(surah.id);
                      final offsetPages = _calculatePagesCompleted(surah.id, _activeReaderAyahIndex);
                      _continuePage = (startPage + offsetPages.toInt()).clamp(1, 604);
                    }

                    final ayahKey = '${surah.id}_$_activeReaderAyahIndex';
                    final alreadyReadToday = _readAyahsToday.contains(ayahKey);
                    
                    if (!alreadyReadToday) {
                      _readAyahsToday.add(ayahKey);
                      _completedAyahsToday++;
                    }
                    
                    if (!_readAyahsAllTime.contains(ayahKey)) {
                      _readAyahsAllTime.add(ayahKey);
                      _khatmTotalJuzCompleted = ((_readAyahsAllTime.length / 6236.0) * 30).floor();
                      if (_khatmTotalJuzCompleted > 30) _khatmTotalJuzCompleted = 30;
                    }
                    _saveState();
                  });
                },
                child: Text(
                  _activeReaderAyahIndex == _loadedAyahs.length ? 'Finish' : 'Next Ayah →',
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddReflectionDialog(String surahName, int ayahNum) {
    final reflectionCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Reflections & Notes', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
          content: TextField(
            controller: reflectionCtrl,
            maxLines: 4,
            style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black),
            decoration: const InputDecoration(hintText: 'Share your personal spiritual reflection here...'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.placeholder)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.navyBlue),
              onPressed: () {
                if (reflectionCtrl.text.trim().isNotEmpty) {
                  setState(() {
                    _reflections.add({
                      'surah': surahName,
                      'ayah': '$ayahNum',
                      'note': reflectionCtrl.text.trim(),
                    });
                    _saveState();
                  });
                  Navigator.pop(ctx);
                }
              },
              child: Text('Save', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // VIEW 4: PROGRESS TAB VIEW WITH MULTI-OPTION DETAILS
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildProgressTabView(Color cardBg, Color themeText) {
    final catchupVal = _targetDailyAyahs - _completedAyahsToday;
    final progressMsg = catchupVal <= 0
        ? 'Great job! You have achieved today\'s target reading verses! 🌟'
        : 'You are $catchupVal verses behind today\'s reading target. Catch up now! 📖';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Text('Reading Progress Ring', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: themeText)),
          const SizedBox(height: 14),

          // Visual Progress Circle Summary Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 75,
                  height: 75,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: _targetDailyAyahs > 0 ? (_completedAyahsToday / _targetDailyAyahs).clamp(0.0, 1.0) : 0.0,
                        backgroundColor: Colors.grey.shade100,
                        color: AppColors.midTeal,
                        strokeWidth: 9,
                      ),
                      Center(
                        child: Text(
                          '${_targetDailyAyahs > 0 ? ((_completedAyahsToday / _targetDailyAyahs) * 100).toInt().clamp(0, 100) : 0}%',
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: themeText),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Today\'s Target Progress', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13.5, color: themeText)),
                      const SizedBox(height: 4),
                      Text(
                        progressMsg,
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.placeholder, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Detailed Stat Cards
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                _buildProgressStatRow('Current Juz', '$_khatmTotalJuzCompleted', Icons.book_rounded),
                const Divider(height: 16),
                _buildProgressStatRow('Current Page', '$_continuePage', Icons.find_in_page_rounded),
                const Divider(height: 16),
                _buildProgressStatRow('Completed %', '${((_khatmTotalJuzCompleted / 30.0) * 100).toInt()}%', Icons.done_all_rounded),
                const Divider(height: 16),
                _buildProgressStatRow('Streak Counter', '$_currentStreak Days', Icons.local_fire_department_rounded),
                const Divider(height: 16),
                _buildProgressStatRow('Reading Time', '0 Hours', Icons.hourglass_top_rounded),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildMoreCardItem(
            cardBg,
            Icons.analytics_rounded,
            AppColors.midTeal,
            'Weekly & Monthly Statistics',
            'View visual progression charts',
            () => setState(() {
              _bottomNavIndex = 4;
              _activeMoreSubView = 'stats';
            }),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.navyBlue,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, color: AppColors.coralOrange, size: 20),
                    const SizedBox(width: 8),
                    Text('Quran Khatm Planner', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Finish reading the entire Quran by configuring customized daily page goals.',
                  style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white70),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.midTeal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    _showKhatmPlannerBottomSheet();
                  },
                  child: Text('Configure Planner Plan', style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // VIEW 5: WAZIFA PAGE (HADITH VIRTUES SYSTEM IMPLEMENTED)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildWazifaTabView(Color cardBg, Color themeText) {
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          Container(
            color: cardBg,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: AppColors.midTeal,
              labelColor: _isDarkMode ? Colors.white : AppColors.navyBlue,
              unselectedLabelColor: AppColors.placeholder,
              tabs: [
                Tab(child: Text('ওযীফা শরীফ (Wazifa)', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12))),
                Tab(child: Text('সকাল (Morning)', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12))),
                Tab(child: Text('সন্ধ্যা (Evening)', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12))),
                Tab(child: Text('শোয়ার আমল (Sleep)', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12))),
                Tab(child: Text('সালাত শেষে (Salah)', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12))),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildHadithWazifaListTab(cardBg, themeText),
                _buildWazifaCheckList('Morning', cardBg, themeText),
                _buildWazifaCheckList('Evening', cardBg, themeText),
                _buildWazifaCheckList('Before Sleep', cardBg, themeText),
                _buildWazifaCheckList('After Salah', cardBg, themeText),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHadithWazifaListTab(Color cardBg, Color themeText) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _hadithWazifaList.length,
      itemBuilder: (ctx, idx) {
        final w = _hadithWazifaList[idx];
        final val = _completedHadithWazifas[w.title] ?? false;

        return Card(
          color: cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: Checkbox(
              value: val,
              activeColor: AppColors.midTeal,
              onChanged: (v) {
                setState(() {
                  _completedHadithWazifas[w.title] = v!;
                  _saveState();
                });
              },
            ),
            title: Text(w.title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: themeText)),
            subtitle: Text('Virtues: ${w.targetDay} • Count: ${w.recitationCount}', style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.placeholder)),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Divider(),
                    const SizedBox(height: 6),
                    if (_showBanglaTranslation) ...[
                      Text('ফজিলত ও গুরুত্ব (Virtues Bangla):', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                      Text(w.benefitBangla, style: GoogleFonts.inter(fontSize: 12, color: themeText, height: 1.35)),
                      const SizedBox(height: 8),
                    ],
                    if (_showEnglishTranslation) ...[
                      Text('Virtues (English):', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                      Text(w.benefitEnglish, style: GoogleFonts.inter(fontSize: 12, color: themeText, height: 1.35)),
                      const SizedBox(height: 8),
                    ],
                    Text('Hadith Reference:', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.placeholder)),
                    Text(w.hadithReference, style: GoogleFonts.inter(fontSize: 11, color: AppColors.placeholder, fontStyle: FontStyle.italic)),
                    
                    if (w.surahId != null) ...[
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          final targetSurah = _surahList.firstWhere(
                            (s) => s.id == w.surahId,
                            orElse: () => _surahList.first,
                          );
                          setState(() {
                            _activeReaderSurahId = w.surahId;
                            _activeReaderAyahIndex = 1;
                            _bottomNavIndex = 1;
                            _activeMoreSubView = null;
                          });
                          _loadSurahData(w.surahId!, targetSurah.totalAyahs);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navyBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.menu_book_rounded, size: 16, color: Colors.white),
                        label: Text(
                          'সূরাটি তিলাওয়াত করুন (Read Surah)',
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],

                    if (w.arabicText != null) ...[
                      const Divider(height: 24),
                      Text('আরবি (Arabic):', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isDarkMode ? const Color(0xFF2C2C2C) : AppColors.navyBlue.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SelectableText(
                          w.arabicText!,
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          style: GoogleFonts.amiri(
                            fontSize: 18,
                            height: 1.8,
                            color: _isDarkMode ? Colors.white : AppColors.navyBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],

                    if (_showBanglaTranslation && w.banglaPronunciation != null) ...[
                      const SizedBox(height: 12),
                      Text('উচ্চারণ (Bengali Pronunciation):', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                      const SizedBox(height: 4),
                      Text(w.banglaPronunciation!, style: GoogleFonts.inter(fontSize: 12.5, color: themeText, height: 1.45)),
                    ],

                    if (_showBanglaTranslation && w.banglaTranslation != null) ...[
                      const SizedBox(height: 12),
                      Text('অনুবাদ (Bengali Translation):', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                      const SizedBox(height: 4),
                      Text(w.banglaTranslation!, style: GoogleFonts.inter(fontSize: 12.5, color: themeText, height: 1.45)),
                    ],

                    if (_showBanglaTranslation && w.readingRules != null) ...[
                      const SizedBox(height: 12),
                      Text('আমলের নিয়ম (Instructions):', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.coralOrange)),
                      const SizedBox(height: 4),
                      Text(w.readingRules!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.placeholder, fontStyle: FontStyle.italic)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWazifaCheckList(String category, Color cardBg, Color themeText) {
    final list = _wazifaSupplications[category] ?? [];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (ctx, idx) {
          final wazifa = list[idx];
          final val = _completedWazifas['${category}_${wazifa.title}'] ?? false;

          // Check if there is any detailed content to expand
          final hasDetails = wazifa.arabicText != null ||
              wazifa.banglaPronunciation != null ||
              wazifa.banglaTranslation != null ||
              wazifa.readingRules != null ||
              wazifa.benefitBangla != null ||
              wazifa.benefitEnglish != null;

          return Card(
            color: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.only(bottom: 10),
            child: hasDetails
                ? ExpansionTile(
                    leading: Checkbox(
                      value: val,
                      activeColor: AppColors.midTeal,
                      onChanged: (v) {
                        setState(() {
                          _completedWazifas['${category}_${wazifa.title}'] = v!;
                          _saveState();
                        });
                      },
                    ),
                    title: Text(wazifa.title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: themeText)),
                    subtitle: Text('আমলের ফজিলত ও বিবরণ (Tap to expand)', style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.placeholder)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.coralOrange, size: 18),
                      onPressed: () {
                        setState(() {
                          _wazifaSupplications[category]?.removeAt(idx);
                          _completedWazifas.remove('${category}_${wazifa.title}');
                          _saveState();
                        });
                      },
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (wazifa.benefitBangla != null && _showBanglaTranslation) ...[
                              const Divider(),
                              const SizedBox(height: 6),
                              Text('ফজিলত ও গুরুত্ব (Virtues):', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                              Text(wazifa.benefitBangla!, style: GoogleFonts.inter(fontSize: 12, color: themeText, height: 1.35)),
                            ],
                            if (wazifa.benefitEnglish != null && _showEnglishTranslation) ...[
                              const Divider(),
                              const SizedBox(height: 6),
                              Text('Virtues (English):', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                              Text(wazifa.benefitEnglish!, style: GoogleFonts.inter(fontSize: 12, color: themeText, height: 1.35)),
                            ],
                            if (wazifa.arabicText != null) ...[
                              const Divider(),
                              const SizedBox(height: 6),
                              Text('আরবি (Arabic):', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _isDarkMode ? const Color(0xFF2C2C2C) : AppColors.navyBlue.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: SelectableText(
                                  wazifa.arabicText!,
                                  textAlign: TextAlign.right,
                                  textDirection: TextDirection.rtl,
                                  style: GoogleFonts.amiri(
                                    fontSize: 18,
                                    height: 1.8,
                                    color: _isDarkMode ? Colors.white : AppColors.navyBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                            if (wazifa.banglaPronunciation != null && _showBanglaTranslation) ...[
                              const SizedBox(height: 12),
                              Text('উচ্চারণ (Bengali Pronunciation):', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                              const SizedBox(height: 4),
                              Text(wazifa.banglaPronunciation!, style: GoogleFonts.inter(fontSize: 12.5, color: themeText, height: 1.45)),
                            ],
                            if (wazifa.banglaTranslation != null && _showBanglaTranslation) ...[
                              const SizedBox(height: 12),
                              Text('অনুবাদ (Bengali Translation):', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                              const SizedBox(height: 4),
                              Text(wazifa.banglaTranslation!, style: GoogleFonts.inter(fontSize: 12.5, color: themeText, height: 1.45)),
                            ],
                            if (wazifa.readingRules != null && _showBanglaTranslation) ...[
                              const SizedBox(height: 12),
                              Text('আমলের নিয়ম (Instructions):', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.coralOrange)),
                              const SizedBox(height: 4),
                              Text(wazifa.readingRules!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.placeholder, fontStyle: FontStyle.italic)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  )
                : ListTile(
                    leading: Checkbox(
                      value: val,
                      activeColor: AppColors.midTeal,
                      onChanged: (v) {
                        setState(() {
                          _completedWazifas['${category}_${wazifa.title}'] = v!;
                          _saveState();
                        });
                      },
                    ),
                    title: Text(wazifa.title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: themeText)),
                    subtitle: Text('Supplication Checklist entry', style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.placeholder)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.coralOrange, size: 18),
                      onPressed: () {
                        setState(() {
                          _wazifaSupplications[category]?.removeAt(idx);
                          _completedWazifas.remove('${category}_${wazifa.title}');
                          _saveState();
                        });
                      },
                    ),
                  ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: AppColors.navyBlue,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          _showAddWazifaDialog(category);
        },
      ),
    );
  }

  void _showAddWazifaDialog(String category) {
    final titleController = TextEditingController();
    final arabicController = TextEditingController();
    final pronunciationController = TextEditingController();
    final translationController = TextEditingController();
    final rulesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        final fieldColor = _isDarkMode ? Colors.white : Colors.black;
        final hintStyle = TextStyle(color: AppColors.placeholder.withValues(alpha: 0.7), fontSize: 13);
        final labelStyle = GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.midTeal);

        return AlertDialog(
          backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'নতুন আমল যোগ করুন (${category == 'Morning' ? 'সকাল' : category == 'Evening' ? 'সন্ধ্যা' : category == 'Before Sleep' ? 'ঘুমানোর সময়' : 'সালাত শেষে'})',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: _isDarkMode ? Colors.white : AppColors.navyBlue),
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('আমলের নাম / শিরোনাম (Title)*', style: labelStyle),
                  const SizedBox(height: 4),
                  TextField(
                    controller: titleController,
                    style: TextStyle(color: fieldColor),
                    decoration: InputDecoration(
                      hintText: 'উদা: সূরা কাফিরুন, দোয়ার নাম...',
                      hintStyle: hintStyle,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('আরবি টেক্সট (Arabic Text) [ঐচ্ছিক]', style: labelStyle),
                  const SizedBox(height: 4),
                  TextField(
                    controller: arabicController,
                    maxLines: 3,
                    style: TextStyle(color: fieldColor),
                    decoration: InputDecoration(
                      hintText: 'আরবি হরফ লিখুন...',
                      hintStyle: hintStyle,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('বাংলা উচ্চারণ (Pronunciation) [ঐচ্ছিক]', style: labelStyle),
                  const SizedBox(height: 4),
                  TextField(
                    controller: pronunciationController,
                    maxLines: 2,
                    style: TextStyle(color: fieldColor),
                    decoration: InputDecoration(
                      hintText: 'উচ্চারণ বাংলায় লিখুন...',
                      hintStyle: hintStyle,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('বাংলা অনুবাদ (Translation) [ঐচ্ছিক]', style: labelStyle),
                  const SizedBox(height: 4),
                  TextField(
                    controller: translationController,
                    maxLines: 3,
                    style: TextStyle(color: fieldColor),
                    decoration: InputDecoration(
                      hintText: 'অর্থ বাংলায় লিখুন...',
                      hintStyle: hintStyle,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('আমলের নিয়ম ও ফজিলত (Instructions) [ঐচ্ছিক]', style: labelStyle),
                  const SizedBox(height: 4),
                  TextField(
                    controller: rulesController,
                    maxLines: 2,
                    style: TextStyle(color: fieldColor),
                    decoration: InputDecoration(
                      hintText: 'উদা: সকালে ৩ বার, ফজিলত...',
                      hintStyle: hintStyle,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.placeholder)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navyBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isNotEmpty) {
                  setState(() {
                    final newWazifa = CustomWazifa(
                      title: title,
                      arabicText: arabicController.text.trim().isNotEmpty ? arabicController.text.trim() : null,
                      banglaPronunciation: pronunciationController.text.trim().isNotEmpty ? pronunciationController.text.trim() : null,
                      banglaTranslation: translationController.text.trim().isNotEmpty ? translationController.text.trim() : null,
                      readingRules: rulesController.text.trim().isNotEmpty ? rulesController.text.trim() : null,
                    );
                    _wazifaSupplications[category]?.add(newWazifa);
                    _saveState();
                  });
                  Navigator.pop(ctx);
                }
              },
              child: Text('Add', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // VIEW 6: MORE TAB OVERVIEW & FULL PAGE NAVIGATION
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildMoreTabView(Color cardBg, Color themeText) {
    if (_activeMoreSubView != null) {
      return _buildMoreSubViewContent(cardBg, themeText);
    }

    return GridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 2,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      children: [
        _buildMoreGridItem(cardBg, Icons.favorite_rounded, AppColors.coralOrange, 'Hifz Quran Map', 'Track memorization progression', () {
          setState(() => _activeMoreSubView = 'hifz');
        }),
        _buildMoreGridItem(cardBg, Icons.bookmark_rounded, AppColors.midTeal, 'Bookmarks', 'Saved Ayahs and Tafsir notes', () {
          setState(() => _activeMoreSubView = 'bookmarks');
        }),
        _buildMoreGridItem(cardBg, Icons.wb_sunny_rounded, AppColors.midTeal, 'Daily Ayah', 'Spiritual verses of the day', () {
          setState(() => _activeMoreSubView = 'daily_ayah');
        }),
        _buildMoreGridItem(cardBg, Icons.bar_chart_rounded, AppColors.coralOrange, 'Statistics', 'Longest streaks & totals', () {
          setState(() => _activeMoreSubView = 'stats');
        }),
        _buildMoreGridItem(cardBg, Icons.settings_rounded, AppColors.navyBlue, 'Settings', 'Adjust fonts and dark theme', () {
          setState(() => _activeMoreSubView = 'settings');
        }),
      ],
    );
  }

  Widget _buildMoreSubViewContent(Color cardBg, Color themeText) {
    Widget pageBody;
    String headerTitle = '';

    switch (_activeMoreSubView) {
      case 'hifz':
        headerTitle = 'Hifz Quran Map';
        pageBody = _buildHifzFullPage(cardBg, themeText);
        break;
      case 'bookmarks':
        headerTitle = 'Bookmarks & Reflections';
        pageBody = _buildBookmarksFullPage(cardBg, themeText);
        break;
      case 'daily_ayah':
        headerTitle = 'Today\'s Daily Ayah';
        pageBody = _buildDailyAyahFullPage(cardBg, themeText);
        break;
      case 'stats':
        headerTitle = 'Statistics';
        pageBody = _buildStatsFullPage(cardBg, themeText);
        break;
      case 'settings':
        headerTitle = 'Settings';
        pageBody = _buildSettingsFullPage(cardBg, themeText);
        break;
      default:
        pageBody = const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _activeMoreSubView = null),
                icon: const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.midTeal),
                label: Text('Back to More', style: GoogleFonts.poppins(color: AppColors.midTeal, fontWeight: FontWeight.bold, fontSize: 12.5)),
              ),
              Text(headerTitle, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: themeText)),
            ],
          ),
        ),
        Expanded(child: pageBody),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // MORE SUB-PAGES OVERRIDES (HIFZ MAP NAVIGATION & PREMIUM STATS OVERHAUL)
  // ─────────────────────────────────────────────────────────────────────────────

  // 1. HIFZ QURAN MAP WITH CARD CLICKS DIRECT READER LAUNCH
  Widget _buildHifzFullPage(Color cardBg, Color themeText) {
    final completed = _memorizedSurahIds.length;
    final remaining = 114 - completed;
    final percentage = completed > 0 ? ((completed / 114.0) * 100).toInt() : 0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.navyBlue, Color(0xFF1D3557)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Quran Memorization Status', style: GoogleFonts.inter(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text('$completed Completed • $remaining Remaining', style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Text('$percentage%', style: GoogleFonts.poppins(color: AppColors.coralOrange, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: completed / 114.0,
                    minHeight: 8,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation(AppColors.coralOrange),
                  ),
                ),
              ],
            ),
          ),
        ),

        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: _surahList.length,
            itemBuilder: (ctx, idx) {
              final surah = _surahList[idx];
              final isMemorized = _memorizedSurahIds.contains(surah.id);

              return Card(
                color: cardBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: isMemorized ? AppColors.midTeal.withValues(alpha: 0.15) : Colors.grey.shade100,
                        child: Text('${surah.id}', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: isMemorized ? AppColors.midTeal : AppColors.placeholder)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            // Tapping Card routes directly to the Quran Reader view!
                            setState(() {
                              _activeReaderSurahId = surah.id;
                              _activeReaderAyahIndex = 1;
                              _bottomNavIndex = 1; // Quran tab
                              _activeMoreSubView = null;
                            });
                            _loadSurahData(surah.id, surah.totalAyahs);
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(surah.name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: themeText)),
                              Text('${surah.totalAyahs} Ayahs • ${surah.type} • Tap to read', style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.placeholder)),
                            ],
                          ),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isMemorized ? AppColors.midTeal : AppColors.placeholder.withValues(alpha: 0.2),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          setState(() {
                            if (isMemorized) {
                              _memorizedSurahIds.remove(surah.id);
                            } else {
                              _memorizedSurahIds.add(surah.id);
                            }
                            _saveState();
                          });
                        },
                        child: Text(
                          isMemorized ? 'Memorized' : 'Mark Done',
                          style: GoogleFonts.poppins(color: isMemorized ? Colors.white : themeText, fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // 2. BOOKMARKS & REFLECTIONS
  Widget _buildBookmarksFullPage(Color cardBg, Color themeText) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            indicatorColor: AppColors.midTeal,
            labelColor: AppColors.navyBlue,
            unselectedLabelColor: AppColors.placeholder,
            tabs: const [
              Tab(child: Text('Bookmarks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
              Tab(child: Text('Notes & Reflections', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _bookmarks.isEmpty
                    ? Center(
                        child: Text(
                          'No Bookmarks saved yet.',
                          style: GoogleFonts.poppins(color: AppColors.placeholder, fontSize: 12.5),
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _bookmarks.length,
                        itemBuilder: (ctx, idx) {
                          final item = _bookmarks[idx];
                          return Card(
                            color: cardBg,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.bookmark_rounded, color: AppColors.coralOrange),
                              title: Text(item['name']!, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text('Tap to open in reader', style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.placeholder)),
                              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.placeholder),
                              onTap: () {
                                final targetSurah = _surahList.firstWhere((e) => e.name == item['surah'], orElse: () => _surahList[0]);
                                setState(() {
                                  _activeReaderSurahId = targetSurah.id;
                                  _activeReaderAyahIndex = int.tryParse(item['ayah']!) ?? 1;
                                  _bottomNavIndex = 1;
                                  _activeMoreSubView = null;
                                });
                                _loadSurahData(targetSurah.id, targetSurah.totalAyahs);
                              },
                            ),
                          );
                        },
                      ),
                _reflections.isEmpty
                    ? Center(
                        child: Text(
                          'No Reflections recorded yet.',
                          style: GoogleFonts.poppins(color: AppColors.placeholder, fontSize: 12.5),
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _reflections.length,
                        itemBuilder: (ctx, idx) {
                          final item = _reflections[idx];
                          return Card(
                            color: cardBg,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.sticky_note_2_outlined, color: AppColors.midTeal),
                              title: Text('${item['surah']} [Ayah ${item['ayah']}]', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(item['note']!, style: GoogleFonts.inter(fontSize: 11.5, color: themeText)),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppColors.coralOrange, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _reflections.removeAt(idx);
                                    _saveState();
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 3. DAILY AYAH
  Widget _buildDailyAyahFullPage(Color cardBg, Color themeText) {
    final reflectionCtrl = TextEditingController();

    // Use current dynamic verse
    final verseIndex = DateTime.now().day % _dailyVersesDb.length;
    final dailyVerse = _dailyVersesDb[verseIndex];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.navyBlue, Color(0xFF1D3557)]),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Text(
                  dailyVerse.arabic,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.amiri(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold, height: 1.6),
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white30),
                const SizedBox(height: 14),
                Text(
                  'Bangla: ${dailyVerse.bangla}',
                  style: GoogleFonts.inter(fontSize: 13.5, color: Colors.white, height: 1.45),
                ),
                const SizedBox(height: 8),
                Text(
                  'English: ${dailyVerse.english}',
                  style: GoogleFonts.inter(fontSize: 13.5, color: Colors.white70, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Card(
            color: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Spiritual Explanation (Tafsir) • ${dailyVerse.reference}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.coralOrange)),
                  const SizedBox(height: 8),
                  Text(
                    dailyVerse.explanation,
                    style: GoogleFonts.inter(fontSize: 12.5, height: 1.45, color: themeText),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          Card(
            color: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Journal Your Reflection', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reflectionCtrl,
                    maxLines: 3,
                    style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black),
                    decoration: const InputDecoration(hintText: 'What did you learn from this ayah today?'),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.navyBlue),
                    onPressed: () {
                      if (reflectionCtrl.text.trim().isNotEmpty) {
                        setState(() {
                          _reflections.add({
                            'surah': dailyVerse.reference.split(' ')[0],
                            'ayah': dailyVerse.reference.split('(').last.replaceAll(')', ''),
                            'note': reflectionCtrl.text.trim(),
                          });
                          _saveState();
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Reflection journal saved!')),
                        );
                        reflectionCtrl.clear();
                      }
                    },
                    child: Text('Save Reflection', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 4. OVERHAULED, TIDY, AND BEAUTIFUL STATISTICS SCREEN
  Widget _buildStatsFullPage(Color cardBg, Color themeText) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Graphic Activity Dashboard Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
              border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Reading Consistency', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.midTeal)),
                    Text('Weekly Pages', style: GoogleFonts.inter(fontSize: 11, color: AppColors.placeholder)),
                  ],
                ),
                const SizedBox(height: 20),

                // Beautiful custom visual bar chart using styled container columns
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildStatsBarItem('Mon', 4, AppColors.midTeal),
                    _buildStatsBarItem('Tue', 7, AppColors.coralOrange),
                    _buildStatsBarItem('Wed', 5, AppColors.midTeal),
                    _buildStatsBarItem('Thu', 2, AppColors.placeholder.withValues(alpha: 0.4)),
                    _buildStatsBarItem('Fri', 8, AppColors.navyBlue),
                    _buildStatsBarItem('Sat', 5, AppColors.midTeal),
                    _buildStatsBarItem('Sun', 3, AppColors.midTeal),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Activity & Milestones Category cards
          Text('Activity Overview', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: themeText)),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  cardBg,
                  Icons.layers_rounded,
                  AppColors.midTeal,
                  'Ayahs Today',
                  '$_completedAyahsToday Verses',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  cardBg,
                  Icons.local_fire_department_rounded,
                  AppColors.coralOrange,
                  'Active Streak',
                  '$_currentStreak Days',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  cardBg,
                  Icons.menu_book_rounded,
                  AppColors.navyBlue,
                  'Juz Read',
                  '$_khatmTotalJuzCompleted / 30 Juz',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  cardBg,
                  Icons.star_half_rounded,
                  AppColors.midTeal,
                  'Longest Streak',
                  '$_longestStreak Days',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Quran Completion Milestone
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('General Khatm Milestones', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: themeText)),
                    Text('${((_khatmTotalJuzCompleted / 30.0) * 100).toInt()}%', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _khatmTotalJuzCompleted / 30.0,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade100,
                    valueColor: const AlwaysStoppedAnimation(AppColors.midTeal),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatsBarItem(String day, double heightFactor, Color color) {
    return Column(
      children: [
        Text('${(heightFactor * 2).toInt()}', style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Container(
          width: 24,
          height: heightFactor * 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 6),
        Text(day, style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.placeholder)),
      ],
    );
  }

  Widget _buildMetricTile(Color cardBg, IconData icon, Color iconColor, String title, String val) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 10),
          Text(title, style: GoogleFonts.inter(fontSize: 11, color: AppColors.placeholder)),
          const SizedBox(height: 2),
          Text(val, style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // 5. SETTINGS
  Widget _buildSettingsFullPage(Color cardBg, Color themeText) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        color: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Arabic Font Size', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => setState(() => _arabicFontSize = (_arabicFontSize - 2).clamp(16.0, 36.0))),
                      Text('${_arabicFontSize.toInt()}'),
                      IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => setState(() => _arabicFontSize = (_arabicFontSize + 2).clamp(16.0, 36.0))),
                    ],
                  ),
                ],
              ),
              const Divider(height: 16),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Bangla Translation', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold)),
                value: _showBanglaTranslation,
                activeTrackColor: AppColors.midTeal.withValues(alpha: 0.5),
                activeThumbColor: AppColors.midTeal,
                onChanged: (v) => setState(() => _showBanglaTranslation = v),
              ),
              const Divider(height: 16),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('English Translation', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold)),
                value: _showEnglishTranslation,
                activeTrackColor: AppColors.midTeal.withValues(alpha: 0.5),
                activeThumbColor: AppColors.midTeal,
                onChanged: (v) => setState(() => _showEnglishTranslation = v),
              ),
              const Divider(height: 16),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Dark Reading Theme', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold)),
                value: _isDarkMode,
                activeTrackColor: AppColors.coralOrange.withValues(alpha: 0.5),
                activeThumbColor: AppColors.coralOrange,
                onChanged: (v) async {
                  setState(() => _isDarkMode = v);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('is_dark_mode', v);
                                     },
                              ),             
              const Divider(height: 16),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Daily Reading Reminder', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold)),
                value: _readingReminderEnabled,
                activeTrackColor: AppColors.midTeal.withValues(alpha: 0.5),
                activeThumbColor: AppColors.midTeal,
                onChanged: (v) => setState(() => _readingReminderEnabled = v),
              ),
              const Divider(height: 16),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.refresh_rounded, color: AppColors.coralOrange),
                title: Text('Reset Progress & Data', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.coralOrange)),
                subtitle: Text('Clear reading metrics, streak, and reset to zero', style: GoogleFonts.inter(fontSize: 10, color: AppColors.placeholder)),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('Reset All Data?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      content: Text('This will reset your streaks, completed pages, and Hifz logs back to zero.', style: GoogleFonts.inter(fontSize: 12.5)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.clear();
                            setState(() {
                              _currentStreak = 0;
                              _longestStreak = 0;
                              _completedAyahsToday = 0;
                              _targetDailyAyahs = 208;
                              _khatmTotalJuzCompleted = 0;
                              _continueSurahId = 1;
                              _continuePage = 1;
                              _continueAyah = 1;
                              _readAyahsToday.clear();
                              _readAyahsAllTime.clear();
                              _memorizedSurahIds.clear();
                              _bookmarks.clear();
                              _reflections.clear();
                              _completedWazifas.clear();
                              _completedHadithWazifas.clear();
                            });
                            await _saveState();
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All data has been reset to zero.')));
                          },
                          child: const Text('Reset', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressStatRow(String label, String value, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.midTeal, size: 18),
            const SizedBox(width: 10),
            Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
        Text(value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMoreCardItem(Color cardBg, IconData icon, Color iconColor, String title, String desc, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  Text(desc, style: GoogleFonts.inter(fontSize: 10, color: AppColors.placeholder)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.placeholder),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreGridItem(Color cardBg, IconData icon, Color iconColor, String title, String desc, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(height: 10),
            Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13.5)),
            const SizedBox(height: 2),
            Text(desc, style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.placeholder), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  void _showKhatmPlannerBottomSheet() {
    int planDays = _khatmTargetDays;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final dailyRecAyahs = (6236 / planDays).ceil();
            final dailyRecJuz = (30.0 / planDays);

            return Container(
              decoration: BoxDecoration(
                color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
                  ),
                  const SizedBox(height: 16),
                  Text('Khatm Planner Plan', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text('Choose target timeframe:', style: GoogleFonts.inter(fontSize: 12, color: AppColors.placeholder)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [15, 30, 60].map((days) {
                      final isSelected = planDays == days;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setSheetState(() => planDays = days),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.navyBlue : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('$days Days', textAlign: TextAlign.center, style: GoogleFonts.poppins(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.midTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text('Resulting Reading Requirement:', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.placeholder, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text('$dailyRecAyahs Ayahs Daily', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                        Text('or roughly ${dailyRecJuz.toStringAsFixed(2)} Juz Daily', style: GoogleFonts.inter(fontSize: 12, color: AppColors.placeholder)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.navyBlue, padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: () {
                      setState(() {
                        _khatmTargetDays = planDays;
                        _targetDailyAyahs = dailyRecAyahs;
                        _khatmEstimatedCompletion = DateFormat('dd MMMM yyyy').format(DateTime.now().add(Duration(days: planDays)));
                        _saveState();
                      });
                      Navigator.pop(context);
                    },
                    child: Text('Start Plan', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatTile(String label, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.placeholder)),
        Text(val, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REAL OFFLINE VERSES DICTIONARY
// ─────────────────────────────────────────────────────────────────────────────
final Map<int, List<AyahContent>> _realQuranText = {
  1: [
    const AyahContent(
      number: 1,
      arabic: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
      banglaTranslation: 'পরম করুণাময় ও অসীম দয়ালু আল্লাহর নামে শুরু করছি।',
      englishTranslation: 'In the name of Allah, the Entirely Merciful, the Especially Merciful.',
      banglaExplanation: 'এই আয়াতটি আল্লাহর অসীম দয়া ও করুণা স্মরণ করায়। যেকোনো শুভ কাজের শুরুতে তাসমিয়া পাঠ করা সুন্নাত।',
      englishExplanation: 'This ayah reminds us of Allah\'s infinite mercy. It is sunnah to begin any good deed with Basmalah.',
    ),
    const AyahContent(
      number: 2,
      arabic: 'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ',
      banglaTranslation: 'যাবতীয় প্রশংসা আল্লাহরই, যিনি জগৎসমূহের প্রতিপালক।',
      englishTranslation: 'All praise is due to Allah, Lord of the worlds.',
      banglaExplanation: 'সৃষ্টিজগতের সব নিয়ামত ও সৃষ্টির জন্য প্রশংসা একমাত্র আল্লাহর প্রাপ্য।',
      englishExplanation: 'All gratitude and praise belong strictly to Allah, the sustainer and creator of everything.',
    ),
    const AyahContent(
      number: 3,
      arabic: 'الرَّحْمَٰنِ الرَّحِيمِ',
      banglaTranslation: 'যিনি পরম করুণাময় ও অসীম দয়ালু।',
      englishTranslation: 'The Entirely Merciful, the Especially Merciful.',
      banglaExplanation: 'তিনি ইহকাল ও পরকালে সবার প্রতি দয়াশীল।',
      englishExplanation: 'His mercy encompasses all creation in this world and the hereafter.',
    ),
    const AyahContent(
      number: 4,
      arabic: 'مَالِكِ يَوْمِ الدِّينِ',
      banglaTranslation: 'যিনি বিচার দিবসের মালিক।',
      englishTranslation: 'Sovereign of the Day of Recompense.',
      banglaExplanation: 'কেয়ামত দিবসের চূড়ান্ত ফয়সালার মালিক একমাত্র আল্লাহ তায়ালা।',
      englishExplanation: 'Allah is the absolute master and judge of the Day of Judgment.',
    ),
    const AyahContent(
      number: 5,
      arabic: 'إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ',
      banglaTranslation: 'আপনারই আমরা এবাদত করি এবং আপনারই সাহায্য প্রার্থনা করি।',
      englishTranslation: 'It is You we worship and You we ask for help.',
      banglaExplanation: 'একমাত্র আল্লাহর দাসত্ব স্বীকার এবং কেবল তাঁর কাছেই সাহায্য চাওয়ার নির্দেশ।',
      englishExplanation: 'Shows that we worship only Allah and seek absolute reliance from Him alone.',
    ),
    const AyahContent(
      number: 6,
      arabic: 'اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ',
      banglaTranslation: 'আমাদের সরল পথ প্রদর্শন করুন।',
      englishTranslation: 'Guide us to the straight path.',
      banglaExplanation: 'হিদায়াত ও সঠিক দ্বীনের ওপর অবিচল থাকার জন্য প্রার্থনা।',
      englishExplanation: 'Spiritual prayer asking Allah for ultimate guidance and righteousness.',
    ),
    const AyahContent(
      number: 7,
      arabic: 'صِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ الْمَغْضُوبِ عَلَيْهِمْ وَلَا الضَّالِّينَ',
      banglaTranslation: 'তাদের পথ, যাদের আপনি নিয়ামত দান করেছেন। অভিশপ্ত ও পথভ্রষ্টদের পথ নয়।',
      englishTranslation: 'The path of those upon whom You have bestowed favor, not of those who have evoked [Your] anger or of those who are astray.',
      banglaExplanation: 'নবী-রাসুল ও সালিহিনদের সরল পথ অনুসরণের তৌফিক কামনার আবেদন।',
      englishExplanation: 'A prayer to be placed among the righteous, avoiding anger and deviation.',
    ),
  ],
  103: [
    const AyahContent(
      number: 1,
      arabic: 'وَالْعَصْرِ',
      banglaTranslation: 'সময়ের শপথ,',
      englishTranslation: 'By time,',
      banglaExplanation: 'সময়ের দ্রুত অতিবাহিত হওয়া মানুষের জীবনে অত্যন্ত গুরুত্বপূর্ণ বিষয়। আল্লাহ সময়ের কসম খেয়েছেন।',
      englishExplanation: 'Allah swears by the passage of time to emphasize its critical importance in human life.',
    ),
    const AyahContent(
      number: 2,
      arabic: 'إِنَّ الْإِنْسَانَ لَفِي خُسْرٍ',
      banglaTranslation: 'নিশ্চয়ই মানুষ ক্ষতিগ্রস্ততায় নিমজ্জিত।',
      englishTranslation: 'Indeed, mankind is in loss,',
      banglaExplanation: 'অধিকাংশ মানুষই তাদের মূল্যবান সময়কে অবহেলায় কাটিয়ে ক্ষতিগ্রস্ততায় অবস্থান করছে।',
      englishExplanation: 'Without conscious spiritual effort, humanity naturally drifts toward moral and ultimate loss.',
    ),
    const AyahContent(
      number: 3,
      arabic: 'إِلَّا الَّذِينَ آمَنُوا وَعَمِلُوا الصَّالِحَاتِ وَتَوَاصَوْا بِالْحَقِّ وَتَوَاصَوْا بِالصَّبْرِ',
      banglaTranslation: 'কিন্তু তারা ব্যতীত, যারা ঈমান এনেছে, সৎকাজ করেছে, পরস্পরকে সত্যের উপদেশ দিয়েছে এবং ধৈর্যের উপদেশ দিয়েছে।',
      englishTranslation: 'Except for those who have believed and done righteous deeds and advised each other to truth and advised each other to patience.',
      banglaExplanation: 'ক্ষতি থেকে বাঁচার ৪টি উপায়: ঈমান, নেক আমল, সত্যের দাওয়াত ও ধৈর্যের উপদেশ দেওয়া।',
      englishExplanation: 'The 4 conditions for success: Faith, good deeds, inviting to truth, and encouraging perseverance.',
    ),
  ],
  112: [
    const AyahContent(
      number: 1,
      arabic: 'قُلْ هُوَ اللَّهُ أَحَدٌ',
      banglaTranslation: 'বলুন, তিনিই আল্লাহ, একক-অদ্বিতীয়।',
      englishTranslation: 'Say, "He is Allah, [who is] One,',
      banglaExplanation: 'আল্লাহ এক ও অদ্বিতীয়, তাঁর কোনো শরিক নেই। তাওহীদের মূল স্তম্ভ।',
      englishExplanation: 'Establishes absolute monotheism (Tawhid). Allah is singular in His essence.',
    ),
    const AyahContent(
      number: 2,
      arabic: 'اللَّهُ الصَّمَدُ',
      banglaTranslation: 'আল্লাহ মুখাপেক্ষীহীন, সবাই তাঁর মুখাপেক্ষী।',
      englishTranslation: 'Allah, the Eternal Refuge.',
      banglaExplanation: 'আল্লাহ কারও মুখাপেক্ষী নন, সমগ্র সৃষ্টিজগৎ তাঁর করুণার ভিখারী।',
      englishExplanation: 'Allah is completely self-sufficient while all creation relies on Him.',
    ),
    const AyahContent(
      number: 3,
      arabic: 'لَمْ يَلِدْ وَلَمْ يُولَدْ',
      banglaTranslation: 'তিনি কাউকে জন্ম দেননি এবং জন্ম নেনওনি।',
      englishTranslation: 'He neither begets nor is born,',
      banglaExplanation: 'আল্লাহর কোনো সন্তান বা পিতা-মাতা নেই। তিনি সমস্ত সৃষ্টিগত দুর্বলতা থেকে পবিত্র।',
      englishExplanation: 'Rejects all concepts of divine lineage or ancestry.',
    ),
    const AyahContent(
      number: 4,
      arabic: 'وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ',
      banglaTranslation: 'এবং তাঁর সমকক্ষ কেউ নেই।',
      englishTranslation: 'And there is none co-equal or comparable to Him."',
      banglaExplanation: 'গুণাবলীতে ও ক্ষমতায় আল্লাহর সমকক্ষ কেউ হতে পারে না।',
      englishExplanation: 'There is nothing comparable in authority or essence to Allah.',
    ),
  ],
};
