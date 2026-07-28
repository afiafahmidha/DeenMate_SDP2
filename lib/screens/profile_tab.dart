import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/auth_header.dart'; // AppColors

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
  bool _isBengali = false;
  bool _isEditing = false;

  // Profile photo — a real picked file now, instead of a preset gradient avatar.
  File? _avatarImage;

  // Quran reading preferences (merged in from the old "Quran Journey" settings page).
  double _arabicFontSize = 24;
  bool _banglaTranslation = true;
  bool _englishTranslation = true;

  // Notifications — single on/off as requested.
  bool _notificationsEnabled = true;

  // ===== EDITABLE FIELDS ===== (email is intentionally NOT included — it's locked)
  final _fullNameController = TextEditingController(text: "Muhammad Ali");
  final _phoneController = TextEditingController(text: "+880 1712-345678");
  final _addressController = TextEditingController(text: "Dhaka, Bangladesh");

  // Locked — shown as plain text everywhere, never becomes a TextField.
  String _email = "muhammad.ali@deenmate.com";

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedImagePath = prefs.getString('profile_avatar_path');
    setState(() {
      _isBengali = prefs.getBool('is_bengali') ?? false;

      _fullNameController.text = prefs.getString('profile_name') ?? "Muhammad Ali";
      _phoneController.text = prefs.getString('profile_phone') ?? "+880 1712-345678";
      _addressController.text = prefs.getString('profile_address') ?? "Dhaka, Bangladesh";
      _email = prefs.getString('profile_email') ?? "muhammad.ali@deenmate.com";

      _arabicFontSize = prefs.getDouble('quran_font_size') ?? 24;
      _banglaTranslation = prefs.getBool('quran_bangla_translation') ?? true;
      _englishTranslation = prefs.getBool('quran_english_translation') ?? true;

      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;

      if (savedImagePath != null && savedImagePath.isNotEmpty) {
        _avatarImage = File(savedImagePath);
      }
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_bengali', _isBengali);

    await prefs.setString('profile_name', _fullNameController.text);
    await prefs.setString('profile_phone', _phoneController.text);
    await prefs.setString('profile_address', _addressController.text);
    // Email is deliberately never written from a user-editable field.

    await prefs.setDouble('quran_font_size', _arabicFontSize);
    await prefs.setBool('quran_bangla_translation', _banglaTranslation);
    await prefs.setBool('quran_english_translation', _englishTranslation);

    await prefs.setBool('notifications_enabled', _notificationsEnabled);

    if (_avatarImage != null) {
      await prefs.setString('profile_avatar_path', _avatarImage!.path);
    }
  }

  // ===== IMAGE PICKING =====
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _avatarImage = File(picked.path);
        });
        await _saveSettings();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open ${source == ImageSource.camera ? 'camera' : 'gallery'}: $e')),
        );
      }
    }
  }

  Color _getPrimaryThemeColor() => AppColors.midTeal;

  Color _getBgColor() => widget.isDarkMode ? const Color(0xFF121212) : const Color(0xFFF7F9FC);

  Color _getCardColor() => widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

  Color _getTextColor() => widget.isDarkMode ? Colors.white : const Color(0xFF2C3E50);

  Color _getSubtextColor() => widget.isDarkMode ? Colors.white70 : Colors.black54;

  final Map<String, Map<String, String>> _localizedText = {
    'en': {
      'profile': 'My Profile',
      'subtitle': 'Personal settings & account information',
      'language': 'App Language',
      'theme_mode': 'Dark Mode Theme',
      'personal_info': 'Account Information',
      'full_name': 'Full Name',
      'email': 'Email Address',
      'phone': 'Phone Number',
      'address': 'Address',
      'quran_settings': 'Quran Reading Settings',
      'arabic_font_size': 'Arabic Font Size',
      'bangla_translation': 'Bangla Translation',
      'english_translation': 'English Translation',
      'notifications': 'Notifications',
      'app_notifications': 'App Notifications',
      'help_support': 'Help & Support',
      'contact_us': 'Contact Support Team',
      'about': 'About DeenMate',
      'save': 'Save Profile',
      'edit': 'Edit Profile',
      'logout': 'Sign Out',
      'change_photo': 'Change Profile Photo',
      'take_photo': 'Take Photo',
      'choose_gallery': 'Choose from Gallery',
      'email_locked': 'Email cannot be changed',
    },
    'bn': {
      'profile': 'আমার প্রোফাইল',
      'subtitle': 'ব্যক্তিগত তথ্য ও অ্যাপ সেটিংস',
      'language': 'অ্যাপের ভাষা',
      'theme_mode': 'ডার্ক মোড থিম',
      'personal_info': 'অ্যাকাউন্টের তথ্য',
      'full_name': 'সম্পূর্ণ নাম',
      'email': 'ইমেইল ঠিকানা',
      'phone': 'ফোন নম্বর',
      'address': 'ঠিকানা',
      'quran_settings': 'কুরআন পড়ার সেটিংস',
      'arabic_font_size': 'আরবি ফন্ট সাইজ',
      'bangla_translation': 'বাংলা অনুবাদ',
      'english_translation': 'ইংরেজি অনুবাদ',
      'notifications': 'নোটিফিকেশন',
      'app_notifications': 'অ্যাপ নোটিফিকেশন',
      'help_support': 'সহায়তা ও সাপোর্ট',
      'contact_us': 'সহায়তা টিমের সাথে যোগাযোগ',
      'about': 'দীনমেট সম্পর্কে',
      'save': 'প্রোফাইল সংরক্ষণ',
      'edit': 'প্রোফাইল সম্পাদন',
      'logout': 'লগ আউট',
      'change_photo': 'প্রোফাইল ছবি পরিবর্তন',
      'take_photo': 'ছবি তুলুন',
      'choose_gallery': 'গ্যালারি থেকে বাছাই করুন',
      'email_locked': 'ইমেইল পরিবর্তন করা যাবে না',
    }
  };

  String _t(String key) {
    final lang = _isBengali ? 'bn' : 'en';
    return _localizedText[lang]![key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = _getPrimaryThemeColor();
    final bgColor = _getBgColor();
    final cardBg = _getCardColor();
    final textColor = _getTextColor();
    final subtextColor = _getSubtextColor();

    return Container(
      color: bgColor,
      child: SafeArea(
        child: Column(
          children: [
            _buildProfileAvatarCard(primaryColor, cardBg, textColor, subtextColor),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

                  // Quran reading settings — merged in from the separate settings page.
                  _buildQuranSettingsCard(primaryColor, cardBg, textColor, subtextColor),
                  const SizedBox(height: 14),

                  // Notifications — single toggle.
                  _buildSectionCard(
                    title: _t('notifications'),
                    icon: Icons.notifications_active_rounded,
                    accentColor: primaryColor,
                    cardBg: cardBg,
                    textColor: textColor,
                    children: [
                      _buildToggleRow(
                        _t('app_notifications'),
                        Icons.notifications_rounded,
                        primaryColor,
                        textColor,
                        _notificationsEnabled,
                        (val) {
                          setState(() => _notificationsEnabled = val);
                          _saveSettings();
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
                        onTap: () {},
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Icon(Icons.info_outline_rounded, color: primaryColor, size: 18),
                        title: Text(_t('about'),
                            style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                        onTap: () {},
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
                        : null,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: _avatarImage == null
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
              Text(_isBengali ? 'অ্যাপ সেটিংস' : 'App Settings',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
            ],
          ),
          const Divider(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_t('language'), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
              DropdownButton<bool>(
                value: _isBengali,
                underline: const SizedBox(),
                dropdownColor: cardBg,
                style: GoogleFonts.poppins(fontSize: 12, color: textColor, fontWeight: FontWeight.bold),
                items: const [
                  DropdownMenuItem(value: false, child: Text("English")),
                  DropdownMenuItem(value: true, child: Text("বাংলা")),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _isBengali = val;
                      _saveSettings();
                    });
                  }
                },
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
        ],
      ),
    );
  }

  // ===== Quran reading settings (Arabic font size + Bangla/English translation) =====
  Widget _buildQuranSettingsCard(Color primaryColor, Color cardBg, Color textColor, Color subtextColor) {
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
              Icon(Icons.menu_book_rounded, color: primaryColor, size: 18),
              const SizedBox(width: 8),
              Text(_t('quran_settings'),
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
            ],
          ),
          const Divider(height: 18),

          // Arabic font size stepper
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_t('arabic_font_size'),
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
              Row(
                children: [
                  _stepperButton(Icons.remove_rounded, primaryColor, textColor, () {
                    if (_arabicFontSize > 14) {
                      setState(() => _arabicFontSize -= 1);
                      _saveSettings();
                    }
                  }),
                  SizedBox(
                    width: 30,
                    child: Text(
                      _arabicFontSize.toInt().toString(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                    ),
                  ),
                  _stepperButton(Icons.add_rounded, primaryColor, textColor, () {
                    if (_arabicFontSize < 40) {
                      setState(() => _arabicFontSize += 1);
                      _saveSettings();
                    }
                  }),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),

          _buildToggleRow(
            _t('bangla_translation'),
            Icons.translate_rounded,
            primaryColor,
            textColor,
            _banglaTranslation,
            (val) {
              setState(() => _banglaTranslation = val);
              _saveSettings();
            },
          ),
          _buildToggleRow(
            _t('english_translation'),
            Icons.translate_rounded,
            primaryColor,
            textColor,
            _englishTranslation,
            (val) {
              setState(() => _englishTranslation = val);
              _saveSettings();
            },
          ),
        ],
      ),
    );
  }

  Widget _stepperButton(IconData icon, Color primaryColor, Color textColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: primaryColor.withValues(alpha: 0.4)),
        ),
        child: Icon(icon, size: 14, color: primaryColor),
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

  // ===== Reusable toggle row (used for translations + notifications) =====
  Widget _buildToggleRow(
    String label,
    IconData icon,
    Color accentColor,
    Color textColor,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      secondary: Icon(icon, color: accentColor, size: 18),
      title: Text(label, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor)),
      value: value,
      activeThumbColor: accentColor,
      onChanged: onChanged,
    );
  }
}