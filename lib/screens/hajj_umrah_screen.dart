import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/auth_header.dart'; // AppColors

class HajjUmrahPlannerScreen extends StatefulWidget {
  const HajjUmrahPlannerScreen({super.key});

  @override
  State<HajjUmrahPlannerScreen> createState() => _HajjUmrahPlannerScreenState();
}

class _HajjUmrahPlannerScreenState extends State<HajjUmrahPlannerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _mode = 'Hajj'; // 'Hajj' or 'Umrah'
  bool _isDarkMode = false;

  final Map<String, bool> _hajjRitualDone = {};
  final Map<String, bool> _umrahRitualDone = {};
  final Map<String, bool> _packingDone = {};
  final Map<String, bool> _documentsDone = {};

  // ===== RITUAL STEPS DATA =====
  final List<Map<String, String>> _hajjSteps = [
    {'id': 'ihram', 'title': 'Enter Ihram', 'desc': 'Wear Ihram at the Miqat with the intention (Niyyah) for Hajj.'},
    {'id': 'tawaf_qudum', 'title': 'Tawaf al-Qudum', 'desc': 'Arrival Tawaf around the Kaaba (7 rounds).'},
    {'id': 'mina1', 'title': 'Day of Tarwiyah (8th Dhul Hijjah)', 'desc': 'Travel to Mina, stay overnight, offer the 5 daily prayers.'},
    {'id': 'arafat', 'title': 'Day of Arafah (9th Dhul Hijjah)', 'desc': 'Stand at Arafat (Wuquf) from Dhuhr until Maghrib — the core of Hajj.'},
    {'id': 'muzdalifah', 'title': 'Muzdalifah', 'desc': 'Travel after sunset, collect pebbles for Rami, stay overnight.'},
    {'id': 'rami1', 'title': 'Rami al-Jamarat (10th)', 'desc': 'Stone the large Jamarat (Jamarat al-Aqabah) with 7 pebbles.'},
    {'id': 'qurbani', 'title': 'Qurbani (Sacrifice)', 'desc': 'Offer the sacrifice, then shave or trim the hair (Halq/Taqsir).'},
    {'id': 'tawaf_ifadah', 'title': 'Tawaf al-Ifadah', 'desc': 'Return to Makkah for the obligatory Tawaf, then Sa\'i.'},
    {'id': 'rami_days', 'title': 'Rami (11th–13th)', 'desc': 'Stone all three Jamarat each day while staying at Mina.'},
    {'id': 'tawaf_wida', 'title': 'Tawaf al-Wida', 'desc': 'Farewell Tawaf performed just before leaving Makkah.'},
  ];

  final List<Map<String, String>> _umrahSteps = [
    {'id': 'ihram_u', 'title': 'Enter Ihram', 'desc': 'Wear Ihram at the Miqat with the intention (Niyyah) for Umrah.'},
    {'id': 'tawaf_u', 'title': 'Tawaf', 'desc': 'Circle the Kaaba 7 times, starting and ending at the Black Stone.'},
    {'id': 'sai_u', 'title': 'Sa\'i', 'desc': 'Walk between the hills of Safa and Marwah 7 times.'},
    {'id': 'halq_u', 'title': 'Halq / Taqsir', 'desc': 'Shave or trim the hair to complete Umrah.'},
  ];

  // ===== PACKING & DOCUMENT LISTS =====
  final List<String> _packingItems = [
    'Ihram cloths (2 sets, for men)',
    'Modest, comfortable clothing (for women)',
    'Sandals / slippers',
    'Money belt / travel pouch',
    'Small foldable prayer mat',
    'Umbrella or cap for sun protection',
    'Personal medicine & first-aid kit',
    'Unscented soap, shampoo & toiletries',
    'Power bank & charger',
    'Small backpack for daily use',
    'Reusable water bottle',
    'Copies of important documents',
  ];

  final List<String> _documentItems = [
    'Valid passport (6+ months validity)',
    'Hajj/Umrah visa',
    'Meningitis (ACYW135) vaccination certificate',
    'Return flight ticket',
    'Hotel / package booking confirmation',
    'Travel & health insurance',
    'Passport-size photographs',
    'Emergency contact list',
  ];

  // ===== DUAS =====
  final List<Map<String, String>> _duas = [
    {
      'title': 'Talbiyah',
      'arabic': 'لَبَّيْكَ اللَّهُمَّ لَبَّيْكَ',
      'translit': 'Labbayk Allahumma Labbayk',
      'meaning': 'Here I am, O Allah, here I am, at Your service.',
    },
    {
      'title': 'Entering Ihram',
      'arabic': 'اللَّهُمَّ إِنِّي أُرِيدُ الْحَجَّ',
      'translit': 'Allahumma inni ureedul Hajja',
      'meaning': 'O Allah, I intend to perform Hajj — make it easy for me and accept it from me.',
    },
    {
      'title': 'Between Safa & Marwah',
      'arabic': 'رَبِّ اغْفِرْ وَارْحَمْ',
      'translit': 'Rabbighfir warham',
      'meaning': 'My Lord, forgive and have mercy.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadState();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
      for (final s in _hajjSteps) {
        _hajjRitualDone[s['id']!] = prefs.getBool('hajj_${s['id']}') ?? false;
      }
      for (final s in _umrahSteps) {
        _umrahRitualDone[s['id']!] = prefs.getBool('umrah_${s['id']}') ?? false;
      }
      for (final item in _packingItems) {
        _packingDone[item] = prefs.getBool('pack_${item.hashCode}') ?? false;
      }
      for (final item in _documentItems) {
        _documentsDone[item] = prefs.getBool('doc_${item.hashCode}') ?? false;
      }
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isDarkMode ? const Color(0xFF121212) : const Color(0xFFF7F7F5);
    final outerBg = _isDarkMode ? const Color(0xFF000000) : const Color(0xFFE8E8E8);

    return Container(
      color: outerBg,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Scaffold(
            backgroundColor: bgColor,
            body: SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  _buildTabBar(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildRitualsTab(),
                        _buildPackingTab(),
                        _buildDocumentsTab(),
                        _buildDuasTab(),
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

  // ===== HEADER (back button + title + Hajj/Umrah toggle) =====
  Widget _buildHeader() {
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;
    final subtextColor = _isDarkMode ? Colors.white70 : AppColors.navyBlue.withValues(alpha: 0.55);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _isDarkMode ? const Color(0xFF2C2C2C) : AppColors.navyBlue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hajj & Umrah Planner',
                    style: GoogleFonts.poppins(
                        fontSize: 15.5, fontWeight: FontWeight.bold, color: textColor)),
                Text('Rituals, packing & documents',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: subtextColor)),
              ],
            ),
          ),
          // Hajj / Umrah mode toggle
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: _isDarkMode ? const Color(0xFF2C2C2C) : AppColors.navyBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: ['Hajj', 'Umrah'].map((m) {
                final bool selected = _mode == m;
                return GestureDetector(
                  onTap: () => setState(() => _mode = m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? (_isDarkMode ? AppColors.midTeal : AppColors.navyBlue) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      m,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : (_isDarkMode ? Colors.white70 : AppColors.navyBlue.withValues(alpha: 0.6)),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final cardBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final labelColor = _isDarkMode ? Colors.white : AppColors.navyBlue;
    final unselectedColor = _isDarkMode ? Colors.white38 : AppColors.placeholder;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: labelColor,
        unselectedLabelColor: unselectedColor,
        indicatorColor: AppColors.midTeal,
        indicatorWeight: 3,
        labelStyle: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w500),
        tabs: const [
          Tab(text: 'Rituals'),
          Tab(text: 'Packing'),
          Tab(text: 'Documents'),
          Tab(text: 'Duas'),
        ],
      ),
    );
  }

  // ===== RITUALS TAB =====
  Widget _buildRitualsTab() {
    final steps = _mode == 'Hajj' ? _hajjSteps : _umrahSteps;
    final doneMap = _mode == 'Hajj' ? _hajjRitualDone : _umrahRitualDone;
    final prefix = _mode == 'Hajj' ? 'hajj_' : 'umrah_';
    final completed = doneMap.values.where((v) => v).length;
    final cardBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;
    final subtextColor = _isDarkMode ? Colors.white70 : AppColors.navyBlue.withValues(alpha: 0.6);

    return ListView(
      key: ValueKey('rituals_$_mode'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _buildProgressCard(completed, steps.length, '$_mode Progress'),
        const SizedBox(height: 16),
        ...List.generate(steps.length, (i) {
          final step = steps[i];
          final id = step['id']!;
          final isDone = doneMap[id] ?? false;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () {
                setState(() => doneMap[id] = !isDone);
                _saveBool('$prefix$id', !isDone);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDone ? AppColors.midTeal.withValues(alpha: 0.4) : (_isDarkMode ? Colors.white.withOpacity(0.08) : Colors.transparent),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3)),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        color: isDone ? AppColors.midTeal : (_isDarkMode ? Colors.white.withOpacity(0.12) : AppColors.navyBlue.withValues(alpha: 0.06)),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                            : Text('${i + 1}',
                                style: GoogleFonts.poppins(
                                    fontSize: 12, fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(step['title']!,
                              style: GoogleFonts.poppins(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: isDone ? AppColors.midTeal : textColor,
                                decoration: isDone ? TextDecoration.lineThrough : null,
                              )),
                          const SizedBox(height: 3),
                          Text(step['desc']!,
                              style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  color: subtextColor,
                                  height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ===== PACKING TAB =====
  Widget _buildPackingTab() {
    final completed = _packingDone.values.where((v) => v).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _buildProgressCard(completed, _packingItems.length, 'Packing Progress'),
        const SizedBox(height: 16),
        ..._packingItems.map((item) => _buildChecklistTile(
              label: item,
              isDone: _packingDone[item] ?? false,
              onTap: () {
                final newVal = !(_packingDone[item] ?? false);
                setState(() => _packingDone[item] = newVal);
                _saveBool('pack_${item.hashCode}', newVal);
              },
              icon: Icons.checkroom_rounded,
            )),
      ],
    );
  }

  // ===== DOCUMENTS TAB =====
  Widget _buildDocumentsTab() {
    final completed = _documentsDone.values.where((v) => v).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _buildProgressCard(completed, _documentItems.length, 'Document Progress'),
        const SizedBox(height: 16),
        ..._documentItems.map((item) => _buildChecklistTile(
              label: item,
              isDone: _documentsDone[item] ?? false,
              onTap: () {
                final newVal = !(_documentsDone[item] ?? false);
                setState(() => _documentsDone[item] = newVal);
                _saveBool('doc_${item.hashCode}', newVal);
              },
              icon: Icons.description_rounded,
            )),
      ],
    );
  }

  // ===== DUAS TAB =====
  Widget _buildDuasTab() {
    final cardBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;
    final subtextColor = _isDarkMode ? Colors.white70 : AppColors.navyBlue.withValues(alpha: 0.65);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: _duas.map((dua) {
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.menu_book_rounded, color: AppColors.midTeal, size: 18),
                  const SizedBox(width: 8),
                  Text(dua['title']!,
                      style: GoogleFonts.poppins(
                          fontSize: 13.5, fontWeight: FontWeight.bold, color: textColor)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                dua['arabic']!,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: _isDarkMode ? const Color(0xFF81C784) : AppColors.navyBlue,
                  height: 1.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(dua['translit']!,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: AppColors.midTeal,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(dua['meaning']!,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: subtextColor, height: 1.4)),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ===== SHARED WIDGETS =====
  Widget _buildProgressCard(int completed, int total, String label) {
    final double progress = total == 0 ? 0 : completed / total;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isDarkMode
              ? [const Color(0xFF1E2638), const Color(0xFF111827)]
              : [AppColors.navyBlue, const Color(0xFF1D3550)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.75))),
              Text('$completed / $total',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.coralOrange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistTile({
    required String label,
    required bool isDone,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    final cardBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isDone ? AppColors.midTeal : cardBg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDone ? AppColors.midTeal : (_isDarkMode ? Colors.white38 : AppColors.navyBlue.withValues(alpha: 0.25)),
                    width: 1.6,
                  ),
                ),
                child: isDone ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
              ),
              const SizedBox(width: 12),
              Icon(icon, size: 16, color: _isDarkMode ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.35)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: isDone
                        ? (_isDarkMode ? Colors.white38 : AppColors.navyBlue.withValues(alpha: 0.4))
                        : textColor,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}