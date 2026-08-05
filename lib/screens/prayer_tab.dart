import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../widgets/auth_header.dart'; // AppColors
import '../services/theme_service.dart';

/// ─────────────────────────────────────────────────────────────────────
/// Dark-mode aware color helpers for this tab.
///
/// Every card here was originally styled as a fixed light "frosted
/// glass" surface (white-ish translucent background + navy text/icons).
/// That's kept exactly as-is in light mode. In dark mode, every one of
/// those cards instead renders solid black with white text/icons, driven
/// by Theme.of(context).brightness — so this follows whatever mechanism
/// the app already uses to switch into dark mode (ThemeMode.system /
/// light / dark on MaterialApp, or a manual theme swap that sets
/// ThemeData(brightness: Brightness.dark)).
bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

/// Card / surface background color.
Color _cardSurface(BuildContext context, {double lightAlpha = 0.72}) {
  return _isDark(context)
      ? Colors.black
      : Colors.white.withValues(alpha: lightAlpha);
}

/// Primary text/icon color: navy in light mode, white in dark mode.
Color _onSurface(BuildContext context, {double alpha = 1.0}) {
  return _isDark(context)
      ? Colors.white.withValues(alpha: alpha)
      : AppColors.navyBlue.withValues(alpha: alpha);
}

/// Faint fill used for pills/rows/unselected chips inside a card.
Color _subtleFill(
  BuildContext context, {
  double lightAlpha = 0.05,
  double darkAlpha = 0.12,
}) {
  return _isDark(context)
      ? Colors.white.withValues(alpha: darkAlpha)
      : AppColors.navyBlue.withValues(alpha: lightAlpha);
}

/// Card border color.
Color _cardBorder(BuildContext context) {
  return _isDark(context)
      ? Colors.white.withValues(alpha: 0.16)
      : AppColors.navyBlue.withValues(alpha: 0.08);
}

/// The Prayer tab: full-width looping video hero (mosque landscape), salat
/// tracker, qaza counter and prayer time list.
///
/// Salat completion, qaza counts, and alarms are still owned by
/// DashboardScreen and passed in (its real-time timer needs them too, to
/// fire the in-app alarm overlay and auto-log qaza regardless of which tab
/// is active).
///
/// Which prayer's *scene* is currently shown (hero video + highlighted
/// list card), however, is owned locally by this widget. It always starts
/// on whichever prayer window we're actually in right now, and only
/// changes when the user explicitly taps a different prayer in the list —
/// it deliberately does not trust an externally-provided initial value for
/// this, so it can never open on the wrong prayer's video.
class PrayerTab extends StatefulWidget {
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

  @override
  State<PrayerTab> createState() => _PrayerTabState();
}

class _PrayerTabState extends State<PrayerTab> {
  // Explicit manual scene choice made by the user tapping a prayer card in
  // this session. Null until they tap something — while null, the hero
  // video and highlighted card always fall back to the *actual current
  // prayer*, computed fresh below, regardless of widget.selectedPrayerScene.
  String? _manualScene;

  static const Map<String, IconData> _sceneIcons = {
    'Fajr': Icons.nightlight_round,
    'Sunrise': Icons.wb_twilight_rounded,
    'Dhuhr': Icons.wb_sunny_rounded,
    'Asr': Icons.filter_drama_rounded,
    'Maghrib': Icons.brightness_4_rounded,
    'Isha': Icons.dark_mode_rounded,
  };

  void _selectScene(String name) {
    setState(() => _manualScene = name);
    widget.onSceneSelected(name);
  }

  // Approximate Hijri date string for display in the header.
  String _getHijriDateString() {
    final today = DateTime.now();
    final hijriMonths = [
      "Muharram",
      "Safar",
      "Rabi' al-Awwal",
      "Rabi' ath-Thani",
      "Jumada al-Ula",
      "Jumada al-Akhirah",
      "Rajab",
      "Sha'ban",
      "Ramadan",
      "Shawwal",
      "Dhu al-Qa'dah",
      "Dhu al-Hijjah",
    ];
    int monthIndex = (today.month + 3) % 12;
    int day = (today.day + 12) % 29 + 1;
    int year = today.year - 578;
    return "$day ${hijriMonths[monthIndex]}, $year AH";
  }

  String _getCurrentPrayerName(
    Coordinates coordinates,
    CalculationParameters params,
  ) {
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
    final coordinates = Coordinates(widget.latitude, widget.longitude);
    final params = CalculationMethod.karachi.getParameters();
    params.madhab = Madhab.hanafi;

    final prayerTimes = PrayerTimes.today(coordinates, params);
    final formatter = DateFormat('hh:mm a');
    final now = DateTime.now();

    final currentPrayer = _getCurrentPrayerName(coordinates, params);

    // Source of truth for "what's shown" — the actual current prayer until
    // the user taps something else.
    final String effectiveScene = _manualScene ?? currentPrayer;

    int completedCount = widget.salatCompleted.values.where((v) => v).length;

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

    // The prayer "day" isn't over until Isha's own window has closed (i.e.
    // tomorrow's Fajr arrives) — that's the same boundary already used
    // below to decide whether Isha itself was missed. Only once we're past
    // that point do we actually know whether every prayer was completed,
    // so "All Caught Up" is reserved for that moment.
    final bool dayEnded = now.isAfter(tomorrowFajrTime);

    // A salat only counts as "missed" once ITS OWN window has closed and
    // it still isn't marked done — never the moment the window opens.
    // e.g. Fajr is only missed once sunrise arrives, Dhuhr once Asr
    // arrives, and so on, with Isha missed only once tomorrow's Fajr
    // arrives. This is computed locally so the tracker card reflects the
    // correct timing regardless of how the externally-owned qaza counter
    // (in DashboardScreen) currently increments.
    DateTime? expireTimeFor(String salat) {
      switch (salat) {
        case 'Fajr':
          return prayerTimes.sunrise;
        case 'Dhuhr':
          return salatDts['Asr'];
        case 'Asr':
          return salatDts['Maghrib'];
        case 'Maghrib':
          return salatDts['Isha'];
        case 'Isha':
          return tomorrowFajrTime;
        default:
          return null;
      }
    }

    final List<String> todaysMissedPrayers =
        ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'].where((salat) {
          final expireTime = expireTimeFor(salat);
          final isDone = widget.salatCompleted[salat] ?? false;
          return expireTime != null && now.isAfter(expireTime) && !isDone;
        }).toList();

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

    return Column(
      key: const ValueKey('PrayerTab'),
      children: [
        // ── FULL-WIDTH VIDEO HERO (no card, no rounding, edge-to-edge) ──
        SizedBox(
          width: double.infinity,
          height: 260 + MediaQuery.of(context).padding.top,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Hero background reactive to user's theme choice (Video or Vector)
              ValueListenableBuilder<String>(
                valueListenable: prayerCardThemeNotifier,
                builder: (context, themeId, _) {
                  if (themeId == 'vector') {
                    return _PrayerVectorBackground(scene: effectiveScene);
                  }
                  return _PrayerVideoBackground(scene: effectiveScene);
                },
              ),
              // Subtle scrim so the header text/icons stay legible over
              // whatever part of the video is showing.
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.38),
                      Colors.black.withValues(alpha: 0.05),
                      Colors.black.withValues(alpha: 0.45),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    MediaQuery.of(context).padding.top + 8,
                    18,
                    14,
                  ),
                  child: Stack(
                    children: [
                      // Top row: title + location button — pinned to the top.
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.25),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.schedule_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Prayer Times',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                    Text(
                                      'Daily timings, reminders',
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        color: Colors.white.withValues(alpha: 0.78),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            IconButton(
                              tooltip: 'Find nearby mosques',
                              icon: const Icon(
                                Icons.location_on_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: () async {
                                final lat = widget.latitude;
                                final lng = widget.longitude;
                                final messenger = ScaffoldMessenger.of(context);
                                final geoUri = Uri.parse(
                                  'geo:$lat,$lng?q=mosque+near+me&z=14',
                                );
                                final mapsWebUri = Uri.parse(
                                  'https://www.google.com/maps/search/mosque+near+me/@$lat,$lng,14z',
                                );
                                if (await canLaunchUrl(geoUri)) {
                                  await launchUrl(geoUri);
                                } else if (await canLaunchUrl(mapsWebUri)) {
                                  await launchUrl(
                                    mapsWebUri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                } else {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Could not open Maps. Please install Google Maps.',
                                        style: GoogleFonts.inter(fontSize: 13),
                                      ),
                                      backgroundColor: AppColors.navyBlue,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      // Bottom block: next prayer + countdown + location —
                      // pinned to the bottom, independent of the top row's
                      // height, so short (landscape) viewports can never
                      // force an overflow here.
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Next: ${widget.nextPrayerName}',
                                      style: GoogleFonts.inter(
                                        color: Colors.white.withValues(alpha: 0.85),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.liveCountdownStr,
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 34,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.0,
                                        height: 1.1,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.4,
                                            ),
                                            blurRadius: 10,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  color: Colors.white70,
                                  size: 13,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.locationName.split(',').first,
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 12,
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
                ),
              ),
            ],
          ),
        ),

        // ── SCROLLABLE LOWER SECTION ──
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 14),

                // Tappable scene strip — tap a prayer to preview its
                // ambient hero video above. A small red dot flags any
                // prayer already missed today (Sunrise is never "missed").
                SizedBox(
                  height: 72,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: 6,
                    separatorBuilder: (_, __) => const SizedBox(width: 9),
                    itemBuilder: (context, index) {
                      const names = [
                        'Fajr',
                        'Sunrise',
                        'Dhuhr',
                        'Asr',
                        'Maghrib',
                        'Isha',
                      ];
                      final String pName = names[index];
                      final bool isSalat = pName != 'Sunrise';

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
                        isMissed =
                            expireTime != null &&
                            now.isAfter(expireTime) &&
                            !(widget.salatCompleted[pName] ?? false);
                      }

                      final bool isSelected = pName == effectiveScene;
                      final bool dark = _isDark(context);

                      // The scene icon/text color adapts to the theme —
                      // navy on light backgrounds, white on dark ones —
                      // selection is conveyed by weight/opacity, not hue.
                      final Color accent = dark
                          ? Colors.white
                          : AppColors.navyBlue;

                     final bool alarmEnabled =
                          isSalat && (widget.prayerAlarms[pName] ?? false);

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: GestureDetector(
                              onTap: () => _selectScene(pName),
                              child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                              width: 58,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: dark
                                    ? (isSelected
                                          ? Colors.white.withValues(alpha: 0.15)
                                          : Colors.black)
                                    : (isSelected
                                          ? accent.withValues(alpha: 0.10)
                                          : Colors.white.withValues(alpha: 0.6)),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? accent.withValues(alpha: dark ? 0.55 : 0.4)
                                      : (dark
                                            ? Colors.white.withValues(alpha: 0.25)
                                            : accent.withValues(alpha: 0.08)),
                                  width: 1.2,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: accent.withValues(
                                            alpha: isSelected ? 0.18 : 0.1,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _sceneIcons[pName],
                                          color: accent,
                                          size: 14,
                                        ),
                                      ),
                                      if (isMissed)
                                        Positioned(
                                          right: -2,
                                          top: -2,
                                          child: Container(
                                            width: 9,
                                            height: 9,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE57373),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 1.2,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    pName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 9.5,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: isMissed
                                          ? const Color(0xFFEF9A9A)
                                          : isSelected
                                          ? accent
                                          : accent.withValues(
                                              alpha: dark ? 0.65 : 0.6,
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ),
                          ),
                          // Bell toggle — only for actual salat (not Sunrise).
                          // Tapping it toggles that prayer's alarm without
                          // triggering the card's own onTap (scene select).
                         if (isSalat)
                            Positioned(
                              top: 0,
                              right: -3,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => widget.onAlarmToggle(
                                  pName,
                                  !alarmEnabled,
                                ),
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: alarmEnabled
                                        ? AppColors.coralOrange
                                        : (dark
                                              ? Colors.black
                                              : Colors.white),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: alarmEnabled
                                          ? AppColors.coralOrange
                                          : (dark
                                                ? Colors.white.withValues(
                                                    alpha: 0.35,
                                                  )
                                                : accent.withValues(alpha: 0.25)),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.18,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    alarmEnabled
                                        ? Icons.notifications_active_rounded
                                        : Icons.notifications_off_rounded,
                                    size: 10,
                                    color: alarmEnabled ? Colors.white : accent,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 14),

                // 1. Prayer Overview Summary Card — mirrors the reference
                // "Prayer Time" mockup (date, next/current highlight cards,
                // Suhoor/Iftar, mosque/location, compact prayer list, sun
                // times) restyled with the app's navy / coral / dusty-teal
                // palette from the splash screen. This is the single
                // source of truth for the compact per-prayer time list —
                // it is not repeated anywhere else on this tab.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _PrayerOverviewCard(
                    prayerTimes: prayerTimes,
                    currentPrayer: currentPrayer,
                    nextPrayerName: widget.nextPrayerName,
                    liveCountdownStr: widget.liveCountdownStr,
                    locationName: widget.locationName,
                    hijriDate: _getHijriDateString(),
                    formatter: formatter,
                  ),
                ),

                const SizedBox(height: 16),

                // 2. Daily Salat Count Checklist Tracker
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: _GlassCard(
                    child: Column(
                      children: [
                        _SectionHeader(
                          icon: Icons.stars_rounded,
                          iconColor: AppColors.navyBlue,
                          title: 'Daily Salat Tracker',
                          subtitle: 'Mark each prayer as you complete it',
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.navyBlue,
                                  AppColors.navyBlue.withValues(alpha: 0.72),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.navyBlue.withValues(
                                    alpha: 0.25,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              '$completedCount/5',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 6,
                            color: _isDark(context)
                                ? Colors.white.withValues(alpha: 0.12)
                                : AppColors.navyBlue.withValues(alpha: 0.08),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 500),
                                    curve: Curves.easeOutCubic,
                                    width:
                                        constraints.maxWidth *
                                        (completedCount / 5),
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.navyBlue,
                                          Color(0xFF3D6FA0),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: widget.salatCompleted.keys.map((salat) {
                            final isDone =
                                widget.salatCompleted[salat] ?? false;

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

                            final bool isFuture =
                                sTime != null && now.isBefore(sTime);
                            final bool isExpired =
                                expireTime != null && now.isAfter(expireTime);
                            final bool isSalatMissed = isExpired && !isDone;
                            final bool dark = _isDark(context);

                              return GestureDetector(
                                onTap: () {
                                  if (isSalatMissed || isFuture) return;
                                  widget.onSalatToggle(salat, !isDone);
                                },
                                child: Column(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.elasticOut,
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: isDone
                                          ? null
                                          : isSalatMissed
                                          ? (dark
                                                ? const Color(0xFF3A1618)
                                                : const Color(0xFFFFEBEE))
                                          : isFuture
                                          ? (dark
                                                ? Colors.white.withValues(
                                                    alpha: 0.06,
                                                  )
                                                : Colors.black.withValues(
                                                    alpha: 0.04,
                                                  ))
                                          : (dark
                                                ? Colors.white.withValues(
                                                    alpha: 0.08,
                                                  )
                                                : Colors.white.withValues(
                                                    alpha: 0.4,
                                                  )),
                                      gradient: isDone
                                          ? const LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                AppColors.navyBlue,
                                                Color(0xFF23415C),
                                              ],
                                            )
                                          : null,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSalatMissed
                                            ? const Color(0xFFE57373)
                                            : isFuture
                                            ? (dark
                                                  ? Colors.white.withValues(
                                                      alpha: 0.16,
                                                    )
                                                  : Colors.black.withValues(
                                                      alpha: 0.1,
                                                    ))
                                            : isDone
                                            ? Colors.transparent
                                            : (dark
                                                  ? Colors.white.withValues(
                                                      alpha: 0.35,
                                                    )
                                                  : AppColors.navyBlue
                                                        .withValues(
                                                          alpha: 0.25,
                                                        )),
                                        width: 1.4,
                                      ),
                                      boxShadow: isDone
                                          ? [
                                              BoxShadow(
                                                color: AppColors.navyBlue
                                                    .withValues(alpha: 0.28),
                                                blurRadius: 8,
                                                spreadRadius: 0.5,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: Center(
                                      child: isSalatMissed
                                          ? const Icon(
                                              Icons.close_rounded,
                                              color: Color(0xFFE57373),
                                              size: 16,
                                            )
                                          : isFuture
                                          ? Icon(
                                              Icons.lock_outline_rounded,
                                              color: dark
                                                  ? Colors.white.withValues(
                                                      alpha: 0.4,
                                                    )
                                                  : Colors.black.withValues(
                                                      alpha: 0.22,
                                                    ),
                                              size: 14,
                                            )
                                          : isDone
                                          ? const Icon(
                                              Icons.check_rounded,
                                              color: Colors.white,
                                              size: 18,
                                            )
                                          : Icon(
                                              Icons.circle_outlined,
                                              color: dark
                                                  ? Colors.white.withValues(
                                                      alpha: 0.5,
                                                    )
                                                  : AppColors.navyBlue
                                                        .withValues(
                                                          alpha: 0.28,
                                                        ),
                                              size: 16,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    salat,
                                    style: GoogleFonts.poppins(
                                      color: isSalatMissed
                                          ? const Color(0xFFE57373)
                                          : isFuture
                                          ? (dark
                                                ? Colors.white.withValues(
                                                    alpha: 0.4,
                                                  )
                                                : Colors.black.withValues(
                                                    alpha: 0.3,
                                                  ))
                                          : isDone
                                          ? (dark
                                                ? Colors.white
                                                : AppColors.navyBlue)
                                          : (dark
                                                ? Colors.white.withValues(
                                                    alpha: 0.7,
                                                  )
                                                : AppColors.navyBlue.withValues(
                                                    alpha: 0.6,
                                                  )),
                                      fontSize: 10.5,
                                      fontWeight: isDone
                                          ? FontWeight.bold
                                          : FontWeight.w500,
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

                // ===== TODAY'S MISSED PRAYER STATUS CARD =====
                // "All Caught Up" only appears once the prayer day is
                // actually over (past Isha's window). While the day is
                // still in progress: show the running missed prayers if
                // there are any, otherwise show nothing — it's premature
                // to declare the day clean before it's finished.
                //
                // Driven by todaysMissedPrayers (computed above from each
                // prayer's own window closing), not widget.qazaCount —
                // this guarantees a prayer is only ever flagged missed
                // once its time has fully passed, never the moment it
                // starts.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: todaysMissedPrayers.isNotEmpty
                        ? Container(
                            key: const ValueKey('MissedWarning'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              gradient: _isDark(context)
                                  ? const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF2A1113),
                                        Color(0xFF1F0D0E),
                                      ],
                                    )
                                  : const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFFFFF5F5),
                                        Color(0xFFFFEBEB),
                                      ],
                                    ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(
                                  0xFFE57373,
                                ).withValues(alpha: 0.4),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFE57373,
                                  ).withValues(alpha: 0.12),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFE57373,
                                        ).withValues(alpha: 0.14),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.warning_amber_rounded,
                                          color: Color(0xFFD32F2F),
                                          size: 19,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            dayEnded
                                                ? 'Today\'s Missed Prayers'
                                                : 'Missed So Far Today',
                                            style: GoogleFonts.poppins(
                                              color: _isDark(context)
                                                  ? const Color(0xFFFFCDD2)
                                                  : const Color(0xFFB71C1C),
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'You missed ${todaysMissedPrayers.length} prayer${todaysMissedPrayers.length > 1 ? 's' : ''}${dayEnded ? '' : ' so far'} today.',
                                            style: GoogleFonts.inter(
                                              color:
                                                  (_isDark(context)
                                                          ? const Color(
                                                              0xFFFFCDD2,
                                                            )
                                                          : const Color(
                                                              0xFFD32F2F,
                                                            ))
                                                      .withValues(alpha: 0.80),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFE57373,
                                        ).withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${todaysMissedPrayers.length}',
                                        style: GoogleFonts.poppins(
                                          color: _isDark(context)
                                              ? const Color(0xFFFFCDD2)
                                              : const Color(0xFFB71C1C),
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: todaysMissedPrayers.map((name) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFE57373,
                                        ).withValues(alpha: 0.16),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        name,
                                        style: GoogleFonts.inter(
                                          color: _isDark(context)
                                              ? const Color(0xFFFFCDD2)
                                              : const Color(0xFFB71C1C),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          )
                        : dayEnded
                        ? Container(
                            key: const ValueKey('AllCompleted'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              gradient: _isDark(context)
                                  ? const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF10251A),
                                        Color(0xFF0B1D13),
                                      ],
                                    )
                                  : const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFFF4FBF7),
                                        Color(0xFFEBF7F0),
                                      ],
                                    ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(
                                  0xFF81C784,
                                ).withValues(alpha: 0.4),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF81C784,
                                  ).withValues(alpha: 0.12),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF81C784,
                                    ).withValues(alpha: 0.14),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.check_circle_outline_rounded,
                                      color: Color(0xFF2E7D32),
                                      size: 19,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'All Caught Up!',
                                        style: GoogleFonts.poppins(
                                          color: _isDark(context)
                                              ? const Color(0xFFA5D6A7)
                                              : const Color(0xFF1B5E20),
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'No missed prayers today.',
                                        style: GoogleFonts.inter(
                                          color:
                                              (_isDark(context)
                                                      ? const Color(0xFFA5D6A7)
                                                      : const Color(0xFF2E7D32))
                                                  .withValues(alpha: 0.80),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(key: ValueKey('DayInProgress')),
                  ),
                ),

                // ===== INTERACTIVE QAZA COUNTER SECTION =====
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeader(
                          icon: Icons.history_toggle_off_rounded,
                          iconColor: AppColors.navyBlue,
                          title: 'Qaza Prayer Counter',
                          subtitle:
                              'Log missed prayers to make them up over time',
                        ),
                        const SizedBox(height: 14),
                        ...['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'].map((
                          salat,
                        ) {
                          final count = widget.qazaCounts[salat] ?? 0;
                          final bool dark = _isDark(context);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: count > 0
                                  ? (dark
                                        ? AppColors.coralOrange.withValues(
                                            alpha: 0.18,
                                          )
                                        : AppColors.coralOrange.withValues(
                                            alpha: 0.06,
                                          ))
                                  : (dark
                                        ? Colors.black
                                        : AppColors.navyBlue.withValues(
                                            alpha: 0.035,
                                          )),
                              borderRadius: BorderRadius.circular(16),
                              border: dark
                                  ? Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.12,
                                      ),
                                      width: 1,
                                    )
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        color: count > 0
                                            ? AppColors.coralOrange
                                            : _onSurface(context, alpha: 0.25),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 11),
                                    Text(
                                      salat,
                                      style: GoogleFonts.poppins(
                                        color: _onSurface(context),
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    _QazaStepperButton(
                                      icon: Icons.remove_rounded,
                                      onTap: () {
                                        if (count > 0)
                                          widget.onQazaCountChange(
                                            salat,
                                            count - 1,
                                          );
                                      },
                                    ),
                                    SizedBox(
                                      width: 32,
                                      child: Text(
                                        '$count',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.poppins(
                                          color: _onSurface(context),
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    _QazaStepperButton(
                                      icon: Icons.add_rounded,
                                      onTap: () => widget.onQazaCountChange(
                                        salat,
                                        count + 1,
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
}

/// Consistent frosted "glass" surface used for every card in the lower
/// section — same radius, border, and soft shadow everywhere so the page
/// reads as one cohesive design instead of a stack of mismatched panels.
class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final double borderWidth;

  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderColor, // null = theme-appropriate default (see build())
    this.borderWidth = 1.4,
  });

  @override
  Widget build(BuildContext context) {
    final bool dark = _isDark(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: dark ? Colors.black : Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color:
              borderColor ??
              (dark
                  ? Colors.white.withValues(alpha: 0.16)
                  : const Color(0x261A2E40)),
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: dark
                ? Colors.black.withValues(alpha: 0.5)
                : AppColors.navyBlue.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Shared section title row: a tinted icon chip, title + optional
/// subtitle, and an optional trailing badge/action.
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final Color effectiveIconColor = _isDark(context)
        ? Colors.white
        : iconColor;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: effectiveIconColor.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: effectiveIconColor, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: _onSurface(context),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: GoogleFonts.inter(
                    color: _onSurface(context, alpha: 0.6),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Compact +/- button used in the Qaza counter rows.
class _QazaStepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QazaStepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool dark = _isDark(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: dark ? Colors.black : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: dark
                ? Colors.white.withValues(alpha: 0.35)
                : AppColors.navyBlue.withValues(alpha: 0.14),
          ),
          boxShadow: dark
              ? []
              : [
                  BoxShadow(
                    color: AppColors.navyBlue.withValues(alpha: 0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Icon(
          icon,
          size: 14,
          color: dark ? Colors.white : AppColors.navyBlue,
        ),
      ),
    );
  }
}

/// Full-bleed looping ambient video background. Muted, auto-plays, loops
/// seamlessly, and crops (BoxFit.cover) to fill the available space.
///
/// All scene videos are preloaded and kept "warm" (initialized + paused)
/// in a controller cache, so switching scenes never has to wait on
/// [VideoPlayerController.initialize] — the crossfade starts the instant
/// the user taps a new prayer, instead of stalling on a black/loading
/// frame while the new asset spins up.
class _PrayerVideoBackground extends StatefulWidget {
  final String? scene;

  const _PrayerVideoBackground({this.scene});

  @override
  State<_PrayerVideoBackground> createState() => _PrayerVideoBackgroundState();
}

class _PrayerVideoBackgroundState extends State<_PrayerVideoBackground>
    with SingleTickerProviderStateMixin {
  static const String _fallbackAsset = 'assets/videos/mosque_ambient.mp4';

  static const Map<String, String> _prayerVideoMap = {
    'fajr': 'assets/videos/fajr.mp4',
    'sunrise': 'assets/videos/sunrise.mp4',
    'dhuhr': 'assets/videos/zuhr.mp4',
    'zuhr': 'assets/videos/zuhr.mp4',
    'asr': 'assets/videos/asr.mp4',
    'maghrib': 'assets/videos/maghrib.mp4',
    'isha': 'assets/videos/isha.mp4',
  };

  // Every controller we've ever created for a given asset path, kept alive
  // (not disposed) so re-selecting a scene is instant on subsequent taps.
  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, bool> _ready = {};
  final Map<String, Future<void>> _initFutures = {};

  String? _currentPath;
  String? _previousPath;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  String _resolveAssetPath() {
    if (widget.scene != null && widget.scene!.isNotEmpty) {
      final key = widget.scene!.toLowerCase();
      if (_prayerVideoMap.containsKey(key)) {
        return _prayerVideoMap[key]!;
      }
    }
    return _fallbackAsset;
  }

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    final initialPath = _resolveAssetPath();
    _showInitial(initialPath);

    // Warm up every other scene's video in the background so the very
    // first tap on a different prayer is just as instant as later ones.
    _preloadRemainingScenes(skip: initialPath);
  }

  /// Ensures a controller exists for [path] and is being initialized.
  /// Safe to call repeatedly — returns the same in-flight/completed future.
  Future<void> _ensureController(String path) {
    final existing = _initFutures[path];
    if (existing != null) return existing;

    final controller = VideoPlayerController.asset(path);
    _controllers[path] = controller;

    final future = controller
        .initialize()
        .then((_) async {
          await controller.setLooping(true);
          await controller.setVolume(0);
          _ready[path] = true;
        })
        .catchError((_) {
          _ready[path] = false;
        });

    _initFutures[path] = future;
    return future;
  }

  Future<void> _showInitial(String path) async {
    _currentPath = path;
    await _ensureController(path);
    if (!mounted) return;

    if (_ready[path] == true) {
      _controllers[path]!.play();
      _fadeController.value = 1.0;
      setState(() {});
    } else if (path != _fallbackAsset) {
      // Asset missing/failed — fall back gracefully.
      _currentPath = _fallbackAsset;
      await _showInitial(_fallbackAsset);
    }
  }

  void _preloadRemainingScenes({required String skip}) {
    final allPaths = {..._prayerVideoMap.values, _fallbackAsset};
    for (final path in allPaths) {
      if (path == skip) continue;
      // Fire-and-forget: just gets the controller initialized and cached
      // ahead of time so a later switch to this scene is instantaneous.
      _ensureController(path);
    }
  }

  @override
  void didUpdateWidget(covariant _PrayerVideoBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    final targetPath = _resolveAssetPath();
    if (targetPath != _currentPath) {
      _switchVideo(targetPath);
    }
  }

  Future<void> _switchVideo(String newPath) async {
    final oldPath = _currentPath;

    // If it's already preloaded, this resolves on the same frame and the
    // crossfade begins immediately. If it's somehow not ready yet (e.g. a
    // very fast double-tap before preload finished), we just await it —
    // still far faster than starting cold from scratch.
    await _ensureController(newPath);
    if (!mounted) return;

    if (_ready[newPath] != true) {
      if (newPath != _fallbackAsset) {
        return _switchVideo(_fallbackAsset);
      }
      return;
    }

    _previousPath = oldPath;
    _currentPath = newPath;
    _controllers[newPath]!.play();

    _fadeController.forward(from: 0.0).whenCompleteOrCancel(() {
      if (!mounted) return;
      setState(() {
        _previousPath = null;
      });
      // Pause the outgoing video once it's fully hidden — keeps it warm
      // (still initialized, ready to resume instantly) without burning
      // CPU decoding a layer nobody sees.
      if (oldPath != null && oldPath != _currentPath) {
        _controllers[oldPath]?.pause();
      }
    });

    setState(() {});
  }

  @override
  void dispose() {
    _fadeController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _buildPlayer(String? path) {
    if (path == null) return const SizedBox.expand();
    final controller = _controllers[path];
    if (controller == null ||
        _ready[path] != true ||
        !controller.value.isInitialized) {
      return const SizedBox.expand();
    }
    final videoSize = controller.value.size;
    if (videoSize.width == 0 || videoSize.height == 0) {
      return const SizedBox.expand();
    }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: videoSize.width,
        height: videoSize.height,
        child: VideoPlayer(controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF1B2A44),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Fading-out previous video layer
          if (_previousPath != null)
            FadeTransition(
              opacity: ReverseAnimation(_fadeAnimation),
              child: _buildPlayer(_previousPath),
            ),

          // Fading-in current video layer
          if (_currentPath != null)
            FadeTransition(
              opacity: _fadeAnimation,
              child: _buildPlayer(_currentPath),
            ),

          // Dynamic Atmospheric Overlay (flying birds)
          _AmbientAtmosphericOverlay(scene: widget.scene),
        ],
      ),
    );
  }
}

/// Animated atmospheric layer adding flying birds for gentle motion over
/// the video hero. (Twinkling stars were removed.)
class _AmbientAtmosphericOverlay extends StatefulWidget {
  final String? scene;
  const _AmbientAtmosphericOverlay({this.scene});

  @override
  State<_AmbientAtmosphericOverlay> createState() =>
      _AmbientAtmosphericOverlayState();
}

class _AmbientAtmosphericOverlayState extends State<_AmbientAtmosphericOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return CustomPaint(
          painter: _FlyingBirdsPainter(progress: _animController.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _FlyingBirdsPainter extends CustomPainter {
  final double progress;

  _FlyingBirdsPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final birdPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 3; i++) {
      final offsetVal = i * 0.18;
      final birdProgress = (progress + offsetVal) % 1.0;

      final x = (birdProgress * (size.width + 120)) - 60;
      final y =
          size.height * 0.18 +
          math.sin(birdProgress * math.pi * 2) * 10 +
          (i * 16);

      final flap = math.sin(progress * math.pi * 20 + (i * 2)) * 5;

      final path = Path();
      path.moveTo(x - 9, y - flap);
      path.quadraticBezierTo(x - 4, y - 3, x, y);
      path.quadraticBezierTo(x + 4, y - 3, x + 9, y - flap);

      canvas.drawPath(path, birdPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FlyingBirdsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Prayer overview summary card shown directly beneath the video hero.
///
/// Layout is modeled on the reference "Prayer Time" mockup — a date
/// header, a "Next" + "Ongoing" highlight pair, a Suhoor/Iftar row, the
/// mosque/location line, a compact 5-prayer time strip, and a
/// Sunrise/Mid Day/Sunset row — but restyled entirely with the app's own
/// navy / coral-orange / dusty-blue-teal palette (see [AppColors] and
/// splash_screen.dart) instead of the mockup's peach/orange theme.
///
/// This card is the ONLY place on the tab that lists every prayer's time
/// — the type scale used here (13 / 11 / 10.5 / 16 / 12.5 / 9.5) is the
/// reference scale the rest of the tab's cards are matched against.
class _PrayerOverviewCard extends StatelessWidget {
  final PrayerTimes prayerTimes;
  final String currentPrayer;
  final String nextPrayerName;
  final String liveCountdownStr;
  final String locationName;
  final String hijriDate;
  final DateFormat formatter;

  const _PrayerOverviewCard({
    required this.prayerTimes,
    required this.currentPrayer,
    required this.nextPrayerName,
    required this.liveCountdownStr,
    required this.locationName,
    required this.hijriDate,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final suhoorTime = formatter.format(prayerTimes.fajr);
    final iftarTime = formatter.format(prayerTimes.maghrib);
    final sunriseTime = formatter.format(prayerTimes.sunrise);
    final middayTime = formatter.format(prayerTimes.dhuhr);
    final sunsetTime = formatter.format(prayerTimes.maghrib);
    final nextPrayerTime = _timeFor(nextPrayerName);
    final currentPrayerTime = _timeFor(currentPrayer);

    final List<Map<String, String>> compactList = [
      {'name': 'Fajr', 'time': formatter.format(prayerTimes.fajr)},
      {'name': 'Dhuhr', 'time': formatter.format(prayerTimes.dhuhr)},
      {'name': 'Asr', 'time': formatter.format(prayerTimes.asr)},
      {'name': 'Maghrib', 'time': formatter.format(prayerTimes.maghrib)},
      {'name': 'Isha', 'time': formatter.format(prayerTimes.isha)},
    ];

    final bool dark = _isDark(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? Colors.black : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.14)
              : AppColors.navyBlue.withValues(alpha: 0.08),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: dark
                ? Colors.black.withValues(alpha: 0.5)
                : AppColors.navyBlue.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date header (mirrors the "7 Ramadan, 1444 / Wed, 29 March" line)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                hijriDate,
                style: GoogleFonts.poppins(
                  color: _onSurface(context),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                DateFormat('EEE, d MMM yyyy').format(DateTime.now()),
                style: GoogleFonts.inter(
                  color: _onSurface(context, alpha: 0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Two highlight cards: Next prayer (dark navy) + Ongoing prayer (light)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  height: 122,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.navyBlue, Color(0xFF23415C)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.navyBlue.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: 0,
                        bottom: -4,
                        child: Icon(
                          Icons.mosque,
                          size: 56,
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Next time',
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            nextPrayerName,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (nextPrayerTime != null) ...[
                            const SizedBox(height: 1),
                            Text(
                              nextPrayerTime,
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const Spacer(),
                          Text(
                            liveCountdownStr,
                            style: GoogleFonts.poppins(
                              color: AppColors.coralOrange,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  height: 122,
                  decoration: BoxDecoration(
                    color: dark
                        ? Colors.black
                        : AppColors.dustyBlueTeal.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: dark
                          ? Colors.white.withValues(alpha: 0.30)
                          : AppColors.dustyBlueTeal.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: 0,
                        bottom: -4,
                        child: Icon(
                          Icons.nightlight_round,
                          size: 52,
                          color: _onSurface(context, alpha: 0.1),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ongoing',
                            style: GoogleFonts.inter(
                              color: _onSurface(context, alpha: 0.65),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentPrayer,
                            style: GoogleFonts.poppins(
                              color: _onSurface(context),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (currentPrayerTime != null) ...[
                            const SizedBox(height: 1),
                            Text(
                              currentPrayerTime,
                              style: GoogleFonts.inter(
                                color: _onSurface(context, alpha: 0.6),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.coralOrange.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'In progress',
                              style: GoogleFonts.inter(
                                color: AppColors.coralOrange,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Suhoor / Iftar row
          Row(
            children: [
              Expanded(
                child: _MiniTimePill(
                  icon: Icons.wb_twilight_rounded,
                  label: 'Suhoor',
                  time: suhoorTime,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniTimePill(
                  icon: Icons.brightness_4_rounded,
                  label: 'Iftar',
                  time: iftarTime,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Location (mirrors the "Al Masjid an Nabawi" row)
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _onSurface(context, alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.mosque, color: _onSurface(context), size: 15),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  locationName,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: _onSurface(context),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          Divider(color: _onSurface(context, alpha: 0.1), height: 1),
          const SizedBox(height: 12),

          // Compact prayer times row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: compactList.map((p) {
              final bool isCurrent = p['name'] == currentPrayer;
              return Column(
                children: [
                  Text(
                    p['name']!,
                    style: GoogleFonts.inter(
                      color: isCurrent
                          ? AppColors.coralOrange
                          : _onSurface(context, alpha: 0.6),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p['time']!,
                    style: GoogleFonts.poppins(
                      color: isCurrent
                          ? _onSurface(context)
                          : _onSurface(context, alpha: 0.8),
                      fontSize: 11.5,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),

          const SizedBox(height: 14),
          Divider(color: _onSurface(context, alpha: 0.1), height: 1),
          const SizedBox(height: 12),

          // Sunrise / Mid Day / Sunset row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SunTimeItem(
                icon: Icons.wb_twilight_rounded,
                label: 'Sunrise',
                time: sunriseTime,
              ),
              _SunTimeItem(
                icon: Icons.wb_sunny_rounded,
                label: 'Mid Day',
                time: middayTime,
              ),
              _SunTimeItem(
                icon: Icons.brightness_4_rounded,
                label: 'Sunset',
                time: sunsetTime,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Formats the clock time for a given prayer name, used for the small
  /// caption under the "Next time" / "Ongoing" labels. Returns null for
  /// names that aren't one of the five salat (e.g. if 'Sunrise' is ever
  /// passed in).
  String? _timeFor(String name) {
    switch (name) {
      case 'Fajr':
        return formatter.format(prayerTimes.fajr);
      case 'Sunrise':
        return formatter.format(prayerTimes.sunrise);
      case 'Dhuhr':
        return formatter.format(prayerTimes.dhuhr);
      case 'Asr':
        return formatter.format(prayerTimes.asr);
      case 'Maghrib':
        return formatter.format(prayerTimes.maghrib);
      case 'Isha':
        return formatter.format(prayerTimes.isha);
      default:
        return null;
    }
  }
}

/// Small icon + label + time pill, used for the Suhoor/Iftar row.
class _MiniTimePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String time;

  const _MiniTimePill({
    required this.icon,
    required this.label,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _isDark(context)
            ? Colors.black
            : AppColors.navyBlue.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(14),
        border: _isDark(context)
            ? Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1)
            : null,
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _onSurface(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: _onSurface(context, alpha: 0.65),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  time,
                  style: GoogleFonts.poppins(
                    color: _onSurface(context),
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon + label + time column, used for the Sunrise / Mid Day / Sunset row.
class _SunTimeItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String time;

  const _SunTimeItem({
    required this.icon,
    required this.label,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: _onSurface(context, alpha: 0.55)),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            color: _onSurface(context, alpha: 0.6),
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          time,
          style: GoogleFonts.poppins(
            color: _onSurface(context),
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// Dynamic Vector Background for Prayer Tab hero.
/// Follows soft theme color palettes, crisp glowing mosque outlines, sun/moon positions, sparkling stars and morning birds.
class _PrayerVectorBackground extends StatefulWidget {
  final String scene;
  const _PrayerVectorBackground({required this.scene});

  @override
  State<_PrayerVectorBackground> createState() => _PrayerVectorBackgroundState();
}

class _PrayerVectorBackgroundState extends State<_PrayerVectorBackground>
    with TickerProviderStateMixin {
  late final AnimationController _animController;   // continuous pulse (glow/stars)
  late final AnimationController _transitionCtrl;   // 0→1 on scene change for sun/moon glide
  String _prevScene = '';

  @override
  void initState() {
    super.initState();
    _prevScene = widget.scene;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _transitionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      value: 1.0, // starts complete — no animation on first render
    );
  }

  @override
  void didUpdateWidget(_PrayerVectorBackground old) {
    super.didUpdateWidget(old);
    if (old.scene != widget.scene) {
      _prevScene = old.scene;          // save where we came from
      _transitionCtrl.forward(from: 0); // animate 0→1
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _transitionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = _VectorThemeSpec.getForScene(widget.scene);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 900),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: spec.skyGradient,
        ),
      ),
      child: AnimatedBuilder(
        animation: Listenable.merge([_animController, _transitionCtrl]),
        builder: (context, _) {
          return CustomPaint(
            painter: _PrayerTabVectorArtPainter(
              scene: widget.scene,
              prevScene: _prevScene,
              transitionValue: CurveTween(curve: Curves.easeInOutCubic)
                  .evaluate(_transitionCtrl),
              animValue: _animController.value,
              spec: spec,
            ),
          );
        },
      ),
    );
  }
}

class _VectorThemeSpec {
  final List<Color> skyGradient;
  final Color bodyColor;
  final Color domeAccentColor;
  final Color sideDomeColor; // separate color for left/right domes (e.g. navy for Dhuhr)
  final Color windowColor;

  const _VectorThemeSpec({
    required this.skyGradient,
    required this.bodyColor,
    required this.domeAccentColor,
    Color? sideDomeColor,
    required this.windowColor,
  }) : sideDomeColor = sideDomeColor ?? domeAccentColor;

  static _VectorThemeSpec getForScene(String scene) {
    final s = scene.toLowerCase();
    if (s.contains('fajr')) {
      return const _VectorThemeSpec(
        skyGradient: [Color(0xFF2E2440), Color(0xFF5A4468), Color(0xFF9E7185), Color(0xFFF3BD9E)],
        bodyColor: Color(0xFFE2D6EE), // Soft Lavender Cream
        domeAccentColor: Color(0xFFC8A5C6), // Soft Dusk Rose
        windowColor: Color(0xFF8B678A), // Soft Deep Plum
      );
    } else if (s.contains('sunrise')) {
      return const _VectorThemeSpec(
        skyGradient: [Color(0xFF385E7E), Color(0xFF6F9FB8), Color(0xFFEBA87E), Color(0xFFFDE4C3)],
        bodyColor: Color(0xFFFDE8D7), // Soft Peach Cream
        domeAccentColor: Color(0xFFF4B8A5), // Soft Terracotta Coral
        windowColor: Color(0xFFC48677), // Warm Rose Bronze
      );
    } else if (s.contains('dhuhr') || s.contains('zuhr')) {
      return const _VectorThemeSpec(
        skyGradient: [Color(0xFF3B82F6), Color(0xFF60A5FA), Color(0xFF93C5FD), Color(0xFFE0F2FE)],
        bodyColor: Color(0xFFFFFFFF),         // Pure White Body
        domeAccentColor: Color(0xFF459490),   // Mid Teal — center dome
        sideDomeColor: Color(0xFF1A2E40),      // Navy Blue — left & right side domes
        windowColor: Color(0xFF1A2E40),        // Deep Navy Door & Windows
      );
    } else if (s.contains('asr')) {
      return const _VectorThemeSpec(
        skyGradient: [Color(0xFF4A76A8), Color(0xFFC78B45), Color(0xFFF5B05E), Color(0xFFFEF0C7)],
        bodyColor: Color(0xFFFEF3E2), // Warm Cream Ivory Body
        domeAccentColor: Color(0xFFECC488), // Soft Golden Caramel Domes
        windowColor: Color(0xFFB88243), // Warm Amber Bronze Door & Windows
      );
    } else if (s.contains('maghrib')) {
      return const _VectorThemeSpec(
        skyGradient: [Color(0xFF512B58), Color(0xFF9D446E), Color(0xFFED736A), Color(0xFFFDD5A5)],
        bodyColor: Color(0xFFFBE4E8), // Soft Sunset Rose Cream Body
        domeAccentColor: Color(0xFFE0A0B0), // Soft Sunset Berry Domes
        windowColor: Color(0xFF8C4257), // Deep Sunset Ruby Door & Windows
      );
    } else {
      // Isha / Night
      return const _VectorThemeSpec(
        skyGradient: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155), Color(0xFF475569)],
        bodyColor: Color(0xFFE0F2FE), // Soft Moonlit Ice Blue Body
        domeAccentColor: Color(0xFF94A3B8), // Soft Periwinkle Slate Domes
        windowColor: Color(0xFF334155), // Midnight Indigo Door & Windows
      );
    }
  }
}

// Returns the fractional (dx, dy) position of the sun/moon for a given scene.
// These are relative to canvas width/height and used for smooth interpolation.
// Dhuhr is a special case: position is anchored above the mosque — handled in paint().
Offset _celestialFraction(String scene) {
  final s = scene.toLowerCase();
  if (s.contains('fajr'))    return const Offset(0.22, 0.22);  // crescent top-left
  if (s.contains('sunrise')) return const Offset(0.22, 0.38);  // rising sun low-left
  if (s.contains('dhuhr') || s.contains('zuhr')) return const Offset(0.50, 0.12); // placeholder — overridden in paint
  if (s.contains('asr'))     return const Offset(0.64, 0.26);  // midway between zuhr & maghrib
  if (s.contains('maghrib')) return const Offset(0.80, 0.42);  // dipping sun low-right
  return const Offset(0.78, 0.22); // isha crescent
}

class _PrayerTabVectorArtPainter extends CustomPainter {
  final String scene;
  final String prevScene;
  final double transitionValue; // 0 = prev scene position, 1 = current scene position
  final double animValue;
  final _VectorThemeSpec spec;

  _PrayerTabVectorArtPainter({
    required this.scene,
    required this.prevScene,
    required this.transitionValue,
    required this.animValue,
    required this.spec,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final s = scene.toLowerCase();
    final double pulse = math.sin(animValue * 2 * math.pi);

    final bool isFajr = s.contains('fajr');
    final bool isSunrise = s.contains('sunrise');
    final bool isDhuhr = s.contains('dhuhr') || s.contains('zuhr');
    final bool isAsr = s.contains('asr');
    final bool isMaghrib = s.contains('maghrib');
    final bool isIsha = s.contains('isha');

    const double equalSunRadius = 24.0;

    // Mosque geometry — used to anchor the Dhuhr sun above the spire
    const double mosqueWidthFrac = 0.96;
    const double mosqueHeightFrac = 0.54;
    final double mosqueRight = w * 0.99;
    final double mosqueWidth = w * mosqueWidthFrac;
    final double mosqueHeight = h * mosqueHeightFrac;
    final double by = h;
    final double mCx = mosqueRight - mosqueWidth / 2;
    final double centerDomeTopY = by - mosqueHeight * 0.35 - mosqueHeight * 0.55;
    final double spireTopY = centerDomeTopY - 18;
    // Dhuhr sun: close above the spire, but not too far (won't go off screen)
    final Offset dhuhrSunPos = Offset(mCx, spireTopY - equalSunRadius - 6);

    // Compute interpolated celestial position (smooth scene transition)
    Offset resolvePos(String sc) {
      final frac = _celestialFraction(sc);
      if ((sc.contains('dhuhr') || sc.contains('zuhr'))) return dhuhrSunPos;
      return Offset(w * frac.dx, h * frac.dy);
    }
    final Offset fromPos = resolvePos(prevScene);
    final Offset toPos   = resolvePos(scene);
    // Lerp with ease curve already applied via transitionValue
    final Offset celestialPos = Offset.lerp(fromPos, toPos, transitionValue)!;

    // 1. Celestial Objects
    if (isFajr) {
      _drawCrescentMoon(canvas, celestialPos, 18, Colors.white.withValues(alpha: 0.92));
      _drawSparklingStars(canvas, [
        Offset(w * 0.12, h * 0.12),
        Offset(w * 0.38, h * 0.16),
        Offset(w * 0.55, h * 0.10),
        Offset(w * 0.75, h * 0.20),
        Offset(w * 0.88, h * 0.14),
      ], pulse);
    } else if (isSunrise) {
      _drawSun(canvas, celestialPos, equalSunRadius, const Color(0xFFFFF3E0), pulse);
    } else if (isDhuhr) {
      _drawSun(canvas, celestialPos, equalSunRadius, const Color(0xFFFFFDE7), pulse);
    } else if (isAsr) {
      _drawSun(canvas, celestialPos, equalSunRadius, const Color(0xFFFFF8E1), pulse);
    } else if (isMaghrib) {
      _drawSun(canvas, celestialPos, equalSunRadius, const Color(0xFFFFE0E6), pulse);
    } else if (isIsha) {
      _drawCrescentMoon(canvas, celestialPos, 20, Colors.white.withValues(alpha: 0.95));
      _drawSparklingStars(canvas, [
        Offset(w * 0.15, h * 0.15),
        Offset(w * 0.32, h * 0.22),
        Offset(w * 0.48, h * 0.10),
        Offset(w * 0.62, h * 0.28),
        Offset(w * 0.82, h * 0.12),
        Offset(w * 0.25, h * 0.35),
      ], pulse);
    }

    // 2. Draw Mosque Silhouette
    _drawMosqueSilhouettes(canvas, w, h, spec, pulse);
  }

  void _drawCrescentMoon(Canvas canvas, Offset center, double radius, Color moonColor) {
    // 1. Glowing outer aura
    final glowPaint = Paint()
      ..color = moonColor.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawCircle(center, radius + 6, glowPaint);

    // 2. True crescent path (difference between 2 ovals)
    final outerPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));

    final innerPath = Path()
      ..addOval(Rect.fromCircle(
        center: Offset(center.dx + radius * 0.48, center.dy - radius * 0.25),
        radius: radius * 0.85,
      ));

    final crescentPath = Path.combine(PathOperation.difference, outerPath, innerPath);

    final moonPaint = Paint()
      ..color = moonColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(crescentPath, moonPaint);
  }

  void _drawSun(Canvas canvas, Offset center, double radius, Color sunColor, double pulse) {
    // 1. Wide outer radiant glow halo (animates/pulses gently!)
    final outerGlowPaint = Paint()
      ..color = sunColor.withValues(alpha: 0.30 + 0.12 * pulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 32);
    canvas.drawCircle(center, radius * 2.4, outerGlowPaint);

    // 2. Inner radiant aura
    final innerAuraPaint = Paint()
      ..color = sunColor.withValues(alpha: 0.60 + 0.15 * pulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawCircle(center, radius * 1.4, innerAuraPaint);

    // 3. Crisp Sun Core
    final corePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, corePaint);

    final sunBodyPaint = Paint()
      ..color = sunColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.88, sunBodyPaint);
  }

  void _drawSparklingStars(Canvas canvas, List<Offset> locations, double pulse) {
    for (int i = 0; i < locations.length; i++) {
      final loc = locations[i];
      final alpha = 0.35 + 0.45 * math.sin(pulse * math.pi + i * 1.2);
      final starPaint = Paint()
        ..color = Colors.white.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;

      final path = Path();
      final cx = loc.dx;
      final cy = loc.dy;
      final r = 3.5;

      path.moveTo(cx, cy - r);
      path.quadraticBezierTo(cx, cy, cx + r, cy);
      path.quadraticBezierTo(cx, cy, cx, cy + r);
      path.quadraticBezierTo(cx, cy, cx - r, cy);
      path.quadraticBezierTo(cx, cy, cx, cy - r);
      path.close();

      canvas.drawPath(path, starPaint);
    }
  }

  void _drawMosqueSilhouettes(Canvas canvas, double w, double h, _VectorThemeSpec spec, double pulse) {
    final bodyPaint = Paint()
      ..color = spec.bodyColor
      ..style = PaintingStyle.fill;

    final domePaint = Paint()
      ..color = spec.domeAccentColor
      ..style = PaintingStyle.fill;

    final windowPaint = Paint()
      ..color = spec.windowColor
      ..style = PaintingStyle.fill;

    // Outline: very subtle white glow (tiny blur sigma=2) + thin stroke
    final outlineGlowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    final outlinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final double mosqueRight = w * 0.99;
    final double mosqueWidth = w * 0.96; // wider
    final double mosqueHeight = h * 0.54;
    final double by = h;
    final double cx = mosqueRight - mosqueWidth / 2;

    void drawOutlined(Path path) {
      canvas.drawPath(path, outlineGlowPaint);
      canvas.drawPath(path, outlinePaint);
    }

    // 1. Draw Side Domes — use spec.sideDomeColor (navy for Dhuhr, accent for others)
    final sideDomePaint = Paint()
      ..color = spec.sideDomeColor
      ..style = PaintingStyle.fill;
    _drawOnionDomeFillWithOutline(canvas, cx - mosqueWidth * 0.26, by - mosqueHeight * 0.35,
        mosqueWidth * 0.20, mosqueHeight * 0.32, sideDomePaint, outlineGlowPaint, outlinePaint);
    _drawOnionDomeFillWithOutline(canvas, cx + mosqueWidth * 0.26, by - mosqueHeight * 0.35,
        mosqueWidth * 0.20, mosqueHeight * 0.32, sideDomePaint, outlineGlowPaint, outlinePaint);

    // 2. Draw Center Onion Dome
    final centerDomeW = mosqueWidth * 0.38;
    final centerDomeH = mosqueHeight * 0.55;
    final centerDomeY = by - mosqueHeight * 0.35;
    _drawOnionDomeFillWithOutline(canvas, cx, centerDomeY, centerDomeW, centerDomeH,
        domePaint, outlineGlowPaint, outlinePaint);

    // Spire on center dome
    final spireTopY = centerDomeY - centerDomeH;
    canvas.drawLine(Offset(cx, spireTopY), Offset(cx, spireTopY - 18), outlineGlowPaint);
    canvas.drawLine(Offset(cx, spireTopY), Offset(cx, spireTopY - 18), outlinePaint);
    canvas.drawCircle(Offset(cx, spireTopY - 18), 3.2, windowPaint);

    // 3. Draw Connective Base Walls
    final wallPath = Path()
      ..moveTo(cx - mosqueWidth * 0.44, by)
      ..lineTo(cx - mosqueWidth * 0.44, by - mosqueHeight * 0.38)
      ..lineTo(cx + mosqueWidth * 0.44, by - mosqueHeight * 0.38)
      ..lineTo(cx + mosqueWidth * 0.44, by)
      ..close();
    canvas.drawPath(wallPath, bodyPaint);
    drawOutlined(wallPath);

    // 4. Draw Minarets
    _drawMinaretFills(canvas, cx - mosqueWidth * 0.42, by,
        mosqueWidth * 0.08, mosqueHeight * 0.88,
        bodyPaint, domePaint, windowPaint, outlineGlowPaint, outlinePaint);
    _drawMinaretFills(canvas, cx + mosqueWidth * 0.42, by,
        mosqueWidth * 0.08, mosqueHeight * 0.88,
        bodyPaint, domePaint, windowPaint, outlineGlowPaint, outlinePaint);

    // 5. Central Arched Door ONLY
    final doorW = mosqueWidth * 0.16;
    final doorH = mosqueHeight * 0.28;
    final doorPath = Path()
      ..moveTo(cx - doorW / 2, by)
      ..lineTo(cx - doorW / 2, by - doorH * 0.65)
      ..quadraticBezierTo(cx, by - doorH, cx + doorW / 2, by - doorH * 0.65)
      ..lineTo(cx + doorW / 2, by)
      ..close();
    canvas.drawPath(doorPath, windowPaint);
    drawOutlined(doorPath);
  }

  Path _buildOnionDomePath(double cx, double by, double width, double height) {
    final path = Path();
    final double w2 = width / 2;
    final double bulge = width * 0.09;
    path.moveTo(cx - w2, by);
    path.cubicTo(
      cx - w2 - bulge, by - height * 0.35,
      cx - w2 + bulge * 0.2, by - height * 0.75,
      cx, by - height,
    );
    path.cubicTo(
      cx + w2 - bulge * 0.2, by - height * 0.75,
      cx + w2 + bulge, by - height * 0.35,
      cx + w2, by,
    );
    path.close();
    return path;
  }

  void _drawOnionDomeFillWithOutline(
    Canvas canvas,
    double cx, double by, double width, double height,
    Paint fillPaint, Paint outlineGlowPaint, Paint outlinePaint,
  ) {
    final path = _buildOnionDomePath(cx, by, width, height);
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, outlineGlowPaint);
    canvas.drawPath(path, outlinePaint);
  }

  void _drawMinaretFills(
    Canvas canvas,
    double cx, double by, double width, double height,
    Paint bodyPaint, Paint domePaint, Paint windowPaint,
    Paint outlineGlowPaint, Paint outlinePaint,
  ) {
    final double colW = width * 0.65;
    final double balconyW = width * 1.25;

    void outlineRect(Rect r) {
      canvas.drawRect(r, outlineGlowPaint);
      canvas.drawRect(r, outlinePaint);
    }

    // Column body
    final colRect = Rect.fromLTRB(cx - colW / 2, by - height, cx + colW / 2, by);
    canvas.drawRect(colRect, bodyPaint);
    outlineRect(colRect);

    // Lower Balcony
    final b1Rect = Rect.fromLTRB(cx - balconyW / 2, by - height * 0.75, cx + balconyW / 2, by - height * 0.71);
    canvas.drawRect(b1Rect, windowPaint);
    outlineRect(b1Rect);

    // Upper Balcony
    final b2Rect = Rect.fromLTRB(cx - balconyW / 2, by - height - 4, cx + balconyW / 2, by - height);
    canvas.drawRect(b2Rect, windowPaint);
    outlineRect(b2Rect);

    // Onion Dome Cap
    _drawOnionDomeFillWithOutline(canvas, cx, by - height - 4,
        width * 0.75, height * 0.16, domePaint, outlineGlowPaint, outlinePaint);
  }

  // _drawArchedWindow removed — side windows removed per user request

  @override
  bool shouldRepaint(covariant _PrayerTabVectorArtPainter old) =>
      old.scene != scene ||
      old.prevScene != prevScene ||
      old.transitionValue != transitionValue ||
      old.animValue != animValue;
}
