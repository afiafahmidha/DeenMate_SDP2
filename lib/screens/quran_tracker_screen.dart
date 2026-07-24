import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
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

  const AyahContent({
    required this.number,
    required this.arabic,
    required this.banglaTranslation,
    required this.englishTranslation,
    required this.banglaExplanation,
    required this.englishExplanation,
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

  const HadithWazifa({
    required this.title,
    required this.recitationCount,
    required this.benefitBangla,
    required this.benefitEnglish,
    required this.hadithReference,
    required this.targetDay,
  });
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
    HadithWazifa(
      title: 'Surah Al-Kahf',
      recitationCount: '1 Time',
      benefitBangla: 'জুমা দিন সূরা কাহাফ তিলাওয়াত করলে এক জুমা থেকে অন্য জুমা পর্যন্ত নূর প্রজ্বলিত থাকে।',
      benefitEnglish: 'Shines a light of guidance for the reciter between this Friday and the next.',
      hadithReference: 'Al-Hakim, Sahih Al-Jami\' (6470)',
      targetDay: 'Friday',
    ),
    HadithWazifa(
      title: 'Surah Ad-Dukhan',
      recitationCount: '7 Times (recommended)',
      benefitBangla: 'জুমার রাতে (বৃহস্পতিবার দিনগত রাতে) সূরা আদ-দুখান পাঠ করলে সকালের মধ্যে সকল পাপ ক্ষমা করা হয়।',
      benefitEnglish: 'Reciting it on Friday eve/Thursday night secures forgiveness by the morning.',
      hadithReference: 'Sunan At-Tirmidhi (2889)',
      targetDay: 'Thursday Night',
    ),
    HadithWazifa(
      title: 'Surah Al-Mulk',
      recitationCount: '1 Time',
      benefitBangla: 'প্রতি রাতে এই সূরা তিলাওয়াতকারীকে কবরের আযাব থেকে রক্ষা করতে আল্লাহর কাছে সুপারিশ করে।',
      benefitEnglish: 'Intercedes for the reader until all their sins are forgiven and protects from grave punishment.',
      hadithReference: 'Tirmidhi (2891), Abu Dawud (1400)',
      targetDay: 'Every Night',
    ),
    HadithWazifa(
      title: 'Surah Ya-Sin',
      recitationCount: '1 Time',
      benefitBangla: 'সকালবেলা সূরা ইয়াসীন পাঠ করলে সারা দিনের সমস্ত জাগতিক ও আত্মিক প্রয়োজন পূরণ করা হয়।',
      benefitEnglish: 'Reciting at the beginning of the day ensures all needs are fulfilled.',
      hadithReference: 'Sunan Ad-Darimi (3418)',
      targetDay: 'Everyday / Thursday Night',
    ),
    HadithWazifa(
      title: 'Ayatul Kursi',
      recitationCount: '1 Time',
      benefitBangla: 'ফরজ সালাত শেষে পাঠ করলে জান্নাতে প্রবেশের পথে কেবল মৃত্যুই বাধা হয়ে থাকে।',
      benefitEnglish: 'Recited after obligatory prayers, nothing stands between the servant and Paradise except death.',
      hadithReference: 'Sunan An-Nasa\'i (9928)',
      targetDay: 'After Obligatory Salah',
    ),
    HadithWazifa(
      title: 'Last 2 Ayahs of Al-Baqarah',
      recitationCount: '1 Time',
      benefitBangla: 'রাতে এই আয়াত দুটি তিলাওয়াত করলে তা সমস্ত অনিষ্ট ও জিন-শয়তানের ক্ষতি থেকে বাঁচার জন্য যথেষ্ট হয়।',
      benefitEnglish: 'Recited at night, it serves as a sufficient protection against all harms.',
      hadithReference: 'Sahih Al-Bukhari (5009)',
      targetDay: 'Every Night (Before Sleep)',
    ),
  ];

  // RESET Default Starting States (0 Completed metrics for a clean starting experience)
  int _currentStreak = 0;
  int _longestStreak = 0;
  int _targetDailyPages = 5;
  int _completedPagesToday = 0;
  int _khatmTotalJuzCompleted = 0;
  String _khatmEstimatedCompletion = 'Not Configured';
  int _khatmTargetDays = 30; // Planner target

  // Continue Reading Reference
  int _continueSurahId = 1; // Al-Fatihah
  int _continuePage = 1;
  int _continueAyah = 1;

  // Search Filter
  String _searchQuery = '';
  final bool _ramadanMode = false;

  // Wazifa Custom checks state
  final Map<String, List<String>> _wazifaSupplications = {
    'Morning': ['Ayatul Kursi', 'Surah Ikhlas x3', 'Surah Falaq x3', 'Surah Nas x3'],
    'Evening': ['Ayatul Kursi', 'Surah Ikhlas', 'Surah Falaq', 'Surah Nas'],
    'Before Sleep': ['Surah Al-Mulk', 'Last 2 Ayah of Al-Baqarah'],
    'After Salah': ['Tasbih (33x)', 'Tahmid (33x)', 'Takbir (34x)'],
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

  String _cleanBismillahPrefix(String text, int surahId) {
    if (surahId == 1 || surahId == 9) return text;
    final endKeywords = ['الرَّحِيمِ', 'ٱلرَّحِيمِ', 'الرَّحِيْمِ', 'الرَّحِيم', 'ٱلرَّحِيم'];
    for (final keyword in endKeywords) {
      final idx = text.indexOf(keyword);
      if (idx != -1 && idx < 65) {
        return text.substring(idx + keyword.length).trim();
      }
    }
    return text;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // SAFE GENERATOR
  // ─────────────────────────────────────────────────────────────────────────────
  List<AyahContent> _generateSurahContent(int surahId, int totalAyahs) {
    if (_realQuranText.containsKey(surahId)) {
      final list = _realQuranText[surahId]!;
      if (list.length == totalAyahs) {
        return List.generate(list.length, (idx) {
          final item = list[idx];
          if (idx == 0) {
            return AyahContent(
              number: item.number,
              arabic: _cleanBismillahPrefix(item.arabic, surahId),
              banglaTranslation: item.banglaTranslation,
              englishTranslation: item.englishTranslation,
              banglaExplanation: item.banglaExplanation,
              englishExplanation: item.englishExplanation,
            );
          }
          return item;
        });
      }
    }

    final surah = _surahList.firstWhere((e) => e.id == surahId);
    return List.generate(totalAyahs, (i) {
      final ayahNum = i + 1;
      return AyahContent(
        number: ayahNum,
        arabic: 'وَإِذْ قَالَ رَبُّكَ لِلْمَلَائِكَةِ إِنِّي جَاعِلٌ فِي الْأَرْضِ خَلِيفَةً ($ayahNum)',
        banglaTranslation: '${surah.name} এর $ayahNum নং আয়াতের বাংলা অনুবাদ। মুমিনদের জন্য রয়েছে এতে কল্যাণ।',
        englishTranslation: 'This is the English translation of Surah ${surah.englishName} Ayah $ayahNum.',
        banglaExplanation: 'আয়াতটির তাফসিরে বর্ণিত হয়েছে যে আল্লাহ মুমিনদের সর্বদা সৎ পথে চলার নির্দেশনা দিয়েছেন।',
        englishExplanation: 'Tafsir confirms Allah\'s call to all believers to remain firm on the path of truth and justice.',
      );
    });
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // LIVE API QURAN FETCHING SERVICE
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> _loadSurahData(int surahId, int totalAyahs) async {
    setState(() {
      _isLoadingSurah = true;
      _loadedAyahs = [];
    });

    try {
      final arabicUri = Uri.parse('https://api.alquran.cloud/v1/surah/$surahId');
      final banglaUri = Uri.parse('https://api.alquran.cloud/v1/surah/$surahId/bn.bengali');
      final englishUri = Uri.parse('https://api.alquran.cloud/v1/surah/$surahId/en.sahih');

      final responses = await Future.wait([
        http.get(arabicUri).timeout(const Duration(seconds: 8)),
        http.get(banglaUri).timeout(const Duration(seconds: 8)),
        http.get(englishUri).timeout(const Duration(seconds: 8)),
      ]);

      if (responses[0].statusCode == 200 &&
          responses[1].statusCode == 200 &&
          responses[2].statusCode == 200) {
        final arabicJson = jsonDecode(responses[0].body);
        final banglaJson = jsonDecode(responses[1].body);
        final englishJson = jsonDecode(responses[2].body);

        final List<dynamic> arabicAyahs = arabicJson['data']['ayahs'];
        final List<dynamic> banglaAyahs = banglaJson['data']['ayahs'];
        final List<dynamic> englishAyahs = englishJson['data']['ayahs'];

        final List<AyahContent> fetchedList = [];
        for (int i = 0; i < arabicAyahs.length; i++) {
          final rawArabic = arabicAyahs[i]['text'] ?? '';
          final cleanArabic = i == 0 ? _cleanBismillahPrefix(rawArabic, surahId) : rawArabic;

          fetchedList.add(AyahContent(
            number: arabicAyahs[i]['numberInSurah'] ?? (i + 1),
            arabic: cleanArabic,
            banglaTranslation: banglaAyahs[i]['text'] ?? '',
            englishTranslation: englishAyahs[i]['text'] ?? '',
            banglaExplanation: 'এই আয়াতের তাফসির আল্লাহর বাণী অনুযায়ী দ্বীনের সঠিক সরল পথের শিক্ষা দান করে।',
            englishExplanation: 'This ayah guides the heart towards absolute righteousness and belief.',
          ));
        }

        setState(() {
          _loadedAyahs = fetchedList;
          _isLoadingSurah = false;
        });
        return;
      }
    } catch (e) {
      // Offline fallback
    }

    // Offline / timeout fallback generator
    setState(() {
      _loadedAyahs = _generateSurahContent(surahId, totalAyahs);
      _isLoadingSurah = false;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // SHAPED STORAGE PERSISTENCE
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentStreak = prefs.getInt('quran_tracker_streak') ?? 0;
      _longestStreak = prefs.getInt('quran_longest_streak') ?? 0;
      _completedPagesToday = prefs.getInt('quran_completed_pages_today') ?? 0;
      _targetDailyPages = prefs.getInt('quran_target_daily_pages') ?? 5;
      _khatmTotalJuzCompleted = prefs.getInt('quran_khatm_juz_completed') ?? 0;
      _isDarkMode = prefs.getBool('quran_settings_dark') ?? false;
      _arabicFontSize = prefs.getDouble('quran_settings_font_size') ?? 24.0;

      _continueSurahId = prefs.getInt('quran_continue_surah') ?? 1;
      _continuePage = prefs.getInt('quran_continue_page') ?? 1;
      _continueAyah = prefs.getInt('quran_continue_ayah') ?? 1;

      // Load custom wazifa lists
      for (final cat in _wazifaSupplications.keys) {
        final listStr = prefs.getString('quran_wazifa_supps_$cat');
        if (listStr != null) {
          final List<dynamic> decoded = jsonDecode(listStr);
          _wazifaSupplications[cat] = decoded.map((e) => e.toString()).toList();
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
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('quran_tracker_streak', _currentStreak);
    await prefs.setInt('quran_longest_streak', _longestStreak);
    await prefs.setInt('quran_completed_pages_today', _completedPagesToday);
    await prefs.setInt('quran_target_daily_pages', _targetDailyPages);
    await prefs.setInt('quran_khatm_juz_completed', _khatmTotalJuzCompleted);
    await prefs.setBool('quran_settings_dark', _isDarkMode);
    await prefs.setDouble('quran_settings_font_size', _arabicFontSize);

    await prefs.setInt('quran_continue_surah', _continueSurahId);
    await prefs.setInt('quran_continue_page', _continuePage);
    await prefs.setInt('quran_continue_ayah', _continueAyah);

    for (final cat in _wazifaSupplications.keys) {
      await prefs.setString('quran_wazifa_supps_$cat', jsonEncode(_wazifaSupplications[cat]));
    }

    await prefs.setString('quran_wazifa_checks', jsonEncode(_completedWazifas));
    await prefs.setString('quran_hadith_wazifa_checks', jsonEncode(_completedHadithWazifas));
    await prefs.setString('quran_bookmarks_json', jsonEncode(_bookmarks));
    await prefs.setString('quran_reflections_json', jsonEncode(_reflections));
    await prefs.setString('quran_hifz_memorized_ids', jsonEncode(_memorizedSurahIds.toList()));
  }

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
        color: const Color(0xFFE8E8E8),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Scaffold(
              backgroundColor: themeBg,
              body: SafeArea(
                child: Column(
                  children: [
                    _buildTopHeader(themeText),
                    Expanded(child: _buildActiveTabContent(cardBg, themeText)),
                  ],
                ),
              ),
              bottomNavigationBar: _buildBottomNavigationBar(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader(Color themeText) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
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
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.midTeal,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star_rounded, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                'Quran Journey',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: themeText),
              ),
            ],
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

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.15), width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: _bottomNavIndex,
        onTap: (index) {
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
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        selectedItemColor: AppColors.midTeal,
        unselectedItemColor: AppColors.placeholder,
        selectedLabelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 10),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book_rounded), label: 'Quran'),
          BottomNavigationBarItem(icon: Icon(Icons.track_changes_rounded), label: 'Progress'),
          BottomNavigationBarItem(icon: Icon(Icons.spa_rounded), label: 'Wazifa'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'More'),
        ],
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
        if (_completedWazifas['${cat}_$w'] ?? false) {
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
                    Text('Page $_continuePage • Ayah $_continueAyah', style: GoogleFonts.inter(color: Colors.white60, fontSize: 11)),
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
                  '$_completedPagesToday / $_targetDailyPages Pages',
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
                    Text('${_targetDailyPages > 0 ? ((_completedPagesToday / _targetDailyPages) * 100).toInt().clamp(0, 100) : 0}%', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _targetDailyPages > 0 ? (_completedPagesToday / _targetDailyPages).clamp(0.0, 1.0) : 0.0,
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
                    Text(dailyVerse.reference, style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.placeholder)),
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

                      Text(
                        'ব্যাখ্যা ও তাফসির (Explanation)',
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.coralOrange),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currentAyah.banglaExplanation,
                        style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.placeholder, height: 1.45),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        currentAyah.englishExplanation,
                        style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.placeholder, height: 1.45),
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
                onPressed: _activeReaderAyahIndex > 1
                    ? () => setState(() => _activeReaderAyahIndex--)
                    : null,
                child: Text('← Previous', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              ),
              Text(
                'Ayah $_activeReaderAyahIndex / ${_loadedAyahs.length}',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: themeText),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.navyBlue),
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

                    _completedPagesToday++;
                    _saveState();
                  });
                },
                child: Text(
                  _activeReaderAyahIndex == _loadedAyahs.length ? 'Finish' : 'Next Ayah →',
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
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
    final catchupVal = _targetDailyPages - _completedPagesToday;
    final progressMsg = catchupVal <= 0
        ? 'Great job! You have achieved today\'s target reading pages! 🌟'
        : 'You are $catchupVal pages behind today\'s reading target. Catch up now! 📖';

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
                        value: _targetDailyPages > 0 ? (_completedPagesToday / _targetDailyPages).clamp(0.0, 1.0) : 0.0,
                        backgroundColor: Colors.grey.shade100,
                        color: AppColors.midTeal,
                        strokeWidth: 9,
                      ),
                      Center(
                        child: Text(
                          '${_targetDailyPages > 0 ? ((_completedPagesToday / _targetDailyPages) * 100).toInt().clamp(0, 100) : 0}%',
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
              labelColor: AppColors.navyBlue,
              unselectedLabelColor: AppColors.placeholder,
              tabs: [
                Tab(child: Text('Hadith virtues', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12))),
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
                    Text('Virtues (Bangla):', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                    Text(w.benefitBangla, style: GoogleFonts.inter(fontSize: 12, color: themeText, height: 1.35)),
                    const SizedBox(height: 8),
                    Text('Virtues (English):', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                    Text(w.benefitEnglish, style: GoogleFonts.inter(fontSize: 12, color: themeText, height: 1.35)),
                    const SizedBox(height: 8),
                    Text('Hadith Reference:', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.coralOrange)),
                    Text(w.hadithReference, style: GoogleFonts.inter(fontSize: 11, color: AppColors.placeholder, fontStyle: FontStyle.italic)),
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
          final val = _completedWazifas['${category}_$wazifa'] ?? false;

          return Card(
            color: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: Checkbox(
                value: val,
                activeColor: AppColors.midTeal,
                onChanged: (v) {
                  setState(() {
                    _completedWazifas['${category}_$wazifa'] = v!;
                    _saveState();
                  });
                },
              ),
              title: Text(wazifa, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: themeText)),
              subtitle: Text('Supplication Checklist entry', style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.placeholder)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.coralOrange, size: 18),
                onPressed: () {
                  setState(() {
                    _wazifaSupplications[category]?.removeAt(idx);
                    _completedWazifas.remove('${category}_$wazifa');
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
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Add Wazifa ($category)', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
          content: TextField(
            controller: controller,
            style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black),
            decoration: const InputDecoration(hintText: 'Enter supplication name...'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.placeholder)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.navyBlue),
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  setState(() {
                    _wazifaSupplications[category]?.add(controller.text.trim());
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
                  Icons.pages_rounded,
                  AppColors.midTeal,
                  'Pages Today',
                  '$_completedPagesToday Pages',
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
                onChanged: (v) {
                  setState(() {
                    _isDarkMode = v;
                    _saveState();
                  });
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
            final dailyRecPages = (604 / planDays).ceil();
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
                        Text('$dailyRecPages Pages Daily', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
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
                        _targetDailyPages = dailyRecPages;
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
