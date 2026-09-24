import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the device-local cache isolated when multiple Firebase accounts use
/// the same phone. Firestore remains the source of truth; this service simply
/// swaps the local SharedPreferences snapshot belonging to the active UID.
class AccountScopedStorageService {
  AccountScopedStorageService._();

  static final instance = AccountScopedStorageService._();
  static const _activeUidKey = '_deenmate_active_uid';
  static const _snapshotPrefix = '_deenmate_snapshot_';
  static const _scopeVersionKey = '_deenmate_account_scope_version';
  static const _scopeVersion = 2;
  static const _metadataKeys = {
    _activeUidKey,
    _scopeVersionKey,
    'is_logged_in',
  };

  Future<void> switchTo(String uid) async {
    if (uid.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();

    // Invalidate snapshots created by the earlier isolation implementation;
    // those snapshots may already contain mixed-account data from before the
    // auth transition was awaited.
    if (prefs.getInt(_scopeVersionKey) != _scopeVersion) {
      for (final key in prefs.getKeys().where((k) => k.startsWith(_snapshotPrefix)).toList()) {
        await prefs.remove(key);
      }
      await prefs.setInt(_scopeVersionKey, _scopeVersion);
    }

    final activeUid = prefs.getString(_activeUidKey);
    if (activeUid == uid) return;

    // Preserve any pre-migration local data for the first account that opens
    // the updated app. It will be synced to that account's Firestore profile
    // by the feature loaders instead of being silently discarded.
    if (activeUid == null || activeUid.isEmpty) {
      await prefs.setString(_activeUidKey, uid);
      return;
    }

    await _saveSnapshot(prefs, activeUid);

    final keys = prefs.getKeys().toList();
    for (final key in keys) {
      if (_metadataKeys.contains(key) || key.startsWith(_snapshotPrefix)) {
        continue;
      }
      await prefs.remove(key);
    }

    await _restoreSnapshot(prefs, uid);
    await prefs.setString(_activeUidKey, uid);
    debugPrint('Account-local storage switched to $uid');
  }

  Future<void> _saveSnapshot(SharedPreferences prefs, String uid) async {
    final values = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      if (_metadataKeys.contains(key) || key.startsWith(_snapshotPrefix)) {
        continue;
      }
      final value = prefs.get(key);
      if (value is String || value is num || value is bool || value is List<String>) {
        values[key] = value;
      }
    }
    await prefs.setString('$_snapshotPrefix$uid', jsonEncode(values));
  }

  Future<void> _restoreSnapshot(SharedPreferences prefs, String uid) async {
    final raw = prefs.getString('$_snapshotPrefix$uid');
    if (raw == null || raw.isEmpty) return;
    try {
      final values = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in values.entries) {
        final value = entry.value;
        if (value is String) {
          await prefs.setString(entry.key, value);
        } else if (value is bool) {
          await prefs.setBool(entry.key, value);
        } else if (value is int) {
          await prefs.setInt(entry.key, value);
        } else if (value is double) {
          await prefs.setDouble(entry.key, value);
        } else if (value is num) {
          await prefs.setDouble(entry.key, value.toDouble());
        } else if (value is List) {
          await prefs.setStringList(entry.key, value.map((e) => e.toString()).toList());
        }
      }
    } catch (e) {
      debugPrint('Could not restore local account snapshot: $e');
    }
  }
}
