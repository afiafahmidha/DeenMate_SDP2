import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final String banglaPronunciation;
  final String englishPronunciation;
  final String banglaTranslation;
  final String englishTranslation;
  final String banglaExplanation;
  final String englishExplanation;
  final int? page;

  const AyahContent({
    required this.number,
    required this.arabic,
    this.banglaPronunciation = '',
    this.englishPronunciation = '',
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
  final String benefitEnglish;
  final String hadithReference;
  final String targetDay;
  final int? surahId;
  final String? arabicText;
  final String? englishPronunciation;
  final String? englishTranslation;
  final String? readingRules;

  const HadithWazifa({
    required this.title,
    required this.recitationCount,
    required this.benefitEnglish,
    required this.hadithReference,
    required this.targetDay,
    this.surahId,
    this.arabicText,
    this.englishPronunciation,
    this.englishTranslation,
    this.readingRules,
  });
}

class CustomWazifa {
  final String title;
  final String? benefitEnglish;
  final String? arabicText;
  final String? englishPronunciation;
  final String? englishTranslation;
  final String? readingRules;

  CustomWazifa({
    required this.title,
    this.benefitEnglish,
    this.arabicText,
    this.englishPronunciation,
    this.englishTranslation,
    this.readingRules,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'benefitEnglish': benefitEnglish,
    'arabicText': arabicText,
    'englishPronunciation': englishPronunciation,
    'englishTranslation': englishTranslation,
    'readingRules': readingRules,
  };

  factory CustomWazifa.fromJson(Map<String, dynamic> json) => CustomWazifa(
    title: json['title'] as String,
    benefitEnglish: (json['benefitEnglish'] ?? json['benefitBangla']) as String?,
    arabicText: json['arabicText'] as String?,
    englishPronunciation: (json['englishPronunciation'] ?? json['banglaPronunciation']) as String?,
    englishTranslation: (json['englishTranslation'] ?? json['banglaTranslation']) as String?,
    readingRules: json['readingRules'] as String?,
  );
}

class AuthenticDuaItem {
  final String title;
  final String arabicText;
  final String englishPronunciation;
  final String englishTranslation;
  final String hadithReference;
  final String benefitEnglish;
  final String readingRules;
  final String defaultCategory;
  final List<String> tags;

  const AuthenticDuaItem({
    required this.title,
    required this.arabicText,
    required this.englishPronunciation,
    required this.englishTranslation,
    required this.hadithReference,
    required this.benefitEnglish,
    required this.readingRules,
    required this.defaultCategory,
    required this.tags,
  });

  CustomWazifa toCustomWazifa() {
    return CustomWazifa(
      title: title,
      arabicText: arabicText,
      englishPronunciation: englishPronunciation,
      englishTranslation: englishTranslation,
      benefitEnglish: '$benefitEnglish ($hadithReference)',
      readingRules: readingRules,
    );
  }
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
  // User profile name
  String _userName = 'User';
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
    SurahInfo(10, 'Yunus', 'Yunus', 109, 'Makki', 11),
    SurahInfo(11, 'Hud', 'Hud', 123, 'Makki', 11),
    SurahInfo(12, 'Yusuf', 'Yusuf', 111, 'Makki', 12),
    SurahInfo(13, 'Ar-Ra\'d', 'The Thunder', 43, 'Madani', 13),
    SurahInfo(14, 'Ibrahim', 'Ibrahim', 52, 'Makki', 13),
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
    HadithWazifa(
      title: "Surah Al-Kahf (Friday Sunnah)",
      recitationCount: "1 Time / Verses 1-10",
      benefitEnglish: "Light between two Fridays and protection against the trial of Dajjal (Anti-Christ).",
      hadithReference: "Sahih Muslim (809), Al-Hakim (2/368)",
      targetDay: "Friday (Jumu'ah)",
      surahId: 18,
      readingRules: "Recite on Friday between Thursday Maghrib and Friday Maghrib. Tap button below to open in Quran Reader.",
    ),
    HadithWazifa(
      title: "Surah Al-Mulk (Night Sunnah)",
      recitationCount: "1 Time (30 Verses)",
      benefitEnglish: "Intercedes for its reciter until he is forgiven and protects against the punishment of the grave.",
      hadithReference: "Sunan at-Tirmidhi (2891), Sunan Abu Dawud (1400)",
      targetDay: "Every Night (Bedtime)",
      surahId: 67,
      readingRules: "Recite every night before sleeping. Tap button below to open in Quran Reader.",
    ),
    HadithWazifa(
      title: "Surah As-Sajdah (Night Sunnah)",
      recitationCount: "1 Time (30 Verses)",
      benefitEnglish: "The Prophet (ﷺ) would never sleep at night until he recited Surah As-Sajdah and Surah Al-Mulk.",
      hadithReference: "Sunan at-Tirmidhi (2892), Musnad Ahmad",
      targetDay: "Every Night",
      surahId: 32,
      readingRules: "Recite before going to sleep at night. Tap button below to open in Quran Reader.",
    ),
    HadithWazifa(
      title: "Ayatul Kursi (Verse of the Throne)",
      recitationCount: "1 Time after each Prayer & Bedtime",
      benefitEnglish: "Nothing stands between the reciter and entering Paradise except death. Guarantees divine protection from Shaytan.",
      hadithReference: "Sunan an-Nasa'i Al-Kubra (9928), Sahih al-Bukhari",
      targetDay: "Daily (After Salah & Sleep)",
      surahId: 2,
      arabicText: "اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَّهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَن ذَا الَّذِي يَشْفَعُ عِندَهُ إِلَّا بِإِذْنِهِ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ",
      englishPronunciation: "Allahu la ilaha illa Huwal-Hayyul-Qayyum. La ta'khudhuhu sinatuw-wa la nawm. Lahu ma fis-samawati wa ma fil-ard. Man dhal-lazi yashfa'u 'indahu illa bi-idhnih. Ya'lamu ma bayna aydihim wa ma khalfahum, wa la yuhituna bi-shay'im-min 'ilmihi illa bima sha'. Wasi'a Kursiyyuhus-samawati wal-ard, wa la ya'uduhu hifzuhuma, wa Huwal-'Aliyyul-'Azim.",
      englishTranslation: "Allah! There is no deity except Him, the Ever-Living, the Sustainer of all existence. Neither drowsiness overtakes Him nor sleep. To Him belongs whatever is in the heavens and whatever is on the earth. Who is it that can intercede with Him except by His permission? He knows what is before them and what will be after them, and they encompass not a thing of His knowledge except for what He wills. His Kursi extends over the heavens and the earth, and their preservation tires Him not. And He is the Most High, the Most Great.",
      readingRules: "Recite after every obligatory prayer, morning, evening, and bedtime.",
    ),
    HadithWazifa(
      title: "The Three Quls (Al-Ikhlas, Al-Falaq, An-Nas)",
      recitationCount: "3 Times Morning & Evening / 1 Time After Salah",
      benefitEnglish: "Sufficient for protection against all harms, evil eye, black magic, and whispers.",
      hadithReference: "Sunan at-Tirmidhi (3575), Sunan Abu Dawud (5082)",
      targetDay: "Daily (Morning, Evening, Sleep)",
      arabicText: "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ ۝ قُلْ هُوَ اللَّهُ أَحَدٌ ۝ اللَّهُ الصَّمَدُ ۝ لَمْ يَلِدْ وَلَمْ يُولَدْ ۝ وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ\n\nبِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ ۝ قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ ۝ مِن شَرِّ مَا خَلَقَ ۝ وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ ۝ وَمِن شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ ۝ وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ\n\nبِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ ۝ قُلْ أَعُوذُ بِرَبِّ النَّاسِ ۝ مَلِكِ النَّاسِ ۝ إِلَٰهِ النَّاسِ ۝ مِن شَرِّ الْوَسْوَاسِ الْخَنَّاسِ ۝ الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ ۝ مِنَ الْجِنَّةِ وَالنَّاسِ",
      englishPronunciation: "1. Al-Ikhlas: Bismillahir-Rahmanir-Rahim. Qul Huwal-Lahu Ahad. Allahus-Samad. Lam yalid wa lam yulad. Wa lam yakul-lahu kufuwan ahad.\n\n2. Al-Falaq: Bismillahir-Rahmanir-Rahim. Qul a'udhu bi-Rabbil-falaq. Min sharri ma khalaq. Wa min sharri ghasiqin idha waqab. Wa min sharrin-naffathati fil-'uqad. Wa min sharri hasidin idha hasad.\n\n3. An-Nas: Bismillahir-Rahmanir-Rahim. Qul a'udhu bi-Rabbin-nas. Malikin-nas. Ilahin-nas. Min sharril-waswasil-khannas. Allazi yuwaswisu fi sudurin-nas. Minal-jinnati wan-nas.",
      englishTranslation: "1. Al-Ikhlas: In the name of Allah, the Entirely Merciful, the Especially Merciful. Say: He is Allah, [who is] One. Allah, the Eternal Refuge. He neither begets nor is born. Nor is there to Him any equivalent.\n\n2. Al-Falaq: Say: I seek refuge in the Lord of daybreak from the evil of that which He created, and from the evil of darkness when it settles, and from the evil of the blowers in knots, and from the evil of an envier when he envies.\n\n3. An-Nas: Say: I seek refuge in the Lord of mankind, the Sovereign of mankind, the God of mankind, from the evil of the retreating whisperer who whispers into the breasts of mankind—from among the jinn and mankind.",
      readingRules: "Recite 3 times in morning & evening, and blow onto hands before sleep.",
    ),
    HadithWazifa(
      title: "Sayyidul Istighfar (Master Supplication for Forgiveness)",
      recitationCount: "1 Time Morning & Evening",
      benefitEnglish: "Whoever recites it in the day/night with firm belief and dies that day/night will be among the people of Jannah.",
      hadithReference: "Sahih al-Bukhari (6306)",
      targetDay: "Daily (Morning & Evening)",
      arabicText: "اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ خَلَقْتَنِي وَأَنَا عَبْدُكَ وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ وَأَبُوءُ لَكِ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ",
      englishPronunciation: "Allahumma Anta Rabbi la ilaha illa Anta, khalaqtani wa ana 'abduka, wa ana 'ala 'ahdika wa wa'dika mas-tata'tu, a'udhu bika min sharri ma sana'tu, abu'u laka bi-ni'matika 'alayya, wa abu'u bi-dhanbi faghfir li fa-innahu la yaghfirudh-dhunuba illa Ant.",
      englishTranslation: "O Allah, You are my Lord! There is no deity worthy of worship except You. You created me and I am Your servant, and I abide by Your covenant and promise as best I can. I seek refuge in You from the evil of what I have done. I acknowledge Your favor upon me, and I acknowledge my sin, so forgive me, for none forgives sins except You.",
      readingRules: "Recite 1 time every morning after Fajr and every evening after Maghrib.",
    ),
    HadithWazifa(
      title: "Dua Yunus (Prayer of Prophet Jonah in Distress)",
      recitationCount: "As needed in hardship",
      benefitEnglish: "No Muslim supplicates with this prayer in any distress except that Allah answers his prayer.",
      hadithReference: "Sunan at-Tirmidhi (3505), Surah Al-Anbiya (87)",
      targetDay: "In Times of Distress / Daily",
      arabicText: "لَّا إِلَٰهَ إِلَّا أَنتَ سُبْحَانَكَ إِنِّي كُنتُ مِنَ الظَّالِمِينَ",
      englishPronunciation: "La ilaha illa Anta subhanaka inni kuntu minaz-zalimin.",
      englishTranslation: "There is no deity except You; exalted are You! Indeed, I have been of the wrongdoers.",
      readingRules: "Recite constantly when facing hardship, stress, or worries.",
    ),
    HadithWazifa(
      title: "Surah Al-Waqi'ah (Surah of Abundance & Barakah)",
      recitationCount: "1 Time Every Night",
      benefitEnglish: "Whoever recites Surah Al-Waqi'ah every night will never be afflicted by poverty.",
      hadithReference: "Shu'ab al-Iman al-Bayhaqi (2498), Ibn Asakir",
      targetDay: "Daily (Night)",
      surahId: 56,
      readingRules: "Recite every evening after Maghrib or Isha prayer. Tap button below to open in Quran Reader.",
    ),
    HadithWazifa(
      title: "Surah Ya-Sin (The Heart of the Quran)",
      recitationCount: "1 Time Morning",
      benefitEnglish: "Whoever recites Surah Ya-Sin in the morning, all his needs for the day will be fulfilled.",
      hadithReference: "Sunan ad-Darimi (3418)",
      targetDay: "Daily (Morning)",
      surahId: 36,
      readingRules: "Recite in the morning after Fajr prayer. Tap button below to open in Quran Reader.",
    ),
    HadithWazifa(
      title: "Durood-e-Ibrahim (Salawat upon the Prophet)",
      recitationCount: "10 Times Morning & Evening / Friday",
      benefitEnglish: "The most superior Salawat. Earns 10 divine mercies, erases 10 sins, and grants the Prophet's intercession.",
      hadithReference: "Sahih al-Bukhari (3370), Sahih Muslim (405)",
      targetDay: "Daily & Friday",
      arabicText: "اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ كَمَا صَلَّيْتَ عَلَى إِبْرَاهِيمَ وَعَلَى آلِ إِبْرَاهِيمَ إِنَّكَ حَمِيدٌ مَجِيدٌ ۝ اللَّهُمَّ بَارِكْ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ كَمَا بَارَكْتَ عَلَى إِبْرَاهِيمَ وَعَلَى آلِ إِبْرَاهِيمَ إِنَّكَ حَمِيدٌ مَجِيدٌ",
      englishPronunciation: "Allahumma salli 'ala Muhammadin wa 'ala ali Muhammadin kamasallayta 'ala Ibrahima wa 'ala ali Ibrahima innaka Hamidum-Majid. Allahumma barik 'ala Muhammadin wa 'ala ali Muhammadin kama barakta 'ala Ibrahima wa 'ala ali Ibrahima innaka Hamidum-Majid.",
      englishTranslation: "O Allah, send peace upon Muhammad and upon the family of Muhammad, as You sent peace upon Ibrahim and upon the family of Ibrahim; indeed, You are Praiseworthy and Glorious. O Allah, send blessings upon Muhammad and upon the family of Muhammad, as You sent blessings upon Ibrahim and upon the family of Ibrahim; indeed, You are Praiseworthy and Glorious.",
      readingRules: "Recite 10 times morning and evening, and abundantly on Friday.",
    ),
    HadithWazifa(
      title: "Quranic Manzil (33 Verse Protection)",
      recitationCount: "1 Time Daily",
      benefitEnglish: "A combination of 33 Quranic verses offering divine protection against evil eye, magic, jinns, and harm.",
      hadithReference: "Musnad Ahmad, Sunan Ibn Majah",
      targetDay: "Daily / In Hardship",
      arabicText: "وَإِلَٰهُكُمْ إِلَٰهٌ وَاحِدٌ ۖ لَّا إِلَٰهَ إِلَّا هُوَ الرَّحْمَٰنُ الرَّحِيمُ",
      englishPronunciation: "Wa Ilahukum Ilahun Wahid; la ilaha illa Huwar-Rahmanur-Rahim.",
      englishTranslation: "And your god is one God. There is no deity worthy of worship except Him, the Entirely Merciful, the Especially Merciful.",
      readingRules: "Recite once daily in the house for divine protection.",
    ),
  ];

  // Searchable authentic Duas repository from Quran & Sahih Sunnah
  static const List<AuthenticDuaItem> _authenticDuasDatabase = [
    AuthenticDuaItem(
      title: "Dua upon Waking Up",
      arabicText: "الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا وَإِلَيْهِ النُّشُورُ",
      englishPronunciation: "Al-hamdu lillahillazi ahyana ba'da ma amatana wa ilaihin-nushur.",
      englishTranslation: "Praise be to Allah Who brought us back to life after causing us to die, and unto Him is the resurrection.",
      hadithReference: "Sahih al-Bukhari (6312), Sahih Muslim",
      benefitEnglish: "Expresses gratitude to Allah immediately upon waking up.",
      readingRules: "Recite immediately when waking up from sleep.",
      defaultCategory: "Morning",
      tags: ["wakeup", "morning", "sleep", "gratitude"],
    ),
    AuthenticDuaItem(
      title: "Dua for Peace after Prayer (Allahumma Antas-Salam)",
      arabicText: "اللَّهُمَّ أَنْتَ السَّلَامُ وَمِنْكَ السَّلَامُ تَبَارَكْتَ يَا ذَا الْجَلَالِ وَالْإِكْرَامِ",
      englishPronunciation: "Allahumma Antas-Salamu wa minkas-salam, tabarakta ya Dhal-Jalali wal-Ikram.",
      englishTranslation: "O Allah, You are Peace and from You is peace. Blessed are You, O Owner of Majesty and Honor.",
      hadithReference: "Sahih Muslim (591)",
      benefitEnglish: "Sunnah supplication recited right after completing obligatory prayer.",
      readingRules: "Recite 1 time after saying Astaghfirullah 3 times following obligatory prayer.",
      defaultCategory: "After Salah",
      tags: ["salah", "salam", "peace", "prayer"],
    ),
    AuthenticDuaItem(
      title: "Dua for Assistance in Worship (Allahumma A'inni)",
      arabicText: "اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ وَشُكْرِكَ وَحُسْنِ عِبَادَتِكَ",
      englishPronunciation: "Allahumma a'inni 'ala dhikrika wa shukrika wa husni 'ibadatik.",
      englishTranslation: "O Allah, help me to remember You, to thank You, and to worship You in the best manner.",
      hadithReference: "Sunan Abu Dawud (1522), Sunan an-Nasa'i (1303)",
      benefitEnglish: "Recommended by the Prophet (ﷺ) to Mu'adh ibn Jabal (RA) after every prayer.",
      readingRules: "Recite at the end of every obligatory prayer before or after salam.",
      defaultCategory: "After Salah",
      tags: ["salah", "gratitude", "worship", "dhikr"],
    ),
    AuthenticDuaItem(
      title: "Quranic Prayer for Parents (Rabbi-irhamhuma)",
      arabicText: "رَّبِّ ارْحَمْهُمَا كَمَا رَبَّيَانِي صَغِيرًا",
      englishPronunciation: "Rabbi-irhamhuma kama rabbayani saghira.",
      englishTranslation: "My Lord, have mercy upon them both as they brought me up when I was small.",
      hadithReference: "Surah Al-Isra (24)",
      benefitEnglish: "The greatest Quranic prayer for children to seek mercy and forgiveness for their parents.",
      readingRules: "Recite frequently after daily prayers and during personal supplications.",
      defaultCategory: "After Salah",
      tags: ["parents", "family", "mercy", "dua"],
    ),
    AuthenticDuaItem(
      title: "Quranic Prayer for Family & Pious Offspring",
      arabicText: "رَبَّنَا هَبْ لَنَا مِنْ أَزْوَاجِنَا وَذُرِّيَّاتِنَا قُرَّةَ أَعْيُنٍ وَاجْعَلْنَا لِلْمُتَّقِينَ إِمَامًا",
      englishPronunciation: "Rabbana hab lana min azwajina wa dhurriyyatina qurrata a'yuniw-waj'alna lil-muttaqina imama.",
      englishTranslation: "Our Lord, grant us from among our wives and offspring comfort to our eyes and make us a leader for the righteous.",
      hadithReference: "Surah Al-Furqan (74)",
      benefitEnglish: "Brings harmony to marriage, joy through pious children, and spiritual leadership.",
      readingRules: "Recite as part of daily family supplications.",
      defaultCategory: "Morning",
      tags: ["family", "children", "marriage", "home"],
    ),
    AuthenticDuaItem(
      title: "Dua for Relief from Anxiety & Debt (Allahumma Inni A'udhu Bika)",
      arabicText: "اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ وَالْعَجْزِ وَالْكَسَلِ وَالْبُخْلِ وَالْجُبْنِ وَضَلَعِ الدَّيْنِ وَغَلَبَةِ الرِّجَالِ",
      englishPronunciation: "Allahumma inni a'udhu bika minal-hammi wal-hazani, wal-'ajzi wal-kasali, wal-bukhli wal-jubni, wa dala'id-dayni wa ghalabatir-rijal.",
      englishTranslation: "O Allah, I seek refuge in You from anxiety and grief, helplessness and laziness, cowardice and miserliness, the burden of debt and the oppression of men.",
      hadithReference: "Sahih al-Bukhari (2893)",
      benefitEnglish: "Removes deep distress, anxiety, depression, and financial burdens.",
      readingRules: "Recite in the morning and evening and whenever overwhelmed by worries.",
      defaultCategory: "Morning",
      tags: ["anxiety", "debt", "distress", "depression", "relief"],
    ),
    AuthenticDuaItem(
      title: "Dua of Reliance in Times of Hardship (Hasbunallahu)",
      arabicText: "حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ",
      englishPronunciation: "Hasbunallahu wa ni'mal-Wakil.",
      englishTranslation: "Allah is sufficient for us, and He is the best Disposer of affairs.",
      hadithReference: "Sahih al-Bukhari (4563), Surah Ali 'Imran (173)",
      benefitEnglish: "Recited by Prophet Ibrahim (AS) when thrown into the fire, bringing divine salvation.",
      readingRules: "Recite repeatedly during sudden adversity or difficulties.",
      defaultCategory: "Morning",
      tags: ["distress", "protection", "reliance", "trust"],
    ),
    AuthenticDuaItem(
      title: "Dua in Distress: Dua Yunus",
      arabicText: "لَّا إِلَٰهَ إِلَّا أَنتَ سُبْحَانَكَ إِنِّي كُنتُ مِنَ الظَّالِمِينَ",
      englishPronunciation: "La ilaha illa Anta subhanaka inni kuntu minaz-zalimin.",
      englishTranslation: "There is no deity except You; exalted are You! Indeed, I have been of the wrongdoers.",
      hadithReference: "Sunan at-Tirmidhi (3505), Surah Al-Anbiya (87)",
      benefitEnglish: "Removes extreme distress and hardship when called upon sincerely.",
      readingRules: "Recite as often as possible when facing trials or sorrow.",
      defaultCategory: "Before Sleep",
      tags: ["distress", "hardship", "yunus", "trouble"],
    ),
    AuthenticDuaItem(
      title: "Master Supplication for Forgiveness (Sayyidul Istighfar)",
      arabicText: "اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ خَلَقْتَنِي وَأَنَا عَبْدُكَ وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ وَأَبُوءُ لَكِ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ",
      englishPronunciation: "Allahumma Anta Rabbi la ilaha illa Anta, khalaqtani wa ana 'abduka, wa ana 'ala 'ahdika wa wa'dika mas-tata'tu, a'udhu bika min sharri ma sana'tu, abu'u laka bi-ni'matika 'alayya, wa abu'u bi-dhanbi faghfir li fa-innahu la yaghfirudh-dhunuba illa Ant.",
      englishTranslation: "O Allah, You are my Lord! There is no deity worthy of worship except You. You created me and I am Your servant, and I abide by Your covenant and promise as best I can. I seek refuge in You from the evil of what I have done. I acknowledge Your favor upon me, and I acknowledge my sin, so forgive me, for none forgives sins except You.",
      hadithReference: "Sahih al-Bukhari (6306)",
      benefitEnglish: "Guarantees Jannah if recited with conviction in the day/night before passing away.",
      readingRules: "Recite 1 time morning and evening.",
      defaultCategory: "Morning",
      tags: ["istighfar", "forgiveness", "sayyidul", "repentance"],
    ),
    AuthenticDuaItem(
      title: "Ayatul Kursi (The Greatest Verse)",
      arabicText: "اللَّهُ لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَّهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَن ذَا الَّذِي يَشْفَعُ عِندَهُ إِلَّا بِإِذْنِهِ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ",
      englishPronunciation: "Allahu la ilaha illa Huwal-Hayyul-Qayyum. La ta'khudhuhu sinatuw-wa la nawm. Lahu ma fis-samawati wa ma fil-ard. Man dhal-lazi yashfa'u 'indahu illa bi-idhnih. Ya'lamu ma bayna aydihim wa ma khalfahum, wa la yuhituna bi-shay'im-min 'ilmihi illa bima sha'. Wasi'a Kursiyyuhus-samawati wal-ard, wa la ya'uduhu hifzuhuma, wa Huwal-'Aliyyul-'Azim.",
      englishTranslation: "Allah! There is no deity except Him, the Ever-Living, the Sustainer of all existence. Neither drowsiness overtakes Him nor sleep. To Him belongs whatever is in the heavens and whatever is on the earth. Who is it that can intercede with Him except by His permission? He knows what is before them and what will be after them, and they encompass not a thing of His knowledge except for what He wills. His Kursi extends over the heavens and the earth, and their preservation tires Him not. And He is the Most High, the Most Great.",
      hadithReference: "Sunan an-Nasa'i Al-Kubra (9928)",
      benefitEnglish: "Reciting after obligatory prayer leaves only death between the reciter and Jannah.",
      readingRules: "Recite after every obligatory prayer, morning, evening, and bedtime.",
      defaultCategory: "After Salah",
      tags: ["ayatul kursi", "protection", "salah", "kursi"],
    ),
    AuthenticDuaItem(
      title: "Dua for Divine Protection (Bismillahil-ladhi)",
      arabicText: "بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّماءِ وَهُوَ السَّمِيعُ الْعَلِيمُ",
      englishPronunciation: "Bismillahil-ladhi la yadurru ma'as-mihi shay'un fil-ardi wa la fis-sama'i wa Huwas-Sami'ul-'Alim.",
      englishTranslation: "In the name of Allah, with Whose name nothing can cause harm in the earth or in the heaven, and He is the All-Hearing, the All-Knowing.",
      hadithReference: "Sunan at-Tirmidhi (3388), Sunan Abu Dawud (5088)",
      benefitEnglish: "Protects against all sudden afflictions, harmful creatures, and poison.",
      readingRules: "Recite 3 times every morning and 3 times every evening.",
      defaultCategory: "Morning",
      tags: ["protection", "bismillah", "harm", "morning", "evening"],
    ),
    AuthenticDuaItem(
      title: "Dua for Sufficient Provision & Halal Rizq (Allahummak-fini)",
      arabicText: "اللَّهُمَّ اكْفِنِي بِحَلَالِكَ عَنْ حَرَامِكَ وَأَغْنِنِي بِفَضْلِكَ عَمَّنْ سِوَاكَ",
      englishPronunciation: "Allahummak-fini bi-halalika 'an haramika wa aghnini bi-fadlika 'amman siwak.",
      englishTranslation: "O Allah, suffice me with Your lawful against Your prohibited, and make me independent of all besides You by Your grace.",
      hadithReference: "Sunan at-Tirmidhi (3563)",
      benefitEnglish: "Helps pay off heavy debts even as large as a mountain.",
      readingRules: "Recite after prayers and frequently on Fridays.",
      defaultCategory: "After Salah",
      tags: ["rizq", "debt", "wealth", "halal", "provision"],
    ),
    AuthenticDuaItem(
      title: "Dua for Increasing Knowledge (Rabbi Zidni 'Ilma)",
      arabicText: "رَّبِّ زِدْنِي عِلْمًا",
      englishPronunciation: "Rabbi zidni 'ilma.",
      englishTranslation: "My Lord, increase me in knowledge.",
      hadithReference: "Surah Ta-Ha (114)",
      benefitEnglish: "Enhances memory, understanding, and beneficial Islamic knowledge.",
      readingRules: "Recite before studying or engaging in Islamic learning.",
      defaultCategory: "Morning",
      tags: ["knowledge", "ilm", "study", "wisdom"],
    ),
    AuthenticDuaItem(
      title: "Dua for Beneficial Knowledge, Pure Provision & Accepted Deeds",
      arabicText: "اللَّهُمَّ إِنِّي أَسْأَلُكَ عِلْمًا نَافِعًا وَرِزْقًا طَيِّبًا وَعَمَلًا مُتَقَبَّلًا",
      englishPronunciation: "Allahumma inni as'aluka 'ilman nafi'an, wa rizqan tayyiban, wa 'amalan mutaqabbala.",
      englishTranslation: "O Allah, I ask You for beneficial knowledge, pure provision, and acceptable deeds.",
      hadithReference: "Sunan Ibn Majah (925), Sahih at-Targhib",
      benefitEnglish: "The Prophet (ﷺ) recited this every morning right after concluding Fajr prayer.",
      readingRules: "Recite 1 time right after Fajr prayer.",
      defaultCategory: "Morning",
      tags: ["morning", "rizq", "ilm", "fajr", "deeds"],
    ),
    AuthenticDuaItem(
      title: "Dua for Healing & Physical Recovery (Shefa)",
      arabicText: "اللَّهُمَّ رَبَّ النَّاسِ أَذْهِبِ الْبَاسَ اشْفِ أَنْتَ الشَّافِي لَا شِفَاءَ إِلَّا شِفَاؤُكَ شِفَاءً لَا يُغَادِرُ سَقَمًا",
      englishPronunciation: "Allahumma Rabban-nasi azhibil-ba's, ishfi Antash-Shafi, la shifa'a illa shifa'uk, shifa'an la yughadiru saqama.",
      englishTranslation: "O Allah, Lord of mankind, remove the suffering; heal, for You are the Healer. There is no healing except Your healing—a healing that leaves no illness behind.",
      hadithReference: "Sahih al-Bukhari (5675), Sahih Muslim (2191)",
      benefitEnglish: "Brings divine cure when recited over an ill person or oneself.",
      readingRules: "Place right hand over the pain area and recite 3 or 7 times.",
      defaultCategory: "Before Sleep",
      tags: ["health", "illness", "cure", "shefa", "recovery"],
    ),
    AuthenticDuaItem(
      title: "Bedtime Sunnah Supplication",
      arabicText: "بِاسْمِكَ رَبِّي وَضَعْتُ جَنْبِي وَبِكَ أَرْفَعُهُ فَإِنْ أَمْسَكْتَ نَفْسِي فَارْحَمْهَا وَإِنْ أَرْسَلْتَهَا فَاحْفَظْهَا بِمَا تَحْفَظُ بِهِ عِبَادَكَ الصَّالِحِينَ",
      englishPronunciation: "Bismika Rabbi wada'tu janbi wa bika arfa'uh, fa-in amsakta nafsi farhamha, wa in arsaltaha fahfazha bima tahfazu bihi 'ibadakas-salihin.",
      englishTranslation: "In Your name, my Lord, I lay my side down, and in Your name I raise it. If You take my soul, have mercy on it, and if You return it, protect it as You protect Your righteous servants.",
      hadithReference: "Sahih al-Bukhari (6320), Sahih Muslim (2714)",
      benefitEnglish: "Secures divine protection from bad dreams and unexpected harms during sleep.",
      readingRules: "Recite 1 time while lying on the right side in bed.",
      defaultCategory: "Before Sleep",
      tags: ["sleep", "bedtime", "night", "protection"],
    ),
    AuthenticDuaItem(
      title: "Dua when Leaving the Home",
      arabicText: "بِسْمِ اللَّهِ تَوَكَّلْتُ عَلَى اللَّهِ لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ",
      englishPronunciation: "Bismillahi tawakkaltu 'alallah, la hawla wa la quwwata illa billah.",
      englishTranslation: "In the name of Allah, I place my trust in Allah; there is no power or might except with Allah.",
      hadithReference: "Sunan at-Tirmidhi (3426), Sunan Abu Dawud (5095)",
      benefitEnglish: "Angels declare: 'You are guided, defended, and protected,' and Shaytan steps away.",
      readingRules: "Recite 1 time whenever stepping out of the house.",
      defaultCategory: "Morning",
      tags: ["home", "travel", "protection", "exit"],
    ),
    AuthenticDuaItem(
      title: "Superior Salawat: Durood-e-Ibrahim",
      arabicText: "اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ كَمَا صَلَّيْتَ عَلَى إِبْرَاهِيمَ وَعَلَى آلِ إِبْرَاهِيمَ إِنَّكَ حَمِيدٌ مَجِيدٌ ۝ اللَّهُمَّ بَارِكْ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ كَمَا بَارَكْتَ عَلَى إِبْرَاهِيمَ وَعَلَى آلِ إِبْرَاهِيمَ إِنَّكَ حَمِيدٌ مَجِيدٌ",
      englishPronunciation: "Allahumma salli 'ala Muhammadin wa 'ala ali Muhammadin kamasallayta 'ala Ibrahima wa 'ala ali Ibrahima innaka Hamidum-Majid. Allahumma barik 'ala Muhammadin wa 'ala ali Muhammadin kama barakta 'ala Ibrahima wa 'ala ali Ibrahima innaka Hamidum-Majid.",
      englishTranslation: "O Allah, send peace upon Muhammad and upon the family of Muhammad, as You sent peace upon Ibrahim and upon the family of Ibrahim; indeed, You are Praiseworthy and Glorious. O Allah, send blessings upon Muhammad and upon the family of Muhammad, as You sent blessings upon Ibrahim and upon the family of Ibrahim; indeed, You are Praiseworthy and Glorious.",
      hadithReference: "Sahih al-Bukhari (3370)",
      benefitEnglish: "Brings 10 blessings, erases 10 sins, and elevates rank in Paradise.",
      readingRules: "Recite in Tashahhud of prayer and abundantly on Fridays.",
      defaultCategory: "After Salah",
      tags: ["durood", "ibrahim", "prophet", "friday"],
    ),
    AuthenticDuaItem(
      title: "Dua for Protection from Evil & Harmful Creatures",
      arabicText: "أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ",
      englishPronunciation: "A'udhu bi-kalimatil-lahit-tammati min sharri ma khalaq.",
      englishTranslation: "I seek refuge in the perfect words of Allah from the evil of what He has created.",
      hadithReference: "Sahih Muslim (2708), Sunan at-Tirmidhi (3604)",
      benefitEnglish: "Guarantees that no poisonous insect or creature will harm the reciter that night.",
      readingRules: "Recite 3 times in the evening and when arriving at a new location.",
      defaultCategory: "Evening",
      tags: ["protection", "evening", "creatures", "harm"],
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
        title: "Ayatul Kursi (Morning)",
        arabicText: "اللَّهُ لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَّهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَن ذَا الَّذِي يَشْفَعُ عِندَهُ إِلَّا بِإِذْنِهِ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ",
        englishPronunciation: "Allahu la ilaha illa Huwal-Hayyul-Qayyum. La ta'khudhuhu sinatuw-wa la nawm. Lahu ma fis-samawati wa ma fil-ard. Man dhal-lazi yashfa'u 'indahu illa bi-idhnih. Ya'lamu ma bayna aydihim wa ma khalfahum, wa la yuhituna bi-shay'im-min 'ilmihi illa bima sha'. Wasi'a Kursiyyuhus-samawati wal-ard, wa la ya'uduhu hifzuhuma, wa Huwal-'Aliyyul-'Azim.",
        englishTranslation: "Allah! There is no deity except Him, the Ever-Living, the Sustainer of all existence. Neither drowsiness overtakes Him nor sleep. To Him belongs whatever is in the heavens and whatever is on the earth. Who is it that can intercede with Him except by His permission? He knows what is before them and what will be after them, and they encompass not a thing of His knowledge except for what He wills. His Kursi extends over the heavens and the earth, and their preservation tires Him not. And He is the Most High, the Most Great.",
        readingRules: "Recite every morning after Fajr. Provides divine protection for the day.",
      ),
      CustomWazifa(
        title: "Three Quls — Al-Ikhlas, Al-Falaq, An-Nas (3×)",
        arabicText: "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ ۝ قُلْ هُوَ اللَّهُ أَحَدٌ ۝ اللَّهُ الصَّمَدُ ۝ لَمْ يَلِدْ وَلَمْ يُولَدْ ۝ وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ\n\nبِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ ۝ قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ ۝ مِن شَرِّ مَا خَلَقَ ۝ وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ ۝ وَمِن شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ ۝ وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ\n\nبِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ ۝ قُلْ أَعُوذُ بِرَبِّ النَّاسِ ۝ مَلِكِ النَّاسِ ۝ إِلَٰهِ النَّاسِ ۝ مِن شَرِّ الْوَسْوَاسِ الْخَنَّاسِ ۝ الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ ۝ مِنَ الْجِنَّةِ وَالنَّاسِ",
        englishPronunciation: "1. Al-Ikhlas: Bismillahir-Rahmanir-Rahim. Qul Huwal-Lahu Ahad. Allahus-Samad. Lam yalid wa lam yulad. Wa lam yakul-lahu kufuwan ahad.\n\n2. Al-Falaq: Bismillahir-Rahmanir-Rahim. Qul a'udhu bi-Rabbil-falaq. Min sharri ma khalaq. Wa min sharri ghasiqin idha waqab. Wa min sharrin-naffathati fil-'uqad. Wa min sharri hasidin idha hasad.\n\n3. An-Nas: Bismillahir-Rahmanir-Rahim. Qul a'udhu bi-Rabbin-nas. Malikin-nas. Ilahin-nas. Min sharril-waswasil-khannas. Allazi yuwaswisu fi sudurin-nas. Minal-jinnati wan-nas.",
        englishTranslation: "1. Al-Ikhlas: In the name of Allah, the Entirely Merciful, the Especially Merciful. Say: He is Allah, [who is] One. Allah, the Eternal Refuge. He neither begets nor is born. Nor is there to Him any equivalent.\n\n2. Al-Falaq: Say: I seek refuge in the Lord of daybreak from the evil of that which He created, and from the evil of darkness when it settles, and from the evil of the blowers in knots, and from the evil of an envier when he envies.\n\n3. An-Nas: Say: I seek refuge in the Lord of mankind, the Sovereign of mankind, the God of mankind, from the evil of the retreating whisperer who whispers into the breasts of mankind—from among the jinn and mankind.",
        readingRules: "Recite each surah 3 times after Fajr prayer, then blow onto your hands and wipe over your body.",
      ),
      CustomWazifa(
        title: "Sayyidul Istighfar (Master Forgiveness Dua)",
        arabicText: "اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ خَلَقْتَنِي وَأَنَا عَبْدُكَ وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ وَأَبُوءُ لَكِ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ",
        englishPronunciation: "Allahumma Anta Rabbi la ilaha illa Anta, khalaqtani wa ana 'abduka, wa ana 'ala 'ahdika wa wa'dika mas-tata'tu, a'udhu bika min sharri ma sana'tu, abu'u laka bi-ni'matika 'alayya, wa abu'u bi-dhanbi faghfir li fa-innahu la yaghfirudh-dhunuba illa Ant.",
        englishTranslation: "O Allah, You are my Lord! There is no deity worthy of worship except You. You created me and I am Your servant, and I abide by Your covenant and promise as best I can. I seek refuge in You from the evil of what I have done. I acknowledge Your favor upon me, and I acknowledge my sin, so forgive me, for none forgives sins except You.",
        readingRules: "Recite 1 time every morning after Fajr. Guarantees Jannah if believed sincerely.",
      ),
      CustomWazifa(
        title: "Morning Dua upon Waking (Alhamdulillah)",
        arabicText: "اللَّهُمَّ بِكَ أَصْبَحْنَا وَبِكَ أَمْسَيْنَا وَبِكَ نَحْيَا وَبِكَ نَمُوتُ وَإِلَيْكَ النُّشُورُ",
        englishPronunciation: "Allahumma bika asbahna wa bika amsayna wa bika nahya wa bika namutu wa ilaykan-nushur.",
        englishTranslation: "O Allah, by You we enter the morning and by You we enter the evening; by You we live and by You we die, and unto You is the resurrection.",
        readingRules: "Sunnah to recite 1 time every morning after Fajr.",
      ),
    ],
    'Evening': [
      CustomWazifa(
        title: "Ayatul Kursi (Evening)",
        arabicText: "اللَّهُ لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَّهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَن ذَا الَّذِي يَشْفَعُ عِندَهُ إِلَّا بِإِذْنِهِ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ",
        englishPronunciation: "Allahu la ilaha illa Huwal-Hayyul-Qayyum. La ta'khudhuhu sinatuw-wa la nawm. Lahu ma fis-samawati wa ma fil-ard. Man dhal-lazi yashfa'u 'indahu illa bi-idhnih. Ya'lamu ma bayna aydihim wa ma khalfahum, wa la yuhituna bi-shay'im-min 'ilmihi illa bima sha'. Wasi'a Kursiyyuhus-samawati wal-ard, wa la ya'uduhu hifzuhuma, wa Huwal-'Aliyyul-'Azim.",
        englishTranslation: "Allah! There is no deity except Him, the Ever-Living, the Sustainer of all existence. Neither drowsiness overtakes Him nor sleep. To Him belongs whatever is in the heavens and whatever is on the earth. Who is it that can intercede with Him except by His permission? He knows what is before them and what will be after them, and they encompass not a thing of His knowledge except for what He wills. His Kursi extends over the heavens and the earth, and their preservation tires Him not. And He is the Most High, the Most Great.",
        readingRules: "Recite every evening after Maghrib. Protects from Jinn and Shaytan all night.",
      ),
      CustomWazifa(
        title: "Three Quls — Al-Ikhlas, Al-Falaq, An-Nas (3×)",
        arabicText: "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ ۝ قُلْ هُوَ اللَّهُ أَحَدٌ ۝ اللَّهُ الصَّمَدُ ۝ لَمْ يَلِدْ وَلَمْ يُولَدْ ۝ وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ\n\nبِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ ۝ قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ ۝ مِن شَرِّ مَا خَلَقَ ۝ وَمِن شَرِّ غَاسِقٍ إِذَا وَقَبَ ۝ وَمِن شَرِّ النَّفَّاثَاتِ فِي الْعُقَدِ ۝ وَمِن شَرِّ حَاسِدٍ إِذَا حَسَدَ\n\nبِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ ۝ قُلْ أَعُوذُ بِرَبِّ النَّاسِ ۝ مَلِكِ النَّاسِ ۝ إِلَٰهِ النَّاسِ ۝ مِن شَرِّ الْوَسْوَاسِ الْخَنَّاسِ ۝ الَّذِي يُوَسْوِسُ فِي صُدُورِ النَّاسِ ۝ مِنَ الْجِنَّةِ وَالنَّاسِ",
        englishPronunciation: "1. Al-Ikhlas: Bismillahir-Rahmanir-Rahim. Qul Huwal-Lahu Ahad. Allahus-Samad. Lam yalid wa lam yulad. Wa lam yakul-lahu kufuwan ahad.\n\n2. Al-Falaq: Bismillahir-Rahmanir-Rahim. Qul a'udhu bi-Rabbil-falaq. Min sharri ma khalaq. Wa min sharri ghasiqin idha waqab. Wa min sharrin-naffathati fil-'uqad. Wa min sharri hasidin idha hasad.\n\n3. An-Nas: Bismillahir-Rahmanir-Rahim. Qul a'udhu bi-Rabbin-nas. Malikin-nas. Ilahin-nas. Min sharril-waswasil-khannas. Allazi yuwaswisu fi sudurin-nas. Minal-jinnati wan-nas.",
        englishTranslation: "1. Al-Ikhlas: In the name of Allah, the Entirely Merciful, the Especially Merciful. Say: He is Allah, [who is] One. Allah, the Eternal Refuge. He neither begets nor is born. Nor is there to Him any equivalent.\n\n2. Al-Falaq: Say: I seek refuge in the Lord of daybreak from the evil of that which He created, and from the evil of darkness when it settles, and from the evil of the blowers in knots, and from the evil of an envier when he envies.\n\n3. An-Nas: Say: I seek refuge in the Lord of mankind, the Sovereign of mankind, the God of mankind, from the evil of the retreating whisperer who whispers into the breasts of mankind—from among the jinn and mankind.",
        readingRules: "Recite each surah 3 times after Maghrib prayer.",
      ),
      CustomWazifa(
        title: "Last 3 Verses of Surah Al-Hashr",
        arabicText: "هُوَ اللَّهُ الَّذِي لَا إِلَٰهَ إِلَّا هُوَ ۖ عَالِمُ الْغَيْبِ وَالشَّهَادَةِ ۖ هُوَ الرَّحْمَٰنُ الرَّحِيمُ ۝ هُوَ اللَّهُ الَّذِي لَا إِلَٰهَ إِلَّا هُوَ الْمَلِكُ الْقُدُّوسُ السَّلَامُ الْمُؤْمِنُ الْمُهَيْمِنُ الْعَزِيزُ الْجَبَّارُ الْمُتَكَبِّرُ ۚ سُبْحَانَ اللَّهِ عَمَّا يُشْرِكُونَ ۝ هُوَ اللَّهُ الْخَالِقُ الْبَارِئُ الْمُصَوِّرُ ۖ لَهُ الْأَسْمَاءُ الْحُسْنَىٰ ۚ يُسَبِّحُ لَهُ مَا فِي السَّمَاوَاتِ وَالْأَرْضِ ۖ وَهُوَ الْعَلِيُّ الْحَكِيمُ",
        englishPronunciation: "Huwallahul-ladhi la ilaha illa Huwa, 'Alimul-ghaybi wash-shahadati Huwar-Rahmanur-Rahim. Huwallahul-ladhi la ilaha illa Huwal-Malikul-Quddusus-Salamul-Mu'minul-Muhayminul-'Azizul-Jabbarul-Mutakabbir; Subhanallahi 'amma yushrikun. Huwallahul-Khaliqul-Bari'ul-Musawwiru lahul-Asma'ul-Husna; yusabbihu lahu ma fis-samawati wal-ardi wa Huwal-'Azizul-Hakim.",
        englishTranslation: "He is Allah, other than whom there is no deity, Knower of the unseen and the witnessed. He is the Entirely Merciful, the Especially Merciful. He is Allah, other than whom there is no deity, the Sovereign, the Pure, the Perfection, the Grantor of Security, the Overseer, the Exalted in Might, the Compeller, the Superior. Exalted is Allah above whatever they associate with Him. He is Allah, the Creator, the Inventor, the Fashioner; to Him belong the best names. Whatever is in the heavens and earth is exalting Him. And He is the Exalted in Might, the Wise.",
        readingRules: "Recite 1 time after Maghrib — brings 70,000 angels seeking forgiveness for the reciter.",
      ),
      CustomWazifa(
        title: "Evening Remembrance Dua",
        arabicText: "اللَّهُمَّ بِكَ أَمْسَيْنَا وَبِكَ أَصْبَحْنَا وَبِكَ نَحْيَا وَبِكَ نَمُوتُ وَإِلَيْكَ الْمَصِيرُ",
        englishPronunciation: "Allahumma bika amsayna wa bika asbahna wa bika nahya wa bika namutu wa ilaykal-masir.",
        englishTranslation: "O Allah, by You we enter the evening and by You we enter the morning; by You we live and by You we die, and to You is our return.",
        readingRules: "Sunnah to recite 1 time every evening after Maghrib.",
      ),
    ],
    'Before Sleep': [
      CustomWazifa(
        title: "Surah Al-Mulk (Night Protection)",
        benefitEnglish: "Intercedes for the reciter until forgiven. Protects from the punishment of the grave.",
        readingRules: "Recite Surah 67 (Al-Mulk) before sleep. Tap button below to open in Quran Reader.",
      ),
      CustomWazifa(
        title: "Surah As-Sajdah (Night Sunnah)",
        benefitEnglish: "The Prophet (peace be upon him) never slept without reciting Surah As-Sajdah and Al-Mulk.",
        readingRules: "Recite Surah 32 (As-Sajdah) before sleep. Tap button below to open in Quran Reader.",
      ),
      CustomWazifa(
        title: "Last 2 Verses of Surah Al-Baqarah",
        arabicText: "آمَنَ الرَّسُولُ بِمَا أُنْزِلَ إِلَيْهِ مِنْ رَبِّهِ وَالْمُؤْمِنُونَ ۚ كُلٌّ آمَنَ بِاللَّهِ وَمَلَائِكَتِهِ وَكُتُبِهِ وَرُسُلِهِ لَا نُفَرِّقُ بَيْنَ أَحَدٍ مِنْ رُسُلِهِ ۚ وَقَالُوا سَمِعْنَا وَأَطَعْنَا ۖ غُفْرَانَكَ رَبَّنَا وَإِلَيْكَ الْمَصِيرُ ۝ لَا يُكَلِّفُ اللَّهُ نَفْسًا إِلَّا وُسْعَهَا ۚ لَهَا مَا كَسَبَتْ وَعَلَيْهَا مَا اكْتَسَبَتْ ۗ رَبَّنَا لَا تُؤَاخِذْنَا إِنْ نَسِينَا أَوْ أَخْطَأْنَا ۚ رَبَّنَا وَلَا تَحْمِلْ عَلَيْنَا إِصْرًا كَمَا حَمَلْتَهُ عَلَى الَّذِينَ مِنْ قَبْلِنَا ۚ رَبَّنَا وَلَا تَحِّمْلْنَا مَا لَا طَاقَةَ لَنَا بِهِ ۖ وَاعْفُ عَنَّا وَاغْفِرْ لَنَا وَارْحَمْنَا ۚ أَنْتَ مَوْلَانَا فَانْصُرْنَا عَلَى الْقَوْمِ الْكَافِرِينَ",
        englishPronunciation: "Amanar-Rasulu bima unzila ilayhi mir-Rabbihi wal-mu'minun. Kullun amana billahi wa mala'ikatihi wa kutubihi wa rusulih; la nufarriqu bayna ahadim-mir-rusulih. Wa qalu sami'na wa ata'na ghufranaka Rabbana wa ilaykal-masir. La yukallifullahu nafsan illa wus'aha; laha ma kasabat wa 'alayha maktasabat. Rabbana la tu'akhidhna in-nasina aw akhta'na; Rabbana wa la tahmil 'alayna isran kama hamaltahu 'alal-ladhina min qablina; Rabbana wa la tuhammilna ma la taqata lana bih; wa'fu 'anna waghfir lana warhamna; Anta Mawlana fansurna 'alal-qawmil-kafirin.",
        englishTranslation: "The Messenger has believed in what was revealed to him from his Lord, and so have the believers. All of them have believed in Allah and His angels and His books and His messengers, [saying], \"We make no distinction between any of His messengers.\" And they say, \"We hear and we obey. [We seek] Your forgiveness, our Lord, and to You is the final destination.\" Allah does not charge a soul except [with that within] its capacity. It will have [the consequence of] what [good] it has gained, and it will bear [the consequence of] what [evil] it has earned. \"Our Lord, do not impose blame upon us if we have forgotten or errored. Our Lord, and lay not upon us a burden like that which You laid upon those before us. Our Lord, and burden us not with that which we have no ability to bear. And pardon us; and forgive us; and have mercy upon us. You are our protector, so give us victory over the disbelieving people.\"",
        readingRules: "Recite before sleeping. These two verses are sufficient protection for the night.",
      ),
      CustomWazifa(
        title: "Surah Al-Kafirun (Before Sleep)",
        arabicText: "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ ۝ قُلْ يَا أَيُّهَا الْكَافِرُونَ ۝ لَا أَعْبُدُ مَا تَعْبُدُونَ ۝ وَلَا أَنْتُمْ عَابِدُونَ مَا أَعْبُدُ ۝ وَلَا أَنَا عَابِدٌ مَا عَبَدْتُمْ ۝ وَلَا أَنْتُمْ عَابِدُونَ مَا أَعْبُدُ ۝ لَكُمْ دِينُكُمْ وَلِيَ دِينِ",
        englishPronunciation: "Bismillahir-Rahmanir-Rahim. Qul ya ayyuhal-kafirun. La a'budu ma ta'budun. Wa la antum 'abiduna ma a'bud. Wa la ana 'abidum-ma 'abadtum. Wa la antum 'abiduna ma a'bud. Lakum dinukum wa liya din.",
        englishTranslation: "In the name of Allah, the Entirely Merciful, the Especially Merciful. Say: O disbelievers, I do not worship what you worship. Nor are you worshippers of what I worship. Nor will I be a worshipper of what you worshipped. Nor will you be worshippers of what I worship. For you is your religion, and for me is my religion.",
        readingRules: "Recite before sleeping — it is a declaration of pure Tawhid and protection from Shirk.",
      ),
      CustomWazifa(
        title: "Bedtime Dua (Bismika Allahumma)",
        arabicText: "بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا",
        englishPronunciation: "Bismika Allahumma amutu wa ahya.",
        englishTranslation: "In Your name, O Allah, I die and I live.",
        readingRules: "Recite lying on your right side before sleeping.",
      ),
    ],
    'After Salah': [
      CustomWazifa(
        title: "Ayatul Kursi (After Prayer)",
        arabicText: "اللَّهُ لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ سِنَةٌ وَلَا نَوْمٌ ۚ لَّهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ مَن ذَا الَّذِي يَشْفَعُ عِندَهُ إِلَّا بِإِذْنِهِ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِّنْ عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ",
        englishPronunciation: "Allahu la ilaha illa Huwal-Hayyul-Qayyum. La ta'khudhuhu sinatuw-wa la nawm. Lahu ma fis-samawati wa ma fil-ard. Man dhal-lazi yashfa'u 'indahu illa bi-idhnih. Ya'lamu ma bayna aydihim wa ma khalfahum, wa la yuhituna bi-shay'im-min 'ilmihi illa bima sha'. Wasi'a Kursiyyuhus-samawati wal-ard, wa la ya'uduhu hifzuhuma, wa Huwal-'Aliyyul-'Azim.",
        englishTranslation: "Allah! There is no deity except Him, the Ever-Living, the Sustainer of all existence. Neither drowsiness overtakes Him nor sleep. To Him belongs whatever is in the heavens and whatever is on the earth. Who is it that can intercede with Him except by His permission? He knows what is before them and what will be after them, and they encompass not a thing of His knowledge except for what He wills. His Kursi extends over the heavens and the earth, and their preservation tires Him not. And He is the Most High, the Most Great.",
        readingRules: "Recite after every obligatory prayer. Nothing stands between the reciter and Jannah except death.",
      ),
      CustomWazifa(
        title: "Tasbih Fatimah (33 + 33 + 34)",
        arabicText: "سُبْحَانَ اللَّهِ (33×)، الْحَمْدُ لِلَّهِ (33×)، اللَّهُ أَكْبَرُ (34×)",
        englishPronunciation: "Subhanallah (33x), Alhamdulillah (33x), Allahu Akbar (34x)",
        englishTranslation: "Glory be to Allah (33 times), Praise be to Allah (33 times), Allah is the Greatest (34 times).",
        readingRules: "Recite Subhanallah 33 times, Alhamdulillah 33 times, and Allahu Akbar 34 times after each obligatory prayer.",
      ),
      CustomWazifa(
        title: "Astaghfirullah (3×) & Peace Dua",
        arabicText: "أَسْتَغْفِرُ اللَّهَ (3×) — اللَّهُمَّ أَنْتَ السَّلَامُ وَمِنْكَ السَّلَامُ تَبَارَكْتَ يَا ذَا الْجَلَالِ وَالْإِكْرَامِ",
        englishPronunciation: "Astaghfirullah (3 times). Allahumma Antas-Salamu wa minkas-salam, tabarakta ya Dhal-Jalali wal-Ikram.",
        englishTranslation: "I seek forgiveness from Allah (3 times). O Allah, You are Peace and from You is peace. Blessed are You, O Owner of Majesty and Honor.",
        readingRules: "Recite 3 times immediately after salam at end of every prayer.",
      ),
      CustomWazifa(
        title: "Three Quls (After Prayer)",
        arabicText: "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ ۝ قُلْ هُوَ اللَّهُ أَحَدٌ... ۝ قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ... ۝ قُلْ أَعُوذُ بِرَبِّ النَّاسِ...",
        englishPronunciation: "Qul Huwal-lahu Ahad... Qul a-udhu bi-Rabbil-falaq... Qul a-udhu bi-Rabbin-nas...",
        englishTranslation: "Say: He is Allah, the One... Say: I seek refuge in the Lord of daybreak... Say: I seek refuge in the Lord of mankind...",
        readingRules: "Recite each of the three Quls once after every obligatory prayer.",
      ),
    ],
  };  // Completed states mapped by "Category_Supplication" -> bool
  final Map<String, bool> _completedWazifas = {};
  final Map<String, bool> _completedHadithWazifas = {};

  // Bookmarks & Notes (Reset empty)
  final List<Map<String, String>> _bookmarks = [];
  final List<Map<String, String>> _reflections = [];

  // Dynamic Hifz Visual Quran Map state
  Set<int> _memorizedSurahIds = {};

  // Weekly Reading History for Functional Statistics (Mon -> Sun)
  Map<String, int> _weeklyAyahsHistory = {
    'Mon': 0,
    'Tue': 0,
    'Wed': 0,
    'Thu': 0,
    'Fri': 0,
    'Sat': 0,
    'Sun': 0,
  };

  // Settings state
  // Quran Audio Tilawat Player State
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;
  bool _isLoadingAudio = false;
  int? _currentlyPlayingSurah;
  int? _currentlyPlayingAyah;
  String _selectedReciter = 'Alafasy_128kbps';

  static const List<Map<String, String>> _reciterList = [
    {'id': 'Alafasy_128kbps', 'name': 'Mishary Rashid Alafasy'},
    {'id': 'Abdul_Basit_Murattal_192kbps', 'name': 'Abdul Basit (Murattal)'},
    {'id': 'Husary_128kbps', 'name': 'Mahmoud Khalil Al-Husary'},
    {'id': 'Abdurrahmaan_As-Sudais_192kbps', 'name': 'Abdur-Rahman As-Sudais'},
    {'id': 'Ghamadi_40kbps', 'name': 'Saad Al-Ghamdi'},
    {'id': 'Abu_Bakr_Ash-Shaatree_128kbps', 'name': 'Abu Bakr Al-Shatri'},
    {'id': 'Ali_Jaber_64kbps', 'name': 'Ali Jaber'},
  ];

  String _getReciterName(String id) {
    final match = _reciterList.firstWhere((r) => r['id'] == id, orElse: () => {'name': 'Mishary Alafasy'});
    return match['name']!;
  }

  double _arabicFontSize = 24.0;
  String _arabicFont = 'Amiri'; // 'Amiri', 'Scheherazade New', 'Noto Naskh Arabic', 'Lateef', 'Katibeh'
  bool _showBanglaPronunciation = true;
  bool _showEnglishPronunciation = true;
  bool _showBanglaTranslation = true;
  bool _showEnglishTranslation = true;
  bool _showBanglaTafsir = true;
  bool _showEnglishTafsir = true;
  bool _isDarkMode = false;
  bool _readingReminderEnabled = true;

  TextStyle _getArabicStyle({double? fontSize, FontWeight? fontWeight, Color? color, double? height}) {
    final size = fontSize ?? _arabicFontSize;
    final wt = fontWeight ?? FontWeight.bold;
    final h = height ?? 1.8;
    switch (_arabicFont) {
      case 'Scheherazade New':
        return GoogleFonts.scheherazadeNew(fontSize: size, fontWeight: wt, color: color, height: h);
      case 'Noto Naskh Arabic':
        return GoogleFonts.notoNaskhArabic(fontSize: size, fontWeight: wt, color: color, height: h);
      case 'Lateef':
        return GoogleFonts.lateef(fontSize: size + 4, fontWeight: wt, color: color, height: h);
      case 'Katibeh':
        return GoogleFonts.katibeh(fontSize: size + 2, fontWeight: wt, color: color, height: h);
      case 'Amiri':
      default:
        return GoogleFonts.amiri(fontSize: size, fontWeight: wt, color: color, height: h);
    }
  }

  static String _translitToBangla(String englishTranslit) {
    if (englishTranslit.trim().isEmpty) return '';

    String text = englishTranslit.trim();

    final Map<String, String> wordMap = {
      'bismillahir': 'বিসমিল্লাহির',
      'bismillaahir': 'বিসমিল্লাহির',
      'rahmaanir': 'রাহমানির',
      'rahmaan': 'রাহমান',
      'raheem': 'রাহীম',
      'alhamdu': 'আলহামদু',
      'lillaahi': 'লিল্লাহি',
      'lillahi': 'লিল্লাহি',
      'rabbil': 'রাব্বিল',
      'aalameen': 'আলামীন',
      'maaliki': 'মালিকি',
      'yawmid-deen': 'ইয়াওমিদ-দ্বীন',
      'yawmiddin': 'ইয়াওমিদ-দ্বীন',
      'iyyaaka': 'ইয়্যাকা',
      'na\'budu': 'না\'বুদু',
      'wa': 'ওয়া',
      'nasta\'een': 'নাসতা\'ঈন',
      'ihdinas-siraatal-mustaqeem': 'ইহদিনাস সিরাতাল মুস্তাক্বীম',
      'ihdinas': 'ইহদিনাস',
      'siraatal': 'সিরাতাল',
      'siraata': 'সিরাতা',
      'mustaqeem': 'মুস্তাক্বীম',
      'al-mustaqeem': 'আল-মুস্তাক্বীম',
      'allazeena': 'আল্লাযীনা',
      'allazee': 'আল্লাযী',
      'lazeena': 'লাযীনা',
      'lazee': 'লাযী',
      'an\'amta': 'আন\'আমতা',
      'alayhim': 'আলাইহিম',
      'ghayril': 'গাইরিল',
      'maghdoobi': 'মাগদূবী',
      'lad-daalleen': 'লাদ-দোয়াল্লীন',
      'daalleen': 'দোয়াল্লীন',
      'qul': 'ক্বুল',
      'huwal': 'হুয়াল',
      'laahu': 'ল্লাহু',
      'laaha': 'ল্লাহা',
      'laahi': 'ল্লাহি',
      'allah': 'আল্লাহ',
      'allahu': 'আল্লাহু',
      'ahad': 'আহাদ',
      'samad': 'সামাদ',
      'lam': 'লাম',
      'yalid': 'য়ালিদ',
      'yoolad': 'য়ূলাদ',
      'yakul-lahu': 'ইয়াকুল-লাহু',
      'kufuwan': 'কুফুওয়ান',
      'wal-\'asr': 'ওয়াল-\'আসর',
      'innal': 'ইন্নাল',
      'insana': 'ইনসানা',
      'lafee': 'লাফী',
      'khusr': 'খুসর',
      'illal-lazeena': 'ইল্লাল্লাযীনা',
      'aamanoo': 'আমানূ',
      'amilus-saalihaati': '\'আমিলুস সালিহাত',
      'saalihaati': 'সালিহাত',
      'tawaasaw': 'তাওয়াসাও',
      'bil-haqqi': 'বিল-হাক্ব',
      'bis-sabr': 'বিস-সাবর',
      'yaaa': 'ইয়া',
      'aiyuhan': 'আইয়্যুহান',
      'naasut': 'নাসুত',
      'taqoo': 'তাক্বু',
      'rabbakumul': 'রাব্বাকুমুল',
      'khalaqakum': 'খালাক্বাকুম',
      'min': 'মিন',
      'nafsinw': 'নাফসিঁও',
      'waahidatinw': 'ওয়াহিদাতিঁও',
      'khalaqa': 'খালাক্বা',
      'minhaa': 'মিনহা',
      'zawjahaa': 'যাওজাহা',
      'bas': 'বাসসা',
      'sa': '',
      'minhumaa': 'মিনহুমা',
      'rijaalan': 'রিজালান',
      'kaseeranw': 'কাসীরাঁও',
      'nisaaa\'aa': 'নিসা-আ',
      'wattaqul': 'ওয়াত্তাক্বুল',
      'laahallazee': 'ল্লাহাল্লাযী',
      'tasaaa': 'তাসা-আ',
      '\'aloona': '\'আলূনা',
      'bihee': 'বিহী',
      'wal': 'ওয়াল',
      'arhaam': 'আরহাম',
      'kaana': 'কানা',
      '\'alaikum': '\'আলাইকুম',
      'raqeeba': 'রাক্বীবা',
    };

    final List<String> words = text.split(' ');
    final List<String> converted = [];

    for (final rawWord in words) {
      if (rawWord.trim().isEmpty) continue;
      String clean = rawWord.toLowerCase().replaceAll(RegExp(r"[^a-z0-9\-']"), '');
      String trailingPunct = '';
      if (rawWord.endsWith(';') || rawWord.endsWith(',') || rawWord.endsWith('.')) {
        trailingPunct = rawWord.substring(rawWord.length - 1);
      }

      if (wordMap.containsKey(clean)) {
        final bn = wordMap[clean]!;
        if (bn.isNotEmpty) {
          converted.add(bn + trailingPunct);
        }
        continue;
      }

      // Phonetic word builder
      String w = clean;
      w = w.replaceAll('sh', 'শ');
      w = w.replaceAll('kh', 'খ');
      w = w.replaceAll('gh', 'গ');
      w = w.replaceAll('th', 'ছ');
      w = w.replaceAll(RegExp(r'dh|zh|z'), 'য');
      w = w.replaceAll('q', 'ক্ব');
      w = w.replaceAll('k', 'ক');
      w = w.replaceAll('b', 'ব');
      w = w.replaceAll('t', 'ত');
      w = w.replaceAll('j', 'জ');
      w = w.replaceAll('h', 'হ');
      w = w.replaceAll('d', 'দ');
      w = w.replaceAll('r', 'র');
      w = w.replaceAll('s', 'স');
      w = w.replaceAll(RegExp(r'f|ph'), 'ফ');
      w = w.replaceAll('l', 'ল');
      w = w.replaceAll('m', 'ম');
      w = w.replaceAll('n', 'ন');
      w = w.replaceAll(RegExp(r'w|v'), 'ওয়');
      w = w.replaceAll('y', 'ইয়');
      w = w.replaceAll(RegExp(r'ee|iy|ii'), 'ী');
      w = w.replaceAll(RegExp(r'oo|uu'), 'ূ');
      w = w.replaceAll('aa', 'া');
      w = w.replaceAll(RegExp(r'ai|ay'), 'াই');
      w = w.replaceAll(RegExp(r'au|aw'), 'াও');
      w = w.replaceAll('a', 'া');
      w = w.replaceAll('i', 'ি');
      w = w.replaceAll('u', 'ু');
      w = w.replaceAll('o', 'ো');
      w = w.replaceAll('e', 'ে');

      // Fix leading vowel signs
      if (w.startsWith('া')) w = 'আ${w.substring(1)}';
      if (w.startsWith('ি') || w.startsWith('ী')) w = 'ই${w.substring(1)}';
      if (w.startsWith('ু') || w.startsWith('ূ')) w = 'উ${w.substring(1)}';
      if (w.startsWith('ে')) w = 'এ${w.substring(1)}';
      if (w.startsWith('ো')) w = 'ও${w.substring(1)}';
      if (w.startsWith('াই')) w = 'আই${w.substring(2)}';
      if (w.startsWith('াও')) w = 'আও${w.substring(2)}';

      converted.add(w + trailingPunct);
    }

    return converted.join(' ');
  }

  static String _phoneticEnglishPronunciation(String arabic) {
    if (arabic.isEmpty) return '';
    String res = arabic;
    res = res.replaceAll('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ', 'Bismillahir-Rahmanir-Rahim');
    res = res.replaceAll('الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ', 'Al-hamdu lillahi Rabbil-\'alamin');
    res = res.replaceAll('الرَّحْمَٰنِ الرَّحِيمِ', 'Ar-Rahmanir-Rahim');
    res = res.replaceAll('مَالِكِ يَوْمِ الدِّينِ', 'Maliki Yawmid-Din');
    res = res.replaceAll('إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ', 'Iyyaka na\'budu wa iyyaka nasta\'in');
    res = res.replaceAll('اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ', 'Ihdinas-Siratal-Mustaqim');
    res = res.replaceAll('صِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ الْمَغْضُوبِ عَلَيْهِمْ وَلَا الضَّالِّينَ', 'Siratal-ladhina an\'amta \'alayhim, ghayril-maghdubi \'alayhim walad-dallin');
    res = res.replaceAll('قُلْ هُوَ اللَّهُ أَحَدٌ', 'Qul Huwallahu Ahad');
    res = res.replaceAll('اللَّهُ الصَّمَدُ', 'Allahus-Samad');
    res = res.replaceAll('لَمْ يَلِدْ وَلَمْ يُولَدْ', 'Lam yalid wa lam yulad');
    res = res.replaceAll('وَلَمْ يَكُن لَّهُ كُফُوًا أَحَدٌ', 'Wa lam yakul-lahu kufuwan ahad');
    res = res.replaceAll('وَالْعَصْرِ', 'Wal-\'Asr');
    res = res.replaceAll('إِنَّ الْإِنْسَانَ لَفِي خُসْرٍ', 'Innal-insana lafi khusr');
    res = res.replaceAll('إِلَّا الَّذِينَ آمَنُوا وَعَمِلُوا الصَّالِحَاتِ وَتَوَاصَوْا بِالْحَقِّ وَتَوَاصَوْا بِالصَّবْرِ', 'Illal-ladhina amanu wa \'amilus-salihati wa tawasa bi-haqqi wa tawasa bis-sabr');
    return res == arabic ? '' : res;
  }

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = false;
          _isLoadingAudio = false;
          _currentlyPlayingSurah = null;
          _currentlyPlayingAyah = null;
        });
      }
    });
    _loadState();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlayAyahAudio(int surahId, int ayahNum) async {
    if (_isPlayingAudio && _currentlyPlayingSurah == surahId && _currentlyPlayingAyah == ayahNum) {
      await _audioPlayer.pause();
      setState(() => _isPlayingAudio = false);
      return;
    }

    setState(() {
      _isLoadingAudio = true;
      _currentlyPlayingSurah = surahId;
      _currentlyPlayingAyah = ayahNum;
    });

    try {
      final sStr = surahId.toString().padLeft(3, '0');
      final aStr = ayahNum.toString().padLeft(3, '0');
      final url = 'https://everyayah.com/data/$_selectedReciter/$sStr$aStr.mp3';

      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
      if (mounted) {
        setState(() {
          _isPlayingAudio = true;
          _isLoadingAudio = false;
        });
      }
    } catch (e) {
      debugPrint('Audio playback error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not play audio: $e')),
        );
        setState(() {
          _isPlayingAudio = false;
          _isLoadingAudio = false;
        });
      }
    }
  }

  Future<void> _stopAyahAudio() async {
    await _audioPlayer.stop();
    if (mounted) {
      setState(() {
        _isPlayingAudio = false;
        _isLoadingAudio = false;
        _currentlyPlayingSurah = null;
        _currentlyPlayingAyah = null;
      });
    }
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
        // Load profile user name
        final savedName = prefs.getString('profile_name');
        final currentUser = FirebaseAuth.instance.currentUser;
        if (savedName != null && savedName.trim().isNotEmpty) {
          _userName = savedName.trim();
        } else if (currentUser != null && currentUser.displayName != null && currentUser.displayName!.trim().isNotEmpty) {
          _userName = currentUser.displayName!.trim();
        } else if (currentUser != null && currentUser.email != null && currentUser.email!.trim().isNotEmpty) {
          final prefix = currentUser.email!.split('@').first;
          _userName = prefix.isNotEmpty ? (prefix[0].toUpperCase() + prefix.substring(1)) : 'User';
        } else {
          _userName = 'User';
        }

        if (currentUser != null) {
          FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get()
              .then((doc) {
            if (doc.exists && doc.data() != null) {
              final data = doc.data()!;
              String? name;
              if (data['profile'] is Map && data['profile']['fullName'] != null) {
                name = data['profile']['fullName'].toString();
              } else if (data['name'] != null) {
                name = data['name'].toString();
              } else if (data['fullName'] != null) {
                name = data['fullName'].toString();
              }
              if (name != null && name.trim().isNotEmpty && mounted) {
                setState(() {
                  _userName = name!.trim();
                });
                prefs.setString('profile_name', _userName);
              }
            }
          }).catchError((e) {
            debugPrint("Error fetching user name in Quran Tracker: $e");
          });
        }

        _currentStreak = prefs.getInt('quran_tracker_streak') ?? 0;
        _longestStreak = prefs.getInt('quran_longest_streak') ?? 0;
        
        _completedAyahsToday = prefs.getInt('quran_completed_ayahs_today') ?? 0;
        _targetDailyAyahs = prefs.getInt('quran_target_daily_ayahs') ?? 208;

        _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
        _arabicFont = prefs.getString('quran_arabic_font') ?? 'Amiri';
        _selectedReciter = prefs.getString('quran_selected_reciter') ?? 'Alafasy_128kbps';
        _showBanglaPronunciation = prefs.getBool('quran_show_bangla_pronunciation') ?? true;
        _showEnglishPronunciation = prefs.getBool('quran_show_english_pronunciation') ?? true;
        _showBanglaTranslation = prefs.getBool('quran_show_bangla_translation') ?? true;
        _showEnglishTranslation = prefs.getBool('quran_show_english_translation') ?? true;
        _showBanglaTafsir = prefs.getBool('quran_show_bangla_tafsir') ?? true;
        _showEnglishTafsir = prefs.getBool('quran_show_english_tafsir') ?? true;
        
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

        // Load weekly stats
        final weeklyStr = prefs.getString('quran_weekly_ayahs_history');
        if (weeklyStr != null) {
          final Map<String, dynamic> decoded = jsonDecode(weeklyStr);
          decoded.forEach((key, val) {
            _weeklyAyahsHistory[key] = (val as num).toInt();
          });
        }
        final todayShort = DateFormat('E').format(DateTime.now());
        if (_completedAyahsToday > 0) {
          _weeklyAyahsHistory[todayShort] = _completedAyahsToday;
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
    await prefs.setString('quran_arabic_font', _arabicFont);
    await prefs.setString('quran_selected_reciter', _selectedReciter);
    await prefs.setBool('quran_show_bangla_pronunciation', _showBanglaPronunciation);
    await prefs.setBool('quran_show_english_pronunciation', _showEnglishPronunciation);
    await prefs.setBool('quran_show_bangla_translation', _showBanglaTranslation);
    await prefs.setBool('quran_show_english_translation', _showEnglishTranslation);
    await prefs.setBool('quran_show_bangla_tafsir', _showBanglaTafsir);
    await prefs.setBool('quran_show_english_tafsir', _showEnglishTafsir);
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

    final todayShort = DateFormat('E').format(DateTime.now());
    _weeklyAyahsHistory[todayShort] = _completedAyahsToday;
    await prefs.setString('quran_weekly_ayahs_history', jsonEncode(_weeklyAyahsHistory));
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
      final translitUri  = Uri.parse('https://api.alquran.cloud/v1/surah/$surahId/en.transliteration');
      // Tafsir Ibn Kathir (id=169, English) & Tafsir Abu Bakr Zakaria / Ibn Kathir (id=166, Bangla)
      final engTafsirUri = Uri.parse('https://api.quran.com/api/v4/tafsirs/169/by_chapter/$surahId?per_page=300');
      final bnTafsirUri  = Uri.parse('https://api.quran.com/api/v4/tafsirs/166/by_chapter/$surahId?per_page=300');

      final responses = await Future.wait([
        http.get(arabicUri).timeout(const Duration(seconds: 8)),
        http.get(banglaUri).timeout(const Duration(seconds: 8)),
        http.get(englishUri).timeout(const Duration(seconds: 8)),
        http.get(translitUri).timeout(const Duration(seconds: 8)),
        http.get(engTafsirUri, headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 10)),
        http.get(bnTafsirUri,  headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 10)),
      ]);

      if (responses[0].statusCode == 200 &&
          responses[1].statusCode == 200 &&
          responses[2].statusCode == 200) {
        final arabicJson  = jsonDecode(responses[0].body);
        final banglaJson  = jsonDecode(responses[1].body);
        final englishJson = jsonDecode(responses[2].body);

        List<dynamic> translitAyahs = [];
        if (responses[3].statusCode == 200) {
          try {
            translitAyahs = (jsonDecode(responses[3].body))['data']['ayahs'] ?? [];
          } catch (_) {}
        }

        final List<dynamic> arabicAyahs  = arabicJson['data']['ayahs'];
        final List<dynamic> banglaAyahs  = banglaJson['data']['ayahs'];
        final List<dynamic> englishAyahs = englishJson['data']['ayahs'];

        // Populate tafsir caches from quran.com
        if (responses[4].statusCode == 200) {
          try {
            final List<dynamic> items = (jsonDecode(responses[4].body))['tafsirs'] ?? [];
            for (final t in items) {
              final k = t['verse_key']?.toString() ?? '';
              final v = t['text']?.toString() ?? '';
              if (k.isNotEmpty) _engTafsirCache[k] = _stripHtml(v);
            }
          } catch (_) {}
        }
        if (responses[5].statusCode == 200) {
          try {
            final List<dynamic> items = (jsonDecode(responses[5].body))['tafsirs'] ?? [];
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

          String engPronounce = '';
          if (i < translitAyahs.length) {
            engPronounce = translitAyahs[i]['text'] ?? '';
          }
          if (engPronounce.isEmpty) {
            engPronounce = _phoneticEnglishPronunciation(cleanArabic);
          }

          final bnPronounce = _translitToBangla(engPronounce);

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
            banglaPronunciation: bnPronounce,
            englishPronunciation: engPronounce,
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
          final ar = idx == 0 ? _cleanBismillahPrefix(item.arabic, surahId) : item.arabic;
          
          return AyahContent(
            number: item.number,
            arabic: ar,
            banglaPronunciation: item.banglaPronunciation.isNotEmpty ? item.banglaPronunciation : _translitToBangla(item.englishPronunciation.isNotEmpty ? item.englishPronunciation : _phoneticEnglishPronunciation(ar)),
            englishPronunciation: item.englishPronunciation.isNotEmpty ? item.englishPronunciation : _phoneticEnglishPronunciation(ar),
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
      final sampleArabic = 'وَإِذْ قَالَ رَبُّكَ لِلْمَلَائِكَةِ إِنِّي جَاعِلٌ فِي الْأَرْضِ خَلِيفَةً ($ayahNum)';

      return AyahContent(
        number: ayahNum,
        arabic: sampleArabic,
        banglaPronunciation: _translitToBangla('Wa idh qala rabbuka lil-mala\'ikati inni ja\'ilun fil-ardi khalifah'),
        englishPronunciation: 'Wa idh qala rabbuka lil-mala\'ikati inni ja\'ilun fil-ardi khalifah ($ayahNum)',
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
            'Assalamu Alaikum, $_userName',
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

          // Audio Tilawat Recitation Playback Bar
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (_isPlayingAudio && _currentlyPlayingAyah == currentAyah.number)
                  ? AppColors.midTeal.withValues(alpha: 0.14)
                  : cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (_isPlayingAudio && _currentlyPlayingAyah == currentAyah.number)
                    ? AppColors.midTeal.withValues(alpha: 0.45)
                    : Colors.grey.withValues(alpha: 0.15),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: () => _togglePlayAyahAudio(surah.id, currentAyah.number),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: (_isPlayingAudio && _currentlyPlayingAyah == currentAyah.number)
                          ? AppColors.midTeal
                          : AppColors.midTeal.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: (_isLoadingAudio && _currentlyPlayingAyah == currentAyah.number)
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(
                            (_isPlayingAudio && _currentlyPlayingAyah == currentAyah.number)
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: (_isPlayingAudio && _currentlyPlayingAyah == currentAyah.number)
                                ? Colors.white
                                : AppColors.midTeal,
                            size: 20,
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        (_isPlayingAudio && _currentlyPlayingAyah == currentAyah.number)
                            ? 'Playing Tilawat...'
                            : 'Listen Ayah Tilawat (Audio)',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: (_isPlayingAudio && _currentlyPlayingAyah == currentAyah.number)
                              ? AppColors.midTeal
                              : themeText,
                        ),
                      ),
                      Text(
                        'Qari: ${_getReciterName(_selectedReciter)} · Ayah ${currentAyah.number}',
                        style: GoogleFonts.inter(fontSize: 10, color: AppColors.placeholder),
                      ),
                    ],
                  ),
                ),
                if (_isPlayingAudio && _currentlyPlayingAyah == currentAyah.number)
                  IconButton(
                    tooltip: 'Stop',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.stop_circle_outlined, color: Colors.redAccent, size: 22),
                    onPressed: _stopAyahAudio,
                  ),
              ],
            ),
          ),

          // Sleek, ultra-thin Memorization Strip (Zero screen squeeze)
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isSurahMemorized
                  ? AppColors.midTeal.withValues(alpha: 0.12)
                  : cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSurahMemorized
                    ? AppColors.midTeal.withValues(alpha: 0.35)
                    : Colors.grey.withValues(alpha: 0.15),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isSurahMemorized ? Icons.check_circle_rounded : Icons.bookmark_border_rounded,
                      size: 14,
                      color: isSurahMemorized ? AppColors.midTeal : AppColors.placeholder,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isSurahMemorized ? 'Memorized in Hifz Map' : 'Not marked as memorized',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSurahMemorized ? AppColors.midTeal : AppColors.placeholder,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      if (isSurahMemorized) {
                        _memorizedSurahIds.remove(surah.id);
                      } else {
                        _memorizedSurahIds.add(surah.id);
                      }
                      _saveState();
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      isSurahMemorized ? 'Mark Not Done' : 'Mark Memorized',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: isSurahMemorized ? Colors.redAccent : AppColors.midTeal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Card(
                color: cardBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_activeReaderAyahIndex == 1 && surah.id != 9) ...[
                        Text(
                          'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                          textAlign: TextAlign.center,
                          style: _getArabicStyle(
                            fontSize: _arabicFontSize + 2,
                            fontWeight: FontWeight.bold,
                            color: AppColors.midTeal,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Divider(height: 1),
                        const SizedBox(height: 14),
                      ],
                      Text(
                        currentAyah.arabic,
                        textAlign: TextAlign.center,
                        style: _getArabicStyle(
                          fontSize: _arabicFontSize,
                          fontWeight: FontWeight.bold,
                          height: 1.8,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 14),

                      // 1. Bangla Pronunciation
                      if (_showBanglaPronunciation && currentAyah.banglaPronunciation.isNotEmpty) ...[
                        Text(
                          'Bangla Pronunciation',
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.midTeal),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentAyah.banglaPronunciation,
                          style: GoogleFonts.inter(fontSize: 12.5, height: 1.45, color: themeText),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // 2. English Pronunciation
                      if (_showEnglishPronunciation && currentAyah.englishPronunciation.isNotEmpty) ...[
                        Text(
                          'English Pronunciation',
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.midTeal),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentAyah.englishPronunciation,
                          style: GoogleFonts.inter(fontSize: 12.5, height: 1.45, color: themeText, fontStyle: FontStyle.italic),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // 3. Bangla Translation
                      if (_showBanglaTranslation && currentAyah.banglaTranslation.isNotEmpty) ...[
                        Text(
                          'Bangla Translation',
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.midTeal),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentAyah.banglaTranslation,
                          style: GoogleFonts.inter(fontSize: 13, height: 1.45, color: themeText),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // 4. English Translation
                      if (_showEnglishTranslation && currentAyah.englishTranslation.isNotEmpty) ...[
                        Text(
                          'English Translation',
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.midTeal),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentAyah.englishTranslation,
                          style: GoogleFonts.inter(fontSize: 13, height: 1.45, color: themeText),
                        ),
                        const SizedBox(height: 14),
                      ],

                      const Divider(height: 1),
                      const SizedBox(height: 14),

                      // 5. Bangla Tafsir
                      if (_showBanglaTafsir && currentAyah.banglaExplanation.isNotEmpty) ...[
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
                                  'Bangla Tafsir',
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

                      // 6. English Tafsir
                      if (_showEnglishTafsir && currentAyah.englishExplanation.isNotEmpty) ...[
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
                                  'English Tafsir',
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
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Bottom Navigation Row with distinct Manual "Mark as Read" action
          Builder(
            builder: (context) {
              final ayahKey = '${surah.id}_$_activeReaderAyahIndex';
              final isCurrentAyahRead = _readAyahsToday.contains(ayahKey);

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _activeReaderAyahIndex > 1
                        ? () => setState(() {
                            _activeReaderAyahIndex--;
                            _continueAyah = _activeReaderAyahIndex;
                            _continueSurahId = surah.id;
                            _saveState();
                          })
                        : null,
                    child: Text('← Prev', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),

                  // Explicit "Mark as Read" toggle button (Doesn't falsely add when just browsing)
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (isCurrentAyahRead) {
                          _readAyahsToday.remove(ayahKey);
                          if (_completedAyahsToday > 0) _completedAyahsToday--;
                        } else {
                          _readAyahsToday.add(ayahKey);
                          _completedAyahsToday++;
                          if (!_readAyahsAllTime.contains(ayahKey)) {
                            _readAyahsAllTime.add(ayahKey);
                            _khatmTotalJuzCompleted = ((_readAyahsAllTime.length / 6236.0) * 30).floor();
                            if (_khatmTotalJuzCompleted > 30) _khatmTotalJuzCompleted = 30;
                          }
                        }
                        _saveState();
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isCurrentAyahRead
                            ? Colors.green.withValues(alpha: 0.15)
                            : cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isCurrentAyahRead ? Colors.green : Colors.grey.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCurrentAyahRead ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            size: 14,
                            color: isCurrentAyahRead ? Colors.green : AppColors.placeholder,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isCurrentAyahRead ? 'Read Today' : 'Mark as Read',
                            style: GoogleFonts.poppins(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: isCurrentAyahRead ? Colors.green : themeText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  GestureDetector(
                    onTap: () => _showWheelPagePickerModal(context, cardBg, themeText),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.midTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.midTeal.withValues(alpha: 0.30)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.unfold_more_rounded, size: 14, color: AppColors.midTeal),
                          const SizedBox(width: 2),
                          Text(
                            '$_activeReaderAyahIndex / ${_loadedAyahs.length}',
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.midTeal),
                          ),
                        ],
                      ),
                    ),
                  ),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navyBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                        _saveState();
                      });
                    },
                    child: Text(
                      _activeReaderAyahIndex == _loadedAyahs.length ? 'Finish' : 'Next →',
                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              );
            },
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
                Tab(child: Text('Sunnah Wazifa', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12))),
                Tab(child: Text('Morning', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12))),
                Tab(child: Text('Evening', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12))),
                Tab(child: Text('Before Sleep', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12))),
                Tab(child: Text('After Salah', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12))),
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
      padding: const EdgeInsets.all(14),
      itemCount: _hadithWazifaList.length,
      itemBuilder: (ctx, idx) {
        final w = _hadithWazifaList[idx];
        final val = _completedHadithWazifas[w.title] ?? false;

        final itemBorder = _isDarkMode ? BorderSide.none : const BorderSide(color: Color(0xFFE2E8F0));
        return Card(
          color: _isDarkMode ? cardBg : Colors.white,
          elevation: _isDarkMode ? 0 : 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: itemBorder),
          margin: const EdgeInsets.only(bottom: 10),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
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
            title: Text(w.title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12.5, color: themeText)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('Virtues: ${w.targetDay} • Count: ${w.recitationCount}', style: GoogleFonts.inter(fontSize: 10, color: AppColors.placeholder, height: 1.3)),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Divider(height: 16),
                    Text('Virtues & Benefit:', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                    const SizedBox(height: 2),
                    Text(w.benefitEnglish, style: GoogleFonts.inter(fontSize: 11, color: themeText, height: 1.4)),
                    const SizedBox(height: 8),
                    Text('Hadith Reference:', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.placeholder)),
                    const SizedBox(height: 2),
                    Text(w.hadithReference, style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.placeholder, fontStyle: FontStyle.italic)),
                    
                    if (w.surahId != null) ...[
                      const SizedBox(height: 10),
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
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.menu_book_rounded, size: 14, color: Colors.white),
                        label: Text(
                          'Read Surah in Quran Reader',
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
                    ],

                    if (w.arabicText != null) ...[
                      const Divider(height: 20),
                      Text('Arabic Verse:', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF8FAFC),
                          border: Border.all(color: _isDarkMode ? const Color(0xFF3C3C3C) : const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: SelectableText(
                          w.arabicText!,
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          style: GoogleFonts.amiri(
                            fontSize: 15.5,
                            height: 1.7,
                            color: _isDarkMode ? Colors.white : AppColors.navyBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],

                    if (w.englishPronunciation != null) ...[
                      const SizedBox(height: 8),
                      Text('English Transliteration:', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                      const SizedBox(height: 2),
                      Text(w.englishPronunciation!, style: GoogleFonts.inter(fontSize: 11, color: themeText, height: 1.4)),
                    ],

                    if (w.englishTranslation != null) ...[
                      const SizedBox(height: 8),
                      Text('English Meaning:', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                      const SizedBox(height: 2),
                      Text(w.englishTranslation!, style: GoogleFonts.inter(fontSize: 11, color: themeText, height: 1.4)),
                    ],

                    if (w.readingRules != null) ...[
                      const SizedBox(height: 8),
                      Text('Instructions & Rules:', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.coralOrange)),
                      const SizedBox(height: 2),
                      Text(w.readingRules!, style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.placeholder, fontStyle: FontStyle.italic, height: 1.35)),
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
        padding: const EdgeInsets.all(14),
        itemCount: list.length,
        itemBuilder: (ctx, idx) {
          final wazifa = list[idx];
          final val = _completedWazifas['${category}_${wazifa.title}'] ?? false;

          final hasDetails = wazifa.arabicText != null ||
              wazifa.englishPronunciation != null ||
              wazifa.englishTranslation != null ||
              wazifa.readingRules != null ||
              wazifa.benefitEnglish != null;

          final itemBorder = _isDarkMode ? BorderSide.none : const BorderSide(color: Color(0xFFE2E8F0));
          return Card(
            color: _isDarkMode ? cardBg : Colors.white,
            elevation: _isDarkMode ? 0 : 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: itemBorder),
            margin: const EdgeInsets.only(bottom: 10),
            child: hasDetails
                ? ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
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
                    title: Text(wazifa.title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12.5, color: themeText)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('Virtues & Supplication Details (Tap to expand)', style: GoogleFonts.inter(fontSize: 10, color: AppColors.placeholder, height: 1.3)),
                    ),
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
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (wazifa.benefitEnglish != null) ...[
                              const Divider(height: 16),
                              Text('Virtues & Benefit:', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                              const SizedBox(height: 2),
                              Text(wazifa.benefitEnglish!, style: GoogleFonts.inter(fontSize: 11, color: themeText, height: 1.4)),
                            ],
                            if (wazifa.arabicText != null) ...[
                              const Divider(height: 16),
                              Text('Arabic Verse:', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF8FAFC),
                                  border: Border.all(color: _isDarkMode ? const Color(0xFF3C3C3C) : const Color(0xFFE2E8F0)),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: SelectableText(
                                  wazifa.arabicText!,
                                  textAlign: TextAlign.right,
                                  textDirection: TextDirection.rtl,
                                  style: GoogleFonts.amiri(
                                    fontSize: 15.5,
                                    height: 1.7,
                                    color: _isDarkMode ? Colors.white : AppColors.navyBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                            if (wazifa.englishPronunciation != null) ...[
                              const SizedBox(height: 8),
                              Text('English Transliteration:', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                              const SizedBox(height: 2),
                              Text(wazifa.englishPronunciation!, style: GoogleFonts.inter(fontSize: 11, color: themeText, height: 1.4)),
                            ],
                            if (wazifa.englishTranslation != null) ...[
                              const SizedBox(height: 8),
                              Text('English Meaning:', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                              const SizedBox(height: 2),
                              Text(wazifa.englishTranslation!, style: GoogleFonts.inter(fontSize: 11, color: themeText, height: 1.4)),
                            ],
                            if (wazifa.readingRules != null) ...[
                              const SizedBox(height: 8),
                              Text('Instructions & Rules:', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.coralOrange)),
                              const SizedBox(height: 2),
                              Text(wazifa.readingRules!, style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.placeholder, fontStyle: FontStyle.italic, height: 1.35)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  )
                : ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
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
                    title: Text(wazifa.title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12.5, color: themeText)),
                    subtitle: Text('Supplication Checklist entry', style: GoogleFonts.inter(fontSize: 10, color: AppColors.placeholder)),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String searchQuery = '';
        String selectedFilterTag = 'All';
        final titleController = TextEditingController();
        final arabicController = TextEditingController();
        final pronunciationController = TextEditingController();
        final translationController = TextEditingController();
        final rulesController = TextEditingController();

        final quickTags = [
          'All',
          'Rizq',
          'Forgiveness',
          'Protection',
          'Healing',
          'Anxiety',
          'Parents',
          'Prayer',
          'Knowledge',
          'Sleep',
        ];

        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final fieldColor = _isDarkMode ? Colors.white : AppColors.navyBlue;
            final sheetBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
            final cardBg = _isDarkMode ? const Color(0xFF2A2A2A) : Colors.white;
            final itemBorderColor = _isDarkMode ? const Color(0xFF383838) : const Color(0xFFE2E8F0);

            final filteredDuas = _authenticDuasDatabase.where((item) {
              final query = searchQuery.trim().toLowerCase();
              final matchesQuery = query.isEmpty ||
                  item.title.toLowerCase().contains(query) ||
                  item.arabicText.contains(query) ||
                  item.englishPronunciation.toLowerCase().contains(query) ||
                  item.englishTranslation.toLowerCase().contains(query) ||
                  item.benefitEnglish.toLowerCase().contains(query) ||
                  item.hadithReference.toLowerCase().contains(query) ||
                  item.tags.any((t) => t.toLowerCase().contains(query));

              final matchesTag = selectedFilterTag == 'All' ||
                  item.tags.any((t) => t.toLowerCase().contains(selectedFilterTag.toLowerCase()));

              return matchesQuery && matchesTag;
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.placeholder.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.midTeal.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.auto_awesome_rounded, color: AppColors.midTeal, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Add Supplication from Catalog',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: fieldColor),
                                ),
                                Text(
                                  'Routine Category: $category',
                                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.placeholder),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () => Navigator.pop(modalCtx),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TabBar(
                      indicatorColor: AppColors.midTeal,
                      labelColor: AppColors.midTeal,
                      unselectedLabelColor: AppColors.placeholder,
                      indicatorWeight: 3,
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.search_rounded, size: 16),
                              const SizedBox(width: 6),
                              Text('Dua Catalog', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.edit_note_rounded, size: 18),
                              const SizedBox(width: 6),
                              Text('Custom Entry', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                                child: TextField(
                                  onChanged: (val) {
                                    setModalState(() {
                                      searchQuery = val;
                                    });
                                  },
                                  style: TextStyle(color: fieldColor, fontSize: 13),
                                   decoration: InputDecoration(
                                    hintText: 'Search Supplications (e.g., Forgiveness, Rizq, Protection, Health)...',
                                    hintStyle: TextStyle(color: AppColors.placeholder.withValues(alpha: 0.7), fontSize: 12.5),
                                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.midTeal, size: 20),
                                    suffixIcon: searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear_rounded, size: 18),
                                            onPressed: () {
                                              setModalState(() {
                                                searchQuery = '';
                                              });
                                            },
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: cardBg,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.midTeal.withValues(alpha: 0.35))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.midTeal.withValues(alpha: 0.35))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.midTeal, width: 1.5)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  ),
                                ),
                              ),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                child: Row(
                                  children: quickTags.map((tag) {
                                    final isSelected = selectedFilterTag == tag;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: ChoiceChip(
                                        label: Text(
                                          tag,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            color: isSelected ? Colors.white : fieldColor,
                                          ),
                                        ),
                                        selected: isSelected,
                                        selectedColor: AppColors.midTeal,
                                        backgroundColor: cardBg,
                                        onSelected: (val) {
                                          if (val) {
                                            setModalState(() {
                                              selectedFilterTag = tag;
                                            });
                                          }
                                        },
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              const Divider(height: 16),
                              Expanded(
                                child: filteredDuas.isEmpty
                                    ? Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(24),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.search_off_rounded, size: 48, color: AppColors.placeholder.withValues(alpha: 0.5)),
                                              const SizedBox(height: 10),
                                              Text(
                                                'No matching supplication found',
                                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.placeholder),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Try searching another keyword or create a custom entry in the next tab.',
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.placeholder),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    : ListView.builder(
                                        physics: const BouncingScrollPhysics(),
                                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                                        itemCount: filteredDuas.length,
                                        itemBuilder: (itemCtx, idx) {
                                          final dua = filteredDuas[idx];
                                          final isAlreadyAdded = (_wazifaSupplications[category] ?? [])
                                              .any((w) => w.title == dua.title);

                                            return Card(
                                              color: cardBg,
                                              margin: const EdgeInsets.only(bottom: 10),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: itemBorderColor)),
                                              child: Theme(
                                                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                                child: ExpansionTile(
                                                  tilePadding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                                                  trailing: const SizedBox.shrink(),
                                                  title: Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              dua.title,
                                                              maxLines: 2,
                                                              overflow: TextOverflow.ellipsis,
                                                              style: GoogleFonts.poppins(
                                                                fontWeight: FontWeight.w600,
                                                                fontSize: 12,
                                                                color: fieldColor,
                                                                height: 1.3,
                                                              ),
                                                            ),
                                                            const SizedBox(height: 4),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: AppColors.midTeal.withValues(alpha: 0.15),
                                                                borderRadius: BorderRadius.circular(6),
                                                              ),
                                                              child: Text(
                                                                dua.hadithReference,
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                                style: GoogleFonts.inter(fontSize: 9.0, fontWeight: FontWeight.w600, color: AppColors.midTeal),
                                                              ),
                                                            ),
                                                            const SizedBox(height: 4),
                                                            Text(
                                                              dua.benefitEnglish,
                                                              maxLines: 2,
                                                              overflow: TextOverflow.ellipsis,
                                                              style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.placeholder, height: 1.35),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Column(
                                                        mainAxisSize: MainAxisSize.min,
                                                        crossAxisAlignment: CrossAxisAlignment.end,
                                                        children: [
                                                          isAlreadyAdded
                                                              ? Container(
                                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                                                  decoration: BoxDecoration(
                                                                    color: Colors.green.withValues(alpha: 0.15),
                                                                    borderRadius: BorderRadius.circular(8),
                                                                  ),
                                                                  child: Row(
                                                                    mainAxisSize: MainAxisSize.min,
                                                                    children: [
                                                                      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 12),
                                                                      const SizedBox(width: 3),
                                                                      Text(
                                                                        'Added',
                                                                        style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.green),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                )
                                                              : SizedBox(
                                                                  height: 30,
                                                                  child: ElevatedButton.icon(
                                                                    onPressed: () {
                                                                      setState(() {
                                                                        _wazifaSupplications.putIfAbsent(category, () => []).add(dua.toCustomWazifa());
                                                                        _saveState();
                                                                      });
                                                                      Navigator.pop(modalCtx);
                                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                                        SnackBar(
                                                                          backgroundColor: AppColors.navyBlue,
                                                                          behavior: SnackBarBehavior.floating,
                                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                                          content: Row(
                                                                            children: [
                                                                              const Icon(Icons.check_circle_rounded, color: AppColors.midTeal, size: 18),
                                                                              const SizedBox(width: 8),
                                                                              Expanded(
                                                                                child: Text(
                                                                                  '"${dua.title}" added to your $category routine!',
                                                                                  style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.white),
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        ),
                                                                      );
                                                                    },
                                                                    style: ElevatedButton.styleFrom(
                                                                      backgroundColor: AppColors.midTeal,
                                                                      foregroundColor: Colors.white,
                                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                                      elevation: 0,
                                                                    ),
                                                                    icon: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                                                                    label: Text(
                                                                      'Add',
                                                                      style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white),
                                                                    ),
                                                                  ),
                                                                ),
                                                          const SizedBox(height: 6),
                                                          const Padding(
                                                            padding: EdgeInsets.only(right: 4),
                                                            child: Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.placeholder),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                  children: [
                                                   Padding(
                                                     padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                                                     child: Column(
                                                       crossAxisAlignment: CrossAxisAlignment.stretch,
                                                       children: [
                                                         const Divider(height: 16),
                                                         Text('Arabic Verse:', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                                                         const SizedBox(height: 4),
                                                         Container(
                                                           padding: const EdgeInsets.all(10),
                                                           decoration: BoxDecoration(
                                                             color: _isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF8FAFC),
                                                             border: Border.all(color: _isDarkMode ? const Color(0xFF3C3C3C) : const Color(0xFFE2E8F0)),
                                                             borderRadius: BorderRadius.circular(10),
                                                           ),
                                                           child: SelectableText(
                                                             dua.arabicText,
                                                             textAlign: TextAlign.right,
                                                             textDirection: TextDirection.rtl,
                                                             style: GoogleFonts.amiri(
                                                               fontSize: 15.5,
                                                               height: 1.7,
                                                               fontWeight: FontWeight.bold,
                                                               color: _isDarkMode ? Colors.white : AppColors.navyBlue,
                                                             ),
                                                           ),
                                                         ),
                                                         const SizedBox(height: 8),
                                                         Text('English Transliteration:', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                                                         const SizedBox(height: 2),
                                                         Text(dua.englishPronunciation, style: GoogleFonts.inter(fontSize: 11, color: fieldColor, height: 1.4)),
                                                         const SizedBox(height: 8),
                                                         Text('English Meaning:', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                                                         const SizedBox(height: 2),
                                                         Text(dua.englishTranslation, style: GoogleFonts.inter(fontSize: 11, color: fieldColor, height: 1.4)),
                                                         const SizedBox(height: 8),
                                                         Text('Instructions & Rules:', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.coralOrange)),
                                                         const SizedBox(height: 2),
                                                          Text(dua.readingRules, style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.placeholder, fontStyle: FontStyle.italic, height: 1.35)),
                                                        ],
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
                                  ),
                                  SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('Supplication Title*', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.midTeal)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: titleController,
                                  style: TextStyle(color: fieldColor),
                                  decoration: InputDecoration(
                                    hintText: 'e.g: Morning Protection Supplication',
                                    hintStyle: TextStyle(color: AppColors.placeholder.withValues(alpha: 0.7), fontSize: 12.5),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text('Arabic Text [Optional]', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.midTeal)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: arabicController,
                                  maxLines: 2,
                                  textDirection: TextDirection.rtl,
                                  style: GoogleFonts.amiri(fontSize: 16, color: fieldColor),
                                  decoration: InputDecoration(
                                    hintText: 'أدخل النص العربي...',
                                    hintStyle: TextStyle(color: AppColors.placeholder.withValues(alpha: 0.7), fontSize: 12.5),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text('English Transliteration [Optional]', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.midTeal)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: pronunciationController,
                                  maxLines: 2,
                                  style: TextStyle(color: fieldColor),
                                  decoration: InputDecoration(
                                    hintText: 'Write English pronunciation...',
                                    hintStyle: TextStyle(color: AppColors.placeholder.withValues(alpha: 0.7), fontSize: 12.5),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text('English Meaning / Translation [Optional]', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.midTeal)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: translationController,
                                  maxLines: 3,
                                  style: TextStyle(color: fieldColor),
                                  decoration: InputDecoration(
                                    hintText: 'Write English translation...',
                                    hintStyle: TextStyle(color: AppColors.placeholder.withValues(alpha: 0.7), fontSize: 12.5),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text('Instructions & Virtues [Optional]', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.midTeal)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: rulesController,
                                  maxLines: 2,
                                  style: TextStyle(color: fieldColor),
                                  decoration: InputDecoration(
                                    hintText: 'e.g: Recite 3 times after Fajr prayer...',
                                    hintStyle: TextStyle(color: AppColors.placeholder.withValues(alpha: 0.7), fontSize: 12.5),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    final title = titleController.text.trim();
                                    if (title.isNotEmpty) {
                                      final newWazifa = CustomWazifa(
                                        title: title,
                                        benefitEnglish: rulesController.text.trim().isNotEmpty
                                            ? rulesController.text.trim()
                                            : (translationController.text.trim().isNotEmpty
                                                ? translationController.text.trim()
                                                : 'Custom User Added Supplication'),
                                        arabicText: arabicController.text.trim().isNotEmpty ? arabicController.text.trim() : null,
                                        englishPronunciation: pronunciationController.text.trim().isNotEmpty ? pronunciationController.text.trim() : null,
                                        englishTranslation: translationController.text.trim().isNotEmpty ? translationController.text.trim() : null,
                                        readingRules: rulesController.text.trim().isNotEmpty ? rulesController.text.trim() : null,
                                      );
                                      setState(() {
                                        _wazifaSupplications.putIfAbsent(category, () => []).add(newWazifa);
                                        _saveState();
                                      });
                                      Navigator.pop(modalCtx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: AppColors.navyBlue,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          content: Row(
                                            children: [
                                              const Icon(Icons.check_circle_rounded, color: AppColors.midTeal, size: 18),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  '"$title" added to your $category routine!',
                                                  style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.white),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.navyBlue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  icon: const Icon(Icons.check_rounded, color: Colors.white),
                                  label: Text(
                                    'Add to Daily Routine',
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

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

                // Fully Functional Live Weekly Consistency Bar Chart
                Builder(
                  builder: (context) {
                    final todayName = DateFormat('E').format(DateTime.now());
                    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                    
                    int maxVal = 1;
                    for (final d in days) {
                      final v = _weeklyAyahsHistory[d] ?? 0;
                      if (v > maxVal) maxVal = v;
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: days.map((d) {
                        final val = _weeklyAyahsHistory[d] ?? 0;
                        final isToday = d == todayName;
                        final double factor = maxVal > 0 ? (val / maxVal).clamp(0.12, 1.0) * 8.0 : 1.0;
                        final Color barColor = isToday
                            ? (val > 0 ? AppColors.coralOrange : AppColors.midTeal)
                            : (val > 0 ? AppColors.midTeal : AppColors.placeholder.withValues(alpha: 0.25));

                        return _buildStatsBarItem(d, factor, barColor, val);
                      }).toList(),
                    );
                  },
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

  Widget _buildStatsBarItem(String day, double heightFactor, Color color, [int? realCount]) {
    final displayNum = realCount ?? (heightFactor * 2).toInt();
    return Column(
      children: [
        Text(
          '$displayNum',
          style: GoogleFonts.poppins(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: displayNum > 0 ? color : AppColors.placeholder.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 26,
          height: (heightFactor * 10).clamp(10.0, 90.0),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          day,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.placeholder,
          ),
        ),
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
    const arabicFonts = [
      {'name': 'Amiri', 'label': 'Amiri'},
      {'name': 'Scheherazade New', 'label': 'Scheherazade'},
      {'name': 'Noto Naskh Arabic', 'label': 'Noto Naskh'},
      {'name': 'Lateef', 'label': 'Lateef'},
      {'name': 'Katibeh', 'label': 'Katibeh'},
    ];

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
              // Quran Reciter (Tilawat) Selection
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quran Reciter',
                          style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _selectedReciter,
                    dropdownColor: cardBg,
                    underline: const SizedBox(),
                    isDense: true,
                    items: _reciterList.map((r) {
                      return DropdownMenuItem<String>(
                        value: r['id']!,
                        child: Text(
                          r['name']!,
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: themeText),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedReciter = val);
                        _saveState();
                      }
                    },
                  ),
                ],
              ),
              const Divider(height: 16),

              // Arabic Font Selection (Zero pixel overflow)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Arabic Quran Font',
                      style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _arabicFont,
                    dropdownColor: cardBg,
                    underline: const SizedBox(),
                    isDense: true,
                    items: arabicFonts.map((f) {
                      return DropdownMenuItem<String>(
                        value: f['name']!,
                        child: Text(
                          f['label']!,
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: themeText),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _arabicFont = val);
                        _saveState();
                      }
                    },
                  ),
                ],
              ),
              const Divider(height: 16),

              // Arabic Font Size
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Arabic Font Size', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () {
                          setState(() => _arabicFontSize = (_arabicFontSize - 2).clamp(16.0, 36.0));
                          _saveState();
                        },
                      ),
                      Text('${_arabicFontSize.toInt()}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () {
                          setState(() => _arabicFontSize = (_arabicFontSize + 2).clamp(16.0, 36.0));
                          _saveState();
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 16),

              // Pronunciation Options (Clean English titles without brackets)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Bangla Pronunciation', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold)),
                value: _showBanglaPronunciation,
                activeTrackColor: AppColors.midTeal.withValues(alpha: 0.5),
                activeThumbColor: AppColors.midTeal,
                onChanged: (v) {
                  setState(() => _showBanglaPronunciation = v);
                  _saveState();
                },
              ),
              const Divider(height: 16),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('English Pronunciation', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold)),
                value: _showEnglishPronunciation,
                activeTrackColor: AppColors.midTeal.withValues(alpha: 0.5),
                activeThumbColor: AppColors.midTeal,
                onChanged: (v) {
                  setState(() => _showEnglishPronunciation = v);
                  _saveState();
                },
              ),
              const Divider(height: 16),

              // Translation Options (Clean English titles)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Bangla Translation', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold)),
                value: _showBanglaTranslation,
                activeTrackColor: AppColors.midTeal.withValues(alpha: 0.5),
                activeThumbColor: AppColors.midTeal,
                onChanged: (v) {
                  setState(() => _showBanglaTranslation = v);
                  _saveState();
                },
              ),
              const Divider(height: 16),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('English Translation', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold)),
                value: _showEnglishTranslation,
                activeTrackColor: AppColors.midTeal.withValues(alpha: 0.5),
                activeThumbColor: AppColors.midTeal,
                onChanged: (v) {
                  setState(() => _showEnglishTranslation = v);
                  _saveState();
                },
              ),
              const Divider(height: 16),

              // Tafsir Options (Clean English titles, no extra subtitles)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Bangla Tafsir', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold)),
                value: _showBanglaTafsir,
                activeTrackColor: AppColors.coralOrange.withValues(alpha: 0.5),
                activeThumbColor: AppColors.coralOrange,
                onChanged: (v) {
                  setState(() => _showBanglaTafsir = v);
                  _saveState();
                },
              ),
              const Divider(height: 16),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('English Tafsir', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold)),
                value: _showEnglishTafsir,
                activeTrackColor: AppColors.coralOrange.withValues(alpha: 0.5),
                activeThumbColor: AppColors.coralOrange,
                onChanged: (v) {
                  setState(() => _showEnglishTafsir = v);
                  _saveState();
                },
              ),
              const Divider(height: 16),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Daily Reading Reminder', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold)),
                value: _readingReminderEnabled,
                activeTrackColor: AppColors.midTeal.withValues(alpha: 0.5),
                activeThumbColor: AppColors.midTeal,
                onChanged: (v) {
                  setState(() => _readingReminderEnabled = v);
                  _saveState();
                },
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