import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../widgets/auth_header.dart'; // To access AppColors
import '../services/notification_service.dart';
class QurbaniPlannerSheet extends StatefulWidget {
  final ScrollController scrollController;
  const QurbaniPlannerSheet({super.key, required this.scrollController});
  @override
  State<QurbaniPlannerSheet> createState() => _QurbaniPlannerSheetState();
}
class _QurbaniPlannerSheetState extends State<QurbaniPlannerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // --- Common Settings ---
  String _selectedFiqh = 'Hanafi'; // 'Hanafi' or 'Shafi\'i'
  // --- Eligibility Checker State ---
  final TextEditingController _savingsCtrl = TextEditingController(text: '0');
  final TextEditingController _metalsCtrl = TextEditingController(text: '0');
  final TextEditingController _cashCtrl = TextEditingController(text: '0');
  final TextEditingController _debtsCtrl = TextEditingController(text: '0');
  bool _hasCheckedEligibility = false;
  bool _isEligible = false;
  double _netAssets = 0.0;
  String _eligibilityReason = '';
  // --- Cost Planner State ---
  String _selectedAnimal = 'Cow'; // 'Cow', 'Goat', 'Camel'
  String _selectedLocation = 'Dhaka'; // 'Dhaka', 'Chittagong', 'Other'
  int _selectedShares = 1;
  double _estimatedCost = 0.0;
  // --- Share Management State ---
  final int _totalShares = 7;
  final List<Map<String, dynamic>> _shareParticipants = [
    {'name': 'Self', 'shares': 1, 'paid': true},
    {'name': 'Brother Rahim', 'shares': 2, 'paid': true},
    {'name': 'Uncle Kamal', 'shares': 2, 'paid': false},
  ];
  final TextEditingController _participantNameCtrl = TextEditingController();
  int _newParticipantShares = 1;
  // --- Checklist State ---
  final List<Map<String, dynamic>> _checklistItems = [
    // Before Eid
    {'id': 'buy_animal', 'title': 'Buy Animal', 'isBefore': true, 'done': false},
    {'id': 'health_check', 'title': 'Verify animal requirements (Age, Health, Eyes, Teeth)', 'isBefore': true, 'done': false},
    {'id': 'prepare_knife', 'title': 'Prepare & sharpen knife', 'isBefore': true, 'done': false},
    {'id': 'contact_butcher', 'title': 'Arrange and contact butcher', 'isBefore': true, 'done': false},
    {'id': 'arrange_bags', 'title': 'Arrange meat distribution bags', 'isBefore': true, 'done': false},
    {'id': 'charity_list', 'title': 'Make list of poor families/needy', 'isBefore': true, 'done': false},
    // After Qurbani
    {'id': 'divide_meat', 'title': 'Divide meat into 3 equal portions', 'isBefore': false, 'done': false},
    {'id': 'family_portion', 'title': 'Distribute family portion', 'isBefore': false, 'done': false},
    {'id': 'relatives_portion', 'title': 'Distribute relatives & friends portion', 'isBefore': false, 'done': false},
    {'id': 'poor_portion', 'title': 'Distribute poor & needy portion', 'isBefore': false, 'done': false},
  ];
  // --- Reminder State ---
  final Map<String, bool> _activeReminders = {
    'Eid': false,
    'Payment': false,
    'Collection': false,
    'Distribution': false,
  };
  // --- Meat Distribution State ---
  double _totalMeatKg = 30.0;
  // --- Aqiqah Planner State ---
  String _aqiqahBabyGender = 'Boy'; // 'Boy' or 'Girl'
  int _aqiqahQuantity = 2;
  double _aqiqahEstimatedCost = 0.0;
  final List<Map<String, dynamic>> _aqiqahChecklist = [
    {'title': 'Name baby on 7th day', 'done': false},
    {'title': 'Shave baby\'s hair & give charity in silver weight equivalent', 'done': false},
    {'title': 'Purchase Aqiqah animals', 'done': false},
    {'title': 'Arrange food/distribution of meat', 'done': false},
  ];
  // --- Expense Tracker State ---
  final List<Map<String, dynamic>> _expenses = [
    {'category': 'Animal Purchase', 'amount': 85000.0, 'notes': 'Shared Cow'},
    {'category': 'Transport / Haat entry fee', 'amount': 2500.0, 'notes': 'Pickup truck'},
    {'category': 'Butcher Charge', 'amount': 5000.0, 'notes': 'Advance paid'},
  ];
  final TextEditingController _expCategoryCtrl = TextEditingController();
  final TextEditingController _expAmountCtrl = TextEditingController();
  final TextEditingController _expNotesCtrl = TextEditingController();
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _calculateCosts();
    _calculateAqiqahCosts();
  }
  @override
  void dispose() {
    _tabController.dispose();
    _savingsCtrl.dispose();
    _metalsCtrl.dispose();
    _cashCtrl.dispose();
    _debtsCtrl.dispose();
    _participantNameCtrl.dispose();
    _expCategoryCtrl.dispose();
    _expAmountCtrl.dispose();
    _expNotesCtrl.dispose();
    super.dispose();
  }
  // --- Calculations ---
  void _calculateCosts() {
    double basePrice = 0.0;
    if (_selectedAnimal == 'Cow') {
      if (_selectedLocation == 'Dhaka') {
        basePrice = 18000.0;
      } else if (_selectedLocation == 'Chittagong') {
        basePrice = 20000.0;
      } else {
        basePrice = 15500.0;
      }
      _estimatedCost = basePrice * _selectedShares;
    } else if (_selectedAnimal == 'Goat') {
      if (_selectedLocation == 'Dhaka') {
        basePrice = 28000.0;
      } else if (_selectedLocation == 'Chittagong') {
        basePrice = 30000.0;
      } else {
        basePrice = 22000.0;
      }
      _estimatedCost = basePrice; // Whole animal
    } else if (_selectedAnimal == 'Camel') {
      if (_selectedLocation == 'Dhaka') {
        basePrice = 60000.0;
      } else {
        basePrice = 50000.0;
      }
      _estimatedCost = basePrice * _selectedShares;
    }
  }
  void _calculateAqiqahCosts() {
    double pricePerGoat = _selectedLocation == 'Dhaka'
        ? 25000.0
        : _selectedLocation == 'Chittagong'
            ? 27000.0
            : 20000.0;
    _aqiqahEstimatedCost = pricePerGoat * _aqiqahQuantity;
  }
  void _checkEligibility() {
    double savings = double.tryParse(_savingsCtrl.text) ?? 0.0;
    double metals = double.tryParse(_metalsCtrl.text) ?? 0.0;
    double cash = double.tryParse(_cashCtrl.text) ?? 0.0;
    double debts = double.tryParse(_debtsCtrl.text) ?? 0.0;
    _netAssets = savings + metals + cash - debts;
    // Approximate Silver Nisab threshold in BDT (612.36g of Silver @ ~190 BDT/g)
    const double nisabLimit = 115000.0;
    setState(() {
      _hasCheckedEligibility = true;
      if (_selectedFiqh == 'Hanafi') {
        _isEligible = _netAssets >= nisabLimit;
        if (_isEligible) {
          _eligibilityReason =
              'According to Hanafi Fiqh, Qurbani is WAJIB (mandatory) for you. Your net assets (৳${NumberFormat('#,##,###').format(_netAssets)}) exceed the Silver Nisab threshold of ৳${NumberFormat('#,##,###').format(nisabLimit)}.';
        } else {
          _eligibilityReason =
              'According to Hanafi Fiqh, Qurbani is not mandatory for you. Your net assets (৳${NumberFormat('#,##,###').format(_netAssets)}) are below the Silver Nisab threshold of ৳${NumberFormat('#,##,###').format(nisabLimit)}. You can still perform it voluntarily.';
        }
      } else {
        // Shafi'i Fiqh
        _isEligible = _netAssets > 0;
        if (_isEligible) {
          _eligibilityReason =
              'According to Shafi\'i Fiqh, Qurbani is a SUNNAH MU\'AKKADAH (highly recommended practice) for you, as you possess a surplus of wealth beyond your basic needs for Eid.';
        } else {
          _eligibilityReason =
              'According to Shafi\'i Fiqh, Qurbani is not recommended for you because you do not have surplus financial capabilities beyond basic needs.';
        }
      }
    });
  }
  // --- Share Manager ---
  int get _filledShares {
    return _shareParticipants.fold(0, (sum, p) => sum + (p['shares'] as int));
  }
  int get _remainingShares {
    int rem = _totalShares - _filledShares;
    return rem < 0 ? 0 : rem;
  }
  void _addParticipant() {
    String name = _participantNameCtrl.text.trim();
    if (name.isEmpty) return;
    if (_newParticipantShares > _remainingShares) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot add participant. Shares exceed remaining limit!'),
          backgroundColor: AppColors.coralOrange,
        ),
      );
      return;
    }
    setState(() {
      _shareParticipants.add({
        'name': name,
        'shares': _newParticipantShares,
        'paid': false,
      });
      _participantNameCtrl.clear();
      _newParticipantShares = 1;
    });
  }
  // --- Expenses Tracker ---
  double get _totalExpenses {
    return _expenses.fold(0.0, (sum, exp) => sum + (exp['amount'] as double));
  }
  void _addExpense() {
    String category = _expCategoryCtrl.text.trim();
    double amount = double.tryParse(_expAmountCtrl.text) ?? 0.0;
    String notes = _expNotesCtrl.text.trim();
    if (category.isEmpty || amount <= 0) return;
    setState(() {
      _expenses.add({
        'category': category,
        'amount': amount,
        'notes': notes,
      });
      _expCategoryCtrl.clear();
      _expAmountCtrl.clear();
      _expNotesCtrl.clear();
    });
  }
  // --- Reminder Services ---
  Future<void> _toggleReminder(String type, String title, String body, DateTime time) async {
    bool current = _activeReminders[type] ?? false;
    setState(() {
      _activeReminders[type] = !current;
    });
    if (!current) {
      // Schedule reminder
      int id = 2000 + type.hashCode % 1000;
      await NotificationService.instance.scheduleCustomNotification(
        id: id,
        title: title,
        body: body,
        scheduledTime: time,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🔔 Scheduled: "$title" for ${DateFormat('dd MMM hh:mm a').format(time)}'),
            backgroundColor: AppColors.navyBlue,
          ),
        );
      }
    } else {
      // Cancel reminder
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔕 Reminder disabled.'),
            backgroundColor: Colors.grey,
          ),
        );
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##,###');
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          // Header handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 12),
          // Sheet Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.navyBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.pets_rounded, color: AppColors.navyBlue, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Qurbani & Aqiqah Planner',
                        style: GoogleFonts.poppins(
                          color: AppColors.navyBlue,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Plan and track your sacrifice according to Sunnah',
                        style: GoogleFonts.inter(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Fiqh Selector Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedFiqh = 'Hanafi';
                          if (_hasCheckedEligibility) _checkEligibility();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedFiqh == 'Hanafi' ? AppColors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _selectedFiqh == 'Hanafi'
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Hanafi Fiqh',
                          style: GoogleFonts.inter(
                            color: _selectedFiqh == 'Hanafi' ? AppColors.navyBlue : Colors.grey[600],
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedFiqh = 'Shafi\'i';
                          if (_hasCheckedEligibility) _checkEligibility();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedFiqh == 'Shafi\'i' ? AppColors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _selectedFiqh == 'Shafi\'i'
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Shafi\'i Fiqh',
                          style: GoogleFonts.inter(
                            color: _selectedFiqh == 'Shafi\'i' ? AppColors.navyBlue : Colors.grey[600],
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Navigation Tab Bar
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.navyBlue,
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: AppColors.navyBlue,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            tabs: const [
              Tab(text: 'Eligibility & Rules'),
              Tab(text: 'Calculators & Aqiqah'),
              Tab(text: 'Share Manager'),
              Tab(text: 'Meat Distribution'),
              Tab(text: 'Tasks & Expenses'),
            ],
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEligibilityAndRulesTab(currencyFormat),
                _buildCalculatorsTab(currencyFormat),
                _buildShareManagerTab(),
                _buildMeatDistributionTab(),
                _buildTasksAndExpensesTab(currencyFormat),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // ===== TAB 1: ELIGIBILITY & RULES =====
  Widget _buildEligibilityAndRulesTab(NumberFormat fmt) {
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        // Fiqh specific notice banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.dustyBlueTeal.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.dustyBlueTeal.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.navyBlue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Guidance for $_selectedFiqh Fiqh',
                    style: GoogleFonts.poppins(
                      color: AppColors.navyBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _selectedFiqh == 'Hanafi'
                    ? 'In Hanafi Fiqh, Qurbani is WAJIB (compulsory) for every adult, sane Muslim who owns Nisab threshold of wealth on the days of Eid. It requires sacrificing one goat/sheep per person, or 1 share in a larger animal (like cow/camel).'
                    : 'In Shafi\'i Fiqh, Qurbani is SUNNAH MU\'AKKADAH (highly recommended, emphasized Sunnah) for those who have financial capabilities. It is not Wajib but holds immense rewards.',
                style: GoogleFonts.inter(color: Colors.grey[800], fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Eligibility Input Cards
        Text(
          'Check Your Eligibility',
          style: GoogleFonts.poppins(color: AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 10),
        Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInputRow(
                  icon: Icons.savings_outlined,
                  label: 'Annual Savings',
                  controller: _savingsCtrl,
                ),
                _buildInputRow(
                  icon: Icons.storefront_outlined,
                  label: 'Gold / Silver (value in BDT)',
                  controller: _metalsCtrl,
                ),
                _buildInputRow(
                  icon: Icons.monetization_on_outlined,
                  label: 'Available Cash',
                  controller: _cashCtrl,
                ),
                _buildInputRow(
                  icon: Icons.money_off_csred_outlined,
                  label: 'Debts & Liabilities',
                  controller: _debtsCtrl,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _checkEligibility,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navyBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 45),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Evaluate Eligibility',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Eligibility Result Screen
        if (_hasCheckedEligibility) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isEligible
                  ? AppColors.midTeal.withValues(alpha: 0.1)
                  : Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _isEligible ? AppColors.midTeal : AppColors.coralOrange,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _isEligible ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
                  color: _isEligible ? AppColors.midTeal : AppColors.coralOrange,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEligible ? '✔ Eligible for Qurbani' : '✖ Not Eligible / Optional',
                        style: GoogleFonts.poppins(
                          color: _isEligible ? AppColors.midTeal : AppColors.coralOrange,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _eligibilityReason,
                        style: GoogleFonts.inter(color: Colors.grey[800], fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          'General Rules & Guidelines',
          style: GoogleFonts.poppins(color: AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 10),
        _buildRuleBullet('Age limits:', 'Goat/Sheep must be 1+ years. Cow/Buffalo must be 2+ years. Camel must be 5+ years.'),
        _buildRuleBullet('Health conditions:', 'The animal must be healthy and free of defects like blindness, severe limp, or extreme emaciation.'),
        _buildRuleBullet('Important Sunnahs:', 'Fast during the first 9 days of Dhul Hijjah, do not cut hair or nails from 1st Dhul Hijjah until sacrifice is done, and recite Takbeer Tashreeq after prayers.'),
        _buildRuleBullet('Meat distribution:', 'Recommended to divide the meat into three parts: 1/3 for family, 1/3 for relatives/friends, 1/3 for poor/needy.'),
      ],
    );
  }
  Widget _buildInputRow({
    required IconData icon,
    required String label,
    required TextEditingController controller,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.navyBlue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(color: Colors.grey[700], fontSize: 13),
            ),
          ),
          SizedBox(
            width: 120,
            height: 38,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.end,
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                prefixText: '৳ ',
                prefixStyle: GoogleFonts.inter(color: Colors.grey[600]),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildRuleBullet(String boldText, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.brightness_1, size: 6, color: AppColors.navyBlue),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(color: Colors.grey[800], fontSize: 13, height: 1.4),
                children: [
                  TextSpan(text: '$boldText ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  // ===== TAB 2: CALCULATORS & AQIQAH =====
  Widget _buildCalculatorsTab(NumberFormat fmt) {
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Qurbani Cost Planner',
          style: GoogleFonts.poppins(color: AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Card(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Animal',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey[700]),
                ),
                const SizedBox(height: 6),
                Row(
                  children: ['Cow', 'Goat', 'Camel'].map((animal) {
                    bool sel = _selectedAnimal == animal;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedAnimal = animal;
                            if (animal == 'Goat') _selectedShares = 1;
                            _calculateCosts();
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: sel ? AppColors.navyBlue : Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            animal,
                            style: GoogleFonts.inter(
                              color: sel ? Colors.white : Colors.grey[800],
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // Location selector
                Text(
                  'Select Location',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey[700]),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedLocation,
                  items: const [
                    DropdownMenuItem(value: 'Dhaka', child: Text('Dhaka')),
                    DropdownMenuItem(value: 'Chittagong', child: Text('Chittagong')),
                    DropdownMenuItem(value: 'Other', child: Text('Other Divisions')),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedLocation = val!;
                      _calculateCosts();
                      _calculateAqiqahCosts();
                    });
                  },
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),
                // Share count (Only if Cow or Camel)
                if (_selectedAnimal != 'Goat') ...[
                  Text(
                    'Number of Shares (1 to 7)',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _selectedShares > 1
                            ? () => setState(() {
                                  _selectedShares--;
                                  _calculateCosts();
                                })
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_selectedShares Share(s)',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _selectedShares < 7
                            ? () => setState(() {
                                  _selectedShares++;
                                  _calculateCosts();
                                })
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                // Cost Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.navyBlue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Estimated Cost:',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.navyBlue),
                      ),
                      Text(
                        '৳${fmt.format(_estimatedCost)}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: AppColors.coralOrange,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Aqiqah Planner Section
        Text(
          '🍼 Aqiqah Planner',
          style: GoogleFonts.poppins(color: AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Card(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aqiqah Guidelines',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.navyBlue, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  'Aqiqah is a sunnah practice of sacrificing animal(s) upon the birth of a child. It is recommended to perform it on the 7th, 14th, or 21st day after birth.',
                  style: GoogleFonts.inter(color: Colors.grey[700], fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Baby\'s Gender', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            initialValue: _aqiqahBabyGender,
                            items: const [
                              DropdownMenuItem(value: 'Boy', child: Text('Boy')),
                              DropdownMenuItem(value: 'Girl', child: Text('Girl')),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _aqiqahBabyGender = val!;
                                _aqiqahQuantity = _aqiqahBabyGender == 'Boy' ? 2 : 1;
                                _calculateAqiqahCosts();
                              });
                            },
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Animal Qty', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$_aqiqahQuantity Goat / Sheep',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.midTeal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Aqiqah Estimated Cost:',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.midTeal),
                      ),
                      Text(
                        '৳${fmt.format(_aqiqahEstimatedCost)}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: AppColors.midTeal,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Aqiqah Checklist',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.navyBlue, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Column(
                  children: _aqiqahChecklist.map((item) {
                    return CheckboxListTile(
                      value: item['done'],
                      title: Text(item['title'], style: GoogleFonts.inter(fontSize: 13)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setState(() {
                          item['done'] = val;
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  // ===== TAB 3: SHARE MANAGER =====
  Widget _buildShareManagerTab() {
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '🐄 Qurbani Share Management',
          style: GoogleFonts.poppins(color: AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          'Organize participants for a shared Cow or Camel (max 7 shares).',
          style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 12),
        ),
        const SizedBox(height: 16),
        // Progress bar for shares
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Shares: $_totalShares', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  Text(
                    'Filled: $_filledShares | Remaining: $_remainingShares',
                    style: GoogleFonts.inter(color: AppColors.navyBlue, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _filledShares / _totalShares,
                  minHeight: 14,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.midTeal),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // List of participants
        Text(
          'Participant List',
          style: GoogleFonts.poppins(color: AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _shareParticipants.length,
          itemBuilder: (context, index) {
            final p = _shareParticipants[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.navyBlue.withValues(alpha: 0.1),
                    child: const Icon(Icons.person, color: AppColors.navyBlue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p['name'],
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          '${p['shares']} Share(s)',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        p['paid'] = !p['paid'];
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: p['paid'] ? Colors.green[50] : Colors.orange[50],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        p['paid'] ? 'Paid' : 'Unpaid',
                        style: GoogleFonts.inter(
                          color: p['paid'] ? Colors.green[800] : Colors.orange[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _shareParticipants.removeAt(index);
                      });
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        // Add new participant input
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Participant',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _participantNameCtrl,
                decoration: InputDecoration(
                  hintText: 'Participant Name',
                  hintStyle: GoogleFonts.inter(fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Shares:', style: GoogleFonts.inter(fontSize: 13)),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _newParticipantShares > 1
                            ? () => setState(() => _newParticipantShares--)
                            : null,
                        icon: const Icon(Icons.remove),
                      ),
                      Text('$_newParticipantShares', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      IconButton(
                        onPressed: _newParticipantShares < _remainingShares
                            ? () => setState(() => _newParticipantShares++)
                            : null,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _addParticipant,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.midTeal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 40),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Add Friend', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    );
  }
  // ===== TAB 4: MEAT DISTRIBUTION =====
  Widget _buildMeatDistributionTab() {
    double familyQty = _totalMeatKg / 3;
    double relativesQty = _totalMeatKg / 3;
    double poorQty = _totalMeatKg / 3;
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '⚖ Meat Distribution Planner',
          style: GoogleFonts.poppins(color: AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 6),
        Text(
          'Set your total meat quantity to plan the Sunnah-based 3-way distribution.',
          style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 12),
        ),
        const SizedBox(height: 16),
        // Total Meat Input
        Card(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Meat Amount (in kg)',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        'Adjust slider or enter below',
                        style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 11),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      suffixText: ' kg',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _totalMeatKg = double.tryParse(val) ?? 0.0;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Slider(
          value: _totalMeatKg.clamp(0.0, 300.0),
          min: 0,
          max: 300,
          divisions: 30,
          activeColor: AppColors.navyBlue,
          inactiveColor: Colors.grey[300],
          label: '${_totalMeatKg.round()} kg',
          onChanged: (val) {
            setState(() {
              _totalMeatKg = val;
            });
          },
        ),
        const SizedBox(height: 16),
        // Visual chart
        Text(
          'Suggested Distribution Split',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navyBlue),
        ),
        const SizedBox(height: 8),
        Container(
          height: 35,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.grey[200],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    color: AppColors.navyBlue,
                    alignment: Alignment.center,
                    child: Text('Family (1/3)', style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                Container(width: 1.5, color: Colors.white),
                Expanded(
                  child: Container(
                    color: AppColors.midTeal,
                    alignment: Alignment.center,
                    child: Text('Relatives (1/3)', style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                Container(width: 1.5, color: Colors.white),
                Expanded(
                  child: Container(
                    color: AppColors.coralOrange,
                    alignment: Alignment.center,
                    child: Text('Poor (1/3)', style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Cards showing kg amounts
        Row(
          children: [
            _buildDistributionCard('Family Portion', familyQty, AppColors.navyBlue),
            const SizedBox(width: 10),
            _buildDistributionCard('Relatives Portion', relativesQty, AppColors.midTeal),
            const SizedBox(width: 10),
            _buildDistributionCard('Poor / Needy', poorQty, AppColors.coralOrange),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber[200]!),
          ),
          child: Text(
            '💡 Note: The 1/3 meat distribution rule is a highly recommended (Mustahabb) Sunnah based on traditional Islamic practices to encourage sharing and charity, but it is not a binding compulsory requirement. You may distribute more to charity or retain more based on family size and needs.',
            style: GoogleFonts.inter(color: Colors.amber[900], fontSize: 11, height: 1.4),
          ),
        ),
      ],
    );
  }
  Widget _buildDistributionCard(String title, double qty, Color accentColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border(top: BorderSide(color: accentColor, width: 4)),
        ),
        child: Column(
          children: [
            Text(title, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600]), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              '${qty.toStringAsFixed(1)} kg',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navyBlue),
            ),
          ],
        ),
      ),
    );
  }
  // ===== TAB 5: TASKS & EXPENSES =====
  Widget _buildTasksAndExpensesTab(NumberFormat fmt) {
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        // Expenses section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '💵 Qurbani Expenses',
              style: GoogleFonts.poppins(color: AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.navyBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Total: ৳${fmt.format(_totalExpenses)}',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _expenses.length,
          itemBuilder: (context, index) {
            final exp = _expenses[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payment, color: AppColors.midTeal, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(exp['category'], style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                        if (exp['notes'].isNotEmpty)
                          Text(exp['notes'], style: GoogleFonts.inter(color: Colors.grey, fontSize: 10)),
                      ],
                    ),
                  ),
                  Text(
                    '৳${fmt.format(exp['amount'])}',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _expenses.removeAt(index);
                      });
                    },
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        // Add expense inputs
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Log New Expense', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _expCategoryCtrl,
                      decoration: const InputDecoration(hintText: 'Category (e.g. Transport)', contentPadding: EdgeInsets.all(8)),
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _expAmountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'Amount (BDT)', contentPadding: EdgeInsets.all(8)),
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _expNotesCtrl,
                decoration: const InputDecoration(hintText: 'Notes', contentPadding: EdgeInsets.all(8)),
                style: GoogleFonts.inter(fontSize: 12),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _addExpense,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navyBlue,
                  minimumSize: const Size(double.infinity, 36),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Add Expense', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Task checklist section
        Text(
          '☑ Qurbani Task Checklist',
          style: GoogleFonts.poppins(color: AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),
        Text(
          'Before Eid Al-Adha:',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.midTeal),
        ),
        Column(
          children: _checklistItems.where((item) => item['isBefore']).map((item) {
            return CheckboxListTile(
              value: item['done'],
              title: Text(item['title'], style: GoogleFonts.inter(fontSize: 12)),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              onChanged: (val) {
                setState(() {
                  item['done'] = val;
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Text(
          'After Qurbani / Slaughter:',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.coralOrange),
        ),
        Column(
          children: _checklistItems.where((item) => !item['isBefore']).map((item) {
            return CheckboxListTile(
              value: item['done'],
              title: Text(item['title'], style: GoogleFonts.inter(fontSize: 12)),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              onChanged: (val) {
                setState(() {
                  item['done'] = val;
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        // Reminders triggers
        Text(
          '🔔 Reminders & Notifications',
          style: GoogleFonts.poppins(color: AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        _buildReminderTile(
          type: 'Eid',
          title: 'Qurbani Day Reminder',
          desc: 'Get notified on Eid Al-Adha morning (10th Dhul Hijjah) to prepare for Qurbani.',
          reminderTitle: '🐏 Qurbani Eid Day Reminder',
          reminderBody: 'Assalamu alaikum! Eid Mubarak. Today is Qurbani day. Ensure animal requirements and health conditions are verified.',
          timeOffset: const Duration(seconds: 15), // Mock: 15 seconds in the future
        ),
        _buildReminderTile(
          type: 'Payment',
          title: 'Qurbani Share Payment Reminder',
          desc: 'Reminder to pay the share cost to the primary host before buying the animal.',
          reminderTitle: '💰 Qurbani Payment Reminder',
          reminderBody: 'Reminder: Make sure all Qurbani share payments are completed and participants have agreed on their shares.',
          timeOffset: const Duration(seconds: 30),
        ),
        _buildReminderTile(
          type: 'Collection',
          title: 'Animal Collection / Haat Reminder',
          desc: 'Get notified to visit the animal market (Haat) or collect your pre-booked animal.',
          reminderTitle: '🐄 Animal Collection Reminder',
          reminderBody: 'Time to collect your animal. Double check the age (2+ yrs for cow, 1+ for goat) and health status.',
          timeOffset: const Duration(seconds: 45),
        ),
        _buildReminderTile(
          type: 'Distribution',
          title: 'Meat Distribution Reminder',
          desc: 'Get notified 2 hours after Eid Prayer to begin packaging and distribution of meat.',
          reminderTitle: '⚖ Meat Distribution Reminder',
          reminderBody: 'Time to divide meat into three equal portions (Family, Relatives, and Needy) as per Sunnah.',
          timeOffset: const Duration(seconds: 60),
        ),
      ],
    );
  }
  Widget _buildReminderTile({
    required String type,
    required String title,
    required String desc,
    required String reminderTitle,
    required String reminderBody,
    required Duration timeOffset,
  }) {
    bool active = _activeReminders[type] ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                Text(desc, style: GoogleFonts.inter(color: Colors.grey, fontSize: 10)),
              ],
            ),
          ),
          Switch(
            value: active,
            activeThumbColor: AppColors.navyBlue,
            onChanged: (val) {
              _toggleReminder(
                type,
                reminderTitle,
                reminderBody,
                DateTime.now().add(timeOffset),
              );
            },
          ),
        ],
      ),
    );
  }
}
