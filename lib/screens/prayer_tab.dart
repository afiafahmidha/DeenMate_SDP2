import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/auth_header.dart'; // AppColors

/// The Prayer tab: dynamic sky scene, salat tracker, qaza counter and
/// prayer time list. All persistent state (salat completion, qaza
/// counts, alarms) is owned by DashboardScreen and passed in, because
/// DashboardScreen's real-time timer also needs it (to fire the in-app
/// alarm overlay and auto-log qaza regardless of which tab is active).
/// This widget is intentionally "dumb" about persistence — it just
/// renders state and reports user actions back up via callbacks.
class PrayerTab extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String locationName;
  final String nextPrayerName;
  final String liveCountdownStr;
  final String selectedPrayerScene;
  final Map<String, bool> salatCompleted;
  final Map<String, int> qazaCounts;
  final Map<String, bool> prayerAlarms;
  final int qazaCount;
  final AnimationController pulseController;
  final AnimationController cloudsController;

  final ValueChanged<String> onSceneSelected;
  final VoidCallback onBack;
  final void Function(String salat, bool done) onSalatToggle;
  final void Function(String salat, int newCount) onQazaCountChange;
  final void Function(String prayer, bool enabled) onAlarmToggle;

  const PrayerTab({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.locationName,
    required this.nextPrayerName,
    required this.liveCountdownStr,
    required this.selectedPrayerScene,
    required this.salatCompleted,
    required this.qazaCounts,
    required this.prayerAlarms,
    required this.qazaCount,
    required this.pulseController,
    required this.cloudsController,
    required this.onSceneSelected,
    required this.onBack,
    required this.onSalatToggle,
    required this.onQazaCountChange,
    required this.onAlarmToggle,
  });

  // Approximate Hijri date string for display in the header.
  String _getHijriDateString() {
    final today = DateTime.now();
    final hijriMonths = [
      "Muharram", "Safar", "Rabi' al-Awwal", "Rabi' ath-Thani",
      "Jumada al-Ula", "Jumada al-Akhirah", "Rajab", "Sha'ban",
      "Ramadan", "Shawwal", "Dhu al-Qa'dah", "Dhu al-Hijjah"
    ];
    int monthIndex = (today.month + 3) % 12;
    int day = (today.day + 12) % 29 + 1;
    int year = today.year - 578;
    return "$day ${hijriMonths[monthIndex]}, $year AH";
  }

  String _getCurrentPrayerName(Coordinates coordinates, CalculationParameters params) {
    final prayerTimes = PrayerTimes.today(coordinates, params);
    final current = prayerTimes.currentPrayer();
    switch (current) {
      case Prayer.fajr:
        return 'Fajr';
      case Prayer.sunrise:
        return 'Sunrise';
      case Prayer.dhuhr:
        return 'Dhuhr';
      case Prayer.asr:
        return 'Asr';
      case Prayer.maghrib:
        return 'Maghrib';
      case Prayer.isha:
      case Prayer.none:
        return 'Isha';
    }
  }

  @override
  Widget build(BuildContext context) {
    final coordinates = Coordinates(latitude, longitude);
    final params = CalculationMethod.karachi.getParameters();
    params.madhab = Madhab.hanafi;

    final prayerTimes = PrayerTimes.today(coordinates, params);
    final formatter = DateFormat('hh:mm a');
    final now = DateTime.now();

    final List<Map<String, dynamic>> prayerItems = [
      {'name': 'Fajr',    'time': formatter.format(prayerTimes.fajr),    'dt': prayerTimes.fajr},
      {'name': 'Sunrise', 'time': formatter.format(prayerTimes.sunrise), 'dt': prayerTimes.sunrise},
      {'name': 'Dhuhr',   'time': formatter.format(prayerTimes.dhuhr),   'dt': prayerTimes.dhuhr},
      {'name': 'Asr',     'time': formatter.format(prayerTimes.asr),     'dt': prayerTimes.asr},
      {'name': 'Maghrib', 'time': formatter.format(prayerTimes.maghrib), 'dt': prayerTimes.maghrib},
      {'name': 'Isha',    'time': formatter.format(prayerTimes.isha),    'dt': prayerTimes.isha},
    ];

    final currentPrayer = _getCurrentPrayerName(coordinates, params);
    int completedCount = salatCompleted.values.where((v) => v).length;

    final salatNames = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final Map<String, DateTime?> salatDts = {
      'Fajr': prayerTimes.fajr,
      'Dhuhr': prayerTimes.dhuhr,
      'Asr': prayerTimes.asr,
      'Maghrib': prayerTimes.maghrib,
      'Isha': prayerTimes.isha,
    };

    final tomorrow = now.add(const Duration(days: 1));
    final tomorrowPrayerTimes = PrayerTimes(
      coordinates,
      DateComponents.from(tomorrow),
      params,
    );
    final tomorrowFajrTime = tomorrowPrayerTimes.fajr;

    DateTime getIshaStartTime(DateTime todayIsha) {
      final todayFajr = prayerTimes.fajr;
      if (now.isBefore(todayFajr)) {
        final yesterday = now.subtract(const Duration(days: 1));
        final yesterdayPrayerTimes = PrayerTimes(
          coordinates,
          DateComponents.from(yesterday),
          params,
        );
        return yesterdayPrayerTimes.isha;
      }
      return todayIsha;
    }

    // === Define sky gradient per prayer scene ===
    LinearGradient skyGradient;
    bool showStars;
    bool showClouds;
    Color cloudColor;

    switch (selectedPrayerScene) {
      case 'Fajr':
        skyGradient = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F1E36), Color(0xFF1D3557), Color(0xFF457B9D)],
        );
        showStars = true;
        showClouds = false;
        cloudColor = Colors.white;
        break;
      case 'Sunrise':
        skyGradient = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE2E9F3), Color(0xFFFBC490), Color(0xFFFDE4C3)],
        );
        showStars = false;
        showClouds = true;
        cloudColor = const Color(0xFFCE5C2C).withValues(alpha: 0.4);
        break;
      case 'Dhuhr':
        skyGradient = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB), Color(0xFFE0F7FA)],
        );
        showStars = false;
        showClouds = true;
        cloudColor = Colors.white;
        break;
      case 'Asr':
        skyGradient = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFD1E8F2), Color(0xFFB3D9EA), Color(0xFFFFF1C5)],
        );
        showStars = false;
        showClouds = true;
        cloudColor = Colors.white;
        break;
      case 'Maghrib':
        skyGradient = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE2D4F0), Color(0xFFFFCCD5), Color(0xFFFFDFD3)],
        );
        showStars = false;
        showClouds = true;
        cloudColor = const Color(0xFFE07040).withValues(alpha: 0.3);
        break;
      case 'Isha':
      default:
        skyGradient = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A1128), Color(0xFF001F54), Color(0xFF034078)],
        );
        showStars = true;
        showClouds = false;
        cloudColor = Colors.white;
        break;
    }

    return Column(
      key: const ValueKey('PrayerTab'),
      children: [
        // ── PINNED SKY SCENE CARD ──────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 16, 16, 10),
          child: Container(
            height: 240,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeInOutCubic,
              decoration: BoxDecoration(gradient: skyGradient),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final height = constraints.maxHeight;

                  return Stack(
                    children: [
                      if (showStars)
                        AnimatedBuilder(
                          animation: pulseController,
                          builder: (context, _) {
                            return CustomPaint(
                              size: Size(width, height),
                              painter: PrayerHeaderStarsPainter(pulseVal: pulseController.value),
                            );
                          },
                        ),
                      if (showClouds)
                        AnimatedBuilder(
                          animation: cloudsController,
                          builder: (context, _) {
                            return CustomPaint(
                              size: Size(width, height),
                              painter: DriftingCloudsPainter(
                                animVal: cloudsController.value,
                                cloudColor: cloudColor,
                              ),
                            );
                          },
                        ),
                      _buildSunPosition(width),
                      _buildMoonPosition(width),
                      Positioned(
                        bottom: -2,
                        left: 0,
                        right: 0,
                        height: height * 0.45,
                        child: CustomPaint(
                          painter: MosqueSilhouettePainter(selectedScene: selectedPrayerScene),
                        ),
                      ),
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
                                    onPressed: onBack,
                                  ),
                                  Column(
                                    children: [
                                      Text(
                                        'Prayer Times',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                      Text(
                                        _getHijriDateString(),
                                        style: GoogleFonts.inter(
                                          color: Colors.white.withValues(alpha: 0.75),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    tooltip: 'Find nearby mosques',
                                    icon: const Icon(Icons.location_on_rounded, color: Colors.white, size: 20),
                                    onPressed: () async {
                                      final lat = latitude;
                                      final lng = longitude;
                                      final messenger = ScaffoldMessenger.of(context);
                                      final geoUri = Uri.parse('geo:$lat,$lng?q=mosque+near+me&z=14');
                                      final mapsWebUri = Uri.parse(
                                        'https://www.google.com/maps/search/mosque+near+me/@$lat,$lng,14z',
                                      );
                                      if (await canLaunchUrl(geoUri)) {
                                        await launchUrl(geoUri);
                                      } else if (await canLaunchUrl(mapsWebUri)) {
                                        await launchUrl(mapsWebUri, mode: LaunchMode.externalApplication);
                                      } else {
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Could not open Maps. Please install Google Maps.',
                                              style: GoogleFonts.inter(fontSize: 13),
                                            ),
                                            backgroundColor: AppColors.navyBlue,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Next: $nextPrayerName',
                                        style: GoogleFonts.inter(
                                          color: Colors.white.withValues(alpha: 0.80),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        liveCountdownStr,
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 34,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.0,
                                          height: 1.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.location_on_rounded, color: Colors.white54, size: 13),
                                  const SizedBox(width: 4),
                                  Text(
                                    locationName.split(',').first,
                                    style: GoogleFonts.inter(
                                      color: Colors.white.withValues(alpha: 0.75),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),

        // ── SCROLLABLE LOWER SECTION ──
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // 2. Daily Salat Count Checklist Tracker
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.navyBlue.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.stars_rounded, color: AppColors.navyBlue, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Daily Salat Tracker',
                                  style: GoogleFonts.poppins(
                                    color: AppColors.navyBlue,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.navyBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$completedCount / 5 Completed',
                                style: GoogleFonts.inter(
                                  color: AppColors.navyBlue,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: completedCount / 5,
                            minHeight: 6,
                            backgroundColor: Colors.white.withValues(alpha: 0.3),
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.navyBlue),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: salatCompleted.keys.map((salat) {
                            final isDone = salatCompleted[salat] ?? false;

                            final sTime = salat == 'Isha'
                                ? getIshaStartTime(salatDts['Isha'] ?? now)
                                : salatDts[salat];

                            final expireTime = salat == 'Fajr'
                                ? prayerTimes.sunrise
                                : salat == 'Dhuhr'
                                    ? salatDts['Asr']
                                    : salat == 'Asr'
                                        ? salatDts['Maghrib']
                                        : salat == 'Maghrib'
                                            ? salatDts['Isha']
                                            : tomorrowFajrTime;

                            final bool isFuture = sTime != null && now.isBefore(sTime);
                            final bool isExpired = expireTime != null && now.isAfter(expireTime);
                            final bool isSalatMissed = isExpired && !isDone;

                            return GestureDetector(
                              onTap: () {
                                if (isSalatMissed || isFuture) return;
                                onSalatToggle(salat, !isDone);
                              },
                              child: Column(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.elasticOut,
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: isSalatMissed
                                          ? const Color(0xFFFFEBEE)
                                          : isFuture
                                              ? Colors.black.withValues(alpha: 0.04)
                                              : isDone
                                                  ? AppColors.navyBlue
                                                  : Colors.white.withValues(alpha: 0.25),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSalatMissed
                                            ? const Color(0xFFE57373)
                                            : isFuture
                                                ? Colors.black.withValues(alpha: 0.12)
                                                : isDone
                                                    ? AppColors.navyBlue
                                                    : Colors.white.withValues(alpha: 0.4),
                                        width: 1.8,
                                      ),
                                      boxShadow: isDone
                                          ? [
                                              BoxShadow(
                                                color: AppColors.navyBlue.withValues(alpha: 0.2),
                                                blurRadius: 8,
                                                spreadRadius: 1,
                                              )
                                            ]
                                          : [],
                                    ),
                                    child: Center(
                                      child: isSalatMissed
                                          ? const Icon(Icons.close_rounded, color: Color(0xFFE57373), size: 22)
                                          : isFuture
                                              ? Icon(Icons.lock_outline_rounded,
                                                  color: Colors.black.withValues(alpha: 0.22), size: 18)
                                              : isDone
                                                  ? const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24)
                                                  : Icon(Icons.circle_outlined,
                                                      color: AppColors.navyBlue.withValues(alpha: 0.3), size: 20),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    salat,
                                    style: GoogleFonts.poppins(
                                      color: isSalatMissed
                                          ? const Color(0xFFE57373)
                                          : isFuture
                                              ? Colors.black.withValues(alpha: 0.3)
                                              : isDone
                                                  ? AppColors.navyBlue
                                                  : AppColors.navyBlue.withValues(alpha: 0.6),
                                      fontSize: 11,
                                      fontWeight: isDone ? FontWeight.bold : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. Scrollable List of Prayer Times
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: prayerItems.length,
                    itemBuilder: (context, index) {
                      final item = prayerItems[index];
                      final String pName = item['name'];
                      final String pTime = item['time'];

                      final bool isSalat = (pName != 'Sunrise');
                      bool isMissed = false;
                      if (isSalat) {
                        final expireTime = pName == 'Fajr'
                            ? prayerTimes.sunrise
                            : pName == 'Dhuhr'
                                ? salatDts['Asr']
                                : pName == 'Asr'
                                    ? salatDts['Maghrib']
                                    : pName == 'Maghrib'
                                        ? salatDts['Isha']
                                        : tomorrowFajrTime;

                        isMissed = expireTime != null &&
                            now.isAfter(expireTime) &&
                            !(salatCompleted[pName] ?? false);
                      }

                      final bool isSceneSelected = (pName == selectedPrayerScene);
                      final bool isActive = (pName == currentPrayer);
                      final bool hasAlarm = prayerAlarms[pName] ?? false;

                      Color cardAccent;
                      Color cardBg;
                      switch (pName) {
                        case 'Fajr':
                          cardAccent = const Color(0xFF1A2E40);
                          cardBg = const Color(0xFFEBF0F8);
                          break;
                        case 'Sunrise':
                          cardAccent = const Color(0xFFF5A623);
                          cardBg = const Color(0xFFFFF6E6);
                          break;
                        case 'Dhuhr':
                          cardAccent = const Color(0xFF4AABDB);
                          cardBg = const Color(0xFFEBF7FF);
                          break;
                        case 'Asr':
                          cardAccent = const Color(0xFF2677A7);
                          cardBg = const Color(0xFFE5F2F9);
                          break;
                        case 'Maghrib':
                          cardAccent = const Color(0xFF7B3F7E);
                          cardBg = const Color(0xFFF5EBF8);
                          break;
                        case 'Isha':
                        default:
                          cardAccent = const Color(0xFF0A1628);
                          cardBg = const Color(0xFFE8EBF0);
                          break;
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => onSceneSelected(pName),
                            borderRadius: BorderRadius.circular(18),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeInOutCubic,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                              decoration: BoxDecoration(
                                color: isMissed
                                    ? const Color(0xFFFFF0F0)
                                    : isSceneSelected
                                        ? cardBg
                                        : Colors.white.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isMissed
                                      ? const Color(0xFFE57373).withValues(alpha: 0.55)
                                      : isSceneSelected
                                          ? cardAccent
                                          : Colors.white.withValues(alpha: 0.4),
                                  width: isSceneSelected ? 2.0 : 1.0,
                                ),
                                boxShadow: isSceneSelected
                                    ? [
                                        BoxShadow(
                                          color: cardAccent.withValues(alpha: 0.12),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : [
                                        BoxShadow(
                                          color: AppColors.navyBlue.withValues(alpha: 0.04),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        width: 10,
                                        height: 10,
                                        margin: const EdgeInsets.only(right: 10),
                                        decoration: BoxDecoration(
                                          color: isSceneSelected ? cardAccent : cardAccent.withValues(alpha: 0.3),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Text(
                                        pName,
                                        style: GoogleFonts.poppins(
                                          color: isMissed
                                              ? const Color(0xFFD32F2F)
                                              : isSceneSelected
                                                  ? cardAccent
                                                  : AppColors.navyBlue,
                                          fontSize: 15,
                                          fontWeight: isSceneSelected ? FontWeight.bold : FontWeight.w600,
                                          decoration: isMissed ? TextDecoration.lineThrough : null,
                                          decorationColor: const Color(0xFFD32F2F),
                                        ),
                                      ),
                                      if (isActive) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          margin: const EdgeInsets.only(left: 8),
                                          decoration: BoxDecoration(
                                            color: AppColors.coralOrange.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Now',
                                            style: GoogleFonts.inter(
                                              color: AppColors.coralOrange,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (isMissed) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          margin: const EdgeInsets.only(left: 8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE57373).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(7),
                                          ),
                                          child: Text(
                                            'Missed',
                                            style: GoogleFonts.inter(
                                              color: const Color(0xFFD32F2F),
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        pTime,
                                        style: GoogleFonts.inter(
                                          color: isSceneSelected ? cardAccent : AppColors.navyBlue.withValues(alpha: 0.75),
                                          fontSize: 14.5,
                                          fontWeight: isSceneSelected ? FontWeight.bold : FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      GestureDetector(
                                        onTap: () {
                                          final newState = !hasAlarm;
                                          onAlarmToggle(pName, newState);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).clearSnackBars();
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  newState ? '🔔 $pName alarm set' : '🔕 $pName alarm removed',
                                                  style: GoogleFonts.inter(fontSize: 13),
                                                ),
                                                duration: const Duration(seconds: 2),
                                                behavior: SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                width: math.min(MediaQuery.of(context).size.width, 430) - 32,
                                                backgroundColor: AppColors.navyBlue,
                                              ),
                                            );
                                          }
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 250),
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: hasAlarm
                                                ? AppColors.coralOrange.withValues(alpha: 0.12)
                                                : Colors.transparent,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            hasAlarm ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                                            color: hasAlarm ? AppColors.coralOrange : AppColors.navyBlue.withValues(alpha: 0.35),
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // ===== TODAY'S MISSED PRAYER STATUS CARD =====
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: qazaCount > 0
                        ? Container(
                            key: const ValueKey('MissedWarning'),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFFFF5F5), Color(0xFFFFEBEB)],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFFE57373).withValues(alpha: 0.45), width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE57373).withValues(alpha: 0.10),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE57373).withValues(alpha: 0.14),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.warning_amber_rounded, color: Color(0xFFD32F2F), size: 24),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Today\'s Missed Prayers',
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFFB71C1C),
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'You missed $qazaCount prayer${qazaCount > 1 ? 's' : ''} today.',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFFD32F2F).withValues(alpha: 0.80),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE57373).withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$qazaCount',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFFB71C1C),
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            key: const ValueKey('AllCompleted'),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFF4FBF7), Color(0xFFEBF7F0)],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFF81C784).withValues(alpha: 0.45), width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF81C784).withValues(alpha: 0.10),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF81C784).withValues(alpha: 0.14),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.check_circle_outline_rounded, color: Color(0xFF2E7D32), size: 24),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'All Caught Up!',
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFF1B5E20),
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'No missed prayers detected today.',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF2E7D32).withValues(alpha: 0.80),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
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

                // ===== INTERACTIVE QAZA COUNTER SECTION =====
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.navyBlue.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.history_toggle_off_rounded, color: AppColors.navyBlue, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Qaza Prayer Counter',
                              style: GoogleFonts.poppins(
                                color: AppColors.navyBlue,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manually track and log your missed prayers to make them up over time.',
                          style: GoogleFonts.inter(color: AppColors.navyBlue.withValues(alpha: 0.6), fontSize: 11),
                        ),
                        const SizedBox(height: 16),
                        ...['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'].map((salat) {
                          final count = qazaCounts[salat] ?? 0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(color: AppColors.coralOrange, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      salat,
                                      style: GoogleFonts.poppins(
                                        color: AppColors.navyBlue,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        if (count > 0) onQazaCountChange(salat, count - 1);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: AppColors.navyBlue.withValues(alpha: 0.15)),
                                        ),
                                        child: const Icon(Icons.remove, size: 14, color: AppColors.navyBlue),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 28,
                                      child: Text(
                                        '$count',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.poppins(
                                          color: AppColors.navyBlue,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    GestureDetector(
                                      onTap: () => onQazaCountChange(salat, count + 1),
                                      child: Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: AppColors.navyBlue.withValues(alpha: 0.15)),
                                        ),
                                        child: const Icon(Icons.add, size: 14, color: AppColors.navyBlue),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSunPosition(double width) {
    double sunTop = 80.0;
    double sunLeft = width * 0.5 - 25;
    double opacity = 0.0;

    switch (selectedPrayerScene) {
      case 'Sunrise':
        sunTop = 150.0;
        sunLeft = width * 0.5 - 25;
        opacity = 0.9;
        break;
      case 'Dhuhr':
        sunTop = 38.0;
        sunLeft = width * 0.5 - 25;
        opacity = 1.0;
        break;
      case 'Asr':
        sunTop = 72.0;
        sunLeft = width * 0.72 - 25;
        opacity = 0.95;
        break;
      case 'Maghrib':
        sunTop = 175.0;
        sunLeft = width * 0.5 - 25;
        opacity = 0.85;
        break;
      default:
        opacity = 0.0;
    }

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeInOutCubic,
      top: sunTop,
      left: sunLeft,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 700),
        opacity: opacity,
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9C4),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: const Color(0xFFFFA000).withValues(alpha: 0.55), blurRadius: 28, spreadRadius: 8),
              const BoxShadow(color: Colors.white, blurRadius: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoonPosition(double width) {
    double moonTop = 50.0;
    double moonLeft = width * 0.5 - 25;
    double opacity = 0.0;

    if (selectedPrayerScene == 'Fajr' || selectedPrayerScene == 'Isha') {
      opacity = 0.95;
    }

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeInOutCubic,
      top: moonTop,
      left: moonLeft,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 700),
        opacity: opacity,
        child: SizedBox(
          width: 50,
          height: 50,
          child: CustomPaint(painter: CrescentMoonPainter()),
        ),
      ),
    );
  }
}

// ===== PRAYER HEADER STARS PAINTER =====
class PrayerHeaderStarsPainter extends CustomPainter {
  final double pulseVal;
  PrayerHeaderStarsPainter({required this.pulseVal});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final List<Offset> positions = [
      Offset(w * 0.05, h * 0.12), Offset(w * 0.12, h * 0.28),
      Offset(w * 0.18, h * 0.08), Offset(w * 0.25, h * 0.18),
      Offset(w * 0.32, h * 0.32), Offset(w * 0.40, h * 0.10),
      Offset(w * 0.48, h * 0.24), Offset(w * 0.55, h * 0.38),
      Offset(w * 0.60, h * 0.14), Offset(w * 0.67, h * 0.06),
      Offset(w * 0.72, h * 0.30), Offset(w * 0.78, h * 0.20),
      Offset(w * 0.85, h * 0.40), Offset(w * 0.90, h * 0.12),
      Offset(w * 0.95, h * 0.26), Offset(w * 0.08, h * 0.44),
      Offset(w * 0.22, h * 0.50), Offset(w * 0.36, h * 0.48),
      Offset(w * 0.50, h * 0.55), Offset(w * 0.64, h * 0.52),
    ];

    for (int i = 0; i < positions.length; i++) {
      final double phase = (i * 0.37) % 1.0;
      final double twinkle = (math.sin((pulseVal + phase) * math.pi) + 1.0) / 2.0;
      final double alpha = 0.15 + twinkle * 0.7;
      final double starSize = 2.0 + (i % 3) * 1.5;

      final paint = Paint()
        ..color = Colors.white.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;

      _drawStar(canvas, positions[i], starSize, paint);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    final cx = center.dx;
    final cy = center.dy;
    final r = size / 2;
    path.moveTo(cx, cy - r);
    path.quadraticBezierTo(cx, cy, cx + r, cy);
    path.quadraticBezierTo(cx, cy, cx, cy + r);
    path.quadraticBezierTo(cx, cy, cx - r, cy);
    path.quadraticBezierTo(cx, cy, cx, cy - r);
    path.close();
    canvas.drawPath(path, paint);
    canvas.drawCircle(center, size * 0.12, Paint()..color = Colors.white..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant PrayerHeaderStarsPainter oldDelegate) => oldDelegate.pulseVal != pulseVal;
}

// ===== DRIFTING CLOUDS PAINTER =====
class DriftingCloudsPainter extends CustomPainter {
  final double animVal;
  final Color cloudColor;

  DriftingCloudsPainter({required this.animVal, required this.cloudColor});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final cloudPaint = Paint()
      ..color = cloudColor.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;

    double x1 = (w * animVal + w * 0.1) % (w + 100) - 50;
    _drawCloud(canvas, Offset(x1, h * 0.25), 26, cloudPaint);

    double x2 = (w * 1.4 * animVal + w * 0.55) % (w + 120) - 60;
    _drawCloud(canvas, Offset(x2, h * 0.42), 32, cloudPaint);

    double x3 = (w * 0.7 * animVal + w * 0.3) % (w + 80) - 40;
    _drawCloud(canvas, Offset(x3, h * 0.60), 16,
        Paint()..color = cloudColor.withValues(alpha: 0.08)..style = PaintingStyle.fill);
  }

  void _drawCloud(Canvas canvas, Offset center, double baseSize, Paint paint) {
    final cx = center.dx;
    final cy = center.dy;
    canvas.drawCircle(Offset(cx, cy), baseSize, paint);
    canvas.drawCircle(Offset(cx - baseSize * 0.6, cy + baseSize * 0.22), baseSize * 0.75, paint);
    canvas.drawCircle(Offset(cx + baseSize * 0.6, cy + baseSize * 0.22), baseSize * 0.75, paint);
    canvas.drawCircle(Offset(cx - baseSize * 1.15, cy + baseSize * 0.38), baseSize * 0.55, paint);
    canvas.drawCircle(Offset(cx + baseSize * 1.15, cy + baseSize * 0.38), baseSize * 0.55, paint);
  }

  @override
  bool shouldRepaint(covariant DriftingCloudsPainter oldDelegate) =>
      oldDelegate.animVal != animVal || oldDelegate.cloudColor != cloudColor;
}

// ===== DYNAMIC CRESCENT MOON PAINTER =====
class CrescentMoonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width * 0.4;

    final moonPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), radius, moonPaint);

    final cutoutPaint = Paint()
      ..color = Colors.transparent
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.fill;

    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawCircle(Offset(cx, cy), radius, moonPaint);
    canvas.drawCircle(Offset(cx + radius * 0.35, cy - radius * 0.18), radius * 0.85, cutoutPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ===== FULL RICH MOSQUE SILHOUETTE (matches splash screen style) =====
class MosqueSilhouettePainter extends CustomPainter {
  final String selectedScene;

  MosqueSilhouettePainter({required this.selectedScene});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    Color navyC, tealC, whiteC;
    switch (selectedScene) {
      case 'Fajr':
        navyC = const Color(0xFF1D2D44);
        tealC = const Color(0xFF4A7C74);
        whiteC = const Color(0xFFB8CEDE);
        break;
      case 'Sunrise':
        navyC = const Color(0xFF5D3A1A);
        tealC = const Color(0xFFD4854A);
        whiteC = const Color(0xFFFFE9D6);
        break;
      case 'Dhuhr':
        navyC = const Color(0xFF0D47A1);
        tealC = const Color(0xFF1976D2);
        whiteC = Colors.white;
        break;
      case 'Asr':
        navyC = const Color(0xFF1B5E8A);
        tealC = const Color(0xFF4FA8D2);
        whiteC = const Color(0xFFE0F7FA);
        break;
      case 'Maghrib':
        navyC = const Color(0xFF4A1942);
        tealC = const Color(0xFFB05C8A);
        whiteC = const Color(0xFFFFD4E8);
        break;
      case 'Isha':
      default:
        navyC = const Color(0xFF0A1628);
        tealC = const Color(0xFF1A3050);
        whiteC = const Color(0xFF7B93B0);
        break;
    }

    final paintNavy = Paint()..color = navyC..style = PaintingStyle.fill;
    final paintTeal = Paint()..color = tealC..style = PaintingStyle.fill;
    final paintWhite = Paint()..color = whiteC..style = PaintingStyle.fill;

    _drawOnionDome(canvas, w * 0.28, h * 0.68, w * 0.16, h * 0.26, paintTeal);
    _drawOnionDome(canvas, w * 0.72, h * 0.68, w * 0.16, h * 0.26, paintTeal);

    final wallPath = Path()
      ..moveTo(w * 0.12, h)
      ..lineTo(w * 0.12, h * 0.70)
      ..lineTo(w * 0.88, h * 0.70)
      ..lineTo(w * 0.88, h)
      ..close();
    canvas.drawPath(wallPath, paintWhite);

    _drawOnionDome(canvas, w * 0.50, h * 0.65, w * 0.32, h * 0.42, paintNavy);

    final double spireTop = h * 0.65 - h * 0.42 - 8;
    final spirePaint = Paint()
      ..color = whiteC
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w * 0.50, h * 0.65 - h * 0.42), Offset(w * 0.50, spireTop), spirePaint);
    canvas.drawCircle(Offset(w * 0.50, spireTop), 2.2, paintWhite);

    final double doorCx = w * 0.50;
    final double doorW = w * 0.12;
    final double doorH = h * 0.30;
    final double doorTop = h - doorH;
    final doorPath = Path()
      ..moveTo(doorCx - doorW / 2, h)
      ..lineTo(doorCx - doorW / 2, doorTop + doorW * 0.5)
      ..quadraticBezierTo(doorCx, doorTop - doorW * 0.3, doorCx + doorW / 2, doorTop + doorW * 0.5)
      ..lineTo(doorCx + doorW / 2, h)
      ..close();
    canvas.drawPath(doorPath, paintNavy);

    for (final wx in [w * 0.35, w * 0.65]) {
      final winW = w * 0.07;
      final winH = h * 0.16;
      final winTop = h - winH - h * 0.06;
      final winPath = Path()
        ..moveTo(wx - winW / 2, h - h * 0.06)
        ..lineTo(wx - winW / 2, winTop + winW * 0.5)
        ..quadraticBezierTo(wx, winTop - winW * 0.2, wx + winW / 2, winTop + winW * 0.5)
        ..lineTo(wx + winW / 2, h - h * 0.06)
        ..close();
      canvas.drawPath(winPath, paintNavy);
    }

    canvas.drawRect(Rect.fromLTRB(0, h * 0.92, w, h), paintWhite);

    _drawMinaret(canvas, w * 0.14, h, w * 0.07, h * 0.90, paintWhite, paintTeal);
    _drawMinaret(canvas, w * 0.86, h, w * 0.07, h * 0.90, paintWhite, paintTeal);
  }

  void _drawOnionDome(Canvas canvas, double cx, double by, double width, double height, Paint paint) {
    final path = Path();
    final double w2 = width / 2;
    final double bulge = width * 0.08;
    path.moveTo(cx - w2, by);
    path.cubicTo(cx - w2 - bulge, by - height * 0.35, cx - w2 + bulge * 0.2, by - height * 0.75, cx, by - height);
    path.cubicTo(cx + w2 - bulge * 0.2, by - height * 0.75, cx + w2 + bulge, by - height * 0.35, cx + w2, by);
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawMinaret(Canvas canvas, double cx, double by, double width, double height, Paint paintBody, Paint paintCap) {
    final double colW = width * 0.55;
    final double balconyW = width * 1.15;
    canvas.drawRect(Rect.fromLTRB(cx - colW / 2, by - height, cx + colW / 2, by), paintBody);
    canvas.drawRect(Rect.fromLTRB(cx - balconyW / 2, by - height * 0.72, cx + balconyW / 2, by - height * 0.69), paintBody);
    canvas.drawRect(Rect.fromLTRB(cx - balconyW / 2, by - height - 2, cx + balconyW / 2, by - height), paintBody);
    _drawOnionDome(canvas, cx, by - height - 2, width * 0.75, height * 0.13, paintCap);
  }

  @override
  bool shouldRepaint(covariant MosqueSilhouettePainter oldDelegate) => oldDelegate.selectedScene != selectedScene;
}