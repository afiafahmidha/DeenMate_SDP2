import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/auth_header.dart'; // AppColors

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
  int _avatarIndex = 0; // index of selected profile avatar
  bool _isEditing = false;

  // Controllers for profile details (bio removed as requested)
  final _fullNameController = TextEditingController(text: "Muhammad Ali");
  final _emailController = TextEditingController(text: "muhammad.ali@deenmate.com");
  final _phoneController = TextEditingController(text: "+880 1712-345678");
  final _locationController = TextEditingController(text: "Dhaka, Bangladesh");

  // Avatar presets: list of gradient decoration styles
  final List<LinearGradient> _avatarGradients = [
    const LinearGradient(colors: [Color(0xFF80DEEA), Color(0xFF00ACC1)]), // Teal/Cyan
    const LinearGradient(colors: [Color(0xFFCE93D8), Color(0xFF8E24AA)]), // Purple
    const LinearGradient(colors: [Color(0xFFFFCC80), Color(0xFFF57C00)]), // Amber/Orange
    const LinearGradient(colors: [Color(0xFF9FA8DA), Color(0xFF3F51B5)]), // Indigo
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isBengali = prefs.getBool('is_bengali') ?? false;
      _avatarIndex = prefs.getInt('profile_avatar_index') ?? 0;

      _fullNameController.text = prefs.getString('profile_name') ?? "Muhammad Ali";
      _emailController.text = prefs.getString('profile_email') ?? "muhammad.ali@deenmate.com";
      _phoneController.text = prefs.getString('profile_phone') ?? "+880 1712-345678";
      _locationController.text = prefs.getString('profile_location') ?? "Dhaka, Bangladesh";
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_bengali', _isBengali);
    await prefs.setInt('profile_avatar_index', _avatarIndex);

    await prefs.setString('profile_name', _fullNameController.text);
    await prefs.setString('profile_email', _emailController.text);
    await prefs.setString('profile_phone', _phoneController.text);
    await prefs.setString('profile_location', _locationController.text);
  }

  Color _getPrimaryThemeColor() {
    return AppColors.midTeal;
  }

  Color _getBgColor() {
    return widget.isDarkMode ? const Color(0xFF121212) : const Color(0xFFF7F9FC);
  }

  Color _getCardColor() {
    return widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
  }

  Color _getTextColor() {
    return widget.isDarkMode ? Colors.white : const Color(0xFF2C3E50);
  }

  Color _getSubtextColor() {
    return widget.isDarkMode ? Colors.white70 : Colors.black54;
  }

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
      'location': 'Location / City',
      'security_settings': 'Privacy & Preferences',
      'prayer_alerts': 'Adhan Notifications',
      'silent_haram': 'Auto-Silence inside Haram',
      'help_support': 'Help & Support',
      'contact_us': 'Contact Support Team',
      'about': 'About DeenMate',
      'save': 'Save Profile',
      'edit': 'Edit Profile',
      'logout': 'Sign Out',
      'change_photo': 'Change Profile Picture',
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
      'location': 'অবস্থান / শহর',
      'security_settings': 'গোপনীয়তা ও সেটিংস',
      'prayer_alerts': 'আজান নোটিফিকেশন',
      'silent_haram': 'হারাম শরিফে অটো-সাইলেন্ট',
      'help_support': 'সহায়তা ও সাপোর্ট',
      'contact_us': 'সহায়তা টিমের সাথে যোগাযোগ',
      'about': 'দীনমেট সম্পর্কে',
      'save': 'প্রোফাইল সংরক্ষণ',
      'edit': 'প্রোফাইল সম্পাদন',
      'logout': 'লগ আউট',
      'change_photo': 'প্রোফাইল ছবি পরিবর্তন',
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
            // Profile Header Card (Avatar + Edit Toggle)
            _buildProfileAvatarCard(primaryColor, cardBg, textColor, subtextColor),
            
            // Scrollable settings list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // App Customization Settings Card (Language & Dark Mode Toggle)
                  _buildSettingsCard(primaryColor, cardBg, textColor, subtextColor),
                  const SizedBox(height: 14),

                  // Account Info Card (Full Name, Email, Phone, Location)
                  _buildSectionCard(
                    title: _t('personal_info'),
                    icon: Icons.account_circle_rounded,
                    accentColor: primaryColor,
                    cardBg: cardBg,
                    textColor: textColor,
                    children: [
                      _buildProfileField(_t('full_name'), _fullNameController),
                      _buildProfileField(_t('email'), _emailController, keyboardType: TextInputType.emailAddress),
                      _buildProfileField(_t('phone'), _phoneController, keyboardType: TextInputType.phone),
                      _buildProfileField(_t('location'), _locationController),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Privacy & Alerts Preferences Card
                  _buildSectionCard(
                    title: _t('security_settings'),
                    icon: Icons.settings_suggest_rounded,
                    accentColor: primaryColor,
                    cardBg: cardBg,
                    textColor: textColor,
                    children: [
                      _buildTogglePreferenceTile(_t('prayer_alerts'), Icons.notifications_active_rounded, primaryColor, textColor, subtextColor),
                      _buildTogglePreferenceTile(_t('silent_haram'), Icons.do_not_disturb_on_rounded, primaryColor, textColor, subtextColor),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Help & Support Card
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
                        leading: Icon(Icons.info_outline_rounded, color: primaryColor, size: 18),
                        title: Text(_t('about'), style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                        onTap: () {},
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Icon(Icons.support_agent_rounded, color: primaryColor, size: 18),
                        title: Text(_t('contact_us'), style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Log Out Button
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
                          side: BorderSide(color: Colors.red.withOpacity(0.2)),
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

  // Profile avatar header card with photo changer badge
  Widget _buildProfileAvatarCard(Color primaryColor, Color cardBg, Color textColor, Color subtextColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
      decoration: BoxDecoration(
        color: cardBg,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Avatar circle with camera icon overlay badge
          Center(
            child: Stack(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _avatarGradients[_avatarIndex],
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _fullNameController.text.isNotEmpty ? _fullNameController.text.substring(0, 1).toUpperCase() : "U",
                      style: GoogleFonts.poppins(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: InkWell(
                    onTap: _showAvatarPickerSheet,
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
          Text(
            _emailController.text,
            style: GoogleFonts.inter(fontSize: 12, color: subtextColor),
          ),
          const SizedBox(height: 10),

          // Edit/Save button
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
            icon: Icon(_isEditing ? Icons.check_circle_rounded : Icons.edit_rounded, size: 14, color: widget.isDarkMode ? Colors.white : Colors.black87),
            label: Text(
              _isEditing ? _t('save') : _t('edit'),
              style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.bold, color: widget.isDarkMode ? Colors.white : Colors.black87),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: BorderSide(color: Colors.grey.withOpacity(0.3)),
            ),
          ),
        ],
      ),
    );
  }

  // App Theme & Settings card (Controls Dark Mode for WHOLE APP)
  Widget _buildSettingsCard(Color primaryColor, Color cardBg, Color textColor, Color subtextColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, color: primaryColor, size: 18),
              const SizedBox(width: 8),
              Text(
                _isBengali ? 'অ্যাপ সেটিংস' : 'App Settings',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
              ),
            ],
          ),
          const Divider(height: 18),

          // Language Selector
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

          // Dark Mode Switch (Updates WHOLE APP)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_t('theme_mode'), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
              Switch(
                value: widget.isDarkMode,
                activeColor: primaryColor,
                onChanged: (val) {
                  widget.onThemeChanged(val);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Section wrapper card
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
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
              ),
            ],
          ),
          const Divider(height: 18),
          ...children,
        ],
      ),
    );
  }

  Widget _buildProfileField(String label, TextEditingController controller, {TextInputType keyboardType = TextInputType.text, int maxLines = 1}) {
    final textColor = _getTextColor();
    final labelColor = widget.isDarkMode ? Colors.white38 : Colors.grey[500]!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: labelColor),
          ),
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
                      borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
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

  Widget _buildTogglePreferenceTile(String label, IconData icon, Color accentColor, Color textColor, Color subtextColor) {
    bool isPrefEnabled = true;
    return StatefulBuilder(
      builder: (context, setStateTile) {
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          secondary: Icon(icon, color: accentColor, size: 18),
          title: Text(label, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor)),
          value: isPrefEnabled,
          activeColor: accentColor,
          onChanged: (val) {
            setStateTile(() {
              isPrefEnabled = val;
            });
          },
        );
      },
    );
  }

  // Avatar picker bottom sheet
  void _showAvatarPickerSheet() {
    final primaryColor = _getPrimaryThemeColor();
    final cardBg = _getCardColor();
    final textColor = _getTextColor();

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t('change_photo'),
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(_avatarGradients.length, (index) {
                  final isSelected = _avatarIndex == index;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _avatarIndex = index;
                        _saveSettings();
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _avatarGradients[index],
                        border: isSelected ? Border.all(color: primaryColor, width: 3) : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 18),
            ],
          ),
        );
      },
    );
  }
}
