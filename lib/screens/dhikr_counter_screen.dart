import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui' as ui;
import '../widgets/auth_header.dart';

/// ===== DHIKR COUNTER SCREEN =====
/// Push like the other planner pages:
///   Navigator.of(context).push(
///     MaterialPageRoute(builder: (_) => const DhikrCounterScreen()),
///   );
class DhikrCounterScreen extends StatefulWidget {
  const DhikrCounterScreen({super.key});

  @override
  State<DhikrCounterScreen> createState() => _DhikrCounterScreenState();
}

// ===== DHIKR PRESET DATA =====
class _DhikrPreset {
  final String name;
  final String arabic;
  final String translit;
  final String meaning;
  final int target;
  final IconData icon;
  const _DhikrPreset({
    required this.name,
    required this.arabic,
    required this.translit,
    required this.meaning,
    required this.target,
    required this.icon,
  });
}

const List<_DhikrPreset> _presets = [
  _DhikrPreset(
    name: 'SubhanAllah',
    arabic: 'سُبْحَانَ اللّٰهِ',
    translit: 'SubhanAllah',
    meaning: 'Glory be to Allah',
    target: 33,
    icon: Icons.star_rounded,
  ),
  _DhikrPreset(
    name: 'Alhamdulillah',
    arabic: 'الْحَمْدُ لِلّٰهِ',
    translit: 'Alhamdulillah',
    meaning: 'All praise is due to Allah',
    target: 33,
    icon: Icons.favorite_rounded,
  ),
  _DhikrPreset(
    name: 'Allahu Akbar',
    arabic: 'اللّٰهُ أَكْبَرُ',
    translit: 'Allahu Akbar',
    meaning: 'Allah is the Greatest',
    target: 34,
    icon: Icons.mosque_rounded,
  ),
  _DhikrPreset(
    name: 'Astaghfirullah',
    arabic: 'أَسْتَغْفِرُ اللّٰهَ',
    translit: 'Astaghfirullah',
    meaning: 'I seek forgiveness from Allah',
    target: 100,
    icon: Icons.wb_twilight_rounded,
  ),
  _DhikrPreset(
    name: 'La ilaha illallah',
    arabic: 'لَا إِلٰهَ إِلَّا اللّٰهُ',
    translit: 'La ilaha illallah',
    meaning: 'There is no god but Allah',
    target: 100,
    icon: Icons.nights_stay_rounded,
  ),
];

// The classic "Tasbih of Fatimah (RA)" routine — 33 + 33 + 34 in sequence
const List<_DhikrPreset> _tasbihFatimahSequence = [
  _DhikrPreset(
    name: 'SubhanAllah',
    arabic: 'سُبْحَانَ اللّٰهِ',
    translit: 'SubhanAllah',
    meaning: 'Glory be to Allah',
    target: 33,
    icon: Icons.star_rounded,
  ),
  _DhikrPreset(
    name: 'Alhamdulillah',
    arabic: 'الْحَمْدُ لِلّٰهِ',
    translit: 'Alhamdulillah',
    meaning: 'All praise is due to Allah',
    target: 33,
    icon: Icons.favorite_rounded,
  ),
  _DhikrPreset(
    name: 'Allahu Akbar',
    arabic: 'اللّٰهُ أَكْبَرُ',
    translit: 'Allahu Akbar',
    meaning: 'Allah is the Greatest',
    target: 34,
    icon: Icons.mosque_rounded,
  ),
];

class _DhikrCounterScreenState extends State<DhikrCounterScreen> with TickerProviderStateMixin {
  int _selectedPresetIndex = 0;
  int _count = 0;
  int _customTarget = 100;

  bool _isSequenceMode = false;
  int _sequencePhase = 0; // 0,1,2 within _tasbihFatimahSequence

  int _todayTotal = 0;
  int _lifetimeTotal = 0;
  int _currentStreak = 0;
  bool _showHint = true;

  late AnimationController _tapPulseController;
  late AnimationController _breathController; // slow idle glow

  _DhikrPreset get _activePreset {
    if (_isSequenceMode) return _tasbihFatimahSequence[_sequencePhase];
    if (_selectedPresetIndex < _presets.length) return _presets[_selectedPresetIndex];
    return _DhikrPreset(
      name: 'Custom',
      arabic: '',
      translit: 'Custom Dhikr',
      meaning: 'Your own count target',
      target: _customTarget,
      icon: Icons.tune_rounded,
    );
  }

  @override
  void initState() {
    super.initState();
    _tapPulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _breathController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat(reverse: true);
    _loadStats();
  }

  @override
  void dispose() {
    _tapPulseController.dispose();
    _breathController.dispose();
    super.dispose();
  }

  String get _todayKey => 'dhikr_daily_${DateFormat('yyyyMMdd').format(DateTime.now())}';

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final today = prefs.getInt(_todayKey) ?? 0;
    final lifetime = prefs.getInt('dhikr_lifetime_total') ?? 0;
    final hintDismissed = prefs.getBool('dhikr_hint_dismissed') ?? false;

    int streak = 0;
    DateTime day = DateTime.now();
    while (true) {
      final key = 'dhikr_daily_${DateFormat('yyyyMMdd').format(day)}';
      final val = prefs.getInt(key) ?? 0;
      if (val > 0) {
        streak++;
        day = day.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    if (!mounted) return;
    setState(() {
      _todayTotal = today;
      _lifetimeTotal = lifetime;
      _currentStreak = streak;
      _showHint = !hintDismissed;
    });
  }

  Future<void> _dismissHint() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dhikr_hint_dismissed', true);
    setState(() => _showHint = false);
  }

  Future<void> _persistTap() async {
    final prefs = await SharedPreferences.getInstance();
    final today = (prefs.getInt(_todayKey) ?? 0) + 1;
    final lifetime = (prefs.getInt('dhikr_lifetime_total') ?? 0) + 1;
    await prefs.setInt(_todayKey, today);
    await prefs.setInt('dhikr_lifetime_total', lifetime);

    // Track per-dhikr breakdown so "Today" and "Lifetime" details can show
    // exactly what was recited, not just a combined total.
    final String presetKey = _activePreset.name.replaceAll(' ', '_');
    final String todayPresetKey = '${_todayKey}_$presetKey';
    final int todayPresetCount = (prefs.getInt(todayPresetKey) ?? 0) + 1;
    await prefs.setInt(todayPresetKey, todayPresetCount);

    final String lifetimePresetKey = 'dhikr_lifetime_$presetKey';
    final int lifetimePresetCount = (prefs.getInt(lifetimePresetKey) ?? 0) + 1;
    await prefs.setInt(lifetimePresetKey, lifetimePresetCount);

    if (!mounted) return;
    setState(() {
      _todayTotal = today;
      _lifetimeTotal = lifetime;
      if (_currentStreak == 0) _currentStreak = 1;
    });
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    _tapPulseController.forward(from: 0);
    if (_showHint) _dismissHint();

    setState(() => _count++);
    _persistTap();

    if (_count >= _activePreset.target) {
      HapticFeedback.mediumImpact();
      if (_isSequenceMode && _sequencePhase < _tasbihFatimahSequence.length - 1) {
        setState(() {
          _sequencePhase++;
          _count = 0;
        });
        _showSnack('${_tasbihFatimahSequence[_sequencePhase - 1].name} complete! Next: ${_tasbihFatimahSequence[_sequencePhase].name}');
      } else if (_isSequenceMode) {
        _showSnack('Tasbih Fatimah complete! 🌙 May Allah accept your dhikr.');
        setState(() {
          _isSequenceMode = false;
          _sequencePhase = 0;
          _count = 0;
        });
      } else {
        _showSnack('${_activePreset.name} target reached! 🎉');
        setState(() => _count = 0);
      }
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: GoogleFonts.inter(fontSize: 13)),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: AppColors.navyBlue,
      ),
    );
  }

  void _resetCounter() {
    setState(() {
      _count = 0;
      if (_isSequenceMode) _sequencePhase = 0;
    });
  }

  void _selectPreset(int index) {
    setState(() {
      _isSequenceMode = false;
      _selectedPresetIndex = index;
      _count = 0;
    });
  }

  void _startTasbihFatimah() {
    setState(() {
      _isSequenceMode = true;
      _sequencePhase = 0;
      _count = 0;
    });
  }

  void _editCustomTarget() {
    final ctrl = TextEditingController(text: _customTarget.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Set Custom Target', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'e.g. 500',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.placeholder))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.navyBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              final val = int.tryParse(ctrl.text);
              if (val != null && val > 0) {
                setState(() {
                  _customTarget = val;
                  _selectedPresetIndex = _presets.length; // marks "custom"
                  _isSequenceMode = false;
                  _count = 0;
                });
              }
              Navigator.pop(context);
            },
            child: Text('Save', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8E8E8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Scaffold(
            backgroundColor: const Color(0xFFF4F6F7),
            body: SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                      children: [
                        if (_showHint) _buildHintCard(),
                        if (_showHint) const SizedBox(height: 16),
                        _buildMeaningCard(),
                        const SizedBox(height: 24),
                        _buildCounterCircle(),
                        const SizedBox(height: 8),
                        _buildTapLabel(),
                        const SizedBox(height: 18),
                        _buildCounterActions(),
                        const SizedBox(height: 26),
                        _buildSectionLabel('Choose a Dhikr to Count', Icons.touch_app_rounded),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 12, bottom: 12),
                          child: Text('Tap a card below to switch what you\'re counting.',
                              style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.navyBlue.withValues(alpha: 0.45))),
                        ),
                        _buildPresetList(),
                        const SizedBox(height: 26),
                        _buildSectionLabel('Your Progress', Icons.insights_rounded),
                        const SizedBox(height: 12),
                        _buildStatsRow(),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.navyBlue, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.navyBlue, Color(0xFF1D3550)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.fingerprint_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dhikr Counter', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
                Text('Remember Allah, in every moment', style: GoogleFonts.inter(fontSize: 11, color: AppColors.navyBlue.withValues(alpha: 0.55))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== HINT / HOW-TO CARD (shown once, dismissible) =====
  Widget _buildHintCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.midTeal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.midTeal.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_rounded, color: AppColors.midTeal, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'How it works: pick a Dhikr below, then tap the big circle once for each repetition. It fills up as you go and celebrates when you hit the target!',
              style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.navyBlue.withValues(alpha: 0.75), height: 1.5),
            ),
          ),
          GestureDetector(
            onTap: _dismissHint,
            child: Icon(Icons.close_rounded, size: 16, color: AppColors.navyBlue.withValues(alpha: 0.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String title, IconData icon) {
    return Row(
      children: [
        Container(width: 4, height: 16, decoration: BoxDecoration(color: AppColors.navyBlue, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Icon(icon, size: 15, color: AppColors.navyBlue.withValues(alpha: 0.6)),
        const SizedBox(width: 5),
        Text(title, style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
      ],
    );
  }

  // ===== MEANING CARD (currently active dhikr) =====
  Widget _buildMeaningCard() {
    final preset = _activePreset;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.navyBlue, Color(0xFF1D3550)]),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: AppColors.navyBlue.withValues(alpha: 0.22), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  _isSequenceMode ? 'Tasbih Fatimah — Phase ${_sequencePhase + 1}/3' : 'Now Counting',
                  style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
              Icon(preset.icon, color: Colors.white.withValues(alpha: 0.7), size: 20),
            ],
          ),
          const SizedBox(height: 14),
          if (preset.arabic.isNotEmpty)
            Text(preset.arabic,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: Colors.white, height: 1.6)),
          if (preset.arabic.isNotEmpty) const SizedBox(height: 8),
          Text(preset.translit, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(preset.meaning, style: GoogleFonts.inter(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.75))),
        ],
      ),
    );
  }

  // ===== TAP COUNTER CIRCLE =====
  Widget _buildCounterCircle() {
    final target = _activePreset.target;
    final progress = target > 0 ? (_count / target).clamp(0.0, 1.0) : 0.0;

    return Center(
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedBuilder(
          animation: Listenable.merge([_tapPulseController, _breathController]),
          builder: (context, child) {
            final tapScale = 1.0 - (_tapPulseController.value * 0.05);
            final breathGlow = 0.15 + (_breathController.value * 0.15);
            return Transform.scale(
              scale: tapScale,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: AppColors.midTeal.withValues(alpha: breathGlow), blurRadius: 40, spreadRadius: 6),
                  ],
                ),
                child: child,
              ),
            );
          },
          child: SizedBox(
            width: 230,
            height: 230,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 230,
                  height: 230,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 11,
                    backgroundColor: AppColors.navyBlue.withValues(alpha: 0.07),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.midTeal),
                  ),
                ),
                Container(
                  width: 186,
                  height: 186,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: AppColors.navyBlue.withValues(alpha: 0.1), blurRadius: 22, offset: const Offset(0, 10))],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.touch_app_rounded, size: 18, color: AppColors.midTeal.withValues(alpha: 0.5)),
                      const SizedBox(height: 4),
                      Text('$_count', style: GoogleFonts.poppins(fontSize: 50, fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
                      Text('of $target',
                          style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.navyBlue.withValues(alpha: 0.45))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTapLabel() {
    return Center(
      child: Text('👆 Tap the circle above to count',
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.navyBlue.withValues(alpha: 0.4))),
    );
  }

  Widget _buildCounterActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _actionChip(icon: Icons.refresh_rounded, label: 'Reset', onTap: _resetCounter),
        const SizedBox(width: 10),
        _actionChip(
          icon: Icons.auto_awesome_rounded,
          label: 'Tasbih Fatimah',
          onTap: _startTasbihFatimah,
          highlighted: _isSequenceMode,
        ),
        const SizedBox(width: 10),
        _actionChip(icon: Icons.tune_rounded, label: 'Custom', onTap: _editCustomTarget),
      ],
    );
  }

  Widget _actionChip({required IconData icon, required String label, required VoidCallback onTap, bool highlighted = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: highlighted ? AppColors.midTeal.withValues(alpha: 0.15) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: highlighted ? AppColors.midTeal : AppColors.navyBlue.withValues(alpha: 0.15)),
          boxShadow: highlighted ? [] : [BoxShadow(color: AppColors.navyBlue.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: highlighted ? AppColors.midTeal : AppColors.navyBlue.withValues(alpha: 0.6)),
            const SizedBox(width: 5),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w600, color: highlighted ? AppColors.midTeal : AppColors.navyBlue.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }

 // ===== PRESET LIST (vertical cards, more descriptive than chips) =====
  Widget _buildPresetList() {
    final bool customSelected = !_isSequenceMode && _selectedPresetIndex == _presets.length;

    return Column(
      children: [
        ...List.generate(_presets.length, (i) {
          final preset = _presets[i];
          final selected = !_isSequenceMode && _selectedPresetIndex == i;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => _selectPreset(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: selected ? AppColors.navyBlue : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: selected ? AppColors.navyBlue : AppColors.navyBlue.withValues(alpha: 0.1), width: selected ? 2 : 1),
                  boxShadow: [BoxShadow(color: AppColors.navyBlue.withValues(alpha: selected ? 0.15 : 0.04), blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: selected ? Colors.white.withValues(alpha: 0.15) : AppColors.midTeal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(preset.icon, color: selected ? Colors.white : AppColors.midTeal, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(preset.name,
                              style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: selected ? Colors.white : AppColors.navyBlue)),
                          const SizedBox(height: 2),
                          Text(preset.meaning,
                              style: GoogleFonts.inter(fontSize: 10.5, color: selected ? Colors.white.withValues(alpha: 0.65) : AppColors.navyBlue.withValues(alpha: 0.45))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: selected ? Colors.white.withValues(alpha: 0.15) : AppColors.navyBlue.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${preset.target}x',
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: selected ? Colors.white : AppColors.navyBlue)),
                    ),
                    if (selected) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),

        // ── CUSTOM TARGET CARD ──
        GestureDetector(
          onTap: _editCustomTarget,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: customSelected ? AppColors.navyBlue : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: customSelected ? AppColors.navyBlue : AppColors.navyBlue.withValues(alpha: 0.1),
                width: customSelected ? 2 : 1,
              ),
              boxShadow: [BoxShadow(color: AppColors.navyBlue.withValues(alpha: customSelected ? 0.15 : 0.04), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: customSelected ? Colors.white.withValues(alpha: 0.15) : AppColors.coralOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.tune_rounded, color: customSelected ? Colors.white : AppColors.coralOrange, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Custom Target',
                          style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: customSelected ? Colors.white : AppColors.navyBlue)),
                      const SizedBox(height: 2),
                      Text(customSelected ? 'Currently active — tap to change' : 'Set your own count target',
                          style: GoogleFonts.inter(fontSize: 10.5, color: customSelected ? Colors.white.withValues(alpha: 0.65) : AppColors.navyBlue.withValues(alpha: 0.45))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: customSelected ? Colors.white.withValues(alpha: 0.15) : AppColors.navyBlue.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${_customTarget}x',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: customSelected ? Colors.white : AppColors.navyBlue)),
                ),
                if (customSelected) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===== STATS ROW =====
  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _statCard(icon: Icons.today_rounded, label: 'Today', value: '$_todayTotal', color: AppColors.navyBlue, onTap: _showTodayDetails)),
        const SizedBox(width: 10),
        Expanded(child: _statCard(icon: Icons.local_fire_department_rounded, label: 'Streak', value: '$_currentStreak d', color: AppColors.coralOrange, onTap: _showStreakDetails)),
        const SizedBox(width: 10),
        Expanded(child: _statCard(icon: Icons.all_inclusive_rounded, label: 'Lifetime', value: '$_lifetimeTotal', color: AppColors.midTeal, onTap: _showLifetimeDetails)),
      ],
    );
  }

  Widget _statCard({required IconData icon, required String label, required String value, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 18),
                Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.4), size: 16),
              ],
            ),
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.navyBlue.withValues(alpha: 0.5))),
            const SizedBox(height: 2),
            Text(value, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
          ],
        ),
      ),
    );
  }
  // ===== DETAIL SHEETS =====
  void _showTodayDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final List<MapEntry<String, int>> breakdown = [];
    for (final preset in [..._presets, const _DhikrPreset(name: 'Custom', arabic: '', translit: '', meaning: '', target: 0, icon: Icons.tune_rounded)]) {
      final key = '${_todayKey}_${preset.name.replaceAll(' ', '_')}';
      final count = prefs.getInt(key) ?? 0;
      if (count > 0) breakdown.add(MapEntry(preset.name, count));
    }
    if (!mounted) return;
    _showDetailSheet(
      title: "Today's Dhikr",
      subtitle: DateFormat('EEEE, MMMM d').format(DateTime.now()),
      icon: Icons.today_rounded,
      color: AppColors.navyBlue,
      rows: breakdown.isEmpty
          ? [const MapEntry('No dhikr counted yet today', 0)]
          : breakdown,
      totalLabel: 'Total today',
      totalValue: _todayTotal,
    );
  }

  void _showStreakDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final List<MapEntry<String, int>> lastDays = [];
    DateTime day = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final key = 'dhikr_daily_${DateFormat('yyyyMMdd').format(day)}';
      final count = prefs.getInt(key) ?? 0;
      final label = i == 0 ? 'Today' : DateFormat('EEE, MMM d').format(day);
      lastDays.add(MapEntry(label, count));
      day = day.subtract(const Duration(days: 1));
    }
    if (!mounted) return;
    _showDetailSheet(
      title: 'Your Streak',
      subtitle: _currentStreak > 0 ? '$_currentStreak day${_currentStreak == 1 ? '' : 's'} in a row 🔥' : 'Start today to begin a streak!',
      icon: Icons.local_fire_department_rounded,
      color: AppColors.coralOrange,
      rows: lastDays,
      totalLabel: 'Current streak',
      totalValue: _currentStreak,
      totalSuffix: ' days',
    );
  }

  void _showLifetimeDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final List<MapEntry<String, int>> breakdown = [];
    for (final preset in _presets) {
      final key = 'dhikr_lifetime_${preset.name.replaceAll(' ', '_')}';
      final count = prefs.getInt(key) ?? 0;
      if (count > 0) breakdown.add(MapEntry(preset.name, count));
    }
    final customCount = prefs.getInt('dhikr_lifetime_Custom') ?? 0;
    if (customCount > 0) breakdown.add(MapEntry('Custom', customCount));

    if (!mounted) return;
    _showDetailSheet(
      title: 'Lifetime Dhikr',
      subtitle: 'Everything you\'ve counted since you started',
      icon: Icons.all_inclusive_rounded,
      color: AppColors.midTeal,
      rows: breakdown.isEmpty ? [const MapEntry('No history yet', 0)] : breakdown,
      totalLabel: 'Grand total',
      totalValue: _lifetimeTotal,
    );
  }

  void _showDetailSheet({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<MapEntry<String, int>> rows,
    required String totalLabel,
    required int totalValue,
    String totalSuffix = '',
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim, secondaryAnim, child) {
        return BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 6 * anim.value, sigmaY: 6 * anim.value),
          child: FadeTransition(
            opacity: anim,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1.0).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: Container(
                color: Colors.black.withValues(alpha: 0.25 * anim.value),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 30, offset: const Offset(0, 12)),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                                  child: Icon(icon, color: color, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
                                      Text(subtitle, style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.navyBlue.withValues(alpha: 0.5))),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Icon(Icons.close_rounded, size: 18, color: AppColors.navyBlue.withValues(alpha: 0.4)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ...rows.map((r) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 5),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(r.key,
                                            style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.navyBlue.withValues(alpha: 0.75))),
                                      ),
                                      if (r.value > 0)
                                        Text('${r.value}', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
                                    ],
                                  ),
                                )),
                            const Divider(height: 22),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(totalLabel, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.navyBlue)),
                                  Text('$totalValue$totalSuffix', style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.bold, color: color)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}