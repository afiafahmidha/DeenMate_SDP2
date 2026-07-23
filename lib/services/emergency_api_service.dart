import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Service handling real-life HTTP API calls to the DeenMate Emergency Backend.
/// Replace [baseUrl] with your production API endpoint.
class EmergencyApiService {
  EmergencyApiService._();
  static final EmergencyApiService instance = EmergencyApiService._();

  // Configurable base URL for DeenMate backend services
  static const String baseUrl = 'https://api.deenmate.com/v1';

  /// Triggers a live emergency SOS alert to the backend.
  /// Sends the pilgrim's current GPS location, medical details, emergency contacts,
  /// and whether it is a silent trigger.
  Future<bool> triggerEmergencySos({
    required double latitude,
    required double longitude,
    required Map<String, dynamic> medicalProfile,
    required List<Map<String, String>> emergencyContacts,
    required bool isSilent,
    required String? groupLeaderId,
  }) async {
    final url = Uri.parse('$baseUrl/emergency/sos/trigger');
    final payload = {
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'location': {
        'latitude': latitude,
        'longitude': longitude,
      },
      'medicalProfile': medicalProfile,
      'emergencyContacts': emergencyContacts,
      'isSilent': isSilent,
      'groupLeaderId': groupLeaderId,
      'status': 'ACTIVE',
    };

    try {
      debugPrint('[EmergencyApiService] Sending POST to $url with payload: ${jsonEncode(payload)}');
      
      // In real life, we perform the post request:
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[EmergencyApiService] SOS triggered successfully on backend.');
        return true;
      } else {
        debugPrint('[EmergencyApiService] Backend returned error: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('[EmergencyApiService] Network error triggering SOS: $e');
      // Return false to let the caller trigger SMS fallback due to network absence.
      return false;
    }
  }

  /// Sends periodic GPS location updates to the backend during an active SOS.
  Future<bool> updateLiveLocation({
    required double latitude,
    required double longitude,
    required String emergencyId,
  }) async {
    final url = Uri.parse('$baseUrl/emergency/sos/update-location');
    final payload = {
      'emergencyId': emergencyId,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'location': {
        'latitude': latitude,
        'longitude': longitude,
      },
    };

    try {
      debugPrint('[EmergencyApiService] Updating location: ${jsonEncode(payload)}');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 8));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[EmergencyApiService] Location update failed: $e');
      return false;
    }
  }

  /// Resolves/Deactivates the active SOS alarm.
  /// Sends a broadcast informing contacts and backend that the user is safe.
  Future<bool> deactivateEmergencySos({
    required String emergencyId,
    required double latitude,
    required double longitude,
  }) async {
    final url = Uri.parse('$baseUrl/emergency/sos/resolve');
    final payload = {
      'emergencyId': emergencyId,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'status': 'RESOLVED',
      'location': {
        'latitude': latitude,
        'longitude': longitude,
      },
    };

    try {
      debugPrint('[EmergencyApiService] Resolving SOS: ${jsonEncode(payload)}');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 8));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[EmergencyApiService] Resolution update failed: $e');
      return false;
    }
  }

  /// Submits the pilgrim's "Check-in" status in response to a group leader's safety query.
  Future<bool> sendGroupCheckInStatus({
    required String checkInId,
    required String status, // 'SAFE' or 'NEED_HELP'
    required double latitude,
    required double longitude,
  }) async {
    final url = Uri.parse('$baseUrl/groups/check-in/respond');
    final payload = {
      'checkInId': checkInId,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'status': status,
      'location': {
        'latitude': latitude,
        'longitude': longitude,
      },
    };

    try {
      debugPrint('[EmergencyApiService] Sending check-in response: ${jsonEncode(payload)}');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 8));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[EmergencyApiService] Check-in transmission failed: $e');
      return false;
    }
  }

  /// Reports a geofencing violation to the group server, notifying the group leader.
  Future<bool> reportGeofenceViolation({
    required String groupLeaderId,
    required double latitude,
    required double longitude,
    required double distanceOut,
  }) async {
    final url = Uri.parse('$baseUrl/groups/alerts/geofence-breach');
    final payload = {
      'groupLeaderId': groupLeaderId,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'location': {
        'latitude': latitude,
        'longitude': longitude,
      },
      'distanceOut': distanceOut,
    };

    try {
      debugPrint('[EmergencyApiService] Sending geofence alert: ${jsonEncode(payload)}');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 8));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[EmergencyApiService] Geofence report failed: $e');
      return false;
    }
  }
}
