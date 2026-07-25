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
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _mode = 'Hajj'; // 'Hajj' or 'Umrah'
  bool _isDarkMode = false;

  final Map<String, bool> _hajjRitualDone = {};
  final Map<String, bool> _umrahRitualDone = {};
  final Map<String, bool> _packingDone = {};
  final Map<String, bool> _documentsDone = {};

  // ===== ROAD-FILL ANIMATION CONTROLLERS =====
  // One controller per "segment" of the dotted road (segment i connects
  // stop i to stop i+1). When stop i is marked done, its segment animates
  // from 0 -> 1, filling in with a soft green glow as if the road lit up
  // on the way to the next stop.
  final Map<String, AnimationController> _segmentControllers = {};
  final Map<String, Animation<double>> _segmentAnimations = {};

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

  // ===== STEP ILLUSTRATIONS (used as the "stops" on the ritual road) =====
  final Map<String, String> _hajjStepImages = {
    'ihram': 'assets/images/hajj_umrah/2.png',
    'tawaf_qudum': 'assets/images/hajj_umrah/1.png',
    'mina1': 'assets/images/hajj_umrah/6.png',
    'arafat': 'assets/images/hajj_umrah/8.png',
    'muzdalifah': 'assets/images/hajj_umrah/9.png',
    'rami1': 'assets/images/hajj_umrah/5.png',
    'qurbani': 'assets/images/hajj_umrah/10.png',
    'tawaf_ifadah': 'assets/images/hajj_umrah/4.png',
    'rami_days': 'assets/images/hajj_umrah/11.png',
    'tawaf_wida': 'assets/images/hajj_umrah/1.png',
  };

  final Map<String, String> _umrahStepImages = {
    'ihram_u': 'assets/images/hajj_umrah/2.png',
    'tawaf_u': 'assets/images/hajj_umrah/1.png',
    'sai_u': 'assets/images/hajj_umrah/6.png',
    'halq_u': 'assets/images/hajj_umrah/7.png',
  };

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
    _initSegmentControllers();
    _loadState();
  }

  // Creates one AnimationController (+ eased Animation) per road segment,
  // for both Hajj and Umrah, up front so mode-switching is instant.
  void _initSegmentControllers() {
    for (int i = 0; i < _hajjSteps.length - 1; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 750),
      );
      _segmentControllers['hajj_$i'] = controller;
      _segmentAnimations['hajj_$i'] =
          CurvedAnimation(parent: controller, curve: Curves.easeOutCubic);
    }
    for (int i = 0; i < _umrahSteps.length - 1; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 750),
      );
      _segmentControllers['umrah_$i'] = controller;
      _segmentAnimations['umrah_$i'] =
          CurvedAnimation(parent: controller, curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final controller in _segmentControllers.values) {
      controller.dispose();
    }
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

      // Set the road-fill controllers to their resting state (no animation)
      // to match whatever was already completed before this session.
      for (int i = 0; i < _hajjSteps.length - 1; i++) {
        final done = _hajjRitualDone[_hajjSteps[i]['id']] ?? false;
        _segmentControllers['hajj_$i']?.value = done ? 1.0 : 0.0;
      }
      for (int i = 0; i < _umrahSteps.length - 1; i++) {
        final done = _umrahRitualDone[_umrahSteps[i]['id']] ?? false;
        _segmentControllers['umrah_$i']?.value = done ? 1.0 : 0.0;
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

  // ===== RITUALS TAB — "road / journey" layout =====
  // A dotted path winds down the screen, alternating left/right. Each stop is
  // a circular photo (the ritual illustration) with its step number badge,
  // and the info card next to it carries the title + a "guideline" line
  // underneath describing what to do for that day/step. When a stop is
  // tapped done, the road segment leading to the next stop softly fills
  // in with green.
  Widget _buildRitualsTab() {
    final steps = _mode == 'Hajj' ? _hajjSteps : _umrahSteps;
    final doneMap = _mode == 'Hajj' ? _hajjRitualDone : _umrahRitualDone;
    final prefix = _mode == 'Hajj' ? 'hajj_' : 'umrah_';
    final segKeyPrefix = _mode == 'Hajj' ? 'hajj' : 'umrah';
    final images = _mode == 'Hajj' ? _hajjStepImages : _umrahStepImages;
    final completed = doneMap.values.where((v) => v).length;
    final cardBg = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;
    final subtextColor = _isDarkMode ? Colors.white70 : AppColors.navyBlue.withValues(alpha: 0.6);
    final pathColor = _isDarkMode ? Colors.white24 : AppColors.navyBlue.withValues(alpha: 0.28);

    const double rowHeight = 208;
    const double nodeSize = 64;
    const double sidePad = 16;
    // Extra breathing room between the progress card above and the first
    // ritual stop, so "Enter Ihram" isn't crammed right under the card.
    const double topOffset = 36;

    return ListView(
      key: ValueKey('rituals_$_mode'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _buildProgressCard(completed, steps.length, '$_mode Progress'),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final totalHeight = rowHeight * steps.length + nodeSize + topOffset;

            // Pre-compute the centre of every "stop" on the road, zig-zagging
            // left/right so the dotted line snakes down the page.
            final centers = List.generate(steps.length, (i) {
              final isLeft = i.isEven;
              final cx = isLeft ? sidePad + nodeSize / 2 : width - sidePad - nodeSize / 2;
              final cy = topOffset + nodeSize / 2 + rowHeight * i;
              return Offset(cx, cy);
            });

            final segmentAnimations = List.generate(
              steps.length - 1,
              (i) => _segmentAnimations['${segKeyPrefix}_$i']!,
            );

            return SizedBox(
              width: width,
              height: totalHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // dotted road + animated green fill on completion
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: Listenable.merge(segmentAnimations),
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _JourneyPathPainter(
                            points: centers,
                            progresses: segmentAnimations.map((a) => a.value).toList(),
                            baseColor: pathColor,
                            glowColor: AppColors.midTeal,
                          ),
                        );
                      },
                    ),
                  ),
                  for (int i = 0; i < steps.length; i++) ...[
                    _buildJourneyNode(
                      center: centers[i],
                      nodeSize: nodeSize,
                      imagePath: images[steps[i]['id']],
                      isDone: doneMap[steps[i]['id']] ?? false,
                      // Locked = not done AND the previous step isn't done yet.
                      isLocked: i > 0 &&
                          !(doneMap[steps[i]['id']] ?? false) &&
                          !(doneMap[steps[i - 1]['id']] ?? false),
                      stepNumber: i + 1,
                      cardBg: cardBg,
                      onTap: () {
                        final id = steps[i]['id']!;
                        final alreadyDone = doneMap[id] ?? false;

                        if (!alreadyDone) {
                          // Completing this step requires the previous one done first.
                          if (i > 0) {
                            final prevDone = doneMap[steps[i - 1]['id']!] ?? false;
                            if (!prevDone) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Complete "${steps[i - 1]['title']}" first'),
                                  duration: const Duration(seconds: 2),
                                  backgroundColor: AppColors.coralOrange,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }
                          }
                        } else {
                          // Un-checking requires the next step to not be done.
                          if (i < steps.length - 1) {
                            final nextDone = doneMap[steps[i + 1]['id']!] ?? false;
                            if (nextDone) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Uncheck "${steps[i + 1]['title']}" first'),
                                  duration: const Duration(seconds: 2),
                                  backgroundColor: AppColors.coralOrange,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }
                          }
                        }

                        final newVal = !alreadyDone;
                        setState(() => doneMap[id] = newVal);
                        _saveBool('$prefix$id', newVal);

                        // Animate the road segment leading to the next stop.
                        if (i < steps.length - 1) {
                          final controller = _segmentControllers['${segKeyPrefix}_$i'];
                          if (controller != null) {
                            if (newVal) {
                              controller.forward();
                            } else {
                              controller.reverse();
                            }
                          }
                        }
                      },
                    ),
                    _buildJourneyCard(
                      center: centers[i],
                      isLeft: i.isEven,
                      width: width,
                      nodeSize: nodeSize,
                      sidePad: sidePad,
                      title: steps[i]['title']!,
                      guideline: steps[i]['desc']!,
                      isDone: doneMap[steps[i]['id']] ?? false,
                      cardBg: cardBg,
                      textColor: textColor,
                      subtextColor: subtextColor,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // A single circular "stop" photo sitting on the dotted road.
  Widget _buildJourneyNode({
    required Offset center,
    required double nodeSize,
    required String? imagePath,
    required bool isDone,
    required bool isLocked,
    required int stepNumber,
    required Color cardBg,
    required VoidCallback onTap,
  }) {
    return Positioned(
      left: center.dx - nodeSize / 2,
      top: center.dy - nodeSize / 2,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Opacity(
              opacity: isLocked ? 0.5 : 1.0,
              child: Container(
                width: nodeSize,
                height: nodeSize,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cardBg,
                  border: Border.all(
                    color: isDone
                        ? AppColors.midTeal
                        : (_isDarkMode ? Colors.white24 : AppColors.navyBlue.withValues(alpha: 0.2)),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: ClipOval(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      imagePath != null
                          ? Image.asset(
                              imagePath,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) => Container(
                                color: AppColors.navyBlue.withValues(alpha: 0.08),
                                child: const Icon(Icons.mosque_rounded, color: AppColors.navyBlue),
                              ),
                            )
                          : Container(
                              color: AppColors.navyBlue.withValues(alpha: 0.08),
                              child: const Icon(Icons.mosque_rounded, color: AppColors.navyBlue),
                            ),
                      if (isDone)
                        Container(
                          color: AppColors.midTeal.withValues(alpha: 0.55),
                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 26),
                        ),
                      if (isLocked)
                        Container(
                          color: Colors.black.withValues(alpha: 0.35),
                          child: const Icon(Icons.lock_rounded, color: Colors.white, size: 20),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // step number badge
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone ? AppColors.midTeal : AppColors.coralOrange,
                  border: Border.all(color: cardBg, width: 2),
                ),
                child: Center(
                  child: Text('$stepNumber',
                      style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // The info card next to a stop: title on top, the "guideline" (what to do)
  // underneath it, exactly like a caption below each day's stop on the road.
  Widget _buildJourneyCard({
    required Offset center,
    required bool isLeft,
    required double width,
    required double nodeSize,
    required double sidePad,
    required String title,
    required String guideline,
    required bool isDone,
    required Color cardBg,
    required Color textColor,
    required Color subtextColor,
  }) {
    final cardWidth = width - nodeSize - sidePad * 2 - 16;
    final left = isLeft ? (sidePad + nodeSize + 12) : sidePad;

    return Positioned(
      left: left,
      top: center.dy - 54,
      width: cardWidth,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDone ? AppColors.midTeal.withValues(alpha: 0.4) : (_isDarkMode ? Colors.white.withOpacity(0.08) : Colors.transparent),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: isDone ? AppColors.midTeal : textColor,
                decoration: isDone ? TextDecoration.lineThrough : null,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 1,
              color: (_isDarkMode ? Colors.white : AppColors.navyBlue).withValues(alpha: 0.08),
            ),
            const SizedBox(height: 6),
            // ----- Guideline, shown below the step -----
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 12, color: AppColors.midTeal),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    guideline,
                    style: GoogleFonts.inter(fontSize: 10.5, color: subtextColor, height: 1.35),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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

// Draws the winding "road" between ritual stops: a subtle dashed base path,
// plus — for each segment whose stop has been marked done — a soft, glowing
// green fill that animates in from the completed stop toward the next one.
//
// NOTE: the animated portion is drawn by manually sampling the same cubic
// bezier used for the base road (instead of relying on
// Path.computeMetrics().extractPath), because extractPath on a freshly
// built Path can behave inconsistently across engine versions when the
// path length is recomputed every frame. Manual sampling is simple,
// deterministic, and guaranteed to render every frame.
class _JourneyPathPainter extends CustomPainter {
  final List<Offset> points;
  final List<double> progresses;
  final Color baseColor;
  final Color glowColor;

  static const Color _brightGreen = Color(0xFF6FE6A8);

  _JourneyPathPainter({
    required this.points,
    required this.progresses,
    required this.baseColor,
    required this.glowColor,
  });

  Offset _cubicPoint(Offset p0, Offset c0, Offset c1, Offset p1, double t) {
    final u = 1 - t;
    final tt = t * t;
    final uu = u * u;
    final uuu = uu * u;
    final ttt = tt * t;
    final x = uuu * p0.dx + 3 * uu * t * c0.dx + 3 * u * tt * c1.dx + ttt * p1.dx;
    final y = uuu * p0.dy + 3 * uu * t * c0.dy + 3 * u * tt * c1.dy + ttt * p1.dy;
    return Offset(x, y);
  }

  Path _partialCubic(Offset p0, Offset p1, double progress, {int steps = 28}) {
    final midY = (p0.dy + p1.dy) / 2;
    final c0 = Offset(p0.dx, midY);
    final c1 = Offset(p1.dx, midY);
    final path = Path()..moveTo(p0.dx, p0.dy);
    final segCount = (steps * progress).ceil().clamp(1, steps);
    for (int s = 1; s <= segCount; s++) {
      final t = (s / steps).clamp(0.0, progress);
      final pt = _cubicPoint(p0, c0, c1, p1, t);
      path.lineTo(pt.dx, pt.dy);
    }
    return path;
  }

  // Finely-sampled polyline for the partial (animated) curve — used to walk
  // a fixed dash length along the curve regardless of its overall length.
  List<Offset> _partialCubicPoints(Offset p0, Offset p1, double progress, {int steps = 80}) {
    final midY = (p0.dy + p1.dy) / 2;
    final c0 = Offset(p0.dx, midY);
    final c1 = Offset(p1.dx, midY);
    final segCount = (steps * progress).ceil().clamp(1, steps);
    final pts = <Offset>[p0];
    for (int s = 1; s <= segCount; s++) {
      final t = (s / steps).clamp(0.0, progress);
      pts.add(_cubicPoint(p0, c0, c1, p1, t));
    }
    return pts;
  }

  // Walks a polyline (a sequence of short straight sub-segments approximating
  // a curve) and draws short dash strokes with gaps in between, matching the
  // look of the dashed base road but in the glowing green. `distanceIntoPattern`
  // tracks total distance travelled so the dash/gap rhythm stays continuous
  // across the whole polyline instead of resetting per sub-segment.
  void _drawDashedPolyline(
    Canvas canvas,
    List<Offset> pts,
    Paint paint, {
    double dashWidth = 6,
    double dashSpace = 7,
  }) {
    if (pts.length < 2) return;
    final cycle = dashWidth + dashSpace;
    double distanceIntoPattern = 0;

    for (int i = 0; i < pts.length - 1; i++) {
      final segStart = pts[i];
      final segEnd = pts[i + 1];
      final segLength = (segEnd - segStart).distance;
      if (segLength == 0) continue;

      double travelled = 0;
      while (travelled < segLength) {
        final posInCycle = distanceIntoPattern % cycle;
        final isDash = posInCycle < dashWidth;
        final remainInPhase = isDash ? (dashWidth - posInCycle) : (cycle - posInCycle);
        final stepLength = (segLength - travelled) < remainInPhase
            ? (segLength - travelled)
            : remainInPhase;

        final tStart = travelled / segLength;
        final tEnd = (travelled + stepLength) / segLength;
        final a = Offset.lerp(segStart, segEnd, tStart)!;
        final b = Offset.lerp(segStart, segEnd, tEnd)!;

        if (isDash) {
          canvas.drawLine(a, b, paint);
        }

        travelled += stepLength;
        distanceIntoPattern += stepLength;
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    // ---- base dotted road, always visible underneath ----
    final fullPath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final midY = (p0.dy + p1.dy) / 2;
      fullPath.cubicTo(p0.dx, midY, p1.dx, midY, p1.dx, p1.dy);
    }

    final dashPaint = Paint()
      ..color = baseColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const double dashWidth = 6;
    const double dashSpace = 7;

    for (final metric in fullPath.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          dashPaint,
        );
        distance += dashWidth + dashSpace;
      }
    }

    // ---- animated soft-green fill, one segment per completed stop ----
    for (int i = 0; i < points.length - 1; i++) {
      final progress = i < progresses.length ? progresses[i] : 0.0;
      if (progress <= 0.001) continue;

      final p0 = points[i];
      final p1 = points[i + 1];
      final extracted = _partialCubic(p0, p1, progress);
      final sampledPts = _partialCubicPoints(p0, p1, progress);

      // wide soft outer halo — kept continuous (not dashed) so the glow
      // still reads as one smooth soft wash of light along the path
      final haloPaint = Paint()
        ..color = _brightGreen.withValues(alpha: 0.20)
        ..strokeWidth = 20
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawPath(extracted, haloPaint);

      // mid glow — also continuous, sits behind the dashes
      final glowPaint = Paint()
        ..color = glowColor.withValues(alpha: 0.45)
        ..strokeWidth = 10
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawPath(extracted, glowPaint);

      // crisp bright DOTTED core line — same dash rhythm as the base road
      final corePaint = Paint()
        ..color = _brightGreen
        ..strokeWidth = 4.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      _drawDashedPolyline(canvas, sampledPts, corePaint, dashWidth: 7, dashSpace: 6);

      // glowing "leading" dot while the fill is still travelling
      if (progress < 1.0 && progress > 0.02) {
        final midY = (p0.dy + p1.dy) / 2;
        final leadPoint = _cubicPoint(p0, Offset(p0.dx, midY), Offset(p1.dx, midY), p1, progress);
        canvas.drawCircle(
          leadPoint,
          11,
          Paint()
            ..color = _brightGreen.withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
        canvas.drawCircle(leadPoint, 5.5, Paint()..color = _brightGreen);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _JourneyPathPainter oldDelegate) => true;
}