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
import '../widgets/auth_header.dart'; // AppColors
import '../services/emergency_api_service.dart';
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
  const EmergencySosScreen({super.key});

  @override
  State<EmergencySosScreen> createState() => _EmergencySosScreenState();
}

class _EmergencySosScreenState extends State<EmergencySosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ===== SOS ACTIVATION STATES =====
  bool _isSosTriggered = false;
  bool _isHolding = false;
  double _holdProgress = 0.0;
  Timer? _holdTimer;
  Timer? _cancelTimer;
  int _cancelCountdown = 5;
  bool _isCountingDown = false;
  bool _isSilentMode = false;
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
  List<Map<String, dynamic>> _offlineQueue = [];
  List<Map<String, dynamic>> _incidentLogs = [];

  // ===== DYNAMIC EMERGENCY CONTACTS LIST =====
  List<EmergencyContact> _contacts = [];

  // ===== IN-APP ROUTE PLANNER CONTROLLERS =====
  final _routeOriginController = TextEditingController(text: "Al Mashair, Makkah");
  final _routeDestController = TextEditingController(text: "Kaaba, Al Haram, Makkah");
  bool _isRouteActive = true;

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
  final _groupCodeController = TextEditingController(text: "MKK-9981");

  // Map variables
  double _mapZoomScale = 1.0;

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
    _tabController = TabController(length: 4, vsync: this);
    _loadProfileData();
    _loadIncidentLogs();
    _initLocationTracking();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _holdTimer?.cancel();
    _cancelTimer?.cancel();
    _positionStreamSubscription?.cancel();
    
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
          // Initialize with default
          _contacts = [
            EmergencyContact(name: "Fatimah Ali (Wife)", number: "+628123456789"),
            EmergencyContact(name: "Ahmed Hajj Agency", number: "+966509876543"),
          ];
        }
      }
    });
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

      // Continuous locations stream
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position position) {
        if (mounted) {
          _updateLocationInfo(position);
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

  void _updateEmergencyNumber(String? country) {
    if (country == null) return;
    final cName = country.toLowerCase();
    setState(() {
      if (cName.contains("saudi") || cName.contains("arabia")) {
        _emergencyNumber = "997";
      } else if (cName.contains("united states") || cName.contains("america")) {
        _emergencyNumber = "911";
      } else if (cName.contains("united kingdom")) {
        _emergencyNumber = "999";
      } else if (cName.contains("turkey")) {
        _emergencyNumber = "112";
      } else if (cName.contains("malaysia")) {
        _emergencyNumber = "999";
      } else if (cName.contains("indonesia")) {
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

    if (!_isSilentMode) {
      NotificationService.instance.showCustomNotification(
        id: 9999,
        title: "🚨 SOS ACTIVATED 🚨",
        body: "All emergency contacts and group leaders have been notified.",
        scheduledTime: DateTime.now().add(const Duration(seconds: 1)),
      );
    }

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
        isSilent: _isSilentMode,
        groupLeaderId: _isGroupJoined ? "LEADER_9981" : null,
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
      'type': _isSilentMode ? 'Silent SOS' : 'Standard SOS',
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
      final phone = contact.numberController.text;
      final name = contact.nameController.text;
      final message = "DEENMATE EMERGENCY SOS!\nI need help. My medical profile is attached to this account. My current GPS location: $locationLink";
      final uri = Uri.parse("sms:$phone?body=${Uri.encodeComponent(message)}");
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
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
      title: "💚 Status Safe 💚",
      body: "An 'I am Safe' broadcast has been sent to your emergency contacts.",
      scheduledTime: DateTime.now().add(const Duration(seconds: 1)),
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
      final phone = contact.numberController.text;
      final safeMsg = "Alhamdulillah, the danger has passed and I am safe now. Thank you for your support.";
      final uri = Uri.parse("sms:$phone?body=${Uri.encodeComponent(safeMsg)}");
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
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
        groupLeaderId: _isGroupJoined ? "LEADER_9981" : null,
      );
    }
    setState(() {
      _offlineQueue.clear();
      _activeSosLogs.add("[${DateTime.now().toLocal().toString().substring(11, 19)}] ✅ Offline queue synced.");
    });
  }

  Future<void> _makeCall(String phone) async {
    final uri = Uri.parse("tel:$phone");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  // ===== UI BUILDING =====
  @override
  Widget build(BuildContext context) {
    final primaryBg = _isSilentMode ? const Color(0xFF121212) : const Color(0xFFF7F7F5);
    final textThemeColor = _isSilentMode ? Colors.white70 : AppColors.navyBlue;
    final cardBg = _isSilentMode ? const Color(0xFF1E1E1E) : Colors.white;

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
                  _buildTabBar(cardBg, textThemeColor),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildSosTriggerTab(primaryBg, cardBg, textThemeColor),
                        _buildMedicalProfileTab(cardBg, textThemeColor),
                        _buildGuidesAndContactsTab(cardBg, textThemeColor),
                        _buildGroupHubTab(cardBg, textThemeColor),
                      ],
                    ),
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
              color: _isSilentMode ? Colors.grey[900] : const Color(0xFFD32F2F),
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
                  _isSilentMode ? 'Inconspicuous Hub' : 'Emergency SOS',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Text(
                  _isSilentMode ? 'Screen dimmed, silent background alerts active' : 'Live panic trigger & critical care',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: textColor.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          if (_isSilentMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red[900]?.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red[900]!, width: 1),
              ),
              child: Text(
                'SILENT',
                style: GoogleFonts.poppins(fontSize: 10, color: Colors.red[300], fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  // ===== TAB BAR =====
  Widget _buildTabBar(Color bg, Color activeColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: _isSilentMode ? Colors.white : AppColors.navyBlue,
        unselectedLabelColor: _isSilentMode ? Colors.white38 : AppColors.placeholder,
        indicatorColor: _isSilentMode ? Colors.red[800] : AppColors.midTeal,
        indicatorWeight: 3,
        labelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500),
        tabs: const [
          Tab(text: 'SOS Button'),
          Tab(text: 'Medical Card'),
          Tab(text: 'Maps & Guides'),
          Tab(text: 'Group Hub'),
        ],
      ),
    );
  }

  // ===== TAB 1: SOS TRIGGER PANEL =====
  Widget _buildSosTriggerTab(Color mainBg, Color containerBg, Color textColor) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (_isCountingDown) _buildCountdownCard(containerBg, textColor),

        if (!_isCountingDown) ...[
          _buildPanicButtonSection(textColor),
          const SizedBox(height: 20),
          _buildSilentModeToggleCard(containerBg, textColor),
          const SizedBox(height: 14),
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
                  Text(
                    "Click once when safe to broadcast recovery",
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600),
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

  Widget _buildSilentModeToggleCard(Color containerBg, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Material(
        color: Colors.transparent,
        child: SwitchListTile(
          activeColor: Colors.red[700],
          contentPadding: EdgeInsets.zero,
          title: Row(
            children: [
              Icon(
                _isSilentMode ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: _isSilentMode ? Colors.red[700] : AppColors.placeholder,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                "Silent SOS Mode",
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
              ),
            ],
          ),
          subtitle: Text(
            "For theft or harassment. Triggers alerts in the background with no sound, vibration, or bright UI triggers.",
            style: GoogleFonts.inter(fontSize: 11, color: textColor.withValues(alpha: 0.6), height: 1.3),
          ),
          value: _isSilentMode,
          onChanged: (val) {
            setState(() {
              _isSilentMode = val;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(val
                    ? 'Silent SOS enabled. Screen will dim to black if SOS triggers.'
                    : 'Silent SOS disabled. Alarm will sound on SOS.'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.midTeal.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.my_location_rounded, color: AppColors.midTeal, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Real-time GPS Status",
                  style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor),
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
            gradient: LinearGradient(
              colors: _isSilentMode
                  ? [const Color(0xFF303030), const Color(0xFF1E1E1E)]
                  : [const Color(0xFFE53935), const Color(0xFFC62828)],
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
                    color: _isSilentMode ? const Color(0xFF2C2C2C) : Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.withOpacity(0.15)),
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
              color: _isSilentMode ? Colors.white38 : AppColors.placeholder,
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
                    style: GoogleFonts.poppins(fontSize: 13, color: _isSilentMode ? Colors.white : AppColors.navyBlue),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: AppColors.midTeal),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: _isSilentMode ? const Color(0xFF2C2C2C) : Colors.grey[50],
                    ),
                  ),
                )
              : Text(
                  controller.text.isEmpty ? "Not Filled" : controller.text,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _isSilentMode ? Colors.white70 : AppColors.navyBlue,
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
            color: _isSilentMode ? Colors.white38 : AppColors.placeholder,
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
                  style: GoogleFonts.poppins(fontSize: 12.5, color: _isSilentMode ? Colors.white : AppColors.navyBlue),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: AppColors.midTeal),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    filled: true,
                    fillColor: _isSilentMode ? const Color(0xFF333333) : Colors.white,
                  ),
                ),
              )
            : Text(
                controller.text.isEmpty ? "Not Filled" : controller.text,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _isSilentMode ? Colors.white70 : AppColors.navyBlue,
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
                          style: GoogleFonts.inter(fontSize: 11, color: _isSilentMode ? Colors.white38 : AppColors.placeholder),
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
                      color: AppColors.midTeal.withOpacity(0.1),
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
                            color: AppColors.midTeal.withOpacity(0.08),
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
          title: "☀️ Heatstroke & Dehydration",
          subtitle: "Recognize heat exhaustion & act instantly",
          icon: Icons.light_mode_rounded,
          iconColor: Colors.orange,
          content: "• Symptoms: Extremely high body temp (>40°C), red/dry skin, heavy sweating or lack of sweating, rapid pulse, dizziness/confusion.\n"
              "• Actions: Move to a shaded cool place immediately, spray skin with cold water or cover with damp sheets, fan actively. Offer small sips of cool water if conscious.",
        ),
        _buildSafetyGuideCard(
          title: "🤝 Crowd Crush Survival Guide",
          subtitle: "What to do in a high-density crowd surge",
          icon: Icons.groups_rounded,
          iconColor: AppColors.navyBlue,
          content: "• Protect Chest: Keep your arms up in front of your chest like a boxer to create breathing space.\n"
              "• Stay Standing: Do not drop bags or try to pick up dropped items. If you fall, get up immediately or roll into a ball.\n"
              "• Move Diagonally: Never fight the crowd force. Move diagonally with the flow toward edges.",
        ),
        _buildSafetyGuideCard(
          title: "❤️ CPR & Basic First Aid",
          subtitle: "Offline quick-action cardiovascular resuscitation",
          icon: Icons.favorite_rounded,
          iconColor: Colors.red[800]!,
          content: "1. Verify consciousness & breathing. Call 997 immediately.\n"
              "2. Place hands in the center of the chest.\n"
              "3. Compress hard and fast: 100-120 compressions per minute at 2-inch depth.\n"
              "4. If trained, deliver 2 rescue breaths after every 30 compressions.",
        ),
        _buildSafetyGuideCard(
          title: "🎒 \"Lost Pilgrim\" Protocol",
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
                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: _isSilentMode ? Colors.white70 : AppColors.navyBlue),
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
        color: _isSilentMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          collapsedTextColor: _isSilentMode ? Colors.white70 : AppColors.navyBlue,
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
                style: GoogleFonts.inter(fontSize: 11.5, color: _isSilentMode ? Colors.white60 : AppColors.navyBlue.withValues(alpha: 0.75), height: 1.4),
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
            color: Colors.black.withOpacity(0.03),
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
                    color: AppColors.midTeal.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.midTeal.withOpacity(0.3)),
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
              color: _isSilentMode ? const Color(0xFF2B2B2B) : Colors.blue.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.midTeal.withOpacity(0.2)),
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
                          style: GoogleFonts.poppins(fontSize: 11.5, color: _isSilentMode ? Colors.white : AppColors.navyBlue),
                          decoration: InputDecoration(
                            hintText: "Start (Origin)",
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            filled: true,
                            fillColor: _isSilentMode ? const Color(0xFF3B3B3B) : Colors.white,
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.withOpacity(0.2))),
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
                          style: GoogleFonts.poppins(fontSize: 11.5, color: _isSilentMode ? Colors.white : AppColors.navyBlue),
                          decoration: InputDecoration(
                            hintText: "Destination (To)",
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            filled: true,
                            fillColor: _isSilentMode ? const Color(0xFF3B3B3B) : Colors.white,
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.withOpacity(0.2))),
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
              color: _isSilentMode ? const Color(0xFF151515) : const Color(0xFFE3F2FD),
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
                            isSilent: _isSilentMode,
                            groupMembers: _isGroupJoined ? _mockGroupMembers : [],
                          ),
                        ),
                        if (!_isSilentMode)
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.navigation_rounded, color: AppColors.midTeal),
              const SizedBox(width: 8),
              Text(
                "Google Maps Navigation",
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Select a destination to draw your turn-by-turn route line from your current location:",
                style: GoogleFonts.inter(fontSize: 12, height: 1.3),
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
              child: const Text("CANCEL"),
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
      title: Text(name, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.navyBlue)),
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
          color: AppColors.midTeal.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.midTeal.withOpacity(0.2)),
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
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: _isSilentMode ? Colors.white54 : AppColors.navyBlue),
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
                color: Colors.black.withOpacity(0.03),
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

        // Interactive simulation actions
        Text(
          "Simulate External Triggers",
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
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildSimActionButton(
                label: "Simulate Leader Safety Check-in Ping",
                description: "Receives group message query: 'Ahmed requests safe check-in status after Jamarat crowding'",
                icon: Icons.campaign_rounded,
                onPressed: () {
                  NotificationService.instance.showCustomNotification(
                    id: 8881,
                    title: "🚨 Group Safety Check-In 🚨",
                    body: "Leader Ahmed requests your safety status. Tap to respond.",
                    scheduledTime: DateTime.now().add(const Duration(seconds: 1)),
                  );
                  _showCheckInDialog();
                },
              ),
              const Divider(height: 20),
              _buildSimActionButton(
                label: "Simulate Geofence Wandering Alert",
                description: "Simulates pilgrim walking 650m outside the predefined Mina Camp boundary",
                icon: Icons.map_outlined,
                onPressed: () {
                  _triggerGeofenceBreachAlert();
                },
              ),
            ],
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
                        color: log['resolved'] ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
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
                            color: log['resolved'] ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
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

  // Group Protocol Guide when NOT joined
  Widget _buildGroupSetupGuide(Color cardBg, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
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
            style: GoogleFonts.inter(fontSize: 11, color: textColor.withOpacity(0.55)),
          ),
          const Divider(height: 24),
          
          _buildProtocolStep("1", "Leader Creates Group", "Hajj agency leader logs in, sets up caravan coordinates, and generates a unique code (e.g. MKK-9981)."),
          _buildProtocolStep("2", "Leader Shares Code", "Leader prints the code on wristbands, ID cards, or sends it via text/WhatsApp to members."),
          _buildProtocolStep("3", "Pilgrims Join in App", "Pilgrims enter the code below to sync live coordinates and profiles with the caravan."),
          _buildProtocolStep("4", "Live Safety Layer Active", "Caravan leader can trigger safety pings after big crowd movements (e.g. Jamarat, Arafat)."),
          
          const Divider(height: 24),
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
                    style: GoogleFonts.poppins(fontSize: 13, color: _isSilentMode ? Colors.white : AppColors.navyBlue),
                    decoration: InputDecoration(
                      hintText: "Enter Code (e.g. MKK-9981)",
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: AppColors.midTeal),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: _isSilentMode ? const Color(0xFF2C2C2C) : Colors.grey[50],
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
                onPressed: () {
                  if (_groupCodeController.text.trim().isNotEmpty) {
                    setState(() {
                      _isGroupJoined = true;
                    });
                    _saveProfileData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Successfully joined group ${_groupCodeController.text.toUpperCase()}!')),
                    );
                  }
                },
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
                  style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.bold, color: _isSilentMode ? Colors.white70 : AppColors.navyBlue),
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
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
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
                      "Makkah Caravan - Group A",
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
                onPressed: () {
                  setState(() {
                    _isGroupJoined = false;
                  });
                  _saveProfileData();
                },
              ),
            ],
          ),
          const Divider(height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildGroupMeta("GROUP CODE", _groupCodeController.text.toUpperCase()),
              _buildGroupMeta("CARAVAN LEADER", "Ahmed Al-Harbi"),
              _buildGroupMeta("LEADER PHONE", "+966 50 123 4567"),
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
            final bool isOk = !status.contains("BREACH");

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _isSilentMode ? const Color(0xFF2C2C2C) : Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isOk ? Colors.grey.withOpacity(0.1) : Colors.orange.withOpacity(0.3)),
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
                      color: isOk ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
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
          }).toList(),
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
            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: _isSilentMode ? Colors.white70 : AppColors.navyBlue),
          ),
        ],
      ),
    );
  }

  Widget _buildSimActionButton({
    required String label,
    required String description,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.midTeal, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: _isSilentMode ? Colors.white70 : AppColors.navyBlue),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: GoogleFonts.inter(fontSize: 10.5, color: Colors.grey[500], height: 1.3),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 36,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.midTeal),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text("TRIGGER SIMULATION", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
            onPressed: onPressed,
          ),
        ),
      ],
    );
  }

  void _showCheckInDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.campaign_rounded, color: AppColors.midTeal),
              const SizedBox(width: 8),
              Text("Group Safety Check-In", style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            "Ahmed (Group Leader) has initiated a safety check-in for 'Garuda Hajj Cluster 4' after Jamarat crowd movements.\n\nPlease declare your current safety status.",
            style: GoogleFonts.inter(fontSize: 12.5, height: 1.4),
          ),
          actions: [
            TextButton(
              child: Text("I NEED HELP", style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.bold)),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await EmergencyApiService.instance.sendGroupCheckInStatus(
                  checkInId: "CHK_9011",
                  status: "NEED_HELP",
                  latitude: _currentPosition?.latitude ?? 21.4225,
                  longitude: _currentPosition?.longitude ?? 39.8262,
                );
                _fireSosAlert();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.midTeal),
              child: Text("I AM SAFE", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await EmergencyApiService.instance.sendGroupCheckInStatus(
                  checkInId: "CHK_9011",
                  status: "SAFE",
                  latitude: _currentPosition?.latitude ?? 21.4225,
                  longitude: _currentPosition?.longitude ?? 39.8262,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Safety check-in response sent to group leader: 'I AM SAFE'")),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _triggerGeofenceBreachAlert() async {
    final double lat = _currentPosition?.latitude ?? 21.4225;
    final double lng = _currentPosition?.longitude ?? 39.8262;

    await EmergencyApiService.instance.reportGeofenceViolation(
      groupLeaderId: "LEADER_9981",
      latitude: lat,
      longitude: lng,
      distanceOut: 650.0,
    );

    NotificationService.instance.showCustomNotification(
      id: 7771,
      title: "⚠️ Geofence Wandering Alert ⚠️",
      body: "You are 650m outside the Mina Pilgrim Encampment zone. Ahmed (leader) has been flagged.",
      scheduledTime: DateTime.now().add(const Duration(seconds: 1)),
    );

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.map_outlined, color: Colors.orange),
              SizedBox(width: 8),
              Text("Geofence Boundary Breach", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            "You have wandered 650m outside the expected Mina Encampment Boundary.\n\nYour group leader has been notified automatically to prevent you from getting lost. Please return to the group zone or follow the directions.",
            style: GoogleFonts.inter(fontSize: 12.5, height: 1.4),
          ),
          actions: [
            TextButton(
              child: const Text("CLOSE"),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.midTeal),
              child: const Text("NAVIGATE BACK", style: TextStyle(color: Colors.white)),
              onPressed: () async {
                Navigator.of(ctx).pop();
                final uri = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=21.4172,39.8821");
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
          ],
        );
      },
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
          Colors.blue.withOpacity(0.0),
          Colors.blue.withOpacity(0.12),
          Colors.blue.withOpacity(0.0),
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
class HajjMapPainter extends CustomPainter {
  final double userLat;
  final double userLng;
  final double zoomScale;
  final bool isSilent;
  final List<Map<String, dynamic>> groupMembers;

  HajjMapPainter({
    required this.userLat,
    required this.userLng,
    required this.zoomScale,
    required this.isSilent,
    required this.groupMembers,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;

    final gridPaint = Paint()
      ..color = isSilent ? Colors.white10 : Colors.blue.withOpacity(0.05)
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
      ..color = isSilent ? const Color(0xFF252525) : const Color(0xFFCFD8DC)
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
      ..color = isSilent ? Colors.black26 : Colors.green.withOpacity(0.07)
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

    _drawText(canvas, "Makkah Haram", makkahPos.dx, makkahPos.dy + 15 * zoomScale, isSilent);
    _drawText(canvas, "Mina Camps", minaPos.dx, minaPos.dy + 15 * zoomScale, isSilent);
    _drawText(canvas, "Muzdalifah", muzdalifahPos.dx, muzdalifahPos.dy + 15 * zoomScale, isSilent);
    _drawText(canvas, "Mount Arafat", arafatPos.dx, arafatPos.dy + 15 * zoomScale, isSilent);

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
        ..color = memberPaint.color.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(mPos, 9.0 * zoomScale, memberPulse);

      _drawText(canvas, "$mName (${mDist.toStringAsFixed(1)}km)", mPos.dx, mPos.dy - 10 * zoomScale, isSilent);
    }

    final pilgrimPaint = Paint()
      ..color = Colors.blue[600]!
      ..style = PaintingStyle.fill;
    
    final pilgrimPulse = Paint()
      ..color = Colors.blue[400]!.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    canvas.drawCircle(Offset(cx, cy), 6.5 * zoomScale, pilgrimPaint);
    canvas.drawCircle(Offset(cx, cy), 12.0 * zoomScale, pilgrimPulse);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(cx, cy), 6.5 * zoomScale, borderPaint);

    _drawText(canvas, "YOU", cx, cy - 12 * zoomScale, isSilent, isBold: true);
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

  void _drawText(Canvas canvas, String text, double x, double y, bool isSilent, {bool isBold = false}) {
    final span = TextSpan(
      text: text,
      style: GoogleFonts.inter(
        fontSize: 9,
        fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
        color: isSilent ? Colors.white60 : AppColors.navyBlue,
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
