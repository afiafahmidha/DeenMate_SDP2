import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/auth_header.dart'; // AppColors

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
  const _DhikrPreset({
    required this.name,
    required this.arabic,
    required this.translit,
    required this.meaning,
    required this.target,
  });
}

const List<_DhikrPreset> _presets = [
  _DhikrPreset(
    name: 'SubhanAllah',
    arabic: 'سُبْحَانَ اللّٰهِ',
    translit: 'SubhanAllah',
    meaning: 'Glory be to Allah',
    target: 33,
  ),
  _DhikrPreset(
    name: 'Alhamdulillah',
    arabic: 'الْحَمْدُ لِلّٰهِ',
    translit: 'Alhamdulillah',
    meaning: 'All praise is due to Allah',
    target: 33,
  ),
  _DhikrPreset(
    name: 'Allahu Akbar',
    arabic: 'اللّٰهُ أَكْبَرُ',
    translit: 'Allahu Akbar',
    meaning: 'Allah is the Greatest',
    target: 34,
  ),
  _DhikrPreset(
    name: 'Astaghfirullah',
    arabic: 'أَسْتَغْفِرُ اللّٰهَ',
    translit: 'Astaghfirullah',
    meaning: 'I seek forgiveness from Allah',
    target: 100,
  ),
  _DhikrPreset(
    name: 'La ilaha illallah',
    arabic: 'لَا إِلٰهَ إِلَّا اللّٰهُ',
    translit: 'La ilaha illallah',
    meaning: 'There is no god but Allah',
    target: 100,
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
  ),
  _DhikrPreset(
    name: 'Alhamdulillah',
    arabic: 'الْحَمْدُ لِلّٰهِ',
    translit: 'Alhamdulillah',
    meaning: 'All praise is due to Allah',
    target: 33,
  ),
  _DhikrPreset(
    name: 'Allahu Akbar',
    arabic: 'اللّٰهُ أَكْبَرُ',
    translit: 'Allahu Akbar',
    meaning: 'Allah is the Greatest',
    target: 34,
  ),
];

class _DhikrCounterScreenState extends State<DhikrCounterScreen> with SingleTickerProviderStateMixin {
  int _selectedPresetIndex = 0;
  int _count = 0;
  int _customTarget = 100;

  bool _isSequenceMode = false;
  int _sequencePhase = 0; // 0,1,2 within _tasbihFatimahSequence

  int _todayTotal = 0;
  int _lifetimeTotal = 0;
  int _currentStreak = 0;

  late AnimationController _pulseController;

  _DhikrPreset get _activePreset {
    if (_isSequenceMode) return _tasbihFatimahSequence[_sequencePhase];
    if (_selectedPresetIndex < _presets.length) return _presets[_selectedPresetIndex];
    return _DhikrPreset(
      name: 'Custom',
      arabic: '',
      translit: 'Custom Dhikr',
      meaning: 'Your own count target',
      target: _customTarget,
    );
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _loadStats();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String get _todayKey => 'dhikr_daily_${DateFormat('yyyyMMdd').format(DateTime.now())}';

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final today = prefs.getInt(_todayKey) ?? 0;
    final lifetime = prefs.getInt('dhikr_lifetime_total') ?? 0;

    // Calculate current streak by walking backwards from today
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
    });
  }

  Future<void> _persistTap() async {
    final prefs = await SharedPreferences.getInstance();
    final today = (prefs.getInt(_todayKey) ?? 0) + 1;
    final lifetime = (prefs.getInt('dhikr_lifetime_total') ?? 0) + 1;
    await prefs.setInt(_todayKey, today);
    await prefs.setInt('dhikr_lifetime_total', lifetime);
    if (!mounted) return;
    setState(() {
      _todayTotal = today;
      _lifetimeTotal = lifetime;
      if (_currentStreak == 0) _currentStreak = 1;
    });
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    _pulseController.forward(from: 0);

    setState(() => _count++);
    _persistTap();

    if (_count >= _activePreset.target) {
      HapticFeedback.mediumImpact();
      if (_isSequenceMode && _sequencePhase < _tasbihFatimahSequence.length - 1) {
        // Move to next phase in the Tasbih Fatimah routine
        setState(() {
          _sequencePhase++;
          _count = 0;
        });
        _showSnack('${_tasbihFatimahSequence[_sequencePhase - 1].name} complete! Next: ${_tasbihFatimahSequence[_sequencePhase].name}');
      } else if (_isSequenceMode) {
        // Whole routine finished
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
          decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.navyBlue),
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
            backgroundColor: const Color(0xFFF7F7F5),
            body: SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        _buildMeaningCard(),
                        const SizedBox(height: 18),
                        _buildCounterCircle(),
                        const SizedBox(height: 14),
                        _buildCounterActions(),
                        const SizedBox(height: 22),
                        _buildSectionLabel('Choose Dhikr'),
                        const SizedBox(height: 10),
                        _buildPresetChips(),
                        const SizedBox(height: 20),
                        _buildSectionLabel('Your Stats'),
                        const SizedBox(height: 10),
                        _buildStatsRow(),
                        const SizedBox(height: 20),
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
            decoration: BoxDecoration(color: AppColors.navyBlue, borderRadius: BorderRadius.circular(14)),
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
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppColors.navyBlue.withValues(alpha: 0.6), size: 22),
            onPressed: _resetCounter,
            tooltip: 'Reset counter',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String title) {
    return Row(
      children: [
        Container(width: 4, height: 16, decoration: BoxDecoration(color: AppColors.navyBlue, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
      ],
    );
  }

  // ===== MEANING CARD =====
  Widget _buildMeaningCard() {
    final preset = _activePreset;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.navyBlue, Color(0xFF1D3550)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.navyBlue.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isSequenceMode)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                child: Text('Tasbih Fatimah — Phase ${_sequencePhase + 1}/3',
                    style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          if (preset.arabic.isNotEmpty)
            Text(preset.arabic,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: Colors.white, height: 1.6)),
          if (preset.arabic.isNotEmpty) const SizedBox(height: 6),
          Text(preset.translit, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(preset.meaning, style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.75))),
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
          animation: _pulseController,
          builder: (context, child) {
            final scale = 1.0 - (_pulseController.value * 0.05);
            return Transform.scale(scale: scale, child: child);
          },
          child: SizedBox(
            width: 220,
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 220,
                  height: 220,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    backgroundColor: AppColors.navyBlue.withValues(alpha: 0.08),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.midTeal),
                  ),
                ),
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: AppColors.navyBlue.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$_count', style: GoogleFonts.poppins(fontSize: 48, fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
                      Text('/ $target',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.navyBlue.withValues(alpha: 0.45))),
                      const SizedBox(height: 6),
                      Text('tap to count', style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.navyBlue.withValues(alpha: 0.35))),
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

  Widget _buildCounterActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _actionChip(icon: Icons.refresh_rounded, label: 'Reset', onTap: _resetCounter),
        const SizedBox(width: 12),
        _actionChip(
          icon: Icons.auto_awesome_rounded,
          label: 'Tasbih Fatimah',
          onTap: _startTasbihFatimah,
          highlighted: _isSequenceMode,
        ),
        const SizedBox(width: 12),
        _actionChip(icon: Icons.tune_rounded, label: 'Custom', onTap: _editCustomTarget),
      ],
    );
  }

  Widget _actionChip({required IconData icon, required String label, required VoidCallback onTap, bool highlighted = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: highlighted ? AppColors.midTeal.withValues(alpha: 0.15) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: highlighted ? AppColors.midTeal : AppColors.navyBlue.withValues(alpha: 0.15)),
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

  // ===== PRESET CHIPS =====
  Widget _buildPresetChips() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(_presets.length, (i) {
        final selected = !_isSequenceMode && _selectedPresetIndex == i;
        return GestureDetector(
          onTap: () => _selectPreset(i),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.navyBlue : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? AppColors.navyBlue : AppColors.navyBlue.withValues(alpha: 0.15)),
              boxShadow: [BoxShadow(color: AppColors.navyBlue.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_presets[i].name,
                    style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: selected ? Colors.white : AppColors.navyBlue)),
                Text('Target: ${_presets[i].target}',
                    style: GoogleFonts.inter(fontSize: 10, color: selected ? Colors.white.withValues(alpha: 0.7) : AppColors.navyBlue.withValues(alpha: 0.45))),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ===== STATS ROW =====
  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _statCard(icon: Icons.today_rounded, label: 'Today', value: '$_todayTotal', color: AppColors.navyBlue)),
        const SizedBox(width: 10),
        Expanded(child: _statCard(icon: Icons.local_fire_department_rounded, label: 'Streak', value: '$_currentStreak days', color: AppColors.coralOrange)),
        const SizedBox(width: 10),
        Expanded(child: _statCard(icon: Icons.all_inclusive_rounded, label: 'Lifetime', value: '$_lifetimeTotal', color: AppColors.midTeal)),
      ],
    );
  }

  Widget _statCard({required IconData icon, required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.navyBlue.withValues(alpha: 0.1)),
        boxShadow: [BoxShadow(color: AppColors.navyBlue.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.navyBlue.withValues(alpha: 0.5))),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
        ],
      ),
    );
  }
}