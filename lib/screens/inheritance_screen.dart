import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/auth_header.dart'; // AppColors

/// ===== SIMPLE INHERITANCE (FARAID) GUIDE SCREEN =====
/// Covers the most common family scenario: spouse + children + parents.
/// Does NOT handle extended family / Awl / Radd edge cases — a disclaimer
/// is shown for those situations.
///
/// Push like the other planner pages:
///   Navigator.of(context).push(
///     MaterialPageRoute(builder: (_) => const InheritanceGuideScreen()),
///   );
class InheritanceGuideScreen extends StatefulWidget {
  const InheritanceGuideScreen({super.key});

  @override
  State<InheritanceGuideScreen> createState() => _InheritanceGuideScreenState();
}

// ===== INHERITANCE-RELATED AYAH DATA =====
// Each entry pairs one background image with one Faraid-related ayah so
// the hero carousel and the ayah caption change together as it cycles.
// Add your own images to assets/images/inheritance/1.jpg ... 5.jpg (and
// register the folder in pubspec.yaml) — if an image is missing, that
// slide gracefully falls back to a navy gradient instead of crashing.
class _InheritanceAyahSlide {
  final String imagePath;
  final String reference;
  final String quotedPhrase;
  final String reflection;
  const _InheritanceAyahSlide({
    required this.imagePath,
    required this.reference,
    required this.quotedPhrase,
    required this.reflection,
  });
}

const List<_InheritanceAyahSlide> _inheritanceAyahs = [
  _InheritanceAyahSlide(
    imagePath: 'assets/images/inheritance/1.jpg',
    reference: 'Surah An-Nisa 4:7',
    quotedPhrase: 'men is a share of what parents and relatives leave',
    reflection:
        'The Quran establishes that both men and women have a rightful, defined share in inherited wealth — a principle unusual for its time.',
  ),
  _InheritanceAyahSlide(
    imagePath: 'assets/images/inheritance/2.jpg',
    reference: 'Surah An-Nisa 4:11',
    quotedPhrase: 'for the male what is equal to the share of two females',
    reflection:
        'This verse lays out the foundation of how children inherit — the core ratio the Sons/Daughters calculation on this page is built on.',
  ),
  _InheritanceAyahSlide(
    imagePath: 'assets/images/inheritance/3.jpg',
    reference: 'Surah An-Nisa 4:11',
    quotedPhrase: 'after any bequest is made or debt is paid',
    reflection:
        'Before any heir receives their share, the Quran requires settling debts and honoring a will (up to a third of the estate) first.',
  ),
  _InheritanceAyahSlide(
    imagePath: 'assets/images/inheritance/4.jpg',
    reference: 'Surah An-Nisa 4:12',
    quotedPhrase: 'for you is half of what your wives leave',
    reflection:
        'This verse sets out the spouse\'s share — the basis for the Husband/Wife calculation used in this guide.',
  ),
  _InheritanceAyahSlide(
    imagePath: 'assets/images/inheritance/5.jpg',
    reference: 'Surah An-Nisa 4:11',
    quotedPhrase: 'Allah is Knowing and Wise',
    reflection:
        'The Faraid shares close with a reminder that this precise, detailed system of division reflects divine wisdom, not arbitrary rule.',
  ),
];

class _InheritanceGuideScreenState extends State<InheritanceGuideScreen> {
  // ===== INPUT STATE =====
  String _deceasedGender = 'Male'; // 'Male' or 'Female'
  bool _spouseAlive = false;
  int _wivesCount = 1; // only relevant if deceased is Male
  int _sonsCount = 0;
  int _daughtersCount = 0;
  bool _fatherAlive = false;
  bool _motherAlive = false;

  final TextEditingController _estateCtrl = TextEditingController(text: '0');

  @override
  void dispose() {
    _estateCtrl.dispose();
    super.dispose();
  }

  double get _estateValue => double.tryParse(_estateCtrl.text.replaceAll(',', '')) ?? 0;

  bool get _hasChildren => _sonsCount > 0 || _daughtersCount > 0;

  // ===== CORE FARAID CALCULATION (common-case simplification) =====
  // Returns a list of {label, fraction, note}
  List<Map<String, dynamic>> _calculateShares() {
    final List<Map<String, dynamic>> result = [];
    double usedFraction = 0.0;

    // ---- 1. Spouse share (Fard) ----
    double spouseFraction = 0.0;
    if (_spouseAlive) {
      if (_deceasedGender == 'Male') {
        // Deceased is a husband -> wife/wives share
        spouseFraction = _hasChildren ? (1 / 8) : (1 / 4);
        final double perWife = spouseFraction / _wivesCount;
        for (int i = 0; i < _wivesCount; i++) {
          result.add({
            'label': _wivesCount > 1 ? 'Wife ${i + 1}' : 'Wife',
            'fraction': perWife,
            'note': _hasChildren ? 'Fard share: 1/8 (shared)' : 'Fard share: 1/4 (shared)',
          });
        }
      } else {
        // Deceased is a wife -> husband share
        spouseFraction = _hasChildren ? (1 / 4) : (1 / 2);
        result.add({
          'label': 'Husband',
          'fraction': spouseFraction,
          'note': _hasChildren ? 'Fard share: 1/4' : 'Fard share: 1/2',
        });
      }
      usedFraction += spouseFraction;
    }

    // ---- 2. Mother share (Fard) ----
    double motherFraction = 0.0;
    if (_motherAlive) {
      motherFraction = _hasChildren ? (1 / 6) : (1 / 3);
      result.add({
        'label': 'Mother',
        'fraction': motherFraction,
        'note': _hasChildren ? 'Fard share: 1/6 (children present)' : 'Fard share: 1/3',
      });
      usedFraction += motherFraction;
    }

    // ---- 3. Father & Children ----
    if (_hasChildren) {
      // Father gets 1/6 as Fard when children are present
      double fatherFraction = 0.0;
      if (_fatherAlive) {
        fatherFraction = 1 / 6;
        result.add({
          'label': 'Father',
          'fraction': fatherFraction,
          'note': 'Fard share: 1/6 (children present)',
        });
        usedFraction += fatherFraction;
      }

      if (_sonsCount > 0) {
        // Sons + daughters share the remainder as Asaba, ratio 2:1
        final double remainder = (1.0 - usedFraction).clamp(0.0, 1.0);
        final double shareUnits = ((_sonsCount * 2) + _daughtersCount).toDouble();
        final double perUnit = shareUnits > 0 ? remainder / shareUnits : 0.0;
        if (_sonsCount > 0) {
          result.add({
            'label': _sonsCount > 1 ? '$_sonsCount Sons (combined)' : 'Son',
            'fraction': perUnit * 2 * _sonsCount,
            'note': 'Residuary (Asaba) — each son gets 2x a daughter\'s share',
          });
        }
        if (_daughtersCount > 0) {
          result.add({
            'label': _daughtersCount > 1 ? '$_daughtersCount Daughters (combined)' : 'Daughter',
            'fraction': perUnit * _daughtersCount,
            'note': 'Residuary (Asaba) — half a son\'s share each',
          });
        }
      } else if (_daughtersCount > 0) {
        // No sons: daughters get Fard share directly
        double daughtersFraction = _daughtersCount == 1 ? (1 / 2) : (2 / 3);
        result.add({
          'label': _daughtersCount > 1 ? '$_daughtersCount Daughters (combined)' : 'Daughter',
          'fraction': daughtersFraction,
          'note': _daughtersCount == 1 ? 'Fard share: 1/2 (only daughter)' : 'Fard share: 2/3 (shared)',
        });
        usedFraction += daughtersFraction;

        // Remainder (if any) goes to father as Asaba
        if (_fatherAlive) {
          final double remainder = (1.0 - usedFraction).clamp(0.0, 1.0);
          // Update father's entry to include residue
          final int fatherIdx = result.indexWhere((e) => e['label'] == 'Father');
          if (fatherIdx != -1) {
            result[fatherIdx]['fraction'] = (result[fatherIdx]['fraction'] as double) + remainder;
            result[fatherIdx]['note'] = 'Fard 1/6 + residue (no sons present)';
          }
        }
      }
    } else {
      // ---- No children: father takes residue as Asaba ----
      if (_fatherAlive) {
        final double remainder = (1.0 - usedFraction).clamp(0.0, 1.0);
        result.add({
          'label': 'Father',
          'fraction': remainder,
          'note': 'Residuary (Asaba) — takes remaining estate',
        });
        usedFraction += remainder;
      }
    }

    return result;
  }

  bool get _hasUnallocatedRemainder {
    final shares = _calculateShares();
    final total = shares.fold<double>(0.0, (sum, e) => sum + (e['fraction'] as double));
    // If nobody is set as residuary and total < 1, there's unallocated estate
    return total < 0.999 && (_spouseAlive || _motherAlive || _fatherAlive || _hasChildren);
  }

  @override
  Widget build(BuildContext context) {
    final shares = _calculateShares();
    final bool anyoneSelected = _spouseAlive || _motherAlive || _fatherAlive || _hasChildren;

    return Container(
      color: const Color(0xFFE8E8E8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Scaffold(
            backgroundColor: const Color(0xFFF7F7F5),
            body: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── HERO IMAGE + AYAH CAROUSEL (auto-scrolls while on this page) ──
                SliverAppBar(
                  expandedHeight: 260,
                  pinned: true,
                  backgroundColor: AppColors.navyBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.pin,
                    background: const _InheritanceHeroCarousel(slides: _inheritanceAyahs),
                  ),
                ),
                // ── REST OF THE PAGE (unchanged calculator) ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      children: [
                        _buildEstateInput(),
                        const SizedBox(height: 16),
                        _buildDeceasedGenderCard(),
                        const SizedBox(height: 16),
                        _buildSurvivorsCard(),
                        const SizedBox(height: 20),
                        _buildSectionLabel('Distribution Result'),
                        const SizedBox(height: 10),
                        if (!anyoneSelected)
                          _buildEmptyState()
                        else
                          ...shares.map((s) => _buildShareCard(s)),
                        if (anyoneSelected && _hasUnallocatedRemainder) _buildRemainderNotice(),
                        const SizedBox(height: 20),
                        _buildDisclaimerCard(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Container(width: 4, height: 16, decoration: BoxDecoration(color: AppColors.navyBlue, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(title, style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
        ],
      ),
    );
  }

  // ===== ESTATE VALUE INPUT =====
  Widget _buildEstateInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: AppColors.navyBlue.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.navyBlue.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.navyBlue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Net Estate Value',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navyBlue)),
          ),
          SizedBox(
            width: 130,
            child: TextField(
              controller: _estateCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navyBlue),
              decoration: InputDecoration(
                prefixText: '৳ ',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                filled: true,
                fillColor: const Color(0xFFF5F7FA),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.midTeal, width: 1.5),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  // ===== DECEASED GENDER SELECTOR =====
  Widget _buildDeceasedGenderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: AppColors.navyBlue.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Deceased Person', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navyBlue)),
          const SizedBox(height: 10),
          Row(
            children: ['Male', 'Female'].map((g) {
              final bool selected = _deceasedGender == g;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _deceasedGender = g;
                    _spouseAlive = false;
                  }),
                  child: Container(
                    margin: EdgeInsets.only(right: g == 'Male' ? 8 : 0, left: g == 'Female' ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.navyBlue : const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(g,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : AppColors.navyBlue.withValues(alpha: 0.55),
                        )),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ===== SURVIVORS INPUT =====
  Widget _buildSurvivorsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: AppColors.navyBlue.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Surviving Family Members',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navyBlue)),
          const SizedBox(height: 14),

          // Spouse toggle
          _buildSwitchRow(
            label: _deceasedGender == 'Male' ? 'Wife/Wives alive' : 'Husband alive',
            value: _spouseAlive,
            onChanged: (v) => setState(() => _spouseAlive = v),
          ),
          if (_spouseAlive && _deceasedGender == 'Male') ...[
            const SizedBox(height: 10),
            _buildCounterRow(
              label: 'Number of wives',
              value: _wivesCount,
              min: 1,
              max: 4,
              onChanged: (v) => setState(() => _wivesCount = v),
            ),
          ],
          const Divider(height: 28),

          _buildCounterRow(
            label: 'Number of sons',
            value: _sonsCount,
            min: 0,
            max: 10,
            onChanged: (v) => setState(() => _sonsCount = v),
          ),
          const SizedBox(height: 12),
          _buildCounterRow(
            label: 'Number of daughters',
            value: _daughtersCount,
            min: 0,
            max: 10,
            onChanged: (v) => setState(() => _daughtersCount = v),
          ),
          const Divider(height: 28),

          _buildSwitchRow(
            label: 'Father alive',
            value: _fatherAlive,
            onChanged: (v) => setState(() => _fatherAlive = v),
          ),
          const SizedBox(height: 10),
          _buildSwitchRow(
            label: 'Mother alive',
            value: _motherAlive,
            onChanged: (v) => setState(() => _motherAlive = v),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow({required String label, required bool value, required ValueChanged<bool> onChanged}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.navyBlue)),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: AppColors.midTeal,
          inactiveTrackColor: const Color(0xFFE0E0E0),
        ),
      ],
    );
  }

  Widget _buildCounterRow({
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.navyBlue)),
        Row(
          children: [
            _counterButton(Icons.remove_rounded, () {
              if (value > min) onChanged(value - 1);
            }),
            Container(
              width: 32,
              alignment: Alignment.center,
              child: Text('$value', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
            ),
            _counterButton(Icons.add_rounded, () {
              if (value < max) onChanged(value + 1);
            }),
          ],
        ),
      ],
    );
  }

  Widget _counterButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: AppColors.navyBlue.withValues(alpha: 0.08), shape: BoxShape.circle),
        child: Icon(icon, size: 16, color: AppColors.navyBlue),
      ),
    );
  }

  // ===== EMPTY STATE =====
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(Icons.family_restroom_rounded, size: 36, color: AppColors.navyBlue.withValues(alpha: 0.25)),
          const SizedBox(height: 10),
          Text('Select surviving family members above to see the share distribution.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.navyBlue.withValues(alpha: 0.5))),
        ],
      ),
    );
  }

  // ===== SHARE RESULT CARD =====
  Widget _buildShareCard(Map<String, dynamic> share) {
    final double fraction = share['fraction'] as double;
    final double amount = fraction * _estateValue;
    final String fractionStr = _fractionToReadable(fraction);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.navyBlue.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.midTeal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Text(fractionStr,
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(share['label'] as String,
                    style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
                const SizedBox(height: 2),
                Text(share['note'] as String,
                    style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.navyBlue.withValues(alpha: 0.5))),
              ],
            ),
          ),
          if (_estateValue > 0)
            Text('৳ ${amount.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
        ],
      ),
    );
  }

  String _fractionToReadable(double f) {
    if (f <= 0) return '0';
    // Try to express as a simple fraction for common Faraid values
    const Map<String, double> common = {
      '1/2': 0.5, '1/3': 1 / 3, '1/4': 0.25, '1/6': 1 / 6,
      '1/8': 0.125, '2/3': 2 / 3, '1/12': 1 / 12, '1/24': 1 / 24,
    };
    for (final entry in common.entries) {
      if ((f - entry.value).abs() < 0.005) return entry.key;
    }
    return '${(f * 100).toStringAsFixed(1)}%';
  }

  Widget _buildRemainderNotice() {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.coralOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.coralOrange, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Part of the estate remains unallocated — this usually goes to other relatives (siblings, grandparents) not covered in this simplified guide.',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.navyBlue.withValues(alpha: 0.65), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ===== DISCLAIMER =====
  Widget _buildDisclaimerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.navyBlue.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.navyBlue, size: 16),
              const SizedBox(width: 8),
              Text('Important Note',
                  style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'This guide only covers common cases: spouse, children, and parents. It does not handle siblings, grandparents, multiple wives with children from different marriages, debts, or wills (up to 1/3 of estate must be deducted first). For real distribution, please consult a qualified Islamic scholar or Faraid expert.',
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.navyBlue.withValues(alpha: 0.6), height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ===== HERO IMAGE + AYAH CAROUSEL =====
// Auto-scrolls through the image+ayah pairs the whole time the user stays
// on this page. Falls back to a navy gradient per-slide if the image
// asset isn't found yet, so nothing crashes before real photos are added.
class _InheritanceHeroCarousel extends StatefulWidget {
  final List<_InheritanceAyahSlide> slides;
  const _InheritanceHeroCarousel({required this.slides});

  @override
  State<_InheritanceHeroCarousel> createState() => _InheritanceHeroCarouselState();
}

class _InheritanceHeroCarouselState extends State<_InheritanceHeroCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    if (widget.slides.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;
      _page = (_page + 1) % widget.slides.length;
      _controller.animateToPage(
        _page,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Widget _gradientFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navyBlue, Color(0xFF1D3550)],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: widget.slides.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (context, index) {
            return Image.asset(
              widget.slides[index].imagePath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _gradientFallback(),
            );
          },
        ),
        // Gradient overlay so the ayah text stays legible over any photo
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.05),
                  Colors.black.withValues(alpha: 0.80),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.3, 1.0],
              ),
            ),
          ),
        ),
        // Ayah caption — changes together with the image
        Positioned(
          left: 20,
          right: 20,
          bottom: 20,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Column(
              key: ValueKey(_page),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.slides[_page].reference,
                  style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.coralOrange),
                ),
                const SizedBox(height: 6),
                Text(
                  '"${widget.slides[_page].quotedPhrase}"',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 17,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.slides[_page].reflection,
                  style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.85), height: 1.4),
                ),
              ],
            ),
          ),
        ),
        // Dot indicators
        if (widget.slides.length > 1)
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.slides.length, (i) {
                final isActive = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: isActive ? 0.95 : 0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}