import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart';
import '../widgets/auth_header.dart'; // To access AppColors and AppLogo
import '../services/notification_service.dart'; // Real prayer alarm notifications
import '../widgets/notification_center_modal.dart';
import 'calendar_tab.dart';
import 'hajj_umrah_screen.dart';
import 'inheritance_screen.dart';
import 'qurbani_planner_screen.dart';
import 'assistant_tab.dart';
import 'zakat_manager_screen.dart';
import 'quran_tracker_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/theme_service.dart';
import '../services/language_service.dart';
import '../l10n/app_localizations.dart';
import 'emergency_sos_screen.dart';
import 'dhikr_counter_screen.dart';
import 'profile_tab.dart';
import 'halal_scanner/halal_scanner_home.dart';
import 'prayer_tab.dart'; // Extracted Prayer tab widget
import 'salat_guide_screen.dart'; // Salat rules, illustrated steps & rakat guide
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const DashboardScreen({super.key, required this.onLogout});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0; // Bottom navigation tab
  bool _isDarkMode = false; // Global Dark Mode state for the app
  String _userName = 'User';


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
  StreamSubscription<Position>? _positionStreamSub;

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


Future<void> _loadUserProfile() async {
  debugPrint('🔥🔥🔥 LOAD USER PROFILE CALLED 🔥🔥🔥');

  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('No logged-in user found.');
      return;
    }

    // 1. Immediately load cached name from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final cachedName = prefs.getString('profile_name');
    if (cachedName != null && cachedName.trim().isNotEmpty) {
      if (mounted) {
        setState(() {
          _userName = cachedName.trim();
        });
      }
    } else {
      // Fallback to auth display name if available
      if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
        if (mounted) {
          setState(() {
            _userName = user.displayName!.trim();
          });
        }
      }
    }

    // 2. Fetch from Firestore users/{uid} directly
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      final data = doc.data();
      if (data != null) {
        // Sync profile details
        if (data['profile'] != null) {
          final profile = data['profile'] as Map<String, dynamic>;
          final fullName = profile['fullName'] as String?;
          
          if (fullName != null && fullName.trim().isNotEmpty) {
            if (mounted) {
              setState(() {
                _userName = fullName.trim();
              });
            }
            await prefs.setString('profile_name', _userName);
          }
        }

        // Sync Qaza Counts
        if (data['qazaCounts'] != null) {
          final firestoreQaza = data['qazaCounts'] as Map<String, dynamic>;
          for (final prayer in _qazaCounts.keys) {
            if (firestoreQaza.containsKey(prayer)) {
              final count = firestoreQaza[prayer] as int;
              if (mounted) {
                setState(() {
                  _qazaCounts[prayer] = count;
                });
              }
              await prefs.setInt('qaza_$prayer', count);
            }
          }
        }

        // Sync Prayer Alarms
        if (data['prayerAlarms'] != null) {
          final firestoreAlarms = data['prayerAlarms'] as Map<String, dynamic>;
          for (final prayer in _prayerAlarms.keys) {
            if (firestoreAlarms.containsKey(prayer)) {
              final enabled = firestoreAlarms[prayer] as bool;
              if (mounted) {
                setState(() {
                  _prayerAlarms[prayer] = enabled;
                });
              }
              await prefs.setBool('alarm_$prayer', enabled);
            }
          }
          _syncAlarms();
        }

        // Sync Salat Completed for today
        if (data['salatCompleted'] != null) {
          final firestoreSalat = data['salatCompleted'] as Map<String, dynamic>;
          final now = DateTime.now();
          final ymd = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
          
          for (final salat in _salatCompleted.keys) {
            final key = '${ymd}_$salat';
            if (firestoreSalat.containsKey(key)) {
              final val = firestoreSalat[key] as bool;
              if (mounted) {
                setState(() {
                  _salatCompleted[salat] = val;
                });
              }
              await prefs.setBool('completed_${ymd}_$salat', val);
            }
          }
        }
      }
    } else {
      debugPrint('User profile document does not exist.');
    }
  } catch (e) {
    debugPrint('Error loading user profile/syncing: $e');
  }
}
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

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'qazaCounts': {
            prayer: val,
          }
        }, SetOptions(merge: true));
      }
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

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'salatCompleted': {
            '${ymd}_$salat': val,
          }
        }, SetOptions(merge: true));
      }
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

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'prayerAlarms': {
            prayer: val,
          }
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error saving alarm state: $e');
    }
  }

  Future<void> _loadAppTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
      });
    } catch (e) {
      debugPrint('Error loading app theme: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAppTheme();
    _loadUserProfile();

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

    // Hook up real notification actions & cold start replay
    _setupNotificationListener();
  }

  @override
void dispose() {
  _staggerController.dispose();
  _pulseController.dispose();
  _floatController.dispose();
  _cloudsController.dispose();
  _realTimeTimer?.cancel();
  _positionStreamSub?.cancel(); // NEW — cancel live location stream
  super.dispose();
}

  // ===== LOCATION & TRACKING INITIALIZATION =====
Future<void> _initLocationAndTracking() async {
  // 1. Initial calculation using default coordinates (Dhaka)
  _updatePrayerTimes();

  // 2. Kick off continuous, real-time GPS tracking (replaces one-shot fetch)
  await _startLocationStream();

  // 3. Periodic timer to update countdown & time every 1 second
  _realTimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
    if (mounted) {
      _updatePrayerTimes();
    }
  });
}

// Requests permission, gets an immediate fix, then subscribes to a live
// position stream so location keeps updating in real time as the device
// moves (instead of only fetching once at app start).
Future<void> _startLocationStream() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) return;

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return;
  }
  if (permission == LocationPermission.deniedForever) return;

  const locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 100, // meters — only fires when the user has actually moved
  );

  // Cancel any previous subscription before starting a new one.
  await _positionStreamSub?.cancel();

  _positionStreamSub =
      Geolocator.getPositionStream(locationSettings: locationSettings).listen(
    (Position position) => _onPositionUpdate(position),
    onError: (e) => debugPrint("Location stream error: $e"),
  );

  // Also grab an immediate fix so we don't wait for the first stream event.
  try {
    final Position initial = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 8),
      ),
    );
    await _onPositionUpdate(initial);
  } catch (e) {
    debugPrint("Failed to get initial location: $e");
  }
}

// Called every time we get a new real-time GPS fix (initial + stream).
Future<void> _onPositionUpdate(Position position) async {
  if (!mounted) return;
  setState(() {
    _latitude = position.latitude;
    _longitude = position.longitude;
  });

  // Reverse geocode to get the current City name
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

  // Recalculate prayer times for the new position and re-sync notifications
  _updatePrayerTimes();
  _syncAlarms();
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
      // System notifications provide the alarm and its actions. Avoid a
      // duplicate in-app prayer prompt.
      if (diffSec <= 30 && !_triggeredAlarms.contains(alarmKey)) {
        _triggeredAlarms.add(alarmKey);
      }
    }

    // === Auto Qaza Calculation ===
    // A prayer is Qaza only after its own time window has ended while it is
    // still unchecked. Starting a prayer time must never mark that prayer as
    // missed. Isha remains valid until tomorrow's Fajr.
    final tomorrowForIsha = now.add(const Duration(days: 1));
    final tomorrowPrayerTimes = PrayerTimes(
      coordinates,
      DateComponents.from(tomorrowForIsha),
      params,
    );
    final Map<String, DateTime?> prayerWindowEnds = {
      'Fajr': _sunriseTime,
      'Dhuhr': _asrTime,
      'Asr': _maghribTime,
      'Maghrib': _ishaTime,
      'Isha': tomorrowPrayerTimes.fajr,
    };
    final ymd = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final List<String> fardPrayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    for (final sName in fardPrayers) {
      final windowEnd = prayerWindowEnds[sName];
      if (windowEnd == null) continue;
      final bool hasWindowEnded = now.isAfter(windowEnd);
      final bool isDone = _salatCompleted[sName] ?? false;
      if (hasWindowEnded && !isDone) {
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
      countdown = AppLocalizations.of(context)!.tr('any_moment');
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
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tomorrowPrayerTimes = PrayerTimes(
      Coordinates(_latitude, _longitude),
      DateComponents.from(tomorrow),
      CalculationMethod.karachi.getParameters()..madhab = Madhab.hanafi,
    );
    final windowEnds = <String, DateTime?>{
      'Fajr': _sunriseTime,
      'Sunrise': null,
      'Dhuhr': _asrTime,
      'Asr': _maghribTime,
      'Maghrib': _ishaTime,
      'Isha': tomorrowPrayerTimes.fajr,
    };
    for (final entry in allTimes.entries) {
      final pName = entry.key;
      final pTime = entry.value;
      final isEnabled = _prayerAlarms[pName] ?? false;
      if (isEnabled && pTime != null) {
        await NotificationService.instance.schedulePrayerAlarm(
          prayerName: pName,
          scheduledTime: pTime,
          windowEndTime: windowEnds[pName],
        );
      } else {
        await NotificationService.instance.cancelPrayerAlarm(pName);
      }
    }
  }

  void _setupNotificationListener() {
    NotificationService.instance.onPrayerAction = (prayerName, action, kind) async {
      if (action == PrayerNotificationAction.prayed) {
        setState(() {
          _salatCompleted[prayerName] = true;
        });
        await _saveSalatCompleted(prayerName, true);
        await NotificationService.instance.cancelEndOfWindowNudge(prayerName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Logged $prayerName as prayed. Prayer tracker updated.'),
              backgroundColor: const Color(0xFF1D3557),
            ),
          );
        }
      } else if (action == PrayerNotificationAction.snooze) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$prayerName alarm snoozed for ${NotificationService.instance.snoozeDurationMinutes} minutes.'),
              backgroundColor: const Color(0xFF1D3557),
            ),
          );
        }
      }
    };

    NotificationService.instance.drainPendingActions((prayerName, action, kind) async {
      if (action == PrayerNotificationAction.prayed) {
        setState(() {
          _salatCompleted[prayerName] = true;
        });
        await _saveSalatCompleted(prayerName, true);
        await NotificationService.instance.cancelEndOfWindowNudge(prayerName);
      } else if (action == PrayerNotificationAction.snooze) {
        // NotificationService schedules the next 20-minute alarm itself.
      }
    });
  }

  void _openNotificationCenter() {
    NotificationCenterModal.show(
      context,
      isDarkMode: _isDarkMode,
      onPrayed: (prayerName) async {
        setState(() {
          _salatCompleted[prayerName] = true;
        });
        await _saveSalatCompleted(prayerName, true);
        await NotificationService.instance.cancelEndOfWindowNudge(prayerName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Logged $prayerName as prayed. Prayer tracker updated.'),
              backgroundColor: const Color(0xFF1D3557),
            ),
          );
        }
      },
      onSnooze: (prayerName) async {
        await NotificationService.instance.snoozePrayerAlarm(prayerName: prayerName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$prayerName alarm snoozed for ${NotificationService.instance.snoozeDurationMinutes} minutes.'),
              backgroundColor: const Color(0xFF1D3557),
            ),
          );
        }
      },
      onNotificationTap: (item) {
        Navigator.pop(context);
        if (item.category == 'prayers') {
          setState(() => _currentIndex = 1);
        } else if (item.category == 'dhikr') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const DhikrCounterScreen()));
        } else if (item.category == 'zakat') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ZakatManagerScreen()));
        } else if (item.category == 'quran') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const QuranTrackerScreen()));
        } else if (item.category == 'events') {
          setState(() => _currentIndex = 2);
        } else if (item.category == 'sos') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencySosScreen()));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final double maxAppWidth = 430.0;
    final double appWidth = math.min(size.width, maxAppWidth);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF121212) : Colors.white,
      body: Center(
        child: Container(
          width: appWidth,
          height: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _isDarkMode ? const Color(0xFF121212) : Colors.white,
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
                    child: KeyedSubtree(
                      key: ValueKey('DashboardTab_$_currentIndex'),
                      child: _buildActiveTabContent(),
                    ),
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
                          color: _isDarkMode ? Colors.black : Colors.white,           // was Color(0xFF1E1E1E)
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
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Mosque icon
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: _isDarkMode
                                      ? Colors.white.withValues(alpha: 0.12)
                                      : AppColors.navyBlue.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.mosque_rounded,
                                  size: 38,
                                  color: _isDarkMode ? Colors.white : AppColors.navyBlue,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                 AppLocalizations.of(context)!.tr('prayer_time'),
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 13,
                                  letterSpacing: 3,
                                  color: _isDarkMode
                                      ? Colors.white70
                                      : AppColors.navyBlue.withValues(alpha: 0.5),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _alarmPrayerName,
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                  color: _isDarkMode ? Colors.white : AppColors.navyBlue,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'الله أكبر • الله أكبر',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  color: _isDarkMode
                                      ? Colors.white.withValues(alpha: 0.9)
                                      : AppColors.navyBlue.withValues(alpha: 0.7),
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                 '${AppLocalizations.of(context)!.tr("it_is_time_for")} $_alarmPrayerName ${AppLocalizations.of(context)!.tr("prayer_dot")}',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: _isDarkMode
                                      ? Colors.white70
                                      : AppColors.navyBlue.withValues(alpha: 0.55),
                                ),
                              ),
                              const SizedBox(height: 28),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => setState(() => _showAlarmOverlay = false),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isDarkMode
                                        ? const Color(0xFF1E3A5F)
                                        : AppColors.navyBlue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                     AppLocalizations.of(context)!.tr('dismiss'),
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
        color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
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
            _buildNavItem(0, Icons.home_rounded, AppLocalizations.of(context)!.tr('home')),
            _buildNavItem(1, Icons.access_time_rounded, AppLocalizations.of(context)!.tr('prayer')),
            _buildNavItem(2, Icons.calendar_month_rounded, AppLocalizations.of(context)!.tr('calendar')),
            _buildNavItem(3, Icons.auto_awesome_rounded, AppLocalizations.of(context)!.tr('assistant')),
            _buildNavItem(4, Icons.person_outline_rounded, AppLocalizations.of(context)!.tr('profile')),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final bool isSelected = _currentIndex == index;
    final Color activeColor = _isDarkMode ? Colors.white : AppColors.navyBlue;
    final Color inactiveColor = _isDarkMode ? Colors.white38 : AppColors.placeholder;

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
                    ? (_isDarkMode ? Colors.white.withValues(alpha: 0.15) : AppColors.dustyBlueTeal.withValues(alpha: 0.25))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                color: isSelected ? activeColor : inactiveColor,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
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
        return Theme(
          data: Theme.of(context).copyWith(
            brightness: _isDarkMode ? Brightness.dark : Brightness.light,
          ),
          child: PrayerTab(
            key: const ValueKey('PrayerTab'),
            latitude: _latitude,
            longitude: _longitude,
            locationName: _locationName,
            nextPrayerName: _nextPrayerName,
            liveCountdownStr: _liveCountdownStr,
            selectedPrayerScene: _selectedPrayerScene,
            salatCompleted: _salatCompleted,
            qazaCounts: _qazaCounts,
            prayerAlarms: _prayerAlarms,
            qazaCount: _qazaCount,
            pulseController: _pulseController,
            cloudsController: _cloudsController,
            onSceneSelected: (scene) => setState(() => _selectedPrayerScene = scene),
            onBack: () => setState(() => _currentIndex = 0),
            onSalatToggle: (salat, done) async {
              setState(() => _salatCompleted[salat] = done);
              await _saveSalatCompleted(salat, done);
              if (done) {
                await NotificationService.instance.cancelEndOfWindowNudge(salat);
              }
            },
            onQazaCountChange: (salat, newCount) {
              setState(() => _qazaCounts[salat] = newCount);
              _saveQazaCount(salat, newCount);
            },
            onAlarmToggle: (prayer, enabled) {
              setState(() => _prayerAlarms[prayer] = enabled);
              _saveAlarmState(prayer, enabled);
              _syncAlarms();
            },
          ),
        );
      case 2:
        return CalendarTab(
          key: const ValueKey('CalendarTab'),
          onOpenZakatCalculator: _showZakatCalculatorSheet,
          isDarkMode: _isDarkMode,
        );
      case 3:
        return AssistantTab(isDarkMode: _isDarkMode);
      case 4:
        return ProfileTab(
          key: const ValueKey('ProfileTab'),
          onLogout: widget.onLogout,
          isDarkMode: _isDarkMode,
          onThemeChanged: (isDark) async {
            setState(() {
              _isDarkMode = isDark;
            });
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('is_dark_mode', isDark);
            // update global app theme notifier so top-level MaterialApp updates
            appThemeNotifier.value = isDark;
          },
        );
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
                child: _buildSectionTitle(AppLocalizations.of(context)!.tr('islamic_wealth')),
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
            child: _buildSectionTitle(AppLocalizations.of(context)!.tr('worship')),
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
                      AppLocalizations.of(context)!.tr('assalamu_alaikum'),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _isDarkMode ? Colors.white70 : AppColors.navyBlue.withValues(alpha: 0.65),
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
  _userName,
  style: GoogleFonts.poppins(
    fontSize: 30,
    fontWeight: FontWeight.bold,
    color: _isDarkMode ? Colors.white : AppColors.navyBlue,
    letterSpacing: 0.5,
  ),
),
              ],
            ),
          ),
          // Interactive Notification Bell with real-time unread badge
          GestureDetector(
            onTap: _openNotificationCenter,
            child: Stack(
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
                ValueListenableBuilder<int>(
                  valueListenable:
                      NotificationService.instance.unreadCountNotifier,
                  builder: (context, count, _) {
                    if (count == 0) return const SizedBox.shrink();
                    return Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.coralOrange,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
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
                           AppLocalizations.of(context)!.tr('next_prayer'),
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
                      // Transparent analog clock — static (hour & minute hands only,
                      // tick marks at 12/3/6/9 only, no numbers, no pulse/float animation)
                      SizedBox(
                        width: 76,
                        height: 76,
                        child: CustomPaint(
                          painter: _AnalogClockPainter(
                            time: DateTime.now(),
                            prayerName: _nextPrayerName,
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
          color: _isDarkMode ? Colors.white : AppColors.navyBlue,
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
                   label: AppLocalizations.of(context)!.tr('zakat_calculator'),
                  iconPainter: _ZakatIconPainter(isDark: _isDarkMode),
                  onTap: _showZakatCalculatorSheet,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildFeatureCard(
                  icon: Icons.pets_rounded,
                   label: AppLocalizations.of(context)!.tr('qurbani_planner'),
                  iconPainter: _QurbaniIconPainter(isDark: _isDarkMode),
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
                   label: AppLocalizations.of(context)!.tr('hajj_umrah'),
                  iconPainter: _HajjIconPainter(isDark: _isDarkMode),
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
                   label: AppLocalizations.of(context)!.tr('inheritance'),
                  iconPainter: _InheritanceIconPainter(isDark: _isDarkMode),
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
                   label: AppLocalizations.of(context)!.tr('quran_tracker'),
                  iconPainter: _QuranIconPainter(isDark: _isDarkMode),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const QuranTrackerScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildFeatureCard(
                  icon: Icons.fingerprint_rounded,
                   label: AppLocalizations.of(context)!.tr('dhikr_counter'),
                  iconPainter: _DhikrIconPainter(isDark: _isDarkMode),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DhikrCounterScreen(isDarkMode: _isDarkMode),
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
                   label: AppLocalizations.of(context)!.tr('halal_scanner'),
                  iconPainter: _HalalIconPainter(isDark: _isDarkMode),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HalalScannerHomeScreen(isDarkMode: _isDarkMode),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildFeatureCard(
                  icon: Icons.health_and_safety_rounded,
                   label: AppLocalizations.of(context)!.tr('emergency_sos'),
                  iconPainter: _EmergencyIconPainter(isDark: _isDarkMode),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EmergencySosScreen(isDarkMode: _isDarkMode),
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
                  icon: Icons.crop_portrait_rounded,
                   label: AppLocalizations.of(context)!.tr('salat_guide'),
                  iconPainter: _SalatGuideIconPainter(isDark: _isDarkMode),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SalatGuideScreen(isDarkMode: _isDarkMode),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(child: SizedBox()), // reserved for a future Worship tile (e.g. Qibla Compass)
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
          color: _isDarkMode ? Colors.black : Colors.white,   // was Color(0xFF1E1E1E)
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _isDarkMode
                  ? Colors.black.withValues(alpha: 0.5)
                  : AppColors.navyBlue.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(
            color: _isDarkMode
                ? Colors.white.withValues(alpha: 0.16)        // was 0.12 — a bit brighter
                : AppColors.navyBlue.withValues(alpha: 0.22),
            width: 1.6,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isDarkMode
                    ? Colors.white.withValues(alpha: 0.16)    // was 0.12 — icon chip pops more
                    : AppColors.midTeal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isDarkMode
                      ? Colors.white.withValues(alpha: 0.30)  // was 0.2
                      : AppColors.midTeal.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: iconPainter != null
                  ? CustomPaint(painter: iconPainter)
                  : Icon(icon, color: _isDarkMode ? Colors.white : AppColors.navyBlue, size: 22),
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: _isDarkMode ? Colors.white : AppColors.navyBlue,
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
        color: _isDarkMode ? Colors.black : Colors.white,     // was Color(0xFF1E1E1E)
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _isDarkMode
                ? Colors.black.withValues(alpha: 0.5)
                : AppColors.navyBlue.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: _isDarkMode
              ? Colors.white.withValues(alpha: 0.16)          // was 0.12
              : AppColors.dustyBlueTeal.withValues(alpha: 0.12),
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
                    color: _isDarkMode ? Colors.white : AppColors.navyBlue,
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
                color: _isDarkMode ? Colors.white70 : AppColors.navyBlue.withValues(alpha: 0.7),
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
    final List<String> tabNames = [
      AppLocalizations.of(context)!.tr('home'),
      AppLocalizations.of(context)!.tr('prayer'),
      AppLocalizations.of(context)!.tr('calendar'),
      AppLocalizations.of(context)!.tr('assistant'),
      AppLocalizations.of(context)!.tr('profile'),
    ];
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
            '${tabNames[_currentIndex]} ${AppLocalizations.of(context)!.tr("coming_soon")}',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.navyBlue.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.tr('under_development'),
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
    _opacity = Tween<double>(begin: 0.25, end: 1.0).animate(
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
      ..color = const Color(0xFFFFE082).withValues(alpha: 0.9) // Bright glowing yellow-gold star
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
      ..color = Colors.white.withValues(alpha: 0.95)
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

    // 1. Draw Twinkling Stars — only for Fajr and Isha
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
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: Offset(w * 0.82, h * 0.22), radius: 32));
      canvas.drawCircle(Offset(w * 0.82, h * 0.22), 32, sunGlow);
      final sunCore = Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(w * 0.82, h * 0.22), 16, sunCore);
    }

    // 3. Draw a warm glow orb for Maghrib
    if (prayerName == 'Maghrib') {
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFF9966).withValues(alpha: 0.25),
            const Color(0xFFFF9966).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: Offset(w * 0.80, h * 0.25), radius: 38));
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

// ===== TRANSPARENT ANALOG CLOCK PAINTER =====
// Draws a minimalist analog clock face: transparent background, a thin
// outer ring, tick marks only at the 12 / 3 / 6 / 9 positions (no numerals),
// and hour + minute hands only (no second hand). Purely static per-frame —
// no built-in pulsing or scaling; the caller controls if/when it repaints.
class _AnalogClockPainter extends CustomPainter {
  final DateTime time;
  final String prayerName;

  _AnalogClockPainter({required this.time, required this.prayerName});

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = math.min(size.width, size.height) / 2;

    // Outer ring — subtle, transparent/glassy
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(center, radius - 1, ringPaint);

    // Tick marks only at 12, 3, 6, 9 — no digits drawn anywhere
    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    const List<double> tickAngles = [
      -math.pi / 2, // 12
      0, // 3
      math.pi / 2, // 6
      math.pi, // 9
    ];

    final double tickOuter = radius - 7;
    final double tickInner = radius - 14;
    for (final angle in tickAngles) {
      final Offset p1 = Offset(
        center.dx + tickOuter * math.cos(angle),
        center.dy + tickOuter * math.sin(angle),
      );
      final Offset p2 = Offset(
        center.dx + tickInner * math.cos(angle),
        center.dy + tickInner * math.sin(angle),
      );
      canvas.drawLine(p1, p2, tickPaint);
    }

    // Compute hand angles from the given time
    final double hourFraction = (time.hour % 12) / 12 + (time.minute / 60) / 12;
    final double minuteFraction = time.minute / 60;

    final double hourAngle = hourFraction * 2 * math.pi - math.pi / 2;
    final double minuteAngle = minuteFraction * 2 * math.pi - math.pi / 2;

    // Navy is not visible enough on the night card. Only Fajr and Isha use
    // a lighter navy-blue hour hand; every other prayer retains the navy design.
    final isNightPrayer = prayerName == 'Fajr' || prayerName == 'Isha';
    final double hourHandLen = radius * 0.5;
    final hourHandPaint = Paint()
      ..color = isNightPrayer ? const Color(0xFF7AB8E8) : AppColors.navyBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      Offset(
        center.dx + hourHandLen * math.cos(hourAngle),
        center.dy + hourHandLen * math.sin(hourAngle),
      ),
      hourHandPaint,
    );

    // Minute hand — longer & thinner — coral orange
    final double minuteHandLen = radius * 0.75;
    final minuteHandPaint = Paint()
      ..color = AppColors.coralOrange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      Offset(
        center.dx + minuteHandLen * math.cos(minuteAngle),
        center.dy + minuteHandLen * math.sin(minuteAngle),
      ),
      minuteHandPaint,
    );

    // Small center pivot dot
    final centerDotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 2.6, centerDotPaint);
  }

  @override
  bool shouldRepaint(covariant _AnalogClockPainter oldDelegate) {
    return oldDelegate.time.minute != time.minute ||
        oldDelegate.time.hour != time.hour ||
        oldDelegate.prayerName != prayerName;
  }
}

// ===== CUSTOM FEATURE ICON PAINTERS =====

// Zakat Calculator Icon
class _ZakatIconPainter extends CustomPainter {
  final bool isDark;
  _ZakatIconPainter({this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.9) : AppColors.navyBlue.withValues(alpha: 0.75)
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
  final bool isDark;
  _QurbaniIconPainter({this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.9) : AppColors.navyBlue.withValues(alpha: 0.75)
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
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.6)          // was AppColors.navyBlue.withValues(alpha: 0.6)
          : AppColors.navyBlue.withValues(alpha: 0.6)
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
  final bool isDark;
  _HajjIconPainter({this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.9) : AppColors.navyBlue.withValues(alpha: 0.75)
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
  final bool isDark;
  _InheritanceIconPainter({this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.9) : AppColors.navyBlue.withValues(alpha: 0.75)
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
  final bool isDark;
  _QuranIconPainter({this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.9) : AppColors.navyBlue.withValues(alpha: 0.75)
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
  final bool isDark;
  _DhikrIconPainter({this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.24;

    final Color baseColor = isDark ? Colors.white : AppColors.navyBlue;

    for (int i = 0; i < 4; i++) {
      final arcR = r * (0.4 + i * 0.22);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: arcR),
        -math.pi * 0.7,
        math.pi * 1.4,
        false,
        paint..color = baseColor.withValues(alpha: 0.65 - i * 0.1),   // was hardcoded navyBlue
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
  final bool isDark;
  _HalalIconPainter({this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.9) : AppColors.navyBlue.withValues(alpha: 0.75)
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

// Salat Guide Icon — Prayer Rug (Janamaz)
class _SalatGuideIconPainter extends CustomPainter {
  final bool isDark;
  _SalatGuideIconPainter({this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.9) : AppColors.navyBlue.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final rugW = size.width * 0.5;
    final rugH = size.height * 0.56;
    final rugTop = cy - rugH * 0.62;
    final rugBottom = cy + rugH * 0.5;

    // Outer rug border
    final outer = RRect.fromRectAndRadius(
      Rect.fromLTRB(cx - rugW / 2, rugTop, cx + rugW / 2, rugBottom),
      const Radius.circular(3),
    );
    canvas.drawRRect(outer, paint);

    // Inner border (rug trim)
    final innerPaint = Paint()
      ..color = paint.color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final inset = rugW * 0.12;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - rugW / 2 + inset, rugTop + inset,
            cx + rugW / 2 - inset, rugBottom - inset * 1.4),
        const Radius.circular(2),
      ),
      innerPaint,
    );

    // Mihrab arch motif — pointed arch near the top, pointing "toward the Qibla"
    final archW = rugW * 0.46;
    final archTopY = rugTop + inset * 1.6;
    final archBaseY = cy - rugH * 0.02;
    final archPaint = Paint()
      ..color = AppColors.midTeal.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final archPath = Path()
      ..moveTo(cx - archW / 2, archBaseY)
      ..lineTo(cx - archW / 2, archTopY + archW * 0.32)
      ..quadraticBezierTo(cx - archW / 2, archTopY, cx, archTopY)
      ..quadraticBezierTo(cx + archW / 2, archTopY, cx + archW / 2, archTopY + archW * 0.32)
      ..lineTo(cx + archW / 2, archBaseY);
    canvas.drawPath(archPath, archPaint);

    // Small finial dot at the peak of the arch
    canvas.drawCircle(Offset(cx, archTopY - 2), 1.6, Paint()..color = AppColors.coralOrange.withValues(alpha: 0.85));

    // Fringe / tassels along the bottom edge
    final fringePaint = Paint()
      ..color = paint.color.withValues(alpha: 0.55)
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    const tassels = 5;
    for (int i = 0; i < tassels; i++) {
      final x = (cx - rugW / 2) + (rugW / (tassels - 1)) * i;
      canvas.drawLine(Offset(x, rugBottom), Offset(x, rugBottom + 3.5), fringePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Emergency SOS Icon
class _EmergencyIconPainter extends CustomPainter {
  final bool isDark;
  _EmergencyIconPainter({this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final s = size.width * 0.16;

    final paint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.9) : AppColors.navyBlue.withValues(alpha: 0.75)
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
