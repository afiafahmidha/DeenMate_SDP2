import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:adhan/adhan.dart';
import '../widgets/auth_header.dart'; // Import AppColors
// ===== HIJRI DATE MODEL =====
class HijriDate {
  final int year;
  final int month;
  final int day;
  HijriDate(this.year, this.month, this.day);
  static const List<String> monthNames = [
    'Muharram',
    'Safar',
    'Rabi\' al-Awwal',
    'Rabi\' al-Thani',
    'Jumada al-Awwal',
    'Jumada al-Thani',
    'Rajab',
    'Sha\'ban',
    'Ramadan',
    'Shawwal',
    'Dhu al-Qa\'dah',
    'Dhu al-Hijjah',
  ];
  static const List<String> monthNamesBengali = [
    'মহররম',
    'সফর',
    'রবিউল আউয়াল',
    'রবিউস সানি',
    'জুমাদাল উলা',
    'জুমাদাল আখিরা',
    'রজব',
    'শাবান',
    'রমজান',
    'শাওয়াল',
    'জিলকদ',
    'জিলহজ',
  ];
  String get monthName => monthNames[month - 1];
  String get monthNameBengali => monthNamesBengali[month - 1];
  String format(bool isBengali) {
    if (isBengali) {
      final bnDay = _toBengaliNumber(day);
      final bnYear = _toBengaliNumber(year);
      return '$bnDay $monthNameBengali $bnYear হিজরি';
    }
    return '$day $monthName $year AH';
  }
  static String _toBengaliNumber(int number) {
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const bengaliDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    String result = number.toString();
    for (int i = 0; i < 10; i++) {
      result = result.replaceAll(englishDigits[i], bengaliDigits[i]);
    }
    return result;
  }
}
// ===== HIJRI CONVERTER =====
class HijriConverter {
  static int gToJd(int y, int m, int d) {
    if (m < 3) {
      y -= 1;
      m += 12;
    }
    int a = (y / 100).floor();
    int b = (a / 4).floor();
    int c = 2 - a + b;
    int e = (365.25 * (y + 4716)).floor();
    int f = (30.6001 * (m + 1)).floor();
    return c + d + e + f - 1524;
  }
  static HijriDate jdToH(int jd) {
    // 16 July 622 CE is JD 1948440
    int jdShift = jd - 1948440 + 10632;
    int cycle = (jdShift / 10631).floor();
    int rem = jdShift % 10631;
    int yearInCycle = 1;
    int elapsedDays = 0;
    final List<int> leapYears = [2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29];
    for (int y = 1; y <= 30; y++) {
      int days = leapYears.contains(y) ? 355 : 354;
      if (elapsedDays + days > rem) {
        yearInCycle = y;
        break;
      }
      elapsedDays += days;
    }
    int hYear = cycle * 30 + yearInCycle - 30;
    int dayOfYear = rem - elapsedDays;
    int hMonth = 1;
    int hDay = 1;
    int tempDays = 0;
    for (int m = 1; m <= 12; m++) {
      int daysInMonth = (m % 2 != 0) ? 30 : 29;
      if (m == 12 && leapYears.contains(yearInCycle)) {
        daysInMonth = 30;
      }
      if (tempDays + daysInMonth > dayOfYear) {
        hMonth = m;
        hDay = dayOfYear - tempDays + 1;
        break;
      }
      tempDays += daysInMonth;
    }
    return HijriDate(hYear, hMonth, hDay);
  }
  static HijriDate fromGregorian(DateTime date) {
    // Basic tabular calculation. Add +1 adjustment to match standard moon calendars in South Asia
    int jd = gToJd(date.year, date.month, date.day);
    return jdToH(jd);
  }
}
// ===== ISLAMIC EVENT MODEL =====
class IslamicEvent {
  final String title;
  final String titleBengali;
  final String description;
  final String descriptionBengali;
  final String history;
  final String historyBengali;
  final List<String> activities;
  final List<String> activitiesBengali;
  final Color themeColor;
  const IslamicEvent({
    required this.title,
    required this.titleBengali,
    required this.description,
    required this.descriptionBengali,
    required this.history,
    required this.historyBengali,
    required this.activities,
    required this.activitiesBengali,
    this.themeColor = const Color(0xFFEB8A6C), // Coral accent
  });
}
// ===== ISLAMIC EVENTS DATABASE =====
class CalendarDatabase {
  // Key: Month/Day as "Month-Day"
  static final Map<String, IslamicEvent> hijriEvents = {
    '1-1': const IslamicEvent(
      title: 'Islamic New Year',
      titleBengali: 'হিজরি নববর্ষ',
      description: 'First day of the Hijri year. It marks the migration of Prophet Muhammad (PBUH) from Makkah to Madinah.',
      descriptionBengali: 'হিজরি সনের প্রথম দিন। এটি মহানবী হযরত মুহাম্মদ (সা.)-এর মক্কা থেকে মদিনায় হিজরতের স্মৃতি বহন করে।',
      history: 'The Islamic calendar was introduced during the caliphate of Umar ibn al-Khattab, choosing the Hijrah (migration) in 622 CE as the starting point of the calendar because it marked the establishment of the first sovereign Muslim community.',
      historyBengali: 'হযরত ওমর ফারুক (রা.)-এর খেলাফতকালে হিজরি সন প্রবর্তন করা হয়। ৬২২ খ্রিস্টাব্দের হিজরতকে ইসলামি বর্ষপঞ্জির সূচনা হিসেবে বেছে নেওয়া হয়েছিল কারণ এটি প্রথম মুসলিম সমাজ গঠনের মাইলফলক ছিল।',
      activities: [
        'Reflect on the lessons of Hijrah (sacrifice, perseverance, and brotherhood).',
        'Make resolutions for spiritual improvement in the new year.',
        'Offer voluntary prayers and seek forgiveness for the past year\'s shortcomings.',
        'Read about the early history of Madinah and the Ansar.',
      ],
      activitiesBengali: [
        'হিজরতের শিক্ষা (ত্যাগ, ধৈর্য এবং ভ্রাতৃত্ব) নিয়ে চিন্তা করা।',
        'নতুন বছরে আধ্যাত্মিক উন্নতির জন্য বিশেষ সংকল্প করা।',
        'নফল নামাজ আদায় এবং বিগত বছরের গুনাহের জন্য ক্ষমাপ্রার্থনা করা।',
        'মদিনার প্রারম্ভিক ইতিহাস ও আনসারদের অবদান সম্পর্কে অধ্যয়ন করা।',
      ],
    ),
    '1-10': const IslamicEvent(
      title: 'Day of Ashura',
      titleBengali: 'পবিত্র আশুরা',
      description: 'The 10th of Muharram is a day of historic deliverance, gratitude, and remembrance of sacrifices.',
      descriptionBengali: 'মহররমের ১০ তারিখ একটি ঐতিহাসিক মুক্তি, কৃতজ্ঞতা ও আত্মত্যাগের স্মৃতিবিজড়িত দিন।',
      history: 'On this day, Allah split the Red Sea to deliver Prophet Musa (Moses) and the Children of Israel from the tyranny of Pharaoh. It is also the day of the tragic martyrdom of Imam Hussain (RA), the grandson of the Prophet, at the Battle of Karbala while standing up against injustice.',
      historyBengali: 'এই দিনে আল্লাহ তায়ালা লোহিত সাগর দ্বিখণ্ডিত করে হযরত মুসা (আ.) ও বনী ইসরাইলকে ফেরাউনের অত্যাচার থেকে রক্ষা করেছিলেন। এছাড়াও, এই দিনে মহানবী (সা.)-এর দৌহিত্র হযরত ইমাম হোসাইন (রা.) কারবালার ময়দানে অন্যায়ের বিরুদ্ধে লড়াই করে শাহাদাত বরণ করেন।',
      activities: [
        'Fast on the 10th of Muharram, along with either the 9th or 11th (expiates the sins of the previous year).',
        'Provide generous meals and charity to family, relatives, and the poor.',
        'Recite abundant Istighfar (seeking forgiveness) and Salawat.',
        'Reflect on Imam Hussain\'s bravery in standing up for justice and the truth.',
      ],
      activitiesBengali: [
        'মহররমের ১০ তারিখ রোজা রাখা এবং এর সাথে মিলিয়ে ৯ বা ১১ তারিখে আরেকটি রোজা রাখা (যা বিগত এক বছরের গুনাহ মাফ করে)।',
        'পরিবার ও অভাবীদের জন্য উন্নত মানের খাবার এবং দান-সদকার ব্যবস্থা করা।',
        'অনিক পরিমাণে ইস্তিগফার ও দরূদ পাঠ করা।',
        'অন্যায়ের বিরুদ্ধে ইমাম হোসাইন (রা.)-এর আপসহীন লড়াইয়ের শিক্ষা নিজের জীবনে ধারণ করা।',
      ],
      themeColor: Color(0xFFC84B31), // Deep red/coral
    ),
    '3-12': const IslamicEvent(
      title: 'Mawlid al-Nabi',
      titleBengali: 'ঈদে মিলাদুন্নবী',
      description: 'The birth anniversary of the Prophet Muhammad (PBUH), sent as a mercy to all creation.',
      descriptionBengali: 'মানবজাতির মুক্তির দূত হযরত মুহাম্মদ (সা.)-এর পবিত্র জন্ম ও ওফাত দিবস।',
      history: 'Prophet Muhammad (PBUH) was born in Makkah in the Year of the Elephant (circa 570 CE). His arrival transformed Arabia and guided humanity from darkness into the light of monotheism and character excellence.',
      historyBengali: 'হযরত মুহাম্মদ (সা.) হাতির বছরে (৫৭০ খ্রি.) মক্কায় জন্ম নেন। তাঁর আগমন আরবের জাহেলিয়াত দূর করে এবং মানুষকে একত্ববাদ ও সর্বোত্তম চরিত্রের আলোর দিকে পরিচালিত করে।',
      activities: [
        'Send abundant blessings and Salawat upon the Prophet (PBUH).',
        'Read and study the Seerah (biography) of the Prophet.',
        'Gather with family to discuss and share the character, kindness, and mercy of the Prophet.',
        'Give charity (Sadaqah) and feed the needy to spread the Prophet\'s spirit of compassion.',
      ],
      activitiesBengali: [
        'নবীজির প্রতি অধিক হারে দরূদ ও সালাম প্রেরণ করা।',
        'রাসূলুল্লাহ (সা.)-এর পবিত্র সীরাত (জীবনী) পাঠ ও আলোচনা করা।',
        'পরিবারের সাথে নবীজির ক্ষমা, দয়া ও উন্নত চরিত্রের গুণাবলি নিয়ে আলোচনা করা।',
        'নবীজির দানশীলতার অনুসরণে গরিবদের খাবার খাওয়ানো ও দান-সদকা করা।',
      ],
    ),
    '7-27': const IslamicEvent(
      title: 'Isra\' and Mi\'raj',
      titleBengali: 'শবে মেরাজ',
      description: 'The miraculous Night Journey and Ascension of Prophet Muhammad (PBUH) through the heavens.',
      descriptionBengali: 'নবীজির অলৌকিক নৈশ ভ্রমণ ও ঊর্ধ্বলোকে আরোহণের স্মরণীয় রজনী।',
      history: 'In a single night, the Prophet was taken from Makkah to Jerusalem (Al-Aqsa Mosque) and ascended through the seven heavens to meet Allah. On this night, the five daily prayers (Salah) were gifted to the Muslim Ummah as a direct connection to Allah.',
      historyBengali: 'এক রাতে জিবরাইল (আ.)-এর সাথে মহানবী (সা.) মক্কা থেকে আল-আকসায় এবং সেখান থেকে সপ্তাকাশ পাড়ি দিয়ে আল্লাহর সান্নিধ্যে যান। এই রজনীতে উম্মতের জন্য উপহারস্বরূপ পাঁচ ওয়াক্ত নামাজ ফরজ করা হয়।',
      activities: [
        'Guard your daily Salah and focus on improving its quality and humility (Khushu).',
        'Perform voluntary night prayers (Tahajjud) and make sincere Duas.',
        'Read Surah Al-Isra and study the significance of Jerusalem and Al-Aqsa Mosque in Islam.',
        'Share lessons of faith and trust in Allah with family.',
      ],
      activitiesBengali: [
        'পাঁচ ওয়াক্ত নামাজের যত্ন নেওয়া এবং খুশু-খুজুর (মনোযোগ) সাথে আদায়ের চেষ্টা করা।',
        'নফল ইবাদত, তাহাজ্জুদ আদায় এবং আল্লাহর কাছে ক্ষমা চাওয়া।',
        'সূরা আল-ইসরা তিলাওয়াত করা এবং বাইতুল মুকাদ্দাস ও আল-আকসা মসজিদের গুরুত্ব জানা।',
        'ঈমান ও আল্লাহর প্রতি তাওয়াক্কুল সম্পর্কিত মেরাজের শিক্ষা ছড়িয়ে দেওয়া।',
      ],
    ),
    '8-15': const IslamicEvent(
      title: 'Shab-e-Barat (Mid-Sha\'ban)',
      titleBengali: 'শবে বরাত (মধ্য শাবান)',
      description: 'The Night of Salvation and Records. A night of immense divine mercy, forgiveness, and decree.',
      descriptionBengali: 'মুক্তি ও ভাগ্যের রজনী। এটি আল্লাহর রহমত, ক্ষমা এবং বান্দার ভাগ্য নির্ধারণের রাত।',
      history: 'According to tradition, Allah descends to the lowest heaven on the night of 15th Sha\'ban to forgive seeking servants and write decrees for the year regarding life, death, and sustenance.',
      historyBengali: 'হাদিস শরিফ অনুযায়ী, ১৫ই শাবানের রাতে মহান আল্লাহ প্রথম আসমানে অবতরণ করেন এবং ক্ষমাপ্রার্থনাকারী বান্দাদের ক্ষমা করেন ও পরবর্তী বছরের জন্য হায়াত-মউত ও রিজিকের ফয়সালা করেন।',
      activities: [
        'Perform night prayers (Qiyam-ul-Layl) and recite Quran.',
        'Fast on the 15th day of Sha\'ban (Sunnah).',
        'Make intense supplication (Dua) for forgiveness, health, and halal sustenance.',
        'Reconcile with any relatives or friends you are not speaking to, as grudges prevent forgiveness.',
      ],
      activitiesBengali: [
        'নফল ইবাদত, কোরআন তিলাওয়াত ও জিকিরে রাত কাটানো।',
        '১৫ই শাবান দিবসে রোজা রাখা (নফল)।',
        'ক্ষমা, সুস্থতা ও হালাল রিজিকের জন্য আল্লাহর দরবারে কান্নাজড়িত দোয়া করা।',
        'কারো সাথে মনমালিন্য থাকলে তা মিটিয়ে ফেলা, কারণ হিংসা ও শত্রুতা ক্ষমা পাওয়ার অন্তরায়।',
      ],
    ),
    '9-1': const IslamicEvent(
      title: 'First Day of Ramadan',
      titleBengali: 'রমজানের প্রথম দিন',
      description: 'The start of the blessed month of fasting, intense spiritual devotion, and Quran.',
      descriptionBengali: 'রোজা, আত্মসংযম এবং কোরআন নাজিলের বরকতময় মাসের সূচনা।',
      history: 'The month of Ramadan is the month in which the Quran was sent down as a guide for humanity. Fasting was made obligatory during the second year of Hijrah to teach Taqwa (God-consciousness).',
      historyBengali: 'রমজান হলো সেই মাস যে মাসে মানবজাতির পথপ্রদর্শক হিসেবে কোরআন অবতীর্ণ হয়েছে। হিজরি দ্বিতীয় সনে তাকওয়া অর্জনের উদ্দেশ্যে রোজা ফরজ করা হয়।',
      activities: [
        'Intend to fast the whole month with sincere faith and reward-seeking.',
        'Establish congregational Taraweeh prayers.',
        'Set a daily target for reading and understanding the Holy Quran.',
        'Control speech from gossip, lying, and anger, and practice patience.',
      ],
      activitiesBengali: [
        'পূর্ণ ঈমান ও সওয়াব পাওয়ার নিয়তে পুরো মাস রোজা রাখার সংকল্প করা।',
        'তারাবিহর নামাজ গুরুত্বের সাথে আদায় করা।',
        'প্রতিদিন নিয়মিত পবিত্র কোরআন পাঠ ও অর্থ বোঝার লক্ষ্য নির্ধারণ করা।',
        'মিথ্যা, গিবত, রাগ পরিহার করে জিহ্বাকে নিয়ন্ত্রণে রাখা ও ধৈর্য ধারণ করা।',
      ],
      themeColor: Color(0xFF0F6F6B), // Teal accent
    ),
    '9-27': const IslamicEvent(
      title: 'Laylat al-Qadr',
      titleBengali: 'লাইলাতুল কদর (কদরের রাত)',
      description: 'The Night of Decree and Power, which is better than a thousand months (83 years) of worship.',
      descriptionBengali: 'মহিমান্বিত কদরের রাত, যা হাজার মাসের (প্রায় ৮৩ বছর) ইবাদতের চেয়েও শ্রেষ্ঠ।',
      history: 'Surah Al-Qadr was revealed regarding this night. It marks the commencement of the descent of the Quran from the Preserved Tablet (Lauh al-Mahfuz) to the earthly sky, to be revealed to the Prophet (PBUH).',
      historyBengali: 'কদরের রজনী নিয়ে পবিত্র কোরআনে সূরা আল-কদর অবতীর্ণ হয়েছে। এই রাতেই লাওহে মাহফুজ থেকে পবিত্র কোরআন দুনিয়ার আকাশে প্রথম অবতীর্ণ হয়।',
      activities: [
        'Spend the night in continuous prayer, Tahajjud, and Dua.',
        'Recite the special Dua: "Allahumma innaka \'afuwwun tuhibbul \'afwa fa\'fu \'anni".',
        'Give Sadaqah (even a small amount, as its reward is multiplied enormously).',
        'Perform I\'tikaf (spiritual seclusion) in the mosque if possible.',
      ],
      activitiesBengali: [
        'সারারাত নফল নামাজ, তাহাজ্জুদ ও জিকিরে অতিবাহিত করা।',
        'নবীজির শেখানো দোয়া বেশি বেশি পড়া: "আল্লাহুম্মা ইন্নাকা আফুউউন তুহিব্বুল আফওয়া ফাফু আন্নী"।',
        'দান-সদকা করা (অল্প হলেও, কারণ এ রাতের সওয়াব বহুগুণ বৃদ্ধি পায়)।',
        'সম্ভব হলে শেষ দশকে মসজিদে ইতিকাফ করা।',
      ],
      themeColor: Color(0xFF459490), // Green/Teal accent
    ),
    '10-1': const IslamicEvent(
      title: 'Eid al-Fitr',
      titleBengali: 'ঈদুল ফিতর',
      description: 'The festival of breaking the fast, celebrating the successful completion of Ramadan.',
      descriptionBengali: 'রোজা ভাঙার ও রমজানের ইবাদত সফলভাবে সম্পন্ন করার আনন্দের উৎসব।',
      history: 'Established by the Prophet Muhammad (PBUH) in Madinah as a day of thanksgiving to Allah, joy, and unity after fasting for a full month.',
      historyBengali: 'মদিনায় হিজরতের পর মহানবী (সা.) মুসলমানদের জন্য আল্লাহ তায়ালার প্রতি কৃতজ্ঞতা প্রকাশ ও আনন্দের দিন হিসেবে এই উৎসব নির্ধারণ করেন।',
      activities: [
        'Pay Zakat al-Fitr (Fitra) before the Eid prayer to help the poor.',
        'Perform Ghusl, wear clean or new clothes, and apply perfume.',
        'Eat something sweet (preferably dates in odd numbers) before heading to Eid prayer.',
        'Attend the Eid prayer, listen to the Khutbah, and greet the community.',
      ],
      activitiesBengali: [
        'ঈদের নামাজের আগে ফিতরা আদায় করা, যেন দরিদ্ররাও উৎসবে শামিল হতে পারে।',
        'গোসল করা, নতুন বা পরিষ্কার জামাকাপড় পরা এবং সুগন্ধি মাখা।',
        'ঈদের নামাজে যাওয়ার আগে মিষ্টি মুখ করা (বিজোড় সংখ্যক খেজুর খাওয়া সুন্নাত)।',
        'ঈদের নামাজে শরিক হওয়া, খুতবা শোনা এবং পরস্পরের সাথে শুভেচ্ছা বিনিময় করা।',
      ],
      themeColor: Color(0xFF84B5B4), // Blue/Teal accent
    ),
    '12-9': const IslamicEvent(
      title: 'Day of Arafah',
      titleBengali: 'আরাফাহ দিবস',
      description: 'The pinnacle day of the Hajj pilgrimage and a day of supreme forgiveness and acceptance of Duas.',
      descriptionBengali: 'হজের মূল দিন এবং আল্লাহর দরবারে ক্ষমা ও দোয়া কবুলের সর্বশ্রেষ্ঠ দিন।',
      history: 'On this day, pilgrims gather on the plain of Mount Arafah to pray. It is the day Allah perfected the religion of Islam and completed His favors upon us. For non-pilgrims, fasting expiates the sins of the previous year and the coming year.',
      historyBengali: 'এই দিনে হাজিগণ আরাফাতের ময়দানে সমবেত হয়ে ক্ষমা প্রার্থনা করেন। এই দিনেই ইসলামকে পূর্ণাঙ্গ দ্বীন হিসেবে ঘোষণার আয়াত নাজিল হয়। হাজি ছাড়া অন্যদের জন্য এ দিনে রোজা রাখা অত্যন্ত সওয়াবের কাজ।',
      activities: [
        'Fast on this day (for those not performing Hajj) to expiate two years of sins.',
        'Make abundant Dua, especially the best Dua: "La ilaha illallahu wahdahu la sharika lahu...".',
        'Recite the Takbeeraat of Tashreeq ("Allahu Akbar, Allahu Akbar...") aloud after every obligatory prayer starting from Fajr.',
        'Seek sincere forgiveness and repent from all sins.',
      ],
      activitiesBengali: [
        'হাজি ছাড়া অন্যরা রোজা রাখা (যা বিগত ও আগামী বছরের গুনাহ মাফ করে)।',
        'বেশি বেশি দোয়া করা, বিশেষ করে আরাফার সর্বোত্তম দোয়া পাঠ করা।',
        'ফজরের পর থেকে প্রত্যেক ফরজ নামাজের পর তাকবিরে তাশরিক ("আল্লাহু আকবার, আল্লাহু আকবার...") পড়া।',
        'খালেস দিলে তাওবা করা এবং আল্লাহর রহমত কামনা করা।',
      ],
    ),
    '12-10': const IslamicEvent(
      title: 'Eid al-Adha',
      titleBengali: 'ঈদুল আজহা',
      description: 'The festival of sacrifice, commemorating the submission and devotion of Prophet Ibrahim (AS).',
      descriptionBengali: 'কোরবানির ঈদ, যা হযরত ইব্রাহিম (আ.)-এর মহান আত্মত্যাগ ও আল্লাহর প্রতি আনুগত্যের স্মৃতি বহন করে।',
      history: 'It honors the willingness of Prophet Ibrahim (AS) to sacrifice his son Ismail (AS) in obedience to Allah\'s command. Before the sacrifice, Allah replaced Ismail with a ram, establishing this tradition for generations.',
      historyBengali: 'হযরত ইব্রাহিম (আ.) আল্লাহর আদেশে তাঁর প্রিয় পুত্র ইসমাইল (আ.)-কে কোরবানি করতে প্রস্তুত হয়েছিলেন। তাঁর এই চরম আনুগত্যে সন্তুষ্ট হয়ে আল্লাহ জান্নাতি দুম্বা পাঠিয়ে দেন। সেই থেকে পশু কোরবানি সুন্নাত হিসেবে পালিত হয়।',
      activities: [
        'Perform the Eid prayer in the morning.',
        'Perform the Qurbani (sacrifice of a halal animal) if you have the financial means.',
        'Divide the meat into three parts: one for the poor, one for relatives/friends, and one for your family.',
        'Recite Takbeeraat of Tashreeq after every Salah.',
        'Maintain family ties and spread kindness.',
      ],
      activitiesBengali: [
        'সকালে ঈদের নামাজ আদায় করা।',
        'সামর্থ্য থাকলে আল্লাহর সন্তুষ্টির জন্য পশু কোরবানি করা।',
        'কোরবানির গোশত তিন ভাগে বণ্টন করা: এক ভাগ গরিবের, এক ভাগ আত্মীয়দের এবং এক ভাগ নিজের পরিবারের জন্য।',
        'প্রতিটি ফরজ নামাজের পর তাকবিরে তাশরিক পাঠ করা।',
        'পারিবারিক সম্পর্ক মজবুত করা এবং ভ্রাতৃত্বের হাত বাড়িয়ে দেওয়া।',
      ],
      themeColor: Color(0xFFEB8A6C), // Coral
    ),
  };
  // Gregorian Overrides for 2026 and 2027 to align perfectly with regional moon calendars
  static const Map<String, String> gregorianOverrides = {
    // 2026
    '2026-01-16': '7-27',   // Isra' Mi'raj
    '2026-02-03': '8-15',   // Shab-e-Barat
    '2026-02-18': '9-1',    // Ramadan Start
    '2026-03-17': '9-27',   // Laylat al-Qadr
    '2026-03-20': '10-1',   // Eid al-Fitr
    '2026-05-26': '12-9',   // Day of Arafah
    '2026-05-27': '12-10',  // Eid al-Adha
    '2026-06-16': '1-1',    // Islamic New Year
    '2026-06-25': '1-10',   // Day of Ashura
    '2026-08-25': '3-12',   // Mawlid al-Nabi
    // 2027
    '2027-01-05': '7-27',   // Isra' Mi'raj
    '2027-01-23': '8-15',   // Shab-e-Barat
    '2027-02-07': '9-1',    // Ramadan Start
    '2027-03-06': '9-27',   // Laylat al-Qadr
    '2027-03-09': '10-1',   // Eid al-Fitr
    '2027-05-15': '12-9',   // Day of Arafah
    '2027-05-16': '12-10',  // Eid al-Adha
    '2027-06-06': '1-1',    // Islamic New Year
    '2027-06-15': '1-10',   // Day of Ashura
    '2027-08-15': '3-12',   // Mawlid al-Nabi
  };
  static IslamicEvent? getEvent(DateTime date, HijriDate hijriDate) {
    // Check Gregorian overrides first
    final keyGregorian = DateFormat('yyyy-MM-dd').format(date);
    if (gregorianOverrides.containsKey(keyGregorian)) {
      final hijriKey = gregorianOverrides[keyGregorian]!;
      return hijriEvents[hijriKey];
    }
    // Fallback to dynamic Hijri mapping
    final keyHijri = '${hijriDate.month}-${hijriDate.day}';
    return hijriEvents[keyHijri];
  }

  static final Map<String, DailyAyah> eventAyahs = {
    '1-10': const DailyAyah(
      reference: 'Surah Al-Baqarah 2:153',
      referenceBengali: 'সূরা আল-বাকারা, আয়াত ১৫৩',
      reflection: 'Allah tells us He is with those who are patient in hardship — a fitting reminder on a day of historic trial and deliverance.',
      reflectionBengali: 'আল্লাহ বলেন তিনি ধৈর্যশীলদের সাথে আছেন — কষ্ট ও মুক্তির এই দিনে বিশেষভাবে প্রাসঙ্গিক একটি শিক্ষা।',
    ),
    '3-12': const DailyAyah(
      reference: 'Surah Al-Anbiya 21:107',
      referenceBengali: 'সূরা আল-আম্বিয়া, আয়াত ১০৭',
      reflection: '"We sent you not, but as a mercy for all creatures" — the verse most associated with the Prophet\'s (PBUH) birth and purpose.',
      reflectionBengali: '"আমি আপনাকে সমগ্র জাহানের জন্য রহমত স্বরূপ প্রেরণ করেছি" — নবীজির (সা.) জন্ম ও রিসালাতের সাথে সবচেয়ে সম্পর্কিত আয়াত।',
    ),
    '7-27': const DailyAyah(
      reference: 'Surah Al-Isra 17:1',
      referenceBengali: 'সূরা আল-ইসরা, আয়াত ১',
      reflection: 'The opening verse of Surah Al-Isra describes the Night Journey itself — read alongside tonight\'s reflection on Salah.',
      reflectionBengali: 'সূরা আল-ইসরার প্রথম আয়াতেই মেরাজের রাতের বর্ণনা রয়েছে — আজ রাতের নামাজ নিয়ে চিন্তার সাথে একসাথে পড়ুন।',
    ),
    '9-1': const DailyAyah(
      reference: 'Surah Al-Baqarah 2:185',
      referenceBengali: 'সূরা আল-বাকারা, আয়াত ১৮৫',
      reflection: 'The verse that names Ramadan directly — the month the Quran was revealed as guidance for humanity.',
      reflectionBengali: 'যে আয়াতে সরাসরি রমজানের নাম উল্লেখ আছে — মানবজাতির হেদায়েতের জন্য কোরআন নাজিলের মাস।',
    ),
    '9-27': const DailyAyah(
      reference: 'Surah Al-Qadr 97:1-3',
      referenceBengali: 'সূরা আল-কদর, আয়াত ১-৩',
      reflection: 'The short surah revealed about this very night — "better than a thousand months."',
      reflectionBengali: 'এই রাত সম্পর্কে অবতীর্ণ সংক্ষিপ্ত সূরা — "যা হাজার মাসের চেয়ে উত্তম।"',
    ),
    '10-1': const DailyAyah(
      reference: 'Surah Al-Baqarah 2:185',
      referenceBengali: 'সূরা আল-বাকারা, আয়াত ১৮৫',
      reflection: '"...that you should complete the period and glorify Allah for guiding you, so that you may be grateful" — the note to end Ramadan on.',
      reflectionBengali: '"...যেন তোমরা সংখ্যা পূর্ণ কর এবং আল্লাহর শোকর আদায় কর হেদায়েত দানের জন্য" — রমজান শেষের উপযুক্ত শিক্ষা।',
    ),
    '12-9': const DailyAyah(
      reference: 'Surah Al-Ma\'idah 5:3',
      referenceBengali: 'সূরা আল-মায়িদা, আয়াত ৩',
      reflection: '"This day I have perfected your religion for you..." — revealed on this very day during the Farewell Pilgrimage.',
      reflectionBengali: '"আজ আমি তোমাদের জন্য তোমাদের দ্বীনকে পূর্ণাঙ্গ করে দিলাম..." — বিদায় হজের এই দিনেই অবতীর্ণ হয়েছিল।',
    ),
    '12-10': const DailyAyah(
      reference: 'Surah As-Saffat 37:107',
      referenceBengali: 'সূরা আস-সাফফাত, আয়াত ১০৭',
      reflection: '"And We ransomed him with a great sacrifice" — the verse behind the Qurbani tradition itself.',
      reflectionBengali: '"এবং আমি তার পরিবর্তে একটি মহান কোরবানি দিলাম" — কোরবানির ঐতিহ্যের মূল ভিত্তি এই আয়াত।',
    ),
  };

  static const List<DailyAyah> generalAyahPool = [
    DailyAyah(
      reference: 'Surah Ash-Sharh 94:5-6',
      referenceBengali: 'সূরা আশ-শারহ, আয়াত ৫-৬',
      reflection: '"Indeed, with hardship comes ease" — repeated twice for emphasis, a steady reminder for any ordinary day.',
      reflectionBengali: '"নিশ্চয়ই কষ্টের সাথে স্বস্তি রয়েছে" — জোর দিতে দুইবার বলা হয়েছে, যেকোনো সাধারণ দিনের জন্য একটি স্থির স্মরণিকা।',
    ),
    DailyAyah(
      reference: 'Surah Al-Baqarah 2:286',
      referenceBengali: 'সূরা আল-বাকারা, আয়াত ২৮৬',
      reflection: '"Allah does not burden a soul beyond what it can bear" — a grounding verse for any day that feels heavy.',
      reflectionBengali: '"আল্লাহ কাউকে তার সাধ্যের অতিরিক্ত বোঝা দেন না" — ভারী মনে হওয়া যেকোনো দিনের জন্য প্রশান্তিদায়ক আয়াত।',
    ),
    DailyAyah(
      reference: 'Surah Ar-Ra\'d 13:28',
      referenceBengali: 'সূরা আর-রা\'দ, আয়াত ২৮',
      reflection: '"Verily, in the remembrance of Allah do hearts find rest" — a simple anchor for today\'s Dhikr.',
      reflectionBengali: '"জেনে রাখ, আল্লাহর জিকিরেই অন্তর প্রশান্তি লাভ করে" — আজকের জিকিরের জন্য একটি সহজ ভিত্তি।',
    ),
    DailyAyah(
      reference: 'Surah Al-Talaq 65:2-3',
      referenceBengali: 'সূরা আত-তালাক, আয়াত ২-৩',
      reflection: '"And whoever relies upon Allah — then He is sufficient for him" — a reminder to place today\'s worries in perspective.',
      reflectionBengali: '"যে আল্লাহর উপর ভরসা করে, তার জন্য তিনিই যথেষ্ট" — আজকের দুশ্চিন্তাকে সঠিক দৃষ্টিকোণে দেখার একটি স্মরণিকা।',
    ),
    DailyAyah(
      reference: 'Surah Al-Ankabut 29:45',
      referenceBengali: 'সূরা আল-আনকাবুত, আয়াত ৪৫',
      reflection: '"Indeed, prayer prohibits immorality and wrongdoing" — worth reflecting on before today\'s next Salah.',
      reflectionBengali: '"নিশ্চয়ই নামাজ অশ্লীলতা ও অন্যায় থেকে বিরত রাখে" — আজকের পরবর্তী নামাজের আগে চিন্তা করার মতো একটি আয়াত।',
    ),
  ];

  static const DailyAyah jumuahAyah = DailyAyah(
    reference: 'Surah Al-Jumu\'ah 62:9',
    referenceBengali: 'সূরা আল-জুমুআ, আয়াত ৯',
    reflection:
        'The verse commanding Muslims to hasten to the remembrance of Allah when called for Friday prayer.',
    reflectionBengali:
        'জুমার নামাজের আহ্বানে দ্রুত আল্লাহর জিকিরের দিকে ছুটে যাওয়ার নির্দেশ সম্বলিত আয়াত।',
  );

  static DailyAyah getAyahForDate(DateTime date, HijriDate hijri, IslamicEvent? event) {
    final key = '${hijri.month}-${hijri.day}';
    if (eventAyahs.containsKey(key)) return eventAyahs[key]!;
    if (date.weekday == DateTime.friday) return jumuahAyah;
    final dayOfYear = int.parse(DateFormat('D').format(date));
    return generalAyahPool[dayOfYear % generalAyahPool.length];
  }

  static List<PrayerTimeEntry> getPrayerTimesForDate(DateTime date) {
    final coordinates = Coordinates(23.8103, 90.4125); // Dhaka, Bangladesh
    final params = CalculationMethod.karachi.getParameters();
    params.madhab = Madhab.hanafi;
    final prayerTimes = PrayerTimes(
      coordinates,
      DateComponents.from(date),
      params,
    );
    return [
      PrayerTimeEntry('Fajr', 'ফজর', prayerTimes.fajr),
      PrayerTimeEntry('Dhuhr', 'জোহর', prayerTimes.dhuhr),
      PrayerTimeEntry('Asr', 'আসর', prayerTimes.asr),
      PrayerTimeEntry('Maghrib', 'মাগরিব', prayerTimes.maghrib),
      PrayerTimeEntry('Isha', 'এশা', prayerTimes.isha),
    ];
  }
}

class DailyAyah {
  final String reference;
  final String referenceBengali;
  final String reflection;
  final String reflectionBengali;
  const DailyAyah({
    required this.reference,
    required this.referenceBengali,
    required this.reflection,
    required this.reflectionBengali,
  });
}

class PrayerTimeEntry {
  final String name;
  final String nameBengali;
  final DateTime time;
  PrayerTimeEntry(this.name, this.nameBengali, this.time);
}
// ===== INTERACTIVE CALENDAR TAB WIDGET =====
class CalendarTab extends StatefulWidget {
  final VoidCallback onOpenZakatCalculator;
  const CalendarTab({
    super.key,
    required this.onOpenZakatCalculator,
  });
  @override
  State<CalendarTab> createState() => _CalendarTabState();
}
class _CalendarTabState extends State<CalendarTab> {
  DateTime _currentMonth = DateTime(2026, 7, 1);
  DateTime _selectedDate = DateTime(2026, 7, 13);
  bool _isBengali = false;
  bool _showCalendarGridTab = true;
  final Map<String, bool> _activityStatus = {};
  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _selectedDate = today;
    _currentMonth = DateTime(today.year, today.month, 1);
  }
  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
      _selectDefaultDateForMonth(_currentMonth);
    });
  }
  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
      _selectDefaultDateForMonth(_currentMonth);
    });
  }
  void _selectDefaultDateForMonth(DateTime month) {
    final today = DateTime.now();
    if (today.year == month.year && today.month == month.month) {
      _selectedDate = today;
    } else {
      _selectedDate = DateTime(month.year, month.month, 1);
    }
  }
  // Fasting checks
  bool _isMondayOrThursday(DateTime date) {
    return date.weekday == DateTime.monday || date.weekday == DateTime.thursday;
  }
  bool _isWhiteDay(HijriDate hijri) {
    return hijri.day == 13 || hijri.day == 14 || hijri.day == 15;
  }
  @override
  Widget build(BuildContext context) {
    final daysInMonthString = DateFormat('d').format(DateTime(_currentMonth.year, _currentMonth.month + 1, 0));
    final daysCount = int.parse(daysInMonthString);
    final firstDayOfWeek = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday % 7; // 0 for Sunday
    final currentHijriMonthStart = HijriConverter.fromGregorian(DateTime(_currentMonth.year, _currentMonth.month, 1));
    final currentHijriMonthEnd = HijriConverter.fromGregorian(DateTime(_currentMonth.year, _currentMonth.month, daysCount));
    String hijriRangeStr = '';
    if (currentHijriMonthStart.month == currentHijriMonthEnd.month) {
      final mName = _isBengali ? currentHijriMonthStart.monthNameBengali : currentHijriMonthStart.monthName;
      hijriRangeStr = '$mName ${currentHijriMonthStart.year}';
    } else {
      final mNameStart = _isBengali ? currentHijriMonthStart.monthNameBengali : currentHijriMonthStart.monthName;
      final mNameEnd = _isBengali ? currentHijriMonthEnd.monthNameBengali : currentHijriMonthEnd.monthName;
      hijriRangeStr = '$mNameStart - $mNameEnd ${currentHijriMonthStart.year}';
    }
    final selectedHijri = HijriConverter.fromGregorian(_selectedDate);
    final selectedEvent = CalendarDatabase.getEvent(_selectedDate, selectedHijri);
    final selectedIsFasting = _isMondayOrThursday(_selectedDate) || _isWhiteDay(selectedHijri);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER WITH LANG TOGGLE
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isBengali ? 'ইসলামিক ক্যালেন্ডার' : 'Islamic Calendar',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navyBlue,
                    ),
                  ),
                  // Premium English / বাংলা toggle pill
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.dustyBlueTeal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _isBengali = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: !_isBengali ? AppColors.navyBlue : Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              'EN',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: !_isBengali ? Colors.white : AppColors.navyBlue,
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _isBengali = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _isBengali ? AppColors.navyBlue : Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              'বাংলা',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _isBengali ? Colors.white : AppColors.navyBlue,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Tab bar selection: Calendar Grid vs Special Events
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _showCalendarGridTab = true),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: _showCalendarGridTab
                              ? AppColors.navyBlue
                              : const Color(0xFFF3F7F9),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _showCalendarGridTab
                              ? [
                                  BoxShadow(
                                    color: AppColors.navyBlue.withValues(alpha: 0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  )
                                ]
                              : [],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_view_month_rounded,
                              size: 16,
                              color: _showCalendarGridTab ? Colors.white : AppColors.navyBlue,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isBengali ? 'ক্যালেন্ডার গ্রিড' : 'Calendar Grid',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _showCalendarGridTab ? Colors.white : AppColors.navyBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _showCalendarGridTab = false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: !_showCalendarGridTab
                              ? AppColors.navyBlue
                              : const Color(0xFFF3F7F9),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: !_showCalendarGridTab
                              ? [
                                  BoxShadow(
                                    color: AppColors.navyBlue.withValues(alpha: 0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  )
                                ]
                              : [],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_note_rounded,
                              size: 16,
                              color: !_showCalendarGridTab ? Colors.white : AppColors.navyBlue,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isBengali ? 'বিশেষ দিনসমূহ' : 'Special Events',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: !_showCalendarGridTab ? Colors.white : AppColors.navyBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.dustyBlueTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            DateFormat('MMMM yyyy').format(_currentMonth),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hijriRangeStr,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: AppColors.dustyBlueTeal,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 20),
                      onPressed: _nextMonth,
                    ),
                  ],
                ),
              ),
              if (_showCalendarGridTab) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    _legendDot(AppColors.coralOrange, _isBengali ? 'ইসলামিক দিবস' : 'Islamic event'),
                    const SizedBox(width: 16),
                    _legendDot(AppColors.midTeal, _isBengali ? 'নফল রোজা' : 'Sunnah fast'),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((day) {
                    return SizedBox(
                      width: 40,
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.navyBlue.withValues(alpha: 0.5),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (!constraints.maxWidth.isFinite || constraints.maxWidth <= 0) {
                      return const SizedBox(
                        height: 320,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return _buildCalendarGrid(firstDayOfWeek, daysCount);
                  },
                ),
                const SizedBox(height: 25),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.dustyBlueTeal.withValues(alpha: 0.15)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.navyBlue.withValues(alpha: 0.04),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                        style: GoogleFonts.poppins(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.navyBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedHijri.format(_isBengali),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.midTeal,
                        ),
                      ),
                      const Divider(height: 25, thickness: 1),
                      _buildPrayerTimesSection(),
                      const SizedBox(height: 18),
                      _buildRelatedAyahSection(selectedEvent),
                      const SizedBox(height: 18),
                      if (selectedEvent != null) ...[
                        _buildEventPromptCard(selectedEvent, selectedHijri),
                      ] else if (selectedIsFasting) ...[
                        _buildFastingDetailCard(selectedHijri),
                      ] else ...[
                        _buildRegularDayCard(),
                      ]
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 20),
                _buildSpecialEventsList(),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialEventsList() {
    final year = _currentMonth.year;
    final events = _getEventsForYear(year);

    if (events.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(30),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.dustyBlueTeal.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            const Icon(Icons.event_busy_rounded, size: 40, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              _isBengali ? 'কোন বিশেষ দিন পাওয়া যায়নি' : 'No special events found',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.navyBlue,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            _isBengali ? '$year সালের বিশেষ দিনসমূহ' : 'Special Events in $year',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.navyBlue,
            ),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: events.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final entry = events[index];
            final date = entry.key;
            final event = entry.value;
            final eventHijri = HijriConverter.fromGregorian(date);

            final eventTitle = _isBengali ? event.titleBengali : event.title;
            final eventDesc = _isBengali ? event.descriptionBengali : event.description;
            final gregorianStr = DateFormat('EEEE, MMMM d, yyyy').format(date);
            final hijriStr = eventHijri.format(_isBengali);
            final color = event.themeColor;

            // Highlight if the event is in the currently viewed month
            final isCurrentMonth = date.month == _currentMonth.month;

            return Container(
              decoration: BoxDecoration(
                color: isCurrentMonth
                    ? color.withValues(alpha: 0.05)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isCurrentMonth
                      ? color.withValues(alpha: 0.25)
                      : AppColors.dustyBlueTeal.withValues(alpha: 0.15),
                  width: isCurrentMonth ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.navyBlue.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        color: color,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      eventTitle,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.navyBlue,
                                      ),
                                    ),
                                  ),
                                  if (isCurrentMonth)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _isBengali ? 'এই মাস' : 'This Month',
                                        style: GoogleFonts.poppins(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                gregorianStr,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.midTeal,
                                ),
                              ),
                              Text(
                                hijriStr,
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.navyBlue.withValues(alpha: 0.5),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                eventDesc,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.navyBlue.withValues(alpha: 0.7),
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: TextButton.icon(
                                  onPressed: () => _openEventDetail(event, date, eventHijri),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    backgroundColor: color.withValues(alpha: 0.1),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  icon: Icon(Icons.menu_book_rounded, size: 13, color: color),
                                  label: Text(
                                    _isBengali ? 'বিস্তারিত দেখুন' : 'View Details',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  List<MapEntry<DateTime, IslamicEvent>> _getEventsForYear(int year) {
    List<MapEntry<DateTime, IslamicEvent>> events = [];
    for (int month = 1; month <= 12; month++) {
      int daysInMonth = DateTime(year, month + 1, 0).day;
      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(year, month, day);
        final cellHijri = HijriConverter.fromGregorian(date);
        final event = CalendarDatabase.getEvent(date, cellHijri);
        if (event != null) {
          if (events.isNotEmpty &&
              events.last.value.title == event.title &&
              date.difference(events.last.key).inDays <= 1) {
            continue;
          }
          events.add(MapEntry(date, event));
        }
      }
    }
    return events;
  }

  // Extracted so the LayoutBuilder guard above can stay simple. Builds the
  // actual 6-week grid once we know we have a real, finite width to lay
  // out against.
  Widget _buildCalendarGrid(int firstDayOfWeek, int daysCount) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.82,
      ),
      itemCount: 42,
      itemBuilder: (context, index) {
        final int dayNumber = index - firstDayOfWeek + 1;
        if (dayNumber <= 0 || dayNumber > daysCount) {
          return const SizedBox();
        }
        final cellDate = DateTime(_currentMonth.year, _currentMonth.month, dayNumber);
        final cellHijri = HijriConverter.fromGregorian(cellDate);
        final isSelected = cellDate.year == _selectedDate.year &&
            cellDate.month == _selectedDate.month &&
            cellDate.day == _selectedDate.day;
        final now = DateTime.now();
        final isToday =
            cellDate.year == now.year && cellDate.month == now.month && cellDate.day == now.day;
        final event = CalendarDatabase.getEvent(cellDate, cellHijri);
        final hasEvent = event != null;
        final isFasting = _isMondayOrThursday(cellDate) || _isWhiteDay(cellHijri);

        Color cellBgColor = Colors.transparent;
        Border? cellBorder;

        if (isSelected) {
          cellBgColor = AppColors.navyBlue;
        } else {
          if (hasEvent) {
            cellBgColor = AppColors.coralOrange.withValues(alpha: 0.15);
            cellBorder = Border.all(color: AppColors.coralOrange.withValues(alpha: 0.4), width: 1);
          } else if (isFasting) {
            cellBgColor = AppColors.midTeal.withValues(alpha: 0.15);
            cellBorder = Border.all(color: AppColors.midTeal.withValues(alpha: 0.4), width: 1);
          }

          if (isToday) {
            cellBorder = Border.all(color: AppColors.navyBlue, width: 1.5);
          }
        }

        return GestureDetector(
          onTap: () {
            setState(() => _selectedDate = cellDate);
            if (hasEvent) {
              _openEventDetail(event, cellDate, cellHijri);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: cellBgColor,
              borderRadius: BorderRadius.circular(12),
              border: cellBorder,
            ),
            padding: const EdgeInsets.all(7),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    dayNumber.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppColors.navyBlue,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    cellHijri.day.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.dustyBlueTeal
                          : AppColors.navyBlue.withValues(alpha: 0.45),
                    ),
                  ),
                ),
                if (hasEvent || isFasting)
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Container(
                      width: 5.5,
                      height: 5.5,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white
                            : (hasEvent ? AppColors.coralOrange : AppColors.midTeal),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: AppColors.navyBlue.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }

  IconData _getPrayerIcon(String name) {
    switch (name.toLowerCase()) {
      case 'fajr':
        return Icons.wb_twilight_rounded;
      case 'dhuhr':
        return Icons.wb_sunny_rounded;
      case 'asr':
        return Icons.wb_cloudy_rounded;
      case 'maghrib':
        return Icons.brightness_4_rounded;
      case 'isha':
        return Icons.nights_stay_rounded;
      default:
        return Icons.access_time_rounded;
    }
  }

  Widget _buildPrayerCard(PrayerTimeEntry entry) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dustyBlueTeal.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navyBlue.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                _getPrayerIcon(entry.name),
                size: 13,
                color: AppColors.navyBlue.withValues(alpha: 0.65),
              ),
              const SizedBox(width: 6),
              Text(
                _isBengali ? entry.nameBengali : entry.name,
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navyBlue,
                ),
              ),
            ],
          ),
          Text(
            DateFormat('h:mm a').format(entry.time),
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: AppColors.midTeal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerCardCentered(PrayerTimeEntry entry) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dustyBlueTeal.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navyBlue.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getPrayerIcon(entry.name),
            size: 13,
            color: AppColors.navyBlue.withValues(alpha: 0.65),
          ),
          const SizedBox(width: 6),
          Text(
            _isBengali ? entry.nameBengali : entry.name,
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: AppColors.navyBlue,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            DateFormat('h:mm a').format(entry.time),
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: AppColors.midTeal,
            ),
          ),
        ],
      ),
    );
  }
  // ===== SEGMENTED COMPONENT: DETAILS PANEL =====
  Widget _buildDetailsPanel(HijriDate selectedHijri, IslamicEvent? selectedEvent, bool selectedIsFasting) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.dustyBlueTeal.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navyBlue.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
            style: GoogleFonts.poppins(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: AppColors.navyBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            selectedHijri.format(_isBengali),
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.midTeal,
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildPrayerCard(times[0])),
                  const SizedBox(width: 8),
                  Expanded(child: _buildPrayerCard(times[1])),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildPrayerCard(times[2])),
                  const SizedBox(width: 8),
                  Expanded(child: _buildPrayerCard(times[3])),
                ],
              ),
              const SizedBox(height: 8),
              _buildPrayerCardCentered(times[4]),
            ],
          ),
        );
      },
    );
  }
  // ===== HELPER: GREGORIAN DATE RESOLVERS FOR EVENTS LIST =====
  String _getGregorianDateForEvent(String hijriKey, int year) {
    final rawDate = _getGregorianDateForEventRaw(hijriKey, year);
    if (rawDate.isNotEmpty) {
      final date = DateTime.parse(rawDate);
      return DateFormat('dd MMMM, yyyy').format(date);
    }
    return '';
  }
  String _getGregorianDateForEventRaw(String hijriKey, int year) {
    for (var entry in CalendarDatabase.gregorianOverrides.entries) {
      if (entry.key.startsWith('$year-') && entry.value == hijriKey) {
        return entry.key;
      }
    }
    // Fallback search to 2026/2027 mapping
    for (var entry in CalendarDatabase.gregorianOverrides.entries) {
      if (entry.key.startsWith('2026-') && entry.value == hijriKey) {
        return entry.key.replaceAll('2026-', '$year-');
      }
    }
    return '';
  }
  // ===== RENDER EVENT DETAILS =====
  Widget _buildEventDetailCard(IslamicEvent event) {
    final title = _isBengali ? event.titleBengali : event.title;
    final description = _isBengali ? event.descriptionBengali : event.description;
    final history = _isBengali ? event.historyBengali : event.history;
    final activities = _isBengali ? event.activitiesBengali : event.activities;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Event Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: event.themeColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: event.themeColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rounded, color: event.themeColor, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: event.themeColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Description
        Text(
          _isBengali ? 'বিবরণ' : 'Description',
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: AppColors.navyBlue,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.navyBlue.withValues(alpha: 0.75),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 18),
        // History
        Text(
          _isBengali ? 'ইতিহাস ও গুরুত্ব' : 'History & Significance',
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: AppColors.navyBlue,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          history,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.navyBlue.withValues(alpha: 0.75),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        // Recommended Activities
        Text(
          _isBengali ? 'করণীয় আমলসমূহ' : 'Recommended Activities',
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: AppColors.navyBlue,
          ),
        ),
        const SizedBox(height: 10),
        Column(
          children: List.generate(activities.length, (index) {
            final key = '${DateFormat('yyyyMMdd').format(_selectedDate)}_event_$index';
            final isChecked = _activityStatus[key] ?? false;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: CheckboxListTile(
                value: isChecked,
                onChanged: (val) {
                  setState(() {
                    _activityStatus[key] = val ?? false;
                  });
                },
                title: Text(
                  activities[index],
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: AppColors.navyBlue.withValues(alpha: 0.8),
                    decoration: isChecked ? TextDecoration.lineThrough : null,
                  ),
                ),
                activeColor: AppColors.midTeal,
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            );
          }),
        ),
      ],
    );
  }
  // ===== RENDER FASTING DETAILS =====
  Widget _buildFastingDetailCard(HijriDate hijri) {
    final isWhiteDay = _isWhiteDay(hijri);
    final isMonday = _selectedDate.weekday == DateTime.monday;
    String fastingTitle = '';
    String fastingTitleBn = '';
    String fastingDesc = '';
    String fastingDescBn = '';
    String fastingHistory = '';
    String fastingHistoryBn = '';
    List<String> fastingActs = [];
    List<String> fastingActsBn = [];
    if (isWhiteDay) {
      fastingTitle = 'Ayyam al-Beedh (White Days) Fast';
      fastingTitleBn = 'আইয়ামে বিজের রোজা (চন্দ্র মাসের ১৩, ১৪ ও ১৫ তারিখ)';
      fastingDesc = 'Fasting on the 13th, 14th, and 15th of the lunar month is highly recommended.';
      fastingDescBn = 'প্রতি হিজরি মাসের ১৩, ১৪ ও ১৫ তারিখ রোজা রাখা অত্যন্ত সওয়াবের কাজ ও গুরুত্বপূর্ণ সুন্নাত।';
      fastingHistory = 'The Prophet Muhammad (PBUH) instructed his companions to fast three days of every month—the white days—saying that it is like fasting a lifetime because the reward of a good deed is multiplied tenfold.';
      fastingHistoryBn = 'রাসূলুল্লাহ (সা.) সাহাবিদের প্রতি মাসে তিনটি রোজা (আইয়ামে বিজ) রাখার নির্দেশ দিতেন। তিনি বলেন, প্রতি কাজের সওয়াব দশ গুণ বৃদ্ধি পাওয়ার কারণে তিন দিনের রোজা সারা বছর রোজা রাখার সমান।';
      fastingActs = [
        'Keep the fast (abstain from food & drink from dawn to sunset).',
        'Read Quran and perform voluntary prayers.',
        'Make dua at the time of breaking the fast (Iftar), as the fasting person\'s prayer is accepted.',
        'Give charity (Sadaqah).',
      ];
      fastingActsBn = [
        'রোজা রাখা (সুবহে সাদেক থেকে সূর্যাস্ত পর্যন্ত পানাহার থেকে বিরত থাকা)।',
        'কোরআন তিলাওয়াত ও নফল নামাজ আদায় করা।',
        'ইফতারের সময় আল্লাহর কাছে দুআ করা, কেননা রোজাদারের দুআ ফিরিয়ে দেওয়া হয় না।',
        'অভাবীকে দান-সদকা করা।',
      ];
    } else {
      final dayName = isMonday ? 'Monday' : 'Thursday';
      final dayNameBn = isMonday ? 'সোমবার' : 'বৃহস্পতিবার';
      fastingTitle = 'Sunnah $dayName Fast';
      fastingTitleBn = 'সুন্নাত $dayNameBn-এর রোজা';
      fastingDesc = 'Fasting on Mondays and Thursdays is an established practice of the Messenger of Allah (PBUH).';
      fastingDescBn = 'সোমবার এবং বৃহস্পতিবার রোজা রাখা মহানবী হযরত মুহাম্মদ (সা.)-এর নিয়মিত আমল ও সুন্নাত ছিল।';
      fastingHistory = 'The Prophet (PBUH) said: "The deeds of people are presented (to Allah) on Mondays and Thursdays, and I like that my deeds are presented while I am fasting." It was also on a Monday that the Prophet was born and began receiving revelation.';
      fastingHistoryBn = 'নবীজি (সা.) বলেছেন, "সোমবার ও বৃহস্পতিবার বান্দার আমল আল্লাহর দরবারে পেশ করা হয়। আর আমার আমল রোজা রাখা অবস্থায় পেশ করা হোক, এটাই আমি পছন্দ করি।" তাছাড়া সোমবারে নবীজির জন্ম ও নবুওয়াত প্রকাশ পেয়েছিল।';
      fastingActs = [
        'Perform the Sunnah fast.',
        'Make Iftar supplications and feed another fasting person if possible.',
        'Increase Dhikr (remembrance of Allah) throughout the day.',
        'Seek forgiveness for oneself and the Ummah.',
      ];
      fastingActsBn = [
        'সুন্নাত রোজা রাখা।',
        'ইফতারের সময় দুআ করা এবং সম্ভব হলে কোনো রোজাদারকে ইফতার করানো।',
        'সারা দিন কাজের ফাকে জিকির করা।',
        'নিজের জন্য এবং পুরো মুসলিম উম্মাহর জন্য ক্ষমা প্রার্থনা করা।',
      ];
    }
    final title = _isBengali ? fastingTitleBn : fastingTitle;
    final description = _isBengali ? fastingDescBn : fastingDesc;
    final history = _isBengali ? fastingHistoryBn : fastingHistory;
    final activities = _isBengali ? fastingActsBn : fastingActs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fasting Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.midTeal.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.midTeal.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.favorite_rounded, color: AppColors.midTeal, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.midTeal,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Description
        Text(
          _isBengali ? 'বিবরণ' : 'Description',
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: AppColors.navyBlue,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.navyBlue.withValues(alpha: 0.75),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 18),
        // History
        Text(
          _isBengali ? 'ইতিহাস ও গুরুত্ব' : 'History & Significance',
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: AppColors.navyBlue,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          history,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.navyBlue.withValues(alpha: 0.75),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        // Fasting Activities
        Text(
          _isBengali ? 'আমল ও করণীয়' : 'Spiritual Activities',
          style: GoogleFonts.poppins(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: AppColors.navyBlue,
          ),
        ),
        const SizedBox(height: 10),
        Column(
          children: List.generate(activities.length, (index) {
            final key = '${DateFormat('yyyyMMdd').format(_selectedDate)}_fasting_$index';
            final isChecked = _activityStatus[key] ?? false;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: CheckboxListTile(
                value: isChecked,
                onChanged: (val) {
                  setState(() {
                    _activityStatus[key] = val ?? false;
                  });
                },
                title: Text(
                  activities[index],
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: AppColors.navyBlue.withValues(alpha: 0.8),
                    decoration: isChecked ? TextDecoration.lineThrough : null,
                  ),
                ),
                activeColor: AppColors.midTeal,
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            );
          }),
        ),
      ],
    );
  }
  // ===== RENDER REGULAR DAY PLANNER =====
  Widget _buildRegularDayCard() {
    final List<String> dailyActs = [
      'Perform all 5 daily prayers on time (Fajr, Dhuhr, Asr, Maghrib, Isha).',
      'Recite Morning & Evening Adhkar (remembrance).',
      'Read at least one page of the Holy Quran with translation.',
      'Recite Salawat (100 times) and Istighfar (100 times).',
      'Do a voluntary good deed (help family, check on a neighbor, give charity).',
    ];
    final List<String> dailyActsBn = [
      'পাঁচ ওয়াক্ত ফরজ নামাজ সময়মতো আদায় করা (ফজর, জোহর, আসর, মাগরিব, এশা)।',
      'সকাল ও সন্ধ্যার মাসনুন জিকির ও দুআসমূহ (আজকার) পাঠ করা।',
      'অর্থসহ অন্তত এক পৃষ্ঠা পবিত্র কোরআন তিলাওয়াত ও তাদাব্বুর করা।',
      '১০০ বার দরূদ পাঠ ও ১০০ বার ইস্তিগফার (ক্ষমাপ্রার্থনা) করা।',
      'একটি নফল ভালো কাজ করা (পরিবারকে সাহায্য, দান বা ভালো কথা বলা)।',
    ];
    final title = _isBengali ? 'দৈনিক ইসলামি নির্দেশিকা' : 'Daily Islamic Guidance';
    final activities = _isBengali ? dailyActsBn : dailyActs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Row(
          children: [
            const Icon(Icons.wb_sunny_outlined, color: AppColors.navyBlue, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.navyBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _isBengali
              ? 'একটি নিয়মিত আধ্যাত্মিক রুটিন বজায় রাখা ঈমান মজবুত করতে সাহায্য করে। নিচের তালিকাটি ব্যবহার করে আজকের আমলগুলো ট্র্যাক করুন:'
              : 'Maintaining a structured daily spiritual routine strengthens your faith. Check off today\'s actions as you complete them:',
          style: GoogleFonts.inter(
            fontSize: 12.5,
            color: AppColors.navyBlue.withValues(alpha: 0.65),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        // Checklist items
        Column(
          children: List.generate(activities.length, (index) {
            final key = '${DateFormat('yyyyMMdd').format(_selectedDate)}_regular_$index';
            final isChecked = _activityStatus[key] ?? false;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: CheckboxListTile(
                value: isChecked,
                onChanged: (val) {
                  setState(() {
                    _activityStatus[key] = val ?? false;
                  });
                },
                title: Text(
                  activities[index],
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: AppColors.navyBlue.withValues(alpha: 0.8),
                    decoration: isChecked ? TextDecoration.lineThrough : null,
                  ),
                ),
                activeColor: AppColors.midTeal,
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            );
          }),
        ),
      ],
    );
  }
}