import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/auth_header.dart'; // AppColors
import '../services/emergency_api_service.dart';
import '../services/emergency_group_service.dart';
import '../services/weather_service.dart';
import '../services/notification_service.dart';

class EmergencyContact {
  final TextEditingController nameController;
  final TextEditingController numberController;

  EmergencyContact({required String name, required String number})
      : nameController = TextEditingController(text: name),
        numberController = TextEditingController(text: number);

  Map<String, String> toMap() {
    return {'name': nameController.text, 'number': numberController.text};
  }

  void dispose() {
    nameController.dispose();
    numberController.dispose();
  }
}

class EmergencySosScreen extends StatefulWidget {
  final bool isDarkMode;

  const EmergencySosScreen({super.key, this.isDarkMode = false});

  @override
  State<EmergencySosScreen> createState() => _EmergencySosScreenState();
}

class _EmergencySosScreenState extends State<EmergencySosScreen> {
  int _tab = 0;
  static const _tabLabels = ['SOS', 'Medical', 'Maps', 'Group'];
  static const _tabIcons = [
    Icons.emergency_recording_rounded,
    Icons.medical_services_rounded,
    Icons.map_rounded,
    Icons.group_rounded,
  ];

  // ===== SOS ACTIVATION STATES =====
  bool _isSosTriggered = false;
  bool _isHolding = false;
  double _holdProgress = 0.0;
  Timer? _holdTimer;
  Timer? _cancelTimer;
  int _cancelCountdown = 5;
  bool _isCountingDown = false;
  bool _isOfflineSimulated = false;
  bool _isLowBatterySimulated = false;

  // Location details
  Position? _currentPosition;
  String _currentAddress = "Locating...";
  String _currentCountry = "Saudi Arabia";
  String _emergencyNumber = "997"; // Default KSA Red Crescent
  StreamSubscription<Position>? _positionStreamSubscription;

  // Active logs, offline queues, and incident history
  List<String> _activeSosLogs = [];
  final List<Map<String, dynamic>> _offlineQueue = [];
  List<Map<String, dynamic>> _incidentLogs = [];

  // ===== DYNAMIC EMERGENCY CONTACTS LIST =====
  List<EmergencyContact> _contacts = [];

  // ===== IN-APP ROUTE PLANNER CONTROLLERS =====
  final _routeOriginController = TextEditingController(text: "Al Mashair, Makkah");
  final _routeDestController = TextEditingController(text: "Kaaba, Al Haram, Makkah");
  final bool _isRouteActive = true;

  // ===== MEDICAL PROFILE DATA (CONTROLLERS) =====
  final _nameController = TextEditingController();
  final _passportController = TextEditingController();
  final _nationalityController = TextEditingController();
  final _bloodController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _conditionsController = TextEditingController();
  final _medsController = TextEditingController();
  final _groupNameController = TextEditingController();
  final _hotelController = TextEditingController();

  bool _isProfileEditing = false;

  // ===== GROUP TRACKING & PROTOCOLS =====
  bool _isGroupJoined = false;
  bool _isGroupLeader = false;
  final _groupCodeController = TextEditingController();
  StreamSubscription<List<Map<String, dynamic>>>? _groupMembersSubscription;
  StreamSubscription<Map<String, dynamic>?>? _groupSubscription;
  List<Map<String, dynamic>> _liveGroupMembers = [];
  double _groupRangeMeters = 1000;
  String _groupLeaderName = '';
  final Set<String> _geofenceAlertedMembers = {};
  EmergencyWeatherData? _weather;
  DateTime? _lastWeatherFetch;
  bool _weatherLoading = false;
  int _weatherPreviewIndex = -1;

  // Map variables
  final double _mapZoomScale = 1.0;

  // ===== HAJJ PLACES FOR GPS DISTANCE CALCULATIONS =====
  final List<Map<String, dynamic>> _medicalPoints = [
    {
      'name': 'Mina Emergency Clinic 4',
      'lat': 21.4172,
      'lng': 39.8821,
      'desc': 'Located near Jamarat Bridge, Zone A',
    },
    {
      'name': 'East Arafat General Hospital',
      'lat': 21.3533,
      'lng': 39.9839,
      'desc': 'Close to Mount Arafat pilgrim camp area',
    },
    {
      'name': 'Ajyad Emergency Hospital',
      'lat': 21.4192,
      'lng': 39.8286,
      'desc': 'Directly behind Makkah Grand Mosque (Haram)',
    },
    {
      'name': 'Al Haram Medical Clinic Madinah',
      'lat': 24.4672,
      'lng': 39.6111,
      'desc': 'Northern courtyard of the Prophet\'s Mosque',
    },
  ];

  List<Map<String, dynamic>> _sortedMedicalPoints = [];

  // Dynamic coordinates for mock group members relative to user
  List<Map<String, dynamic>> get _mockGroupMembers {
    final double uLat = _currentPosition?.latitude ?? 21.4225;
    final double uLng = _currentPosition?.longitude ?? 39.8262;

    if (_isGroupJoined) {
      return _liveGroupMembers
          .where((member) => member['latitude'] is num && member['longitude'] is num)
          .map((member) {
        final lat = (member['latitude'] as num).toDouble();
        final lng = (member['longitude'] as num).toDouble();
        final distance = Geolocator.distanceBetween(uLat, uLng, lat, lng);
        final outOfRange = distance > _groupRangeMeters;
        return {
          ...member,
          'lat': lat,
          'lng': lng,
          'dist': distance / 1000,
          'battery': member['battery'] ?? 0,
          'status': outOfRange ? 'OUT OF RANGE' : 'SAFE',
        };
      }).toList();
    }

    final List<Map<String, dynamic>> members = [
      {'name': 'Ahmed (Leader)', 'lat': 21.4180, 'lng': 39.8830, 'battery': 88, 'status': 'SAFE'},
      {'name': 'Fatimah', 'lat': 21.4210, 'lng': 39.8270, 'battery': 92, 'status': 'SAFE'},
      {'name': 'Yusuf', 'lat': 21.3550, 'lng': 39.9850, 'battery': 12, 'status': '⚠️ OUT OF BOUNDS / GEOFENCE BREACH'},
    ];

    for (var m in members) {
      final double dist = Geolocator.distanceBetween(uLat, uLng, m['lat'], m['lng']) / 1000.0;
      m['dist'] = dist;
    }
    return members;
  }

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _loadIncidentLogs();
    _initLocationTracking();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _cancelTimer?.cancel();
    _positionStreamSubscription?.cancel();
    _groupMembersSubscription?.cancel();
    _groupSubscription?.cancel();

    _nameController.dispose();
    _passportController.dispose();
    _nationalityController.dispose();
    _bloodController.dispose();
    _allergiesController.dispose();
    _conditionsController.dispose();
    _medsController.dispose();
    _groupNameController.dispose();
    _hotelController.dispose();
    _groupCodeController.dispose();

    for (var contact in _contacts) {
      contact.dispose();
    }
    super.dispose();
  }

  // ===== DATA STORAGE =====
  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('sos_name') ?? "Muhammad Ali";
      _passportController.text = prefs.getString('sos_passport') ?? "K98765432";
      _nationalityController.text = prefs.getString('sos_nationality') ?? "Indonesian";
      _bloodController.text = prefs.getString('sos_blood') ?? "O+";
      _allergiesController.text = prefs.getString('sos_allergies') ?? "Penicillin, Pollen";
      _conditionsController.text = prefs.getString('sos_conditions') ?? "Hypertension";
      _medsController.text = prefs.getString('sos_meds') ?? "Lisinopril 10mg daily";
      _groupNameController.text = prefs.getString('sos_group_name') ?? "Garuda Hajj Cluster 4";
      _hotelController.text = prefs.getString('sos_hotel') ?? "Al Kiswah Towers, Makkah";
      _isGroupJoined = prefs.getBool('sos_is_group_joined') ?? false;
      _isGroupLeader = prefs.getBool('sos_is_group_leader') ?? false;
      _groupCodeController.text = prefs.getString('sos_group_code') ?? '';

      // Load contacts json list
      final String? contactsJson = prefs.getString('sos_contacts_json');
      if (contactsJson != null) {
        final List<dynamic> decoded = jsonDecode(contactsJson);
        _contacts = decoded.map((item) => EmergencyContact(
          name: item['name'] ?? '',
          number: item['number'] ?? '',
        )).toList();
      } else {
        // Graceful migration from old single contact keys
        final String? oldName = prefs.getString('sos_contact_name');
        final String? oldNum = prefs.getString('sos_contact_number');
        if (oldName != null && oldNum != null) {
          _contacts = [EmergencyContact(name: oldName, number: oldNum)];
        } else {
          // Never send a real emergency message to demonstration numbers.
          _contacts = [];
        }
      }
    });
    if (_isGroupJoined && _groupCodeController.text.trim().isNotEmpty) {
      _startGroupTracking();
    }
  }

  Future<void> _saveProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sos_name', _nameController.text);
    await prefs.setString('sos_passport', _passportController.text);
    await prefs.setString('sos_nationality', _nationalityController.text);
    await prefs.setString('sos_blood', _bloodController.text);
    await prefs.setString('sos_allergies', _allergiesController.text);
    await prefs.setString('sos_conditions', _conditionsController.text);
    await prefs.setString('sos_meds', _medsController.text);
    await prefs.setString('sos_group_name', _groupNameController.text);
    await prefs.setString('sos_hotel', _hotelController.text);
    await prefs.setBool('sos_is_group_joined', _isGroupJoined);
    await prefs.setBool('sos_is_group_leader', _isGroupLeader);
    await prefs.setString('sos_group_code', _groupCodeController.text.trim().toUpperCase());

    // Save serialized contacts list
    final List<Map<String, String>> serializedContacts = _contacts.map((c) => c.toMap()).toList();
    await prefs.setString('sos_contacts_json', jsonEncode(serializedContacts));

    setState(() => _isProfileEditing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile card and emergency contacts saved.')),
    );
  }

  Future<void> _loadIncidentLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? logJson = prefs.getString('sos_incident_logs');
    if (logJson != null) {
      setState(() {
        _incidentLogs = List<Map<String, dynamic>>.from(jsonDecode(logJson));
      });
    }
  }

  Future<void> _saveIncidentLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sos_incident_logs', jsonEncode(_incidentLogs));
  }

  // ===== GEOLOCATION =====
  Future<void> _initLocationTracking() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _currentAddress = "Location services disabled");
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _currentAddress = "Location permission denied");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _currentAddress = "Location permissions permanently denied");
        return;
      }

      // Get current position
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        _updateLocationInfo(pos);
      } catch (e) {
        debugPrint("Error fetching coordinates: $e");
      }

      // Continuous location stream — keeps GPS card live in real time
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((Position position) {
        if (mounted) {
          _updateLocationInfo(position);
          _publishGroupLocation(position);
          if (_isSosTriggered && !_isOfflineSimulated) {
            EmergencyApiService.instance.updateLiveLocation(
              latitude: position.latitude,
              longitude: position.longitude,
              emergencyId: "SOS_${position.timestamp.millisecondsSinceEpoch}",
            );
            setState(() {
              _activeSosLogs.add("[${DateTime.now().toLocal().toString().substring(11, 19)}] Live GPS update: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}");
            });
          }
        }
      });
    } catch (e) {
      debugPrint("Geolocator platform channel error (test simulation fallback): $e");
      setState(() {
        _currentPosition = Position(
          longitude: 39.8262,
          latitude: 21.4225,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 277.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );
        _currentAddress = "Al Haram, Makkah, Saudi Arabia";
        _currentCountry = "Saudi Arabia";
        _emergencyNumber = "997";
      });
      _recalculateMedicalDistances(_currentPosition!);
    }
  }

  Future<void> _updateLocationInfo(Position pos) async {
    setState(() {
      _currentPosition = pos;
    });

    _recalculateMedicalDistances(pos);

    try {
      final geocoding = Geocoding();
      final placemarks = await geocoding.placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final pm = placemarks.first;
        setState(() {
          _currentAddress = "${pm.street ?? ''}, ${pm.locality ?? ''}, ${pm.country ?? ''}";
          _currentCountry = pm.country ?? "Saudi Arabia";
          _updateEmergencyNumber(pm.country);
        });
      }
    } catch (e) {
      setState(() {
        _currentAddress = "Coordinates: ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}";
      });
    }
  }

  Future<void> _refreshWeather(Position position, {bool force = false}) async {
    if (_weatherLoading || (!force && _lastWeatherFetch != null && DateTime.now().difference(_lastWeatherFetch!) < const Duration(minutes: 20))) return;
    setState(() => _weatherLoading = true);
    try {
      final weather = await WeatherService.instance.current(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() {
        _weather = weather;
        _lastWeatherFetch = DateTime.now();
      });
    } catch (error) {
      debugPrint('[Weather] $error');
    } finally {
      if (mounted) setState(() => _weatherLoading = false);
    }
  }

  void _updateEmergencyNumber(String? country) {
    if (country == null) return;
    final cName = country.toLowerCase();
    setState(() {
      if (cName.contains("saudi") || cName.contains("arabia")) {
        _emergencyNumber = "997";
      } else if (cName.contains("united states") || cName.contains("america") || cName.contains('canada')) {
        _emergencyNumber = "911";
      } else if (cName.contains("united kingdom") || cName.contains('bangladesh') || cName.contains('malaysia') || cName.contains('singapore')) {
        _emergencyNumber = "999";
      } else if (cName.contains("turkey") || cName.contains('türkiye') || cName.contains('indonesia') || cName.contains('india') || cName.contains('pakistan') || cName.contains('united arab emirates') || cName.contains('qatar') || cName.contains('oman') || cName.contains('kuwait') || cName.contains('bahrain') || cName.contains('jordan') || cName.contains('egypt') || cName.contains('morocco') || cName.contains('germany') || cName.contains('france') || cName.contains('italy') || cName.contains('spain') || cName.contains('netherlands') || cName.contains('sweden') || cName.contains('norway') || cName.contains('australia') || cName.contains('new zealand') || cName.contains('japan') || cName.contains('south korea') || cName.contains('china')) {
        _emergencyNumber = "112";
      } else {
        _emergencyNumber = "112";
      }
    });
  }

  void _recalculateMedicalDistances(Position userPos) {
    List<Map<String, dynamic>> pointsWithDistance = [];
    for (var point in _medicalPoints) {
      final double distanceInMeters = Geolocator.distanceBetween(
        userPos.latitude,
        userPos.longitude,
        point['lat'],
        point['lng'],
      );
      pointsWithDistance.add({
        ...point,
        'distance': distanceInMeters / 1000.0,
      });
    }
    pointsWithDistance.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
    setState(() {
      _sortedMedicalPoints = pointsWithDistance;
    });
  }

  // ===== SOS ACTIVATION FLOW =====
  void _startHoldTimer() {
    setState(() {
      _isHolding = true;
      _holdProgress = 0.0;
    });
    const tick = Duration(milliseconds: 50);
    int elapsed = 0;
    _holdTimer = Timer.periodic(tick, (timer) {
      elapsed += 50;
      setState(() {
        _holdProgress = elapsed / 2000.0; // 2 seconds hold time
      });
      if (elapsed >= 2000) {
        timer.cancel();
        _isHolding = false;
        _initiateSosCountdown();
      }
    });
  }

  void _cancelHoldTimer() {
    _holdTimer?.cancel();
    setState(() {
      _isHolding = false;
      _holdProgress = 0.0;
    });
  }

  void _initiateSosCountdown() {
    setState(() {
      _isCountingDown = true;
      _cancelCountdown = 5;
      _activeSosLogs = [
        "[${DateTime.now().toLocal().toString().substring(11, 19)}] SOS Triggered. Waiting 5s auto-cancel..."
      ];
    });

    _cancelTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cancelCountdown > 1) {
        setState(() {
          _cancelCountdown--;
        });
      } else {
        timer.cancel();
        setState(() {
          _isCountingDown = false;
        });
        _fireSosAlert();
      }
    });
  }

  void _cancelSosCountdown() {
    _cancelTimer?.cancel();
    setState(() {
      _isCountingDown = false;
      _isSosTriggered = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SOS canceled during countdown.')),
    );
  }

  Future<void> _fireSosAlert() async {
    setState(() {
      _isSosTriggered = true;
    });

    final double lat = _currentPosition?.latitude ?? 21.4225;
    final double lng = _currentPosition?.longitude ?? 39.8262;
    final String locationLink = "https://maps.google.com/?q=$lat,$lng";

    NotificationService.instance.showCustomNotification(
      id: 9999,
      title: "SOS ACTIVATED",
      body: "All emergency contacts and group leaders have been notified.",
      category: 'sos',
      targetRoute: '/sos',
    );

    _activeSosLogs.add("[${DateTime.now().toLocal().toString().substring(11, 19)}] Gathering GPS coordinates: $lat, $lng");
    _activeSosLogs.add("[${DateTime.now().toLocal().toString().substring(11, 19)}] Loading medical profile and ${_contacts.length} emergency contacts...");

    final profile = {
      'name': _nameController.text,
      'passport': _passportController.text,
      'nationality': _nationalityController.text,
      'bloodType': _bloodController.text,
      'allergies': _allergiesController.text,
      'conditions': _conditionsController.text,
      'meds': _medsController.text,
      'group': _groupNameController.text,
      'hotel': _hotelController.text,
    };

    final contacts = _contacts.map((c) => c.toMap()).toList();

    if (_isLowBatterySimulated) {
      _activeSosLogs.add("[${DateTime.now().toLocal().toString().substring(11, 19)}] ⚠️ BATTERY CRITICALLY LOW! Auto-sending final location link before device shutdown.");
    }

    if (_isOfflineSimulated) {
      _activeSosLogs.add("[${DateTime.now().toLocal().toString().substring(11, 19)}] ❌ Offline Mode. Queueing SOS payload locally.");
      _offlineQueue.add({
        'timestamp': DateTime.now().toIso8601String(),
        'lat': lat,
        'lng': lng,
        'profile': profile,
        'contacts': contacts,
        'link': locationLink,
      });
      _activeSosLogs.add("[${DateTime.now().toLocal().toString().substring(11, 19)}] 💬 Launching SMS fallback protocols...");
      _launchSmsFallback(locationLink);
    } else {
      _activeSosLogs.add("[${DateTime.now().toLocal().toString().substring(11, 19)}] 🌐 Connection OK. Contacting DeenMate Emergency API...");

      final success = await EmergencyApiService.instance.triggerEmergencySos(
        latitude: lat,
        longitude: lng,
        medicalProfile: profile,
        emergencyContacts: contacts,
        isSilent: false,
        groupLeaderId: _isGroupJoined ? _groupCodeController.text.trim().toUpperCase() : null,
      );

      if (success) {
        _activeSosLogs.add("[${DateTime.now().toLocal().toString().substring(11, 19)}] ✅ Broadcast successful. Group leader notified via server push.");
      } else {
        _activeSosLogs.add("[${DateTime.now().toLocal().toString().substring(11, 19)}] ⚠️ API request failed. Falling back to cellular SMS...");
        _launchSmsFallback(locationLink);
      }
    }

    final newIncident = {
      'id': 'INC_${DateTime.now().millisecondsSinceEpoch}',
      'timestamp': DateTime.now().toIso8601String(),
      'type': 'Standard SOS',
      'lat': lat,
      'lng': lng,
      'address': _currentAddress,
      'resolved': false,
      'resolvedTime': null,
    };
    setState(() {
      _incidentLogs.insert(0, newIncident);
    });
    _saveIncidentLogs();
  }

  Future<void> _launchSmsFallback(String locationLink) async {
    for (var contact in _contacts) {
      final phone = contact.numberController.text.trim();
      final name = contact.nameController.text.trim();
      final message = "DEENMATE EMERGENCY SOS!\nI need help. My medical profile is attached to this account. My current GPS location: $locationLink";
      final uri = Uri(
        scheme: 'sms',
        path: phone,
        queryParameters: {'body': message},
      );
      // Try the intent directly. canLaunchUrl may report false on Android
      // even when an SMS app exists, due to package visibility rules.
      if (phone.isNotEmpty && await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        setState(() {
          _activeSosLogs.add("[${DateTime.now().toLocal().toString().substring(11, 19)}] 📲 SMS draft launched to $name ($phone)");
        });
      } else {
        setState(() {
          _activeSosLogs.add("[${DateTime.now().toLocal().toString().substring(11, 19)}] ❌ SMS Launcher failed for $name.");
        });
      }
    }
  }

  Future<void> _deactivateSos() async {
    final double lat = _currentPosition?.latitude ?? 21.4225;
    final double lng = _currentPosition?.longitude ?? 39.8262;

    setState(() {
      _isSosTriggered = false;
      _activeSosLogs.add("[${DateTime.now().toLocal().toString().substring(11, 19)}] SOS Deactivated. Broadcasting safe status...");
    });

    if (!_isOfflineSimulated) {
      await EmergencyApiService.instance.deactivateEmergencySos(
        emergencyId: "SOS_ACTIVE",
        latitude: lat,
        longitude: lng,
      );
    }

    NotificationService.instance.showCustomNotification(
      id: 9998,
      title: "Status Safe",
      body: "An 'I am Safe' broadcast has been sent to your emergency contacts.",
      category: 'sos',
      targetRoute: '/sos',
    );

    if (_incidentLogs.isNotEmpty && !_incidentLogs.first['resolved']) {
      setState(() {
        _incidentLogs.first['resolved'] = true;
        _incidentLogs.first['resolvedTime'] = DateTime.now().toIso8601String();
      });
      _saveIncidentLogs();
    }

    // Launch WhatsApp/SMS broadcast directly
    for (var contact in _contacts) {
      final phone = contact.numberController.text.trim();
      final safeMsg = "Alhamdulillah, the danger has passed and I am safe now. Thank you for your support.";
      if (phone.isEmpty) continue;
      final uri = Uri(
        scheme: 'sms',
        path: phone,
        queryParameters: {'body': safeMsg},
      );
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _syncOfflineQueue() {
    if (_offlineQueue.isEmpty) return;
    setState(() {
      _activeSosLogs.add("[${DateTime.now().toLocal().toString().substring(11, 19)}] 🔄 Syncing ${_offlineQueue.length} buffered offline SOS alerts...");
    });

    for (var queued in _offlineQueue) {
      EmergencyApiService.instance.triggerEmergencySos(
        latitude: queued['lat'],
        longitude: queued['lng'],
        medicalProfile: queued['profile'],
        emergencyContacts: queued['contacts'],
        isSilent: false,
        groupLeaderId: _isGroupJoined ? _groupCodeController.text.trim().toUpperCase() : null,
      );
    }
    setState(() {
      _offlineQueue.clear();
      _activeSosLogs.add("[${DateTime.now().toLocal().toString().substring(11, 19)}] ✅ Offline queue synced.");
    });
  }

  Future<void> _makeCall(String phone) async {
    final uri = Uri.parse("tel:$phone");
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No phone application is available on this device.')),
        );
      }
    } catch (error) {
      debugPrint('[Emergency SOS] Could not open phone dialer: $error');
    }
  }

  // ===== GROUP CODE GENERATION =====
  Future<void> _generateGroupCode() async {
    try {
      final code = await EmergencyGroupService.instance.createGroup(
        leaderName: _nameController.text,
        rangeMeters: _groupRangeMeters,
      );
      if (!mounted) return;
      setState(() {
        _groupCodeController.text = code;
        _isGroupJoined = true;
        _isGroupLeader = true;
        _groupLeaderName = _nameController.text;
      });
      await _saveProfileData();
      _startGroupTracking();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Group "$code" created. Share this code with members.')),
      );
    } catch (error) {
      _showGroupError(error);
    }
  }

  Future<void> _joinGroup() async {
    final code = _groupCodeController.text.trim().toUpperCase();
    if (code.isEmpty) return;
    try {
      await EmergencyGroupService.instance.joinGroup(
        code: code,
        memberName: _nameController.text,
      );
      if (!mounted) return;
      setState(() {
        _groupCodeController.text = code;
        _isGroupJoined = true;
        _isGroupLeader = false;
      });
      await _saveProfileData();
      _startGroupTracking();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Joined group $code. Live tracking is active.')),
      );
    } catch (error) {
      _showGroupError(error);
    }
  }

  void _startGroupTracking() {
    final code = _groupCodeController.text.trim().toUpperCase();
    if (code.isEmpty) return;
    _groupMembersSubscription?.cancel();
    _groupSubscription?.cancel();
    _groupMembersSubscription = EmergencyGroupService.instance.members(code).listen((members) {
      if (!mounted) return;
      setState(() => _liveGroupMembers = members);
      _checkGroupRange();
    }, onError: _showGroupError);
    _groupSubscription = EmergencyGroupService.instance.group(code).listen((group) {
      if (!mounted || group == null) return;
      setState(() {
        _groupRangeMeters = (group['rangeMeters'] as num?)?.toDouble() ?? 1000;
        _groupLeaderName = group['leaderName'] as String? ?? '';
      });
    }, onError: _showGroupError);
    if (_currentPosition != null) _publishGroupLocation(_currentPosition!);
  }

  void _publishGroupLocation(Position position) {
    if (!_isGroupJoined || _isOfflineSimulated) return;
    EmergencyGroupService.instance.updateMyLocation(
      code: _groupCodeController.text.trim().toUpperCase(),
      latitude: position.latitude,
      longitude: position.longitude,
    ).catchError(_showGroupError);
    _checkGroupRange();
  }

  void _checkGroupRange() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || _currentPosition == null) return;
    for (final member in _mockGroupMembers) {
      final id = member['id'] as String?;
      if (id == null || id == userId) continue;
      final isOut = member['status'] == 'OUT OF RANGE';
      if (isOut && _geofenceAlertedMembers.add(id)) {
        NotificationService.instance.showCustomNotification(
          id: id.hashCode & 0x7fffffff,
          title: 'Group distance alert',
          body: '${member['name']} is outside the ${(_groupRangeMeters / 1000).toStringAsFixed(1)} km safety range.',
          category: 'sos',
          targetRoute: '/sos',
        );
      } else if (!isOut) {
        _geofenceAlertedMembers.remove(id);
      }
    }
  }

  void _showGroupError(Object error) {
    debugPrint('[Emergency group] $error');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
    );
  }

  Future<void> _leaveGroup() async {
    final code = _groupCodeController.text.trim().toUpperCase();
    Object? cloudError;
    try {
      if (code.isNotEmpty) await EmergencyGroupService.instance.leaveGroup(code);
    } catch (error) {
      // Local leave must still succeed; a failed cloud delete should not trap
      // a user in a group after going offline or losing Firebase permission.
      cloudError = error;
      debugPrint('[Emergency group] Could not remove cloud membership: $error');
    } finally {
      _groupMembersSubscription?.cancel();
      _groupSubscription?.cancel();
      if (!mounted) return;
      setState(() {
        _isGroupJoined = false;
        _isGroupLeader = false;
        _groupCodeController.clear();
        _groupLeaderName = '';
        _liveGroupMembers = [];
        _geofenceAlertedMembers.clear();
      });
      await _saveProfileData();
      if (cloudError != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You left this device. Cloud membership will be removed when Firebase access is restored.')),
        );
      }
    }
  }

  // ===== UI BUILDING =====
  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDarkMode;
    final primaryBg = isDark ? const Color(0xFF121212) : const Color(0xFFF7F7F5);
    final textThemeColor = isDark ? Colors.white70 : AppColors.navyBlue;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      color: const Color(0xFFE8E8E8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Scaffold(
            backgroundColor: primaryBg,
            body: SafeArea(
              child: Column(
                children: [
                  _buildHeader(textThemeColor),
                  const SizedBox(height: 12),
                  _buildTabBar(cardBg, textThemeColor),
                  Expanded(
                    child: _buildTabContent(primaryBg, cardBg, textThemeColor),
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
  Widget _buildHeader(Color textColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFD32F2F),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Emergency SOS',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Text(
                  'Live panic trigger & critical care',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: textColor.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== TAB BAR =====
  Widget _buildTabBar(Color bg, Color activeColor) {
    final cardBg = widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final isDark = widget.isDarkMode;

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
                            : (isDark ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.4))),
                    const SizedBox(height: 2),
                    Text(_tabLabels[i],
                        style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: active
                                ? Colors.white
                                : (isDark ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.4)))),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabContent(Color primaryBg, Color cardBg, Color textThemeColor) {
    switch (_tab) {
      case 0:
        return _buildSosTriggerTab(primaryBg, cardBg, textThemeColor);
      case 1:
        return _buildMedicalProfileTab(cardBg, textThemeColor);
      case 2:
        return _buildGuidesAndContactsTab(cardBg, textThemeColor);
      case 3:
        return _buildGroupHubTab(cardBg, textThemeColor);
      default:
        return _buildSosTriggerTab(primaryBg, cardBg, textThemeColor);
    }
  }

  _WeatherVisual _resolvedWeatherVisual() {
    if (_weatherPreviewIndex >= 0) return _WeatherVisual.values[_weatherPreviewIndex];
    final weather = _weather;
    final now = DateTime.now();
    if (weather == null) return _WeatherVisual.sunny;
    if (weather.isRainy) return _WeatherVisual.rain;
    if (weather.isCloudy) return _WeatherVisual.cloudy;
    if (!weather.isDay) return _WeatherVisual.night;
    if (weather.sunrise != null && now.difference(weather.sunrise!).abs() < const Duration(minutes: 50)) return _WeatherVisual.sunrise;
    if (weather.sunset != null && now.difference(weather.sunset!).abs() < const Duration(minutes: 50)) return _WeatherVisual.sunset;
    if (now.hour >= 12 && now.hour < 17) return _WeatherVisual.afternoon;
    return _seasonFor(now.month, _currentPosition?.latitude ?? 0);
  }

  _WeatherVisual _seasonFor(int month, double latitude) {
    final northern = latitude >= 0;
    final adjustedMonth = northern ? month : ((month + 5) % 12) + 1;
    if (adjustedMonth == 12 || adjustedMonth <= 2) return _WeatherVisual.winter;
    if (adjustedMonth <= 5) return _WeatherVisual.spring;
    if (adjustedMonth <= 8) return _WeatherVisual.summer;
    return _WeatherVisual.autumn;
  }

  Widget _buildWeatherTab(Color cardBg, Color textColor) {
    final visual = _resolvedWeatherVisual();
    final weather = _weather;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text('Live weather safety', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 4),
        Text('Weather matched to your GPS position. Visual conditions animate in real time.', style: GoogleFonts.inter(fontSize: 11, color: textColor.withValues(alpha: .6))),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 245,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _AnimatedWeatherBackdrop(visual: visual, darkMode: widget.isDarkMode),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: .22), borderRadius: BorderRadius.circular(20)),
                        child: Text(_weatherPreviewIndex >= 0 ? 'PREVIEW MODE' : 'LIVE • $_currentCountry', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                      const Spacer(),
                      Text(_weatherVisualName(visual), style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, shadows: const [Shadow(color: Colors.black54, blurRadius: 8)])),
                      Text(weather == null ? (_weatherLoading ? 'Getting weather…' : 'Weather unavailable') : '${weather.temperature.toStringAsFixed(0)}°C  •  Feels ${weather.feelsLike.toStringAsFixed(0)}°C  •  Wind ${weather.windSpeed.toStringAsFixed(0)} km/h', style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: .92))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Try every visual', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 4),
            Text('Use Preview next to check rain, clouds, sun, night, sunrise, sunset, afternoon and all seasons.', style: GoogleFonts.inter(fontSize: 10.5, color: textColor.withValues(alpha: .6))),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => setState(() => _weatherPreviewIndex = (_weatherPreviewIndex + 1) % _WeatherVisual.values.length), icon: const Icon(Icons.visibility_rounded), label: const Text('PREVIEW NEXT'))),
              const SizedBox(width: 8),
              TextButton.icon(onPressed: () { setState(() => _weatherPreviewIndex = -1); if (_currentPosition != null) _refreshWeather(_currentPosition!, force: true); }, icon: const Icon(Icons.my_location_rounded), label: const Text('LIVE')),
            ]),
          ]),
        ),
      ],
    );
  }

  String _weatherVisualName(_WeatherVisual visual) => switch (visual) {
    _WeatherVisual.rain => 'Rainy', _WeatherVisual.cloudy => 'Cloudy', _WeatherVisual.sunny => 'Sunny', _WeatherVisual.night => 'Night', _WeatherVisual.sunrise => 'Sunrise', _WeatherVisual.sunset => 'Sunset', _WeatherVisual.afternoon => 'Afternoon', _WeatherVisual.summer => 'Summer', _WeatherVisual.winter => 'Winter', _WeatherVisual.autumn => 'Autumn', _WeatherVisual.spring => 'Spring',
  };

  // ===== TAB 1: SOS TRIGGER PANEL =====
  Widget _buildSosTriggerTab(Color mainBg, Color containerBg, Color textColor) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (_isCountingDown) _buildCountdownCard(containerBg, textColor),

        if (!_isCountingDown) ...[
          _buildPanicButtonSection(textColor),
          const SizedBox(height: 20),
          _buildLiveLocationCard(containerBg, textColor),
          const SizedBox(height: 14),
          if (_isSosTriggered) _buildSosLogsCard(containerBg, textColor),
        ]
      ],
    );
  }

  Widget _buildPanicButtonSection(Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      alignment: Alignment.center,
      child: Column(
        children: [
          Text(
            _isSosTriggered ? "EMERGENCY BROADCAST ACTIVE" : "PRESS & HOLD TO TRIGGER SOS",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: _isSosTriggered
                  ? const Color(0xFFD32F2F)
                  : textColor.withValues(alpha: 0.8),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTapDown: (_) {
              if (!_isSosTriggered) _startHoldTimer();
            },
            onTapUp: (_) {
              if (!_isSosTriggered) _cancelHoldTimer();
            },
            onTapCancel: () {
              if (!_isSosTriggered) _cancelHoldTimer();
            },
            onTap: () {
              if (_isSosTriggered) {
                _deactivateSos();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please hold the button down for 2 seconds to confirm SOS trigger.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _isSosTriggered ? 210 : 180,
                  height: _isSosTriggered ? 210 : 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isSosTriggered
                        ? const Color(0xFFD32F2F).withValues(alpha: 0.15)
                        : (_isHolding
                            ? AppColors.midTeal.withValues(alpha: 0.15)
                            : Colors.grey.withValues(alpha: 0.05)),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _isSosTriggered
                          ? [const Color(0xFFD32F2F), const Color(0xFFB71C1C)]
                          : (_isHolding
                              ? [AppColors.midTeal, const Color(0xFF387A76)]
                              : [const Color(0xFFE57373), const Color(0xFFD32F2F)]),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isSosTriggered
                            ? const Color(0xFFD32F2F).withValues(alpha: 0.4)
                            : Colors.black.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isSosTriggered ? Icons.gpp_maybe_rounded : Icons.warning_amber_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isSosTriggered ? "I'M SAFE\nNOW" : "SOS",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isHolding)
                  SizedBox(
                    width: 162,
                    height: 162,
                    child: CircularProgressIndicator(
                      value: _holdProgress,
                      strokeWidth: 6,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      backgroundColor: Colors.transparent,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_isSosTriggered)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      "Click once when safe to broadcast recovery",
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              "Holding avoids accidental activations in dense crowds",
              style: GoogleFonts.inter(
                fontSize: 11,
                color: textColor.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCountdownCard(Color containerBg, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        children: [
          const Icon(Icons.notifications_active_rounded, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            "Sending Emergency SOS Alert in",
            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 10),
          Text(
            "$_cancelCountdown",
            style: GoogleFonts.poppins(fontSize: 72, fontWeight: FontWeight.w900, color: Colors.red),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.cancel_outlined),
              label: Text("CANCEL NOW", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              onPressed: _cancelSosCountdown,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Pre-filled contacts & authorities will receive GPS coordinates",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 11, color: textColor.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveLocationCard(Color containerBg, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.midTeal.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
              ),
              const Icon(Icons.my_location_rounded, color: AppColors.midTeal, size: 20),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      "Real-time GPS Status",
                      style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "LIVE",
                      style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _currentAddress,
                  style: GoogleFonts.inter(fontSize: 11.5, color: textColor.withValues(alpha: 0.7), height: 1.3),
                ),
                if (_currentPosition != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    "Coordinates: ${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)} (Acc: ${_currentPosition!.accuracy.toStringAsFixed(1)}m)",
                    style: GoogleFonts.robotoMono(fontSize: 10, color: AppColors.midTeal, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSosLogsCard(Color containerBg, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Live Dispatch Log (Real-time)",
                style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.red[800]),
              ),
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.red)),
              ),
            ],
          ),
          const Divider(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _activeSosLogs.length,
            itemBuilder: (context, idx) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  _activeSosLogs[idx],
                  style: GoogleFonts.robotoMono(fontSize: 10.5, color: textColor.withValues(alpha: 0.8), height: 1.3),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ===== TAB 2: MEDICAL PROFILE =====
  Widget _buildMedicalProfileTab(Color cardBg, Color textColor) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: widget.isDarkMode
                ? const LinearGradient(
                    colors: [Color(0xFF303030), Color(0xFF1E1E1E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFFE53935), Color(0xFFC62828)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.emergency_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "MEDICAL EMERGENCY CARD",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.nfc_rounded, color: Colors.white60, size: 20),
                ],
              ),
              const Divider(color: Colors.white24, height: 20),
              Text(
                _nameController.text.toUpperCase(),
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildProfileCardItem("PASSPORT/ID", _passportController.text),
                  _buildProfileCardItem("BLOOD TYPE", _bloodController.text),
                ],
              ),
              const SizedBox(height: 8),
              _buildProfileCardItem("NATIONALITY", _nationalityController.text),
              const SizedBox(height: 8),
              _buildProfileCardItem("ALLERGIES", _allergiesController.text),
              const SizedBox(height: 8),
              _buildProfileCardItem("MEDICAL CONDITIONS", _conditionsController.text),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "EMERGENCY CONTACTS",
                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white60),
                  ),
                  const SizedBox(height: 2),
                  ..._contacts.map((c) {
                    final name = c.nameController.text;
                    final num = c.numberController.text;
                    return Text(
                      "$name ($num)",
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "Profile Information Details",
                      style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: textColor),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      if (_isProfileEditing) {
                        _saveProfileData();
                      } else {
                        setState(() => _isProfileEditing = true);
                      }
                    },
                    icon: Icon(_isProfileEditing ? Icons.save_rounded : Icons.edit_rounded, size: 16),
                    label: Text(
                      _isProfileEditing ? "Save" : "Edit",
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const Divider(height: 12),
              _buildEditableField("Full Name", _nameController),
              _buildEditableField("Passport / ID Number", _passportController),
              _buildEditableField("Nationality", _nationalityController),
              _buildEditableField("Blood Type", _bloodController),
              _buildEditableField("Known Allergies", _allergiesController),
              _buildEditableField("Medical Conditions", _conditionsController),
              _buildEditableField("Current Medications", _medsController),
              _buildEditableField("Hajj/Umrah Group & Agency", _groupNameController),
              _buildEditableField("Makkah/Madinah Hotel Address", _hotelController),

              // Emergency Contacts dynamic editor list
              const Divider(height: 1, thickness: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Emergency Contacts List",
                    style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  if (_isProfileEditing)
                    TextButton.icon(
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 14),
                      label: Text("Add Contact", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        setState(() {
                          _contacts.add(EmergencyContact(name: '', number: ''));
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 6),
              ...List.generate(_contacts.length, (index) {
                final contact = _contacts[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildContactField("Contact Name", contact.nameController),
                            const SizedBox(height: 6),
                            _buildContactField("Phone Number", contact.numberController, keyboardType: TextInputType.phone),
                          ],
                        ),
                      ),
                      if (_isProfileEditing && _contacts.length > 1)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _contacts.removeAt(index).dispose();
                            });
                          },
                        ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCardItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white60),
        ),
        Text(
          value.isEmpty ? "None Declared" : value,
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildEditableField(String label, TextEditingController controller, {TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: widget.isDarkMode ? Colors.white38 : AppColors.placeholder,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          _isProfileEditing
              ? SizedBox(
                  height: 40,
                  child: TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    style: GoogleFonts.poppins(fontSize: 13, color: widget.isDarkMode ? Colors.white : AppColors.navyBlue),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: AppColors.midTeal),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: widget.isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[50],
                    ),
                  ),
                )
              : Text(
                  controller.text.isEmpty ? "Not Filled" : controller.text,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.isDarkMode ? Colors.white70 : AppColors.navyBlue,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildContactField(String label, TextEditingController controller, {TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9.5,
            color: widget.isDarkMode ? Colors.white38 : AppColors.placeholder,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        _isProfileEditing
            ? SizedBox(
                height: 36,
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  style: GoogleFonts.poppins(fontSize: 12.5, color: widget.isDarkMode ? Colors.white : AppColors.navyBlue),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: AppColors.midTeal),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    filled: true,
                    fillColor: widget.isDarkMode ? const Color(0xFF333333) : Colors.white,
                  ),
                ),
              )
            : Text(
                controller.text.isEmpty ? "Not Filled" : controller.text,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: widget.isDarkMode ? Colors.white70 : AppColors.navyBlue,
                ),
              ),
      ],
    );
  }

  // ===== TAB 3: GUIDES & CONTACTS (MAP INTEGRATION) =====
  Widget _buildGuidesAndContactsTab(Color cardBg, Color textColor) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // Live Vector Hajj Radar Map
        _buildMapViewCard(cardBg, textColor),
        const SizedBox(height: 20),

        // Country-specific numbers section
        Text(
          "Location-Aware Emergency Contacts",
          style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: textColor),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Current Detected Country",
                          style: GoogleFonts.inter(fontSize: 11, color: widget.isDarkMode ? Colors.white38 : AppColors.placeholder),
                        ),
                        Text(
                          _currentCountry,
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.midTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "GPS Match",
                      style: GoogleFonts.poppins(fontSize: 10.5, color: AppColors.midTeal, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              _buildCallContactRow(
                label: 'National emergency — $_currentCountry',
                number: _emergencyNumber,
                icon: Icons.emergency_rounded,
                isRecommended: true,
              ),
              _buildCallContactRow(
                label: "Saudi Red Crescent (Ambulance)",
                number: "997",
                icon: Icons.local_hospital_rounded,
                isRecommended: _emergencyNumber == "997",
              ),
              _buildCallContactRow(
                label: "National Police",
                number: "999",
                icon: Icons.local_police_rounded,
                isRecommended: _emergencyNumber == "999",
              ),
              _buildCallContactRow(
                label: "Civil Defense (Fire/Rescue)",
                number: "998",
                icon: Icons.fire_truck_rounded,
                isRecommended: _emergencyNumber == "998",
              ),
              _buildCallContactRow(
                label: "Hajj Pilgrim General Enquiries",
                number: "920002814",
                icon: Icons.contact_support_rounded,
                isRecommended: false,
              ),
              if (_emergencyNumber != "997" && _emergencyNumber != "112")
                _buildCallContactRow(
                  label: "Local Country Emergency Fallback",
                  number: _emergencyNumber,
                  icon: Icons.phone_android_rounded,
                  isRecommended: true,
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Nearest Medical Points (Sorted by GPS)
        Text(
          "Nearest Hajj Medical Points",
          style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: textColor),
        ),
        const SizedBox(height: 8),
        _sortedMedicalPoints.isEmpty
            ? Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  "Waiting for GPS to resolve nearest emergency centers...",
                  style: GoogleFonts.inter(fontSize: 12, color: textColor.withValues(alpha: 0.5)),
                ),
              )
            : Column(
                children: _sortedMedicalPoints.map((point) {
                  final double dist = point['distance'] as double;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.midTeal.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.local_hospital_rounded, color: AppColors.midTeal, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                point['name']!,
                                style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                point['desc']!,
                                style: GoogleFonts.inter(fontSize: 11, color: textColor.withValues(alpha: 0.6)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "${dist.toStringAsFixed(1)} km",
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.midTeal),
                            ),
                            Text(
                              "Away",
                              style: GoogleFonts.inter(fontSize: 9, color: textColor.withValues(alpha: 0.5)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

        const SizedBox(height: 20),

        // Interactive Health/Dehydration and Safety Guides
        Text(
          "Emergency Pilgrim Safety Guides (Offline)",
          style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: textColor),
        ),
        const SizedBox(height: 8),
        _buildSafetyGuideCard(
          title: " Heatstroke & Dehydration",
          subtitle: "Recognize heat exhaustion & act instantly",
          icon: Icons.light_mode_rounded,
          iconColor: Colors.orange,
          content: "• Symptoms: Extremely high body temp (>40°C), red/dry skin, heavy sweating or lack of sweating, rapid pulse, dizziness/confusion.\n"
              "• Actions: Move to a shaded cool place immediately, spray skin with cold water or cover with damp sheets, fan actively. Offer small sips of cool water if conscious.",
        ),
        _buildSafetyGuideCard(
          title: " Crowd Crush Survival Guide",
          subtitle: "What to do in a high-density crowd surge",
          icon: Icons.groups_rounded,
          iconColor: AppColors.navyBlue,
          content: "• Protect Chest: Keep your arms up in front of your chest like a boxer to create breathing space.\n"
              "• Stay Standing: Do not drop bags or try to pick up dropped items. If you fall, get up immediately or roll into a ball.\n"
              "• Move Diagonally: Never fight the crowd force. Move diagonally with the flow toward edges.",
        ),
        _buildSafetyGuideCard(
          title: " CPR & Basic First Aid",
          subtitle: "Offline quick-action cardiovascular resuscitation",
          icon: Icons.favorite_rounded,
          iconColor: Colors.red[800]!,
          content: "1. Verify consciousness & breathing. Call 997 immediately.\n"
              "2. Place hands in the center of the chest.\n"
              "3. Compress hard and fast: 100-120 compressions per minute at 2-inch depth.\n"
              "4. If trained, deliver 2 rescue breaths after every 30 compressions.",
        ),
        _buildSafetyGuideCard(
          title: " \"Lost Pilgrim\" Protocol",
          subtitle: "Action steps if separated from group",
          icon: Icons.person_search_rounded,
          iconColor: AppColors.midTeal,
          content: "• STAY PUT: Wandering blindly makes finding you harder. Find a visible landmark and wait.\n"
              "• USE ID BRACELET: Point to your Hajj agency name, bracelet number, or hotel name to guides/police.\n"
              "• FIND HELP POSTS: Walk to the nearest Scout post or green umbrella police post to request announcement services.",
        ),
      ],
    );
  }

  Widget _buildCallContactRow({
    required String label,
    required String number,
    required IconData icon,
    required bool isRecommended,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: isRecommended ? const Color(0xFFD32F2F) : AppColors.placeholder),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: widget.isDarkMode ? Colors.white70 : AppColors.navyBlue),
                ),
                Text(
                  number,
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.midTeal),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isRecommended ? const Color(0xFFD32F2F) : Colors.grey[200],
              foregroundColor: isRecommended ? Colors.white : AppColors.navyBlue,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.phone_in_talk_rounded, size: 14),
            label: Text("CALL", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
            onPressed: () => _makeCall(number),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyGuideCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          collapsedTextColor: widget.isDarkMode ? Colors.white70 : AppColors.navyBlue,
          textColor: AppColors.midTeal,
          iconColor: AppColors.midTeal,
          title: Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    Text(subtitle, style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey[500])),
                  ],
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                content,
                style: GoogleFonts.inter(fontSize: 11.5, color: widget.isDarkMode ? Colors.white60 : AppColors.navyBlue.withValues(alpha: 0.75), height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  MapType _currentGoogleMapType = MapType.normal;
  bool _useGoogleMapWidget = !kIsWeb;

  Set<Marker> _buildGoogleMapMarkers() {
    final Set<Marker> markers = {};
    final double userLat = _currentPosition?.latitude ?? 21.4225;
    final double userLng = _currentPosition?.longitude ?? 39.8262;

    markers.add(
      Marker(
        markerId: const MarkerId('user_location'),
        position: LatLng(userLat, userLng),
        infoWindow: const InfoWindow(title: 'You (Live Pilgrim Location)', snippet: 'Current position'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    );

    markers.add(
      Marker(
        markerId: const MarkerId('kaaba_haram'),
        position: const LatLng(21.4225, 39.8262),
        infoWindow: const InfoWindow(title: 'Masjid Al-Haram', snippet: 'Makkah Kaaba'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ),
    );

    markers.add(
      Marker(
        markerId: const MarkerId('mina_camp'),
        position: const LatLng(21.4172, 39.8821),
        infoWindow: const InfoWindow(title: 'Mina Pilgrim Encampment', snippet: 'Tents & Jamarat Bridge'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
    );

    markers.add(
      Marker(
        markerId: const MarkerId('mount_arafat'),
        position: const LatLng(21.3533, 39.9839),
        infoWindow: const InfoWindow(title: 'Jabal al-Rahmah', snippet: 'Mount Arafat Plain'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
      ),
    );

    if (_isGroupJoined) {
      for (var member in _mockGroupMembers) {
        final double mLat = member['lat'] as double;
        final double mLng = member['lng'] as double;
        final String mName = member['name'] as String;
        final String mStatus = member['status'] as String;

        markers.add(
          Marker(
            markerId: MarkerId('member_$mName'),
            position: LatLng(mLat, mLng),
            infoWindow: InfoWindow(title: mName, snippet: 'Status: $mStatus'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              mStatus.contains("BREACH") ? BitmapDescriptor.hueYellow : BitmapDescriptor.hueRed,
            ),
          ),
        );
      }
    }

    return markers;
  }

  // ===== MAP CARD WIDGET =====
  Widget _buildMapViewCard(Color cardBg, Color textColor) {
    final double userLat = _currentPosition?.latitude ?? 21.4225;
    final double userLng = _currentPosition?.longitude ?? 39.8262;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Holy Sites Live Map",
                      style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    Text(
                      _useGoogleMapWidget ? "Real-time Google Maps Satellite & Radar" : "GPS-linked route planner & group radar",
                      style: GoogleFonts.inter(fontSize: 10.5, color: textColor.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _useGoogleMapWidget = !_useGoogleMapWidget;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.midTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.midTeal.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(_useGoogleMapWidget ? Icons.map_outlined : Icons.radar_outlined, size: 14, color: AppColors.midTeal),
                      const SizedBox(width: 4),
                      Text(
                        _useGoogleMapWidget ? "Google Map" : "Radar",
                        style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.midTeal),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // In-App Route Search Form Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: widget.isDarkMode ? const Color(0xFF2B2B2B) : Colors.blue.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.midTeal.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.my_location_rounded, color: Colors.blue, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: TextField(
                          controller: _routeOriginController,
                          style: GoogleFonts.poppins(fontSize: 11.5, color: widget.isDarkMode ? Colors.white : AppColors.navyBlue),
                          decoration: InputDecoration(
                            hintText: "Start (Origin)",
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            filled: true,
                            fillColor: widget.isDarkMode ? const Color(0xFF3B3B3B) : Colors.white,
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.midTeal)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: TextField(
                          controller: _routeDestController,
                          style: GoogleFonts.poppins(fontSize: 11.5, color: widget.isDarkMode ? Colors.white : AppColors.navyBlue),
                          decoration: InputDecoration(
                            hintText: "Destination (To)",
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            filled: true,
                            fillColor: widget.isDarkMode ? const Color(0xFF3B3B3B) : Colors.white,
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.midTeal)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildPresetRouteChip("Mina ➔ Kaaba", "Al Mashair, Makkah", "Kaaba, Al Haram, Makkah"),
                            const SizedBox(width: 6),
                            _buildPresetRouteChip("Arafat ➔ Mina", "Mount Arafat, Makkah", "Mina Pilgrim Encampment"),
                            const SizedBox(width: 6),
                            _buildPresetRouteChip("GPS ➔ Hospital", "Current GPS", "Ajyad Emergency Hospital"),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.midTeal,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text("SEARCH", style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        setState(() {});
                        _launchGoogleRouteSearch(_routeOriginController.text, _routeDestController.text);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Map Type Selection Pills (if Google Map is active)
          if (_useGoogleMapWidget)
            Row(
              children: [
                _buildMapTypePill("Normal", MapType.normal),
                const SizedBox(width: 6),
                _buildMapTypePill("Satellite", MapType.satellite),
                const SizedBox(width: 6),
                _buildMapTypePill("Terrain", MapType.terrain),
              ],
            ),
          const SizedBox(height: 10),

          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 220,
              width: double.infinity,
              color: widget.isDarkMode ? const Color(0xFF151515) : const Color(0xFFE3F2FD),
              child: _useGoogleMapWidget
                  ? GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(userLat, userLng),
                        zoom: 13.5,
                      ),
                      mapType: _currentGoogleMapType,
                      markers: _buildGoogleMapMarkers(),
                      myLocationEnabled: false,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: true,
                    )
                  : Stack(
                      children: [
                        CustomPaint(
                          size: const Size(double.infinity, 220),
                          painter: HajjMapPainter(
                            userLat: userLat,
                            userLng: userLng,
                            zoomScale: _mapZoomScale,
                            isDarkMode: widget.isDarkMode,
                            groupMembers: _isGroupJoined ? _mockGroupMembers : [],
                          ),
                        ),
                        if (!widget.isDarkMode)
                          const Positioned.fill(
                            child: IgnorePointer(
                              child: RadarSweepWidget(),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),

          // Action Button to Launch Native Google Maps App
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.midTeal,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.navigation_rounded, size: 16),
              label: Text(
                "Open Turn-by-Turn Navigation in Google Maps",
                style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _showNavigationOptionsDialog(userLat, userLng),
            ),
          ),
        ],
      ),
    );
  }

  void _showNavigationOptionsDialog(double userLat, double userLng) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.navigation_rounded, color: AppColors.midTeal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Google Maps Navigation",
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: widget.isDarkMode ? Colors.white : AppColors.navyBlue,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Select a destination to draw your turn-by-turn route line from your current location:",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.3,
                  color: widget.isDarkMode ? Colors.white70 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 12),
              _buildNavDestinationTile("🕋 Masjid Al-Haram (Kaaba)", 21.4225, 39.8262, userLat, userLng, ctx),
              _buildNavDestinationTile("⛺ Mina Pilgrim Encampment", 21.4172, 39.8821, userLat, userLng, ctx),
              _buildNavDestinationTile("⛰️ Mount Arafat (Jabal al-Rahmah)", 21.3533, 39.9839, userLat, userLng, ctx),
              _buildNavDestinationTile("🏥 Ajyad Emergency Hospital", 21.4192, 39.8286, userLat, userLng, ctx),
            ],
          ),
          actions: [
            TextButton(
              child: Text("CANCEL", style: GoogleFonts.poppins(color: AppColors.midTeal, fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNavDestinationTile(String name, double destLat, double destLng, double userLat, double userLng, BuildContext ctx) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        name,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: widget.isDarkMode ? Colors.white : AppColors.navyBlue,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.midTeal),
      onTap: () async {
        Navigator.of(ctx).pop();
        final uri = Uri.parse("https://www.google.com/maps/dir/?api=1&origin=$userLat,$userLng&destination=$destLat,$destLng");
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
    );
  }

  Widget _buildPresetRouteChip(String label, String origin, String dest) {
    return InkWell(
      onTap: () {
        setState(() {
          _routeOriginController.text = origin;
          _routeDestController.text = dest;
        });
        _launchGoogleRouteSearch(origin, dest);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.midTeal.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.midTeal.withValues(alpha: 0.2)),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.midTeal),
        ),
      ),
    );
  }

  Future<void> _launchGoogleRouteSearch(String origin, String dest) async {
    final double userLat = _currentPosition?.latitude ?? 21.4225;
    final double userLng = _currentPosition?.longitude ?? 39.8262;

    String originParam = origin;
    if (origin.contains("GPS") || origin.contains("Current")) {
      originParam = "$userLat,$userLng";
    }

    final String url = "https://www.google.com/maps/dir/?api=1&origin=${Uri.encodeComponent(originParam)}&destination=${Uri.encodeComponent(dest)}";
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildMapTypePill(String label, MapType mapType) {
    final bool isSelected = _currentGoogleMapType == mapType;
    return InkWell(
      onTap: () {
        setState(() {
          _currentGoogleMapType = mapType;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.navyBlue : Colors.grey[200],
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.navyBlue,
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(IconData icon, Color color, String label) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: widget.isDarkMode ? Colors.white54 : AppColors.navyBlue),
        ),
      ],
    );
  }

  // ===== TAB 4: GROUP HUB & SETUP =====
  Widget _buildGroupHubTab(Color cardBg, Color textColor) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // Group Setup card (Form or Info)
        _isGroupJoined
            ? _buildActiveGroupHub(cardBg, textColor)
            : _buildGroupSetupGuide(cardBg, textColor),
        const SizedBox(height: 20),

        // Emergency Simulation Controls
        Text(
          "Emergency Simulation Controls",
          style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: textColor),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    "Simulate Offline (No Internet)",
                    style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  subtitle: Text(
                    "Enabling blocks API and buffers SOS reports to internal database, forcing SMS backup.",
                    style: GoogleFonts.inter(fontSize: 10.5, color: textColor.withValues(alpha: 0.6)),
                  ),
                  value: _isOfflineSimulated,
                  onChanged: (val) {
                    setState(() {
                      _isOfflineSimulated = val;
                    });
                    if (!val && _offlineQueue.isNotEmpty) {
                      _syncOfflineQueue();
                    }
                  },
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    "Simulate Critically Low Battery (<15%)",
                    style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  subtitle: Text(
                    "Triggers proactive battery-aware SOS location beaconing before phone simulation runs flat.",
                    style: GoogleFonts.inter(fontSize: 10.5, color: textColor.withValues(alpha: 0.6)),
                  ),
                  value: _isLowBatterySimulated,
                  onChanged: (val) {
                    setState(() {
                      _isLowBatterySimulated = val;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Incident Logs History
        Text(
          "Incident History Logs",
          style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: textColor),
        ),
        const SizedBox(height: 8),
        _incidentLogs.isEmpty
            ? Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  "No past incident logs recorded. Safe and sound!",
                  style: GoogleFonts.inter(fontSize: 12, color: textColor.withValues(alpha: 0.5)),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _incidentLogs.length,
                itemBuilder: (context, idx) {
                  final log = _incidentLogs[idx];
                  final timeStr = DateTime.parse(log['timestamp']).toLocal().toString().substring(5, 16);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: log['resolved'] ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${log['type']} - $timeStr",
                                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                              ),
                              Text(
                                "Location: ${log['address']}",
                                style: GoogleFonts.inter(fontSize: 10.5, color: textColor.withValues(alpha: 0.6)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: log['resolved'] ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            log['resolved'] ? "RESOLVED" : "ACTIVE",
                            style: GoogleFonts.poppins(
                              fontSize: 9.5,
                              color: log['resolved'] ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ],
    );
  }

  // Group Protocol Guide when NOT joined — now offers "Create Group" (leader,
  // generates a code) as well as "Join Group" (enter an existing code).
  Widget _buildGroupSetupGuide(Color cardBg, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Hajj Group Formation Protocol",
            style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 4),
          Text(
            "How Hajj/Umrah groups connect for safety tracking",
            style: GoogleFonts.inter(fontSize: 11, color: textColor.withValues(alpha: 0.55)),
          ),
          const Divider(height: 24),

          _buildProtocolStep("1", "Leader Creates Group", "Hajj agency leader logs in, sets up caravan coordinates, and generates a unique code (e.g. MKK-9981)."),
          _buildProtocolStep("2", "Leader Shares Code", "Leader prints the code on wristbands, ID cards, or sends it via text/WhatsApp to members."),
          _buildProtocolStep("3", "Pilgrims Join in App", "Pilgrims enter the code below to sync live coordinates and profiles with the caravan."),
          _buildProtocolStep("4", "Live Safety Layer Active", "Caravan leader can trigger safety pings after big crowd movements (e.g. Jamarat, Arafat)."),

          const Divider(height: 24),

          // ===== CREATE GROUP (LEADER) =====
          Text(
            "Create a New Group",
            style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 4),
          Text(
            "Become the caravan leader and generate a unique code to share with your group.",
            style: GoogleFonts.inter(fontSize: 10.5, color: textColor.withValues(alpha: 0.55)),
          ),
          const SizedBox(height: 8),
          Text(
            'Safety range: ${(_groupRangeMeters / 1000).toStringAsFixed(1)} km',
            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
          ),
          Slider(
            value: _groupRangeMeters,
            min: 100,
            max: 5000,
            divisions: 49,
            label: '${(_groupRangeMeters / 1000).toStringAsFixed(1)} km',
            activeColor: AppColors.midTeal,
            onChanged: (value) => setState(() => _groupRangeMeters = value),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navyBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: Text(
                "CREATE GROUP & GENERATE CODE",
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: _generateGroupCode,
            ),
          ),

          const Divider(height: 28),

          // ===== JOIN EXISTING GROUP =====
          Text(
            "Join Hajj Caravan Group",
            style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _groupCodeController,
                    style: GoogleFonts.poppins(fontSize: 13, color: widget.isDarkMode ? Colors.white : AppColors.navyBlue),
                    decoration: InputDecoration(
                      hintText: "Enter Code (e.g. MKK-9981)",
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: AppColors.midTeal),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: widget.isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[50],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.midTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: Text("JOIN", style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold)),
                onPressed: _joinGroup,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProtocolStep(String number, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: AppColors.midTeal,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.bold, color: widget.isDarkMode ? Colors.white70 : AppColors.navyBlue),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey[500], height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Active Group status when joined
  Widget _buildActiveGroupHub(Color cardBg, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _groupNameController.text.trim().isEmpty ? 'Emergency SOS group' : _groupNameController.text,
                      style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    Text(
                      "Active Safety Synchronization",
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text("LEAVE", style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.red)),
                onPressed: _leaveGroup,
              ),
            ],
          ),
          const Divider(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildGroupMeta("GROUP CODE", _groupCodeController.text.toUpperCase()),
              _buildGroupMeta("CARAVAN LEADER", _isGroupLeader ? "You (Leader)" : (_groupLeaderName.isEmpty ? 'Loading…' : _groupLeaderName)),
              _buildGroupMeta("SAFETY RANGE", '${(_groupRangeMeters / 1000).toStringAsFixed(1)} km'),
            ],
          ),

          const Divider(height: 24),
          Text(
            "Group Members Live Tracker",
            style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 8),

          ..._mockGroupMembers.map((member) {
            final String name = member['name'];
            final int batt = member['battery'];
            final String status = member['status'];
            final double dist = member['dist'];
            final bool isOk = status == 'SAFE';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: widget.isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isOk ? Colors.grey.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    isOk ? Icons.account_circle_rounded : Icons.warning_amber_rounded,
                    color: isOk ? AppColors.midTeal : Colors.orange[800],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.bold, color: textColor),
                        ),
                        Text(
                          "Distance: ${dist.toStringAsFixed(1)} km • Battery: $batt%",
                          style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isOk ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isOk ? "SAFE" : "ALERT",
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        color: isOk ? Colors.green : Colors.orange[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGroupMeta(String label, String val) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.grey[500]),
          ),
          const SizedBox(height: 2),
          Text(
            val,
            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: widget.isDarkMode ? Colors.white70 : AppColors.navyBlue),
          ),
        ],
      ),
    );
  }
}

// ===== RADAR SWEEP EFFECT =====
class RadarSweepWidget extends StatefulWidget {
  const RadarSweepWidget({super.key});

  @override
  State<RadarSweepWidget> createState() => _RadarSweepWidgetState();
}

class _RadarSweepWidgetState extends State<RadarSweepWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _RadarSweepPainter(_controller.value),
        );
      },
    );
  }
}

class _RadarSweepPainter extends CustomPainter {
  final double progress;
  _RadarSweepPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double maxRadius = math.max(cx, cy);

    final Paint sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        colors: [
          Colors.blue.withValues(alpha: 0.0),
          Colors.blue.withValues(alpha: 0.12),
          Colors.blue.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
        transform: GradientRotation(progress * 2 * math.pi),
      ).createShader(Rect.fromLTRB(0, 0, size.width, size.height));

    canvas.drawCircle(Offset(cx, cy), maxRadius, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ===== CUSTOM HAJJ RADAR MAP PAINTER =====
enum _WeatherVisual { rain, cloudy, sunny, night, sunrise, sunset, afternoon, summer, winter, autumn, spring }

class _AnimatedWeatherBackdrop extends StatefulWidget {
  const _AnimatedWeatherBackdrop({required this.visual, required this.darkMode});
  final _WeatherVisual visual;
  final bool darkMode;

  @override
  State<_AnimatedWeatherBackdrop> createState() => _AnimatedWeatherBackdropState();
}

class _AnimatedWeatherBackdropState extends State<_AnimatedWeatherBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (_, __) => CustomPaint(
      painter: _WeatherScenePainter(widget.visual, _controller.value, widget.darkMode),
    ),
  );
}

class _WeatherScenePainter extends CustomPainter {
  _WeatherScenePainter(this.visual, this.progress, this.darkMode);
  final _WeatherVisual visual;
  final double progress;
  final bool darkMode;

  List<Color> get _colors => switch (visual) {
    _WeatherVisual.rain => const [Color(0xFF314B69), Color(0xFF162337)],
    _WeatherVisual.cloudy => const [Color(0xFF71869A), Color(0xFF405262)],
    _WeatherVisual.night => const [Color(0xFF14213D), Color(0xFF050A16)],
    _WeatherVisual.sunrise => const [Color(0xFFF59E72), Color(0xFF7868B2)],
    _WeatherVisual.sunset => const [Color(0xFFE85D75), Color(0xFF38265E)],
    _WeatherVisual.afternoon => const [Color(0xFF2E99C9), Color(0xFF86D0EE)],
    _WeatherVisual.summer => const [Color(0xFF37A9CF), Color(0xFFF2C661)],
    _WeatherVisual.winter => const [Color(0xFF718FC0), Color(0xFFD9EDF5)],
    _WeatherVisual.autumn => const [Color(0xFFB55B37), Color(0xFFF1B15A)],
    _WeatherVisual.spring => const [Color(0xFF67B687), Color(0xFFE7A7C4)],
    _WeatherVisual.sunny => const [Color(0xFF38A9D6), Color(0xFF90D8F2)],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: _colors).createShader(rect));
    final night = visual == _WeatherVisual.night;
    if (night) _stars(canvas, size);
    if (visual == _WeatherVisual.cloudy || visual == _WeatherVisual.rain) _clouds(canvas, size);
    if (visual == _WeatherVisual.rain) _rain(canvas, size);
    if (visual == _WeatherVisual.winter) _snow(canvas, size);
    if (visual == _WeatherVisual.autumn || visual == _WeatherVisual.spring) _leaves(canvas, size);
    if (![ _WeatherVisual.cloudy, _WeatherVisual.rain, _WeatherVisual.winter, _WeatherVisual.night ].contains(visual)) _sun(canvas, size);
    if (night) _moon(canvas, size);
    canvas.drawRect(Rect.fromLTWH(0, size.height * .78, size.width, size.height * .22), Paint()..color = (darkMode ? Colors.black : const Color(0xFF123A54)).withValues(alpha: .18));
  }

  void _sun(Canvas c, Size s) {
    final x = s.width * (.76 + .02 * math.sin(progress * math.pi * 2));
    final y = s.height * (visual == _WeatherVisual.sunrise ? .53 : visual == _WeatherVisual.sunset ? .62 : .23);
    final p = Paint()..color = const Color(0xFFFFE28A);
    c.drawCircle(Offset(x, y), 27, p);
    p..style = PaintingStyle.stroke..strokeWidth = 2..color = const Color(0xFFFFF1B8);
    for (var i = 0; i < 10; i++) { final a = i * math.pi / 5 + progress; c.drawLine(Offset(x + 34 * math.cos(a), y + 34 * math.sin(a)), Offset(x + 43 * math.cos(a), y + 43 * math.sin(a)), p); }
  }

  void _clouds(Canvas c, Size s) {
    final offset = (progress * s.width * .18) - 20;
    final p = Paint()..color = Colors.white.withValues(alpha: visual == _WeatherVisual.rain ? .38 : .7);
    for (final base in [Offset(s.width * .20 + offset, s.height * .28), Offset(s.width * .64 - offset, s.height * .42)]) {
      c.drawCircle(base, 25, p); c.drawCircle(base + const Offset(27, -8), 31, p); c.drawCircle(base + const Offset(56, 3), 22, p);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(base.dx - 20, base.dy, 98, 28), const Radius.circular(18)), p);
    }
  }

  void _rain(Canvas c, Size s) {
    final p = Paint()..color = const Color(0xFFB9E7FF).withValues(alpha: .78)..strokeWidth = 2..strokeCap = StrokeCap.round;
    for (var i = 0; i < 38; i++) { final x = (i * 37.0) % s.width; final y = ((i * 53.0 + progress * s.height * 1.8) % (s.height + 30)) - 20; c.drawLine(Offset(x, y), Offset(x - 7, y + 18), p); }
  }

  void _snow(Canvas c, Size s) {
    final p = Paint()..color = Colors.white.withValues(alpha: .8);
    for (var i = 0; i < 32; i++) { final x = (i * 43.0 + progress * 20) % s.width; final y = ((i * 31.0 + progress * s.height) % (s.height + 12)) - 6; c.drawCircle(Offset(x, y), 2 + (i % 3), p); }
  }

  void _leaves(Canvas c, Size s) {
    final spring = visual == _WeatherVisual.spring;
    final p = Paint()..color = (spring ? const Color(0xFFFFD1E6) : const Color(0xFFFFC25B)).withValues(alpha: .85);
    for (var i = 0; i < 18; i++) { final x = ((i * 62.0) + progress * s.width) % (s.width + 20) - 10; final y = (i * 39.0 + progress * s.height * .35) % s.height; c.save(); c.translate(x, y); c.rotate(progress * math.pi * 4 + i); c.drawOval(Rect.fromCenter(center: Offset.zero, width: 10, height: 5), p); c.restore(); }
  }

  void _stars(Canvas c, Size s) { final p = Paint()..color = Colors.white.withValues(alpha: .8); for (var i = 0; i < 28; i++) { final x = (i * 41.0) % s.width; final y = (i * 29.0) % (s.height * .65); c.drawCircle(Offset(x, y), i % 4 == 0 ? 1.8 : .8, p); } }
  void _moon(Canvas c, Size s) { final o = Offset(s.width * .76, s.height * .23); c.drawCircle(o, 23, Paint()..color = const Color(0xFFF5F0CA)); c.drawCircle(o + const Offset(9, -5), 23, Paint()..color = const Color(0xFF14213D)); }
  @override bool shouldRepaint(covariant _WeatherScenePainter old) => old.visual != visual || old.progress != progress || old.darkMode != darkMode;
}

class HajjMapPainter extends CustomPainter {
  final double userLat;
  final double userLng;
  final double zoomScale;
  final bool isDarkMode;
  final List<Map<String, dynamic>> groupMembers;

  HajjMapPainter({
    required this.userLat,
    required this.userLng,
    required this.zoomScale,
    required this.isDarkMode,
    required this.groupMembers,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;

    final gridPaint = Paint()
      ..color = isDarkMode ? Colors.white10 : Colors.blue.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    final double scale = 14000.0 * zoomScale;

    Offset gpsToCanvas(double lat, double lng) {
      final double dy = (lat - userLat) * scale;
      final double dx = (lng - userLng) * scale;
      return Offset(cx + dx, cy - dy);
    }

    final roadPaint = Paint()
      ..color = isDarkMode ? const Color(0xFF252525) : const Color(0xFFCFD8DC)
      ..strokeWidth = 6.0 * zoomScale
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final makkahPos = gpsToCanvas(21.4225, 39.8262);
    final muzdalifahPos = gpsToCanvas(21.3890, 39.9250);
    final minaPos = gpsToCanvas(21.4172, 39.8821);
    final arafatPos = gpsToCanvas(21.3533, 39.9839);

    final roadPath = Path()
      ..moveTo(makkahPos.dx, makkahPos.dy)
      ..quadraticBezierTo(
        (makkahPos.dx + minaPos.dx) / 2, (makkahPos.dy + minaPos.dy) / 2 - 10,
        minaPos.dx, minaPos.dy,
      )
      ..lineTo(muzdalifahPos.dx, muzdalifahPos.dy)
      ..lineTo(arafatPos.dx, arafatPos.dy);

    canvas.drawPath(roadPath, roadPaint);

    final siteFillPaint = Paint()
      ..color = isDarkMode ? Colors.black26 : Colors.green.withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(makkahPos, 35 * zoomScale, siteFillPaint);
    canvas.drawCircle(minaPos, 45 * zoomScale, siteFillPaint);
    canvas.drawCircle(arafatPos, 40 * zoomScale, siteFillPaint);
    canvas.drawCircle(muzdalifahPos, 30 * zoomScale, siteFillPaint);

    final kaabaPaint = Paint()
      ..color = const Color(0xFFD84315)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromCenter(center: makkahPos, width: 14 * zoomScale, height: 14 * zoomScale), kaabaPaint);
    final kaabaCover = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromCenter(center: makkahPos, width: 12 * zoomScale, height: 12 * zoomScale), kaabaCover);
    final kaabaBelt = Paint()
      ..color = const Color(0xFFFFD54F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * zoomScale;
    canvas.drawRect(Rect.fromCenter(center: makkahPos, width: 12 * zoomScale, height: 4 * zoomScale), kaabaBelt);

    final tentPaint = Paint()
      ..color = Colors.green[700]!
      ..style = PaintingStyle.fill;
    _drawTent(canvas, minaPos, 10 * zoomScale, tentPaint);

    final mtPaint = Paint()
      ..color = Colors.brown[500]!
      ..style = PaintingStyle.fill;
    _drawMountain(canvas, arafatPos, 12 * zoomScale, mtPaint);

    _drawText(canvas, "Makkah Haram", makkahPos.dx, makkahPos.dy + 15 * zoomScale, isDarkMode);
    _drawText(canvas, "Mina Camps", minaPos.dx, minaPos.dy + 15 * zoomScale, isDarkMode);
    _drawText(canvas, "Muzdalifah", muzdalifahPos.dx, muzdalifahPos.dy + 15 * zoomScale, isDarkMode);
    _drawText(canvas, "Mount Arafat", arafatPos.dx, arafatPos.dy + 15 * zoomScale, isDarkMode);

    final crossPaint = Paint()
      ..color = Colors.green[600]!
      ..style = PaintingStyle.fill;
    _drawMedicalCross(canvas, gpsToCanvas(21.4172, 39.8821), 6 * zoomScale, crossPaint);
    _drawMedicalCross(canvas, gpsToCanvas(21.3533, 39.9839), 6 * zoomScale, crossPaint);
    _drawMedicalCross(canvas, gpsToCanvas(21.4192, 39.8286), 6 * zoomScale, crossPaint);

    for (var member in groupMembers) {
      final double mLat = member['lat'] as double;
      final double mLng = member['lng'] as double;
      final double mDist = member['dist'] as double;
      final String mName = member['name'] as String;
      final String mStatus = member['status'] as String;

      final mPos = gpsToCanvas(mLat, mLng);

      final memberPaint = Paint()
        ..color = mStatus.contains("BREACH") ? Colors.orange[800]! : Colors.red[800]!
        ..style = PaintingStyle.fill;
      canvas.drawCircle(mPos, 5.0 * zoomScale, memberPaint);

      final memberPulse = Paint()
        ..color = memberPaint.color.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(mPos, 9.0 * zoomScale, memberPulse);

      _drawText(canvas, "$mName (${mDist.toStringAsFixed(1)}km)", mPos.dx, mPos.dy - 10 * zoomScale, isDarkMode);
    }

    final pilgrimPaint = Paint()
      ..color = Colors.blue[600]!
      ..style = PaintingStyle.fill;

    final pilgrimPulse = Paint()
      ..color = Colors.blue[400]!.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(Offset(cx, cy), 6.5 * zoomScale, pilgrimPaint);
    canvas.drawCircle(Offset(cx, cy), 12.0 * zoomScale, pilgrimPulse);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(cx, cy), 6.5 * zoomScale, borderPaint);

    _drawText(canvas, "YOU", cx, cy - 12 * zoomScale, isDarkMode, isBold: true);
  }

  void _drawTent(Canvas canvas, Offset pos, double size, Paint paint) {
    final path = Path()
      ..moveTo(pos.dx - size, pos.dy + size)
      ..lineTo(pos.dx + size, pos.dy + size)
      ..lineTo(pos.dx + size, pos.dy)
      ..lineTo(pos.dx, pos.dy - size)
      ..lineTo(pos.dx - size, pos.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawMountain(Canvas canvas, Offset pos, double size, Paint paint) {
    final path = Path()
      ..moveTo(pos.dx - size * 1.2, pos.dy + size)
      ..lineTo(pos.dx + size * 1.2, pos.dy + size)
      ..lineTo(pos.dx + size * 0.2, pos.dy - size * 0.8)
      ..lineTo(pos.dx - size * 0.3, pos.dy - size * 0.4)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawMedicalCross(Canvas canvas, Offset pos, double size, Paint paint) {
    final path = Path()
      ..moveTo(pos.dx - size / 3, pos.dy - size)
      ..lineTo(pos.dx + size / 3, pos.dy - size)
      ..lineTo(pos.dx + size / 3, pos.dy - size / 3)
      ..lineTo(pos.dx + size, pos.dy - size / 3)
      ..lineTo(pos.dx + size, pos.dy + size / 3)
      ..lineTo(pos.dx + size / 3, pos.dy + size / 3)
      ..lineTo(pos.dx + size / 3, pos.dy + size)
      ..lineTo(pos.dx - size / 3, pos.dy + size)
      ..lineTo(pos.dx - size / 3, pos.dy + size / 3)
      ..lineTo(pos.dx - size, pos.dy + size / 3)
      ..lineTo(pos.dx - size, pos.dy - size / 3)
      ..lineTo(pos.dx - size / 3, pos.dy - size / 3)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawText(Canvas canvas, String text, double x, double y, bool isDarkMode, {bool isBold = false}) {
    final span = TextSpan(
      text: text,
      style: GoogleFonts.inter(
        fontSize: 9,
        fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
        color: isDarkMode ? Colors.white60 : AppColors.navyBlue,
        shadows: [
          const Shadow(color: Colors.white70, blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
    );
    final tp = TextPainter(
      text: span,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
