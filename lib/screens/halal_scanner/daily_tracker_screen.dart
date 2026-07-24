import 'package:flutter/material.dart';
import 'halal_drawer.dart';

class DailyLog {
  bool fasting;
  double hydration; // in litres
  double weight; // in kg
  double height; // in cm
  int moodIndex; // 0 to 5, -1 if none
  String note;

  DailyLog({
    this.fasting = false,
    this.hydration = 0.0,
    this.weight = 0.0,
    this.height = 0.0,
    this.moodIndex = -1,
    this.note = '',
  });

  double get bmi {
    if (height <= 0 || weight <= 0) return 0.0;
    final heightInMeters = height / 100.0;
    return weight / (heightInMeters * heightInMeters);
  }
}

class DailyTrackerScreen extends StatefulWidget {
  const DailyTrackerScreen({super.key});

  @override
  State<DailyTrackerScreen> createState() => _DailyTrackerScreenState();
}

class _DailyTrackerScreenState extends State<DailyTrackerScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  DateTime _selectedMonth = DateTime(2026, 7, 1);
  int _selectedDay = 24;

  // In-memory database of logs keyed by day integer
  final Map<int, DailyLog> _logs = {
    23: DailyLog(fasting: true, hydration: 1.5, weight: 72.0, height: 178.0, moodIndex: 4, note: 'Had a productive day. Hydration was good.'),
    24: DailyLog(fasting: false, hydration: 0.0, weight: 0.0, height: 0.0, moodIndex: -1, note: ''),
  };

  DailyLog _getOrCreateLog(int day) {
    if (!_logs.containsKey(day)) {
      _logs[day] = DailyLog();
    }
    return _logs[day]!;
  }

  @override
  Widget build(BuildContext context) {
    const tealColor = Color(0xFF55A498);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF9F9FA),
      drawer: const HalalDrawer(activeRoute: 'Daily tracker'),
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
          'Daily tracker',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Month Switcher Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.grey),
                    onPressed: () {
                      setState(() {
                        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                      });
                    },
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: tealColor.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'July 2026', // Hardcoded as per image or dynamic based on _selectedMonth
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: tealColor,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: Colors.grey),
                    onPressed: () {
                      setState(() {
                        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Calendar Weekdays
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _WeekdayLabel('MON'),
                  _WeekdayLabel('TUE'),
                  _WeekdayLabel('WED'),
                  _WeekdayLabel('THU'),
                  _WeekdayLabel('FRI'),
                  _WeekdayLabel('SAT'),
                  _WeekdayLabel('SUN'),
                ],
              ),
              const SizedBox(height: 8),

              // Calendar Grid (Simulating July 2026: starts on Wednesday July 1)
              _buildCalendarGrid(tealColor),
              const SizedBox(height: 20),

              const Divider(),
              const SizedBox(height: 10),

              // Day Detail Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Details for ${_getDayName(_selectedDay)} $_selectedDay July 2026',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Icon(Icons.edit_note, color: tealColor),
                ],
              ),
              const SizedBox(height: 16),

              // Day details logger card
              _buildDayDetailCard(_getOrCreateLog(_selectedDay), tealColor),
            ],
          ),
        ),
      ),
    );
  }

  String _getDayName(int day) {
    // 2026 July 1 is a Wednesday
    final weekdayIndex = (day - 1 + 2) % 7; // Wednesday is 2 (0-indexed Mon=0)
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekdayIndex];
  }

  Widget _buildCalendarGrid(Color tealColor) {
    // July 2026 starts on Wednesday, has 31 days.
    // Padding: 2 empty slots on Mon & Tue.
    final List<int?> days = [
      null, null, 1, 2, 3, 4, 5,
      6, 7, 8, 9, 10, 11, 12,
      13, 14, 15, 16, 17, 18, 19,
      20, 21, 22, 23, 24, 25, 26,
      27, 28, 29, 30, 31
    ];

    // Wrap to rows
    final List<Widget> rows = [];
    List<Widget> currentRow = [];

    for (int i = 0; i < days.length; i++) {
      final day = days[i];
      if (day == null) {
        currentRow.add(Expanded(child: Container()));
      } else {
        final bool isSelected = _selectedDay == day;
        final bool isToday = (day == 24);
        final bool hasLog = _logs.containsKey(day) && (_logs[day]!.fasting || _logs[day]!.hydration > 0.0);

        Color cellColor = Colors.white;
        Color textColor = Colors.black87;

        if (isSelected) {
          cellColor = const Color(0xFF67B0A4);
          textColor = Colors.white;
        } else if (hasLog) {
          cellColor = tealColor.withValues(alpha: 0.2);
          textColor = tealColor;
        } else if (day < 24) {
          // Pre-filled days in light green as shown in Page 11
          cellColor = const Color(0xFFE5F5F3);
          textColor = tealColor;
        }

        currentRow.add(
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDay = day;
                });
              },
              child: Container(
                height: 44,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: cellColor,
                  borderRadius: BorderRadius.circular(6),
                  border: isToday && !isSelected
                      ? Border.all(color: tealColor, width: 1.5)
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                    color: textColor,
                  ),
                ),
              ),
            ),
          ),
        );
      }

      if ((i + 1) % 7 == 0 || i == days.length - 1) {
        // pad if last row is incomplete
        while (currentRow.length < 7) {
          currentRow.add(Expanded(child: Container()));
        }
        rows.add(Row(children: List.from(currentRow)));
        currentRow.clear();
      }
    }

    return Column(children: rows);
  }

  Widget _buildDayDetailCard(DailyLog log, Color tealColor) {
    return Column(
      children: [
        // 1. Fasting Toggle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tealColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.no_meals_outlined, color: Colors.red, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Fasting',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Switch(
                value: log.fasting,
                activeThumbColor: tealColor,
                onChanged: (val) {
                  setState(() {
                    log.fasting = val;
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2. Hydration Tracker
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tealColor.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.local_drink_outlined, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'Hydration Tracker',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Text(
                    '${log.hydration.toStringAsFixed(1)} litre(s)',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Row of 10 Glasses
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(10, (index) {
                  final double glassVolume = (index + 1) * 0.25;
                  final bool isFilled = log.hydration >= glassVolume;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        // Toggle hydration
                        if (isFilled) {
                          log.hydration = index * 0.25;
                        } else {
                          log.hydration = glassVolume;
                        }
                      });
                    },
                    child: Icon(
                      isFilled ? Icons.local_drink_rounded : Icons.local_drink_outlined,
                      color: isFilled ? Colors.blue : Colors.blue.withValues(alpha: 0.3),
                      size: 26,
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 3. Weight & Height & BMI
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tealColor.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              // Weight Row
              Row(
                children: [
                  const Icon(Icons.scale_outlined, color: Colors.grey),
                  const SizedBox(width: 8),
                  const Text('Weight', style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        hintText: '0.0',
                        suffixText: 'Kg',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 4),
                      ),
                      onChanged: (val) {
                        setState(() {
                          log.weight = double.tryParse(val) ?? 0.0;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Height Row
              Row(
                children: [
                  const Icon(Icons.height, color: Colors.grey),
                  const SizedBox(width: 8),
                  const Text('Height', style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        hintText: '0.0',
                        suffixText: 'Cm',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 4),
                      ),
                      onChanged: (val) {
                        setState(() {
                          log.height = double.tryParse(val) ?? 0.0;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              // BMI box
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('BMI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                      SizedBox(height: 2),
                      Text('Body Mass Index', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      border: Border.all(color: Colors.amber[300]!, width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      log.bmi > 0 ? log.bmi.toStringAsFixed(1) : '-',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 4. Mood Selector
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tealColor.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'How are you feeling this day?',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  final List<String> moods = ['😢', '😡', '😐', '🙂', '😊', '😁'];
                  final bool isSelected = log.moodIndex == index;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        log.moodIndex = index;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isSelected ? tealColor.withValues(alpha: 0.15) : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? tealColor : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        moods[index],
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 5. Note Log Text Field
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tealColor.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Note for the Day',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              TextField(
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Add notes here...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  fillColor: Colors.grey[50],
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: tealColor),
                  ),
                ),
                onChanged: (val) {
                  log.note = val;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String label;
  const _WeekdayLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}