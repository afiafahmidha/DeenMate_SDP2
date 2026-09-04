import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:adhan/adhan.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/auth_header.dart';
// Adjust this path if notification_service.dart lives elsewhere in your project.
import '../services/notification_service.dart';
import '../widgets/notification_center_modal.dart';

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
  String get monthName => monthNames[month - 1];
  String format() => '$day $monthName $year AH';
}


class _CalendarStarConfig {
  final double topFraction;
  final double leftFraction;
  final double size;
  final int delayMs;

  _CalendarStarConfig({required this.topFraction, required this.leftFraction, required this.size, required this.delayMs});
}

class _CalendarTwinklingStar extends StatefulWidget {
  final double topFraction;
  final double leftFraction;
  final double size;
  final int delayMs;

  const _CalendarTwinklingStar({required this.topFraction, required this.leftFraction, required this.size, required this.delayMs});

  @override
  State<_CalendarTwinklingStar> createState() => _CalendarTwinklingStarState();
}

class _CalendarTwinklingStarState extends State<_CalendarTwinklingStar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _opacity = Tween<double>(begin: 0.25, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
            child: CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _CalendarStarPainter(),
            ),
          );
        },
      ),
    );
  }
}

class _CalendarStarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFFFE082).withValues(alpha: 0.9)..style = PaintingStyle.fill;
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
    final corePaint = Paint()..color = Colors.white.withValues(alpha: 0.95)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), size.width * 0.12, corePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CalendarTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.navyBlue.withValues(alpha: 0.015)..strokeWidth = 0.4..style = PaintingStyle.stroke;
    final double gridWidth = 16.0;
    final int rows = (size.height / gridWidth).ceil() + 1;
    final int cols = (size.width / gridWidth).ceil() + 1;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        double x = c * gridWidth;
        double y = r * gridWidth;
        canvas.drawRect(Rect.fromLTWH(x - gridWidth / 2, y - gridWidth / 2, gridWidth, gridWidth), paint);
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(math.pi / 4);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: gridWidth, height: gridWidth), paint);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ===== HIJRI CONVERTER =====
// NOTE: Still a tabular approximation with manual Gregorian overrides for
// 2026/2027. Swapping this for a true Umm al-Qura calculation (or a moon-
// sighting service) is tracked separately — flagging it here so it isn't
// lost, since the roadmap message calls for events to be driven off that
// calculation rather than off this table.
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
    int jd = gToJd(date.year, date.month, date.day);
    return jdToH(jd);
  }
}

// ===== HIJRI API SERVICE (AlAdhan) =====
// Fetches Hijri dates for a whole Gregorian month in ONE request from the
// AlAdhan Islamic Calendar API (https://aladhan.com), using the Umm al-Qura
// astronomical calculation — a widely-used standard, and far more accurate
// than the raw tabular arithmetic in HijriConverter above.
//
// Important nuance: this is a *calculated* calendar, not a live feed of
// actual regional crescent-sighting announcements (no such public API
// exists anywhere — moon-sighting committees announce case by case, not
// through an API). That's exactly what CalendarDatabase.gregorianOverrides
// is for: it stays the final source of truth for any date where Bangladesh's
// official moon-sighting announcement is confirmed to differ from the
// calculated date. Priority order used everywhere in this file is:
//   1. gregorianOverrides (confirmed local moon-sighting correction)
//   2. HijriApiService cache (AlAdhan / Umm al-Qura calculation)
//   3. HijriConverter.fromGregorian (local arithmetic fallback — used only
//      while the API call is still in flight, or if it fails/there's no
//      internet, so the calendar never breaks or looks empty).
class HijriApiService {
  static const String _baseUrl = 'https://api.aladhan.com/v1/gToHCalendar';
  // Umm al-Qura — the most widely recognised astronomical Hijri method.
  static const String _calendarMethod = 'UAQ';

  static final Map<String, HijriDate> _cache = {};
  static final Set<String> _fetchedMonths = {}; // "yyyy-MM" already requested

  static String _dayKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
  static String _monthKey(int year, int month) =>
      '$year-${month.toString().padLeft(2, '0')}';

  /// Fetches and caches the Hijri date for every day of [month]/[year].
  /// Safe to call repeatedly — a month already fetched (or in flight)
  /// returns immediately without hitting the network again.
  static Future<void> fetchMonth(int year, int month) async {
    final mKey = _monthKey(year, month);
    if (_fetchedMonths.contains(mKey)) return;
    _fetchedMonths.add(mKey);

    try {
      final uri = Uri.parse('$_baseUrl/$month/$year?calendarMethod=$_calendarMethod');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        _fetchedMonths.remove(mKey); // allow a retry later
        return;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as List<dynamic>?;
      if (data == null) {
        _fetchedMonths.remove(mKey);
        return;
      }

      for (final entry in data) {
        final e = entry as Map<String, dynamic>;
        final gregorian = e['gregorian'] as Map<String, dynamic>;
        final hijri = e['hijri'] as Map<String, dynamic>;
        final gDateParts = (gregorian['date'] as String).split('-'); // DD-MM-YYYY
        final key = '${gDateParts[2]}-${gDateParts[1]}-${gDateParts[0]}'; // yyyy-MM-dd

        final hDay = int.parse(hijri['day'].toString());
        final hMonth = int.parse((hijri['month'] as Map<String, dynamic>)['number'].toString());
        final hYear = int.parse(hijri['year'].toString());
        _cache[key] = HijriDate(hYear, hMonth, hDay);
      }
    } catch (_) {
      // Offline or the API is down — never let this break the calendar.
      // Just remove the month from "fetched" so a later navigation can
      // retry, and let callers keep using the arithmetic fallback.
      _fetchedMonths.remove(mKey);
    }
  }

  /// Returns the API-sourced Hijri date if already fetched, else null.
  static HijriDate? cached(DateTime date) => _cache[_dayKey(date)];
}

class IslamicEvent {
  final String title;
  final String description;
  final String history;
  final List<String> activities;
  final Color themeColor;
  final String? backgroundImagePath;
  // NEW: set of photos shown as an auto-scrolling carousel on the detail
  // page hero, instead of a flat theme-color gradient. Put 5-6 related
  // images per event at these paths (and register the folder in
  // pubspec.yaml). If left empty, the hero falls back to
  // backgroundImagePath (single image) and finally to a themeColor
  // gradient — nothing breaks if the assets aren't there yet.
  final List<String> heroImages;
  const IslamicEvent({
    required this.title,
    required this.description,
    required this.history,
    required this.activities,
    this.themeColor = const Color(0xFFEB8A6C),
    this.backgroundImagePath,
    this.heroImages = const [],
  });

  List<String> get carouselImages {
    if (heroImages.isNotEmpty) return heroImages;
    if (backgroundImagePath != null) return [backgroundImagePath!];
    return const [];
  }
}

class CalendarDatabase {
  // Key: Month/Day as "Month-Day"
  static final Map<String, IslamicEvent> hijriEvents = {
    '1-1': const IslamicEvent(
      title: 'Islamic New Year',
      description: 'First day of the Hijri year. It marks the migration of Prophet Muhammad (PBUH) from Makkah to Madinah.',
      history: 'The Islamic calendar was introduced during the caliphate of Umar ibn al-Khattab, choosing the Hijrah (migration) in 622 CE as the starting point of the calendar because it marked the establishment of the first sovereign Muslim community.',
      activities: [
        'Reflect on the lessons of Hijrah (sacrifice, perseverance, and brotherhood).',
        'Make resolutions for spiritual improvement in the new year.',
        'Offer voluntary prayers and seek forgiveness for the past year\'s shortcomings.',
        'Read about the early history of Madinah and the Ansar.',
      ],
      backgroundImagePath: 'assets/images/islamic_events/islamic_new_year.jpg',
      heroImages: [
        'assets/images/islamic_events/islamic_new_year/1.jpg',
        'assets/images/islamic_events/islamic_new_year/2.jpg',
        'assets/images/islamic_events/islamic_new_year/3.jpg',
        'assets/images/islamic_events/islamic_new_year/4.jpg',
        'assets/images/islamic_events/islamic_new_year/5.jpg',
        'assets/images/islamic_events/islamic_new_year/6.jpg',
      ],
    ),
    '1-10': const IslamicEvent(
      title: 'Day of Ashura',
      description: 'The 10th of Muharram is a day of historic deliverance, gratitude, and remembrance of sacrifices.',
      history: 'On this day, Allah split the Red Sea to deliver Prophet Musa (Moses) and the Children of Israel from the tyranny of Pharaoh. It is also the day of the tragic martyrdom of Imam Hussain (RA), the grandson of the Prophet, at the Battle of Karbala while standing up against injustice.',
      activities: [
        'Fast on the 10th of Muharram, along with either the 9th or 11th (expiates the sins of the previous year).',
        'Provide generous meals and charity to family, relatives, and the poor.',
        'Recite abundant Istighfar (seeking forgiveness) and Salawat.',
        'Reflect on Imam Hussain\'s bravery in standing up for justice and the truth.',
      ],
      themeColor: Color(0xFFC84B31),
      backgroundImagePath: 'assets/images/islamic_events/ashura.jpg',
      heroImages: [
        'assets/images/islamic_events/ashura/1.jpg',
        'assets/images/islamic_events/ashura/2.jpg',
        'assets/images/islamic_events/ashura/3.jpg',
        'assets/images/islamic_events/ashura/4.jpg',
        'assets/images/islamic_events/ashura/5.jpg',
        'assets/images/islamic_events/ashura/6.jpg',
      ],
    ),
    '3-12': const IslamicEvent(
      title: 'Mawlid al-Nabi',
      description: 'The birth anniversary of the Prophet Muhammad (PBUH), sent as a mercy to all creation.',
      history: 'Prophet Muhammad (PBUH) was born in Makkah in the Year of the Elephant (circa 570 CE). His arrival transformed Arabia and guided humanity from darkness into the light of monotheism and character excellence.',
      activities: [
        'Send abundant blessings and Salawat upon the Prophet (PBUH).',
        'Read and study the Seerah (biography) of the Prophet.',
        'Gather with family to discuss and share the character, kindness, and mercy of the Prophet.',
        'Give charity (Sadaqah) and feed the needy to spread the Prophet\'s spirit of compassion.',
      ],
      backgroundImagePath: 'assets/images/islamic_events/mawlid.jpg',
      heroImages: [
        'assets/images/islamic_events/mawlid/1.jpg',
        'assets/images/islamic_events/mawlid/2.jpg',
        'assets/images/islamic_events/mawlid/3.jpg',
        'assets/images/islamic_events/mawlid/4.jpg',
        'assets/images/islamic_events/mawlid/5.jpg',
        'assets/images/islamic_events/mawlid/6.jpg',
      ],
    ),
    '7-27': const IslamicEvent(
      title: 'Isra\' and Mi\'raj',
      description: 'The miraculous Night Journey and Ascension of Prophet Muhammad (PBUH) through the heavens.',
      history: 'In a single night, the Prophet was taken from Makkah to Jerusalem (Al-Aqsa Mosque) and ascended through the seven heavens to meet Allah. On this night, the five daily prayers (Salah) were gifted to the Muslim Ummah as a direct connection to Allah.',
      activities: [
        'Guard your daily Salah and focus on improving its quality and humility (Khushu).',
        'Perform voluntary night prayers (Tahajjud) and make sincere Duas.',
        'Read Surah Al-Isra and study the significance of Jerusalem and Al-Aqsa Mosque in Islam.',
        'Share lessons of faith and trust in Allah with family.',
      ],
      backgroundImagePath: 'assets/images/islamic_events/isra_miraj.jpg',
      heroImages: [
        'assets/images/islamic_events/isra_miraj/1.jpg',
        'assets/images/islamic_events/isra_miraj/2.jpg',
        'assets/images/islamic_events/isra_miraj/3.jpg',
        'assets/images/islamic_events/isra_miraj/4.jpg',
        'assets/images/islamic_events/isra_miraj/5.jpg',
        'assets/images/islamic_events/isra_miraj/6.jpg',
      ],
    ),
    '8-15': const IslamicEvent(
      title: 'Shab-e-Barat (Mid-Sha\'ban)',
      description: 'The Night of Salvation and Records. A night of immense divine mercy, forgiveness, and decree.',
      history: 'According to tradition, Allah descends to the lowest heaven on the night of 15th Sha\'ban to forgive seeking servants and write decrees for the year regarding life, death, and sustenance.',
      activities: [
        'Perform night prayers (Qiyam-ul-Layl) and recite Quran.',
        'Fast on the 15th day of Sha\'ban (Sunnah).',
        'Make intense supplication (Dua) for forgiveness, health, and halal sustenance.',
        'Reconcile with any relatives or friends you are not speaking to, as grudges prevent forgiveness.',
      ],
      backgroundImagePath: 'assets/images/islamic_events/shab_e_barat.jpg',
      heroImages: [
        'assets/images/islamic_events/shab_e_barat/1.jpg',
        'assets/images/islamic_events/shab_e_barat/2.jpg',
        'assets/images/islamic_events/shab_e_barat/3.jpg',
        'assets/images/islamic_events/shab_e_barat/4.jpg',
        'assets/images/islamic_events/shab_e_barat/5.jpg',
        'assets/images/islamic_events/shab_e_barat/6.jpg',
      ],
    ),
    '9-1': const IslamicEvent(
      title: 'First Day of Ramadan',
      description: 'The start of the blessed month of fasting, intense spiritual devotion, and Quran.',
      history: 'The month of Ramadan is the month in which the Quran was sent down as a guide for humanity. Fasting was made obligatory during the second year of Hijrah to teach Taqwa (God-consciousness).',
      activities: [
        'Intend to fast the whole month with sincere faith and reward-seeking.',
        'Establish congregational Taraweeh prayers.',
        'Set a daily target for reading and understanding the Holy Quran.',
        'Control speech from gossip, lying, and anger, and practice patience.',
      ],
      themeColor: Color(0xFF0F6F6B),
      backgroundImagePath: 'assets/images/islamic_events/ramadan_start.jpg',
      heroImages: [
        'assets/images/islamic_events/ramadan_start/1.jpg',
        'assets/images/islamic_events/ramadan_start/2.jpg',
        'assets/images/islamic_events/ramadan_start/3.jpg',
        'assets/images/islamic_events/ramadan_start/4.jpg',
        'assets/images/islamic_events/ramadan_start/5.jpg',
        'assets/images/islamic_events/ramadan_start/6.jpg',
      ],
    ),
    '9-27': const IslamicEvent(
      title: 'Laylat al-Qadr',
      description: 'The Night of Decree and Power, which is better than a thousand months (83 years) of worship.',
      history: 'Surah Al-Qadr was revealed regarding this night. It marks the commencement of the descent of the Quran from the Preserved Tablet (Lauh al-Mahfuz) to the earthly sky, to be revealed to the Prophet (PBUH).',
      activities: [
        'Spend the night in continuous prayer, Tahajjud, and Dua.',
        'Recite the special Dua: "Allahumma innaka \'afuwwun tuhibbul \'afwa fa\'fu \'anni".',
        'Give Sadaqah (even a small amount, as its reward is multiplied enormously).',
        'Perform I\'tikaf (spiritual seclusion) in the mosque if possible.',
      ],
      themeColor: Color(0xFF459490),
      backgroundImagePath: 'assets/images/islamic_events/laylat_al_qadr.jpg',
      heroImages: [
        'assets/images/islamic_events/laylat_al_qadr/1.jpg',
        'assets/images/islamic_events/laylat_al_qadr/2.jpg',
        'assets/images/islamic_events/laylat_al_qadr/3.jpg',
        'assets/images/islamic_events/laylat_al_qadr/4.jpg',
        'assets/images/islamic_events/laylat_al_qadr/5.jpg',
        'assets/images/islamic_events/laylat_al_qadr/6.jpg',
      ],
    ),
    '10-1': const IslamicEvent(
      title: 'Eid al-Fitr',
      description: 'The festival of breaking the fast, celebrating the successful completion of Ramadan.',
      history: 'Established by the Prophet Muhammad (PBUH) in Madinah as a day of thanksgiving to Allah, joy, and unity after fasting for a full month.',
      activities: [
        'Pay Zakat al-Fitr (Fitra) before the Eid prayer to help the poor.',
        'Perform Ghusl, wear clean or new clothes, and apply perfume.',
        'Eat something sweet (preferably dates in odd numbers) before heading to Eid prayer.',
        'Attend the Eid prayer, listen to the Khutbah, and greet the community.',
      ],
      themeColor: Color(0xFF84B5B4),
      backgroundImagePath: 'assets/images/islamic_events/eid_al_fitr.jpg',
      heroImages: [
        'assets/images/islamic_events/eid_al_fitr/1.jpg',
        'assets/images/islamic_events/eid_al_fitr/2.jpg',
        'assets/images/islamic_events/eid_al_fitr/3.jpg',
        'assets/images/islamic_events/eid_al_fitr/4.jpg',
        'assets/images/islamic_events/eid_al_fitr/5.jpg',
        'assets/images/islamic_events/eid_al_fitr/6.jpg',
      ],
    ),
    '12-9': const IslamicEvent(
      title: 'Day of Arafah',
      description: 'The pinnacle day of the Hajj pilgrimage and a day of supreme forgiveness and acceptance of Duas.',
      history: 'On this day, pilgrims gather on the plain of Mount Arafah to pray. It is the day Allah perfected the religion of Islam and completed His favors upon us. For non-pilgrims, fasting expiates the sins of the previous year and the coming year.',
      activities: [
        'Fast on this day (for those not performing Hajj) to expiate two years of sins.',
        'Make abundant Dua, especially the best Dua: "La ilaha illallahu wahdahu la sharika lahu...".',
        'Recite the Takbeeraat of Tashreeq ("Allahu Akbar, Allahu Akbar...") aloud after every obligatory prayer starting from Fajr.',
        'Seek sincere forgiveness and repent from all sins.',
      ],
      backgroundImagePath: 'assets/images/islamic_events/arafah.jpg',
      heroImages: [
        'assets/images/islamic_events/arafah/1.jpg',
        'assets/images/islamic_events/arafah/2.jpg',
        'assets/images/islamic_events/arafah/3.jpg',
        'assets/images/islamic_events/arafah/4.jpg',
        'assets/images/islamic_events/arafah/5.jpg',
        'assets/images/islamic_events/arafah/6.jpg',
      ],
    ),
    '12-10': const IslamicEvent(
      title: 'Eid al-Adha',
      description: 'The festival of sacrifice, commemorating the submission and devotion of Prophet Ibrahim (AS).',
      history: 'It honors the willingness of Prophet Ibrahim (AS) to sacrifice his son Ismail (AS) in obedience to Allah\'s command. Before the sacrifice, Allah replaced Ismail with a ram, establishing this tradition for generations.',
      activities: [
        'Perform the Eid prayer in the morning.',
        'Perform the Qurbani (sacrifice of a halal animal) if you have the financial means.',
        'Divide the meat into three parts: one for the poor, one for relatives/friends, and one for your family.',
        'Recite Takbeeraat of Tashreeq after every Salah.',
        'Maintain family ties and spread kindness.',
      ],
      themeColor: Color(0xFFEB8A6C),
      backgroundImagePath: 'assets/images/islamic_events/eid_al_adha.jpg',
      heroImages: [
        'assets/images/islamic_events/eid_al_adha/1.jpg',
        'assets/images/islamic_events/eid_al_adha/2.jpg',
        'assets/images/islamic_events/eid_al_adha/3.jpg',
        'assets/images/islamic_events/eid_al_adha/4.jpg',
        'assets/images/islamic_events/eid_al_adha/5.jpg',
        'assets/images/islamic_events/eid_al_adha/6.jpg',
      ],
    ),
  };
  // Gregorian Overrides for 2026 and 2027 to align perfectly with regional moon calendars
  static const Map<String, String> gregorianOverrides = {
    // 2026y
    '2026-01-16': '7-27',
    '2026-02-03': '8-15',
    '2026-02-18': '9-1',
    '2026-03-17': '9-27',
    '2026-03-20': '10-1',
    '2026-05-26': '12-9',
    '2026-05-27': '12-10',
    '2026-06-16': '1-1',
    '2026-06-25': '1-10',
    '2026-08-25': '3-12',
    // 2027
    '2027-01-05': '7-27',
    '2027-01-23': '8-15',
    '2027-02-07': '9-1',
    '2027-03-06': '9-27',
    '2027-03-09': '10-1',
    '2027-05-15': '12-9',
    '2027-05-16': '12-10',
    '2027-06-06': '1-1',
    '2027-06-15': '1-10',
    '2027-08-15': '3-12',
  };

  static IslamicEvent? getEvent(DateTime date, HijriDate hijriDate) {
    final keyGregorian = DateFormat('yyyy-MM-dd').format(date);
    if (gregorianOverrides.containsKey(keyGregorian)) {
      final hijriKey = gregorianOverrides[keyGregorian]!;
      return hijriEvents[hijriKey];
    }
    final keyHijri = '${hijriDate.month}-${hijriDate.day}';
    return hijriEvents[keyHijri];
  }

  static final Map<String, DailyAyah> eventAyahs = {
    '1-10': const DailyAyah(
      reference: 'Surah Al-Baqarah 2:153',
      reflection: 'Allah tells us He is with those who are patient in hardship — a fitting reminder on a day of historic trial and deliverance.',
    ),
    '3-12': const DailyAyah(
      reference: 'Surah Al-Anbiya 21:107',
      reflection: '"We sent you not, but as a mercy for all creatures" — the verse most associated with the Prophet\'s (PBUH) birth and purpose.',
    ),
    '7-27': const DailyAyah(
      reference: 'Surah Al-Isra 17:1',
      reflection: 'The opening verse of Surah Al-Isra describes the Night Journey itself — read alongside tonight\'s reflection on Salah.',
    ),
    '9-1': const DailyAyah(
      reference: 'Surah Al-Baqarah 2:185',
      reflection: 'The verse that names Ramadan directly — the month the Quran was revealed as guidance for humanity.',
    ),
    '9-27': const DailyAyah(
      reference: 'Surah Al-Qadr 97:1-3',
      reflection: 'The short surah revealed about this very night — "better than a thousand months."',
    ),
    '10-1': const DailyAyah(
      reference: 'Surah Al-Baqarah 2:185',
      reflection: '"...that you should complete the period and glorify Allah for guiding you, so that you may be grateful" — the note to end Ramadan on.',
    ),
    '12-9': const DailyAyah(
      reference: 'Surah Al-Ma\'idah 5:3',
      reflection: '"This day I have perfected your religion for you..." — revealed on this very day during the Farewell Pilgrimage.',
    ),
    '12-10': const DailyAyah(
      reference: 'Surah As-Saffat 37:107',
      reflection: '"And We ransomed him with a great sacrifice" — the verse behind the Qurbani tradition itself.',
    ),
  };

  static const List<DailyAyah> generalAyahPool = [
    DailyAyah(
      reference: 'Surah Ash-Sharh 94:5-6',
      reflection: '"Indeed, with hardship comes ease" — repeated twice for emphasis, a steady reminder for any ordinary day.',
    ),
    DailyAyah(
      reference: 'Surah Al-Baqarah 2:286',
      reflection: '"Allah does not burden a soul beyond what it can bear" — a grounding verse for any day that feels heavy.',
    ),
    DailyAyah(
      reference: 'Surah Ar-Ra\'d 13:28',
      reflection: '"Verily, in the remembrance of Allah do hearts find rest" — a simple anchor for today\'s Dhikr.',
    ),
    DailyAyah(
      reference: 'Surah Al-Talaq 65:2-3',
      reflection: '"And whoever relies upon Allah — then He is sufficient for him" — a reminder to place today\'s worries in perspective.',
    ),
    DailyAyah(
      reference: 'Surah Al-Ankabut 29:45',
      reflection: '"Indeed, prayer prohibits immorality and wrongdoing" — worth reflecting on before today\'s next Salah.',
    ),
  ];

  static const DailyAyah jumuahAyah = DailyAyah(
    reference: 'Surah Al-Jumu\'ah 62:9',
    reflection:
        'The verse commanding Muslims to hasten to the remembrance of Allah when called for Friday prayer.',
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
      PrayerTimeEntry('Fajr', prayerTimes.fajr),
      PrayerTimeEntry('Dhuhr', prayerTimes.dhuhr),
      PrayerTimeEntry('Asr', prayerTimes.asr),
      PrayerTimeEntry('Maghrib', prayerTimes.maghrib),
      PrayerTimeEntry('Isha', prayerTimes.isha),
    ];
  }
}

class DailyAyah {
  final String reference;
  final String reflection;
  const DailyAyah({
    required this.reference,
    required this.reflection,
  });
}

class PrayerTimeEntry {
  final String name;
  final DateTime time;
  PrayerTimeEntry(this.name, this.time);
}
// ===== INTERACTIVE CALENDAR TAB WIDGET =====
class CalendarTab extends StatefulWidget {
  final VoidCallback onOpenZakatCalculator;
  final bool isDarkMode;
  const CalendarTab({
    super.key,
    required this.onOpenZakatCalculator,
    this.isDarkMode = false,
  });
  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  DateTime _currentMonth = DateTime(2026, 7, 1);
  DateTime _selectedDate = DateTime(2026, 7, 13);
  // Bengali toggle removed per request — English only now. Kept as a
  // (permanently false) field so the many "_isBengali ? bn : en" checks
  // scattered through this file keep compiling and behave as "always
  // English" without needing to touch every single one of them.
  final bool _isBengali = false;
  bool _showCalendarGridTab = true;
  final Map<String, bool> _activityStatus = {};
  // Dates (as 'yyyyMMdd') the user has turned the fasting reminder ON for.
  // Persisted locally so the bell icon reflects the right state after an
  // app restart — the actual OS-level alarm survives on its own once
  // scheduled, this set is just what drives the UI.
  final Set<String> _fastingAlarmDates = {};
  // Set for one tap right when the bell badge is pressed, so the cell's
  // own onTap (select date / open event) can check it and bail out if the
  // same tap also reached it — then cleared on the next microtask so it
  // never affects a later, unrelated tap on the cell.
  bool _suppressNextCellTap = false;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    if (today.year == 2026) {
      _selectedDate = DateTime(2026, today.month, today.day);
      _currentMonth = DateTime(2026, today.month, 1);
    }
    _loadCalendarActivities();
    _loadFastingAlarmDates();
    _refreshHijriApiData();
  }

  // Returns the most accurate Hijri date available for [date] right now:
  // a confirmed local moon-sighting override wins if present, then the
  // AlAdhan/Umm-al-Qura API result once it's loaded, then the offline
  // arithmetic estimate as a safe fallback. See HijriApiService's doc
  // comment for the full reasoning.
  HijriDate _hijriFor(DateTime date) {
    return HijriApiService.cached(date) ?? HijriConverter.fromGregorian(date);
  }

  // Kicks off (non-blocking) AlAdhan API fetches for the currently viewed
  // month plus its neighbours, so prev/next month navigation feels instant
  // — by the time the user flips a page the next month is usually already
  // cached. Cheap to call often: fetchMonth() is a no-op for months
  // already fetched.
  Future<void> _refreshHijriApiData() async {
    final y = _currentMonth.year;
    final m = _currentMonth.month;
    final prev = DateTime(y, m - 1, 1);
    final next = DateTime(y, m + 1, 1);
    await Future.wait([
      HijriApiService.fetchMonth(y, m),
      HijriApiService.fetchMonth(prev.year, prev.month),
      HijriApiService.fetchMonth(next.year, next.month),
    ]);
    if (mounted) setState(() {});
  }

  // Fetches every month of [year] from the API (each already-fetched month
  // is skipped), used before showing the full-year "Special Events" list so
  // that list also reflects the API/override dates instead of only arithmetic.
  Future<void> _ensureYearHijriFetched(int year) async {
    await Future.wait(
      List.generate(12, (i) => HijriApiService.fetchMonth(year, i + 1)),
    );
    if (mounted) setState(() {});
  }

  Future<void> _loadCalendarActivities() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['calendarActivities'] != null) {
          final firestoreActs = data['calendarActivities'] as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              firestoreActs.forEach((key, value) {
                if (value is bool) {
                  _activityStatus[key] = value;
                }
              });
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading calendar activities from Firestore: $e');
    }
  }

  Future<void> _saveCalendarActivity(String key, bool val) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'calendarActivities': {
            key: val,
          }
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error saving calendar activity to Firestore: $e');
    }
  }
  // Sparkling star config for background
  final List<_CalendarStarConfig> _stars = [
    _CalendarStarConfig(topFraction: 0.07, leftFraction: 0.12, size: 6, delayMs: 100),
    _CalendarStarConfig(topFraction: 0.18, leftFraction: 0.35, size: 5, delayMs: 400),
    _CalendarStarConfig(topFraction: 0.26, leftFraction: 0.62, size: 7, delayMs: 800),
    _CalendarStarConfig(topFraction: 0.12, leftFraction: 0.82, size: 5, delayMs: 1200),
    _CalendarStarConfig(topFraction: 0.40, leftFraction: 0.25, size: 6, delayMs: 600),
  ];

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
    _refreshHijriApiData();
  }

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
    _refreshHijriApiData();
  }

  bool _isMondayOrThursday(DateTime date) {
    return date.weekday == DateTime.monday || date.weekday == DateTime.thursday;
  }

  bool _isWhiteDay(HijriDate hijri) {
    return hijri.day == 13 || hijri.day == 14 || hijri.day == 15;
  }

  // ===== FASTING ALARM (evening-before reminder) =====
  // The Islamic (Hijri) day starts at sunset, not midnight — so the
  // reminder for a fasting day has to fire at Maghrib on the evening
  // BEFORE that date, which is when the user should make their intention
  // (Niyyah) and get ready for Suhoor. This section decides which cells
  // get the bell icon, and schedules/cancels that one reminder per date.

  String _dateKey(DateTime d) => DateFormat('yyyyMMdd').format(d);

  // Stable per-date notification id, offset well clear of the prayer
  // (1000s) and prayer-nudge (1500s) ids already used in NotificationService.
  int _fastingAlarmNotifId(DateTime d) => 8000000 + d.year * 10000 + d.month * 100 + d.day;

  // Any day the user may want to fast: the weekly Sunnah days, the lunar
  // "white days", any day in Ramadan, or a special day whose own
  // recommended activities mention fasting (Ashura, 9th of Dhul-Hijjah, etc).
  bool _isFastingDay(DateTime date, HijriDate hijri, IslamicEvent? event) {
    final isRamadan = hijri.month == 9;
    final isEventFast = event != null &&
        event.activities.any((a) => a.toLowerCase().contains('fast'));
    return _isMondayOrThursday(date) || _isWhiteDay(hijri) || isRamadan || isEventFast;
  }

  Future<void> _loadFastingAlarmDates() async {
    Set<String> merged = {};
    try {
      final prefs = await SharedPreferences.getInstance();
      merged.addAll(prefs.getStringList('fasting_alarm_dates') ?? []);
    } catch (e) {
      debugPrint('[CalendarTab] Error loading local fasting alarm dates: $e');
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final remote = doc.data()?['fastingAlarmDates'];
        if (remote is List) {
          merged.addAll(remote.map((e) => e.toString()));
        }
      }
    } catch (e) {
      debugPrint('[CalendarTab] Error loading fasting alarm dates from Firestore: $e');
    }

    if (mounted) {
      setState(() {
        _fastingAlarmDates
          ..clear()
          ..addAll(merged);
      });
    }
    // Write the merged result back locally so a Firestore-only date (e.g.
    // set on another device) also has a fast local copy from now on.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('fasting_alarm_dates', merged.toList());
    } catch (_) {}
  }

  Future<void> _persistFastingAlarmDates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('fasting_alarm_dates', _fastingAlarmDates.toList());
    } catch (e) {
      debugPrint('[CalendarTab] Error saving fasting alarm dates locally: $e');
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fastingAlarmDates': _fastingAlarmDates.toList(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('[CalendarTab] Error saving fasting alarm dates to Firestore: $e');
    }
  }

  Future<void> _toggleFastingAlarm(DateTime fastDate) async {
    final key = _dateKey(fastDate);
    final isOn = _fastingAlarmDates.contains(key);
    final notifId = _fastingAlarmNotifId(fastDate);

    if (isOn) {
      setState(() => _fastingAlarmDates.remove(key));
      await _persistFastingAlarmDates();
      await NotificationService.instance.cancelCustomNotification(notifId);
      NotificationService.instance.notifyFastingAlarmsChanged();
      return;
    }

    setState(() => _fastingAlarmDates.add(key));
    await _persistFastingAlarmDates();

    // Fire at Maghrib the evening before — the true start of the fasting
    // day on the Islamic (lunar) clock, not midnight.
    final eveningBefore = fastDate.subtract(const Duration(days: 1));
    final prayerTimes = CalendarDatabase.getPrayerTimesForDate(eveningBefore);
    final maghrib = prayerTimes.firstWhere((t) => t.name == 'Maghrib').time;
    final hijri = _hijriFor(fastDate);

    DateTime scheduledTime = maghrib;
    final now = DateTime.now();
    if (scheduledTime.isBefore(now)) {
      final tomorrow = now.add(const Duration(days: 1));
      final isTomorrow = fastDate.year == tomorrow.year &&
          fastDate.month == tomorrow.month &&
          fastDate.day == tomorrow.day;
      if (isTomorrow) {
        // If set tonight for tomorrow's fast and Maghrib has already passed,
        // fire a reminder 3 seconds from now.
        scheduledTime = now.add(const Duration(seconds: 3));
      }
    }

    await NotificationService.instance.scheduleCustomNotification(
      id: notifId,
      title: _isBengali ? 'আগামীকাল রোজা' : 'Fasting day tomorrow',
      body: _isBengali
          ? '${DateFormat('d MMM').format(fastDate)} (${hijri.day} ${hijri.monthNameBengali}) তারিখে রোজা রাখতে হবে। নিয়ত করে সাহরির প্রস্তুতি নিন।'
          : '${DateFormat('EEE, d MMM').format(fastDate)} (${hijri.day} ${hijri.monthName}) is a fasting day. Make your intention (Niyyah) and get ready for Suhoor.',
      scheduledTime: scheduledTime,
      category: 'events',
      addToHistory: false,
    );
    NotificationService.instance.notifyFastingAlarmsChanged();
  }

  DateTime? _getUpcomingFastingAlarmDate() {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final upcomingDates = <DateTime>[];

    for (final key in _fastingAlarmDates) {
      if (key.length != 8) continue;
      final date = DateTime.tryParse(
        '${key.substring(0, 4)}-${key.substring(4, 6)}-${key.substring(6, 8)}',
      );
      if (date != null && !date.isBefore(todayStart)) {
        upcomingDates.add(date);
      }
    }

    if (upcomingDates.isEmpty) return null;
    upcomingDates.sort();
    return upcomingDates.first;
  }

// Ayyam al-Beedh (13/14/15) marker color — kept distinct from
// AppColors.midTeal (used for regular Mon/Thu Sunnah fasts) and
// AppColors.coralOrange (used for Islamic events).
    static const Color _ayyamBeedhColor = Color(0xFF9C6ADE); // soft purple
  
  Color _surfaceColor(BuildContext context) {
    final isDark = widget.isDarkMode || Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF1E1E1E) : Colors.white;
  }

  Color _surfaceElevatedColor(BuildContext context) {
    final isDark = widget.isDarkMode || Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF1E2733) : const Color(0xFFF7FAFC);
  }

  Color _borderColor(BuildContext context) {
    final isDark = widget.isDarkMode || Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white.withValues(alpha: 0.12) : AppColors.dustyBlueTeal.withValues(alpha: 0.15);
  }

  Color _primaryTextColor(BuildContext context) {
    final isDark = widget.isDarkMode || Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white : AppColors.navyBlue;
  }

  Color _secondaryTextColor(BuildContext context) {
    final isDark = widget.isDarkMode || Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white.withValues(alpha: 0.75) : AppColors.navyBlue.withValues(alpha: 0.7);
  }

  // Pushes the dedicated, full-bleed detail page for a significant day.
  // This is the ONLY place a background image ever renders — the month
  // grid itself never shows imagery, only small dot markers (see the grid
  // builder below). Keeping the two visually distinct is deliberate: a
  // grid full of thumbnails is unreadable at a glance, but a single
  // full-screen moment for a day you've tapped into is exactly the kind
  // of "deliberate moment" worth spending a hero image on.
  void _openEventDetail(IslamicEvent event, DateTime date, HijriDate hijri) {
    Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EventDetailPage(
              event: event,
              date: date,
              hijri: hijri,
              isDarkMode: widget.isDarkMode,
              activityStatus: _activityStatus,
              onToggleActivity: (key, val) {
                setState(() => _activityStatus[key] = val);
                _saveCalendarActivity(key, val);
              },
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonthString =
          DateFormat('d').format(DateTime(_currentMonth.year, _currentMonth.month + 1, 0));
    final daysCount = int.parse(daysInMonthString);
    final firstDayOfWeek = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday % 7;
    final currentHijriMonthStart =
        _hijriFor(DateTime(_currentMonth.year, _currentMonth.month, 1));
    final currentHijriMonthEnd =
        _hijriFor(DateTime(_currentMonth.year, _currentMonth.month, daysCount));
    String hijriRangeStr = '';
    if (currentHijriMonthStart.month == currentHijriMonthEnd.month) {
      final mName = currentHijriMonthStart.monthName;
      hijriRangeStr = '$mName ${currentHijriMonthStart.year}';
    } else {
      final mNameStart = currentHijriMonthStart.monthName;
      final mNameEnd = currentHijriMonthEnd.monthName;
      hijriRangeStr = '$mNameStart - $mNameEnd ${currentHijriMonthStart.year}';
    }
    final selectedHijri = _hijriFor(_selectedDate);
    final selectedEvent = CalendarDatabase.getEvent(_selectedDate, selectedHijri);
    final selectedIsFasting = _isMondayOrThursday(_selectedDate) || _isWhiteDay(selectedHijri);

    final theme = Theme.of(context);
    final isDark = widget.isDarkMode || theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.white,
      body: Stack(
        children: [
          // Texture background
          Positioned.fill(
            child: CustomPaint(painter: _CalendarTexturePainter()),
          ),
          // Twinkling stars
          ..._stars.map((star) {
            return _CalendarTwinklingStar(
              topFraction: star.topFraction,
              leftFraction: star.leftFraction,
              size: star.size,
              delayMs: star.delayMs,
            );
          }),
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              // This outer Column is what makes the title block fixed: the
              // header lives directly in this Column (not inside the
              // SingleChildScrollView below), so scrolling the content
              // underneath never moves it.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 15, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.dustyBlueTeal.withValues(alpha: 0.18)
                                      : AppColors.navyBlue.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isDark
                                        ? AppColors.dustyBlueTeal.withValues(alpha: 0.4)
                                        : AppColors.navyBlue.withValues(alpha: 0.25),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  Icons.calendar_month_rounded,
                                  color: _primaryTextColor(context),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Islamic Calendar',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: GoogleFonts.poppins(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: _primaryTextColor(context),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Hijri calendar & Islamic events',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: GoogleFonts.poppins(fontSize: 12, color: _secondaryTextColor(context)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Interactive Notification Bell with real-time unread badge
                        GestureDetector(
                          onTap: () => NotificationCenterModal.show(
                            context,
                            isDarkMode: isDark,
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.dustyBlueTeal.withValues(alpha: 0.18)
                                      : Colors.white.withValues(alpha: 0.7),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark
                                        ? AppColors.dustyBlueTeal.withValues(alpha: 0.4)
                                        : AppColors.navyBlue.withValues(alpha: 0.12),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.navyBlue.withValues(alpha: 0.06),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.notifications_outlined,
                                  color: _primaryTextColor(context),
                                  size: 20,
                                ),
                              ),
                              ValueListenableBuilder<int>(
                                valueListenable:
                                    NotificationService.instance.unreadCountNotifier,
                                builder: (context, unreadCount, _) {
                                  if (unreadCount == 0) return const SizedBox.shrink();
                                  return Positioned(
                                    right: -2,
                                    top: -2,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFE63946),
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 16,
                                        minHeight: 16,
                                      ),
                                      child: Text(
                                        unreadCount > 9 ? '9+' : '$unreadCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
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
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20.0, 0, 20.0, 15.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                              ? (isDark ? AppColors.dustyBlueTeal : AppColors.navyBlue)
                              : _surfaceElevatedColor(context),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _showCalendarGridTab
                              ? [
                                  BoxShadow(
                                    color: isDark
                                        ? AppColors.dustyBlueTeal.withValues(alpha: 0.25)
                                        : AppColors.navyBlue.withValues(alpha: 0.15),
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
                              color: _showCalendarGridTab ? Colors.white : _primaryTextColor(context),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Calendar Grid',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _showCalendarGridTab ? Colors.white : _primaryTextColor(context),
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
                      onTap: () {
                        setState(() => _showCalendarGridTab = false);
                        _ensureYearHijriFetched(_currentMonth.year);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: !_showCalendarGridTab
                              ? (isDark ? AppColors.dustyBlueTeal : AppColors.navyBlue)
                              : _surfaceElevatedColor(context),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: !_showCalendarGridTab
                              ? [
                                  BoxShadow(
                                    color: isDark
                                        ? AppColors.dustyBlueTeal.withValues(alpha: 0.25)
                                        : AppColors.navyBlue.withValues(alpha: 0.15),
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
                              color: !_showCalendarGridTab ? Colors.white : _primaryTextColor(context),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Special Events',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: !_showCalendarGridTab ? Colors.white : _primaryTextColor(context),
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
                  gradient: LinearGradient(
                    colors: isDark
                        ? [AppColors.navyBlue, const Color(0xFF2C4356)]
                        : [AppColors.navyBlue, const Color(0xFF2C4356)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? AppColors.dustyBlueTeal.withValues(alpha: 0.2)
                          : AppColors.navyBlue.withValues(alpha: 0.15),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      onPressed: _prevMonth,
                    ),
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
                        ],
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
                    _legendDot(AppColors.coralOrange, 'Islamic event'),
                    const SizedBox(width: 16),
                    _legendDot(AppColors.midTeal, 'Sunnah fast'),
                    const SizedBox(width: 16),
                    _legendDot(_ayyamBeedhColor, 'Ayyam al-Beedh'),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.midTeal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.midTeal.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.notifications_none_rounded, size: 14, color: AppColors.midTeal),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isBengali
                              ? 'রোজার দিনগুলোতে ঘণ্টা আইকনে ট্যাপ করুন — আগের দিন মাগরিবের সময় (যখন ইসলামি দিন শুরু হয়) রিমাইন্ডার পাবেন, যাতে আগে থেকেই নিয়ত করে সাহরির প্রস্তুতি নিতে পারেন।'
                              : 'Tap the bell on any fasting day — you\'ll get a reminder at Maghrib the evening before (when the Islamic day begins), so you can make your intention and prepare for Suhoor ahead of time.',
                          style: GoogleFonts.poppins(fontSize: 10.5, color: _secondaryTextColor(context), height: 1.4),
                        ),
                      ),
                    ],
                  ),
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
                          color: _secondaryTextColor(context),
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
                _buildMonthEventsList(),
                const SizedBox(height: 25),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black : Colors.white,   // was _surfaceColor(context)
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _borderColor(context)),
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
                          color: _primaryTextColor(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedHijri.format(),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialEventsList() {
    final year = _currentMonth.year;
    final events = _getEventsForYear(year);
    // Sort so that this month's upcoming events appear first, then other upcoming, then past events.
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final currentMonth = _currentMonth.month;
    final currentYear = _currentMonth.year;
    events.sort((a, b) {
      final da = a.key;
      final db = b.key;
      int pri(DateTime d) {
        if (d.isBefore(todayStart)) return 2; // past
        if (d.year == currentYear && d.month == currentMonth) return 0; // this month upcoming
        if (d.isBefore(todayStart)) return 2;
        if (d.year == currentYear && d.month == currentMonth) return 0;
        return 1;
      }
      final pa = pri(da);
      final pb = pri(db);
      if (pa != pb) return pa - pb;
      return da.compareTo(db);
    });

    if (events.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(30),
        width: double.infinity,
        decoration: BoxDecoration(
          color: _surfaceColor(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _borderColor(context)),
        ),
        child: Column(
          children: [
            const Icon(Icons.event_busy_rounded, size: 40, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'No special events found',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _primaryTextColor(context),
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
            'Special Events in $year',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: _primaryTextColor(context),
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
            final eventHijri = _hijriFor(date);

            final eventTitle = event.title;
            final eventDesc = event.description;
            final gregorianStr = DateFormat('EEEE, MMMM d, yyyy').format(date);
            final hijriStr = eventHijri.format();
            final color = event.themeColor;

            final isCurrentMonth = date.month == _currentMonth.month;

            return Container(
              decoration: BoxDecoration(
                color: isCurrentMonth
                    ? color.withValues(alpha: 0.05)
                    : _surfaceColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isCurrentMonth
                      ? color.withValues(alpha: 0.25)
                      : _borderColor(context),
                  width: isCurrentMonth ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.isDarkMode ? Colors.black.withValues(alpha: 0.35) : AppColors.navyBlue.withValues(alpha: 0.02),
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
                        width: 4,
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
                                        color: _primaryTextColor(context),
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
                                        'This Month',
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
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: _primaryTextColor(context),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                eventDesc,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: _secondaryTextColor(context),
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
                                    'View Details',
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

  // Scans every day of the currently-viewed month through the same
  // CalendarDatabase.getEvent() lookup the grid cells use (Hijri date +
  // gregorianOverrides), so this list can never disagree with what's
  // actually marked on the grid above it.
  List<MapEntry<DateTime, IslamicEvent>> _getEventsForMonth(int year, int month) {
    final events = <MapEntry<DateTime, IslamicEvent>>[];
    final daysInMonth = DateTime(year, month + 1, 0).day;
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final hijri = _hijriFor(date);
      final event = CalendarDatabase.getEvent(date, hijri);
      if (event != null) {
        events.add(MapEntry(date, event));
      }
    }
    return events;
  }

  // Compact one-line "this month's Islamic events" indicator. Deliberately
  // NOT a bordered card with per-event rows — on a phone screen the month
  // grid already fills almost the whole page, so anything tall here just
  // pushes the grid further down and forces more scrolling, defeating the
  // point. This stays a couple of lines at most, tap it to jump to the
  // full "Special Events" list if there's more than fits.
  Widget _buildMonthEventsList() {
    final monthEvents = _getEventsForMonth(_currentMonth.year, _currentMonth.month);
    if (monthEvents.isEmpty) {
      return const SizedBox.shrink();
    }
    final summary = monthEvents.map((entry) {
      final dateStr = DateFormat('d MMM').format(entry.key);
      final title = _isBengali ? entry.value.titleBengali : entry.value.title;
      return '$dateStr – $title';
    }).join('   •   ');

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: GestureDetector(
        onTap: () {
          setState(() => _showCalendarGridTab = false);
          _ensureYearHijriFetched(_currentMonth.year);
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.mosque_rounded, size: 14, color: AppColors.coralOrange),
            const SizedBox(width: 6),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: _isBengali ? 'এই মাসের ইসলামিক দিবস:  ' : 'Islamic events this month:  ',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _primaryTextColor(context),
                      ),
                    ),
                    TextSpan(
                      text: summary,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.coralOrange,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<MapEntry<DateTime, IslamicEvent>> _getEventsForYear(int year) {
    List<MapEntry<DateTime, IslamicEvent>> events = [];
    for (int month = 1; month <= 12; month++) {
      int daysInMonth = DateTime(year, month + 1, 0).day;
      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(year, month, day);
        final cellHijri = _hijriFor(date);
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

  Widget _buildCalendarGrid(int firstDayOfWeek, int daysCount) {
    final totalCells = firstDayOfWeek + daysCount;
    final gridItemCount = (totalCells / 7).ceil() * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 0.72,
      ),
      itemCount: gridItemCount,
      itemBuilder: (context, index) {
        final int dayNumber = index - firstDayOfWeek + 1;
        if (dayNumber <= 0 || dayNumber > daysCount) {
          return const SizedBox();
        }
        final cellDate = DateTime(_currentMonth.year, _currentMonth.month, dayNumber);
        final cellHijri = _hijriFor(cellDate);
        final isSelected = cellDate.year == _selectedDate.year &&
            cellDate.month == _selectedDate.month &&
            cellDate.day == _selectedDate.day;
        final now = DateTime.now();
        final isToday =
            cellDate.year == now.year && cellDate.month == now.month && cellDate.day == now.day;
final event = CalendarDatabase.getEvent(cellDate, cellHijri);
final hasEvent = event != null;
final isWhiteDay = _isWhiteDay(cellHijri);          // 13, 14, 15 — Ayyam al-Beedh
final isSunnahFast = _isMondayOrThursday(cellDate);  // Mon/Thu (non white-day)
final isFasting = isSunnahFast || isWhiteDay;
// Broader than isFasting above (also covers Ramadan + fast-related special
// days like Ashura) — only used to decide whether the alarm bell shows,
// never touches the dot-marker color logic below.
final canSetFastingAlarm = _isFastingDay(cellDate, cellHijri, event);
final fastingAlarmOn = _fastingAlarmDates.contains(_dateKey(cellDate));
final isDark = widget.isDarkMode || Theme.of(context).brightness == Brightness.dark;

Color cellBgColor = Colors.transparent;
Border? cellBorder;

if (isSelected) {
  cellBgColor = isDark ? AppColors.dustyBlueTeal : AppColors.navyBlue;
} else {
  if (hasEvent) {
    cellBgColor = AppColors.coralOrange.withValues(alpha: 0.15);
    cellBorder = Border.all(color: AppColors.coralOrange.withValues(alpha: 0.4), width: 1);
  } else if (isWhiteDay) {
    // Ayyam al-Beedh gets its own color, distinct from regular Sunnah fasts
    cellBgColor = _ayyamBeedhColor.withValues(alpha: 0.15);
    cellBorder = Border.all(color: _ayyamBeedhColor.withValues(alpha: 0.4), width: 1);
  } else if (isSunnahFast) {
    cellBgColor = AppColors.midTeal.withValues(alpha: 0.15);
    cellBorder = Border.all(color: AppColors.midTeal.withValues(alpha: 0.4), width: 1);
  }

          if (isToday) {
            cellBorder = Border.all(
              color: widget.isDarkMode ? AppColors.dustyBlueTeal : AppColors.navyBlue,
              width: 1.5,
            );
          }
        }

        return GestureDetector(
          onTap: () {
            if (_suppressNextCellTap) {
              _suppressNextCellTap = false;
              return;
            }
            setState(() => _selectedDate = cellDate);
            if (hasEvent) {
              _openEventDetail(event, cellDate, cellHijri);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: cellBgColor,
              borderRadius: BorderRadius.circular(10),
              border: cellBorder,
            ),
            padding: const EdgeInsets.all(7),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Text(
                  '$dayNumber',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : _primaryTextColor(context),
                  ),
                ),
                Text(
                  '${cellHijri.day}',
                  style: GoogleFonts.poppins(
                    fontSize: 9.0,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.8)
                        : (hasEvent
                            ? AppColors.coralOrange
                            : (isWhiteDay
                                ? _ayyamBeedhColor
                                : (isSunnahFast
                                    ? AppColors.midTeal
                                    : _secondaryTextColor(context)))),
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: 4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (hasEvent)
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: AppColors.coralOrange,
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (hasEvent && isFasting) const SizedBox(width: 2),
                      if (isWhiteDay)
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: _ayyamBeedhColor,
                            shape: BoxShape.circle,
                          ),
                        )
                      else if (isSunnahFast)
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: AppColors.midTeal,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                if (canSetFastingAlarm)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _suppressNextCellTap = true;
                        _toggleFastingAlarm(cellDate);
                        // The suppress-flag only needs to survive long
                        // enough to be checked by the cell's own onTap for
                        // this same tap event, if it also fires. Clearing
                        // it on a microtask (rather than leaving it set)
                        // means a later, separate tap on the cell is never
                        // accidentally swallowed.
                        Future.microtask(() => _suppressNextCellTap = false);
                      },
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: fastingAlarmOn
                              ? AppColors.coralOrange
                              : (isDark ? Colors.black : Colors.white),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: fastingAlarmOn
                                ? AppColors.coralOrange
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.35)
                                    : AppColors.navyBlue.withValues(alpha: 0.25)),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Icon(
                          fastingAlarmOn
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_off_rounded,
                          size: 10,
                          color: fastingAlarmOn
                              ? Colors.white
                              : (isDark ? Colors.white : AppColors.navyBlue),
                        ),
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
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: _secondaryTextColor(context),
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
        return Icons.sunny_snowing;
      case 'maghrib':
        return Icons.nights_stay_outlined;
      case 'isha':
        return Icons.bedtime_rounded;
      default:
        return Icons.access_time_filled_rounded;
    }
  }

 Widget _buildPrayerCard(PrayerTimeEntry entry) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _surfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor(context)),
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
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getPrayerIcon(entry.name),
                  size: 13,
                  color: _secondaryTextColor(context),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    entry.name,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _primaryTextColor(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            DateFormat('h:mm a').format(entry.time),
            style: GoogleFonts.poppins(
              fontSize: 11,
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
        color: _surfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor(context)),
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
            color: _secondaryTextColor(context),
          ),
          const SizedBox(width: 6),
          Text(
            entry.name,
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: _primaryTextColor(context),
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

  Widget _buildPrayerTimesSection() {
    final times = CalendarDatabase.getPrayerTimesForDate(_selectedDate);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceElevatedColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time_filled_rounded, color: _secondaryTextColor(context), size: 16),
              const SizedBox(width: 8),
              Text(
                'Prayer Times for This Day',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: _primaryTextColor(context)),
              ),
            ],
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
        ],
      ),
    );
  }

  Widget _buildRelatedAyahSection(IslamicEvent? event) {
    final selectedHijri = _hijriFor(_selectedDate);
    final ayah = CalendarDatabase.getAyahForDate(_selectedDate, selectedHijri, event);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.coralOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.coralOrange.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book_rounded, color: AppColors.coralOrange, size: 16),
              const SizedBox(width: 8),
              Text(
                'Related Ayah for Today',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: _primaryTextColor(context)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            ayah.reference,
            style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.coralOrange),
          ),
          const SizedBox(height: 6),
          Text(
            ayah.reflection,
            style: GoogleFonts.inter(fontSize: 12.5, color: _secondaryTextColor(context), height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildEventPromptCard(IslamicEvent event, HijriDate hijri) {
    final title = event.title;
    final description = event.description;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openEventDetail(event, _selectedDate, hijri),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [event.themeColor, event.themeColor.withValues(alpha: 0.75)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.9), height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFastingDetailCard(HijriDate hijri) {
    final isWhiteDay = _isWhiteDay(hijri);
    final isMonday = _selectedDate.weekday == DateTime.monday;
    String fastingTitle = '';
    String fastingDesc = '';
    String fastingHistory = '';
    List<String> fastingActs = [];
    if (isWhiteDay) {
      fastingTitle = 'Ayyam al-Beedh (White Days) Fast';
      fastingDesc = 'Fasting on the 13th, 14th, and 15th of the lunar month is highly recommended.';
      fastingHistory =
          'The Prophet Muhammad (PBUH) instructed his companions to fast three days of every month—the white days—saying that it is like fasting a lifetime because the reward of a good deed is multiplied tenfold.';
      fastingActs = [
        'Keep the fast (abstain from food & drink from dawn to sunset).',
        'Read Quran and perform voluntary prayers.',
        'Make dua at the time of breaking the fast (Iftar), as the fasting person\'s prayer is accepted.',
        'Give charity (Sadaqah).',
      ];
    } else {
      final dayName = isMonday ? 'Monday' : 'Thursday';
      fastingTitle = 'Sunnah $dayName Fast';
      fastingDesc = 'Fasting on Mondays and Thursdays is an established practice of the Messenger of Allah (PBUH).';
      fastingHistory =
          'The Prophet (PBUH) said: "The deeds of people are presented (to Allah) on Mondays and Thursdays, and I like that my deeds are presented while I am fasting." It was also on a Monday that the Prophet was born and began receiving revelation.';
      fastingActs = [
        'Perform the Sunnah fast.',
        'Make Iftar supplications and feed another fasting person if possible.',
        'Increase Dhikr (remembrance of Allah) throughout the day.',
        'Seek forgiveness for oneself and the Ummah.',
      ];
    }
    final title = fastingTitle;
    final description = fastingDesc;
    final history = fastingHistory;
    final activities = fastingActs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              const Icon(Icons.spa_rounded, color: AppColors.midTeal, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.midTeal),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Description',
          style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: _primaryTextColor(context)),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: GoogleFonts.inter(fontSize: 13, color: _secondaryTextColor(context), height: 1.5),
        ),
        const SizedBox(height: 18),
        Text(
          'History & Significance',
          style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: _primaryTextColor(context)),
        ),
        const SizedBox(height: 6),
        Text(
          history,
          style: GoogleFonts.inter(fontSize: 13, color: _secondaryTextColor(context), height: 1.5),
        ),
        const SizedBox(height: 20),
        Text(
          'Spiritual Activities',
          style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: _primaryTextColor(context)),
        ),
        const SizedBox(height: 10),
        Column(
          children: List.generate(activities.length, (index) {
            final key = '${DateFormat('yyyyMMdd').format(_selectedDate)}_fasting_$index';
            final isChecked = _activityStatus[key] ?? false;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Material(
                color: Colors.transparent,
                child: CheckboxListTile(
                  value: isChecked,
                  onChanged: (val) {
                    final bool newWal = val ?? false;
                    setState(() => _activityStatus[key] = newWal);
                    _saveCalendarActivity(key, newWal);
                  },
                  title: Text(
                    activities[index],
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                        color: isChecked
                          ? const Color(0xFF4CAF50).withValues(alpha: 0.85)
                          : _primaryTextColor(context).withValues(alpha: 0.8),
                      decoration: TextDecoration.none,
                    ),
                  ),
                  activeColor: AppColors.midTeal,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildRegularDayCard() {
    final List<String> dailyActs = [
      'Perform all 5 daily prayers on time (Fajr, Dhuhr, Asr, Maghrib, Isha).',
      'Recite Morning & Evening Adhkar (remembrance).',
      'Read at least one page of the Holy Quran with translation.',
      'Recite Salawat (100 times) and Istighfar (100 times).',
      'Do a voluntary good deed (help family, check on a neighbor, give charity).',
    ];
    final title = 'Daily Islamic Guidance';
    final activities = dailyActs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.wb_sunny_outlined, color: _secondaryTextColor(context), size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: _primaryTextColor(context)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Maintaining a structured daily spiritual routine strengthens your faith. Check off today\'s actions as you complete them:',
          style: GoogleFonts.inter(fontSize: 12.5, color: _secondaryTextColor(context).withValues(alpha: 0.65), height: 1.4),
        ),
        const SizedBox(height: 12),
        Column(
          children: List.generate(activities.length, (index) {
            final key = '${DateFormat('yyyyMMdd').format(_selectedDate)}_regular_$index';
            final isChecked = _activityStatus[key] ?? false;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Material(
                color: Colors.transparent,
                child: CheckboxListTile(
                  value: isChecked,
                  onChanged: (val) {
                    final bool newWal = val ?? false;
                    setState(() => _activityStatus[key] = newWal);
                    _saveCalendarActivity(key, newWal);
                  },
                  title: Text(
                    activities[index],
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                        color: isChecked
                          ? const Color(0xFF4CAF50).withValues(alpha: 0.85)
                          : _primaryTextColor(context).withValues(alpha: 0.8),
                      decoration: TextDecoration.none,
                    ),
                  ),
                  activeColor: AppColors.midTeal,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ===== HERO IMAGE CAROUSEL =====
// Auto-scrolling carousel of 5-6 related photos for the event detail hero,
// replacing the flat theme-color block. Cycles on a timer and shows dot
// indicators. Falls back to a themeColor gradient per-slide (or entirely,
// if no images are configured yet) so nothing breaks before real photo
// assets are added.
class _HeroImageCarousel extends StatefulWidget {
  final List<String> images;
  final Color fallbackColor;
  final Duration interval;

  const _HeroImageCarousel({
    required this.images,
    required this.fallbackColor,
  }) : interval = const Duration(seconds: 4);

  @override
  State<_HeroImageCarousel> createState() => _HeroImageCarouselState();
}

class _HeroImageCarouselState extends State<_HeroImageCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    if (widget.images.length <= 1) return;
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted || !_controller.hasClients) return;
      _page = (_page + 1) % widget.images.length;
      _controller.animateToPage(
        _page,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Widget _gradientFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [widget.fallbackColor, widget.fallbackColor.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return _gradientFallback();
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: widget.images.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (context, index) {
            return Image.asset(
              widget.images[index],
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _gradientFallback(),
            );
          },
        ),
        if (widget.images.length > 1)
          Positioned(
            bottom: 78,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.images.length, (i) {
                final isActive = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: isActive ? 0.95 : 0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

// ===== EVENT DETAIL PAGE =====
// The dedicated, full-bleed "moment" screen for a significant Islamic day.
// This is where the hero carousel + gradient overlay treatment lives —
// nowhere else. The date is pinned in the app bar so it stays clearly
// legible even once the user scrolls past the images.
//
// MOBILE-SIZE FRAME: regardless of the outer app's layout (e.g. a full
// browser window on desktop), this page always renders itself inside a
// fixed phone-width column (capped at 430px) centered on a grey
// letterboxed background — the same trick used by responsive web apps to
// preview a "phone" experience on a wide screen. On an actual phone,
// 430px is wider than the viewport, so this is a no-op and it simply
// fills the screen as before.
class EventDetailPage extends StatelessWidget {
  final IslamicEvent event;
  final DateTime date;
  final HijriDate hijri;
  final bool isDarkMode;
  final Map<String, bool> activityStatus;
  final void Function(String key, bool value) onToggleActivity;

  static const double _mobileFrameWidth = 430;

  const EventDetailPage({
    super.key,
    required this.event,
    required this.date,
    required this.hijri,
    required this.isDarkMode,
    required this.activityStatus,
    required this.onToggleActivity,
  });

  bool get _isDark => isDarkMode;

  Color get _edpPrimaryTextColor => _isDark ? Colors.white : AppColors.navyBlue;

  Color get _edpSecondaryTextColor =>
      _isDark ? Colors.white.withOpacity(0.75) : AppColors.navyBlue.withValues(alpha: 0.7);

  Color get _edpSurfaceColor => _isDark ? const Color(0xFF1E1E1E) : Colors.white;

  Color get _edpSurfaceElevatedColor =>
      _isDark ? const Color(0xFF1E2733) : const Color(0xFFF7FAFC);

  @override
  Widget build(BuildContext context) {
    final title = event.title;
    final description = event.description;
    final history = event.history;
    final activities = event.activities;
    final gregorianStr = DateFormat('EEEE, MMMM d, yyyy').format(date);
    final hijriStr = hijri.format();

    return Container(
      // Grey letterbox background — only visible on screens wider than
      // the mobile frame (i.e. desktop/laptop browsers).
      color: _isDark ? const Color(0xFF0F1216) : const Color(0xFFE8E8E8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _mobileFrameWidth),
          child: Scaffold(
            backgroundColor: _isDark ? const Color(0xFF121212) : Colors.white,
            body: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 300,
                  // Let the expandable hero scroll away so it cannot cover
                  // the details or recommended-activities checklist below.
                  pinned: false,
                  backgroundColor: event.themeColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.pin,
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        _HeroImageCarousel(
                          images: event.carouselImages,
                          fallbackColor: event.themeColor,
                        ),
                        // Gradient overlay — guarantees the date/title read
                        // clearly regardless of the underlying photo's brightness.
                        IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withValues(alpha: 0.05),
                                  Colors.black.withValues(alpha: 0.85),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: const [0.35, 1.0],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Both dates, always clearly legible — the core
                              // requirement, regardless of image content.
                              Text(
                                gregorianStr,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                hijriStr,
                                style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPrayerTimesSection(),
                        const SizedBox(height: 18),
                        _buildAyahSection(),
                        const SizedBox(height: 20),
                        Text(
                          'Description',
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: _edpPrimaryTextColor),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description,
                          style: GoogleFonts.inter(fontSize: 13.5, color: _edpSecondaryTextColor, height: 1.6),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'History & Significance',
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: _edpPrimaryTextColor),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          history,
                          style: GoogleFonts.inter(fontSize: 13.5, color: _edpSecondaryTextColor, height: 1.6),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Recommended Activities',
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: _edpPrimaryTextColor),
                        ),
                        const SizedBox(height: 10),
                        Column(
                          children: List.generate(activities.length, (index) {
                            final key = '${DateFormat('yyyyMMdd').format(date)}_event_$index';
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              // The detail page is a separate route, so it must
                              // rebuild locally after its shared state changes.
                              child: StatefulBuilder(
                                builder: (context, setTileState) => CheckboxListTile(
                                  value: activityStatus[key] ?? false,
                                  onChanged: (val) => setTileState(
                                    () => onToggleActivity(key, val ?? false),
                                  ),
                                  title: Text(
                                    activities[index],
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: (activityStatus[key] ?? false)
                                          ? const Color(0xFF4CAF50).withOpacity(0.85)
                                          : _edpPrimaryTextColor.withOpacity(0.8),
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                  activeColor: AppColors.midTeal,
                                  checkColor: Colors.white,
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  controlAffinity: ListTileControlAffinity.leading,
                                ),
                              ),
                            );
                          }),
                        ),
                        SizedBox(height: 20 + MediaQuery.of(context).padding.bottom),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrayerTimesSection() {
    final times = CalendarDatabase.getPrayerTimesForDate(date);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _edpSurfaceElevatedColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.dustyBlueTeal.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time_filled_rounded, color: _edpSecondaryTextColor, size: 16),
              const SizedBox(width: 8),
              Text(
                'Prayer Times for This Day',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: _edpPrimaryTextColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: times.map((entry) {
              return Expanded(
                child: Column(
                  children: [
                    Text(
                      entry.name,
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: _edpSecondaryTextColor.withOpacity(0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('h:mm a').format(entry.time),
                      style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.midTeal),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAyahSection() {
    final ayah = CalendarDatabase.getAyahForDate(date, hijri, event);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.coralOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.coralOrange.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book_rounded, color: AppColors.coralOrange, size: 16),
              const SizedBox(width: 8),
              Text(
                'Related Ayah for Today',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: _edpPrimaryTextColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            ayah.reference,
            style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.coralOrange),
          ),
          const SizedBox(height: 6),
          Text(
            ayah.reflection,
            style: GoogleFonts.inter(fontSize: 12.5, color: _edpSecondaryTextColor, height: 1.5),
          ),
        ],
      ),
    );
  }
}