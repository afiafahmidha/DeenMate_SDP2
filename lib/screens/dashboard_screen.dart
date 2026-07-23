import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart';
import '../widgets/auth_header.dart'; // To access AppColors and AppLogo
import '../services/notification_service.dart'; // Real prayer alarm notifications
import 'calendar_tab.dart';
import 'hajj_umrah_screen.dart';
import 'inheritance_screen.dart';
import 'qurbani_planner_screen.dart';
import 'assistant_tab.dart';
import 'zakat_manager_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'emergency_sos_screen.dart';
import 'dhikr_counter_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const DashboardScreen({super.key, required this.onLogout});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0; // Bottom navigation tab


  // Animation controllers
  late AnimationController _staggerController;
  late AnimationController _pulseController;
  late AnimationController _floatController;
  late AnimationController _cloudsController; // Controller for floating clouds inside the card

  // Location & Time tracking state
  String _locationName = "Dhaka, Bangladesh";
  double _latitude = 23.8103;
  double _longitude = 90.4125;
  String _nextPrayerName = "Asr";
  String _nextPrayerTimeStr = "4:32 PM";
  String _countdownStr = "1h 12m"; // Safe countdown string for the home page card (prevents splitting errors!)
  String _liveCountdownStr = "00:00:00"; // Exact ticking countdown formatted as HH:mm:ss for prayer tab
  Timer? _realTimeTimer;

  // Selected prayer scene for dynamic prayer tab header
  String _selectedPrayerScene = "Asr";

  // Qaza counter — incremented when a past prayer is missed (not ticked)
  int _qazaCount = 0;

  // Qaza prayer counter state (manually managed + saved via SharedPreferences)
  final Map<String, int> _qazaCounts = {
    'Fajr': 0,
    'Dhuhr': 0,
    'Asr': 0,
    'Maghrib': 0,
    'Isha': 0,
  };

  // Active alarms map for prayer list on Prayer page (all off by default; user toggles)
  final Map<String, bool> _prayerAlarms = {
    'Fajr': false,
    'Sunrise': false,
    'Dhuhr': false,
    'Asr': false,
    'Maghrib': false,
    'Isha': false,
  };

  // Daily salat completion checklist states
  final Map<String, bool> _salatCompleted = {
    'Fajr': false,
    'Dhuhr': false,
    'Asr': false,
    'Maghrib': false,
    'Isha': false,
  };



  // In-app alarm overlay (shown when prayer time strikes while app is open)
  bool _showAlarmOverlay = false;
  String _alarmPrayerName = '';
  final Set<String> _triggeredAlarms = {}; // tracks alarms fired this session

  // Cached today's prayer DateTimes for alarm scheduling
  DateTime? _fajrTime, _sunriseTime, _dhuhrTime, _asrTime, _maghribTime, _ishaTime;


  // Stars configuration for dashboard background
  final List<_DashboardStarConfig> _stars = [
    _DashboardStarConfig(topFraction: 0.02, leftFraction: 0.08, size: 5, delayMs: 200),
    _DashboardStarConfig(topFraction: 0.05, leftFraction: 0.85, size: 7, delayMs: 500),
    _DashboardStarConfig(topFraction: 0.12, leftFraction: 0.45, size: 4, delayMs: 800),
    _DashboardStarConfig(topFraction: 0.08, leftFraction: 0.72, size: 6, delayMs: 300),
    _DashboardStarConfig(topFraction: 0.15, leftFraction: 0.15, size: 5, delayMs: 600),
    _DashboardStarConfig(topFraction: 0.18, leftFraction: 0.92, size: 4, delayMs: 100),
    _DashboardStarConfig(topFraction: 0.25, leftFraction: 0.55, size: 6, delayMs: 700),
    _DashboardStarConfig(topFraction: 0.32, leftFraction: 0.05, size: 4, delayMs: 400),
    _DashboardStarConfig(topFraction: 0.38, leftFraction: 0.78, size: 5, delayMs: 900),
    _DashboardStarConfig(topFraction: 0.45, leftFraction: 0.30, size: 4, delayMs: 150),
    _DashboardStarConfig(topFraction: 0.55, leftFraction: 0.88, size: 6, delayMs: 450),
    _DashboardStarConfig(topFraction: 0.62, leftFraction: 0.12, size: 4, delayMs: 750),
    _DashboardStarConfig(topFraction: 0.70, leftFraction: 0.65, size: 5, delayMs: 350),
    _DashboardStarConfig(topFraction: 0.78, leftFraction: 0.40, size: 4, delayMs: 550),
  ];
  
  

  // Load manual Qaza counts from SharedPreferences
  Future<void> _loadQazaCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final prayer in _qazaCounts.keys) {
        final val = prefs.getInt('qaza_$prayer') ?? 0;
        setState(() {
          _qazaCounts[prayer] = val;
        });
      }
    } catch (e) {
      debugPrint('Error loading qaza counts: $e');
    }
  }

  // Save manual Qaza count for a specific prayer
  Future<void> _saveQazaCount(String prayer, int val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('qaza_$prayer', val);
    } catch (e) {
      debugPrint('Error saving qaza count: $e');
    }
  }

  // Automatically log a missed prayer as Qaza
  Future<void> _autoLogQaza(String prayer, String logKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(logKey) ?? false)) {
        await prefs.setBool(logKey, true);
        final currentCount = _qazaCounts[prayer] ?? 0;
        final newCount = currentCount + 1;
        setState(() {
          _qazaCounts[prayer] = newCount;
        });
        await _saveQazaCount(prayer, newCount);
      }
    } catch (e) {
      debugPrint('Error auto-logging qaza count: $e');
    }
  }

  // Load daily salat completion status from SharedPreferences
  Future<void> _loadSalatCompleted() async {
    try {
      final now = DateTime.now();
      final ymd = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final prefs = await SharedPreferences.getInstance();
      for (final salat in _salatCompleted.keys) {
        final val = prefs.getBool('completed_${ymd}_$salat') ?? false;
        setState(() {
          _salatCompleted[salat] = val;
        });
      }
    } catch (e) {
      debugPrint('Error loading salat completion: $e');
    }
  }

  // Save daily salat completion status to SharedPreferences
  Future<void> _saveSalatCompleted(String salat, bool val) async {
    try {
      final now = DateTime.now();
      final ymd = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('completed_${ymd}_$salat', val);
    } catch (e) {
      debugPrint('Error saving salat completion: $e');
    }
  }

  // Load alarm toggle states from SharedPreferences
  Future<void> _loadAlarmStates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final prayer in _prayerAlarms.keys) {
        // Default to false if never set (user picks their own alarms)
        final val = prefs.getBool('alarm_$prayer') ?? false;
        setState(() {
          _prayerAlarms[prayer] = val;
        });
      }
      // After loading states, sync actual scheduled notifications
      _syncAlarms();
    } catch (e) {
      debugPrint('Error loading alarm states: $e');
    }
  }

  // Save a single alarm toggle state to SharedPreferences
  Future<void> _saveAlarmState(String prayer, bool val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('alarm_$prayer', val);
    } catch (e) {
      debugPrint('Error saving alarm state: $e');
    }
  }

  @override
  void initState() {
    super.initState();

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _cloudsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 30000), // slow drift
    )..repeat();


    // Load saved Qaza counts
    _loadQazaCounts();
    // Load daily checklist status
    _loadSalatCompleted();
    // Load user alarm preferences
    _loadAlarmStates();

    // Start location services & prayer time updates
    _initLocationAndTracking();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _pulseController.dispose();
    _floatController.dispose();
    _cloudsController.dispose();
    _realTimeTimer?.cancel();
    super.dispose();
  }

  // ===== LOCATION & TRACKING INITIALIZATION =====
  Future<void> _initLocationAndTracking() async {
    // 1. Initial calculation using default coordinates (Dhaka)
    _updatePrayerTimes();

    // 2. Determine GPS Location of the device
    try {
      final Position? position = await _determinePosition();
      if (position != null) {
        if (mounted) {
          setState(() {
            _latitude = position.latitude;
            _longitude = position.longitude;
          });
        }

        // Reverse geocoding to get City name
        try {
          final geocoding = Geocoding();
          final List<Placemark> placemarks =
              await geocoding.placemarkFromCoordinates(position.latitude, position.longitude);
          if (placemarks.isNotEmpty && mounted) {
            final pm = placemarks.first;
            final city = pm.locality ?? pm.subAdministrativeArea ?? pm.administrativeArea ?? "My Location";
            final country = pm.country ?? "";
            setState(() {
              _locationName = country.isNotEmpty ? "$city, $country" : city;
            });
          }
        } catch (e) {
          debugPrint("Failed to get address from coordinates: $e");
        }

        // Recalculate prayer times for the new position
        _updatePrayerTimes();
        // Sync real system notifications now that we have accurate prayer times
        _syncAlarms();
      }
    } catch (e) {
      debugPrint("Failed to get location: $e");
    }

    // 3. Periodic timer to update countdown & time every 1 second (essential for live ticking clock!)
    _realTimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _updatePrayerTimes();
      }
    });
  }

  // Request & check GPS position permission
  Future<Position?> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 8),
      ),
    );
  }

  // Calculate actual prayer times based on current date, coordinates & timezone
  void _updatePrayerTimes() {
    final coordinates = Coordinates(_latitude, _longitude);
    final params = CalculationMethod.karachi.getParameters();
    params.madhab = Madhab.hanafi;

    final prayerTimes = PrayerTimes.today(coordinates, params);

    // Cache today's prayer DateTimes so alarm scheduling can use them
    _fajrTime    = prayerTimes.fajr;
    _sunriseTime = prayerTimes.sunrise;
    _dhuhrTime   = prayerTimes.dhuhr;
    _asrTime     = prayerTimes.asr;
    _maghribTime = prayerTimes.maghrib;
    _ishaTime    = prayerTimes.isha;

    // === In-app alarm overlay trigger ===
    // Fire overlay when prayer time is within the current second AND alarm is enabled
    final now = DateTime.now();
    final Map<String, DateTime?> allTimes = {
      'Fajr': _fajrTime,
      'Sunrise': _sunriseTime,
      'Dhuhr': _dhuhrTime,
      'Asr': _asrTime,
      'Maghrib': _maghribTime,
      'Isha': _ishaTime,
    };
    for (final entry in allTimes.entries) {
      final pName = entry.key;
      final pTime = entry.value;
      if (pTime == null) continue;
      final alarmEnabled = _prayerAlarms[pName] ?? false;
      if (!alarmEnabled) continue;
      final diffSec = now.difference(pTime).inSeconds.abs();
      final alarmKey = '${pName}_${pTime.day}_${pTime.hour}_${pTime.minute}';
      // Trigger overlay within a 30-second window of the prayer time
      if (diffSec <= 30 && !_triggeredAlarms.contains(alarmKey)) {
        _triggeredAlarms.add(alarmKey);
        if (mounted) {
          setState(() {
            _alarmPrayerName = pName;
            _showAlarmOverlay = true;
          });
          // Auto-dismiss overlay after 60 seconds
          Future.delayed(const Duration(seconds: 60), () {
            if (mounted && _alarmPrayerName == pName) {
              setState(() => _showAlarmOverlay = false);
            }
          });
        }
      }
    }

    // === Auto Qaza Calculation ===
    // If a fard prayer time has passed today, is unchecked, and hasn't been auto-logged yet for today,
    // automatically increment its persistent Qaza count.
    final ymd = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final List<String> fardPrayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    for (final sName in fardPrayers) {
      final sTime = allTimes[sName];
      if (sTime == null) continue;
      final bool isPast = now.isAfter(sTime);
      final bool isDone = _salatCompleted[sName] ?? false;
      if (isPast && !isDone) {
        final logKey = 'auto_qaza_logged_${ymd}_$sName';
        if (!_triggeredAlarms.contains(logKey)) {
          _triggeredAlarms.add(logKey);
          _autoLogQaza(sName, logKey);
        }
      }
    }

    // Identify current and next prayers
    final next = prayerTimes.nextPrayer();

    String nextName = "Fajr";
    DateTime nextTime = prayerTimes.fajr;

    switch (next) {
      case Prayer.fajr:
        nextName = "Fajr";
        nextTime = prayerTimes.fajr;
        break;
      case Prayer.sunrise:
        nextName = "Dhuhr";
        nextTime = prayerTimes.dhuhr;
        break;
      case Prayer.dhuhr:
        nextName = "Dhuhr";
        nextTime = prayerTimes.dhuhr;
        break;
      case Prayer.asr:
        nextName = "Asr";
        nextTime = prayerTimes.asr;
        break;
      case Prayer.maghrib:
        nextName = "Maghrib";
        nextTime = prayerTimes.maghrib;
        break;
      case Prayer.isha:
        nextName = "Isha";
        nextTime = prayerTimes.isha;
        break;
      case Prayer.none:
        // If it is after Isha, the next prayer is tomorrow's Fajr
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        final tomorrowPrayerTimes = PrayerTimes(
          coordinates,
          DateComponents.from(tomorrow),
          params,
        );
        nextName = "Fajr";
        nextTime = tomorrowPrayerTimes.fajr;
        break;
    }

    // Format times and calculate countdown
    final formatter = DateFormat('h:mm a');
    final String timeStr = formatter.format(nextTime);

    final durationLeft = nextTime.difference(DateTime.now());
    String countdown;
    String liveCountdown;
    if (durationLeft.isNegative) {
      countdown = "any moment";
      liveCountdown = "00:00:00";
    } else {
      final hours = durationLeft.inHours;
      final minutes = durationLeft.inMinutes % 60;
      final seconds = durationLeft.inSeconds % 60;
      if (hours > 0) {
        countdown = "${hours}h ${minutes}m";
      } else {
        countdown = "${minutes}m";
      }
      final hStr = hours.toString().padLeft(2, '0');
      final mStr = minutes.toString().padLeft(2, '0');
      final sStr = seconds.toString().padLeft(2, '0');
      liveCountdown = "$hStr:$mStr:$sStr";
    }

    if (mounted) {
      setState(() {
        _nextPrayerName = nextName;
        _nextPrayerTimeStr = timeStr;
        _countdownStr = countdown;
        _liveCountdownStr = liveCountdown;
      });
    }
  }

  // Schedule or cancel system notifications for all prayers based on toggle states
  Future<void> _syncAlarms() async {
    final Map<String, DateTime?> allTimes = {
      'Fajr': _fajrTime,
      'Sunrise': _sunriseTime,
      'Dhuhr': _dhuhrTime,
      'Asr': _asrTime,
      'Maghrib': _maghribTime,
      'Isha': _ishaTime,
    };
    for (final entry in allTimes.entries) {
      final pName = entry.key;
      final pTime = entry.value;
      final isEnabled = _prayerAlarms[pName] ?? false;
      if (isEnabled && pTime != null) {
        await NotificationService.instance.schedulePrayerAlarm(
          prayerName: pName,
          scheduledTime: pTime,
        );
      } else {
        await NotificationService.instance.cancelPrayerAlarm(pName);
      }
    }
  }

  // Calculate approximate Hijri date string based on current Gregorian date
  String _getHijriDateString() {
    final today = DateTime.now();
    final hijriMonths = [
      "Muharram", "Safar", "Rabi' al-Awwal", "Rabi' ath-Thani",
      "Jumada al-Ula", "Jumada al-Akhirah", "Rajab", "Sha'ban",
      "Ramadan", "Shawwal", "Dhu al-Qa'dah", "Dhu al-Hijjah"
    ];
    // Custom mapping for realistic demonstration of Hijri year 1448 AH in 2026 AD
    int monthIndex = (today.month + 3) % 12;
    int day = (today.day + 12) % 29 + 1;
    int year = today.year - 578; // 2026 - 578 = 1448
    return "$day ${hijriMonths[monthIndex]}, $year AH";
  }

  // Identifies which prayer is current so it can be highlighted
  String _getCurrentPrayerName() {
    final coordinates = Coordinates(_latitude, _longitude);
    final params = CalculationMethod.karachi.getParameters();
    params.madhab = Madhab.hanafi;
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
    final Size size = MediaQuery.of(context).size;
    final double maxAppWidth = 430.0;
    final double appWidth = math.min(size.width, maxAppWidth);

    return PopScope(
      canPop: false, // Prevent accidental back navigation that causes red error
      child: Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Container(
          width: appWidth,
          height: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            color: Colors.white,
          ),
          child: Stack(
            children: [
              // VERY VERY VERY SMALL geometric watermark texture background covering the entire page
              Positioned.fill(
                child: CustomPaint(
                  painter: _DashboardTexturePainter(),
                ),
              ),

              // Sparkling twinkling stars scattered across the background sky
              ..._stars.map((star) {
                return _DashboardTwinklingStar(
                  topFraction: star.topFraction,
                  leftFraction: star.leftFraction,
                  size: star.size,
                  delayMs: star.delayMs,
                );
              }),

              // Main content area with Smooth Slide and Fade Tab Transition
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 70 + MediaQuery.of(context).padding.bottom),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    switchInCurve: Curves.easeInOutCubic,
                    switchOutCurve: Curves.easeInOutCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.03, 0.0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: _buildActiveTabContent(),
                  ),
                ),
              ),

              // Bottom Navigation Bar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomNavigationBar(),
              ),

              // ===== IN-APP PRAYER ALARM OVERLAY =====
              if (_showAlarmOverlay)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => setState(() => _showAlarmOverlay = false),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.55),
                      child: Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 28),
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.navyBlue.withValues(alpha: 0.18),
                                blurRadius: 40,
                                offset: const Offset(0, 12),
                              )
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Mosque icon
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: AppColors.navyBlue.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.mosque_rounded,
                                  size: 38,
                                  color: AppColors.navyBlue,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Prayer Time',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 13,
                                  letterSpacing: 3,
                                  color: AppColors.navyBlue.withValues(alpha: 0.5),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _alarmPrayerName,
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.navyBlue,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'الله أكبر • الله أكبر',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  color: AppColors.navyBlue.withValues(alpha: 0.7),
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'It is time for $_alarmPrayerName prayer.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppColors.navyBlue.withValues(alpha: 0.55),
                                ),
                              ),
                              const SizedBox(height: 28),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => setState(() => _showAlarmOverlay = false),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.navyBlue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    'Dismiss',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ), // PopScope closing parenthesis
    );
  }

  // ===== BOTTOM NAVIGATION BAR =====
  Widget _buildBottomNavigationBar() {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.navyBlue.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        height: 70,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.home_rounded, 'Home'),
            _buildNavItem(1, Icons.access_time_rounded, 'Prayer'),
            _buildNavItem(2, Icons.calendar_month_rounded, 'Calendar'),
            _buildNavItem(3, Icons.auto_awesome_rounded, 'Assistant'),
            _buildNavItem(4, Icons.person_outline_rounded, 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final bool isSelected = _currentIndex == index;
    final Color activeColor = AppColors.navyBlue;

    return GestureDetector(
      onTap: () => setState(() {
        _currentIndex = index;
        if (index == 1) {
          // Sync default prayer tab scene with the current next prayer
          _selectedPrayerScene = _nextPrayerName;
        }
      }),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.dustyBlueTeal.withValues(alpha: 0.25)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                color: isSelected ? activeColor : AppColors.placeholder,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : AppColors.placeholder,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== ZAKAT NAVIGATION =====
  void _showZakatCalculatorSheet() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ZakatManagerScreen(),
      ),
    );
  }

  // ===== ACTIVE TAB CONTENT DISPATCHER =====
Widget _buildActiveTabContent() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _buildPrayerTab();
      case 2:
        return CalendarTab(
          key: const ValueKey('CalendarTab'),
          onOpenZakatCalculator: _showZakatCalculatorSheet,
        );
      case 3:
        return const AssistantTab();
      default:
        return _buildPlaceholderTab();
    }
  }
  // ===== HOME TAB (Main Dashboard) =====
  Widget _buildHomeTab() {
    return SingleChildScrollView(
      key: const ValueKey('HomeTab'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 50, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting Header
          _buildAnimatedEntry(
            delay: 0.0,
            child: _buildGreetingHeader(),
          ),
          const SizedBox(height: 20),

          // Next Prayer Card
          _buildAnimatedEntry(
            delay: 0.1,
            child: _buildNextPrayerCard(),
          ),
          const SizedBox(height: 28),

// Today's Guidance Section
_buildAnimatedEntry(
  delay: 0.15,
  child: _buildTodaysGuidance(),
),
const SizedBox(height: 28),


// Islamic Wealth Section
_buildAnimatedEntry(
  delay: 0.3,
            child: _buildSectionTitle('Islamic Wealth'),
          ),
          const SizedBox(height: 14),

          _buildAnimatedEntry(
            delay: 0.25,
            child: _buildIslamicWealthGrid(),
          ),
          const SizedBox(height: 28),

          // Worship Section
          _buildAnimatedEntry(
            delay: 0.35,
            child: _buildSectionTitle('Worship'),
          ),
          const SizedBox(height: 14),

          _buildAnimatedEntry(
            delay: 0.4,
            child: _buildWorshipGrid(),
          ),
          const SizedBox(height: 28),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ===== PRAYER TAB (Dynamic Scene Visualizer Page) =====
  Widget _buildPrayerTab() {
    final coordinates = Coordinates(_latitude, _longitude);
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

    final currentPrayer = _getCurrentPrayerName();
    int completedCount = _salatCompleted.values.where((v) => v).length;

    // Recalculate qaza count every build (prayers that have passed and aren't ticked)
    // Sunrise is not a salat so excluded
    final salatNames = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final Map<String, DateTime?> salatDts = {
      'Fajr': prayerTimes.fajr,
      'Dhuhr': prayerTimes.dhuhr,
      'Asr': prayerTimes.asr,
      'Maghrib': prayerTimes.maghrib,
      'Isha': prayerTimes.isha,
    };
    // Calculate tomorrow's Fajr for Isha expiration check
    final tomorrow = now.add(const Duration(days: 1));
    final tomorrowPrayerTimes = PrayerTimes(
      coordinates,
      DateComponents.from(tomorrow),
      params,
    );
    final tomorrowFajrTime = tomorrowPrayerTimes.fajr;

    // Helper to calculate active Isha start time (handling midnight transition)
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

    int liveQaza = 0;
    for (final s in salatNames) {
      final isDone = _salatCompleted[s] ?? false;
      final expireTime = s == 'Fajr' ? prayerTimes.sunrise
          : s == 'Dhuhr' ? prayerTimes.asr
          : s == 'Asr' ? prayerTimes.maghrib
          : s == 'Maghrib' ? prayerTimes.isha
          : tomorrowFajrTime;

      if (now.isAfter(expireTime) && !isDone) {
        liveQaza++;
      }
    }
    if (liveQaza != _qazaCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _qazaCount = liveQaza);
      });
    }

    // === Define sky gradient per prayer scene (matching user spec exactly) ===
    LinearGradient skyGradient;
    // Cloud and star visibility flags
    bool showStars;
    bool showClouds;
    Color cloudColor;

    switch (_selectedPrayerScene) {
      case 'Fajr':
        // Fajr (Dawn): Slate-navy to steel blue to dawn sky. Distinct from Isha.
        skyGradient = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0F1E36), // Slate Navy
            Color(0xFF1D3557), // Medium slate-blue
            Color(0xFF457B9D), // Light steel blue horizon
          ],
        );
        showStars = true;
        showClouds = false;
        cloudColor = Colors.white;
        break;
      case 'Sunrise':
        // Sunrise: Soft pastel lavender-blue to warm peach orange to cream base (light theme match)
        skyGradient = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE2E9F3), // Soft pastel sky blue-gray
            Color(0xFFFBC490), // Soft pastel peach
            Color(0xFFFDE4C3), // Golden cream horizon
          ],
        );
        showStars = false;
        showClouds = true;
        cloudColor = const Color(0xFFCE5C2C).withValues(alpha: 0.4);
        break;
      case 'Dhuhr':
        // Bright light pastel clear sky blue
        skyGradient = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE3F2FD), // Light icy sky blue top
            Color(0xFFBBDEFB), // Very soft sky blue midpoint
            Color(0xFFE0F7FA), // Soft cyan horizon
          ],
        );
        showStars = false;
        showClouds = true;
        cloudColor = Colors.white;
        break;
      case 'Asr':
        // Slightly warmer pastel sky blue
        skyGradient = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFD1E8F2), // Slate-gray pastel blue
            Color(0xFFB3D9EA), // Soft mid sky blue
            Color(0xFFFFF1C5), // Creamy sunset horizon
          ],
        );
        showStars = false;
        showClouds = true;
        cloudColor = Colors.white;
        break;
      case 'Maghrib':
        // Maghrib (Sunset): Light pastel violet to soft rose pink to twilight cream
        skyGradient = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE2D4F0), // Soft lavender twilight
            Color(0xFFFFCCD5), // Soft pastel pink rose
            Color(0xFFFFDFD3), // Cream sunset glow horizon
          ],
        );
        showStars = false;
        showClouds = true;
        cloudColor = const Color(0xFFE07040).withValues(alpha: 0.3);
        break;
      case 'Isha':
      default:
        // Isha (Night): Deep dark blue to dusk blue. Dark but distinct from Fajr.
        skyGradient = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0A1128), // Deep night blue
            Color(0xFF001F54), // Dark blue midpoint
            Color(0xFF034078), // Dusk blue base
          ],
        );
        showStars = true;
        showClouds = false;
        cloudColor = Colors.white;
        break;
    }

    // ===== PRAYER TAB: pinned sky card + independently scrollable list =====
    return Column(
      key: const ValueKey('PrayerTab'),
      children: [
        // ── PINNED SKY SCENE CARD (does NOT scroll) ──────────────────
        // 1. DYNAMIC SUN/MOON/SKY HEADER CARD
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
                decoration: BoxDecoration(
                  gradient: skyGradient,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final height = constraints.maxHeight;

                    return Stack(
                      children: [
                        // Stars layer — ONLY Fajr and Isha
                        if (showStars)
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, _) {
                              return CustomPaint(
                                size: Size(width, height),
                                painter: _PrayerHeaderStarsPainter(
                                  pulseVal: _pulseController.value,
                                ),
                              );
                            },
                          ),

                        // Animated Clouds Layer — daytime and sunset scenes
                        if (showClouds)
                          AnimatedBuilder(
                            animation: _cloudsController,
                            builder: (context, _) {
                              return CustomPaint(
                                size: Size(width, height),
                                painter: _DriftingCloudsPainter(
                                  animVal: _cloudsController.value,
                                  cloudColor: cloudColor,
                                ),
                              );
                            },
                          ),

                        // Dynamic Sun
                        _buildSunPosition(width),

                        // Dynamic Moon
                        _buildMoonPosition(width),

                        // Splash Screen Mosque Silhouette base (drawn at bottom right)
                        Positioned(
                          bottom: -2,
                          left: 0,
                          right: 0,
                          height: height * 0.45,
                          child: CustomPaint(
                            painter: _MosqueSilhouettePainter(selectedScene: _selectedPrayerScene),
                          ),
                        ),

                        // Foreground text layout
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
                                      onPressed: () => setState(() => _currentIndex = 0),
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
                                        // Open Google Maps searching for mosques near current location
                                        final lat = _latitude;
                                        final lng = _longitude;
                                        // Capture messenger before async gap
                                        final messenger = ScaffoldMessenger.of(context);
                                        // Try native Maps app first (geo: URI), fallback to browser
                                        final geoUri = Uri.parse(
                                          'geo:$lat,$lng?q=mosque+near+me&z=14',
                                        );
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
                                // Next prayer name + countdown
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Next: $_nextPrayerName',
                                          style: GoogleFonts.inter(
                                            color: Colors.white.withValues(alpha: 0.80),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _liveCountdownStr,
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
                                // Location row
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_rounded, color: Colors.white54, size: 13),
                                    const SizedBox(width: 4),
                                    Text(
                                      _locationName.split(',').first,
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

        // ── SCROLLABLE LOWER SECTION (salat tracker + prayer list) ──
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
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
                  width: 1.2,
                ),
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
                    children: _salatCompleted.keys.map((salat) {
                      final isDone = _salatCompleted[salat] ?? false;

                      final sTime = salat == 'Isha' 
                          ? getIshaStartTime(salatDts['Isha'] ?? now)
                          : salatDts[salat];
                      
                      final expireTime = salat == 'Fajr' ? prayerTimes.sunrise
                          : salat == 'Dhuhr' ? salatDts['Asr']
                          : salat == 'Asr' ? salatDts['Maghrib']
                          : salat == 'Maghrib' ? salatDts['Isha']
                          : tomorrowFajrTime;

                      final bool isFuture = sTime != null && now.isBefore(sTime);
                      final bool isExpired = expireTime != null && now.isAfter(expireTime);
                      final bool isSalatMissed = isExpired && !isDone;

                      return GestureDetector(
                        onTap: () {
                          if (isSalatMissed || isFuture) return;
                          final newDone = !isDone;
                          setState(() {
                            _salatCompleted[salat] = newDone;
                          });
                          _saveSalatCompleted(salat, newDone);
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
                                        ? Icon(Icons.lock_outline_rounded, color: Colors.black.withValues(alpha: 0.22), size: 18)
                                        : isDone
                                            ? const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24)
                                            : Icon(Icons.circle_outlined, color: AppColors.navyBlue.withValues(alpha: 0.3), size: 20),
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

          // 3. Scrollable List of Prayer Times (Clean translucent list matching bg)
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

                // Salat names (Sunrise is not a fard salat)
                final bool isSalat = (pName != 'Sunrise');
                bool isMissed = false;
                if (isSalat) {
                  final expireTime = pName == 'Fajr' ? prayerTimes.sunrise
                      : pName == 'Dhuhr' ? salatDts['Asr']
                      : pName == 'Asr' ? salatDts['Maghrib']
                      : pName == 'Maghrib' ? salatDts['Isha']
                      : tomorrowFajrTime;

                  isMissed = expireTime != null && now.isAfter(expireTime) && !(_salatCompleted[pName] ?? false);
                }

                // Highlight when card is either the active next prayer OR selected by the user scene
                final bool isSceneSelected = (pName == _selectedPrayerScene);
                final bool isActive = (pName == currentPrayer);
                final bool hasAlarm = _prayerAlarms[pName] ?? false;

                // Prayer-specific subtle accent colour for selected card
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
                      onTap: () {
                        setState(() {
                          _selectedPrayerScene = pName;
                        });
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeInOutCubic,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                        decoration: BoxDecoration(
                          color: isMissed
                              ? const Color(0xFFFFF0F0)   // very light red for missed
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
                          boxShadow: isSceneSelected ? [
                            BoxShadow(
                              color: cardAccent.withValues(alpha: 0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ] : [
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
                                // Prayer-specific mini colored dot icon
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
                                        : isSceneSelected ? cardAccent : AppColors.navyBlue,
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
                                // Alarm bell toggle
                                GestureDetector(
                                  onTap: () {
                                    final newState = !hasAlarm;
                                    setState(() {
                                      _prayerAlarms[pName] = newState;
                                    });
                                    // Persist user preference
                                    _saveAlarmState(pName, newState);
                                    // Schedule or cancel system notification for this prayer
                                    _syncAlarms();
                                    // Show snackbar feedback
                                    // Show snackbar feedback
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).clearSnackBars();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            newState
                                                ? '🔔 $pName alarm set'
                                                : '🔕 $pName alarm removed',
                                            style: GoogleFonts.inter(fontSize: 13),
                                          ),
                                          duration: const Duration(seconds: 2),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          width: math.min(MediaQuery.of(context).size.width, 430) - 32, // <-- constrains + centers it
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
                                      hasAlarm
                                          ? Icons.notifications_active_rounded
                                          : Icons.notifications_none_rounded,
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
          // ===== TODAY'S MISSED PRAYER STATUS CARD (Always Visible) =====
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _qazaCount > 0
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
                        border: Border.all(
                          color: const Color(0xFFE57373).withValues(alpha: 0.45),
                          width: 1.2,
                        ),
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
                                  'You missed $_qazaCount prayer${_qazaCount > 1 ? 's' : ''} today.',
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
                              '$_qazaCount',
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
                        border: Border.all(
                          color: const Color(0xFF81C784).withValues(alpha: 0.45),
                          width: 1.2,
                        ),
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

          // ===== INTERACTIVE QAZA COUNTER SECTION (Always Visible) =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
                  width: 1.2,
                ),
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
                    style: GoogleFonts.inter(
                      color: AppColors.navyBlue.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // List of 5 salats with increment / decrement buttons
                  ...['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'].map((salat) {
                    final count = _qazaCounts[salat] ?? 0;
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
                                decoration: const BoxDecoration(
                                  color: AppColors.coralOrange,
                                  shape: BoxShape.circle,
                                ),
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
                              // Decrement Button
                              GestureDetector(
                                onTap: () {
                                  if (count > 0) {
                                    setState(() {
                                      _qazaCounts[salat] = count - 1;
                                    });
                                    _saveQazaCount(salat, count - 1);
                                  }
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
                              // Counter Text
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
                              // Increment Button
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _qazaCounts[salat] = count + 1;
                                  });
                                  _saveQazaCount(salat, count + 1);
                                },
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
          const SizedBox(height: 80), // space above bottom nav
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Helper widget to place the Sun in the dynamic Sky panel based on selected prayer scene
  Widget _buildSunPosition(double width) {
    double sunTop = 80.0;
    double sunLeft = width * 0.5 - 25;
    double opacity = 0.0;

    switch (_selectedPrayerScene) {
      case 'Sunrise':
        sunTop = 150.0;
        sunLeft = width * 0.5 - 25; // rising low at the horizon center
        opacity = 0.9;
        break;
      case 'Dhuhr':
        sunTop = 38.0;
        sunLeft = width * 0.5 - 25; // high in the sky center
        opacity = 1.0;
        break;
      case 'Asr':
        sunTop = 72.0;
        sunLeft = width * 0.72 - 25; // lower and shifted to the right
        opacity = 0.95;
        break;
      case 'Maghrib':
        sunTop = 175.0;
        sunLeft = width * 0.5 - 25; // setting at the bottom horizon
        opacity = 0.85;
        break;
      default:
        opacity = 0.0; // hidden at night
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
              BoxShadow(
                color: const Color(0xFFFFA000).withValues(alpha: 0.55),
                blurRadius: 28,
                spreadRadius: 8,
              ),
              const BoxShadow(
                color: Colors.white,
                blurRadius: 10,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget to place the Moon in the dynamic Sky panel (Fajr and Isha night scenes)
  Widget _buildMoonPosition(double width) {
    double moonTop = 50.0;
    double moonLeft = width * 0.5 - 25;
    double opacity = 0.0;

    if (_selectedPrayerScene == 'Fajr' || _selectedPrayerScene == 'Isha') {
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
        child: Container(
          width: 50,
          height: 50,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
          ),
          child: CustomPaint(
            painter: _CrescentMoonPainter(),
          ),
        ),
      ),
    );
  }

  // ===== ANIMATED ENTRY WRAPPER =====
  Widget _buildAnimatedEntry({required double delay, required Widget child}) {
    final animation = CurvedAnimation(
      parent: _staggerController,
      curve: Interval(
        delay,
        math.min(delay + 0.4, 1.0),
        curve: Curves.easeOutCubic,
      ),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - animation.value)),
          child: Opacity(
            opacity: animation.value,
            child: child,
          ),
        );
      },
    );
  }

  // ===== GREETING HEADER =====
  Widget _buildGreetingHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Assalamu Alaikum, ',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.navyBlue.withValues(alpha: 0.65),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.midTeal,
                      size: 13,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        _locationName,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.midTeal,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Rahim',
                  style: GoogleFonts.poppins(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navyBlue,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          // Notification Bell with dot
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navyBlue.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: AppColors.navyBlue,
                  size: 22,
                ),
              ),
              Positioned(
                top: 8,
                right: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.coralOrange,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===== NEXT PRAYER CARD (static — no float, but animated decoration) =====
  // Returns the gradient for the Next Prayer Card based on the current prayer time
  LinearGradient _getPrayerCardGradient() {
    switch (_nextPrayerName) {
      case 'Fajr':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F1E36), Color(0xFF1D3557), Color(0xFF457B9D)],
        );
      case 'Dhuhr':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A6EA8), Color(0xFF2A8FCC), Color(0xFF52AEDE)],
        );
      case 'Asr':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B5C8A), Color(0xFF2E7BAD), Color(0xFFD4874A)],
        );
      case 'Maghrib':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6B3A7D), Color(0xFFB05C8A), Color(0xFFE8855A)],
        );
      case 'Isha':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF060D1A), Color(0xFF0D1F35), Color(0xFF152942)],
        );
      default: // Fajr fallback
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F1E36), Color(0xFF1D3557), Color(0xFF457B9D)],
        );
    }
  }

  Widget _buildNextPrayerCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: AnimatedBuilder(
        animation: Listenable.merge([_cloudsController, _pulseController]),
        builder: (context, _) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: _getPrayerCardGradient(),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navyBlue.withValues(alpha: 0.30),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Live-animated mosque silhouette + drifting clouds + twinkling stars
                Positioned.fill(
                  child: CustomPaint(
                    painter: _NextPrayerCardDecorationPainter(
                      cloudAnimationVal: _cloudsController.value,
                      pulseVal: _pulseController.value,
                      prayerName: _nextPrayerName,
                    ),
                  ),
                ),
                // Foreground Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.coralOrange,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Next Prayer',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.75),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _nextPrayerName,
                              style: GoogleFonts.poppins(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$_nextPrayerTimeStr  ·  in $_countdownStr',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Pulsing clock ring — still animated
                      Transform.scale(
                        scale: 1.0 + _pulseController.value * 0.055,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.access_time_filled_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ===== SECTION TITLE =====
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.navyBlue,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // ===== ISLAMIC WEALTH GRID =====
  Widget _buildIslamicWealthGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildFeatureCard(
                  icon: Icons.calculate_rounded,
                  label: 'Zakat Calculator',
                  iconPainter: _ZakatIconPainter(),
                  onTap: _showZakatCalculatorSheet,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
  child: _buildFeatureCard(
    icon: Icons.pets_rounded,
    label: 'Qurbani Planner',
    iconPainter: _QurbaniIconPainter(),
    onTap: () {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const QurbaniPlannerPage(),
        ),
      );
    },
  ),
),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildFeatureCard(
                  icon: Icons.flight_takeoff_rounded,
                  label: 'Hajj & Umrah',
                  iconPainter: _HajjIconPainter(),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const HajjUmrahPlannerScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildFeatureCard(
                  icon: Icons.account_balance_rounded,
                  label: 'Inheritance',
                  iconPainter: _InheritanceIconPainter(),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const InheritanceGuideScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  // ===== WORSHIP GRID =====
  // ===== WORSHIP GRID =====
  Widget _buildWorshipGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildFeatureCard(
                  icon: Icons.menu_book_rounded,
                  label: 'Quran Tracker',
                  iconPainter: _QuranIconPainter(),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildFeatureCard(
                  icon: Icons.fingerprint_rounded,
                  label: 'Dhikr Counter',
                  iconPainter: _DhikrIconPainter(),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DhikrCounterScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildFeatureCard(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Halal Scanner',
                  iconPainter: _HalalIconPainter(),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildFeatureCard(
                  icon: Icons.health_and_safety_rounded,
                  label: 'Emergency SOS',
                  iconPainter: _EmergencyIconPainter(),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EmergencySosScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
 
 // ===== FEATURE CARD (Reusable) =====
  Widget _buildFeatureCard({
    required IconData icon,
    required String label,
    CustomPainter? iconPainter,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () {},
        borderRadius: BorderRadius.circular(18),
        splashColor: AppColors.midTeal.withValues(alpha: 0.15),
        highlightColor: AppColors.midTeal.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.navyBlue.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(
              color: AppColors.navyBlue.withValues(alpha: 0.22),
              width: 1.6,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon container with custom vector art
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.midTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.midTeal.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: iconPainter != null
                    ? CustomPaint(painter: iconPainter)
                    : Icon(icon, color: AppColors.navyBlue, size: 22),
              ),
              const SizedBox(height: 14),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navyBlue,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  // ===== TODAY'S GUIDANCE =====
  Widget _buildTodaysGuidance() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.navyBlue.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: AppColors.dustyBlueTeal.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.midTeal,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  "Today's Guidance",
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navyBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Read Surah Al-Kahf today and reflect on its lessons of patience and trust in Allah.',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
                color: AppColors.navyBlue.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== PLACEHOLDER TAB =====
  Widget _buildPlaceholderTab() {
    final List<String> tabNames = ['Home', 'Prayer', 'Calendar', 'Assistant', 'Profile'];
    return Center(
      key: ValueKey('PlaceholderTab_$_currentIndex'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.construction_rounded,
            color: AppColors.navyBlue.withValues(alpha: 0.3),
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            '${tabNames[_currentIndex]} Coming Soon',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.navyBlue.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This feature is under development',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.navyBlue.withValues(alpha: 0.35),
            ),
          ),
          if (_currentIndex == 4) ...[
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text(
                'Log Out',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navyBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

}
class _DashboardStarConfig {
  final double topFraction;
  final double leftFraction;
  final double size;
  final int delayMs;

  _DashboardStarConfig({
    required this.topFraction,
    required this.leftFraction,
    required this.size,
    required this.delayMs,
  });
}

// ===== TWINKLING STAR WIDGET =====
class _DashboardTwinklingStar extends StatefulWidget {
  final double topFraction;
  final double leftFraction;
  final double size;
  final int delayMs;

  const _DashboardTwinklingStar({
    required this.topFraction,
    required this.leftFraction,
    required this.size,
    required this.delayMs,
  });

  @override
  State<_DashboardTwinklingStar> createState() =>
      _DashboardTwinklingStarState();
}

class _DashboardTwinklingStarState extends State<_DashboardTwinklingStar>
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
    _opacity = Tween<double>(begin: 0.05, end: 0.45).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _timer = Timer(Duration(milliseconds: widget.delayMs), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
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
    // Use Align with FractionalOffset instead of LayoutBuilder + Positioned.
    // Positioned must be a direct child of a Stack render object; wrapping it
    // in a LayoutBuilder breaks that requirement and throws a ParentDataWidget
    // assertion. FractionalOffset(x, y) maps [0,0]?top-left, [1,1]?bottom-right.
    return Align(
      alignment: FractionalOffset(widget.leftFraction, widget.topFraction),
      child: AnimatedBuilder(
        animation: _opacity,
        builder: (context, child) {
          return Opacity(
            opacity: _opacity.value,
            child: CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _DashboardStarPainter(),
            ),
          );
        },
      ),
    );
  }
}

// ===== FOUR-POINT STAR PAINTER =====
class _DashboardStarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.navyBlue.withValues(alpha: 0.25)
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

    final corePaint = Paint()
      ..color = AppColors.dustyBlueTeal.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), size.width * 0.12, corePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ===== VERY VERY VERY SMALL ISLAMIC TEXTURE PAINTER =====
class _DashboardTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.navyBlue.withValues(alpha: 0.015)
      ..strokeWidth = 0.4
      ..style = PaintingStyle.stroke;

    final double gridWidth = 16.0;
    final int rows = (size.height / gridWidth).ceil() + 1;
    final int cols = (size.width / gridWidth).ceil() + 1;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        double x = c * gridWidth;
        double y = r * gridWidth;

        canvas.drawRect(
          Rect.fromLTWH(
              x - gridWidth / 2, y - gridWidth / 2, gridWidth, gridWidth),
          paint,
        );

        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(math.pi / 4);
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero, width: gridWidth, height: gridWidth),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ===== NEXT PRAYER CARD CUSTOM VECTOR BACKGROUND PAINTER =====
class _NextPrayerCardDecorationPainter extends CustomPainter {
  final double cloudAnimationVal;
  final double pulseVal;
  final String prayerName;

  _NextPrayerCardDecorationPainter({
    required this.cloudAnimationVal,
    required this.pulseVal,
    this.prayerName = 'Fajr',
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final bool isNight = prayerName == 'Fajr' || prayerName == 'Isha';
    final bool isDaytime = prayerName == 'Dhuhr' || prayerName == 'Asr';

    // 1. Draw Twinkling Stars � only for Fajr and Isha
    if (isNight) {
      final starPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.35 + (0.35 * math.sin(pulseVal * math.pi)))
        ..style = PaintingStyle.fill;

      final List<Offset> starLocations = [
        Offset(w * 0.15, h * 0.22),
        Offset(w * 0.35, h * 0.12),
        Offset(w * 0.48, h * 0.28),
        Offset(w * 0.72, h * 0.18),
        Offset(w * 0.90, h * 0.32),
        Offset(w * 0.25, h * 0.35),
      ];

      for (var offset in starLocations) {
        _drawSparklingStar(canvas, offset, 5.0, starPaint);
      }
    }

    // 2. Draw a glowing sun for daytime prayers (Dhuhr, Asr)
    if (isDaytime) {
      final sunGlow = Paint()
        ..color = Colors.white.withValues(alpha: 0.10 + 0.06 * math.sin(pulseVal * math.pi))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawCircle(Offset(w * 0.82, h * 0.22), 32, sunGlow);
      final sunCore = Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(w * 0.82, h * 0.22), 16, sunCore);
    }

    // 3. Draw a warm glow orb for Maghrib
    if (prayerName == 'Maghrib') {
      final glowPaint = Paint()
        ..color = const Color(0xFFFF9966).withValues(alpha: 0.18 + 0.07 * math.sin(pulseVal * math.pi))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
      canvas.drawCircle(Offset(w * 0.80, h * 0.25), 38, glowPaint);
    }

    // 4. Draw Translucent Floating Clouds
    final cloudAlpha = isDaytime ? 0.12 : 0.08;
    final cloudPaint = Paint()
      ..color = Colors.white.withValues(alpha: cloudAlpha)
      ..style = PaintingStyle.fill;

    // Cloud 1: Slow top drift
    double cx1 = (w * cloudAnimationVal + w * 0.2) % (w + 80) - 40;
    _drawCloud(canvas, Offset(cx1, h * 0.20), 22, cloudPaint);

    // Cloud 2: Faster middle drift (hidden at night)
    if (!isNight) {
      double cx2 = (w * 1.5 * cloudAnimationVal + w * 0.6) % (w + 100) - 50;
      _drawCloud(canvas, Offset(cx2, h * 0.38), 28, cloudPaint);
    }

    // 3. Draw Silhouette Mosque Vector at the Bottom Right
    final mosquePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;

    final double mosqueRight = w * 0.88;
    final double mosqueBaseY = h;
    final double mosqueWidth = w * 0.35;
    final double mosqueHeight = h * 0.62;

    _drawMosqueSilhouette(canvas, mosqueRight, mosqueBaseY, mosqueWidth, mosqueHeight, mosquePaint);
  }

  void _drawSparklingStar(Canvas canvas, Offset center, double size, Paint paint) {
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
  }

  void _drawCloud(Canvas canvas, Offset center, double baseSize, Paint paint) {
    final cx = center.dx;
    final cy = center.dy;

    canvas.drawCircle(Offset(cx, cy), baseSize, paint);
    canvas.drawCircle(Offset(cx - baseSize * 0.6, cy + baseSize * 0.25), baseSize * 0.7, paint);
    canvas.drawCircle(Offset(cx + baseSize * 0.6, cy + baseSize * 0.25), baseSize * 0.7, paint);
    canvas.drawCircle(Offset(cx - baseSize * 1.1, cy + baseSize * 0.4), baseSize * 0.5, paint);
    canvas.drawCircle(Offset(cx + baseSize * 1.1, cy + baseSize * 0.4), baseSize * 0.5, paint);
  }

  void _drawMosqueSilhouette(Canvas canvas, double cx, double by, double width, double height, Paint paint) {
    final path = Path();
    final double w2 = width / 2;
    
    // Main Dome
    final domeH = height * 0.55;
    final domeW = width * 0.6;
    final domeX = cx;
    final domeY = by - height * 0.4;
    
    final double bulge = domeW * 0.08;
    path.moveTo(domeX - domeW / 2, domeY);
    path.cubicTo(
      domeX - domeW / 2 - bulge, domeY - domeH * 0.35,
      domeX - domeW / 2 + bulge * 0.2, domeY - domeH * 0.75,
      domeX, domeY - domeH,
    );
    path.cubicTo(
      domeX + domeW / 2 - bulge * 0.2, domeY - domeH * 0.75,
      domeX + domeW / 2 + bulge, domeY - domeH * 0.35,
      domeX + domeW / 2, domeY,
    );
    path.close();
    canvas.drawPath(path, paint);

    // Left Minaret
    final min1W = width * 0.16;
    final min1H = height * 0.85;
    final min1X = cx - w2 + min1W * 0.6;
    canvas.drawRect(Rect.fromLTRB(min1X - min1W / 2, by - min1H, min1X + min1W / 2, by), paint);
    
    final capW = min1W * 1.2;
    final capH = min1H * 0.18;
    final capY = by - min1H;
    final capPath = Path();
    capPath.moveTo(min1X - capW / 2, capY);
    capPath.lineTo(min1X + capW / 2, capY);
    capPath.lineTo(min1X, capY - capH);
    capPath.close();
    canvas.drawPath(capPath, paint);

    // Right Minaret
    final min2W = width * 0.16;
    final min2H = height * 0.85;
    final min2X = cx + w2 - min2W * 0.6;
    canvas.drawRect(Rect.fromLTRB(min2X - min2W / 2, by - min2H, min2X + min2W / 2, by), paint);

    final capPath2 = Path();
    capPath2.moveTo(min2X - capW / 2, capY);
    capPath2.lineTo(min2X + capW / 2, capY);
    capPath2.lineTo(min2X, capY - capH);
    capPath2.close();
    canvas.drawPath(capPath2, paint);

    canvas.drawRect(Rect.fromLTRB(cx - w2 * 0.8, by - height * 0.45, cx + w2 * 0.8, by), paint);
  }

  @override
  bool shouldRepaint(covariant _NextPrayerCardDecorationPainter oldDelegate) {
    return oldDelegate.cloudAnimationVal != cloudAnimationVal ||
        oldDelegate.pulseVal != pulseVal ||
        oldDelegate.prayerName != prayerName;
  }
}

// ===== DRIFTING CLOUDS PAINTER (Drifts horizontally across dynamic sky header) =====
class _DriftingCloudsPainter extends CustomPainter {
  final double animVal;
  final Color cloudColor;

  _DriftingCloudsPainter({required this.animVal, required this.cloudColor});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final cloudPaint = Paint()
      ..color = cloudColor.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;

    // Cloud 1 � gentle slow drift
    double x1 = (w * animVal + w * 0.1) % (w + 100) - 50;
    _drawCloud(canvas, Offset(x1, h * 0.25), 26, cloudPaint);

    // Cloud 2 � slightly faster drift from the other side
    double x2 = (w * 1.4 * animVal + w * 0.55) % (w + 120) - 60;
    _drawCloud(canvas, Offset(x2, h * 0.42), 32, cloudPaint);

    // Cloud 3 � small accent cloud
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
  bool shouldRepaint(covariant _DriftingCloudsPainter oldDelegate) {
    return oldDelegate.animVal != animVal || oldDelegate.cloudColor != cloudColor;
  }
}

// ===== PRAYER HEADER STARS PAINTER (Twinkling stars for Fajr/Isha scenes) =====
class _PrayerHeaderStarsPainter extends CustomPainter {
  final double pulseVal;

  _PrayerHeaderStarsPainter({required this.pulseVal});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Draw ~20 small twinkling stars across the header sky
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
  bool shouldRepaint(covariant _PrayerHeaderStarsPainter oldDelegate) {
    return oldDelegate.pulseVal != pulseVal;
  }
}

// ===== DYNAMIC CRESCENT MOON PAINTER (Night scenes: Fajr / Isha) =====
class _CrescentMoonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width * 0.4;

    // Draw main glowing moon
    final moonPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), radius, moonPaint);

    // Subtract cutout
    final cutoutPaint = Paint()
      ..color = Colors.transparent
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.fill;

    // Create a layer to support blendMode transparency mask clip
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawCircle(Offset(cx, cy), radius, moonPaint);
    canvas.drawCircle(
      Offset(cx + radius * 0.35, cy - radius * 0.18),
      radius * 0.85,
      cutoutPaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ===== MOSQUE SILHOUETTE PAINTER (Renders splash screen mosque silhouette in header) =====
// ===== FULL RICH MOSQUE SILHOUETTE (matching splash screen style) =====
class _MosqueSilhouettePainter extends CustomPainter {
  final String selectedScene;

  _MosqueSilhouettePainter({required this.selectedScene});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Pick palette per scene � same logic as before but with richer fill details
    Color navyC, tealC, whiteC;
    switch (selectedScene) {
      case 'Fajr':
        navyC  = const Color(0xFF1D2D44);
        tealC  = const Color(0xFF4A7C74);
        whiteC = const Color(0xFFB8CEDE);
        break;
      case 'Sunrise':
        navyC  = const Color(0xFF5D3A1A);
        tealC  = const Color(0xFFD4854A);
        whiteC = const Color(0xFFFFE9D6);
        break;
      case 'Dhuhr':
        navyC  = const Color(0xFF0D47A1);
        tealC  = const Color(0xFF1976D2);
        whiteC = Colors.white;
        break;
      case 'Asr':
        navyC  = const Color(0xFF1B5E8A);
        tealC  = const Color(0xFF4FA8D2);
        whiteC = const Color(0xFFE0F7FA);
        break;
      case 'Maghrib':
        navyC  = const Color(0xFF4A1942);
        tealC  = const Color(0xFFB05C8A);
        whiteC = const Color(0xFFFFD4E8);
        break;
      case 'Isha':
      default:
        navyC  = const Color(0xFF0A1628);
        tealC  = const Color(0xFF1A3050);
        whiteC = const Color(0xFF7B93B0);
        break;
    }

    final paintNavy  = Paint()..color = navyC ..style = PaintingStyle.fill;
    final paintTeal  = Paint()..color = tealC ..style = PaintingStyle.fill;
    final paintWhite = Paint()..color = whiteC..style = PaintingStyle.fill;

    // -- 1. Side domes (teal, background) ----------------------------
    _drawOnionDome(canvas, w * 0.28, h * 0.68, w * 0.16, h * 0.26, paintTeal);
    _drawOnionDome(canvas, w * 0.72, h * 0.68, w * 0.16, h * 0.26, paintTeal);

    // -- 2. Central building walls (white) ---------------------------
    final wallPath = Path()
      ..moveTo(w * 0.12, h)
      ..lineTo(w * 0.12, h * 0.70)
      ..lineTo(w * 0.88, h * 0.70)
      ..lineTo(w * 0.88, h)
      ..close();
    canvas.drawPath(wallPath, paintWhite);

    // -- 3. Central dome (navy) ---------------------------------------
    _drawOnionDome(canvas, w * 0.50, h * 0.65, w * 0.32, h * 0.42, paintNavy);

    // Crescent + spire on center dome
    final double spireTop = h * 0.65 - h * 0.42 - 8;
    final spirePaint = Paint()
      ..color = whiteC
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w * 0.50, h * 0.65 - h * 0.42), Offset(w * 0.50, spireTop), spirePaint);
    canvas.drawCircle(Offset(w * 0.50, spireTop), 2.2, paintWhite);

    // -- 4. Arched entrance door (navy) ------------------------------
    final double doorCx = w * 0.50;
    final double doorW  = w * 0.12;
    final double doorH  = h * 0.30;
    final double doorTop = h - doorH;
    final doorPath = Path()
      ..moveTo(doorCx - doorW / 2, h)
      ..lineTo(doorCx - doorW / 2, doorTop + doorW * 0.5)
      ..quadraticBezierTo(doorCx, doorTop - doorW * 0.3, doorCx + doorW / 2, doorTop + doorW * 0.5)
      ..lineTo(doorCx + doorW / 2, h)
      ..close();
    canvas.drawPath(doorPath, paintNavy);

    // Side windows (two small arched windows)
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

    // Ground floor fill
    canvas.drawRect(Rect.fromLTRB(0, h * 0.92, w, h), paintWhite);

    // -- 5. Left minaret ----------------------------------------------
    _drawMinaret(canvas, w * 0.14, h, w * 0.07, h * 0.90, paintWhite, paintTeal);

    // -- 6. Right minaret ---------------------------------------------
    _drawMinaret(canvas, w * 0.86, h, w * 0.07, h * 0.90, paintWhite, paintTeal);
  }

  void _drawOnionDome(Canvas canvas, double cx, double by, double width, double height, Paint paint) {
    final path = Path();
    final double w2    = width / 2;
    final double bulge = width * 0.08;
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
    canvas.drawPath(path, paint);
  }

  void _drawMinaret(Canvas canvas, double cx, double by, double width, double height,
      Paint paintBody, Paint paintCap) {
    final double colW     = width * 0.55;
    final double balconyW = width * 1.15;
    // Column
    canvas.drawRect(Rect.fromLTRB(cx - colW / 2, by - height, cx + colW / 2, by), paintBody);
    // Balconies
    canvas.drawRect(Rect.fromLTRB(cx - balconyW / 2, by - height * 0.72, cx + balconyW / 2, by - height * 0.69), paintBody);
    canvas.drawRect(Rect.fromLTRB(cx - balconyW / 2, by - height - 2,     cx + balconyW / 2, by - height),         paintBody);
    // Onion dome cap
    _drawOnionDome(canvas, cx, by - height - 2, width * 0.75, height * 0.13, paintCap);
  }

  @override
  bool shouldRepaint(covariant _MosqueSilhouettePainter oldDelegate) {
    return oldDelegate.selectedScene != selectedScene;
  }
}

// ===== CUSTOM FEATURE ICON PAINTERS =====

// Zakat Calculator Icon
class _ZakatIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.navyBlue.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final s = size.width * 0.16;

    for (int r = 0; r < 2; r++) {
      for (int c = 0; c < 2; c++) {
        final x = cx - s * 1.1 + c * s * 1.2;
        final y = cy - s * 1.1 + r * s * 1.2;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, s, s),
            const Radius.circular(3),
          ),
          paint,
        );
      }
    }

    final plusPaint = Paint()
      ..color = AppColors.midTeal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, cy - s * 0.3), Offset(cx, cy + s * 0.3), plusPaint);
    canvas.drawLine(Offset(cx - s * 0.3, cy), Offset(cx + s * 0.3, cy), plusPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Qurbani Planner Icon
class _QurbaniIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.navyBlue.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.22;

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + r * 0.15), width: r * 2, height: r * 1.3),
      paint,
    );

    canvas.drawCircle(Offset(cx - r * 0.85, cy - r * 0.15), r * 0.5, paint);

    canvas.drawLine(
      Offset(cx - r * 1.15, cy - r * 0.55),
      Offset(cx - r * 1.3, cy - r * 0.85),
      paint,
    );
    canvas.drawLine(
      Offset(cx - r * 0.65, cy - r * 0.55),
      Offset(cx - r * 0.5, cy - r * 0.85),
      paint,
    );

    final legPaint = Paint()
      ..color = AppColors.navyBlue.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(cx - r * 0.5, cy + r * 0.7), Offset(cx - r * 0.5, cy + r * 1.2), legPaint);
    canvas.drawLine(Offset(cx + r * 0.5, cy + r * 0.7), Offset(cx + r * 0.5, cy + r * 1.2), legPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Hajj & Umrah Icon
class _HajjIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.navyBlue.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final s = size.width * 0.2;

    final kaaba = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy + s * 0.1), width: s * 1.8, height: s * 1.6),
      const Radius.circular(2),
    );
    canvas.drawRRect(kaaba, paint);

    final bandPaint = Paint()
      ..color = AppColors.midTeal.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(cx - s * 0.9, cy - s * 0.15),
      Offset(cx + s * 0.9, cy - s * 0.15),
      bandPaint,
    );

    final arrowPaint = Paint()
      ..color = AppColors.navyBlue.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(cx, cy - s * 1.0), Offset(cx, cy - s * 1.5), arrowPaint);
    canvas.drawLine(Offset(cx - s * 0.3, cy - s * 1.2), Offset(cx, cy - s * 1.5), arrowPaint);
    canvas.drawLine(Offset(cx + s * 0.3, cy - s * 1.2), Offset(cx, cy - s * 1.5), arrowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Inheritance Icon
class _InheritanceIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.navyBlue.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final s = size.width * 0.18;

    canvas.drawLine(Offset(cx, cy - s * 1.2), Offset(cx, cy + s * 1.0), paint);
    canvas.drawLine(Offset(cx - s * 1.2, cy - s * 0.6), Offset(cx + s * 1.2, cy - s * 0.6), paint);

    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx - s * 1.2, cy - s * 0.2), width: s * 1.0, height: s * 0.5),
      0,
      math.pi,
      false,
      paint,
    );
    canvas.drawLine(Offset(cx - s * 1.2, cy - s * 0.6), Offset(cx - s * 1.7, cy - s * 0.2), paint);
    canvas.drawLine(Offset(cx - s * 1.2, cy - s * 0.6), Offset(cx - s * 0.7, cy - s * 0.2), paint);

    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx + s * 1.2, cy + s * 0.0), width: s * 1.0, height: s * 0.5),
      0,
      math.pi,
      false,
      paint,
    );
    canvas.drawLine(Offset(cx + s * 1.2, cy - s * 0.6), Offset(cx + s * 1.7, cy + s * 0.0), paint);
    canvas.drawLine(Offset(cx + s * 1.2, cy - s * 0.6), Offset(cx + s * 0.7, cy + s * 0.0), paint);

    final triPaint = Paint()
      ..color = AppColors.midTeal.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    final triPath = Path()
      ..moveTo(cx, cy - s * 1.4)
      ..lineTo(cx - s * 0.3, cy - s * 1.0)
      ..lineTo(cx + s * 0.3, cy - s * 1.0)
      ..close();
    canvas.drawPath(triPath, triPaint);

    canvas.drawLine(Offset(cx - s * 0.6, cy + s * 1.0), Offset(cx + s * 0.6, cy + s * 1.0), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Quran Tracker Icon
class _QuranIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.navyBlue.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final s = size.width * 0.2;

    final leftPage = Path()
      ..moveTo(cx, cy - s * 0.8)
      ..quadraticBezierTo(cx - s * 0.5, cy - s * 0.9, cx - s * 1.3, cy - s * 0.7)
      ..lineTo(cx - s * 1.3, cy + s * 0.7)
      ..quadraticBezierTo(cx - s * 0.5, cy + s * 0.5, cx, cy + s * 0.8);
    canvas.drawPath(leftPage, paint);

    final rightPage = Path()
      ..moveTo(cx, cy - s * 0.8)
      ..quadraticBezierTo(cx + s * 0.5, cy - s * 0.9, cx + s * 1.3, cy - s * 0.7)
      ..lineTo(cx + s * 1.3, cy + s * 0.7)
      ..quadraticBezierTo(cx + s * 0.5, cy + s * 0.5, cx, cy + s * 0.8);
    canvas.drawPath(rightPage, paint);

    canvas.drawLine(Offset(cx, cy - s * 0.8), Offset(cx, cy + s * 0.8), paint);

    final linePaint = Paint()
      ..color = AppColors.midTeal.withValues(alpha: 0.4)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(cx - s * 1.0, cy - s * 0.25), Offset(cx - s * 0.3, cy - s * 0.25), linePaint);
    canvas.drawLine(Offset(cx - s * 1.0, cy + s * 0.05), Offset(cx - s * 0.3, cy + s * 0.05), linePaint);
    canvas.drawLine(Offset(cx - s * 1.0, cy + s * 0.35), Offset(cx - s * 0.45, cy + s * 0.35), linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Dhikr Counter Icon
class _DhikrIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.navyBlue.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.24;

    for (int i = 0; i < 4; i++) {
      final arcR = r * (0.4 + i * 0.22);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: arcR),
        -math.pi * 0.7,
        math.pi * 1.4,
        false,
        paint..color = AppColors.navyBlue.withValues(alpha: 0.65 - i * 0.1),
      );
    }

    final dotPaint = Paint()
      ..color = AppColors.midTeal
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), r * 0.15, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Halal Scanner Icon
class _HalalIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.navyBlue.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final s = size.width * 0.22;

    canvas.drawLine(Offset(cx - s, cy - s), Offset(cx - s + s * 0.5, cy - s), paint);
    canvas.drawLine(Offset(cx - s, cy - s), Offset(cx - s, cy - s + s * 0.5), paint);

    canvas.drawLine(Offset(cx + s, cy - s), Offset(cx + s - s * 0.5, cy - s), paint);
    canvas.drawLine(Offset(cx + s, cy - s), Offset(cx + s, cy - s + s * 0.5), paint);

    canvas.drawLine(Offset(cx - s, cy + s), Offset(cx - s + s * 0.5, cy + s), paint);
    canvas.drawLine(Offset(cx - s, cy + s), Offset(cx - s, cy + s - s * 0.5), paint);

    canvas.drawLine(Offset(cx + s, cy + s), Offset(cx + s - s * 0.5, cy + s), paint);
    canvas.drawLine(Offset(cx + s, cy + s), Offset(cx + s, cy + s - s * 0.5), paint);

    final checkPaint = Paint()
      ..color = AppColors.midTeal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - s * 0.3, cy), Offset(cx - s * 0.05, cy + s * 0.3), checkPaint);
    canvas.drawLine(Offset(cx - s * 0.05, cy + s * 0.3), Offset(cx + s * 0.35, cy - s * 0.25), checkPaint);

    final scanPaint = Paint()
      ..color = AppColors.coralOrange.withValues(alpha: 0.5)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(cx - s * 0.8, cy - s * 0.5), Offset(cx + s * 0.8, cy - s * 0.5), scanPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Emergency SOS Icon
class _EmergencyIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final s = size.width * 0.16;

    final paint = Paint()
      ..color = AppColors.navyBlue.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(cx, cy - s * 1.1), Offset(cx, cy + s * 1.1), paint);
    canvas.drawLine(Offset(cx - s * 1.1, cy), Offset(cx + s * 1.1, cy), paint);
    canvas.drawLine(Offset(cx - s * 0.75, cy - s * 0.75), Offset(cx + s * 0.75, cy + s * 0.75), paint);
    canvas.drawLine(Offset(cx + s * 0.75, cy - s * 0.75), Offset(cx - s * 0.75, cy + s * 0.75), paint);

    final centerPaint = Paint()
      ..color = AppColors.coralOrange.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), s * 0.35, centerPaint);

    final outerPaint = Paint()
      ..color = AppColors.navyBlue.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(Offset(cx, cy), s * 1.3, outerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}