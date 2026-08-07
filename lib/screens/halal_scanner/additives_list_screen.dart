import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/auth_header.dart';

// ---------------------------------------------------------------------------
// Shared colors (matches the app's teal / green / red / orange palette)
// ---------------------------------------------------------------------------

const Color kTeal = Color(0xFF55A498);          
const Color kHalalGreen = Color(0xFFC8E6C9);     // light green
const Color kHaramRed = Color(0xFFD4B896);       // balanced almond
const Color kMushboohOrange = Color(0xFFA9B7C6); // light slate grey
const Color kBg = Color(0xFFF6F7F8);
Color statusColorOf(String status) {
  switch (status) {
    case 'HALAL':
      return kHalalGreen;
    case 'HARAM':
      return kHaramRed;
    default:
      return kMushboohOrange;
  }
}

Color riskColorOf(String riskText) {
  switch (riskText) {
    case 'Very toxic':
      return const Color(0xFFE6483A);
    case 'Toxic':
      return const Color(0xFFF08A24);
    case 'Do not abuse':
      return const Color(0xFFB5B335);
    case 'Safe':
      return kHalalGreen;
    default:
      return Colors.grey;
  }
}

// ---------------------------------------------------------------------------
// Wraps a screen so it only ever looks like a real phone.
// - On an actual Android/iOS device (or any narrow window) the screen
//   width is already <= 480, so this widget does nothing and the screen
//   fills the device exactly like a normal app.
// - On a wide desktop window / web browser (e.g. `flutter run -d chrome`)
//   the content is centered at a fixed phone width instead of stretching
//   across the whole browser window.
// ---------------------------------------------------------------------------
class MobileFrame extends StatelessWidget {
  final Widget child;
  final bool isDarkMode;
  const MobileFrame({super.key, required this.child, this.isDarkMode = false});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    if (size.width <= 480) {
      return child;
    }
    return Container(
      color: isDarkMode ? const Color(0xFF0F1216) : const Color(0xFFE7E9EB),
      child: Center(
        child: Container(
          width: 430,
          height: size.height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class Additive {
  final String code;
  final String name;
  final String category; // 'Colour', 'Preservative', 'Emulsifier'...
  final String status; // 'HALAL', 'HARAM', 'MUSHBOOH'
  final String riskText; // 'Do not abuse', 'Very toxic', 'Toxic', 'Safe'
  final double riskScore; // 0.0 to 1.0
  final String origin; // 'animal', 'plant', 'chemical', 'insect'
  final List<String> flags; // 'EU', 'US', 'AU'
  final List<String> bannedFlags; // 'EU', 'US'
  final String description;
  final String? mushboohNote;
  final List<String> certifications; // 'VEGAN', 'JECFA'

  Additive({
    required this.code,
    required this.name,
    required this.category,
    required this.status,
    required this.riskText,
    required this.riskScore,
    required this.origin,
    required this.flags,
    this.bannedFlags = const [],
    this.description = '',
    this.mushboohNote,
    this.certifications = const [],
  });

  Additive copyWith({String? status}) {
    return Additive(
      code: code,
      name: name,
      category: category,
      status: status ?? this.status,
      riskText: riskText,
      riskScore: riskScore,
      origin: origin,
      flags: flags,
      bannedFlags: bannedFlags,
      description: description,
      mushboohNote: mushboohNote,
      certifications: certifications,
    );
  }
}

class AdditivesListScreen extends StatefulWidget {
  final bool isDarkMode;
  const AdditivesListScreen({super.key, this.isDarkMode = false});

  @override
  State<AdditivesListScreen> createState() => _AdditivesListScreenState();
}

class _AdditivesListScreenState extends State<AdditivesListScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _searchQuery = '';
  String _selectedFilter = 'All'; // 'All', 'Halal', 'Haram'

  // Master database of additives
  final List<Additive> _allAdditives = [
    Additive(
      code: 'E100',
      name: 'Curcumina',
      category: 'Colour',
      status: 'MUSHBOOH',
      riskText: 'Do not abuse',
      riskScore: 0.35,
      origin: 'animal',
      flags: ['EU', 'US', 'AU'],
      description:
          'Curcumin is a natural yellow-orange dye extracted from turmeric root. It is used as a colouring agent in food products such as mustard, cheese and confectionery.',
      mushboohNote:
          'This additive is Mushbooh. It is usually plant based, but the capsule or carrier used to stabilise it can sometimes contain gelatin, which would make it Haram.',
      certifications: ['JECFA'],
    ),
    Additive(
      code: 'E101',
      name: 'Riboflavin (Vitamin B2)',
      category: 'Colour',
      status: 'MUSHBOOH',
      riskText: 'Do not abuse',
      riskScore: 0.3,
      origin: 'animal',
      flags: ['EU', 'US', 'AU'],
      description:
          'Natural riboflavin is the vitamin B2 found in wheat bran, eggs, meat and milk, among other things. They are used as natural coloring agents in food products.\n\n'
          'These dyes are naturally produced in the liver, kidney, eggs, milk and vegetables. They can also be prepared industrially by the synthesis of certain yeasts. E101 gives food a yellow color, but its use is limited by its low solubility.',
      mushboohNote:
          'Go carefully with this additive, sometimes it can come from pig liver and kidney then it would be Haram. But sometimes it comes from vegetable places.',
      certifications: ['VEGAN', 'JECFA'],
    ),
    Additive(
      code: 'E102',
      name: 'Tartrazine',
      category: 'Colour',
      status: 'HALAL',
      riskText: 'Very toxic',
      riskScore: 0.8,
      origin: 'plant',
      flags: ['EU', 'US', 'AU'],
      description:
          'Tartrazine is a synthetic lemon-yellow azo dye used widely in soft drinks, sweets and snack foods. It is entirely plant/petrochemical derived, so it carries no animal-origin concerns.',
      certifications: ['VEGAN', 'JECFA'],
    ),
    Additive(
      code: 'E103',
      name: 'Chrysoine Resocinol',
      category: 'Colour',
      status: 'HALAL',
      riskText: 'Very toxic',
      riskScore: 0.85,
      origin: 'plant',
      flags: [],
      bannedFlags: ['EU', 'US', 'AU'],
      description:
          'Chrysoine Resocinol is a synthetic orange-yellow dye. It has been banned in most regions due to toxicity concerns, although it remains plant/chemical derived.',
      certifications: ['VEGAN'],
    ),
    Additive(
      code: 'E104',
      name: 'Quinoline Yellow',
      category: 'Colour',
      status: 'HALAL',
      riskText: 'Very toxic',
      riskScore: 0.75,
      origin: 'chemical',
      flags: ['EU', 'AU'],
      bannedFlags: ['US'],
      description:
          'Quinoline Yellow is a synthetic coal-tar derived dye used to colour drinks, sweets and medicines. It is fully synthetic with no animal origin.',
      certifications: ['VEGAN', 'JECFA'],
    ),
    Additive(
      code: 'E107',
      name: 'Yellow 2G',
      category: 'Colour',
      status: 'HALAL',
      riskText: 'Toxic',
      riskScore: 0.6,
      origin: 'chemical',
      flags: [],
      bannedFlags: ['EU', 'US', 'AU'],
      description:
          'Yellow 2G is a synthetic azo dye, now banned in most countries because of links to hyperactivity and allergic reactions. It is synthetic, not animal derived.',
      certifications: ['VEGAN'],
    ),
    Additive(
      code: 'E111',
      name: 'Orange GGN',
      category: 'Colour',
      status: 'HARAM',
      riskText: 'Very toxic',
      riskScore: 0.9,
      origin: 'chemical',
      flags: [],
      bannedFlags: ['EU', 'US', 'AU'],
      description:
          'Orange GGN is an obsolete synthetic dye, banned worldwide because of severe toxicity. It is no longer permitted in any food supply.',
    ),
    Additive(
      code: 'E120',
      name: 'Cochineal or Carminic Acid',
      category: 'Colour',
      status: 'HARAM',
      riskText: 'Toxic',
      riskScore: 0.65,
      origin: 'insect',
      flags: ['EU', 'US', 'AU'],
      description:
          'Cochineal (Carmine) is a red dye extracted by crushing dried female cochineal insects. Because it is derived from insects, its ruling is disputed among scholars and treated here as Haram.',
    ),
    Additive(
      code: 'E161I',
      name: 'Citranaxanthin',
      category: 'Colour',
      status: 'HARAM',
      riskText: 'Do not abuse',
      riskScore: 0.4,
      origin: 'chemical',
      flags: [],
      bannedFlags: ['EU', 'US', 'AU'],
      description:
          'Citranaxanthin is a synthetic carotenoid colourant, banned in most countries and classified as Haram in this listing due to unresolved sourcing concerns.',
    ),
    Additive(
      code: 'E161J',
      name: 'Astaxanthin',
      category: 'Colour',
      status: 'HARAM',
      riskText: 'Do not abuse',
      riskScore: 0.35,
      origin: 'chemical',
      flags: [],
      bannedFlags: ['EU', 'US', 'AU'],
      description:
          'Astaxanthin is a reddish-pink carotenoid pigment, often produced from algae or synthetically, but also sometimes from crustacean shells.',
    ),
    Additive(
      code: 'E428',
      name: 'Gelatin',
      category: 'Gelling agent',
      status: 'HARAM',
      riskText: 'Do not abuse',
      riskScore: 0.25,
      origin: 'animal',
      flags: ['EU', 'US', 'AU'],
      description:
          'Gelatin is a protein obtained by boiling skin, tendons, ligaments and/or bones with water, most commonly from pigs or cattle. Unless certified halal-slaughtered, it is treated as Haram.',
    ),
    Additive(
      code: 'E441',
      name: 'Superglycerinated hydrogenated rapeseed',
      category: 'Emulsifier',
      status: 'HARAM',
      riskText: 'Do not abuse',
      riskScore: 0.3,
      origin: 'chemical',
      flags: ['EU', 'US', 'AU'],
      description:
          'A modified rapeseed-oil emulsifier. It is classified Haram here because processing aids used in its manufacture cannot always be verified as animal-free.',
    ),
    Additive(
      code: 'E471',
      name: 'Mono- and diglycerides of fatty acids',
      category: 'Emulsifier',
      status: 'MUSHBOOH',
      riskText: 'Safe',
      riskScore: 0.1,
      origin: 'animal',
      flags: ['EU', 'US', 'AU'],
      description:
          'E471 is an emulsifier used in breads, margarine and desserts. It can be produced from either plant oils or animal fat.',
      mushboohNote:
          'This additive is Mushbooh. The fatty acids can come from vegetable oil (Halal) or animal fat (Haram depending on the animal and slaughter method), so the source cannot always be confirmed.',
      certifications: ['JECFA'],
    ),
  ];

  List<Additive> get _filteredAdditives {
    return _allAdditives.where((additive) {
      // Filter by status
      if (_selectedFilter == 'Halal' && additive.status != 'HALAL') return false;
      if (_selectedFilter == 'Haram' && additive.status != 'HARAM') return false;

      // Filter by search query
      final query = _searchQuery.toLowerCase().trim();
      if (query.isEmpty) return true;

      return additive.code.toLowerCase().contains(query) ||
          additive.name.toLowerCase().contains(query);
    }).toList();
  }

  void _openDetail(Additive additive) async {
    final updated = await Navigator.push<Additive>(
      context,
      MaterialPageRoute(builder: (context) => AdditiveDetailScreen(additive: additive, isDarkMode: widget.isDarkMode)),
    );
    if (updated != null) {
      setState(() {
        final index = _allAdditives.indexWhere((a) => a.code == updated.code);
        if (index != -1) _allAdditives[index] = updated;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredAdditives;

    return MobileFrame(
      isDarkMode: widget.isDarkMode,
      child: Scaffold(
      key: _scaffoldKey,
      backgroundColor: widget.isDarkMode ? const Color(0xFF121212) : kBg,
      appBar: AppBar(
        backgroundColor: kTeal,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'List additives',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: widget.isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Search additives (E100, E471...)',
                  hintStyle: TextStyle(color: Colors.grey),
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),

          // Filters Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${list.length} additives',
                  style: TextStyle(color: widget.isDarkMode ? Colors.white70 : Colors.grey[700], fontWeight: FontWeight.w600, fontSize: 15),
                ),
                Row(
                  children: [
                    _buildFilterChip('All', kTeal),
                    const SizedBox(width: 10),
                    _buildFilterChip('Halal', kHalalGreen),
                    const SizedBox(width: 10),
                    _buildFilterChip('Haram', kHaramRed),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Additives List
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final additive = list[index];
                return _buildAdditiveCard(additive);
              },
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildFilterChip(String label, Color activeColor) {
    final bool isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (label == 'All' ? (widget.isDarkMode ? Colors.white70 : Colors.grey[600]) : activeColor),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildAdditiveCard(Additive additive) {
    final badgeColor = statusColorOf(additive.status);
    final riskColor = riskColorOf(additive.riskText);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: widget.isDarkMode ? Colors.white.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.08)),
      ),
      child: InkWell(
        onTap: () => _openDetail(additive),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: E-code + flags stacked
              SizedBox(
                width: 66,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Text(
                       additive.code,
                       style: TextStyle(
                         fontSize: 19,
                         fontWeight: FontWeight.bold,
                         color: widget.isDarkMode ? Colors.white : Colors.black87,
                       ),
                     ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 0,
                      runSpacing: 3,
                      children: [
                        ...additive.flags.map((f) => _buildFlagIcon(f, false)),
                        ...additive.bannedFlags.map((f) => _buildFlagIcon(f, true)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Middle: name + risk row
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Text(
                       additive.name,
                       style: TextStyle(
                         fontSize: 16,
                         fontWeight: FontWeight.w500,
                         color: widget.isDarkMode ? Colors.white : Colors.black87,
                         height: 1.2,
                       ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildRiskGauge(),
                        const SizedBox(width: 6),
                        Text(
                          additive.riskText,
                          style: TextStyle(
                            fontSize: 13,
                            color: riskColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Right: status badge + origin icon
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      additive.status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  CustomPaint(
                    size: const Size(32, 32),
                    painter: OriginPainter(origin: additive.origin),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlagIcon(String flagCode, bool isBanned) {
    return Container(
      margin: const EdgeInsets.only(right: 3, bottom: 3),
      width: 17,
      height: 13,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: widget.isDarkMode ? Colors.white.withValues(alpha: 0.2) : Colors.grey[300]!, width: 0.5),
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              flagCode == 'EU' ? '🇪🇺' : flagCode == 'US' ? '🇺🇸' : '🇦🇺',
              style: const TextStyle(fontSize: 9),
            ),
          ),
          if (isBanned)
            Container(
              color: Colors.red.withValues(alpha: 0.45),
              child: const Center(
                child: Icon(
                  Icons.block_flipped,
                  color: Colors.white,
                  size: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRiskGauge() {
    return SizedBox(
      width: 24,
      height: 13,
      child: CustomPaint(painter: RainbowGaugePainter()),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail screen — full page matching the reference design
// ---------------------------------------------------------------------------
class AdditiveDetailScreen extends StatefulWidget {
  final Additive additive;
  final bool isDarkMode;
  const AdditiveDetailScreen({super.key, required this.additive, this.isDarkMode = false});

  @override
  State<AdditiveDetailScreen> createState() => _AdditiveDetailScreenState();
}

class _AdditiveDetailScreenState extends State<AdditiveDetailScreen> {
  late Additive _additive;

  @override
  void initState() {
    super.initState();
    _additive = widget.additive;
  }

  void _showOverrideDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String currentStatus = _additive.status;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final color = statusColorOf(currentStatus);
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_additive.code, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      currentStatus,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_additive.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Text('Customize status for your country:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatusButton(
                        label: 'Halal',
                        color: kHalalGreen,
                        isActive: currentStatus == 'HALAL',
                        onTap: () => setDialogState(() => currentStatus = 'HALAL'),
                      ),
                      _buildStatusButton(
                        label: 'Haram',
                        color: kHaramRed,
                        isActive: currentStatus == 'HARAM',
                        onTap: () => setDialogState(() => currentStatus = 'HARAM'),
                      ),
                      _buildStatusButton(
                        label: 'Mushbooh',
                        color: kMushboohOrange,
                        isActive: currentStatus == 'MUSHBOOH',
                        onTap: () => setDialogState(() => currentStatus = 'MUSHBOOH'),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTeal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    setState(() {
                      _additive = _additive.copyWith(status: currentStatus);
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Status of ${_additive.code} updated to $currentStatus!')),
                    );
                  },
                  child: const Text('Save Override', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatusButton({
    required String label,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = statusColorOf(_additive.status);
    final riskColor = riskColorOf(_additive.riskText);

    return MobileFrame(
      child: WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _additive);
        return false;
      },
      child: Scaffold(
        backgroundColor: widget.isDarkMode ? const Color(0xFF121212) : Colors.white,
        appBar: AppBar(
          backgroundColor: kTeal,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context, _additive),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _additive.name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                _additive.code,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.4),
                ),
                child: const Icon(Icons.compare_arrows, color: Colors.white, size: 18),
              ),
              onPressed: _showOverrideDialog,
              tooltip: 'Customize status',
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status banner
              Container(
                width: double.infinity,
                color: statusColor,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _additive.status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 14),
                    CustomPaint(
                      size: const Size(30, 30),
                      painter: OriginPainter(origin: _additive.origin),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  children: [
                    Text(
                      _additive.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A6CF7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _additive.category,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFFD6499B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                     Text(
                       _additive.description,
                       textAlign: TextAlign.left,
                       style: TextStyle(fontSize: 15, color: widget.isDarkMode ? Colors.white : Colors.black87, height: 1.5),
                     ),

                    if (_additive.mushboohNote != null) ...[
                      const SizedBox(height: 18),
                       Text(
                         'This additive is ${_additive.status == 'MUSHBOOH' ? 'Mushbooh' : _additive.status[0]}${_additive.status.substring(1).toLowerCase()},',
                         style: TextStyle(fontSize: 15, color: widget.isDarkMode ? Colors.white : Colors.black87, height: 1.5),
                       ),
                       Text(
                         _additive.mushboohNote!,
                         style: TextStyle(fontSize: 15, color: widget.isDarkMode ? Colors.white : Colors.black87, height: 1.5),
                       ),
                    ],

                    if (_additive.certifications.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final cert in _additive.certifications) ...[
                            _buildCertBadge(cert),
                            const SizedBox(width: 12),
                          ],
                        ],
                      ),
                    ],

                    const SizedBox(height: 26),

                    // Flags approval rows
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildApprovalRow('EU', 'Approved in European Union',
                                approved: _additive.flags.contains('EU')),
                            const SizedBox(height: 10),
                            _buildRiskRow(riskColor),
                            const SizedBox(height: 10),
                            _buildApprovalRow('US', 'Approved in United States',
                                approved: _additive.flags.contains('US')),
                            const SizedBox(height: 10),
                            _buildApprovalRow('AU', 'Approved in Australia and New Zealand',
                                approved: _additive.flags.contains('AU')),
                          ],
                        ),
                      ],
                    ),
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

  Widget _buildRiskRow(Color riskColor) {
    return Row(
      children: [
        SizedBox(width: 26, height: 15, child: CustomPaint(painter: RainbowGaugePainter())),
        const SizedBox(width: 12),
        Text(
          _additive.riskText,
          style: TextStyle(fontSize: 14, color: riskColor, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildApprovalRow(String flagCode, String label, {required bool approved}) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.grey[300]!, width: 0.5),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                flagCode,
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.navyBlue),
              ),
              if (!approved)
                Container(
                  color: Colors.red.withValues(alpha: 0.45),
                  child: const Icon(Icons.block_flipped, color: Colors.white, size: 13),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(fontSize: 14, color: widget.isDarkMode ? Colors.white : Colors.black87)),
      ],
    );
  }

  Widget _buildCertBadge(String type) {
    final isVegan = type == 'VEGAN';
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: isVegan ? const Color(0xFFE9573F) : const Color(0xFF43B77B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isVegan ? Icons.eco : Icons.verified, color: Colors.white, size: 18),
          const SizedBox(height: 2),
          Text(
            type,
            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rainbow risk-meter icon (green -> yellow -> orange -> red arc)
// ---------------------------------------------------------------------------
class RainbowGaugePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 1.5;
    const colors = [
      Color(0xFF43B77B),
      Color(0xFFD8D93A),
      Color(0xFFF08A24),
      Color(0xFFE6483A),
    ];

    final sweepEach = 3.1415926 / colors.length;
    for (int i = 0; i < colors.length; i++) {
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        3.1415926 + sweepEach * i,
        sweepEach,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Legacy single-color speedometer gauge — kept for backward compatibility
// with other screens in the project (e.g. product_detail_screen.dart) that
// still reference GaugeArcPainter directly.
// ---------------------------------------------------------------------------
class GaugeArcPainter extends CustomPainter {
  final double score;
  final Color color;

  GaugeArcPainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[200]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.1415,
      3.1415,
      false,
      paint,
    );

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.1415,
      3.1415 * score,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ---------------------------------------------------------------------------
// Custom Origin Painter for drawing Pig, Leaf, Chemical Beaker, Bug
// ---------------------------------------------------------------------------
class OriginPainter extends CustomPainter {
  final String origin;

  OriginPainter({required this.origin});

  @override
  void paint(Canvas canvas, Size size) {
    if (origin == 'plant') {
      _paintLeaf(canvas, size);
    } else if (origin == 'animal') {
      _paintPig(canvas, size);
    } else if (origin == 'chemical') {
      _paintBeaker(canvas, size);
    } else if (origin == 'insect') {
      _paintBug(canvas, size);
    }
  }

  void _paintLeaf(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green[400]!
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width / 2, size.height * 0.1);
    path.quadraticBezierTo(
      size.width * 0.9,
      size.height * 0.2,
      size.width * 0.8,
      size.height * 0.7,
    );
    path.quadraticBezierTo(
      size.width * 0.6,
      size.height * 0.9,
      size.width / 2,
      size.height * 0.9,
    );
    path.quadraticBezierTo(
      size.width * 0.4,
      size.height * 0.9,
      size.width * 0.2,
      size.height * 0.7,
    );
    path.quadraticBezierTo(
      size.width * 0.1,
      size.height * 0.2,
      size.width / 2,
      size.height * 0.1,
    );
    canvas.drawPath(path, paint);

    final stemPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.width / 2, size.height * 0.9),
      Offset(size.width / 2, size.height * 0.2),
      stemPaint,
    );
  }

  void _paintPig(Canvas canvas, Size size) {
    final bodyPaint = Paint()
      ..color = Colors.pink[100]!
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = Colors.pink[400]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.15, size.height * 0.25, size.width * 0.7, size.height * 0.55),
      bodyPaint,
    );
    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.15, size.height * 0.25, size.width * 0.7, size.height * 0.55),
      linePaint,
    );

    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.35, size.height * 0.45, size.width * 0.3, size.height * 0.22),
      Paint()..color = Colors.pink[200]!,
    );
    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.35, size.height * 0.45, size.width * 0.3, size.height * 0.22),
      linePaint,
    );
    canvas.drawCircle(Offset(size.width * 0.45, size.height * 0.56), 1.5, Paint()..color = Colors.pink[400]!);
    canvas.drawCircle(Offset(size.width * 0.55, size.height * 0.56), 1.5, Paint()..color = Colors.pink[400]!);

    canvas.drawCircle(Offset(size.width * 0.35, size.height * 0.4), 1.5, Paint()..color = Colors.black);
    canvas.drawCircle(Offset(size.width * 0.65, size.height * 0.4), 1.5, Paint()..color = Colors.black);

    final earPath1 = Path();
    earPath1.moveTo(size.width * 0.25, size.height * 0.3);
    earPath1.lineTo(size.width * 0.2, size.height * 0.15);
    earPath1.lineTo(size.width * 0.38, size.height * 0.25);
    earPath1.close();
    canvas.drawPath(earPath1, bodyPaint);
    canvas.drawPath(earPath1, linePaint);

    final earPath2 = Path();
    earPath2.moveTo(size.width * 0.75, size.height * 0.3);
    earPath2.lineTo(size.width * 0.8, size.height * 0.15);
    earPath2.lineTo(size.width * 0.62, size.height * 0.25);
    earPath2.close();
    canvas.drawPath(earPath2, bodyPaint);
    canvas.drawPath(earPath2, linePaint);
  }

  void _paintBeaker(Canvas canvas, Size size) {
    final flaskPaint = Paint()
      ..color = Colors.blue[300]!
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = Colors.blue[700]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    path.moveTo(size.width * 0.4, size.height * 0.15);
    path.lineTo(size.width * 0.6, size.height * 0.15);
    path.lineTo(size.width * 0.6, size.height * 0.45);
    path.lineTo(size.width * 0.85, size.height * 0.85);
    path.lineTo(size.width * 0.15, size.height * 0.85);
    path.lineTo(size.width * 0.4, size.height * 0.45);
    path.close();

    canvas.drawPath(path, flaskPaint);
    canvas.drawPath(path, linePaint);

    final bubblePaint = Paint()..color = Colors.white.withValues(alpha: 0.6);
    canvas.drawCircle(Offset(size.width * 0.35, size.height * 0.75), 2.5, bubblePaint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.65), 1.5, bubblePaint);
    canvas.drawCircle(Offset(size.width * 0.6, size.height * 0.78), 2.0, bubblePaint);
  }

  void _paintBug(Canvas canvas, Size size) {
    final bodyPaint = Paint()
      ..color = Colors.red[400]!
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final blackPaint = Paint()..color = Colors.black87;

    canvas.drawCircle(Offset(size.width / 2, size.height * 0.22), size.width * 0.13, blackPaint);

    canvas.drawCircle(Offset(size.width / 2, size.height * 0.58), size.width * 0.3, bodyPaint);
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.58), size.width * 0.3, linePaint);

    canvas.drawLine(
      Offset(size.width / 2, size.height * 0.28),
      Offset(size.width / 2, size.height * 0.88),
      linePaint,
    );

    canvas.drawCircle(Offset(size.width * 0.35, size.height * 0.48), 2, blackPaint);
    canvas.drawCircle(Offset(size.width * 0.65, size.height * 0.48), 2, blackPaint);
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.65), 2, blackPaint);
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.65), 2, blackPaint);

    canvas.drawLine(Offset(size.width * 0.45, size.height * 0.12), Offset(size.width * 0.38, size.height * 0.05), linePaint);
    canvas.drawLine(Offset(size.width * 0.55, size.height * 0.12), Offset(size.width * 0.62, size.height * 0.05), linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}