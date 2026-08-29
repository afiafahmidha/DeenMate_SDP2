import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/auth_header.dart'; // AppColors
import '../services/theme_service.dart';
import '../services/language_service.dart';
import '../l10n/app_localizations.dart';
import '../services/notification_service.dart';
import '../widgets/notification_center_modal.dart';
import 'contact_support_screen.dart';
import 'about_screen.dart';

/// ===== PROFILE TAB =====
/// NOTE ON DEPENDENCIES: this file uses `image_picker` to let the user pick
/// a profile photo from the device gallery or take one with the camera.
/// Add to pubspec.yaml if not already present:
///   image_picker: ^1.1.2
/// Android: no manifest changes needed for modern image_picker versions.
/// iOS: add to Info.plist:
///   NSPhotoLibraryUsageDescription — "Used to set your profile photo"
///   NSCameraUsageDescription       — "Used to take your profile photo"
class ProfileTab extends StatefulWidget {
  final VoidCallback onLogout;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const ProfileTab({
    super.key,
    required this.onLogout,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _isEditing = false;

  // Profile photo — a real picked file now, instead of a preset gradient avatar.
  File? _avatarImage;
  String? _avatarBase64;

  // Quran reading preferences (merged in from the old "Quran Journey" settings page).
  double _arabicFontSize = 24;
  bool _banglaTranslation = true;
  bool _englishTranslation = true;

  // Notifications — single on/off as requested.
  bool _notificationsEnabled = true;

  // ===== EDITABLE FIELDS ===== (email is intentionally NOT included — it's locked)
  // NOTE: these must start EMPTY. Never hardcode a real person's data here —
  // it was leftover test data ("Rahim Uddin") that flashed on screen for
  // every user before their real profile finished loading.
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  // Locked — shown as plain text everywhere, never becomes a TextField.
  String _email = "";

  // True once we've loaded the CURRENT user's real data, so the UI doesn't
  // flash placeholder/stale text while loading.
  bool _profileLoaded = false;

  // Which uid the fields currently on screen belong to. Used to detect a
  // login/logout so we can reload — this tab widget can stay alive (e.g.
  // inside an IndexedStack) across an account switch, and without this,
  // initState() would only ever run once and the old account's fields
  // would just sit there after a different user logs in.
  String? _loadedForUid;
  StreamSubscription<User?>? _authSub;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    appLanguageNotifier.addListener(() {
      if (mounted) setState(() {});
    });
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      if (user?.uid != _loadedForUid) {
        setState(() => _profileLoaded = false); // show spinner, not stale data
        _loadSettings();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // No one is signed in — nothing to load, just stop "loading".
      setState(() {
        _profileLoaded = true;
        _loadedForUid = null;
      });
      return;
    }
    final uid = user.uid;

    // ---- FIX: SharedPreferences keys used to be global (e.g. "profile_name"),
    // shared by every account that ever logged in on this device. That's why a
    // different user's old data ("Rahim Uddin") could show up for someone else.
    // We now namespace every cached key by the current Firebase UID, and we
    // wipe any old un-namespaced keys left over from before this fix.
    String k(String base) => '${base}_$uid';

    // One-time cleanup of the old global keys so they can never leak again.
    for (final oldKey in [
      'profile_name', 'profile_phone', 'profile_address', 'profile_email',
      'profile_avatar_path', 'profile_avatar_base64',
    ]) {
      if (prefs.containsKey(oldKey)) await prefs.remove(oldKey);
    }

    final savedImagePath = prefs.getString(k('profile_avatar_path'));
    String savedImageBase64 = prefs.getString(k('profile_avatar_base64')) ?? "";

    // Cached values scoped to THIS user only.
    String name = prefs.getString(k('profile_name')) ?? "";
    String phone = prefs.getString(k('profile_phone')) ?? "";
    String address = prefs.getString(k('profile_address')) ?? "";
    String email = prefs.getString(k('profile_email')) ?? user.email ?? "";

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['profile'] != null) {
          final profile = data['profile'] as Map<String, dynamic>;
          // Firestore is the source of truth — always prefer it when present.
          name = (profile['fullName'] as String?)?.isNotEmpty == true ? profile['fullName'] : name;
          phone = (profile['phone'] as String?)?.isNotEmpty == true ? profile['phone'] : phone;
          address = (profile['address'] as String?)?.isNotEmpty == true ? profile['address'] : address;
          if (profile['email'] != null && (profile['email'] as String).isNotEmpty) {
            email = profile['email'];
          }
          if (profile['avatarBase64'] != null) {
            savedImageBase64 = profile['avatarBase64'];
          }

          // Cache under this user's namespaced keys only.
          await prefs.setString(k('profile_name'), name);
          await prefs.setString(k('profile_phone'), phone);
          await prefs.setString(k('profile_address'), address);
          await prefs.setString(k('profile_email'), email);
          await prefs.setString(k('profile_avatar_base64'), savedImageBase64);
        }
      } else {
        // Brand-new profile doc. Seed it ONLY from this user's own Firebase
        // Auth account — never from local cache, which could belong to a
        // previous account on this device.
        name = user.displayName ?? "";
        email = user.email ?? "";
        phone = "";
        address = "";
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'profile': {
            'fullName': name,
            'email': email,
            'phone': null,
            'address': null,
            'avatarPath': user.photoURL,
            'avatarBase64': null,
            'language': 'en',
            'darkMode': false,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading profile from Firestore: $e");
    }

    if (name.isEmpty) name = user.displayName ?? "";
    if (email.isEmpty) email = user.email ?? "";

    setState(() {
      _fullNameController.text = name;
      _phoneController.text = phone;
      _addressController.text = address;
      _email = email;
      _profileLoaded = true;
      _loadedForUid = uid;

      _arabicFontSize = prefs.getDouble('quran_font_size') ?? 24;
      _banglaTranslation = prefs.getBool('quran_bangla_translation') ?? true;
      _englishTranslation = prefs.getBool('quran_english_translation') ?? true;

      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;

      _avatarBase64 = savedImageBase64;
      if (savedImagePath != null && savedImagePath.isNotEmpty) {
        _avatarImage = File(savedImagePath);
      }
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    // Keep saves namespaced per-user too, same fix as _loadSettings, so one
    // account's edits can never bleed into another account's cache.
    String k(String base) => user != null ? '${base}_${user.uid}' : base;

    final fullName = _fullNameController.text.trim();
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();

    await prefs.setString(k('profile_name'), fullName);
    await prefs.setString(k('profile_phone'), phone);
    await prefs.setString(k('profile_address'), address);
    // Email is deliberately never written from a user-editable field.

    await prefs.setDouble('quran_font_size', _arabicFontSize);
    await prefs.setBool('quran_bangla_translation', _banglaTranslation);
    await prefs.setBool('quran_english_translation', _englishTranslation);

    await prefs.setBool('notifications_enabled', _notificationsEnabled);

    if (_avatarImage != null) {
      await prefs.setString(k('profile_avatar_path'), _avatarImage!.path);
    }

    final avatarBase64 = prefs.getString(k('profile_avatar_base64'));

    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'profile.fullName': fullName,
          'profile.phone': phone,
          'profile.address': address,
          'profile.avatarBase64': avatarBase64,
          'profile.updatedAt': FieldValue.serverTimestamp(),
        });

        // Also update FirebaseAuth display name
        await user.updateDisplayName(fullName);
      } catch (e) {
        // If document doesn't support update (e.g. doesn't exist yet), set it
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'profile': {
              'fullName': fullName,
              'email': user.email ?? _email,
              'phone': phone,
              'address': address,
              'avatarPath': user.photoURL,
              'avatarBase64': avatarBase64,
              'language': 'en',
              'darkMode': false,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }
          }, SetOptions(merge: true));
        } catch (err) {
          debugPrint("Error updating profile in Firestore: $err");
        }
      }
    }
  }

  // ===== IMAGE PICKING =====
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 200,
        maxHeight: 200,
        imageQuality: 75,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final base64Str = base64Encode(bytes);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_avatar_base64', base64Str);
        await prefs.setString('profile_avatar_path', picked.path);

        setState(() {
          _avatarImage = File(picked.path);
          _avatarBase64 = base64Str;
        });
        await _saveSettings();
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.tr("could_not_open")} ${source == ImageSource.camera ? l10n.tr("take_photo") : l10n.tr("gallery")}: $e')),
        );
      }
    }
  }

  Color _getPrimaryThemeColor() => AppColors.midTeal;

  Color _getBgColor() => widget.isDarkMode ? const Color(0xFF121212) : const Color(0xFFF7F9FC);

  Color _getCardColor() => widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

  Color _getTextColor() => widget.isDarkMode ? Colors.white : const Color(0xFF2C3E50);

  Color _getSubtextColor() => widget.isDarkMode ? Colors.white70 : Colors.black54;

  bool get _isBengali => LanguageService.currentLanguage == LanguageService.bn;
  String _t(String key) => AppLocalizations.of(context)!.tr(key);

  @override
  Widget build(BuildContext context) {
    final primaryColor = _getPrimaryThemeColor();
    final bgColor = _getBgColor();
    final cardBg = _getCardColor();
    final textColor = _getTextColor();
    final subtextColor = _getSubtextColor();

    if (!_profileLoaded) {
      return Container(
        color: bgColor,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    return Container(
      color: bgColor,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildProfileAvatarCard(primaryColor, cardBg, textColor, subtextColor),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: [
                  // Account Information: name/phone/address editable, email locked.
                  _buildSectionCard(
                    title: _t('personal_info'),
                    icon: Icons.account_circle_rounded,
                    accentColor: primaryColor,
                    cardBg: cardBg,
                    textColor: textColor,
                    children: [
                      _buildProfileField(_t('full_name'), _fullNameController),
                      _buildLockedEmailField(textColor, subtextColor),
                      _buildProfileField(_t('phone'), _phoneController, keyboardType: TextInputType.phone),
                      _buildProfileField(_t('address'), _addressController),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // App Settings: theme + language.
                  _buildSettingsCard(primaryColor, cardBg, textColor, subtextColor),
                  const SizedBox(height: 14),

                  // Notifications Section
                  _buildSectionCard(
                    title: _t('notifications'),
                    icon: Icons.notifications_active_rounded,
                    accentColor: primaryColor,
                    cardBg: cardBg,
                    textColor: textColor,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Icon(Icons.settings_suggest_rounded, color: primaryColor, size: 18),
                        title: Text(
                          'Notification Center & Controls',
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        subtitle: Text(
                          'Manage prayer alarms, dhikr, zakat & snooze time (${NotificationService.instance.snoozeDurationMinutes}m)',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: textColor.withValues(alpha: 0.6),
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                        onTap: () {
                          NotificationCenterModal.show(
                            context,
                            isDarkMode: widget.isDarkMode,
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Help & Support
                  _buildSectionCard(
                    title: _t('help_support'),
                    icon: Icons.help_outline_rounded,
                    accentColor: primaryColor,
                    cardBg: cardBg,
                    textColor: textColor,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Icon(Icons.support_agent_rounded, color: primaryColor, size: 18),
                        title: Text(_t('contact_us'),
                            style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ContactSupportScreen(
                                isDarkMode: widget.isDarkMode,
                              ),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Icon(Icons.info_outline_rounded, color: primaryColor, size: 18),
                        title: Text(_t('about'),
                            style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AboutScreen(
                                isDarkMode: widget.isDarkMode,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: ElevatedButton.icon(
                      onPressed: widget.onLogout,
                      icon: const Icon(Icons.logout_rounded, size: 16),
                      label: Text(_t('logout'), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.isDarkMode ? const Color(0xFF3B1E1E) : Colors.red[50],
                        foregroundColor: Colors.red[400],
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.red.withValues(alpha: 0.2)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== HEADER: photo, name, locked email, edit toggle =====
  Widget _buildProfileAvatarCard(Color primaryColor, Color cardBg, Color textColor, Color subtextColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
      decoration: BoxDecoration(
        color: cardBg,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Center(
            child: Stack(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor.withValues(alpha: 0.15),
                    image: _avatarImage != null
                        ? DecorationImage(image: FileImage(_avatarImage!), fit: BoxFit.cover)
                        : (_avatarBase64 != null && _avatarBase64!.isNotEmpty)
                            ? DecorationImage(image: MemoryImage(base64Decode(_avatarBase64!)), fit: BoxFit.cover)
                            : null,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: (_avatarImage == null && (_avatarBase64 == null || _avatarBase64!.isEmpty))
                      ? Center(
                          child: Text(
                            _fullNameController.text.isNotEmpty
                                ? _fullNameController.text.substring(0, 1).toUpperCase()
                                : "U",
                            style: GoogleFonts.poppins(fontSize: 34, fontWeight: FontWeight.bold, color: primaryColor),
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: InkWell(
                    onTap: _showImageSourceSheet,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: cardBg, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          _isEditing
              ? SizedBox(
                  width: 200,
                  height: 38,
                  child: TextField(
                    controller: _fullNameController,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(vertical: 4)),
                  ),
                )
              : Text(
                  _fullNameController.text,
                  style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold, color: textColor),
                ),
          const SizedBox(height: 2),

          // Email — always plain text here too, never editable.
          Text(_email, style: GoogleFonts.inter(fontSize: 12, color: subtextColor)),
          const SizedBox(height: 10),

          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                if (_isEditing) {
                  _isEditing = false;
                  _saveSettings();
                } else {
                  _isEditing = true;
                }
              });
            },
            icon: Icon(_isEditing ? Icons.check_circle_rounded : Icons.edit_rounded,
                size: 14, color: widget.isDarkMode ? Colors.white : Colors.black87),
            label: Text(
              _isEditing ? _t('save') : _t('edit'),
              style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.bold, color: widget.isDarkMode ? Colors.white : Colors.black87),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
            ),
          ),
        ],
      ),
    );
  }

  // ===== Camera / Gallery picker sheet =====
  void _showImageSourceSheet() {
    final cardBg = _getCardColor();
    final textColor = _getTextColor();
    final primaryColor = _getPrimaryThemeColor();

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_t('change_photo'),
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.camera_alt_rounded, color: primaryColor),
                  title: Text(_t('take_photo'),
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.photo_library_rounded, color: primaryColor),
                  title: Text(_t('choose_gallery'),
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===== App Settings: theme + language =====
  Widget _buildSettingsCard(Color primaryColor, Color cardBg, Color textColor, Color subtextColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, color: primaryColor, size: 18),
              const SizedBox(width: 8),
              Text(_t('app_settings'),
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
            ],
          ),
          const Divider(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_t('language'), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'English',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_t('theme_mode'), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
              Switch(
                value: widget.isDarkMode,
                activeThumbColor: primaryColor,
                onChanged: (val) => widget.onThemeChanged(val),
              ),
            ],
          ),
          const Divider(height: 14),
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(Icons.style_rounded, color: primaryColor, size: 18),
             title: Text(
              _t('prayer_card_theme_selection'),
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
            ),
            subtitle: Text(
              _t('hero_video_or_vector'),
              style: GoogleFonts.inter(fontSize: 10, color: subtextColor),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => PrayerCardThemeSelectionScreen(
                    isDarkMode: widget.isDarkMode,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }



  // ===== Generic section wrapper =====
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color accentColor,
    required Color cardBg,
    required Color textColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 18),
              const SizedBox(width: 8),
              Text(title, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
            ],
          ),
          const Divider(height: 18),
          ...children,
        ],
      ),
    );
  }

  // ===== Editable text field (name / phone / address) =====
  Widget _buildProfileField(String label, TextEditingController controller,
      {TextInputType keyboardType = TextInputType.text, int maxLines = 1}) {
    final textColor = _getTextColor();
    final labelColor = widget.isDarkMode ? Colors.white38 : Colors.grey[500]!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: labelColor)),
          const SizedBox(height: 4),
          _isEditing
              ? TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  maxLines: maxLines,
                  style: GoogleFonts.poppins(fontSize: 12.5, color: textColor),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    filled: true,
                    fillColor: widget.isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[50],
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _getPrimaryThemeColor()),
                    ),
                  ),
                )
              : Text(
                  controller.text.isEmpty ? "—" : controller.text,
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: textColor),
                ),
        ],
      ),
    );
  }

  // ===== Locked email field — plain text always, regardless of edit mode =====
  Widget _buildLockedEmailField(Color textColor, Color subtextColor) {
    final labelColor = widget.isDarkMode ? Colors.white38 : Colors.grey[500]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_t('email'), style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: labelColor)),
              const SizedBox(width: 6),
              Icon(Icons.lock_outline_rounded, size: 11, color: labelColor),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(_email, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
              ),
            ],
          ),
          if (_isEditing) ...[
            const SizedBox(height: 3),
            Text(_t('email_locked'), style: GoogleFonts.inter(fontSize: 10, color: subtextColor)),
          ],
        ],
      ),
    );
  }
}

// ===== PRAYER CARD THEME SELECTION SCREEN =====
// Shows only 2 options: actual playing video, actual vector art.
class PrayerCardThemeSelectionScreen extends StatefulWidget {
  final bool isDarkMode;

  const PrayerCardThemeSelectionScreen({
    super.key,
    required this.isDarkMode,
  });

  @override
  State<PrayerCardThemeSelectionScreen> createState() => _PrayerCardThemeSelectionScreenState();
}

class _PrayerCardThemeSelectionScreenState extends State<PrayerCardThemeSelectionScreen>
    with SingleTickerProviderStateMixin {

  // Vector art animation controller
  late AnimationController _vectorAnimController;
  late Animation<double> _vectorAnim;

  @override
  void initState() {
    super.initState();
    _vectorAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _vectorAnim = CurvedAnimation(parent: _vectorAnimController, curve: Curves.linear);
  }

  @override
  void dispose() {
    _vectorAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDarkMode ? const Color(0xFF121212) : const Color(0xFFF7F9FC);
    final cardBg = widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : const Color(0xFF2C3E50);
    final subtextColor = widget.isDarkMode ? Colors.white70 : Colors.black54;
    final primaryColor = AppColors.midTeal;

    return Scaffold(
      backgroundColor: widget.isDarkMode ? Colors.black : const Color(0xFFE8ECEF),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            color: bgColor,
            child: SafeArea(
              child: Column(
                children: [
                  // ── Header ──
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    decoration: BoxDecoration(
                      color: cardBg,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                               Text(
                                 AppLocalizations.of(context)!.tr('prayer_card_theme_selection'),
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                               Text(
                                 AppLocalizations.of(context)!.tr('hero_video_or_vector'),
                                style: GoogleFonts.inter(fontSize: 10.5, color: subtextColor),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── The 2 theme cards side by side (compact size) ──
                  ValueListenableBuilder<String>(
                    valueListenable: prayerCardThemeNotifier,
                    builder: (context, currentThemeId, _) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── VIDEO CARD ──
                            Expanded(
                              child: _buildVideoCard(
                                isSelected: currentThemeId == 'video',
                                cardBg: cardBg,
                                textColor: textColor,
                                subtextColor: subtextColor,
                                primaryColor: primaryColor,
                              ),
                            ),
                            const SizedBox(width: 14),
                            // ── VECTOR CARD ──
                            Expanded(
                              child: _buildVectorCard(
                                isSelected: currentThemeId == 'vector',
                                cardBg: cardBg,
                                textColor: textColor,
                                subtextColor: subtextColor,
                                primaryColor: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── VIDEO CARD: plays the actual fajr prayer video ──
  Widget _buildVideoCard({
    required bool isSelected,
    required Color cardBg,
    required Color textColor,
    required Color subtextColor,
    required Color primaryColor,
  }) {
    return GestureDetector(
      onTap: () async {
        await savePrayerCardThemePreference('video');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context)!.tr('video_theme_selected')),
            duration: const Duration(seconds: 1),
            backgroundColor: primaryColor,
          ));
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.withValues(alpha: 0.2),
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? primaryColor.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: isSelected ? 10 : 4,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Actual video preview (compact height)
              SizedBox(
                height: 140,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _ActualVideoPreview(videoAsset: 'assets/videos/fajr.mp4'),
                    // subtle bottom scrim
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                    // VIDEO badge
                    Positioned(
                      top: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.videocam_rounded, color: Color(0xFF4ECDC4), size: 11),
                            const SizedBox(width: 3),
                            Text('VIDEO', style: GoogleFonts.inter(
                              fontSize: 9, fontWeight: FontWeight.w800,
                              color: Colors.white, letterSpacing: 0.5,
                            )),
                          ],
                        ),
                      ),
                    ),
                    // Selected check
                    if (isSelected)
                      Positioned(
                        top: 8, right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 13),
                        ),
                      ),
                  ],
                ),
              ),
              // Label
              Container(
                color: cardBg,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Text(
                      AppLocalizations.of(context)!.tr('video_theme'),
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(context)!.tr('video_theme_desc'),
                      style: GoogleFonts.inter(fontSize: 10, color: subtextColor, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── VECTOR CARD: renders the actual animated vector art ──
  Widget _buildVectorCard({
    required bool isSelected,
    required Color cardBg,
    required Color textColor,
    required Color subtextColor,
    required Color primaryColor,
  }) {
    return GestureDetector(
      onTap: () async {
        await savePrayerCardThemePreference('vector');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context)!.tr('vector_theme_selected')),
            duration: const Duration(seconds: 1),
            backgroundColor: primaryColor,
          ));
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.withValues(alpha: 0.2),
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? primaryColor.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: isSelected ? 10 : 4,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Actual animated vector art (compact height)
              SizedBox(
                height: 140,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Deep-night gradient sky
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF0D1B3E), Color(0xFF1B2A56), Color(0xFF2C3E6B)],
                        ),
                      ),
                    ),
                    // Animated vector painter (twinkling stars, glowing moon)
                    AnimatedBuilder(
                      animation: _vectorAnim,
                      builder: (context, child) => CustomPaint(
                        painter: _ActualVectorPainter(animValue: _vectorAnim.value),
                      ),
                    ),
                    // VECTOR badge
                    Positioned(
                      top: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFD166), size: 11),
                            const SizedBox(width: 3),
                            Text('VECTOR', style: GoogleFonts.inter(
                              fontSize: 9, fontWeight: FontWeight.w800,
                              color: Colors.white, letterSpacing: 0.5,
                            )),
                          ],
                        ),
                      ),
                    ),
                    // Selected check
                    if (isSelected)
                      Positioned(
                        top: 8, right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 13),
                        ),
                      ),
                  ],
                ),
              ),
              // Label
              Container(
                color: cardBg,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Text(
                      AppLocalizations.of(context)!.tr('vector_art'),
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(context)!.tr('vector_theme_desc'),
                      style: GoogleFonts.inter(fontSize: 10, color: subtextColor, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Actual video player preview widget ──
class _ActualVideoPreview extends StatefulWidget {
  final String videoAsset;
  const _ActualVideoPreview({required this.videoAsset});

  @override
  State<_ActualVideoPreview> createState() => _ActualVideoPreviewState();
}

class _ActualVideoPreviewState extends State<_ActualVideoPreview> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.videoAsset);
    _controller.initialize().then((_) {
      if (mounted) {
        _controller.setLooping(true);
        _controller.setVolume(0);
        _controller.play();
        setState(() => _initialized = true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Container(
        color: const Color(0xFF1B2A44),
        child: const Center(
          child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
          ),
        ),
      );
    }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: _controller.value.size.width,
        height: _controller.value.size.height,
        child: VideoPlayer(_controller),
      ),
    );
  }
}

// ── Actual vector art painter — mosque silhouette + glowing outline + animated stars + moon ──
class _ActualVectorPainter extends CustomPainter {
  final double animValue;
  _ActualVectorPainter({required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Glowing Crescent Moon
    final moonGlow = Paint()
      ..color = const Color(0xFFE0F2FE).withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(Offset(w * 0.78, h * 0.22), 20, moonGlow);

    final moonFill = Paint()
      ..color = const Color(0xFFE0F2FE)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.78, h * 0.22), 13, moonFill);

    final moonBite = Paint()
      ..color = const Color(0xFF1B2A56)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.78 + 7, h * 0.22 - 3), 11, moonBite);

    // Sparkling Stars
    final List<Offset> starLocations = [
      Offset(w * 0.15, h * 0.15),
      Offset(w * 0.35, h * 0.22),
      Offset(w * 0.52, h * 0.10),
      Offset(w * 0.65, h * 0.28),
      Offset(w * 0.22, h * 0.35),
    ];
    for (int i = 0; i < starLocations.length; i++) {
      final loc = starLocations[i];
      final alpha = 0.35 + 0.45 * math.sin(animValue * 2 * math.pi + i * 1.2);
      final starPaint = Paint()
        ..color = Colors.white.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;

      final path = Path();
      final cx = loc.dx;
      final cy = loc.dy;
      final r = 3.0;

      path.moveTo(cx, cy - r);
      path.quadraticBezierTo(cx, cy, cx + r, cy);
      path.quadraticBezierTo(cx, cy, cx, cy + r);
      path.quadraticBezierTo(cx, cy, cx - r, cy);
      path.quadraticBezierTo(cx, cy, cx, cy - r);
      path.close();

      canvas.drawPath(path, starPaint);
    }

    // Mosque Silhouette with Crisp Glowing Outline (#E0F2FE)
    final glowPaint = Paint()
      ..color = const Color(0xFFE0F2FE).withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3);

    final crispLinePaint = Paint()
      ..color = const Color(0xFFE0F2FE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final bodyPaint = Paint()
      ..color = const Color(0xFF202B48)
      ..style = PaintingStyle.fill;

    final domePaint = Paint()
      ..color = const Color(0xFF2B385C)
      ..style = PaintingStyle.fill;

    final double mosqueRight = w * 0.98;
    final double mosqueWidth = w * 0.75;
    final double mosqueHeight = h * 0.52;
    final double by = h;
    final double cx = mosqueRight - mosqueWidth / 2;

    // 1. Draw Side Domes (Background layer)
    _drawOnionDomeWithOutline(
      canvas,
      cx - mosqueWidth * 0.26,
      by - mosqueHeight * 0.35,
      mosqueWidth * 0.20,
      mosqueHeight * 0.32,
      domePaint,
      glowPaint,
      crispLinePaint,
    );
    _drawOnionDomeWithOutline(
      canvas,
      cx + mosqueWidth * 0.26,
      by - mosqueHeight * 0.35,
      mosqueWidth * 0.20,
      mosqueHeight * 0.32,
      domePaint,
      glowPaint,
      crispLinePaint,
    );

    // 2. Draw Center Onion Dome (Foreground main layer)
    final centerDomeW = mosqueWidth * 0.38;
    final centerDomeH = mosqueHeight * 0.55;
    final centerDomeY = by - mosqueHeight * 0.35;
    _drawOnionDomeWithOutline(
      canvas,
      cx,
      centerDomeY,
      centerDomeW,
      centerDomeH,
      bodyPaint,
      glowPaint,
      crispLinePaint,
    );

    // Spire on center dome
    final spireTopY = centerDomeY - centerDomeH;
    canvas.drawLine(Offset(cx, spireTopY), Offset(cx, spireTopY - 18), crispLinePaint);
    canvas.drawCircle(Offset(cx, spireTopY - 18), 3.0, bodyPaint);
    canvas.drawCircle(Offset(cx, spireTopY - 18), 3.0, crispLinePaint);

    // 3. Draw Connective Base Walls
    final wallPath = Path()
      ..moveTo(cx - mosqueWidth * 0.44, by)
      ..lineTo(cx - mosqueWidth * 0.44, by - mosqueHeight * 0.38)
      ..lineTo(cx + mosqueWidth * 0.44, by - mosqueHeight * 0.38)
      ..lineTo(cx + mosqueWidth * 0.44, by)
      ..close();
    canvas.drawPath(wallPath, bodyPaint);
    canvas.drawPath(wallPath, glowPaint);
    canvas.drawPath(wallPath, crispLinePaint);

    // 4. Draw Minarets (Left & Right columns with 2 balconies and onion caps)
    _drawMinaretWithOutline(
      canvas,
      cx - mosqueWidth * 0.42,
      by,
      mosqueWidth * 0.08,
      mosqueHeight * 0.88,
      bodyPaint,
      domePaint,
      glowPaint,
      crispLinePaint,
    );
    _drawMinaretWithOutline(
      canvas,
      cx + mosqueWidth * 0.42,
      by,
      mosqueWidth * 0.08,
      mosqueHeight * 0.88,
      bodyPaint,
      domePaint,
      glowPaint,
      crispLinePaint,
    );

    // 5. Draw Central Arched Door
    final doorW = mosqueWidth * 0.16;
    final doorH = mosqueHeight * 0.28;
    final doorPath = Path()
      ..moveTo(cx - doorW / 2, by)
      ..lineTo(cx - doorW / 2, by - doorH * 0.65)
      ..quadraticBezierTo(cx, by - doorH, cx + doorW / 2, by - doorH * 0.65)
      ..lineTo(cx + doorW / 2, by)
      ..close();
    canvas.drawPath(doorPath, domePaint);
    canvas.drawPath(doorPath, glowPaint);
    canvas.drawPath(doorPath, crispLinePaint);
  }

  void _drawOnionDomeWithOutline(
    Canvas canvas,
    double cx,
    double by,
    double width,
    double height,
    Paint fillPaint,
    Paint glowPaint,
    Paint crispPaint,
  ) {
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

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, crispPaint);
  }

  void _drawMinaretWithOutline(
    Canvas canvas,
    double cx,
    double by,
    double width,
    double height,
    Paint bodyPaint,
    Paint capPaint,
    Paint glowPaint,
    Paint crispPaint,
  ) {
    final double colW = width * 0.65;
    final double balconyW = width * 1.25;

    // Column body
    final colRect = Rect.fromLTRB(cx - colW / 2, by - height, cx + colW / 2, by);
    canvas.drawRect(colRect, bodyPaint);
    canvas.drawRect(colRect, glowPaint);
    canvas.drawRect(colRect, crispPaint);

    // Lower Balcony
    final b1Rect = Rect.fromLTRB(cx - balconyW / 2, by - height * 0.75, cx + balconyW / 2, by - height * 0.71);
    canvas.drawRect(b1Rect, bodyPaint);
    canvas.drawRect(b1Rect, glowPaint);
    canvas.drawRect(b1Rect, crispPaint);

    // Upper Balcony
    final b2Rect = Rect.fromLTRB(cx - balconyW / 2, by - height - 4, cx + balconyW / 2, by - height);
    canvas.drawRect(b2Rect, bodyPaint);
    canvas.drawRect(b2Rect, glowPaint);
    canvas.drawRect(b2Rect, crispPaint);

    // Onion Dome Cap
    _drawOnionDomeWithOutline(
      canvas,
      cx,
      by - height - 4,
      width * 0.75,
      height * 0.16,
      capPaint,
      glowPaint,
      crispPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ActualVectorPainter old) => old.animValue != animValue;
}