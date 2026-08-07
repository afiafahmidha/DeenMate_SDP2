import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/auth_header.dart'; // AppColors

// ─────────────────────────────────────────────────────────────────────────────
//  HajjRitualDetailScreen – mobile-app detail screen with safe area handling
// ─────────────────────────────────────────────────────────────────────────────
class HajjRitualDetailScreen extends StatefulWidget {
  final Map<String, dynamic> detail;
  final String? imagePath;
  final bool isDarkMode;

  const HajjRitualDetailScreen({
    super.key,
    required this.detail,
    this.imagePath,
    required this.isDarkMode,
  });

  @override
  State<HajjRitualDetailScreen> createState() => _HajjRitualDetailScreenState();
}

class _HajjRitualDetailScreenState extends State<HajjRitualDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  int _activeTab = 0;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Theme ───────────────────────────────────────────────────────────────────
  bool  get _dark        => widget.isDarkMode;
  Color get _bg          => _dark ? const Color(0xFF0F1923) : const Color(0xFFF5F7FA);
  Color get _cardBg      => _dark ? const Color(0xFF1C2733) : Colors.white;
  Color get _textColor   => _dark ? const Color(0xFFE8EDF2) : AppColors.navyBlue;
  Color get _subtext     => _dark ? const Color(0xFF8FA3B3) : const Color(0xFF607080);
  Color get _accent      => AppColors.midTeal;
  Color get _gold        => const Color(0xFFD4AF37);
  Color get _amber       => const Color(0xFFE07D1A);

  // ── Tab list ────────────────────────────────────────────────────────────────
  List<_TabItem> _buildTabs(Map<String, dynamic> d) => [
    _TabItem(icon: Icons.article_rounded,         label: 'Overview'),
    _TabItem(icon: Icons.checklist_rounded,        label: 'Actions'),
    if (d['quran']  != null) _TabItem(icon: Icons.menu_book_rounded,    label: "Qur'an"),
    if (d['hadith'] != null) _TabItem(icon: Icons.format_quote_rounded, label: 'Hadith'),
    if (d['dua'] != null || d['duas'] != null) _TabItem(icon: Icons.front_hand_rounded, label: "Du'a"),
  ];

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final d    = widget.detail;
    final tabs = _buildTabs(d);

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Scaffold(
          backgroundColor: _bg,
          body: Column(
            children: [
              // ── Hero Header ─────────────────────────────────────────────
              _buildHero(d),

              // ── Tab Strip ───────────────────────────────────────────────
              _buildTabStrip(tabs),

              // ── Scrollable content starting at top ─────────────────────
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      alignment: Alignment.topCenter,
                      children: <Widget>[
                        ...previousChildren,
                        ...?currentChild != null ? [currentChild] : null,
                      ],
                    );
                  },
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.03, 0), end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_activeTab),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
                      child: _buildActiveSection(d, tabs),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Hero Header (Safe for mobile status bar) ───────────────────────────────
  Widget _buildHero(Map<String, dynamic> d) {
    final topInset = MediaQuery.of(context).padding.top;
    final topPos = topInset > 0 ? topInset + 6.0 : 14.0;
    final heroHeight = 200.0 + (topInset > 0 ? topInset : 0.0);

    return SizedBox(
      height: heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image or gradient
          if (widget.imagePath != null)
            Image.asset(
              widget.imagePath!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _gradientBg(),
            )
          else
            _gradientBg(),

          // Gradient overlay
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.25),
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.85),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),

          // ── Close button (top-right) ────────────────────────────────────
          Positioned(
            top: topPos,
            right: 14,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ),
          ),

          // ── DeenMate logo chip (top-left) ───────────────────────────────
          Positioned(
            top: topPos,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_stories_rounded, color: _accent, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    'Ritual Guide',
                    style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),

          // ── Title block (bottom) ────────────────────────────────────────
          Positioned(
            bottom: 14, left: 14, right: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Arabic title pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    d['titleAr'] ?? '',
                    style: GoogleFonts.amiri(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  d['titleEn'] ?? '',
                  style: GoogleFonts.poppins(
                    fontSize: 16.5, fontWeight: FontWeight.bold, color: Colors.white,
                    shadows: [Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 6)],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.access_time_rounded, size: 12, color: Colors.white60),
                  const SizedBox(width: 4),
                  Expanded(child: Text(
                    d['day'] ?? '',
                    style: GoogleFonts.inter(fontSize: 10.5, color: Colors.white60),
                    overflow: TextOverflow.ellipsis,
                  )),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradientBg() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [AppColors.navyBlue, Color(0xFF1B4B48), AppColors.midTeal],
      ),
    ),
  );

  // ── Tab Strip ──────────────────────────────────────────────────────────────
  Widget _buildTabStrip(List<_TabItem> tabs) {
    return Container(
      color: _dark ? const Color(0xFF14202C) : const Color(0xFFEDF0F4),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(tabs.length, (i) {
            final sel = _activeTab == i;
            return GestureDetector(
              onTap: () => setState(() => _activeTab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 7),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: sel ? _accent : _cardBg,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: sel
                      ? [BoxShadow(color: _accent.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3))]
                      : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 3)],
                  border: Border.all(
                    color: sel ? _accent : (_dark ? Colors.white12 : Colors.black.withValues(alpha: 0.07)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tabs[i].icon, size: 13, color: sel ? Colors.white : _subtext),
                    const SizedBox(width: 5),
                    Text(tabs[i].label,
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? Colors.white : _subtext,
                      )),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ── Active section dispatcher ───────────────────────────────────────────────
  Widget _buildActiveSection(Map<String, dynamic> d, List<_TabItem> tabs) {
    final hasQ = d['quran']  != null;
    final hasH = d['hadith'] != null;
    final hasD = d['dua']    != null || d['duas'] != null;
    final qIdx = 2;
    final hIdx = hasQ ? 3 : 2;
    final dIdx = 2 + (hasQ ? 1 : 0) + (hasH ? 1 : 0);

    if (_activeTab == 0)                        return _overviewSection(d);
    if (_activeTab == 1)                        return _actionsSection(d);
    if (hasQ && _activeTab == qIdx)             return _quranSection(d['quran']  as Map<String, dynamic>);
    if (hasH && _activeTab == hIdx)             return _hadithSection(d['hadith'] as Map<String, dynamic>);
    if (hasD && _activeTab == dIdx)             return _duaSection(d);
    return const SizedBox.shrink();
  }

  // ── Overview ───────────────────────────────────────────────────────────────
  Widget _overviewSection(Map<String, dynamic> d) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionLabel(Icons.article_rounded, 'Elaborate Explanation'),
      const SizedBox(height: 10),
      _glassCard(child: Text(d['overviewEn'] ?? '',
          style: GoogleFonts.inter(fontSize: 12.5, height: 1.65, color: _textColor))),
      const SizedBox(height: 14),
      _arabicBanner(d['overviewAr'] ?? '', d['dayAr'] ?? ''),
    ],
  );

  Widget _arabicBanner(String arabic, String dayAr) {
    if (arabic.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _dark ? [const Color(0xFF1A2820), const Color(0xFF12201A)] : [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accent.withValues(alpha: 0.18)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.translate_rounded, size: 13, color: _accent),
          const SizedBox(width: 5),
          Text('Arabic Reference', style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w600, color: _accent)),
        ]),
        if (dayAr.isNotEmpty) ...[
          const SizedBox(height: 7),
          Directionality(textDirection: TextDirection.rtl,
            child: Text(dayAr, style: GoogleFonts.amiri(fontSize: 12.5, color: _gold, fontWeight: FontWeight.bold))),
        ],
        const SizedBox(height: 5),
        Directionality(textDirection: TextDirection.rtl,
          child: Text(arabic, style: GoogleFonts.amiri(fontSize: 13.5, color: _textColor.withValues(alpha: 0.85), height: 1.7))),
      ]),
    );
  }

  Widget _historySourceCard(String sourceType, String sourceName, String history) {
    final accentColor = sourceType == 'Quran' ? _gold : sourceType == 'Hadith' ? _amber : _accent;
    final icon = sourceType == 'Quran' ? Icons.menu_book_rounded : sourceType == 'Hadith' ? Icons.format_quote_rounded : Icons.history_edu_rounded;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: accentColor.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 18),
              const SizedBox(width: 8),
              Text(sourceName, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: accentColor)),
            ],
          ),
          const SizedBox(height: 10),
          Text(history, style: GoogleFonts.inter(fontSize: 12, color: _textColor.withValues(alpha: 0.88), height: 1.55)),
        ],
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  Widget _actionsSection(Map<String, dynamic> d) {
    final actions = (d['keyActionsEn'] as List?)?.cast<String>() ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(Icons.checklist_rounded, 'Key Ritual Actions'),
        const SizedBox(height: 10),
        ...List.generate(actions.length, (i) => _actionTile(i + 1, actions[i])),
      ],
    );
  }

  Widget _actionTile(int num, String text) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    decoration: BoxDecoration(
      color: _cardBg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _accent.withValues(alpha: 0.15)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: _dark ? 0.18 : 0.04), blurRadius: 7)],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_accent, AppColors.navyBlue],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text('$num', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: GoogleFonts.inter(fontSize: 12.5, height: 1.5, color: _textColor))),
      ],
    ),
  );

  // ── Qur'an ─────────────────────────────────────────────────────────────────
  Widget _quranSection(Map<String, dynamic> q) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionLabel(Icons.menu_book_rounded, "Qur'anic Evidence & Reference"),
      const SizedBox(height: 10),
      _referenceHeader(
        refEn: q['referenceEn'] ?? '',
        color: _gold,
        icon: Icons.bookmark_rounded,
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _dark
                ? [const Color(0xFF1A2820), const Color(0xFF12201A)]
                : [const Color(0xFFEAFBF4), const Color(0xFFD6F5E8)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _accent.withValues(alpha: 0.3)),
          boxShadow: [BoxShadow(color: _accent.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(children: [
          _ornamentRow(false),
          const SizedBox(height: 12),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text('﴿ ${q['textAr']} ﴾', textAlign: TextAlign.center,
              style: GoogleFonts.scheherazadeNew(fontSize: 18, fontWeight: FontWeight.bold, height: 1.9,
                color: _dark ? const Color(0xFFCEF0E4) : const Color(0xFF1A3D30))),
          ),
          const SizedBox(height: 10),
          Divider(color: _accent.withValues(alpha: 0.25)),
          const SizedBox(height: 6),
          Text('"${q['textEn']}"', textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 11.5, fontStyle: FontStyle.italic,
              color: _textColor.withValues(alpha: 0.88), height: 1.5)),
        ]),
      ),
      if (q['explanationEn'] != null) ...[
        const SizedBox(height: 12),
        _glassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Context & Guidance:',
            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: _accent)),
          const SizedBox(height: 5),
          Text(q['explanationEn'] ?? '',
            style: GoogleFonts.inter(fontSize: 12, color: _textColor.withValues(alpha: 0.88), height: 1.5)),
        ])),
      ],
    ],
  );

  // ── Hadith ─────────────────────────────────────────────────────────────────
  Widget _hadithSection(Map<String, dynamic> h) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionLabel(Icons.format_quote_rounded, 'Authentic Hadith Reference'),
      const SizedBox(height: 10),
      _referenceHeader(
        refEn: h['referenceEn'] ?? '',
        color: _amber,
        icon: Icons.history_edu_rounded,
      ),
      const SizedBox(height: 12),
      _historySourceCard('Hadith', 'Sahih al-Bukhari & Sahih Muslim', 'This hadith is recorded in Sahih al-Bukhari, compiled by Imam Muhammad ibn Ismail al-Bukhari (810-870 CE), and Sahih Muslim, compiled by Imam Muslim ibn al-Hajjaj (815-875 CE). These are the two most authentic collections of hadith in Sunni Islam. Al-Bukhari traveled extensively across the Islamic world, collecting and verifying the chains of narration (isnad) for each hadith, ensuring their authenticity through rigorous scholarly standards.'),
      const SizedBox(height: 10),
      Divider(color: _amber.withValues(alpha: 0.3)),
      const SizedBox(height: 6),
      Text(h['textEn'] ?? '',
        style: GoogleFonts.inter(fontSize: 11.5, color: _textColor.withValues(alpha: 0.88), height: 1.5)),
      if (h['explanationEn'] != null) ...[
        const SizedBox(height: 12),
        _glassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Prophetic Wisdom:', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: _amber)),
          const SizedBox(height: 5),
          Text(h['explanationEn'] ?? '', style: GoogleFonts.inter(fontSize: 12, color: _textColor.withValues(alpha: 0.88), height: 1.5)),
        ])),
      ],
    ],
  );

  // ── Du'a (Supports 1, 2, or 3 Du'as!) ──────────────────────────────────────
  Widget _duaSection(Map<String, dynamic> d) {
    List<Map<String, dynamic>> list = [];
    if (d['duas'] is List) {
      list = (d['duas'] as List).cast<Map<String, dynamic>>();
    } else if (d['dua'] is Map) {
      list = [(d['dua'] as Map<String, dynamic>)];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel(Icons.front_hand_rounded, "Recommended Du'a & Dhikr"),
        const SizedBox(height: 10),
        for (int i = 0; i < list.length; i++) ...[
          _buildSingleDuaCard(list[i], i + 1),
          if (i < list.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _buildSingleDuaCard(Map<String, dynamic> dua, int number) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _accent.withValues(alpha: 0.22)),
        boxShadow: [BoxShadow(color: _accent.withValues(alpha: 0.07), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_accent, const Color(0xFF2D7B78)],
                  begin: Alignment.centerLeft, end: Alignment.centerRight),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('#$number', style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dua['title'] ?? 'Recommended Supplication',
                    style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(dua['arabic'] ?? '', textAlign: TextAlign.center,
                    style: GoogleFonts.scheherazadeNew(fontSize: 20, fontWeight: FontWeight.bold, height: 1.9, color: _gold)),
                ),
                if (dua['translit'] != null) ...[
                  const SizedBox(height: 8),
                  Text(dua['translit'] ?? '', textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 11.5, fontStyle: FontStyle.italic, color: _subtext, height: 1.5)),
                ],
                Divider(color: _accent.withValues(alpha: 0.18), height: 22),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.translate_rounded, size: 14, color: _accent),
                  const SizedBox(width: 7),
                  Expanded(child: Text(dua['meaningEn'] ?? '',
                    style: GoogleFonts.inter(fontSize: 12, color: _textColor, height: 1.55))),
                ]),
                if (dua['meaningAr'] != null) ...[
                  const SizedBox(height: 8),
                  Directionality(textDirection: TextDirection.rtl,
                    child: Text(dua['meaningAr'] ?? '',
                      style: GoogleFonts.amiri(fontSize: 13, color: _subtext, height: 1.6))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  Widget _glassCard({required Widget child}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _cardBg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _dark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: _dark ? 0.18 : 0.04), blurRadius: 6)],
    ),
    child: child,
  );

  Widget _sectionLabel(IconData icon, String title) => Row(children: [
    Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(color: _accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(9)),
      child: Icon(icon, size: 14, color: _accent),
    ),
    const SizedBox(width: 9),
    Expanded(child: Text(title, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: _textColor))),
  ]);

  Widget _referenceHeader({
    required String refEn,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 13, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              refEn,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ornamentRow(bool isAmber) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _orn(isAmber),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9),
        child: Icon(
          isAmber ? Icons.format_quote_rounded : Icons.auto_stories_rounded,
          color: isAmber ? _amber : _accent,
          size: 18,
        ),
      ),
      _orn(isAmber),
    ],
  );

  Widget _orn(bool isAmber) => Expanded(
    child: Container(
      height: 1.2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, (isAmber ? _amber : _accent).withValues(alpha: 0.5)],
        ),
      ),
    ),
  );
}

// ── Data class ────────────────────────────────────────────────────────────────
class _TabItem {
  final IconData icon;
  final String label;
  const _TabItem({required this.icon, required this.label});
}
