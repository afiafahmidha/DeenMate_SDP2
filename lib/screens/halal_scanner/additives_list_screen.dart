import 'package:flutter/material.dart';
import 'halal_drawer.dart';

class Additive {
  final String code;
  final String name;
  final String status; // 'HALAL', 'HARAM', 'MUSHBOOH'
  final String riskText; // 'Do not abuse', 'Very toxic', 'Toxic', 'Safe'
  final double riskScore; // 0.0 to 1.0
  final String origin; // 'animal', 'plant', 'chemical', 'insect'
  final List<String> flags; // 'EU', 'US', 'AU'
  final List<String> bannedFlags; // 'EU', 'US'

  Additive({
    required this.code,
    required this.name,
    required this.status,
    required this.riskText,
    required this.riskScore,
    required this.origin,
    required this.flags,
    this.bannedFlags = const [],
  });
}

class AdditivesListScreen extends StatefulWidget {
  const AdditivesListScreen({super.key});

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
      status: 'MUSHBOOH',
      riskText: 'Do not abuse',
      riskScore: 0.35,
      origin: 'animal',
      flags: ['EU', 'US', 'AU'],
    ),
    Additive(
      code: 'E101',
      name: 'Riboflavin (Vitamin B2)',
      status: 'MUSHBOOH',
      riskText: 'Do not abuse',
      riskScore: 0.3,
      origin: 'animal',
      flags: ['EU', 'US', 'AU'],
    ),
    Additive(
      code: 'E102',
      name: 'Tartrazine',
      status: 'HALAL',
      riskText: 'Very toxic',
      riskScore: 0.8,
      origin: 'plant',
      flags: ['EU', 'US', 'AU'],
    ),
    Additive(
      code: 'E103',
      name: 'Chrysoine Resocinol',
      status: 'HALAL',
      riskText: 'Very toxic',
      riskScore: 0.85,
      origin: 'plant',
      flags: [],
      bannedFlags: ['EU', 'US', 'AU'],
    ),
    Additive(
      code: 'E104',
      name: 'Quinoline Yellow',
      status: 'HALAL',
      riskText: 'Very toxic',
      riskScore: 0.75,
      origin: 'chemical',
      flags: ['EU', 'AU'],
      bannedFlags: ['US'],
    ),
    Additive(
      code: 'E107',
      name: 'Yellow 2G',
      status: 'HALAL',
      riskText: 'Toxic',
      riskScore: 0.6,
      origin: 'chemical',
      flags: [],
      bannedFlags: ['EU', 'US', 'AU'],
    ),
    Additive(
      code: 'E111',
      name: 'Orange GGN',
      status: 'HARAM',
      riskText: 'Very toxic',
      riskScore: 0.9,
      origin: 'chemical',
      flags: [],
      bannedFlags: ['EU', 'US', 'AU'],
    ),
    Additive(
      code: 'E120',
      name: 'Cochineal or Carminic Acid',
      status: 'HARAM',
      riskText: 'Toxic',
      riskScore: 0.65,
      origin: 'insect',
      flags: ['EU', 'US', 'AU'],
    ),
    Additive(
      code: 'E161I',
      name: 'Citranaxanthin',
      status: 'HARAM',
      riskText: 'Do not abuse',
      riskScore: 0.4,
      origin: 'chemical',
      flags: [],
      bannedFlags: ['EU', 'US', 'AU'],
    ),
    Additive(
      code: 'E161J',
      name: 'Astaxanthin',
      status: 'HARAM',
      riskText: 'Do not abuse',
      riskScore: 0.35,
      origin: 'chemical',
      flags: [],
      bannedFlags: ['EU', 'US', 'AU'],
    ),
    Additive(
      code: 'E428',
      name: 'Gelatin',
      status: 'HARAM',
      riskText: 'Do not abuse',
      riskScore: 0.25,
      origin: 'animal',
      flags: ['EU', 'US', 'AU'],
    ),
    Additive(
      code: 'E441',
      name: 'Superglycerinated hydrogenated rapeseed',
      status: 'HARAM',
      riskText: 'Do not abuse',
      riskScore: 0.3,
      origin: 'chemical',
      flags: ['EU', 'US', 'AU'],
    ),
    Additive(
      code: 'E471',
      name: 'Mono- and diglycerides of fatty acids',
      status: 'MUSHBOOH',
      riskText: 'Safe',
      riskScore: 0.1,
      origin: 'animal',
      flags: ['EU', 'US', 'AU'],
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

  void _showAdditiveDetail(Additive additive) {
    showDialog(
      context: context,
      builder: (context) {
        String currentStatus = additive.status;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Color statusColor = currentStatus == 'HALAL'
                ? Colors.green
                : currentStatus == 'HARAM'
                    ? Colors.red
                    : Colors.orange;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(additive.code, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      currentStatus,
                      style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    additive.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const Text('Origin:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(additive.origin.toUpperCase()),
                  const SizedBox(height: 8),
                  const Text('Risk Statement:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('${additive.riskText} (${(additive.riskScore * 100).toInt()}% risk)'),
                  const SizedBox(height: 16),
                  const Text('Customize status for your country:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatusButton(
                        label: 'Halal',
                        color: Colors.green,
                        isActive: currentStatus == 'HALAL',
                        onTap: () {
                          setDialogState(() {
                            currentStatus = 'HALAL';
                          });
                        },
                      ),
                      _buildStatusButton(
                        label: 'Haram',
                        color: Colors.red,
                        isActive: currentStatus == 'HARAM',
                        onTap: () {
                          setDialogState(() {
                            currentStatus = 'HARAM';
                          });
                        },
                      ),
                      _buildStatusButton(
                        label: 'Mushbooh',
                        color: Colors.orange,
                        isActive: currentStatus == 'MUSHBOOH',
                        onTap: () {
                          setDialogState(() {
                            currentStatus = 'MUSHBOOH';
                          });
                        },
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
                    backgroundColor: const Color(0xFF55A498),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    // Apply override
                    setState(() {
                      final index = _allAdditives.indexWhere((a) => a.code == additive.code);
                      if (index != -1) {
                        _allAdditives[index] = Additive(
                          code: additive.code,
                          name: additive.name,
                          status: currentStatus,
                          riskText: additive.riskText,
                          riskScore: additive.riskScore,
                          origin: additive.origin,
                          flags: additive.flags,
                          bannedFlags: additive.bannedFlags,
                        );
                      }
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Status of ${additive.code} updated to $currentStatus!')),
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
    const tealColor = Color(0xFF55A498);
    final list = _filteredAdditives;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF9F9FA),
      drawer: const HalalDrawer(activeRoute: 'List additives'),
      appBar: AppBar(
        backgroundColor: tealColor,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              )
            : IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
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
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
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
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${list.length} additives',
                  style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600),
                ),
                Row(
                  children: [
                    _buildFilterChip('All', tealColor),
                    const SizedBox(width: 8),
                    _buildFilterChip('Halal', Colors.green),
                    const SizedBox(width: 8),
                    _buildFilterChip('Haram', Colors.red),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Additives List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final additive = list[index];
                return _buildAdditiveCard(additive);
              },
            ),
          ),
        ],
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildAdditiveCard(Additive additive) {
    Color badgeColor;
    if (additive.status == 'HALAL') {
      badgeColor = Colors.green;
    } else if (additive.status == 'HARAM') {
      badgeColor = Colors.red;
    } else {
      badgeColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: InkWell(
        onTap: () => _showAdditiveDetail(additive),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Left Side: E-Code and Name info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          additive.code,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            additive.name,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Flag lists and risk details
                    Row(
                      children: [
                        // Flags
                        ...additive.flags.map((f) => _buildFlagIcon(f, false)),
                        ...additive.bannedFlags.map((f) => _buildFlagIcon(f, true)),
                        if (additive.flags.isEmpty && additive.bannedFlags.isEmpty)
                          const SizedBox(width: 8),

                        const SizedBox(width: 12),
                        // Risk gauge widget
                        _buildRiskGauge(additive.riskScore),
                        const SizedBox(width: 6),
                        Text(
                          additive.riskText,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Right Side: Status Badge and Custom Origin Icon
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      additive.status,
                      style: TextStyle(
                        color: badgeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  CustomPaint(
                    size: const Size(28, 28),
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
      margin: const EdgeInsets.only(right: 4),
      width: 16,
      height: 12,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: Colors.grey[300]!, width: 0.5),
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              flagCode == 'EU' ? '🇪🇺' : flagCode == 'US' ? '🇺🇸' : '🇦🇺',
              style: const TextStyle(fontSize: 8),
            ),
          ),
          if (isBanned)
            Container(
              color: Colors.red.withValues(alpha: 0.4),
              child: const Center(
                child: Icon(
                  Icons.block_flipped,
                  color: Colors.red,
                  size: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRiskGauge(double score) {
    Color gaugeColor = score < 0.4
        ? Colors.green
        : score < 0.7
            ? Colors.orange
            : Colors.red;

    return SizedBox(
      width: 28,
      height: 14,
      child: CustomPaint(
        painter: GaugeArcPainter(score: score, color: gaugeColor),
      ),
    );
  }
}

// Speedometer Gauge Arc Painter
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

// Custom Origin Painter for drawing Pig, Leaf, Chemical Beaker, Bug
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

    // Stem line
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

    // Body
    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.15, size.height * 0.25, size.width * 0.7, size.height * 0.55),
      bodyPaint,
    );
    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.15, size.height * 0.25, size.width * 0.7, size.height * 0.55),
      linePaint,
    );

    // Snout
    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.35, size.height * 0.45, size.width * 0.3, size.height * 0.22),
      Paint()..color = Colors.pink[200]!,
    );
    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.35, size.height * 0.45, size.width * 0.3, size.height * 0.22),
      linePaint,
    );
    // Snout holes
    canvas.drawCircle(Offset(size.width * 0.45, size.height * 0.56), 1.5, Paint()..color = Colors.pink[400]!);
    canvas.drawCircle(Offset(size.width * 0.55, size.height * 0.56), 1.5, Paint()..color = Colors.pink[400]!);

    // Eyes
    canvas.drawCircle(Offset(size.width * 0.35, size.height * 0.4), 1.5, Paint()..color = Colors.black);
    canvas.drawCircle(Offset(size.width * 0.65, size.height * 0.4), 1.5, Paint()..color = Colors.black);

    // Ears
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
    // Neck
    path.moveTo(size.width * 0.4, size.height * 0.15);
    path.lineTo(size.width * 0.6, size.height * 0.15);
    path.lineTo(size.width * 0.6, size.height * 0.45);
    // Base slope
    path.lineTo(size.width * 0.85, size.height * 0.85);
    // Base
    path.lineTo(size.width * 0.15, size.height * 0.85);
    // Base slope up
    path.lineTo(size.width * 0.4, size.height * 0.45);
    path.close();

    canvas.drawPath(path, flaskPaint);
    canvas.drawPath(path, linePaint);

    // Liquid bubbles inside
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

    // Head
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.22), size.width * 0.13, blackPaint);

    // Body
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.58), size.width * 0.3, bodyPaint);
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.58), size.width * 0.3, linePaint);

    // Wings line
    canvas.drawLine(
      Offset(size.width / 2, size.height * 0.28),
      Offset(size.width / 2, size.height * 0.88),
      linePaint,
    );

    // Dots
    canvas.drawCircle(Offset(size.width * 0.35, size.height * 0.48), 2, blackPaint);
    canvas.drawCircle(Offset(size.width * 0.65, size.height * 0.48), 2, blackPaint);
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.65), 2, blackPaint);
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.65), 2, blackPaint);

    // Antennas
    canvas.drawLine(Offset(size.width * 0.45, size.height * 0.12), Offset(size.width * 0.38, size.height * 0.05), linePaint);
    canvas.drawLine(Offset(size.width * 0.55, size.height * 0.12), Offset(size.width * 0.62, size.height * 0.05), linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}