import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/auth_header.dart'; // AppColors

class AboutScreen extends StatefulWidget {
  final bool isDarkMode;

  const AboutScreen({super.key, required this.isDarkMode});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  bool _privacyExpanded = false;
  bool _termsExpanded = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Color get _bg =>
      widget.isDarkMode ? const Color(0xFF121212) : const Color(0xFFF7F9FC);
  Color get _cardBg =>
      widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
  Color get _textColor =>
      widget.isDarkMode ? Colors.white : const Color(0xFF2C3E50);
  Color get _subtextColor =>
      widget.isDarkMode ? Colors.white60 : Colors.black54;
  Color get _accent => AppColors.midTeal;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: _textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'About DeenMate',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: _textColor,
          ),
        ),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // App Logo & Branding Banner with Login Vector Header
              Container(
                width: double.infinity,
                height: 240,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Positioned.fill(
                      child: RegistrationHeader(),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const AppLogo(size: 60),
                          const SizedBox(height: 8),
                          Text(
                            'DeenMate',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: AppColors.navyBlue,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Version 1.0.0',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white,
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 48),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: Colors.white,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'Your companion on the path of Deen',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Description
              _buildCard(
                icon: Icons.info_outline_rounded,
                title: 'About the App',
                child: Text(
                  'DeenMate is a comprehensive Islamic companion app designed to support Muslims in their daily spiritual practice. '
                  'From accurate prayer times and Quranic recitation to Zakat management, Dhikr tracking, and a built-in Islamic calendar, '
                  'DeenMate brings together everything you need to strengthen your connection with Allah in one beautifully crafted app.',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: _subtextColor,
                    height: 1.65,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Mission & Vision
              _buildCard(
                icon: Icons.flag_outlined,
                title: 'Our Mission',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _missionItem(
                      Icons.star_outline_rounded,
                      'Mission',
                      'To make Islamic practice accessible, consistent, and meaningful for every Muslim by providing reliable, technology-driven tools that fit seamlessly into modern daily life.',
                    ),
                    const SizedBox(height: 14),
                    _missionItem(
                      Icons.visibility_outlined,
                      'Vision',
                      'A world where every Muslim has the digital tools to deepen their faith, fulfill their religious obligations, and build a stronger, more mindful relationship with their Deen.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Key Features
              _buildCard(
                icon: Icons.widgets_outlined,
                title: 'Key Features',
                child: Column(
                  children: [
                    _featureRow(Icons.access_time_rounded,
                        'Accurate Prayer Times', 'Location-based Azan alerts'),
                    _featureRow(Icons.menu_book_rounded, 'Quran Reader',
                        'Arabic text with translations'),
                    _featureRow(Icons.calculate_rounded, 'Zakat Calculator',
                        'Haul tracking and payment logs'),
                    _featureRow(Icons.favorite_border_rounded, 'Dhikr Counter',
                        'Track your daily remembrance'),
                    _featureRow(Icons.calendar_month_rounded,
                        'Islamic Calendar', 'Hijri dates and Islamic events'),
                    _featureRow(Icons.smart_toy_outlined, 'AI Assistant',
                        'Islamic guidance powered by AI'),
                    _featureRow(Icons.qr_code_scanner_rounded,
                        'Halal Scanner', 'Scan barcodes to check Halal status'),
                    _featureRow(Icons.account_balance_rounded,
                        'Inheritance Calculator', 'Islamic Mirath distribution'),
                    _featureRow(Icons.flight_rounded,
                        'Hajj & Umrah Guide', 'Step-by-step rituals and duas'),
                    _featureRow(Icons.how_to_reg_rounded,
                        'Salat Guide', 'Prayer steps with postures and duas'),
                    _featureRow(Icons.set_meal_rounded,
                        'Qurbani & Aqiqah Planner', 'Manage sacrificial animal plans'),
                    _featureRow(Icons.sos_rounded,
                        'Emergency SOS', 'Alert trusted contacts instantly'),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Team
              _buildCard(
                icon: Icons.groups_outlined,
                title: 'The Team',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _accent.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.people_alt_rounded,
                              color: _accent, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DeenMate Team',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'A dedicated group of developers and designers passionate about building meaningful technology for the Muslim community.',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: _subtextColor,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _teamMember('Tasmia Nasir'),
                    _teamMember('Maria Sultana Joly'),
                    _teamMember('Afia Fahmidha Zaman'),
                    _teamMember('Akhi Alom'),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Privacy Policy (expandable)
              _buildExpandableCard(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                isExpanded: _privacyExpanded,
                onToggle: () =>
                    setState(() => _privacyExpanded = !_privacyExpanded),
                content: _privacyPolicyText,
              ),
              const SizedBox(height: 14),

              // Terms of Use (expandable)
              _buildExpandableCard(
                icon: Icons.gavel_rounded,
                title: 'Terms of Use',
                isExpanded: _termsExpanded,
                onToggle: () =>
                    setState(() => _termsExpanded = !_termsExpanded),
                content: _termsOfUseText,
              ),
              const SizedBox(height: 20),

              // Footer
              Center(
                child: Column(
                  children: [
                    Text(
                      'Made with sincerity for the Ummah',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _subtextColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '© 2026 DeenMate Team. All rights reserved.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: _subtextColor.withValues(alpha: 0.6),
                      ),
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

  Widget _buildCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _accent, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildExpandableCard({
    required IconData icon,
    required String title,
    required bool isExpanded,
    required VoidCallback onToggle,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(icon, color: _accent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: _textColor,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: _accent, size: 22),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(height: 0),
            secondChild: Padding(
              padding:
                  const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: _accent.withValues(alpha: 0.2)),
                  const SizedBox(height: 8),
                  Text(
                    content,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: _subtextColor,
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _missionItem(IconData icon, String label, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _accent, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: _subtextColor,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _featureRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _accent, size: 15),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _textColor,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: _subtextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _teamMember(String name) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name[0].toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _accent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            name,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _textColor,
            ),
          ),
        ],
      ),
    );
  }

  static const String _privacyPolicyText = '''Last updated: August 2026

1. INFORMATION WE COLLECT
DeenMate collects only the information necessary to provide its features. This includes location data (for prayer time calculation), profile information you voluntarily enter (name, email), and app preference settings. We do not collect or share personally identifiable information with third parties.

2. HOW WE USE YOUR INFORMATION
Your data is used solely to personalize your experience within the app — including calculating accurate prayer times, saving your Quran reading progress, Zakat records, and notification preferences. All data is stored locally on your device using encrypted storage.

3. DATA STORAGE
DeenMate stores all user data locally on your device. We do not operate servers that store your personal data. Your information remains on your device unless you explicitly choose to share or export it.

4. LOCATION DATA
Location access is used exclusively to determine your city for prayer time calculations. We do not track, log, or share your precise location with any third party.

5. NOTIFICATIONS
You have full control over which notifications you receive through the Notification Center within the app. Disabling notifications will stop all prayer alarms and reminders.

6. CHILDREN'S PRIVACY
DeenMate is suitable for all ages. We do not knowingly collect personal information from children under the age of 13.

7. CHANGES TO THIS POLICY
We may update this Privacy Policy from time to time. Changes will be reflected in the app with an updated revision date.

8. CONTACT
If you have questions about this Privacy Policy, please reach out through the Contact Support section of the app.''';

  static const String _termsOfUseText = '''Last updated: August 2026

1. ACCEPTANCE OF TERMS
By downloading and using DeenMate, you agree to be bound by these Terms of Use. If you do not agree to these terms, please uninstall the application.

2. USE OF THE APP
DeenMate is provided for personal, non-commercial use. You agree not to misuse the app, attempt to reverse-engineer it, or use it for any unlawful purpose.

3. ISLAMIC CONTENT ACCURACY
DeenMate provides Islamic content, prayer times, and Zakat calculations based on widely accepted scholarly references. However, we recommend consulting a qualified Islamic scholar for matters of personal religious practice and ruling. DeenMate does not serve as a religious authority.

4. PRAYER TIMES
Prayer times are calculated using recognized astronomical algorithms. Slight variations may occur depending on your exact location and chosen calculation method. Users should verify times with local mosques when needed.

5. ZAKAT INFORMATION
The Zakat calculations provided are estimates based on current Nisab values and standard scholarly methods. DeenMate is not liable for any religious obligations arising from incorrect input of wealth or assets by the user.

6. DISCLAIMER OF WARRANTIES
DeenMate is provided "as is" without warranty of any kind. We do not guarantee that the app will be error-free or uninterrupted at all times.

7. LIMITATION OF LIABILITY
To the fullest extent permitted by law, the DeenMate Team shall not be liable for any indirect, incidental, or consequential damages arising from your use of the application.

8. MODIFICATIONS
We reserve the right to modify these Terms at any time. Continued use of the app after any changes constitutes your acceptance of the revised Terms.

9. GOVERNING LAW
These Terms are governed by applicable law. Any disputes shall be resolved through good-faith discussion between the parties.

10. CONTACT
For any questions regarding these Terms, please use the Contact Support section within the app.''';
}
