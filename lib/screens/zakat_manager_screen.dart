import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' hide TextDirection;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/auth_header.dart';
import '../services/notification_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────

class ZakatPayment {
  final String id;
  final double amount;
  final String currency;
  final String recipient;
  final String category; // one of 8 Quran categories
  final DateTime date;
  final String note;
  final String? animalDescription;
  final String obligationType; // 'haul', 'crops', 'minerals', 'rikaz'

  ZakatPayment({
    required this.id,
    required this.amount,
    required this.currency,
    required this.recipient,
    required this.category,
    required this.date,
    required this.note,
    this.animalDescription,
    this.obligationType = 'haul',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'currency': currency,
        'recipient': recipient,
        'category': category,
        'date': date.toIso8601String(),
        'note': note,
        'animalDescription': animalDescription,
        'obligationType': obligationType,
      };

  factory ZakatPayment.fromJson(Map<String, dynamic> j) => ZakatPayment(
        id: j['id'] as String,
        amount: (j['amount'] as num).toDouble(),
        currency: j['currency'] as String? ?? 'BDT',
        recipient: j['recipient'] as String,
        category: j['category'] as String,
        date: DateTime.parse(j['date'] as String),
        note: j['note'] as String? ?? '',
        animalDescription: j['animalDescription'] as String?,
        obligationType: j['obligationType'] as String? ?? 'haul',
      );
}

class ZakatYearSnapshot {
  final int year;
  final double wealth;
  final double zakatDue;
  final double zakatPaid;
  final String? livestockZakat;
  final double fitraDue;
  final double fitraPaid;
  final double cropsDue;
  final double cropsPaid;
  final double mineralsDue;
  final double mineralsPaid;
  final double rikazDue;
  final double rikazPaid;
  final List<ZakatPayment> payments;

  ZakatYearSnapshot({
    required this.year,
    required this.wealth,
    required this.zakatDue,
    required this.zakatPaid,
    this.livestockZakat,
    this.fitraDue = 0,
    this.fitraPaid = 0,
    this.cropsDue = 0,
    this.cropsPaid = 0,
    this.mineralsDue = 0,
    this.mineralsPaid = 0,
    this.rikazDue = 0,
    this.rikazPaid = 0,
    this.payments = const [],
  });

  Map<String, dynamic> toJson() => {
        'year': year,
        'wealth': wealth,
        'zakatDue': zakatDue,
        'zakatPaid': zakatPaid,
        'livestockZakat': livestockZakat,
        'fitraDue': fitraDue,
        'fitraPaid': fitraPaid,
        'cropsDue': cropsDue,
        'cropsPaid': cropsPaid,
        'mineralsDue': mineralsDue,
        'mineralsPaid': mineralsPaid,
        'rikazDue': rikazDue,
        'rikazPaid': rikazPaid,
        'payments': payments.map((p) => p.toJson()).toList(),
      };

  factory ZakatYearSnapshot.fromJson(Map<String, dynamic> j) =>
      ZakatYearSnapshot(
        year: j['year'] as int,
        wealth: (j['wealth'] as num).toDouble(),
        zakatDue: (j['zakatDue'] as num).toDouble(),
        zakatPaid: (j['zakatPaid'] as num).toDouble(),
        livestockZakat: j['livestockZakat'] as String?,
        fitraDue: (j['fitraDue'] as num?)?.toDouble() ?? 0,
        fitraPaid: (j['fitraPaid'] as num?)?.toDouble() ?? 0,
        cropsDue: (j['cropsDue'] as num?)?.toDouble() ?? 0,
        cropsPaid: (j['cropsPaid'] as num?)?.toDouble() ?? 0,
        mineralsDue: (j['mineralsDue'] as num?)?.toDouble() ?? 0,
        mineralsPaid: (j['mineralsPaid'] as num?)?.toDouble() ?? 0,
        rikazDue: (j['rikazDue'] as num?)?.toDouble() ?? 0,
        rikazPaid: (j['rikazPaid'] as num?)?.toDouble() ?? 0,
        payments: (j['payments'] as List<dynamic>? ?? [])
            .map((p) => ZakatPayment.fromJson(p as Map<String, dynamic>))
            .toList(),
      );
}

class HaulCycle {
  final int cycleNumber;
  final DateTime startDate;
  final DateTime endDate;
  final double wealthAtCompletion;
  final double lockedZakat;
  final String? lockedLivestockSummary;

  HaulCycle({
    required this.cycleNumber,
    required this.startDate,
    required this.endDate,
    required this.wealthAtCompletion,
    required this.lockedZakat,
    this.lockedLivestockSummary,
  });

  Map<String, dynamic> toJson() => {
        'cycleNumber': cycleNumber,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'wealthAtCompletion': wealthAtCompletion,
        'lockedZakat': lockedZakat,
        'lockedLivestockSummary': lockedLivestockSummary,
      };

  factory HaulCycle.fromJson(Map<String, dynamic> j) => HaulCycle(
        cycleNumber: j['cycleNumber'] as int? ?? 1,
        startDate: DateTime.parse(j['startDate'] as String),
        endDate: DateTime.parse(j['endDate'] as String),
        wealthAtCompletion: (j['wealthAtCompletion'] as num).toDouble(),
        lockedZakat: (j['lockedZakat'] as num).toDouble(),
        lockedLivestockSummary: j['lockedLivestockSummary'] as String?,
      );
}

class _CustomAsset {
  final String id;
  String name;
  double value;
  String currency;
  bool isLiability;

  _CustomAsset({
    required this.id,
    required this.name,
    required this.value,
    required this.currency,
    this.isLiability = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'value': value,
        'currency': currency,
        'isLiability': isLiability,
      };

  factory _CustomAsset.fromJson(Map<String, dynamic> j) => _CustomAsset(
        id: j['id'] as String,
        name: j['name'] as String,
        value: (j['value'] as num).toDouble(),
        currency: j['currency'] as String? ?? 'BDT',
        isLiability: j['isLiability'] as bool? ?? false,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// HIJRI HELPER (algorithmic conversion for Haul tracking)
// ─────────────────────────────────────────────────────────────────────────────

class _Hijri {
  final int year, month, day;
  const _Hijri(this.year, this.month, this.day);

  static const _monthNames = [
    'Muharram', 'Safar', "Rabi' al-Awwal", "Rabi' al-Thani",
    "Jumada al-Awwal", "Jumada al-Thani", 'Rajab', "Sha'ban",
    'Ramadan', 'Shawwal', "Dhu al-Qi'dah", 'Dhu al-Hijjah',
  ];

  String get monthName => _monthNames[month - 1];

  @override
  String toString() => '$day $monthName $year AH';

  static _Hijri fromGregorian(DateTime g) {
    final jd = _gregorianToJD(g.year, g.month, g.day);
    return _jdToHijri(jd);
  }

  static int _gregorianToJD(int y, int m, int d) {
    final a = ((14 - m) / 12).floor();
    final yr = y + 4800 - a;
    final mo = m + 12 * a - 3;
    return d +
        ((153 * mo + 2) / 5).floor() +
        365 * yr +
        (yr / 4).floor() -
        (yr / 100).floor() +
        (yr / 400).floor() -
        32045;
  }

  static _Hijri _jdToHijri(int jd) {
    final l = jd - 1948440 + 10632;
    final n = ((l - 1) / 10631).floor();
    final ll = l - 10631 * n + 354;
    final j =
        (((10985 - ll) / 5316).floor()) * (((50 * ll) / 17719).floor()) +
            (((ll) / 5670).floor()) * (((43 * ll) / 15238).floor());
    final lll = ll -
        (((30 - j) / 15).floor()) * (((17719 * j) / 50).floor()) -
        (((j) / 16).floor()) * (((15238 * j) / 43).floor()) +
        29;
    final month = ((24 * lll) / 709).floor();
    final day = lll - ((709 * month) / 24).floor();
    final year = 30 * n + j - 30;
    return _Hijri(year, month == 0 ? 12 : month, day);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONFIG & CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

class _Currency {
  final String code;
  final String symbol;
  final String name;
  final double toBDT;

  const _Currency(this.code, this.symbol, this.name, this.toBDT);
}

const _currencies = [
  _Currency('BDT', 'Tk', 'Bangladeshi Taka', 1.0),
  _Currency('USD', '\$', 'US Dollar', 110.0),
  _Currency('SAR', 'SR', 'Saudi Riyal', 29.3),
  _Currency('GBP', '£', 'British Pound', 139.0),
  _Currency('EUR', '€', 'Euro', 118.0),
  _Currency('AED', 'DH', 'UAE Dirham', 30.0),
  _Currency('MYR', 'RM', 'Malaysian Ringgit', 24.0),
  _Currency('PKR', 'Rs', 'Pakistani Rupee', 0.39),
  _Currency('INR', 'Rs', 'Indian Rupee', 1.31),
];

const _zakatCategories = [
  'The Poor (Al-Fuqara)',
  'The Needy (Al-Masakin)',
  'Zakat Administrators (Al-Amileen)',
  'New Muslims (Al-Mu\'allafah)',
  'Freeing Captives (Ar-Riqab)',
  'Debt Relief (Al-Gharimeen)',
  'In the Way of Allah (Fi Sabilillah)',
  'Stranded Travellers (Ibn As-Sabil)',
];

class _CharityOrg {
  final String name;
  final String category;
  final String description;
  final String website;
  final String country;

  const _CharityOrg({
    required this.name,
    required this.category,
    required this.description,
    required this.website,
    required this.country,
  });
}

const _charityDirectory = [
  _CharityOrg(
    name: 'As-Sunnah Foundation',
    category: 'The Poor (Al-Fuqara)',
    description: 'Providing education, health, and livelihood support to marginalized populations in Bangladesh.',
    website: 'https://assunnahfoundation.org',
    country: 'Bangladesh',
  ),
  _CharityOrg(
    name: 'Mastul Foundation',
    category: 'The Needy (Al-Masakin)',
    description: 'Empowering orphans, promoting education, and running Zakat-eligible livelihood programs in Bangladesh.',
    website: 'https://www.mastul.net/zakat',
    country: 'Bangladesh',
  ),
  _CharityOrg(
    name: 'Quantum Foundation',
    category: 'The Poor (Al-Fuqara)',
    description: 'Distributes Zakat resources directly to poor families, orphans, and distressed people in Bangladesh.',
    website: 'https://quantummethod.org.bd/en/zakat',
    country: 'Bangladesh',
  ),
  _CharityOrg(
    name: 'JAAGO Foundation',
    category: 'The Poor (Al-Fuqara)',
    description: 'Supports the education of underprivileged children across Bangladesh under Zakat eligibility.',
    website: 'https://jaago.com.bd/zakat',
    country: 'Bangladesh',
  ),
  _CharityOrg(
    name: 'Islamic Relief Worldwide',
    category: 'The Poor (Al-Fuqara)',
    description: 'Emergency relief and sustainable development for the world\'s poorest communities.',
    website: 'https://www.islamic-relief.org/zakat',
    country: 'Global',
  ),
  _CharityOrg(
    name: 'National Zakat Foundation (NZF)',
    category: 'The Needy (Al-Masakin)',
    description: 'Direct distribution of Zakat to eligible Muslim causes locally in the UK.',
    website: 'https://nzf.org.uk',
    country: 'UK',
  ),
  _CharityOrg(
    name: 'UNHCR Refugee Zakat Fund',
    category: 'Stranded Travellers (Ibn As-Sabil)',
    description: 'Direct scholar-approved Zakat aid for displaced families and refugees globally.',
    website: 'https://zakat.unhcr.org',
    country: 'Global',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class ZakatManagerScreen extends StatefulWidget {
  const ZakatManagerScreen({super.key});

  @override
  State<ZakatManagerScreen> createState() => _ZakatManagerScreenState();
}

class _ZakatManagerScreenState extends State<ZakatManagerScreen> {
  int _tab = 0;
  bool _isDarkMode = false;
  bool _isChangingCurrency = false;
  bool? _userPaymentsExpanded;
  bool get _isPaymentsExpanded => _userPaymentsExpanded ?? (_stillOwed > 0);

  // ── Live prices & overrides ──────────────────────────────────
  double _goldSpotUSD = 3280.0;
  double _silverSpotUSD = 33.0;
  double _usdToBDT = 110.0;

  double _goldPerGramBDT = 0.0;
  double _silverPerGramBDT = 0.0;
  bool _pricesLoading = true;
  String _pricesLastUpdated = '--:-- --';
  String? _priceFetchError;
  Timer? _priceRefreshTimer;

  bool _manualOverridePrices = false;
  final _manualGoldPriceCtrl = TextEditingController();
  final _manualSilverPriceCtrl = TextEditingController();

  // Sparkline histories
  final List<double> _goldHistory = [];
  final List<double> _silverHistory = [];

  // ── Currency ─────────────────────────────────────────────────
  String _selectedCurrency = 'BDT';
  final Map<String, double> _liveRatesToBDT = {
    for (final currency in _currencies) currency.code: currency.toBDT,
  };
  _Currency get _currency =>
      _currencies.firstWhere((c) => c.code == _selectedCurrency,
          orElse: () => _currencies.first);
  double get _toBDT => _currencyRate(_selectedCurrency);

  double _toDisplayCurrency(double amountBDT) => amountBDT / _toBDT;

  String _formatMoney(double amountBDT, {int fractionDigits = 0}) {
    final pattern = fractionDigits == 0
        ? '#,##0'
        : '#,##0.${List.filled(fractionDigits, '0').join()}';
    return '${_currency.symbol} ${NumberFormat(pattern).format(_toDisplayCurrency(amountBDT))}';
  }

  String _formatCompactMoney(double amountBDT) {
    final value = _toDisplayCurrency(amountBDT);
    if (value >= 1000000) return '${_currency.symbol} ${(value / 1000000).toStringAsFixed(2)}M';
    if (value >= 100000) return '${_currency.symbol} ${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '${_currency.symbol} ${(value / 1000).toStringAsFixed(1)}K';
    return '${_currency.symbol} ${value.toStringAsFixed(0)}';
  }

  static const _monthNames = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  String _monthName(int month) => _monthNames[month];

  // ── Nisab ────────────────────────────────────────────────────
  String _nisabStandard = 'gold'; // 'gold' or 'silver'
  double get _effectiveGoldPrice => _manualOverridePrices
      ? (double.tryParse(_manualGoldPriceCtrl.text) ??
              (_goldPerGramBDT / _toBDT)) *
          _toBDT
      : _goldPerGramBDT;
  double get _effectiveSilverPrice => _manualOverridePrices
      ? (double.tryParse(_manualSilverPriceCtrl.text) ??
              (_silverPerGramBDT / _toBDT)) *
          _toBDT
      : _silverPerGramBDT;

  double get _nisabBDT => _nisabStandard == 'gold'
      ? 85.0 * _effectiveGoldPrice
      : 595.0 * _effectiveSilverPrice;

  // ── Wealth inputs ────────────────────────────────────────────
  final _cashCtrl = TextEditingController(text: '0');
  final _gold24kCtrl = TextEditingController(text: '0');
  final _gold22kCtrl = TextEditingController(text: '0');
  final _gold21kCtrl = TextEditingController(text: '0');
  final _gold18kCtrl = TextEditingController(text: '0');
  final _silverGramsCtrl = TextEditingController(text: '0');
  final _stocksCtrl = TextEditingController(text: '0');
  final _businessCtrl = TextEditingController(text: '0');
  final _receivableCtrl = TextEditingController(text: '0');
  final _liabilitiesCtrl = TextEditingController(text: '0');

  // ── Agricultural Zakat (Ushr) ─────────────────────────────
  final _cropsHarvestKgCtrl  = TextEditingController(text: '0');
  final _cropsPricePerKgCtrl = TextEditingController(text: '0');
  bool _cropsRainFed = true;   // true = 10% (rain-fed), false = 5% (irrigated)
  double _cropsZakatDue = 0.0;

  // ── Mineral Zakat (Ma'adin) ───────────────────────────────
  final _mineralsValueCtrl = TextEditingController(text: '0');
  double _mineralsZakatDue = 0.0;

  // ── Rikaz (Buried Treasure) ───────────────────────────────
  final _rikazValueCtrl = TextEditingController(text: '0');
  double _rikazZakatDue = 0.0;

  // ── Rental Income ─────────────────────────────────────────
  final _rentalGrossCtrl = TextEditingController(text: '0');

  double _totalWealth = 0.0;
  double _zakatDue = 0.0;
  double _zakatEstimate = 0.0;
  // Locked when haul completes — persists until next cycle is started
  double? _completedHaulWealthZakat;
  String? _completedHaulLivestockSummary;

  String get _lockedLivestockSummary {
    // A completed assessment can deliberately have no livestock obligation.
    // Do not fall back to an older haul in that case.
    if (_completedHaulWealthZakat != null) {
      return _completedHaulLivestockSummary ?? '';
    }
    if (_haulCycles.isNotEmpty) {
      return _haulCycles.last.lockedLivestockSummary ?? '';
    }
    return '';
  }

  bool get _hasCompletedHaulAssessment =>
      _isHaulCompleted || _haulCycles.isNotEmpty;

  /// Live livestock inputs belong to the next haul and must not alter a
  /// completed haul's snapshot, payment options, or financial statement.
  String get _assessmentLivestockSummary => _hasCompletedHaulAssessment
      ? _lockedLivestockSummary
      : _livestockZakatSummary;

  // Record of all completed haul cycles
  List<HaulCycle> _haulCycles = [];
  // Current cycle number (1-based)
  int _currentHaulCycleNumber = 1;

  bool get _isEligible => _totalWealth >= _nisabBDT && _nisabBDT > 0;
  bool get _isHaulCompleted => _haulElapsedDays >= 354;
  int get _haulElapsedDays =>
      _haulStartDate != null ? DateTime.now().difference(_haulStartDate!).inDays : 0;

  // ── Haul / Nisab crossing ───────────────────────────────────
  DateTime? _haulStartDate;
  bool _nisabAlertEnabled = true;
  bool _wasAboveNisab = false;

  // ── Zakat al-Fitr (Fitra) ────────────────────────────────────
  int _fitraMembers = 1;
  String _fitraStaple = 'Rice';
  static const _fitraDefaultWeights = {
    'Rice': 3.0,
    'Wheat': 3.0,
    'Barley': 3.0,
    'Dates': 3.0,
    'Raisins': 3.0,
  };
  final _fitraPriceCtrl = TextEditingController(text: '70');
  final _fitraWeightCtrl = TextEditingController(text: '3.0');
  List<ZakatPayment> _fitraPayments = [];

  double get _fitraRatePerKg => double.tryParse(_fitraPriceCtrl.text) ?? 70.0;
  double get _fitraWeightPerHead => double.tryParse(_fitraWeightCtrl.text) ?? 3.0;
  double get _fitraTotal =>
      _fitraMembers * _fitraWeightPerHead * _fitraRatePerKg * _toBDT;
  bool get _isRamadan => _Hijri.fromGregorian(DateTime.now()).month == 9;

  // ── Payments ─────────────────────────────────────────────────
  double get _activeZakatDue {
    if (_completedHaulWealthZakat != null) return _completedHaulWealthZakat!;
    if (_haulCycles.isNotEmpty) {
      final last = _haulCycles.last;
      return last.lockedZakat > 0
          ? last.lockedZakat
          : (last.wealthAtCompletion > 0 ? last.wealthAtCompletion * 0.025 : 0.0);
    }
    return (_totalWealth >= _nisabBDT && _nisabBDT > 0) ? _totalWealth * 0.025 : 0.0;
  }

  List<ZakatPayment> _payments = [];

  // Only monetary haul-type payments count against monetary Haul Zakat (NOT animal payments, fitra, crops, minerals, rikaz)
  double get _totalPaid => _payments
      .where((p) => p.obligationType == 'haul' && (p.animalDescription == null || p.animalDescription!.isEmpty))
      .fold(0.0, (s, p) => s + (p.amount * _currencyRate(p.currency)));
  double get _stillOwed => (_activeZakatDue - _totalPaid).clamp(0.0, double.infinity);

  // Immediate zakat (crops/minerals/rikaz) is tracked completely separately
  double _immediatePaidFor(String obligationType) => _payments
      .where((p) => p.obligationType == obligationType)
      .fold(0.0, (s, p) => s + (p.amount * _currencyRate(p.currency)));
  double get _immediatePaid => _payments
      .where((p) => p.obligationType == 'crops' || p.obligationType == 'minerals' || p.obligationType == 'rikaz')
      .fold(0.0, (s, p) => s + (p.amount * _currencyRate(p.currency)));
  double get _immediateStillOwed =>
      ((_cropsZakatDue - _immediatePaidFor('crops')).clamp(0.0, double.infinity) +
              (_mineralsZakatDue - _immediatePaidFor('minerals')).clamp(0.0, double.infinity) +
              (_rikazZakatDue - _immediatePaidFor('rikaz')).clamp(0.0, double.infinity))
          .toDouble();
  double get _immediateTotalDue =>
      _cropsZakatDue + _mineralsZakatDue + _rikazZakatDue;

  double get _fitraPaid {
    final currentHijriYear = _Hijri.fromGregorian(DateTime.now()).year;
    return _fitraPayments
        .where((p) => _Hijri.fromGregorian(p.date).year == currentHijriYear)
        .fold(0.0, (s, p) => s + (p.amount * _currencyRate(p.currency)));
  }
  double get _fitraStillOwed => (_fitraTotal - _fitraPaid).clamp(0.0, double.infinity);

  /// Remaining payable amount (in BDT) for a given obligation type.
  double _remainingForObligation(String obligationType) {
    switch (obligationType) {
      case 'crops':
        return (_cropsZakatDue - _immediatePaidFor('crops'))
            .clamp(0.0, double.infinity);
      case 'minerals':
        return (_mineralsZakatDue - _immediatePaidFor('minerals'))
            .clamp(0.0, double.infinity);
      case 'rikaz':
        return (_rikazZakatDue - _immediatePaidFor('rikaz'))
            .clamp(0.0, double.infinity);
      case 'fitra':
        return _fitraStillOwed;
      default:
        return _stillOwed;
    }
  }

  String _obligationLabel(String obligationType) {
    switch (obligationType) {
      case 'crops':
        return 'Ushr';
      case 'minerals':
        return 'Minerals';
      case 'rikaz':
        return 'Rikaz';
      case 'fitra':
        return 'Fitra';
      default:
        return 'Haul';
    }
  }

  /// Formats the remaining payable amount (in BDT) into the given currency.
  String _paymentRemainingText(String currencyCode, String obligationType) {
    final remainingBDT = _remainingForObligation(obligationType);
    final symbol = _currencies
        .firstWhere((c) => c.code == currencyCode, orElse: () => _currencies.first)
        .symbol;
    final rate = _currencyRate(currencyCode);
    return '$symbol ${NumberFormat('#,##0').format(remainingBDT / rate)}';
  }

  double _currencyRate(String code) {
    final c = _currencies.firstWhere((x) => x.code == code,
        orElse: () => _currencies.first);
    return _liveRatesToBDT[code] ?? c.toBDT;
  }

  // ── History ──────────────────────────────────────────────────
  List<ZakatYearSnapshot> _history = [];

  // ── Livestock ─────────────────────────────────────────────────
  // User enters number of animals; market value per animal entered separately
  int _livestockCamels = 0;
  int _livestockCattle = 0;
  int _livestockSheep = 0;
  final _camelValueCtrl = TextEditingController(text: '0'); // market value per camel in BDT
  final _cattleValueCtrl = TextEditingController(text: '0');
  final _sheepValueCtrl = TextEditingController(text: '0');

  // Livestock total market value (used only for wealth calculation)
  double get _livestockTotalBDT =>
      (_livestockCamels * (double.tryParse(_camelValueCtrl.text) ?? 0)) +
      (_livestockCattle * (double.tryParse(_cattleValueCtrl.text) ?? 0)) +
      (_livestockSheep * (double.tryParse(_sheepValueCtrl.text) ?? 0));

  // ── Custom Assets & Liabilities ──────────────────────────────
  List<_CustomAsset> _customAssets = [];      // user-added zakatable assets
  List<_CustomAsset> _customLiabilities = []; // user-added liabilities

  double get _customAssetsTotalBDT => _customAssets.fold(
      0.0, (s, a) => s + (a.value * _currencyRate(a.currency)));
  double get _customLiabilitiesTotalBDT => _customLiabilities.fold(
      0.0, (s, a) => s + (a.value * _currencyRate(a.currency)));

  // ─────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _goldPerGramBDT = (_goldSpotUSD / 31.1035) * _usdToBDT;
    _silverPerGramBDT = (_silverSpotUSD / 31.1035) * _usdToBDT;

    _manualGoldPriceCtrl.text = (_goldPerGramBDT / _toBDT).toStringAsFixed(2);
    _manualSilverPriceCtrl.text = (_silverPerGramBDT / _toBDT).toStringAsFixed(2);

    _recalculate();
    _loadPrefs();
    _fetchLivePrices();

    _priceRefreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted) _fetchLivePrices();
    });

    for (final c in [
      _cashCtrl,
      _gold24kCtrl,
      _gold22kCtrl,
      _gold21kCtrl,
      _gold18kCtrl,
      _silverGramsCtrl,
      _stocksCtrl,
      _businessCtrl,
      _receivableCtrl,
      _liabilitiesCtrl,
      _camelValueCtrl,
      _cattleValueCtrl,
      _sheepValueCtrl,
      _cropsHarvestKgCtrl,
      _cropsPricePerKgCtrl,
      _mineralsValueCtrl,
      _rikazValueCtrl,
      _rentalGrossCtrl,
    ]) {
      c.addListener(_onWealthChanged);
    }
  }

  @override
  void dispose() {
    _priceRefreshTimer?.cancel();
    for (final c in [
      _cashCtrl,
      _gold24kCtrl,
      _gold22kCtrl,
      _gold21kCtrl,
      _gold18kCtrl,
      _silverGramsCtrl,
      _stocksCtrl,
      _businessCtrl,
      _receivableCtrl,
      _liabilitiesCtrl,
      _manualGoldPriceCtrl,
      _manualSilverPriceCtrl,
      _fitraPriceCtrl,
      _fitraWeightCtrl,
      _camelValueCtrl,
      _cattleValueCtrl,
      _sheepValueCtrl,
      _cropsHarvestKgCtrl,
      _cropsPricePerKgCtrl,
      _mineralsValueCtrl,
      _rikazValueCtrl,
      _rentalGrossCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onWealthChanged() {
    if (_isChangingCurrency) return;
    _recalculate();
    _checkNisabCrossing();
  }

  // ─────────────────────────────────────────────────────────────
  // PREFERENCES STORAGE
  // ─────────────────────────────────────────────────────────────

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    _isDarkMode = p.getBool('is_dark_mode') ?? false;

    // Wealth fields
    _cashCtrl.text = p.getString('zm_cash') ?? '0';
    _gold24kCtrl.text = p.getString('zm_gold_24k') ?? '0';
    _gold22kCtrl.text = p.getString('zm_gold_22k') ?? '0';
    _gold21kCtrl.text = p.getString('zm_gold_21k') ?? '0';
    _gold18kCtrl.text = p.getString('zm_gold_18k') ?? '0';
    _silverGramsCtrl.text = p.getString('zm_silver') ?? '0';
    _stocksCtrl.text = p.getString('zm_stocks') ?? '0';
    _businessCtrl.text = p.getString('zm_business') ?? '0';
    _receivableCtrl.text = p.getString('zm_receivable') ?? '0';
    _liabilitiesCtrl.text = p.getString('zm_liabilities') ?? '0';

    // Settings
    _nisabStandard = p.getString('zm_nisab_std') ?? 'gold';
    _selectedCurrency = p.getString('zm_currency') ?? 'BDT';
    _nisabAlertEnabled = p.getBool('zm_nisab_alert') ?? true;
    _manualOverridePrices = p.getBool('zm_manual_prices') ?? false;
    if (_manualOverridePrices) {
      _manualGoldPriceCtrl.text = p.getString('zm_manual_gold_val') ?? '0';
      _manualSilverPriceCtrl.text = p.getString('zm_manual_silver_val') ?? '0';
    } else {
      _manualGoldPriceCtrl.text = (_goldPerGramBDT / _toBDT).toStringAsFixed(2);
      _manualSilverPriceCtrl.text = (_silverPerGramBDT / _toBDT).toStringAsFixed(2);
    }

    // Haul start date
    final haulStr = p.getString('zm_haul_start');
    if (haulStr != null) {
      _haulStartDate = DateTime.tryParse(haulStr);
    }

    // Fitra
    _fitraMembers = p.getInt('zm_fitra_members') ?? 1;
    _fitraStaple = p.getString('zm_fitra_staple') ?? 'Rice';
    _fitraPriceCtrl.text = p.getString('zm_fitra_price') ?? '70';
    _fitraWeightCtrl.text = p.getString('zm_fitra_weight') ?? '3.0';

    // Payments
    final payJson = p.getString('zm_payments');
    if (payJson != null) {
      final list = json.decode(payJson) as List<dynamic>;
      _payments =
          list.map((e) => ZakatPayment.fromJson(e as Map<String, dynamic>)).toList();
    }

    // Fitra payments
    final fitraJson = p.getString('zm_fitra_payments');
    if (fitraJson != null) {
      final list = json.decode(fitraJson) as List<dynamic>;
      _fitraPayments =
          list.map((e) => ZakatPayment.fromJson(e as Map<String, dynamic>)).toList();
    }

    // History
    final histJson = p.getString('zm_history');
    if (histJson != null) {
      final list = json.decode(histJson) as List<dynamic>;
      _history = list
          .map((e) => ZakatYearSnapshot.fromJson(e as Map<String, dynamic>))
          .map((s) {
            if (s.zakatDue == 0 && s.wealth > 0) {
              return ZakatYearSnapshot(
                year: s.year,
                wealth: s.wealth,
                zakatDue: s.wealth * 0.025,
                zakatPaid: s.zakatPaid,
                livestockZakat: s.livestockZakat,
              );
            }
            return s;
          })
          .toList();
    }

    // Livestock
    _livestockCamels = p.getInt('zm_camels') ?? 0;
    _livestockCattle = p.getInt('zm_cattle') ?? 0;
    _livestockSheep = p.getInt('zm_sheep') ?? 0;
    _camelValueCtrl.text = p.getString('zm_camel_val') ?? '0';
    _cattleValueCtrl.text = p.getString('zm_cattle_val') ?? '0';
    _sheepValueCtrl.text = p.getString('zm_sheep_val') ?? '0';

    // Custom assets
    final customJson = p.getString('zm_custom_assets');
    if (customJson != null) {
      final list = json.decode(customJson) as List<dynamic>;
      _customAssets = list
          .map((e) => _CustomAsset.fromJson(e as Map<String, dynamic>))
          .where((a) => !a.isLiability)
          .toList();
      _customLiabilities = list
          .map((e) => _CustomAsset.fromJson(e as Map<String, dynamic>))
          .where((a) => a.isLiability)
          .toList();
    }

    // Agricultural / Minerals / Rikaz / Rental
    _cropsHarvestKgCtrl.text  = p.getString('zm_crops_kg') ?? '0';
    _cropsPricePerKgCtrl.text = p.getString('zm_crops_price') ?? '0';
    _cropsRainFed             = p.getBool('zm_crops_rainfed') ?? true;
    _mineralsValueCtrl.text   = p.getString('zm_minerals_val') ?? '0';
    _rikazValueCtrl.text      = p.getString('zm_rikaz_val') ?? '0';
    _rentalGrossCtrl.text     = p.getString('zm_rental_gross') ?? '0';

    _completedHaulWealthZakat = p.getDouble('zm_completed_haul_wealth_zakat');
    _completedHaulLivestockSummary = p.getString('zm_completed_haul_livestock_summary');

    // Haul cycle history
    final haulCyclesStr = p.getString('zm_haul_cycles');
    if (haulCyclesStr != null) {
      final decoded = json.decode(haulCyclesStr) as List<dynamic>;
      _haulCycles = decoded.map((e) => HaulCycle.fromJson(e as Map<String, dynamic>)).toList();
    }
    _currentHaulCycleNumber = p.getInt('zm_current_haul_cycle_num') ?? 1;

    _checkAutoRollover();
    _repairCurrentYearSnapshotLivestock();
    setState(() {});
    _recalculate();
  }

  /// Repair the current saved record from older app versions that captured
  /// next-haul livestock instead of the completed haul's locked value.
  void _repairCurrentYearSnapshotLivestock() {
    if (!_hasCompletedHaulAssessment) return;

    final index = _history.indexWhere((s) => s.year == DateTime.now().year);
    if (index < 0) return;

    final snapshot = _history[index];
    final livestockSummary = _assessmentLivestockSummary;
    if ((snapshot.livestockZakat ?? '') == livestockSummary) return;

    _history[index] = ZakatYearSnapshot(
      year: snapshot.year,
      wealth: snapshot.wealth,
      zakatDue: snapshot.zakatDue,
      zakatPaid: snapshot.zakatPaid,
      livestockZakat:
          livestockSummary.isEmpty ? null : livestockSummary,
    );
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();

    if (_completedHaulWealthZakat != null) {
      await p.setDouble('zm_completed_haul_wealth_zakat', _completedHaulWealthZakat!);
    } else {
      await p.remove('zm_completed_haul_wealth_zakat');
    }

    if (_completedHaulLivestockSummary != null) {
      await p.setString('zm_completed_haul_livestock_summary', _completedHaulLivestockSummary!);
    } else {
      await p.remove('zm_completed_haul_livestock_summary');
    }

    // Wealth fields
    await p.setString('zm_cash', _cashCtrl.text);
    await p.setString('zm_gold_24k', _gold24kCtrl.text);
    await p.setString('zm_gold_22k', _gold22kCtrl.text);
    await p.setString('zm_gold_21k', _gold21kCtrl.text);
    await p.setString('zm_gold_18k', _gold18kCtrl.text);
    await p.setString('zm_silver', _silverGramsCtrl.text);
    await p.setString('zm_stocks', _stocksCtrl.text);
    await p.setString('zm_business', _businessCtrl.text);
    await p.setString('zm_receivable', _receivableCtrl.text);
    await p.setString('zm_liabilities', _liabilitiesCtrl.text);

    // Settings
    await p.setString('zm_nisab_std', _nisabStandard);
    await p.setString('zm_currency', _selectedCurrency);
    await p.setBool('zm_nisab_alert', _nisabAlertEnabled);
    await p.setBool('zm_manual_prices', _manualOverridePrices);
    await p.setString('zm_manual_gold_val', _manualGoldPriceCtrl.text);
    await p.setString('zm_manual_silver_val', _manualSilverPriceCtrl.text);

    // Haul start
    if (_haulStartDate != null) {
      await p.setString('zm_haul_start', _haulStartDate!.toIso8601String());
      _checkAndNotifyZakatHaul();
    } else {
      await p.remove('zm_haul_start');
    }

    // Fitra
    await p.setInt('zm_fitra_members', _fitraMembers);
    await p.setString('zm_fitra_staple', _fitraStaple);
    await p.setString('zm_fitra_price', _fitraPriceCtrl.text);
    await p.setString('zm_fitra_weight', _fitraWeightCtrl.text);

    // Logs & History
    await p.setString('zm_payments', json.encode(_payments.map((e) => e.toJson()).toList()));
    await p.setString('zm_fitra_payments', json.encode(_fitraPayments.map((e) => e.toJson()).toList()));
    await p.setString('zm_history', json.encode(_history.map((e) => e.toJson()).toList()));

    // Livestock
    await p.setInt('zm_camels', _livestockCamels);
    await p.setInt('zm_cattle', _livestockCattle);
    await p.setInt('zm_sheep', _livestockSheep);
    await p.setString('zm_camel_val', _camelValueCtrl.text);
    await p.setString('zm_cattle_val', _cattleValueCtrl.text);
    await p.setString('zm_sheep_val', _sheepValueCtrl.text);

    // Custom assets + liabilities (combined list)
    final allCustom = [..._customAssets, ..._customLiabilities];
    await p.setString('zm_custom_assets', json.encode(allCustom.map((e) => e.toJson()).toList()));

    // Agricultural / Minerals / Rikaz / Rental
    await p.setString('zm_crops_kg',      _cropsHarvestKgCtrl.text);
    await p.setString('zm_crops_price',   _cropsPricePerKgCtrl.text);
    await p.setBool('zm_crops_rainfed',   _cropsRainFed);
    await p.setString('zm_minerals_val',  _mineralsValueCtrl.text);
    await p.setString('zm_rikaz_val',     _rikazValueCtrl.text);
    await p.setString('zm_rental_gross',  _rentalGrossCtrl.text);

    // Haul cycle history
    await p.setString('zm_haul_cycles', json.encode(_haulCycles.map((c) => c.toJson()).toList()));
    await p.setInt('zm_current_haul_cycle_num', _currentHaulCycleNumber);
  }

  Future<void> _checkAndNotifyZakatHaul() async {
    if (_haulStartDate == null) return;
    if (!_isHaulCompleted) return;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    final bool haulNotified = prefs.getBool('zm_haul_fulfilled_notified') ?? false;
    if (!haulNotified) {
      await NotificationService.instance.showCustomNotification(
        id: 8888,
        title: 'Zakat Haul Completed',
        body: 'Your Zakat Haul (354 lunar days) has been fulfilled. Zakat is now due on your wealth.',
        category: 'zakat',
        targetRoute: '/zakat',
      );
      await prefs.setBool('zm_haul_fulfilled_notified', true);
      await prefs.setString('zm_last_unpaid_reminder_date', now.toIso8601String());
      return;
    }

    if (_stillOwed > 0) {
      final lastReminderStr = prefs.getString('zm_last_unpaid_reminder_date');
      final DateTime lastReminder = lastReminderStr != null
          ? (DateTime.tryParse(lastReminderStr) ?? now)
          : now.subtract(const Duration(days: 21));

      if (now.difference(lastReminder).inDays >= 20) {
        await NotificationService.instance.showCustomNotification(
          id: 8889,
          title: 'Zakat Payment Reminder',
          body: 'Your Zakat Haul is complete and Zakat remains unpaid. Please record your Zakat payment.',
          category: 'zakat',
          targetRoute: '/zakat',
        );
        await prefs.setString('zm_last_unpaid_reminder_date', now.toIso8601String());
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // METAL PRICES FETCH
  // ─────────────────────────────────────────────────────────────

  Future<void> _fetchLivePrices() async {
    if (mounted) {
      setState(() {
        _pricesLoading = true;
        _priceFetchError = null;
      });
    }
    var metalPriceUpdated = false;
    var priceProvider = 'Saved rate';
    String? primaryError;

    // Gold API is the primary source: it is free, requires no API key, and
    // returns USD per troy ounce for both XAU and XAG.
    try {
      final prices = await Future.wait([
        _fetchGoldApiSpotPrice('XAU'),
        _fetchGoldApiSpotPrice('XAG'),
      ]);
      if (prices[0] != null && prices[1] != null) {
        _goldSpotUSD = prices[0]!;
        _silverSpotUSD = prices[1]!;
        metalPriceUpdated = true;
        priceProvider = 'Gold API';
      }
    } catch (error) {
      primaryError = error.toString();
    }

    // Secondary fallback for when Gold API is unavailable.
    if (!metalPriceUpdated) {
    try {
      final metalRes = await http
          .get(Uri.parse('https://api.metals.live/v1/spot'))
          .timeout(const Duration(seconds: 8));
      if (metalRes.statusCode == 200) {
        final data = json.decode(metalRes.body);
        final records = data is List ? data : [data];
        for (final record in records.whereType<Map>()) {
          final gold = record['gold'] ?? record['xau'];
          final silver = record['silver'] ?? record['xag'];
          final goldValue = _positiveNumber(gold);
          final silverValue = _positiveNumber(silver);
          if (goldValue != null) {
            // metals.live returns spot prices in cents per troy ounce. Accept
            // dollar responses too so a provider format change remains safe.
            _goldSpotUSD = goldValue > 10000 ? goldValue / 100 : goldValue;
            metalPriceUpdated = true;
            priceProvider = 'Metals.live';
          }
          if (silverValue != null) {
            _silverSpotUSD = silverValue > 1000 ? silverValue / 100 : silverValue;
            metalPriceUpdated = true;
            priceProvider = 'Metals.live';
          }
        }
      }
    } catch (_) {}
    }

    try {
      final fxRes = await http
          .get(Uri.parse('https://open.er-api.com/v6/latest/USD'))
          .timeout(const Duration(seconds: 8));
      if (fxRes.statusCode == 200) {
        final fx = json.decode(fxRes.body) as Map<String, dynamic>;
        final rates = fx['rates'] as Map<String, dynamic>?;
        final bdtPerUsd = rates?['BDT'];
        if (bdtPerUsd is num && bdtPerUsd > 0) {
          _usdToBDT = bdtPerUsd.toDouble();
          for (final currency in _currencies) {
            final unitsPerUsd = rates?[currency.code];
            if (unitsPerUsd is num && unitsPerUsd > 0) {
              _liveRatesToBDT[currency.code] = _usdToBDT / unitsPerUsd.toDouble();
            }
          }
          _liveRatesToBDT['BDT'] = 1.0;
        }
      }
    } catch (_) {}

    final newGold = (_goldSpotUSD / 31.1035) * _usdToBDT;
    final newSilver = (_silverSpotUSD / 31.1035) * _usdToBDT;

    if (_goldHistory.isEmpty) {
      for (int i = 8; i >= 1; i--) {
        _goldHistory.add(
            newGold * (1 + (math.Random().nextDouble() - 0.5) * 0.006));
        _silverHistory.add(
            newSilver * (1 + (math.Random().nextDouble() - 0.5) * 0.008));
      }
    }
    _goldHistory.add(newGold);
    _silverHistory.add(newSilver);
    if (_goldHistory.length > 20) _goldHistory.removeAt(0);
    if (_silverHistory.length > 20) _silverHistory.removeAt(0);

    if (mounted) {
      setState(() {
        _goldPerGramBDT = newGold;
        _silverPerGramBDT = newSilver;
        _pricesLoading = false;
        _priceFetchError = metalPriceUpdated ? null : primaryError;
        _pricesLastUpdated = metalPriceUpdated
            ? '${DateFormat('hh:mm a').format(DateTime.now())} · $priceProvider'
            : 'Live price unavailable';

        if (!_manualOverridePrices) {
          _manualGoldPriceCtrl.text = (_goldPerGramBDT / _toBDT).toStringAsFixed(2);
          _manualSilverPriceCtrl.text = (_silverPerGramBDT / _toBDT).toStringAsFixed(2);
        }
      });
      _recalculate();
    }
  }

  Future<double?> _fetchGoldApiSpotPrice(String symbol) async {
    final response = await http
        .get(
          Uri.parse('https://api.gold-api.com/price/$symbol'),
          headers: const {
            'Accept': 'application/json',
            'User-Agent': 'DeenMate/1.0',
          },
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw StateError('Gold API returned ${response.statusCode}');
    }
    final data = json.decode(response.body) as Map<String, dynamic>;
    final price = _positiveNumber(data['price']);
    if (price == null) throw const FormatException('Gold API returned no price');
    return price;
  }

  double? _positiveNumber(dynamic value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    return number != null && number > 0 ? number : null;
  }

  void _changeCurrency(String currencyCode) {
    if (currencyCode == _selectedCurrency) return;
    final oldRate = _toBDT;
    final newRate = _currencyRate(currencyCode);
    final controllers = [
      _cashCtrl,
      _stocksCtrl,
      _businessCtrl,
      _receivableCtrl,
      _liabilitiesCtrl,
      _camelValueCtrl,
      _cattleValueCtrl,
      _sheepValueCtrl,
      _fitraPriceCtrl,
      if (_manualOverridePrices) _manualGoldPriceCtrl,
      if (_manualOverridePrices) _manualSilverPriceCtrl,
    ];

    _isChangingCurrency = true;
    try {
      for (final controller in controllers) {
        final value = double.tryParse(controller.text.replaceAll(',', '')) ?? 0;
        controller.text = (value * oldRate / newRate).toStringAsFixed(2);
      }
      setState(() => _selectedCurrency = currencyCode);
      if (!_manualOverridePrices) {
        _manualGoldPriceCtrl.text = (_goldPerGramBDT / _toBDT).toStringAsFixed(2);
        _manualSilverPriceCtrl.text = (_silverPerGramBDT / _toBDT).toStringAsFixed(2);
      }
    } finally {
      _isChangingCurrency = false;
    }
    _recalculate();
  }

  // ─────────────────────────────────────────────────────────────
  // WEALTH RECALCULATION & KARAT MIX CONVERSION
  // ─────────────────────────────────────────────────────────────

  double get _pureGoldEquivalentGrams {
    final g24k = double.tryParse(_gold24kCtrl.text.replaceAll(',', '')) ?? 0;
    final g22k = double.tryParse(_gold22kCtrl.text.replaceAll(',', '')) ?? 0;
    final g21k = double.tryParse(_gold21kCtrl.text.replaceAll(',', '')) ?? 0;
    final g18k = double.tryParse(_gold18kCtrl.text.replaceAll(',', '')) ?? 0;

    // Multipliers based on standard gold content ratios:
    // 24K: 1.0 (pure gold content)
    // 22K: 22/24 ≈ 0.9167
    // 21K: 21/24 ≈ 0.8750
    // 18K: 18/24 ≈ 0.7500
    return (g24k * 1.0) + (g22k * 0.9167) + (g21k * 0.875) + (g18k * 0.75);
  }

  void _recalculate() {
    final rate = _toBDT;
    final cash = (double.tryParse(_cashCtrl.text.replaceAll(',', '')) ?? 0) * rate;

    final pureGoldGrams = _pureGoldEquivalentGrams;
    final silverGrams = double.tryParse(_silverGramsCtrl.text.replaceAll(',', '')) ?? 0;

    final goldVal = pureGoldGrams * _effectiveGoldPrice;
    final silverVal = silverGrams * _effectiveSilverPrice;

    final stocks = (double.tryParse(_stocksCtrl.text.replaceAll(',', '')) ?? 0) * rate;
    final business = (double.tryParse(_businessCtrl.text.replaceAll(',', '')) ?? 0) * rate;
    final receivable = (double.tryParse(_receivableCtrl.text.replaceAll(',', '')) ?? 0) * rate;
    final liabilities = (double.tryParse(_liabilitiesCtrl.text.replaceAll(',', '')) ?? 0) * rate;

    // Rental income (net feeds into standard 2.5% wealth pool)
    final rentalGross = (double.tryParse(_rentalGrossCtrl.text.replaceAll(',', '')) ?? 0) * rate;

    final gross = cash + goldVal + silverVal + stocks + business + receivable + rentalGross
        + _customAssetsTotalBDT;
    final net = (gross - liabilities - _customLiabilitiesTotalBDT).clamp(0.0, double.infinity);

    // Agricultural Zakat (Ushr) — separate, no Haul required, due at each harvest (Nisab = 653 kg)
    final harvestKg = double.tryParse(_cropsHarvestKgCtrl.text.replaceAll(',', '')) ?? 0;
    final pricePerKg = (double.tryParse(_cropsPricePerKgCtrl.text.replaceAll(',', '')) ?? 0) * rate;
    final harvestValue = harvestKg * pricePerKg;
    final cropsZakat = harvestKg >= 653 ? harvestValue * (_cropsRainFed ? 0.10 : 0.05) : 0.0;

    // Mineral Zakat (Ma'adin) — 2.5%, no Haul, Nisab = currency nisab
    final mineralsVal = (double.tryParse(_mineralsValueCtrl.text.replaceAll(',', '')) ?? 0) * rate;
    final mineralsZakat = (_nisabBDT > 0 && mineralsVal >= _nisabBDT) ? mineralsVal * 0.025 : 0.0;

    // Rikaz (Buried Treasure) — 20% flat (Khums), no Nisab, no Haul
    final rikazVal = (double.tryParse(_rikazValueCtrl.text.replaceAll(',', '')) ?? 0) * rate;
    final rikazZakat = rikazVal > 0 ? rikazVal * 0.20 : 0.0;

    // Standard wealth Zakat (2.5% after Haul)
    final wealthZakat = (net >= _nisabBDT && _nisabBDT > 0) ? net * 0.025 : 0.0;
    final isEligible = net >= _nisabBDT && _nisabBDT > 0;

    // ── AUTOMATIC HAUL START & AUTO-ROLLOVER ─────────────────────
    if (isEligible && _haulStartDate == null) {
      _haulStartDate = DateTime.now();
    }
    _checkAutoRollover();

    final liveEstimate = wealthZakat + cropsZakat + mineralsZakat + rikazZakat;

    // Only lock when prices are loaded (nisabBDT > 0), so we don't lock 0
    if (_isHaulCompleted && _nisabBDT > 0) {
      if (_completedHaulWealthZakat == null) {
        _completedHaulWealthZakat = wealthZakat;
        _completedHaulLivestockSummary = _livestockZakatSummary;
      }
    } else if (!_isHaulCompleted) {
      _completedHaulWealthZakat = null;
      _completedHaulLivestockSummary = null;
    }

    // _zakatDue: event-based always due + locked haul zakat if haul complete
    final lockedForDue = _completedHaulWealthZakat ?? 0.0;
    final dueAmount = (lockedForDue > 0 ? lockedForDue : 0.0) + cropsZakat + mineralsZakat + rikazZakat;

    setState(() {
      _totalWealth = net;
      _cropsZakatDue = cropsZakat;
      _mineralsZakatDue = mineralsZakat;
      _rikazZakatDue = rikazZakat;
      _zakatEstimate = liveEstimate;
      _zakatDue = dueAmount;
    });

    _savePrefs();
  }

  /// List of animal zakat obligations for animals meeting Nisab
  List<String> get _livestockZakatDueItems {
    final List<String> items = [];
    final camel = _computeCamelZakat(_livestockCamels);
    if (camel.isNotEmpty) items.add(camel);
    final cattle = _computeCattleZakat(_livestockCattle);
    if (cattle.isNotEmpty) items.add(cattle);
    final sheep = _computeSheepZakat(_livestockSheep);
    if (sheep.isNotEmpty) items.add(sheep);
    return items;
  }

  String get _livestockZakatSummary => _livestockZakatDueItems.join(' + ');

  /// Formatted total zakat string combining monetary amount and livestock zakat
  String _formattedZakatDueText({double? dueAmount, String? livestockSummary}) {
    final double amount = dueAmount ?? _zakatDue;
    final String livestock = livestockSummary ?? _livestockZakatSummary;

    if (amount > 0 && livestock.isNotEmpty) {
      return '${_formatMoney(amount)} + $livestock (or equivalent value)';
    } else if (amount > 0) {
      return _formatMoney(amount);
    } else if (livestock.isNotEmpty) {
      return '$livestock (or equivalent value)';
    }
    return _formatMoney(0);
  }

  /// True if any livestock type meets its own Islamic nisab threshold.
  bool get _livestockMeetsNisab =>
      _livestockCamels >= 5 || _livestockCattle >= 30 || _livestockSheep >= 40;

  // ─────────────────────────────────────────────────────────────
  // NISAB THRESHOLD ALERT BANNER
  // ─────────────────────────────────────────────────────────────

  void _checkNisabCrossing() {
    if (!_nisabAlertEnabled || _nisabBDT <= 0) return;
    final nowAbove = _totalWealth >= _nisabBDT;
    if (nowAbove && !_wasAboveNisab) {
      if (_haulStartDate == null) {
        setState(() => _haulStartDate = DateTime.now());
        _savePrefs();
        _showNisabCrossedNotification(crossed: true);
      }
    } else if (!nowAbove && _wasAboveNisab) {
      _showNisabCrossedNotification(crossed: false);
    }
    _wasAboveNisab = nowAbove;
  }

  void _showNisabCrossedNotification({required bool crossed}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: crossed ? const Color(0xFF2E7D32) : AppColors.coralOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            Icon(crossed ? Icons.check_circle_rounded : Icons.warning_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                crossed
                    ? 'Your wealth crossed the Nisab. Your Haul clock has started.'
                    : 'Your wealth dropped below Nisab. Haul clock may need to be reset.',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 12.5),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // NAVIGATION & ACTIONS
  // ─────────────────────────────────────────────────────────────

  Future<bool> _confirmDeletion(String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: AlertDialog(
                backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Text('Confirm Deletion',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
                content: Text(message, style: GoogleFonts.inter(color: _isDarkMode ? Colors.white70 : Colors.black87)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text('Cancel',
                        style: GoogleFonts.inter(
                            color: _isDarkMode ? Colors.white : AppColors.navyBlue, fontWeight: FontWeight.bold)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text('Delete',
                        style: GoogleFonts.inter(
                            color: AppColors.coralOrange, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD METHOD (Handles PIN lock validation overlay)
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final double maxAppWidth = 430.0;
    final double appWidth = math.min(size.width, maxAppWidth);

    Widget content = SafeArea(
      child: Column(
        children: [
          _buildPremiumHeader(),
          const SizedBox(height: 12),
          _buildTabBar(),
          Expanded(child: _buildTabContent()),
        ],
      ),
    );

    return Container(
      color: _isDarkMode ? const Color(0xFF000000) : const Color(0xFFE8E8E8), // Outer background for desktop/laptop screens
      child: Center(
        child: Container(
          width: appWidth,
          height: double.infinity,
          color: _isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
          child: Scaffold(
            backgroundColor: _isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
            body: content,
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumHeader() {
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;
    final subtextColor = _isDarkMode ? Colors.white70 : AppColors.navyBlue.withValues(alpha: 0.55);

    return Container(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
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
                child: const Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zakat Manager',
                      style: GoogleFonts.poppins(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      'Wealth, Haul & Obligations',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: subtextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _tabLabels = ['Calculator', 'Haul', 'Rules', 'Al-Fitr', 'Payments', 'History', 'Guide'];
  static const _tabIcons = [
    Icons.calculate_rounded,
    Icons.hourglass_bottom_rounded,
    Icons.menu_book_rounded,
    Icons.people_alt_rounded,
    Icons.receipt_long_rounded,
    Icons.bar_chart_rounded,
    Icons.help_outline_rounded,
  ];

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: List.generate(_tabLabels.length, (i) {
          final active = i == _tab;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: active ? AppColors.navyBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(_tabIcons[i],
                        size: 16,
                        color: active
                            ? Colors.white
                            : (_isDarkMode ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.4))),
                    const SizedBox(height: 2),
                    Text(_tabLabels[i],
                        style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: active
                                ? Colors.white
                                : (_isDarkMode ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.4)))),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_tab) {
      case 0:
        return _buildCalculatorTab();
      case 1:
        return _buildHaulTab();
      case 2:
        return _buildRulesTab();
      case 3:
        return _buildFitraTab();
      case 4:
        return _buildPaymentsTab();
      case 5:
        return _buildHistoryTab();
      case 6:
        return _buildGuideTab();
      default:
        return _buildCalculatorTab();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 0 — CALCULATOR
  // ═══════════════════════════════════════════════════════════════

  Widget _buildCalculatorTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSummaryCard(),
          if (_cropsZakatDue + _mineralsZakatDue + _rikazZakatDue > 0) ...[
            const SizedBox(height: 12),
            _buildImmediateZakatSummaryCard(),
          ],
          const SizedBox(height: 16),
          _buildPricesCard(),
          const SizedBox(height: 16),
          _buildCurrencySelector(),
          const SizedBox(height: 16),
          _buildSettingsRow(),
          const SizedBox(height: 16),
          _buildSectionHeader('Gold Karats Breakdown', AppColors.navyBlue),
          const SizedBox(height: 10),
          _buildKaratBreakdownSection(),
          const SizedBox(height: 16),
          _buildSectionHeader('Other Zakatable Assets', AppColors.navyBlue),
          const SizedBox(height: 10),
          _buildInputCard(Icons.account_balance_wallet_outlined, 'Cash & Bank Savings',
              'Cash on hand + accounts', _cashCtrl, _currency.symbol),
          _buildInputCard(Icons.blur_on_outlined, 'Silver (grams)',
              'Silver weight', _silverGramsCtrl, 'g'),
          _buildInputCard(Icons.trending_up_outlined, 'Stocks & Investments',
              'Current stock portfolio value', _stocksCtrl, _currency.symbol),
          _buildInputCard(Icons.store_outlined, 'Business Assets',
              'Commercial stock & inventory value', _businessCtrl, _currency.symbol),
          _buildInputCard(Icons.receipt_long_outlined, 'Receivables',
              'Short-term money owed to you', _receivableCtrl, _currency.symbol),
          _buildInputCard(Icons.home_work_outlined, 'Rental Income (Net)',
              'Annual gross rent minus maintenance costs', _rentalGrossCtrl, _currency.symbol),
          const SizedBox(height: 16),
          // ── Custom Assets ──────────────────────────────────────
          _buildCustomFieldsSection(isLiability: false),
          const SizedBox(height: 16),
          // ── Livestock ──────────────────────────────────────────
          _buildLivestockSection(),
          const SizedBox(height: 16),
          // ── Agricultural Zakat (Ushr) ───────────────────────────
          _buildSectionHeader('Agricultural Zakat — Ushr', const Color(0xFF2E7D32)),
          const SizedBox(height: 10),
          _buildCropsZakatSection(),
          const SizedBox(height: 16),
          // ── Minerals & Rikaz ────────────────────────────────────
          _buildSectionHeader("Minerals (Ma'adin) & Rikaz", AppColors.navyBlue),
          const SizedBox(height: 10),
          _buildMineralsRikazSection(),
          const SizedBox(height: 16),
          // ── Liabilities ────────────────────────────────────────
          _buildSectionHeader('Liabilities', AppColors.coralOrange),
          const SizedBox(height: 10),
          _buildInputCard(Icons.money_off_outlined, 'Liabilities',
              'Debts & outstanding dues to deduct', _liabilitiesCtrl, _currency.symbol),
          const SizedBox(height: 8),
          _buildCustomFieldsSection(isLiability: true),
          const SizedBox(height: 16),
          _buildStatementCard(),
          const SizedBox(height: 16),
          _buildGuidelinesCard(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    String fmt(double v) => _formatCompactMoney(v);

    final haulComplete = _isHaulCompleted;
    final hasActiveAssessment = haulComplete || _haulCycles.isNotEmpty;
    final activeDue = _activeZakatDue;

    // ── LEFT PANEL: "This Year" ───────────────────────────────────────────────
    // If haul is complete OR we have a completed cycle in history → show active zakat
    // Otherwise → show 0 with a Pending badge
    double thisYearAmount;
    String thisYearStatus;
    String thisYearNote;
    Color thisYearAccent;

    if (hasActiveAssessment && activeDue > 0) {
      final remaining = _stillOwed;
      final paid = _totalPaid;

      // Big main number is the amount still to pay
      thisYearAmount = remaining;

      final isPaidInFull = (paid >= activeDue - 1.0) || remaining <= 1.0;

      if (isPaidInFull) {
        thisYearStatus = 'Fully Paid';
        thisYearNote = 'Completed Haul: ${_formatMoney(activeDue)}';
        thisYearAccent = const Color(0xFF81C784);
      } else {
        thisYearStatus = 'Payment Due';
        thisYearNote = 'Completed Haul: ${_formatMoney(activeDue)}';
        thisYearAccent = AppColors.coralOrange;
      }
    } else {
      // Haul is in progress — show Pending (no fixed amount yet)
      thisYearAmount = 0.0;
      thisYearStatus = 'Pending';
      thisYearNote = 'Haul in progress ($_haulElapsedDays / 354 days)';
      thisYearAccent = Colors.amber[200]!;
    }

    // ── RIGHT PANEL: "Next Haul" (live estimate) ─────────────────────────────
    final nextAmount = _zakatEstimate;
    final nextDueDate = _haulStartDate != null
        ? _haulStartDate!.add(const Duration(days: 354))
        : null;
    final nextDateStr = nextDueDate != null
        ? 'Due ${nextDueDate.day} ${_monthName(nextDueDate.month)} ${nextDueDate.year}'
        : '';

    // ── TOP BADGE ─────────────────────────────────────────────────────────────
    final topBadgeText = !hasActiveAssessment
        ? 'Haul In Progress'
        : (thisYearStatus == 'Fully Paid' ? 'Fully Paid' : 'Payment Due');
    final topBadgeColor = !hasActiveAssessment
        ? Colors.amber[200]!
        : (thisYearStatus == 'Fully Paid'
            ? const Color(0xFF81C784)
            : AppColors.coralOrange);
    final topBadgeBg = !hasActiveAssessment
        ? Colors.amber.withValues(alpha: 0.2)
        : (thisYearStatus == 'Fully Paid'
            ? const Color(0xFF4CAF50).withValues(alpha: 0.22)
            : AppColors.coralOrange.withValues(alpha: 0.22));

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isEligible
              ? (thisYearStatus == 'Fully Paid'
                  ? [const Color(0xFF1B4D3E), const Color(0xFF142E24)]
                  : [const Color(0xFF14243B), const Color(0xFF1C3A27)])
              : [const Color(0xFF14243B), const Color(0xFF22364A)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: _isDarkMode ? Colors.white.withValues(alpha: 0.22) : AppColors.navyBlue.withValues(alpha: 0.22),
              blurRadius: 18,
              offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: CardBackgroundPainter(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Zakat Timeline',
                        style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: topBadgeBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          topBadgeText,
                          style: GoogleFonts.inter(
                              color: topBadgeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _buildZakatPeriodPanel(
                            title: 'Completed Haul',
                            icon: Icons.receipt_long_rounded,
                            amount: hasActiveAssessment && activeDue > 0
                                ? (thisYearStatus == 'Fully Paid' || thisYearAmount <= 0
                                    ? 'Fully Paid'
                                    : _formatMoney(thisYearAmount))
                                : '—',
                            status: thisYearStatus,
                            note: thisYearNote,
                            accent: thisYearAccent,
                            livestockSummary: _lockedLivestockSummary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildZakatPeriodPanel(
                            title: 'Next Haul',
                            icon: Icons.hourglass_top_rounded,
                            amount: _formatMoney(nextAmount),
                            status: 'Estimate',
                            note: nextDateStr,
                            accent: AppColors.midTeal,
                            livestockSummary: _livestockZakatSummary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                          child: _buildStatChip('Net Zakatable', fmt(_totalWealth),
                              Icons.account_balance_wallet_rounded)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _buildStatChip(
                              'Nisab (${_nisabStandard == "gold" ? "85g Gold" : "595g Silver"})',
                              fmt(_nisabBDT),
                              Icons.stars_rounded)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImmediateZakatSummaryCard() {
    final cropsDue = _cropsZakatDue;
    final mineralsDue = _mineralsZakatDue;
    final rikazDue = _rikazZakatDue;
    final totalImmediate = _immediateTotalDue;
    final paid = _immediatePaid;
    final remaining = _immediateStillOwed;
    final isFullyPaid = remaining <= 1.0 && paid > 0;

    // Show when there is any obligation OR any payment was made
    if (totalImmediate <= 0 && paid <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isFullyPaid
              ? [const Color(0xFF0D2B1A), const Color(0xFF1A3D2B)]
              : [const Color(0xFF0F3024), const Color(0xFF1B4D3E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B4D3E).withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isFullyPaid ? Icons.check_circle_rounded : Icons.bolt_rounded,
                  color: isFullyPaid ? const Color(0xFF81C784) : Colors.amber,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isFullyPaid ? 'Immediate Zakat — Fully Paid' : 'Immediate Zakat Due (No Haul)',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      isFullyPaid
                          ? 'Crops, Minerals & Rikaz obligations cleared'
                          : 'Due today upon harvest, extraction, or discovery',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isFullyPaid && remaining > 0)
                GestureDetector(
                  onTap: () {
                    setState(() => _tab = 4);
                    _showAddPaymentDialog(
                      isFitra: false,
                      prefilledObligationType: cropsDue > 0 ? 'crops' : (mineralsDue > 0 ? 'minerals' : 'rikaz'),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Pay Now →',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navyBlue,
                      ),
                    ),
                  ),
                ),
              if (isFullyPaid)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF81C784).withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    'Fully Paid',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF81C784),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Stats: Total Due | Paid | Remaining
          Row(
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Total Due', style: GoogleFonts.inter(color: Colors.white54, fontSize: 9.5)),
                  const SizedBox(height: 2),
                  Text(
                    _formatMoney(totalImmediate),
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ]),
              ),
              Container(width: 1, height: 34, color: Colors.white12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Paid', style: GoogleFonts.inter(color: Colors.white54, fontSize: 9.5)),
                    const SizedBox(height: 2),
                    Text(
                      _formatMoney(paid),
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF81C784),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ]),
                ),
              ),
              Container(width: 1, height: 34, color: Colors.white12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Remaining', style: GoogleFonts.inter(color: Colors.white54, fontSize: 9.5)),
                    const SizedBox(height: 2),
                    Text(
                      isFullyPaid ? 'None' : _formatMoney(remaining),
                      style: GoogleFonts.poppins(
                        color: isFullyPaid ? const Color(0xFF81C784) : Colors.amber,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
          if (!isFullyPaid && totalImmediate > 0) ...[  
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (cropsDue > 0)
                  _buildImmediateItemBadge('Crops (Ushr)', cropsDue, const Color(0xFF81C784)),
                if (mineralsDue > 0)
                  _buildImmediateItemBadge('Minerals', mineralsDue, const Color(0xFF81D4FA)),
                if (rikazDue > 0)
                  _buildImmediateItemBadge('Rikaz', rikazDue, const Color(0xFFFFB74D)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImmediateItemBadge(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$label: ${_formatMoney(amount)}',
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildZakatPeriodPanel({
    required String title,
    required IconData icon,
    required String amount,
    required String status,
    required String note,
    required Color accent,
    String? livestockSummary,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: _isDarkMode ? 0.08 : 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Icon + Title
          Row(
            children: [
              Icon(icon, color: accent, size: 14),
              const SizedBox(width: 5),
              Text(
                title,
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Row 2: Status badge on its own line
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: GoogleFonts.inter(
                color: accent,
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Row 3: Amount (large)
          Text(
            amount,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (livestockSummary != null && livestockSummary.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '+ $livestockSummary',
              style: GoogleFonts.inter(
                color: const Color(0xFFA5D6A7),
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 3),
          // Row 4: Note
          Text(
            note,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 9.5,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white60, size: 12),
              const SizedBox(width: 4),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        color: Colors.white60,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.poppins(
                  color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPricesCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.analytics_rounded, color: _isDarkMode ? Colors.white : AppColors.navyBlue, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Metal Rates (${_currency.code}/g)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _pricesLoading
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.navyBlue)))
                      : Flexible(
                          child: Tooltip(
                            message: _priceFetchError ?? 'Live price source: $_pricesLastUpdated',
                            child: Text(
                              _priceFetchError == null
                                  ? 'Updated: $_pricesLastUpdated'
                                  : 'Live price unavailable',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                  color: _priceFetchError == null
                                      ? const Color(0xFF2E7D32)
                                      : AppColors.coralOrange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                  const SizedBox(width: 2),
                  Tooltip(
                    message: 'Refresh live metal prices',
                    child: IconButton(
                      onPressed: _pricesLoading ? null : _fetchLivePrices,
                      icon: const Icon(Icons.refresh_rounded),
                      iconSize: 13,
                      color: _isDarkMode ? AppColors.midTeal : AppColors.navyBlue,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(width: 20, height: 20),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                  child: _buildSparklineCol('24K Gold Rate', _effectiveGoldPrice,
                      _goldHistory, const Color(0xFFB59410))),
              const SizedBox(width: 20),
              Expanded(
                  child: _buildSparklineCol('Pure Silver Rate', _effectiveSilverPrice,
                      _silverHistory, const Color(0xFF78909C))),
            ],
          ),
          const Divider(height: 24, thickness: 1, color: Color(0xFFEEEEEE)),

          // Manual Override toggles
          GestureDetector(
            onTap: () {
              setState(() {
                _manualOverridePrices = !_manualOverridePrices;
                if (!_manualOverridePrices) {
                  _manualGoldPriceCtrl.text = (_goldPerGramBDT / _toBDT).toStringAsFixed(2);
                  _manualSilverPriceCtrl.text = (_silverPerGramBDT / _toBDT).toStringAsFixed(2);
                }
              });
              _recalculate();
              _savePrefs();
            },
            child: Row(
              children: [
                Icon(
                  _manualOverridePrices
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  color: _isDarkMode ? Colors.white : AppColors.navyBlue,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text('Manual Override Price per Gram',
                    style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
              ],
            ),
          ),
          if (_manualOverridePrices) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildOverrideField(
                      _manualGoldPriceCtrl, '24K Gold (${_currency.code}/g)', () => _recalculate()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOverrideField(_manualSilverPriceCtrl, 'Silver (${_currency.code}/g)',
                      () => _recalculate()),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverrideField(
      TextEditingController ctrl, String label, VoidCallback onChanged) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => onChanged(),
      style: GoogleFonts.poppins(
          fontSize: 12.5, fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : AppColors.navyBlue),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 11, color: AppColors.placeholder),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        filled: true,
        fillColor: _isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF5F7FA),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildSparklineCol(String label, double price, List<double> hist, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11, color: _isDarkMode ? Colors.white.withValues(alpha: 0.5) : AppColors.navyBlue.withValues(alpha: 0.5))),
        const SizedBox(height: 3),
        Text('${_formatMoney(price, fractionDigits: 1)}/g',
            style: GoogleFonts.poppins(
                fontSize: 14.5, fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
        const SizedBox(height: 8),
        SizedBox(
            height: 24,
            width: double.infinity,
            child: CustomPaint(painter: _SparklinePainter(data: hist, lineColor: color))),
      ],
    );
  }

  Widget _buildCurrencySelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.currency_exchange_rounded, color: _isDarkMode ? Colors.white : AppColors.navyBlue, size: 16),
              const SizedBox(width: 8),
              Text('Input & Display Currency',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 13, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _currencies.map((c) {
              final active = c.code == _selectedCurrency;
              return GestureDetector(
                onTap: () {
                  _changeCurrency(c.code);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? AppColors.navyBlue : const Color(0xFFF0F2F5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${c.symbol} ${c.code}',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: active
                              ? Colors.white
                              : AppColors.navyBlue.withValues(alpha: 0.65))),
                ),
              );
            }).toList(),
          ),
          if (_selectedCurrency != 'BDT') ...[
            const SizedBox(height: 8),
            Text('1 ${_currency.symbol} ≈ Tk ${_toBDT.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                    fontSize: 10.5, color: _isDarkMode ? Colors.white.withValues(alpha: 0.45) : AppColors.navyBlue.withValues(alpha: 0.45))),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingsRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings_rounded, color: _isDarkMode ? Colors.white : AppColors.navyBlue, size: 16),
              const SizedBox(width: 8),
              Text('Configuration',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 13, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
            ],
          ),
          const SizedBox(height: 12),
          Text('Nisab Calculation Standard',
              style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: _isDarkMode ? Colors.white.withValues(alpha: 0.7) : AppColors.navyBlue.withValues(alpha: 0.7))),
          const SizedBox(height: 6),
          Row(
            children: ['gold', 'silver'].map((s) {
              final active = s == _nisabStandard;
              return GestureDetector(
                onTap: () {
                  setState(() => _nisabStandard = s);
                  _recalculate();
                  _savePrefs();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? AppColors.navyBlue : const Color(0xFFF0F2F5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(s == 'gold' ? 'Gold (85g)' : 'Silver (595g)',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: active
                              ? Colors.white
                              : AppColors.navyBlue.withValues(alpha: 0.65))),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildKaratBreakdownSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Gold weights vary by purity (Karat). We calculate the pure gold weight equivalent:',
            style: GoogleFonts.inter(
                fontSize: 11.5,
                color: _isDarkMode ? Colors.white.withValues(alpha: 0.6) : AppColors.navyBlue.withValues(alpha: 0.6),
                height: 1.4),
          ),
          const SizedBox(height: 14),
          _buildKaratInputField('24K Gold grams (100% pure)', _gold24kCtrl),
          _buildKaratInputField('22K Gold grams (91.6% pure)', _gold22kCtrl),
          _buildKaratInputField('21K Gold grams (87.5% pure)', _gold21kCtrl),
          _buildKaratInputField('18K Gold grams (75.0% pure)', _gold18kCtrl),
          const Divider(height: 20, thickness: 1, color: Color(0xFFEEEEEE)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Equivalent Pure (24K) Gold Weight:',
                  style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _isDarkMode ? Colors.white.withValues(alpha: 0.7) : AppColors.navyBlue.withValues(alpha: 0.7))),
              Text('${_pureGoldEquivalentGrams.toStringAsFixed(2)} g',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Calculated Gold Value:',
                  style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _isDarkMode ? Colors.white.withValues(alpha: 0.7) : AppColors.navyBlue.withValues(alpha: 0.7))),
              Text(
                _formatMoney(_pureGoldEquivalentGrams * _effectiveGoldPrice),
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.midTeal),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKaratInputField(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: GoogleFonts.inter(fontSize: 12, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                  fontSize: 12.5, fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : AppColors.navyBlue),
              decoration: InputDecoration(
                suffixText: ' g',
                suffixStyle: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _isDarkMode ? Colors.white.withValues(alpha: 0.4) : AppColors.navyBlue.withValues(alpha: 0.4)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                filled: true,
                fillColor: _isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF5F7FA),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color accent) {
    return Row(
      children: [
        Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Text(title,
            style: GoogleFonts.poppins(
                fontSize: 14.5, fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
      ],
    );
  }

  Widget _buildInputCard(
      IconData icon, String label, String sub, TextEditingController ctrl, String suffix) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: _cardDeco(),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: _isDarkMode ? Colors.white.withValues(alpha: 0.12) : AppColors.navyBlue.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: _isDarkMode ? Colors.white : AppColors.navyBlue, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.w600, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
                Text(sub,
                    style: GoogleFonts.inter(
                        fontSize: 9.5,
                        color: _isDarkMode ? Colors.white70 : AppColors.navyBlue.withValues(alpha: 0.45))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                  fontSize: 12.5, fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : AppColors.navyBlue),
              decoration: InputDecoration(
                suffixText: ' $suffix',
                suffixStyle: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _isDarkMode ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.4)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                filled: true,
                fillColor: _isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF5F7FA),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatementCard() {
    final rate = _toBDT;
    final cash = (double.tryParse(_cashCtrl.text.replaceAll(',', '')) ?? 0) * rate;
    final pureGold = _pureGoldEquivalentGrams;
    final silverGrams = double.tryParse(_silverGramsCtrl.text.replaceAll(',', '')) ?? 0;

    final goldVal = pureGold * _effectiveGoldPrice;
    final silverVal = silverGrams * _effectiveSilverPrice;

    final stocks = (double.tryParse(_stocksCtrl.text.replaceAll(',', '')) ?? 0) * rate;
    final business = (double.tryParse(_businessCtrl.text.replaceAll(',', '')) ?? 0) * rate;
    final receivable = (double.tryParse(_receivableCtrl.text.replaceAll(',', '')) ?? 0) * rate;
    final liabilities = (double.tryParse(_liabilitiesCtrl.text.replaceAll(',', '')) ?? 0) * rate;
    final gross = cash + goldVal + silverVal + stocks + business + receivable;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_outlined, color: _isDarkMode ? Colors.white : AppColors.navyBlue, size: 18),
              const SizedBox(width: 8),
              Text('Wealth Statement',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 13.5, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
            ],
          ),
          const SizedBox(height: 16),
          _stmtLine('Cash & Bank', cash),
          _stmtLine('Gold (${pureGold.toStringAsFixed(1)}g equivalent)', goldVal),
          _stmtLine('Silver (${silverGrams.toStringAsFixed(1)}g)', silverVal),
          _stmtLine('Stocks & Investments', stocks),
          _stmtLine('Business Assets', business),
          _stmtLine('Receivables', receivable),
          const Divider(height: 22, thickness: 1, color: Color(0xFFEEEEEE)),
          _stmtLine('Total Gross Assets', gross, bold: true),
          _stmtLine('Less: Liabilities', liabilities, isDeduction: true),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
                color: _isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF1F5FB), borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Net Zakatable Wealth',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 12, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
                Text(_formatMoney(_totalWealth),
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 13, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1B4D3E), Color(0xFF142E24)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Zakat Due (2.5%)',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatMoney(_zakatDue),
                        textAlign: TextAlign.end,
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                      ),
                      if (_livestockZakatSummary.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '+ $_livestockZakatSummary',
                          textAlign: TextAlign.end,
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600, fontSize: 11, color: const Color(0xFFA5D6A7)),
                        ),
                        Text(
                          '(or equivalent value)',
                          textAlign: TextAlign.end,
                          style: GoogleFonts.inter(fontSize: 9, color: Colors.white70),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stmtLine(String label, double value,
      {bool bold = false, bool isDeduction = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                    color: _isDarkMode ? Colors.white70 : AppColors.navyBlue.withValues(alpha: bold ? 0.85 : 0.6))),
          ),
          Text(
            '${isDeduction ? '- ' : ''}${_formatMoney(value)}',
            style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                color: isDeduction
                    ? AppColors.coralOrange
                    : (_isDarkMode ? Colors.white : AppColors.navyBlue.withValues(alpha: 0.75))),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidelinesCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _isDarkMode ? Colors.white.withValues(alpha: 0.12) : AppColors.dustyBlueTeal.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: _isDarkMode ? AppColors.midTeal : AppColors.navyBlue, size: 16),
              const SizedBox(width: 8),
              Text('Obligatory Guidelines',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 13, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
            ],
          ),
          const SizedBox(height: 10),
          _bullet(
              'Zakat is obligatory on Muslims who own wealth above the Nisab for one full lunar year (Hawl).'),
          _bullet(
              'The Nisab threshold is 85g of pure gold or 595g of pure silver. Select your standard from configurations.'),
          _bullet('Zakat is payable at the rate of 2.5% on all net qualifying assets.'),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(color: AppColors.midTeal, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(text,
                style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: _isDarkMode ? Colors.white.withValues(alpha: 0.68) : AppColors.navyBlue.withValues(alpha: 0.68),
                    height: 1.5)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CUSTOM ASSET / LIABILITY FIELDS
  // ─────────────────────────────────────────────────────────────

  Widget _buildCustomFieldsSection({required bool isLiability}) {
    final list = isLiability ? _customLiabilities : _customAssets;
    final color = isLiability ? AppColors.coralOrange : (_isDarkMode ? Colors.white : AppColors.navyBlue);
    final label = isLiability ? 'Custom Liabilities' : 'Custom Assets';
    final hint = isLiability
        ? 'e.g. Loan, Credit Card, Mortgage…'
        : 'e.g. Property Value, Rental Income, Crypto…';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: color)),
                  Text(hint,
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          color: color.withValues(alpha: 0.45))),
                ],
              ),
            ),
            InkWell(
              onTap: () => _showAddCustomFieldDialog(isLiability: isLiability),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: color, size: 15),
                    const SizedBox(width: 4),
                    Text('Add Field',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: color)),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (list.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...list.map((asset) => _buildCustomAssetRow(asset, isLiability: isLiability)),
        ],
      ],
    );
  }

  Widget _buildCustomAssetRow(_CustomAsset asset, {required bool isLiability}) {
    final color = isLiability ? AppColors.coralOrange : (_isDarkMode ? Colors.white : AppColors.navyBlue);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isLiability ? Icons.remove_circle_outline_rounded : Icons.add_box_outlined,
              color: color, size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(asset.name,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
                Text(_formatMoney(asset.value * _currencyRate(asset.currency)),
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: _isDarkMode ? Colors.white70 : AppColors.navyBlue.withValues(alpha: 0.5))),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              final confirm = await _confirmDeletion('Remove "${asset.name}"?');
              if (confirm) {
                setState(() {
                  if (isLiability) {
                    _customLiabilities.removeWhere((a) => a.id == asset.id);
                  } else {
                    _customAssets.removeWhere((a) => a.id == asset.id);
                  }
                });
                _recalculate();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.coralOrange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.coralOrange, size: 15),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCustomFieldDialog({required bool isLiability}) {
    final nameCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    String currency = _selectedCurrency;
    final color = isLiability ? AppColors.coralOrange : AppColors.navyBlue;
    final label = isLiability ? 'Custom Liability' : 'Custom Asset';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 430),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          decoration: BoxDecoration(
            color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Add $label',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 16, color: color)),
              const SizedBox(height: 4),
              Text(
                isLiability
                    ? 'e.g. Home Loan, Credit Card Debt, Car Finance…'
                    : 'e.g. Property Value, Livestock Value, Rental Income, Crypto…',
                style: GoogleFonts.inter(
                    fontSize: 11, color: _isDarkMode ? Colors.white.withValues(alpha: 0.45) : AppColors.navyBlue.withValues(alpha: 0.45)),
              ),
              const SizedBox(height: 16),
              _sheetField(nameCtrl, 'Field Name (e.g. Property Value)'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _sheetField(valueCtrl, 'Amount',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                  ),
                  const SizedBox(width: 10),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: currency,
                      dropdownColor: _isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _isDarkMode ? Colors.white : AppColors.navyBlue),
                      onChanged: (v) => setModal(() => currency = v!),
                      items: _currencies
                          .map((c) => DropdownMenuItem(
                                value: c.code,
                                child: Text(c.code),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              InkWell(
                onTap: () {
                  final name = nameCtrl.text.trim();
                  final value = double.tryParse(valueCtrl.text) ?? 0;
                  if (name.isEmpty || value <= 0) return;
                  final asset = _CustomAsset(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    value: value,
                    currency: currency,
                    isLiability: isLiability,
                  );
                  setState(() {
                    if (isLiability) {
                      _customLiabilities.add(asset);
                    } else {
                      _customAssets.add(asset);
                    }
                  });
                  _recalculate();
                  if (Navigator.canPop(ctx)) {
                    Navigator.pop(ctx);
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text('Add $label',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LIVESTOCK ZAKAT SECTION
  // ─────────────────────────────────────────────────────────────

  Widget _buildLivestockSection() {
    final camelZakat = _computeCamelZakat(_livestockCamels);
    final cattleZakat = _computeCattleZakat(_livestockCattle);
    final sheepZakat = _computeSheepZakat(_livestockSheep);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _isDarkMode ? Colors.white.withValues(alpha: 0.12) : AppColors.navyBlue.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.pets_rounded, color: Color(0xFF2E7D32), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Livestock Zakat',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
                    Text('Each type has its own Nisab threshold',
                        style: GoogleFonts.inter(
                            fontSize: 10.5,
                            color: _isDarkMode ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.5))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildAnimalRow(
            icon: Icons.landscape_outlined,
            label: 'Camels',
            count: _livestockCamels,
            nisab: 5,
            zakatText: camelZakat,
            onDecrement: () {
              if (_livestockCamels > 0) {
                setState(() => _livestockCamels--);
                _recalculate();
              }
            },
            onIncrement: () {
              setState(() => _livestockCamels++);
              _recalculate();
            },
          ),
          const Divider(height: 20, color: Color(0xFFEEEEEE)),
          _buildAnimalRow(
            icon: Icons.agriculture_outlined,
            label: 'Cattle / Buffalo',
            count: _livestockCattle,
            nisab: 30,
            zakatText: cattleZakat,
            onDecrement: () {
              if (_livestockCattle > 0) {
                setState(() => _livestockCattle--);
                _recalculate();
              }
            },
            onIncrement: () {
              setState(() => _livestockCattle++);
              _recalculate();
            },
          ),
          const Divider(height: 20, color: Color(0xFFEEEEEE)),
          _buildAnimalRow(
            icon: Icons.grass_outlined,
            label: 'Sheep / Goats',
            count: _livestockSheep,
            nisab: 40,
            zakatText: sheepZakat,
            onDecrement: () {
              if (_livestockSheep > 0) {
                setState(() => _livestockSheep--);
                _recalculate();
              }
            },
            onIncrement: () {
              setState(() => _livestockSheep++);
              _recalculate();
            },
          ),
          if (_livestockMeetsNisab) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Color(0xFF2E7D32), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Livestock Zakat is fulfilled by giving the specified animal(s) or paying their equivalent market value to eligible recipients.',
                      style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color: const Color(0xFF2E7D32),
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnimalRow({
    required IconData icon,
    required String label,
    required int count,
    required int nisab,
    required String zakatText,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    final meetsNisab = count >= nisab;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: _isDarkMode ? Colors.white.withValues(alpha: 0.6) : AppColors.navyBlue.withValues(alpha: 0.6), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                          color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
                  Text(
                    meetsNisab
                        ? 'Nisab met ($nisab+) · Zakat due'
                        : 'Nisab: $nisab animals minimum (you have $count)',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: meetsNisab
                          ? const Color(0xFF2E7D32)
                          : (_isDarkMode ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.4)),
                      fontWeight: meetsNisab ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            // Counter
            Row(
              children: [
                _iconBtn(Icons.remove_rounded, onDecrement),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('$count',
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
                ),
                _iconBtn(Icons.add_rounded, onIncrement),
              ],
            ),
          ],
        ),
        if (meetsNisab && zakatText.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Zakat due: $zakatText (or equivalent monetary value)',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF2E7D32),
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Camel Zakat calculation per classical Hanafi/Shafi'i fiqh tiers.
  String _computeCamelZakat(int n) {
    if (n < 5) return '';
    if (n <= 9) return '1 Sheep/Goat';
    if (n <= 14) return '2 Sheep/Goats';
    if (n <= 19) return '3 Sheep/Goats';
    if (n <= 24) return '4 Sheep/Goats';
    if (n <= 35) return '1 Bint Makhad (1-yr female camel)';
    if (n <= 45) return '1 Bint Labun (2-yr female camel)';
    if (n <= 60) return '1 Hiqqah (3-yr female camel)';
    if (n <= 75) return '1 Jadh\'ah (4-yr female camel)';
    if (n <= 90) return '2 Bint Labun';
    if (n <= 120) return '2 Hiqqah';
    final labun = (n ~/ 40);
    final hiqqah = (n ~/ 50);
    return '$labun Bint Labun + $hiqqah Hiqqah';
  }

  /// Cattle Zakat per classical fiqh tiers.
  String _computeCattleZakat(int n) {
    if (n < 30) return '';
    if (n <= 39) return '1 Tabi\' (1-yr calf)';
    if (n <= 59) return '1 Musinnah (2-yr cow)';
    if (n <= 69) return '2 Tabi\'';
    if (n <= 79) return '1 Musinnah + 1 Tabi\'';
    if (n <= 89) return '2 Musinnah';
    final tabi = (n ~/ 30);
    final musinnah = (n ~/ 40);
    return '$tabi Tabi\' + $musinnah Musinnah';
  }

  /// Sheep/Goat Zakat per classical fiqh tiers.
  String _computeSheepZakat(int n) {
    if (n < 40) return '';
    if (n <= 120) return '1 Sheep/Goat';
    if (n <= 200) return '2 Sheep/Goats';
    if (n <= 300) return '3 Sheep/Goats';
    return '${(n ~/ 100)} Sheep/Goats';
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 1 — HAUL TRACKER
  // ═══════════════════════════════════════════════════════════════


  void _checkAutoRollover() {
    if (_haulStartDate == null) return;
    final now = DateTime.now();
    bool rolled = false;
    while (_haulStartDate != null && now.difference(_haulStartDate!).inDays >= 354) {
      final cycleEnd = _haulStartDate!.add(const Duration(days: 354));
      final lockedZakat = (_totalWealth >= _nisabBDT && _nisabBDT > 0) ? _totalWealth * 0.025 : 0.0;
      final cycle = HaulCycle(
        cycleNumber: _currentHaulCycleNumber,
        startDate: _haulStartDate!,
        endDate: cycleEnd,
        wealthAtCompletion: _totalWealth,
        lockedZakat: lockedZakat,
        lockedLivestockSummary: _livestockZakatSummary.isNotEmpty ? _livestockZakatSummary : null,
      );
      _haulCycles.add(cycle);
      _haulStartDate = cycleEnd;
      _currentHaulCycleNumber++;
      rolled = true;
    }
    if (rolled) {
      _savePrefs();
    }
  }

  Widget _buildHaulTab() {
    _checkAutoRollover();
    final now = DateTime.now();
    final int elapsed = _haulStartDate != null ? now.difference(_haulStartDate!).inDays : 0;
    const int haulDays = 354;
    final double progress = (elapsed / haulDays).clamp(0.0, 1.0);
    final bool haulComplete = elapsed >= haulDays;
    final DateTime? dueGregorianDate =
        _haulStartDate?.add(const Duration(days: haulDays));
    final _Hijri? dueHijri =
        dueGregorianDate != null ? _Hijri.fromGregorian(dueGregorianDate) : null;
    final _Hijri todayHijri = _Hijri.fromGregorian(now);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDeco(),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.midTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.notifications_active_rounded,
                      color: AppColors.midTeal, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nisab Crossing Alerts',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
                      Text('Get notified when wealth drops below or crosses Nisab',
                          style: GoogleFonts.inter(
                              fontSize: 10.5, color: _isDarkMode ? Colors.white.withValues(alpha: 0.5) : AppColors.navyBlue.withValues(alpha: 0.5))),
                    ],
                  ),
                ),
                Switch(
                  value: _nisabAlertEnabled,
                  onChanged: (v) {
                    setState(() => _nisabAlertEnabled = v);
                    _savePrefs();
                  },
                  activeThumbColor: AppColors.midTeal,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDeco(),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isDarkMode ? Colors.white.withValues(alpha: 0.08) : AppColors.navyBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.calendar_month_rounded, color: _isDarkMode ? Colors.white : AppColors.navyBlue, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Today (Hijri)',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: _isDarkMode ? Colors.white.withValues(alpha: 0.5) : AppColors.navyBlue.withValues(alpha: 0.5))),
                    Text(todayHijri.toString(),
                        style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: haulComplete
                    ? [const Color(0xFF14243B), const Color(0xFF1C3A27)]
                    : [const Color(0xFF14243B), const Color(0xFF22364A)],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                    color: _isDarkMode ? Colors.white.withValues(alpha: 0.22) : AppColors.navyBlue.withValues(alpha: 0.22),
                    blurRadius: 18,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Haul Progress',
                        style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: haulComplete
                            ? const Color(0xFF4CAF50).withValues(alpha: 0.22)
                            : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(haulComplete ? 'Zakat Due' : 'In Progress',
                          style: GoogleFonts.inter(
                              color: haulComplete ? const Color(0xFF81C784) : Colors.white60,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text('$elapsed / $haulDays days',
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(
                        haulComplete ? const Color(0xFF81C784) : AppColors.midTeal),
                  ),
                ),
                const SizedBox(height: 14),
                if (dueGregorianDate != null && dueHijri != null)
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatChip(
                            'Zakat Due Date',
                            DateFormat('d MMM yyyy').format(dueGregorianDate),
                            Icons.event_rounded),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatChip('Due Date (Hijri)', dueHijri.toString(),
                            Icons.calendar_today_rounded),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: _cardDeco(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.edit_calendar_rounded, color: _isDarkMode ? Colors.white : AppColors.navyBlue, size: 18),
                    const SizedBox(width: 8),
                    Text('Nisab Crossing Date',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                    'Set the date your wealth first crossed the Nisab threshold. This starts the Haul clock.',
                    style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: _isDarkMode ? Colors.white.withValues(alpha: 0.55) : AppColors.navyBlue.withValues(alpha: 0.55),
                        height: 1.5)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: _isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF5F7FA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _haulStartDate != null
                              ? DateFormat('d MMM yyyy').format(_haulStartDate!)
                              : 'Not set (tap Set Date)',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _haulStartDate != null
                                  ? (_isDarkMode ? Colors.white : AppColors.navyBlue)
                                  : (_isDarkMode ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.35))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _navyButton('Set Date', Icons.edit_rounded, () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _haulStartDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                        builder: (ctx, child) => Theme(
                          data: ThemeData.light().copyWith(
                            colorScheme: const ColorScheme.light(
                                primary: AppColors.navyBlue, onSurface: AppColors.navyBlue),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        final p = await SharedPreferences.getInstance();
                        await p.remove('zm_haul_fulfilled_notified');
                        setState(() => _haulStartDate = picked);
                        _savePrefs();
                      }
                    }),
                    if (_haulStartDate != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () async {
                          final confirm = await _confirmDeletion(
                              'Are you sure you want to reset and clear the Haul start date?');
                          if (confirm) {
                            final p = await SharedPreferences.getInstance();
                            await p.remove('zm_haul_fulfilled_notified');
                            setState(() => _haulStartDate = null);
                            _savePrefs();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.coralOrange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: AppColors.coralOrange, size: 16),
                        ),
                      ),
                    ],
                  ],
                ),
                if (_haulStartDate != null) ...[
                  const SizedBox(height: 8),
                  Text('Hijri start: ${_Hijri.fromGregorian(_haulStartDate!)}',
                      style: GoogleFonts.inter(
                          fontSize: 10.5, color: _isDarkMode ? Colors.white.withValues(alpha: 0.5) : AppColors.navyBlue.withValues(alpha: 0.5))),
                ],
              ],
            ),
          ),
          if (_haulCycles.isNotEmpty || _haulStartDate != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: _cardDeco(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.history_rounded, color: _isDarkMode ? Colors.white : AppColors.navyBlue, size: 18),
                      const SizedBox(width: 8),
                      Text('Haul Cycle History',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Completed cycles (most recent first)
                  ...(_haulCycles.reversed.map((cycle) => _buildHaulCycleRow(cycle))),
                  // Current in-progress cycle
                  if (_haulStartDate != null && !_isHaulCompleted)
                    _buildCurrentHaulRow(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHaulCycleRow(HaulCycle cycle) {
    final startStr = DateFormat('d MMM yyyy').format(cycle.startDate);
    final endStr = DateFormat('d MMM yyyy').format(cycle.endDate);
    // If lockedZakat was archived as 0 (due to prices not loaded at that time),
    // recover from wealthAtCompletion using 2.5% rule
    final displayZakat = cycle.lockedZakat > 0
        ? cycle.lockedZakat
        : (cycle.wealthAtCompletion > 0 ? cycle.wealthAtCompletion * 0.025 : 0.0);
    final isRecovered = cycle.lockedZakat == 0 && cycle.wealthAtCompletion > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E2D3D) : const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '${cycle.cycleNumber}',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: const Color(0xFF4CAF50)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Haul Cycle ${cycle.cycleNumber}',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
                const SizedBox(height: 2),
                Text('$startStr → $endStr',
                    style: GoogleFonts.inter(
                        fontSize: 10.5,
                        color: _isDarkMode ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.55))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_formatMoney(displayZakat),
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: const Color(0xFF4CAF50))),
              Text(isRecovered ? 'Est. (2.5%)' : 'Zakat locked',
                  style: GoogleFonts.inter(fontSize: 9.5, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentHaulRow() {
    final startStr = _haulStartDate != null
        ? DateFormat('d MMM yyyy').format(_haulStartDate!)
        : '—';
    final dueDate = _haulStartDate?.add(const Duration(days: 354));
    final dueDateStr = dueDate != null ? DateFormat('d MMM yyyy').format(dueDate) : '—';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E2D3D) : const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '$_currentHaulCycleNumber',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.amber[700]),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Haul Cycle $_currentHaulCycleNumber (Current)',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
                const SizedBox(height: 2),
                Text('Started $startStr · Due $dueDateStr',
                    style: GoogleFonts.inter(
                        fontSize: 10.5,
                        color: _isDarkMode ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.55))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_formatMoney(_zakatEstimate),
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.amber[700])),
              Text('Estimate',
                  style: GoogleFonts.inter(fontSize: 9.5, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 2 — RULES OF ZAKAT (أَحْكَامُ الزَّكَاةِ)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildRulesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B4D3E), Color(0xFF0D281E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1B4D3E).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Islamic Rules of Zakat',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'أَحْكَامُ الزَّكَاةِ فِي الشَّرِيعَةِ الإِسْلَامِيَّةِ',
                            style: GoogleFonts.amiri(
                              color: const Color(0xFFA5D6A7),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Zakat is the 3rd Pillar of Islam — an obligatory act of worship and charity purifying wealth and supporting the needy.',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 11.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 1. Obligation of Zakat
          _buildRuleSectionCard(
            title: '1. Obligation of Zakat',
            subtitle: 'The 3rd Pillar of Islam',
            icon: Icons.star_rounded,
            iconColor: const Color(0xFF1B4D3E),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paying Zakat is mandatory (Fard) upon every sane, adult Muslim who possesses Nisab-threshold wealth for one full lunar year (Hawl).',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.45,
                    color: _isDarkMode ? Colors.white.withValues(alpha: 0.9) : AppColors.navyBlue,
                  ),
                ),
                _buildQuranReferenceCard(
                  arabicText: 'وَأَقِيمُوا الصَّلَاةَ وَآتُوا الزَّكَاةَ وَارْكَعُوا مَعَ الرَّاكِعِينَ',
                  englishText: 'And establish prayer and give Zakat and bow with those who bow [in worship].',
                  reference: 'Quran - Surah Al-Baqarah (2:43)',
                ),
                _buildHadithReferenceCard(
                  arabicText: 'بُنِيَ الإِسْلاَمُ عَلَى خَمْسٍ: شَهَادَةِ أَنْ لاَ إِلَهَ إِلاَّ اللَّهُ وَأَنَّ مُحَمَّدًا رَسُولُ اللَّهِ، وَإِقَامِ الصَّلاَةِ، وَإِيتَاءِ الزَّكَاةِ، وَالحَجِّ، وَصَوْمِ رَمَضَانَ',
                  englishText: 'Islam is built upon five pillars: Testifying that there is no god but Allah and that Muhammad is the Messenger of Allah, establishing prayer, paying Zakat, performing Hajj, and fasting Ramadan.',
                  reference: 'Sahih al-Bukhari (8), Sahih Muslim (16)',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Conditions of Zakat
          _buildRuleSectionCard(
            title: '2. Conditions of Zakat (Shurut)',
            subtitle: 'When Zakat becomes obligatory',
            icon: Icons.rule_folder_rounded,
            iconColor: Colors.deepOrange,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBulletPoint('1. Islam & Freedom: Must be a Muslim possessing ownership.'),
                _buildBulletPoint('2. Nisab Threshold: Net wealth must meet or exceed the Nisab minimum.'),
                _buildBulletPoint('3. Completion of Hawl: Wealth must be held for 1 full lunar year (354 days).'),
                _buildBulletPoint('4. Fully Owned & Productive: Wealth must be unencumbered by immediate essential debts.'),
                _buildHadithReferenceCard(
                  arabicText: 'لاَ زَكَاةَ فِي مَالٍ حَتَّى يَحُولَ عَلَيْهِ الْحَوْلُ',
                  englishText: 'No Zakat is due on wealth until a full lunar year (Hawl) has passed over it.',
                  reference: 'Sunan Ibn Majah (1789), Sunan al-Tirmidhi (631)',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Monetary & Asset Nisab
          _buildRuleSectionCard(
            title: '3. Gold, Silver, Cash & Business Assets',
            subtitle: 'Nisab values & standard 2.5% rate',
            icon: Icons.monetization_on_rounded,
            iconColor: Colors.amber.shade800,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNisabTable(),
                const SizedBox(height: 8),
                Text(
                  'Rate of Zakat on Cash, Gold, Silver, Stocks, Trade Inventory, & Business Net Assets is exactly 2.5% (1/40th) of net value.',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    height: 1.4,
                    color: _isDarkMode ? Colors.white.withValues(alpha: 0.9) : AppColors.navyBlue,
                  ),
                ),
                _buildHadithReferenceCard(
                  arabicText: 'لَيْسَ فِيمَا دُونَ خَمْسِ أَوَاقٍ صَدَقَةٌ',
                  englishText: 'No Zakat is due on silver weighing less than five Uqiyahs (595 grams).',
                  reference: 'Sahih al-Bukhari (1405), Sahih Muslim (979)',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Livestock Zakat Rules
          _buildRuleSectionCard(
            title: '4. Livestock Zakat (Al-An\'am)',
            subtitle: 'Camels, Cattle, & Sheep/Goats',
            icon: Icons.pets_rounded,
            iconColor: const Color(0xFF2E7D32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Livestock Zakat applies to free-grazing animals (Sa\'imah) kept for milk or breeding for a full lunar year.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.45,
                    color: _isDarkMode ? Colors.white.withValues(alpha: 0.9) : AppColors.navyBlue,
                  ),
                ),
                const SizedBox(height: 10),
                _buildLivestockRuleBox(
                  icon: Icons.landscape_outlined,
                  type: 'Camels (Nisab = 5)',
                  details: [
                    '5 - 9 camels → 1 Sheep/Goat',
                    '10 - 14 camels → 2 Sheep/Goats',
                    '15 - 19 camels → 3 Sheep/Goats',
                    '20 - 24 camels → 4 Sheep/Goats',
                    '25 - 35 camels → 1 Bint Makhad (1-yr she-camel)',
                    '36 - 45 camels → 1 Bint Labun (2-yr she-camel)',
                  ],
                ),
                const SizedBox(height: 8),
                _buildLivestockRuleBox(
                  icon: Icons.agriculture_outlined,
                  type: 'Cattle & Buffaloes (Nisab = 30)',
                  details: [
                    '30 - 39 cattle → 1 Tabi\' (1-yr calf)',
                    '40 - 59 cattle → 1 Musinnah (2-yr cow)',
                    '60 - 69 cattle → 2 Tabi\' (1-yr calves)',
                    '70 - 79 cattle → 1 Musinnah + 1 Tabi\'',
                  ],
                ),
                const SizedBox(height: 8),
                _buildLivestockRuleBox(
                  icon: Icons.grass_outlined,
                  type: 'Sheep & Goats (Nisab = 40)',
                  details: [
                    '40 - 120 sheep/goats → 1 Sheep/Goat',
                    '121 - 200 sheep/goats → 2 Sheep/Goats',
                    '201 - 300 sheep/goats → 3 Sheep/Goats',
                    '301+ sheep/goats → 1 Sheep/Goat per 100 animals',
                  ],
                ),
                _buildHadithReferenceCard(
                  arabicText: 'فِي صَدَقَةِ الْغَنَمِ فِي سَائِمَتِهَا إِذَا كَانَتْ أَرْبَعِينَ إِلَى عِشْرِينَ وَمِائَةٍ شَاةٌ',
                  englishText: 'Regarding Zakat on free-grazing sheep: when they number between 40 and 120, one sheep is due.',
                  reference: 'Sahih al-Bukhari (1454)',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 5. Agricultural Produce (Ushr)
          _buildRuleSectionCard(
            title: '5. Agricultural Zakat — Ushr (عُشْر)',
            subtitle: 'Due at every harvest · No Haul required',
            icon: Icons.grass_rounded,
            iconColor: Colors.teal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Zakat on agricultural produce is a standalone obligation — completely independent of the Haul (lunar year). It is due the moment the crop is gathered and secured. If a farmer has two harvests in one year, Zakat is calculated and paid separately for each.',
                  style: GoogleFonts.inter(fontSize: 12, height: 1.5, color: _isDarkMode ? Colors.white.withValues(alpha: 0.9) : AppColors.navyBlue),
                ),
                _buildQuranReferenceCard(
                  arabicText: 'وَهُوَ الَّذِي أَنشَأَ جَنَّاتٍ مَّعْرُوشَاتٍ وَغَيْرَ مَعْرُوشَاتٍ وَالنَّخْلَ وَالزَّرْعَ مُخْتَلِفًا أُكُلُهُ وَالزَّيْتُونَ وَالرُّمَّانَ مُتَشَابِهًا وَغَيْرَ مُتَشَابِهٍ ۚ كُلُوا مِن ثَمَرِهِ إِذَا أَثْمَرَ وَآتُوا حَقَّهُ يَوْمَ حَصَادِهِ',
                  englishText: 'It is He who produced gardens, both trellised and untrellised, and palm trees, and crops of diverse flavors, and olives, and pomegranates — similar and dissimilar. Eat of its fruits when it yields, and pay its due on the day of its harvest.',
                  reference: 'Quran — Surah Al-An\'am (6:141)',
                ),
                _buildHadithReferenceCard(
                  arabicText: 'فِيمَا سَقَتِ السَّمَاءُ وَالْعُيُونُ أَوْ كَانَ عَثَرِيًّا الْعُشْرُ، وَمَا سُقِيَ بِالنَّضْحِ نِصْفُ الْعُشْرِ',
                  englishText: 'On land watered by rain, springs, or natural streams — a tenth (10%) is due. On land watered by irrigation wells or pumps — a half-tenth (5%) is due.',
                  reference: 'Sahih al-Bukhari (1483)',
                ),
                const SizedBox(height: 8),
                _buildBulletPoint('Nisab (Threshold): 5 Awsaq ≈ 653 kg of cleaned, threshed grain. If harvest is below 653 kg, no Zakat is due for that harvest.'),
                _buildBulletPoint('Rain-fed / Natural Water: 10% (Full Ushr) — because no irrigation cost is incurred.'),
                _buildBulletPoint('Artificial Irrigation (pump/well): 5% (Half Ushr) — reduced rate acknowledges the cost of irrigation.'),
                _buildBulletPoint('Per-Harvest Rule: Each separate harvest triggers its own calculation. Multiple yearly harvests = multiple Zakat obligations.'),
                _buildBulletPoint('No Haul Required: The obligation arises at the moment of harvest, not after a lunar year.'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 6. Mineral Zakat (Ma'adin)
          _buildRuleSectionCard(
            title: "6. Mineral Zakat — Ma'adin (مَعَادِن)",
            subtitle: 'Due upon extraction · No Haul · Nisab required',
            icon: Icons.diamond_outlined,
            iconColor: AppColors.navyBlue,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Minerals extracted from the earth — gold, silver, iron, copper, oil, and similar resources — are subject to Zakat at the standard 2.5% rate. Unlike Rikaz, minerals require the Nisab threshold and significant human labor to extract, which is why scholars apply the lower 2.5% rate instead of 20%.",
                  style: GoogleFonts.inter(fontSize: 12, height: 1.5, color: _isDarkMode ? Colors.white.withValues(alpha: 0.9) : AppColors.navyBlue),
                ),
                _buildHadithReferenceCard(
                  arabicText: 'وَفِي الرِّكَازِ الخُمُسُ',
                  englishText: 'In found buried treasure (Rikaz), one-fifth (20%) is due.',
                  reference: 'Sahih al-Bukhari (1499), Sahih Muslim (1710) — Scholars derive the Mineral (Ma\'adin) rate by analogy at 2.5%, distinguishing it from Rikaz due to the cost of labor.',
                ),
                const SizedBox(height: 8),
                _buildBulletPoint('Covers: Gold ore, silver ore, iron, copper, oil, natural gas, and other earth-extracted resources.'),
                _buildBulletPoint('Nisab: Value of extracted batch must reach the monetary Nisab (equivalent of 85g gold or 595g silver).'),
                _buildBulletPoint('Accumulation Rule: If a mine extracts small daily amounts, aggregate the full extracted batch. Zakat is due once the total batch crosses Nisab.'),
                _buildBulletPoint('No Haul: Zakat is due immediately upon extraction and refinement — no waiting period.'),
                _buildBulletPoint('Rate: 2.5% on the total value of the extracted and refined batch.'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 7. Buried Treasure (Rikaz)
          _buildRuleSectionCard(
            title: '7. Buried Treasure — Rikaz (رِكَاز)',
            subtitle: 'Due immediately on discovery · No Nisab · 20% flat',
            icon: Icons.auto_awesome_rounded,
            iconColor: AppColors.coralOrange,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rikaz refers to pre-Islamic buried treasure (gold, silver, or wealth) discovered on or under one\'s land. Because it is a sudden windfall requiring zero labor or financial investment, Islamic law prescribes a higher and immediate rate of 20% (one-fifth / Khums). There is unanimous scholarly consensus (Ijma\') on this ruling.',
                  style: GoogleFonts.inter(fontSize: 12, height: 1.5, color: _isDarkMode ? Colors.white.withValues(alpha: 0.9) : AppColors.navyBlue),
                ),
                _buildHadithReferenceCard(
                  arabicText: 'الْعَجْمَاءُ جُبَارٌ، وَالْبِئْرُ جُبَارٌ، وَالْمَعْدَنُ جُبَارٌ، وَفِي الرِّكَازِ الخُمُسُ',
                  englishText: 'Injuries caused by animals are not compensated, nor those caused by wells, nor those in mines. And in found buried treasure (Rikaz), one-fifth (20%) is due.',
                  reference: 'Sahih al-Bukhari (1499), Sahih Muslim (1710) — Narrated by Abu Hurayrah (رضي الله عنه)',
                ),
                const SizedBox(height: 8),
                _buildBulletPoint('Definition: Pre-Islamic buried wealth (gold, silver, coins, jewels) found in or under land.'),
                _buildBulletPoint('No Nisab: Even a single ancient coin triggers the obligation — no minimum threshold.'),
                _buildBulletPoint('Immediate: Due the moment of discovery, after satisfying any local ownership or legal requirements.'),
                _buildBulletPoint('Rate: 20% (one-fifth / Khums) of the total discovered value — the highest Zakat rate.'),
                _buildBulletPoint('Unanimous Consensus (Ijma\'): Recognized by all four major schools of Islamic law (Hanafi, Maliki, Shafi\'i, Hanbali).'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 8. 8 Eligible Categories (Asnaf)
          _buildRuleSectionCard(
            title: '8. The 8 Eligible Recipients (Asnaf)',
            subtitle: 'Who is entitled to receive Zakat',
            icon: Icons.people_outline_rounded,
            iconColor: Colors.indigo,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildQuranReferenceCard(
                  arabicText: 'إِنَّمَا الصَّدَقَاتُ لِلْفُقَرَاءِ وَالْمَسَاكِينِ وَالْعَامِلِينَ عَلَيْهَا وَالْمُؤَلَّفَةِ قُلُوبُهُمْ وَفِي الرِّقَابِ وَالْغَارِمِينَ وَفِي سَبِيلِ اللَّهِ وَابْنِ السَّبِيلِ ۖ فَرِيضَةً مِّنَ اللَّهِ ۗ وَاللَّهُ عَلِيمٌ حَكِيمٌ',
                  englishText: 'Zakat expenditures are only for the poor (Al-Fuqara\'), the needy (Al-Masakin), those employed to collect it (Al-\'Amilina \'Alayha), bringing hearts together (Al-Mu\'allafati Qulubuhum), freeing captives (Fi al-Riqab), those in debt (Al-Gharimin), in the cause of Allah (Fi Sabilillah), and the stranded traveler (Ibn al-Sabil) — an obligation imposed by Allah.',
                  reference: 'Quran - Surah At-Tawbah (9:60)',
                ),
                const SizedBox(height: 10),
                _buildAsnafItem('1. Al-Fuqara\' (The Poor)', 'People who have no money or income to meet basic needs.'),
                _buildAsnafItem('2. Al-Masakin (The Needy)', 'People whose income falls short of meeting essential living costs.'),
                _buildAsnafItem('3. Al-\'Amilina \'Alayha (Administrators)', 'Official collectors and distributors of Zakat funds.'),
                _buildAsnafItem('4. Al-Mu\'allafati Qulubuhum', 'New Muslims or those whose hearts are being reconciled to Islam.'),
                _buildAsnafItem('5. Fi al-Riqab (Freeing Captives)', 'Assisting captives or enslaved individuals to gain freedom.'),
                _buildAsnafItem('6. Al-Gharimin (Debtors)', 'Individuals burdened with legitimate debt they cannot repay.'),
                _buildAsnafItem('7. Fi Sabilillah (In Allah\'s Cause)', 'Striving in Islamic causes, education, and community defense.'),
                _buildAsnafItem('8. Ibn al-Sabil (Travelers)', 'Travelers stranded away from home without financial means.'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 9. Ineligible Recipients
          _buildRuleSectionCard(
            title: '9. Ineligible Recipients',
            subtitle: 'Who cannot receive Zakat',
            icon: Icons.cancel_outlined,
            iconColor: Colors.red.shade700,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBulletPoint('Immediate Ascendants: Parents, grandparents.'),
                _buildBulletPoint('Immediate Descendants: Children, grandchildren.'),
                _buildBulletPoint('Spouse: Husband or wife (financial responsibility applies).'),
                _buildBulletPoint('Wealthy Individuals: Anyone possessing Nisab wealth or capable of earning.'),
                _buildBulletPoint('Non-Muslims: Obligatory Zakat is specific to Muslims (voluntary Sadaqah may be given).'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuranReferenceCard({
    required String arabicText,
    required String englishText,
    required String reference,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B4D3E).withValues(alpha: _isDarkMode ? 0.25 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF1B4D3E).withValues(alpha: _isDarkMode ? 0.4 : 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B4D3E),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.menu_book_rounded, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      'QURAN',
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            reference,
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: _isDarkMode ? const Color(0xFF80CBC4) : const Color(0xFF1B4D3E),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            arabicText,
            textAlign: TextAlign.right,
            style: GoogleFonts.amiri(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _isDarkMode ? const Color(0xFFA5D6A7) : const Color(0xFF0D3B2E),
              height: 1.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '"$englishText"',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: _isDarkMode ? Colors.white.withValues(alpha: 0.9) : AppColors.navyBlue.withValues(alpha: 0.85),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHadithReferenceCard({
    required String arabicText,
    required String englishText,
    required String reference,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.navyBlue.withValues(alpha: _isDarkMode ? 0.25 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.navyBlue.withValues(alpha: _isDarkMode ? 0.4 : 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.navyBlue,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bookmark_rounded, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      'HADITH',
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            reference,
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: _isDarkMode ? const Color(0xFF90CAF9) : AppColors.navyBlue,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            arabicText,
            textAlign: TextAlign.right,
            style: GoogleFonts.amiri(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: _isDarkMode ? const Color(0xFF90CAF9) : AppColors.navyBlue,
              height: 1.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '"$englishText"',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: _isDarkMode ? Colors.white.withValues(alpha: 0.9) : AppColors.navyBlue.withValues(alpha: 0.85),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isDarkMode ? Colors.white.withValues(alpha: 0.12) : AppColors.navyBlue.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: _isDarkMode ? Colors.white : AppColors.navyBlue,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: _isDarkMode ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6, right: 8),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: _isDarkMode ? AppColors.midTeal : AppColors.navyBlue,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: _isDarkMode ? Colors.white.withValues(alpha: 0.9) : AppColors.navyBlue.withValues(alpha: 0.85),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNisabTable() {
    final headerStyle = GoogleFonts.poppins(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: _isDarkMode ? Colors.white70 : AppColors.navyBlue,
    );
    return Container(
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Asset Category', style: headerStyle),
              Text('Nisab Minimum', style: headerStyle),
              Text('Zakat Rate', style: headerStyle),
            ],
          ),
          Divider(height: 14, color: _isDarkMode ? Colors.white12 : const Color(0xFFEEEEEE)),
          _nisabTableRow('Pure Gold (24k)', '85 grams', '2.5%'),
          _nisabTableRow('Silver', '595 grams', '2.5%'),
          _nisabTableRow('Cash & Bank', 'Gold/Silver Nisab', '2.5%'),
          _nisabTableRow('Trade Inventory', 'Gold/Silver Nisab', '2.5%'),
        ],
      ),
    );
  }

  Widget _nisabTableRow(String category, String nisab, String rate) {
    final textStyle = GoogleFonts.inter(
      fontSize: 11,
      color: _isDarkMode ? Colors.white.withValues(alpha: 0.9) : AppColors.navyBlue,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(flex: 2, child: Text(category, style: textStyle)),
          Expanded(flex: 2, child: Text(nisab, style: textStyle.copyWith(fontWeight: FontWeight.w600))),
          Text(rate, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _isDarkMode ? const Color(0xFF80CBC4) : AppColors.midTeal)),
        ],
      ),
    );
  }

  Widget _buildLivestockRuleBox({
    required IconData icon,
    required String type,
    required List<String> details,
  }) {
    final textStyle = GoogleFonts.inter(
      fontSize: 11,
      height: 1.35,
      color: _isDarkMode ? Colors.white.withValues(alpha: 0.9) : AppColors.navyBlue,
    );
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF0F4F2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: _isDarkMode ? const Color(0xFF80CBC4) : const Color(0xFF2E7D32),
              ),
              const SizedBox(width: 6),
              Text(
                type,
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: _isDarkMode ? const Color(0xFF80CBC4) : const Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...details.map((d) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('• $d', style: textStyle),
              )),
        ],
      ),
    );
  }

  Widget _buildAsnafItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF8FAF9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _isDarkMode ? const Color(0xFF80CBC4) : AppColors.midTeal,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              description,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: _isDarkMode ? Colors.white.withValues(alpha: 0.85) : Colors.black87,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 3 — ZAKAT AL-FITR (Fitra)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildFitraTab() {
    final now = DateTime.now();
    final todayHijri = _Hijri.fromGregorian(now);

    // Fitra belongs to Ramadan. It must not create a payable amount outside it.
    final bool isRamadan = todayHijri.month == 9;
    final bool isFitraWindowOpen = isRamadan;

    int daysUntilWindow = 0;
    String statusMessage = '';

    if (!isRamadan) {
      int monthsRemaining = 0;
      if (todayHijri.month < 9) {
        monthsRemaining = 9 - todayHijri.month - 1;
      } else {
        monthsRemaining = (12 - todayHijri.month) + 8;
      }
      daysUntilWindow = (monthsRemaining * 29.53 + (30 - todayHijri.day)).round();
      statusMessage = 'Days until Ramadan';
    }

    if (!isFitraWindowOpen) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B2E47), Color(0xFF14243B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: _isDarkMode ? Colors.white.withValues(alpha: 0.1) : AppColors.navyBlue.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.hourglass_empty_rounded,
                      color: Color(0xFFFFD700),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Zakat al-Fitr (Fitra)',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Temporal Obligation of Ramadan',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$daysUntilWindow',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFFFD700),
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          statusMessage,
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isRamadan
                        ? 'Zakat al-Fitr is payable during Ramadan and should be given before the Eid prayer.'
                        : 'Zakat al-Fitr is paid during the month of Ramadan. The calculation and payment logging will unlock automatically once the season begins.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11.5,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: _cardDeco(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About Zakat al-Fitr',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: _isDarkMode ? Colors.white : AppColors.navyBlue,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _bullet(
                      'Obligatory on every Muslim who has food in excess of their needs on Eid day.'),
                  _bullet(
                      'Standard measurement is one Sa\' (approximately 3.0 kg) of staple food per person.'),
                  _bullet('Must be paid before the Eid al-Fitr prayer to count as Zakat al-Fitr.'),
                  _bullet('Purpose is to purify the fasting person from indecent talk and to feed the poor.'),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF14243B), Color(0xFF22364A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.people_alt_rounded, color: Colors.white, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Zakat al-Fitr',
                          style: GoogleFonts.poppins(
                              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Due before Eid al-Fitr prayer. Per head of household.',
                          style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.65), fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDeco(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Household Members',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 13, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
                const SizedBox(height: 4),
                Text('Include yourself, spouse, children, and dependants',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: _isDarkMode ? Colors.white.withValues(alpha: 0.5) : AppColors.navyBlue.withValues(alpha: 0.5))),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _iconBtn(Icons.remove_rounded, () {
                      if (_fitraMembers > 1) {
                        setState(() => _fitraMembers--);
                        _savePrefs();
                      }
                    }),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text('$_fitraMembers',
                          style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
                    ),
                    _iconBtn(Icons.add_rounded, () {
                      setState(() => _fitraMembers++);
                      _savePrefs();
                    }),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDeco(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Staple Food Weights & Rates',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 13, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
                const SizedBox(height: 6),
                Text(
                    'Staple food prices vary significantly by region and variety. Please check your local market rates and input them below.',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: _isDarkMode ? Colors.white.withValues(alpha: 0.5) : AppColors.navyBlue.withValues(alpha: 0.5),
                        height: 1.4)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _fitraDefaultWeights.keys.map((s) {
                    final active = s == _fitraStaple;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _fitraStaple = s;
                          _fitraWeightCtrl.text =
                              (_fitraDefaultWeights[s] ?? 3.0).toStringAsFixed(1);
                        });
                        _savePrefs();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: active ? AppColors.navyBlue : const Color(0xFFF0F2F5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(s,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: active
                                    ? Colors.white
                                    : AppColors.navyBlue.withValues(alpha: 0.65))),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _fitraWeightCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) {
                          setState(() {});
                          _savePrefs();
                        },
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _isDarkMode ? Colors.white : AppColors.navyBlue),
                        decoration: InputDecoration(
                          labelText: 'Weight per person (kg)',
                          labelStyle: GoogleFonts.inter(
                              fontSize: 11, color: AppColors.placeholder),
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          filled: true,
                          fillColor: _isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF5F7FA),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _fitraPriceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) {
                          setState(() {});
                          _savePrefs();
                        },
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _isDarkMode ? Colors.white : AppColors.navyBlue),
                        decoration: InputDecoration(
                          labelText: 'Local Price per kg (${_currency.code})',
                          labelStyle: GoogleFonts.inter(
                              fontSize: 11, color: AppColors.placeholder),
                          suffixText: _currency.symbol,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          filled: true,
                          fillColor: _isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF5F7FA),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: _fitraTotal > 0 && _fitraStillOwed <= 0
                      ? [const Color(0xFF1B4D3E), const Color(0xFF142E24)]
                      : [const Color(0xFF14243B), const Color(0xFF1C3A27)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                            _fitraTotal > 0 && _fitraStillOwed <= 0
                                ? 'Zakat al-Fitr Completed'
                                : 'Zakat al-Fitr Remaining',
                            style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 6),
                        if (_fitraTotal > 0 && _fitraStillOwed <= 0) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF81C784), size: 28),
                              const SizedBox(width: 8),
                              Text('${_formatMoney(_fitraTotal)} Paid',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('May Allah accept this purification of your fasts.',
                              style: GoogleFonts.inter(color: Colors.white60, fontSize: 11)),
                        ] else ...[
                          Text(_formatMoney(_fitraStillOwed),
                              style: GoogleFonts.poppins(
                                  color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
                          if (_fitraPaid > 0 && _fitraTotal > 0) ...[
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: SizedBox(
                                width: 200,
                                child: LinearProgressIndicator(
                                  value: (_fitraPaid / _fitraTotal).clamp(0.0, 1.0),
                                  minHeight: 4,
                                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF81C784)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text('Paid: ${_formatMoney(_fitraPaid)} of ${_formatMoney(_fitraTotal)}',
                                style: GoogleFonts.inter(color: Colors.white54, fontSize: 10.5)),
                          ] else ...[
                            const SizedBox(height: 6),
                            Text(
                                '$_fitraMembers members x ${_fitraWeightPerHead.toStringAsFixed(1)} kg x ${_currency.symbol} ${_fitraRatePerKg.toStringAsFixed(0)}/kg',
                                style: GoogleFonts.inter(color: Colors.white54, fontSize: 11.5)),
                          ],
                        ],
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => _showAddPaymentDialog(isFitra: true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                      _fitraTotal > 0 && _fitraStillOwed <= 0
                                          ? 'Log Additional Payment'
                                          : 'Log Fitra Payment',
                                      style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.dustyBlueTeal.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('About Zakat al-Fitr',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 12.5, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
                const SizedBox(height: 8),
                _bullet(
                    'Obligatory on every Muslim who has food in excess of their needs on Eid day.'),
                _bullet(
                    'Standard measurement is one Sa\' (approximately 3.0 kg) of food per person.'),
                _bullet('Must be paid before the Eid al-Fitr prayer to count as Zakat al-Fitr.'),
              ],
            ),
          ),
          if (_fitraPayments.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSectionHeader('Fitra Payment Log', AppColors.midTeal),
            const SizedBox(height: 10),
            ..._fitraPayments.map((p) => _buildPaymentCard(p, isFitra: true)),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 3 — PAYMENTS & RECEIPTS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildPaymentsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF14243B), Color(0xFF22364A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: _isDarkMode ? Colors.white.withValues(alpha: 0.2) : AppColors.navyBlue.withValues(alpha: 0.2),
                    blurRadius: 14,
                    offset: const Offset(0, 6)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text((_isHaulCompleted || _haulCycles.isNotEmpty) ? 'Haul Zakat' : 'Zakat (Estimate)',
                            style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatMoney(_activeZakatDue),
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                      if (_lockedLivestockSummary.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '+ $_lockedLivestockSummary',
                          style: GoogleFonts.inter(
                              color: const Color(0xFFA5D6A7),
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.white12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Paid',
                          style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _formatMoney(_totalPaid),
                            style: GoogleFonts.poppins(
                                color: const Color(0xFF81C784),
                                fontSize: 15,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.white12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Still Owed',
                          style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _formatMoney(_stillOwed),
                            style: GoogleFonts.poppins(
                                color: _stillOwed > 0
                                    ? AppColors.coralOrange
                                    : const Color(0xFF81C784),
                                fontSize: 15,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildImmediateZakatPaymentsCard(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showAddPaymentDialog(isFitra: false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: AppColors.navyBlue,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_circle_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Log Payment',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _exportFinancialStatementPdf,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Export PDF',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_payments.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_rounded,
                        size: 48, color: _isDarkMode ? Colors.white.withValues(alpha: 0.18) : AppColors.navyBlue.withValues(alpha: 0.18)),
                    const SizedBox(height: 12),
                    Text('No payments logged yet.',
                        style: GoogleFonts.poppins(
                            color: _isDarkMode ? Colors.white.withValues(alpha: 0.4) : AppColors.navyBlue.withValues(alpha: 0.4), fontSize: 13)),
                  ],
                ),
              ),
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader('Payment Log', AppColors.navyBlue),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _userPaymentsExpanded = !_isPaymentsExpanded;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isDarkMode ? Colors.white.withValues(alpha: 0.05) : AppColors.navyBlue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _isPaymentsExpanded ? 'Hide Logs' : 'Show Logs',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _isDarkMode ? Colors.white : AppColors.navyBlue,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_isPaymentsExpanded) ...[
              ..._payments.map((p) => _buildPaymentCard(p, isFitra: false)),
            ] else
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Zakat obligation cleared. Log is collapsed.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _isDarkMode ? Colors.white.withValues(alpha: 0.45) : AppColors.navyBlue.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _showCharityDirectory,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _isDarkMode ? Colors.white.withValues(alpha: 0.12) : AppColors.coralOrange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: AppColors.coralOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.handshake_rounded,
                        color: AppColors.coralOrange, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Verified Charity Directory',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                                color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
                        Text('Browse Zakat-eligible charity donation pages',
                            style: GoogleFonts.inter(
                                fontSize: 10.5, color: _isDarkMode ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.5))),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      color: AppColors.coralOrange, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImmediateZakatPaymentsCard() {
    final totalDue = _immediateTotalDue;
    final paid = _immediatePaid;
    final remaining = _immediateStillOwed;
    final isFullyPaid = remaining <= 1.0 && paid > 0;

    if (totalDue <= 0 && paid <= 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isFullyPaid
              ? const Color(0xFF2E7D32).withValues(alpha: 0.3)
              : AppColors.coralOrange.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isFullyPaid
                      ? const Color(0xFF2E7D32).withValues(alpha: 0.1)
                      : AppColors.coralOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  color: isFullyPaid ? const Color(0xFF2E7D32) : AppColors.coralOrange,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Immediate Zakat Obligations',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _isDarkMode ? Colors.white : AppColors.navyBlue,
                      ),
                    ),
                    Text(
                      'Crops (Ushr), Minerals & Rikaz — Due on event (No Haul)',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: _isDarkMode ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isFullyPaid
                      ? const Color(0xFF2E7D32).withValues(alpha: 0.12)
                      : AppColors.coralOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isFullyPaid ? 'Fully Paid' : 'Payment Due',
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: isFullyPaid ? const Color(0xFF2E7D32) : AppColors.coralOrange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildImmediatePayStat('Total Due', _formatMoney(totalDue)),
              ),
              Expanded(
                child: _buildImmediatePayStat('Total Paid', _formatMoney(paid)),
              ),
              Expanded(
                child: _buildImmediatePayStat(
                  'Remaining',
                  isFullyPaid ? 'Fully Paid' : _formatMoney(remaining),
                  isHighlight: !isFullyPaid && remaining > 0,
                ),
              ),
            ],
          ),
          if (!isFullyPaid && remaining > 0) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _showAddPaymentDialog(
                isFitra: false,
                prefilledObligationType: _cropsZakatDue > 0 ? 'crops' : (_mineralsZakatDue > 0 ? 'minerals' : 'rikaz'),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.navyBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_circle_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Log Immediate Payment',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImmediatePayStat(String label, String value, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: _isDarkMode ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: isHighlight
                ? AppColors.coralOrange
                : (_isDarkMode ? Colors.white : AppColors.navyBlue),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentCard(ZakatPayment p, {required bool isFitra}) {
    final color = _categoryColor(p.category);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(p.category,
                    style: GoogleFonts.inter(
                        fontSize: 9.5, fontWeight: FontWeight.bold, color: color)),
              ),
              const Spacer(),
              Text("Paid on ${DateFormat('dd MMMM yyyy').format(p.date)}",
                  style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.recipient,
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold, fontSize: 13, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
                    if (p.note.isNotEmpty)
                      Text(p.note,
                          style: GoogleFonts.inter(
                              fontSize: 11, color: _isDarkMode ? Colors.white.withValues(alpha: 0.5) : AppColors.navyBlue.withValues(alpha: 0.5))),
                    if (p.animalDescription != null && p.animalDescription!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.pets_rounded, size: 12, color: Color(0xFF2E7D32)),
                            const SizedBox(width: 4),
                            Text(
                              'Paid via Animal: ${p.animalDescription}',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2E7D32),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                  _formatMoney(p.amount * _currencyRate(p.currency)),
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 15, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => _shareReceipt(p),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isDarkMode ? Colors.white.withValues(alpha: 0.07) : AppColors.navyBlue.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.share_rounded, size: 13, color: _isDarkMode ? Colors.white : AppColors.navyBlue),
                      const SizedBox(width: 5),
                      Text('Share Receipt',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  final confirm = await _confirmDeletion(
                      'Are you sure you want to delete this logged payment?');
                  if (confirm) {
                    setState(() {
                      if (isFitra) {
                        _fitraPayments.removeWhere((x) => x.id == p.id);
                      } else {
                        _payments.removeWhere((x) => x.id == p.id);
                      }
                    });
                    _savePrefs();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.coralOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      size: 14, color: AppColors.coralOrange),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _categoryColor(String category) {
    if (category.contains('Poor') || category.contains('Fuqara')) return const Color(0xFF2E7D32);
    if (category.contains('Needy') || category.contains('Masakin')) return const Color(0xFF1565C0);
    if (category.contains('Debt') || category.contains('Gharimeen')) return const Color(0xFFB71C1C);
    if (category.contains('Sabil')) return const Color(0xFF4527A0);
    if (category.contains('Traveller')) return const Color(0xFF00695C);
    if (category.contains('New Muslims')) return const Color(0xFFE65100);
    if (category.contains('Captive')) return const Color(0xFF37474F);
    return AppColors.navyBlue;
  }

  void _showAddPaymentDialog({
    required bool isFitra,
    String? prefilledRecipient,
    String? prefilledCategory,
    String? prefilledObligationType,
  }) {
    final amountCtrl = TextEditingController();
    final recipientCtrl = TextEditingController(text: prefilledRecipient ?? '');
    final noteCtrl = TextEditingController();
    String currency = _selectedCurrency;
    String category = prefilledCategory ?? _zakatCategories.first;
    String obligationType = prefilledObligationType ?? 'haul';

    final bool hasAnimalPaymentLogged = _payments.any((p) =>
        p.obligationType == 'haul' &&
        p.animalDescription != null &&
        p.animalDescription!.isNotEmpty);

    final livestockPaymentOptions = _hasCompletedHaulAssessment
        ? (_lockedLivestockSummary.isEmpty ? <String>[] : [_lockedLivestockSummary])
        : _livestockZakatDueItems;

    final bool activeLivestockPresent = livestockPaymentOptions.isNotEmpty;

    final bool hasLivestockObligation = !isFitra &&
        (prefilledObligationType == null || prefilledObligationType == 'haul') &&
        activeLivestockPresent &&
        !hasAnimalPaymentLogged;

    bool isAnimalPayment = false;
    final String defaultAnimal = livestockPaymentOptions.isNotEmpty
        ? livestockPaymentOptions.first
        : '';
    String selectedAnimal = hasLivestockObligation ? defaultAnimal : '';
    String? paymentError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 430),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: BoxDecoration(
            color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: const Color(0xFFE0E0E0),
                          borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 16),
                Text(isFitra ? 'Log Fitra Payment' : 'Log Zakat Payment',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 16, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
                const SizedBox(height: 16),

                if (hasLivestockObligation) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withValues(alpha: _isDarkMode ? 0.2 : 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.pets_rounded, color: Color(0xFF2E7D32), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Fulfill via Animal Payment',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _isDarkMode ? const Color(0xFF80CBC4) : const Color(0xFF2E7D32),
                                ),
                              ),
                            ),
                            Switch(
                              value: isAnimalPayment,
                              activeThumbColor: const Color(0xFF2E7D32),
                              onChanged: (v) => setModalState(() => isAnimalPayment = v),
                            ),
                          ],
                        ),
                        if (isAnimalPayment) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Select Animal Given:',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _isDarkMode ? Colors.white70 : AppColors.navyBlue,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: livestockPaymentOptions.contains(selectedAnimal) ? selectedAnimal : livestockPaymentOptions.first,
                            style: GoogleFonts.inter(fontSize: 12, color: _isDarkMode ? Colors.white : AppColors.navyBlue),
                            dropdownColor: _isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              filled: true,
                              fillColor: _isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF5F7FA),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            ),
                            items: livestockPaymentOptions
                                .map((item) => DropdownMenuItem(
                                      value: item,
                                      child: Text(item,
                                          style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
                                    ))
                                .toList(),
                            onChanged: (v) => setModalState(() => selectedAnimal = v!),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                Row(
                  children: [
                    Expanded(
                      child: _sheetField(amountCtrl, isAnimalPayment ? 'Equivalent Value (optional)' : 'Amount',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) {
                            if (paymentError != null) {
                              setModalState(() => paymentError = null);
                            }
                          }),
                    ),
                    const SizedBox(width: 10),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: currency,
                        dropdownColor: _isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _isDarkMode ? Colors.white : AppColors.navyBlue),
                        onChanged: (v) {
                          setModalState(() => currency = v!);
                          if (paymentError != null) {
                            setModalState(() => paymentError = null);
                          }
                        },
                        items: _currencies
                            .map((c) => DropdownMenuItem(
                                  value: c.code,
                                  child: Text(c.code),
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                ),
                if (!isAnimalPayment) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Remaining ${_obligationLabel(isFitra ? 'fitra' : obligationType)} to pay: '
                    '${_paymentRemainingText(currency, isFitra ? 'fitra' : obligationType)}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                ],
                if (paymentError != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.coralOrange.withValues(alpha: _isDarkMode ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.coralOrange.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 14, color: AppColors.coralOrange),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            paymentError!,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.coralOrange,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                _sheetField(recipientCtrl, 'Recipient / Organization'),
                const SizedBox(height: 10),
                if (!isFitra) ...[
                  Text('Obligation Type',
                      style: GoogleFonts.inter(
                          fontSize: 11.5, color: _isDarkMode ? Colors.white.withValues(alpha: 0.6) : AppColors.navyBlue.withValues(alpha: 0.6))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: obligationType,
                    style: GoogleFonts.inter(fontSize: 12, color: _isDarkMode ? Colors.white : AppColors.navyBlue),
                    dropdownColor: _isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      filled: true,
                      fillColor: _isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF5F7FA),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    items: [
                      DropdownMenuItem(value: 'haul', child: Text('Standard Wealth (Haul)', style: GoogleFonts.inter(fontSize: 12, color: _isDarkMode ? Colors.white : AppColors.navyBlue))),
                      DropdownMenuItem(value: 'crops', child: Text('Agricultural / Ushr (Immediate)', style: GoogleFonts.inter(fontSize: 12, color: _isDarkMode ? Colors.white : AppColors.navyBlue))),
                      DropdownMenuItem(value: 'minerals', child: Text('Minerals / Ma\'adin (Immediate)', style: GoogleFonts.inter(fontSize: 12, color: _isDarkMode ? Colors.white : AppColors.navyBlue))),
                      DropdownMenuItem(value: 'rikaz', child: Text('Buried Treasure / Rikaz (Immediate)', style: GoogleFonts.inter(fontSize: 12, color: _isDarkMode ? Colors.white : AppColors.navyBlue))),
                    ],
                    onChanged: (v) { setModalState(() => obligationType = v!); },
                  ),
                  const SizedBox(height: 10),
                  Text('Category (from Surah At-Tawbah 9:60)',
                      style: GoogleFonts.inter(
                          fontSize: 11.5, color: _isDarkMode ? Colors.white.withValues(alpha: 0.6) : AppColors.navyBlue.withValues(alpha: 0.6))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: category,
                    style: GoogleFonts.inter(fontSize: 12, color: _isDarkMode ? Colors.white : AppColors.navyBlue),
                    dropdownColor: _isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      filled: true,
                      fillColor: _isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF5F7FA),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    items: _zakatCategories
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c,
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
                            ))
                        .toList(),
                    onChanged: (v) => setModalState(() => category = v!),
                  ),
                  const SizedBox(height: 10),
                ],
                _sheetField(noteCtrl, 'Note (optional)'),
                const SizedBox(height: 18),
                InkWell(
                  onTap: () {
                    final amount = double.tryParse(amountCtrl.text) ?? 0;
                    final payObligationType = isFitra ? 'fitra' : obligationType;
                    if (!isAnimalPayment) {
                      if (amount <= 0) {
                        setModalState(() => paymentError =
                            'Enter an amount greater than 0.');
                        return;
                      }
                      final remainingBDT = _remainingForObligation(payObligationType);
                      final amountBDT = amount * _currencyRate(currency);
                      if (amountBDT > remainingBDT + 0.01) {
                        setModalState(() => paymentError =
                            'Amount exceeds remaining ${_obligationLabel(payObligationType)} to pay '
                            '(max ${_paymentRemainingText(currency, payObligationType)}).');
                        return;
                      }
                    }
                    if (recipientCtrl.text.trim().isEmpty) return;
                    final pay = ZakatPayment(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      amount: amount,
                      currency: currency,
                      recipient: recipientCtrl.text.trim(),
                      category: isFitra ? 'The Poor (Al-Fuqara)' : category,
                      date: DateTime.now(),
                      note: noteCtrl.text.trim(),
                      animalDescription: isAnimalPayment ? selectedAnimal : null,
                      obligationType: isFitra ? 'fitra' : obligationType,
                    );
                    setState(() {
                      if (isFitra) {
                        _fitraPayments.insert(0, pay);
                      } else {
                        _payments.insert(0, pay);
                      }
                    });
                    _recalculate();
                    _savePrefs();
                    if (Navigator.canPop(ctx)) {
                      Navigator.pop(ctx);
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _isDarkMode ? AppColors.midTeal : AppColors.navyBlue,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text('Save Payment',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
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

  Widget _sheetField(TextEditingController ctrl, String label,
      {TextInputType keyboardType = TextInputType.text, ValueChanged<String>? onChanged}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: GoogleFonts.poppins(fontSize: 13, color: _isDarkMode ? Colors.white : AppColors.navyBlue),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            GoogleFonts.inter(fontSize: 12, color: _isDarkMode ? Colors.white.withValues(alpha: 0.5) : AppColors.navyBlue.withValues(alpha: 0.5)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        filled: true,
        fillColor: _isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF5F7FA),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Future<void> _shareReceipt(ZakatPayment p) async {
    final pdf = pw.Document();
    final currencySymbol = _currencies
        .firstWhere((c) => c.code == p.currency, orElse: () => _currencies.first)
        .symbol;
    final bool isAnimal = p.animalDescription != null && p.animalDescription!.isNotEmpty;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.teal, width: 2),
            ),
            padding: const pw.EdgeInsets.all(16),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text('DEENMATE', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
                ),
                pw.Center(
                  child: pw.Text('ZAKAT PAYMENT RECEIPT', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                ),
                pw.SizedBox(height: 16),
                pw.Divider(thickness: 1, color: PdfColors.grey300),
                pw.SizedBox(height: 12),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Receipt ID:', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                    pw.Text(p.id, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Date:', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                    pw.Text(DateFormat('dd MMMM yyyy').format(p.date), style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Divider(thickness: 1, color: PdfColors.grey300),
                pw.SizedBox(height: 12),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Recipient:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.Text(p.recipient, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Category:', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                    pw.Text(p.category, style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                if (isAnimal) ...[
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Payment Type:', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                      pw.Text('Livestock Animal', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Animal Given:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      pw.Text(p.animalDescription!, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
                    ],
                  ),
                ],
                if (p.amount > 0) ...[
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        isAnimal ? 'Equivalent Value:' : 'Amount:',
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal),
                      ),
                      pw.Text('$currencySymbol ${p.amount.toStringAsFixed(2)} ${p.currency}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
                    ],
                  ),
                ],
                if (p.note.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Note:', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                      pw.Text(p.note, style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
                pw.SizedBox(height: 16),
                pw.Divider(thickness: 1, color: PdfColors.grey300),
                pw.SizedBox(height: 16),
                pw.Center(
                  child: pw.Text('May Allah accept your charity and bless your wealth.', style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text('Generated by DeenMate Zakat Manager', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      name: 'Zakat_Payment_Receipt_${p.id}',
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Future<void> _exportFinancialStatementPdf() async {
    final pdf = pw.Document();

    final rate = _toBDT;
    final cash = (double.tryParse(_cashCtrl.text.replaceAll(',', '')) ?? 0) * rate;
    final pureGoldGrams = _pureGoldEquivalentGrams;
    final silverGrams = double.tryParse(_silverGramsCtrl.text.replaceAll(',', '')) ?? 0;
    final goldVal = pureGoldGrams * _effectiveGoldPrice;
    final silverVal = silverGrams * _effectiveSilverPrice;
    final stocks = (double.tryParse(_stocksCtrl.text.replaceAll(',', '')) ?? 0) * rate;
    final business = (double.tryParse(_businessCtrl.text.replaceAll(',', '')) ?? 0) * rate;
    final receivable = (double.tryParse(_receivableCtrl.text.replaceAll(',', '')) ?? 0) * rate;
    final liabilities = (double.tryParse(_liabilitiesCtrl.text.replaceAll(',', '')) ?? 0) * rate;
    final livestockVal = _livestockMeetsNisab ? _livestockTotalBDT : 0.0;
    final statementLivestockSummary = _assessmentLivestockSummary;
    final haulPayments = _payments
        .where((p) => p.obligationType == 'haul')
        .toList();
    final immediatePayments = _payments
        .where((p) =>
            p.obligationType == 'crops' ||
            p.obligationType == 'minerals' ||
            p.obligationType == 'rikaz')
        .toList();
    double paidFor(String obligationType) => _payments
        .where((p) => p.obligationType == obligationType)
        .fold(0.0, (sum, p) => sum + p.amount * _currencyRate(p.currency));
    final cropsPaid = paidFor('crops');
    final mineralsPaid = paidFor('minerals');
    final rikazPaid = paidFor('rikaz');
    // Older records cleared the source value after payment. Preserve a
    // meaningful statement by using that recorded payment as the due amount.
    final cropsDueForStatement = math.max(_cropsZakatDue, cropsPaid).toDouble();
    final mineralsDueForStatement = math.max(_mineralsZakatDue, mineralsPaid).toDouble();
    final rikazDueForStatement = math.max(_rikazZakatDue, rikazPaid).toDouble();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('DeenMate', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
                    pw.Text('Zakat Financial Statement', style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                  ],
                ),
                pw.Text(DateFormat('dd MMMM yyyy').format(DateTime.now()), style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 10),

            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('ZAKAT SUMMARY', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Zakatable Wealth:'),
                      pw.Text(_formatMoney(_totalWealth, fractionDigits: 2), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Nisab Standard (${_nisabStandard.toUpperCase()}):'),
                      pw.Text(_formatMoney(_nisabBDT, fractionDigits: 2)),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Zakat Obligation:'),
                      pw.Text(
                        _formattedZakatDueText(
                          dueAmount: _activeZakatDue,
                          livestockSummary: statementLivestockSummary,
                        ),
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Paid:'),
                      pw.Text(_formatMoney(_totalPaid, fractionDigits: 2), style: pw.TextStyle(color: PdfColors.green)),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Remaining Zakat Owed:'),
                      pw.Text(_formatMoney(_stillOwed, fractionDigits: 2), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _stillOwed > 0 ? PdfColors.red : PdfColors.green)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            if (_isRamadan) ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('ZAKAT AL-FITR SUMMARY (RAMADAN)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Household Members:'),
                      pw.Text('$_fitraMembers'),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Staple Choice:'),
                      pw.Text(_fitraStaple),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Fitra Due:'),
                      pw.Text(_formatMoney(_fitraTotal, fractionDigits: 2), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Fitra Paid:'),
                      pw.Text(_formatMoney(_fitraPaid, fractionDigits: 2), style: pw.TextStyle(color: PdfColors.green)),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Remaining Fitra Owed:'),
                      pw.Text(_formatMoney(_fitraStillOwed, fractionDigits: 2), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _fitraStillOwed > 0 ? PdfColors.red : PdfColors.green)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            ],

            pw.Text('ASSETS BREAKDOWN', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                _pdfTableRow('Asset Category', 'Value (${_currency.code})', isHeader: true),
                _pdfTableRow('Cash & Bank Savings', _formatMoney(cash)),
                _pdfTableRow('Gold Equivalent Value', '${_formatMoney(goldVal)} (${pureGoldGrams.toStringAsFixed(1)}g pure)'),
                _pdfTableRow('Silver Value', '${_formatMoney(silverVal)} (${silverGrams.toStringAsFixed(1)}g)'),
                _pdfTableRow('Stocks & Investments', _formatMoney(stocks)),
                _pdfTableRow('Business Assets & Inventory', _formatMoney(business)),
                _pdfTableRow('Receivables', _formatMoney(receivable)),
                if (_livestockMeetsNisab)
                  _pdfTableRow('Livestock Market Value', _formatMoney(livestockVal)),
                for (var ca in _customAssets)
                  _pdfTableRow(ca.name, _formatMoney(ca.value * _currencyRate(ca.currency))),
                _pdfTableRow('Liabilities (Deduction)', '- ${_formatMoney(liabilities)}'),
                for (var cl in _customLiabilities)
                  _pdfTableRow('${cl.name} (Deduction)',
                      '- ${_formatMoney(cl.value * _currencyRate(cl.currency))}'),
              ],
            ),
            pw.SizedBox(height: 20),

            pw.Text('IMMEDIATE ZAKAT (NO HAUL REQUIRED)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.deepOrange)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                _pdfTableRow3('Type', 'Due', 'Paid', 'Remaining', isHeader: true),
                _pdfTableRow3('Agricultural / Ushr', _formatMoney(cropsDueForStatement), _formatMoney(cropsPaid), _formatMoney((cropsDueForStatement - cropsPaid).clamp(0.0, double.infinity))),
                _pdfTableRow3('Minerals / Ma\'adin', _formatMoney(mineralsDueForStatement), _formatMoney(mineralsPaid), _formatMoney((mineralsDueForStatement - mineralsPaid).clamp(0.0, double.infinity))),
                _pdfTableRow3('Buried Treasure / Rikaz', _formatMoney(rikazDueForStatement), _formatMoney(rikazPaid), _formatMoney((rikazDueForStatement - rikazPaid).clamp(0.0, double.infinity))),
              ],
            ),
            pw.SizedBox(height: 20),

            if (statementLivestockSummary.isNotEmpty) ...[
              pw.Text('LIVESTOCK ZAKAT OBLIGATION', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Text(
                  '$statementLivestockSummary (or equivalent monetary value)',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
                ),
              ),
              pw.SizedBox(height: 20),
            ],

            if (haulPayments.isNotEmpty) ...[
              pw.Text('HAUL ZAKAT PAYMENT HISTORY', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  _pdfTableRow3('Payment Date', 'Recipient', 'Category', 'Amount', isHeader: true),
                  for (var p in haulPayments)
                    _pdfTableRow3(
                      DateFormat('dd MMM yyyy').format(p.date),
                      p.recipient,
                      p.category,
                      (p.animalDescription != null && p.animalDescription!.isNotEmpty)
                          ? (p.amount > 0
                              ? 'Animal: ${p.animalDescription} (+${_formatMoney(p.amount * _currencyRate(p.currency))})'
                              : 'Animal: ${p.animalDescription}')
                          : _formatMoney(p.amount * _currencyRate(p.currency)),
                    ),
                ],
              ),
              pw.SizedBox(height: 20),
            ],

            if (immediatePayments.isNotEmpty) ...[
              pw.Text('IMMEDIATE ZAKAT PAYMENT HISTORY', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  _pdfTableRow3('Payment Date', 'Type', 'Recipient', 'Amount', isHeader: true),
                  for (var p in immediatePayments)
                    _pdfTableRow3(
                      DateFormat('dd MMMM yyyy').format(p.date),
                      p.obligationType == 'crops'
                          ? 'Ushr'
                          : p.obligationType == 'minerals'
                              ? 'Minerals'
                              : 'Rikaz',
                      p.recipient,
                      _formatMoney(p.amount * _currencyRate(p.currency)),
                    ),
                ],
              ),
              pw.SizedBox(height: 20),
            ],

            if (_fitraPayments.isNotEmpty) ...[
              pw.Text('FITRA PAYMENT HISTORY', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  _pdfTableRow3('Date', 'Recipient', 'Category', 'Amount', isHeader: true),
                  for (var p in _fitraPayments)
                    _pdfTableRow3(
                      DateFormat('dd MMMM yyyy').format(p.date),
                      p.recipient,
                      'Zakat al-Fitr',
                      _formatMoney(p.amount * _currencyRate(p.currency)),
                    ),
                ],
              ),
            ],
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      name: 'DeenMate_Zakat_Statement',
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Future<void> _exportYearRecordPdf(ZakatYearSnapshot snapshot) async {
    final pdf = pw.Document();
    // Backfill legacy snapshots that lost a due value after a full payment.
    final cropsDue = math.max(snapshot.cropsDue, snapshot.cropsPaid).toDouble();
    final mineralsDue = math.max(snapshot.mineralsDue, snapshot.mineralsPaid).toDouble();
    final rikazDue = math.max(snapshot.rikazDue, snapshot.rikazPaid).toDouble();
    final immediateDue = cropsDue + mineralsDue + rikazDue;
    final immediatePaid = snapshot.cropsPaid + snapshot.mineralsPaid + snapshot.rikazPaid;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text('DeenMate', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
          pw.Text('Yearly Zakat Record - ${snapshot.year}', style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
          pw.SizedBox(height: 16),
          pw.Text('HAUL ZAKAT (MONETARY & LIVESTOCK)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
          pw.SizedBox(height: 6),
          pw.Table(border: pw.TableBorder.all(color: PdfColors.grey300), children: [
            _pdfTableRow('Net Zakatable Wealth', _formatMoney(snapshot.wealth)),
            _pdfTableRow('Monetary Zakat Due', _formatMoney(snapshot.zakatDue)),
            _pdfTableRow('Monetary Zakat Paid', _formatMoney(snapshot.zakatPaid)),
            if (snapshot.livestockZakat != null && snapshot.livestockZakat!.isNotEmpty)
              _pdfTableRow('Livestock Obligation', snapshot.livestockZakat!),
          ]),
          if (snapshot.fitraDue > 0 || snapshot.fitraPaid > 0) ...[
            pw.SizedBox(height: 16),
            pw.Text('ZAKAT AL-FITR (RAMADAN)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
            pw.SizedBox(height: 6),
            pw.Table(border: pw.TableBorder.all(color: PdfColors.grey300), children: [
              _pdfTableRow('Fitra Due', _formatMoney(snapshot.fitraDue)),
              _pdfTableRow('Fitra Paid', _formatMoney(snapshot.fitraPaid)),
            ]),
          ],
          pw.SizedBox(height: 16),
          pw.Text('IMMEDIATE ZAKAT (NO HAUL REQUIRED)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.deepOrange)),
          pw.SizedBox(height: 6),
          pw.Table(border: pw.TableBorder.all(color: PdfColors.grey300), children: [
            _pdfTableRow3('Type', 'Due', 'Paid', 'Remaining', isHeader: true),
            _pdfTableRow3('Agricultural / Ushr', _formatMoney(cropsDue), _formatMoney(snapshot.cropsPaid), _formatMoney((cropsDue - snapshot.cropsPaid).clamp(0.0, double.infinity))),
            _pdfTableRow3('Minerals / Ma\'adin', _formatMoney(mineralsDue), _formatMoney(snapshot.mineralsPaid), _formatMoney((mineralsDue - snapshot.mineralsPaid).clamp(0.0, double.infinity))),
            _pdfTableRow3('Buried Treasure / Rikaz', _formatMoney(rikazDue), _formatMoney(snapshot.rikazPaid), _formatMoney((rikazDue - snapshot.rikazPaid).clamp(0.0, double.infinity))),
            _pdfTableRow3('Total', _formatMoney(immediateDue), _formatMoney(immediatePaid), _formatMoney((immediateDue - immediatePaid).clamp(0.0, double.infinity))),
          ]),
          if (snapshot.payments.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text('PAYMENTS RECORDED IN ${snapshot.year}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Table(border: pw.TableBorder.all(color: PdfColors.grey300), children: [
              _pdfTableRow3('Date', 'Type', 'Recipient', 'Amount', isHeader: true),
              for (final payment in snapshot.payments)
                _pdfTableRow3(
                  DateFormat('dd MMM yyyy').format(payment.date),
                  payment.obligationType == 'fitra' ? 'Fitra' : payment.obligationType == 'crops' ? 'Ushr' : payment.obligationType == 'minerals' ? 'Minerals' : payment.obligationType == 'rikaz' ? 'Rikaz' : 'Haul',
                  payment.recipient,
                  _formatMoney(payment.amount * _currencyRate(payment.currency)),
                ),
            ]),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(
      name: 'DeenMate_Zakat_Record_${snapshot.year}',
      onLayout: (format) async => pdf.save(),
    );
  }

  pw.TableRow _pdfTableRow(String category, String value, {bool isHeader = false}) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            category,
            style: pw.TextStyle(fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: 10),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            value,
            style: pw.TextStyle(fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: 10),
          ),
        ),
      ],
    );
  }

  pw.TableRow _pdfTableRow3(String date, String recipient, String category, String amount, {bool isHeader = false}) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(date, style: pw.TextStyle(fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: 9)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(recipient, style: pw.TextStyle(fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: 9)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(category, style: pw.TextStyle(fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: 9)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(amount, style: pw.TextStyle(fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: 9)),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 4 — HISTORY
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHistoryTab() {
    final currentYear = DateTime.now().year;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () => _saveYearSnapshot(currentYear),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.navyBlue,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(Icons.save_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Save $currentYear Snapshot',
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold)),
                        Text(
                            'Wealth: ${_formatMoney(_totalWealth)} | Zakat: ${_formatMoney(_activeZakatDue)}',
                            style: GoogleFonts.inter(color: Colors.white60, fontSize: 11)),
                      ],
                    ),
                  ),
                  const Icon(Icons.add_circle_rounded, color: Colors.white, size: 22),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_history.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.bar_chart_rounded,
                        size: 48, color: _isDarkMode ? Colors.white.withValues(alpha: 0.15) : AppColors.navyBlue.withValues(alpha: 0.15)),
                    const SizedBox(height: 12),
                    Text('Save snapshots to start tracking year-over-year history.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                            color: _isDarkMode ? Colors.white.withValues(alpha: 0.4) : AppColors.navyBlue.withValues(alpha: 0.4), fontSize: 13)),
                  ],
                ),
              ),
            )
          else ...[
            _buildSectionHeader('Zakat Due by Year', AppColors.navyBlue),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: _cardDeco(),
              child: SizedBox(
                height: 180,
                child: CustomPaint(painter: _BarChartPainter(snapshots: _history, isDarkMode: _isDarkMode)),
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionHeader('Yearly Records', AppColors.midTeal),
            const SizedBox(height: 10),
            ..._history.reversed.map((s) => _buildHistoryCard(s)),
          ],
        ],
      ),
    );
  }

  void _saveYearSnapshot(int year) {
    final existing = _history.indexWhere((s) => s.year == year);
    final yearPayments = [..._payments, ..._fitraPayments]
        .where((p) => p.date.year == year)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    double paidFor(String obligationType) => yearPayments
        .where((p) => p.obligationType == obligationType)
        .fold(0.0, (sum, p) => sum + p.amount * _currencyRate(p.currency));
    final snap = ZakatYearSnapshot(
      year: year,
      wealth: _totalWealth,
      zakatDue: _activeZakatDue,
      zakatPaid: paidFor('haul'),
      livestockZakat: _assessmentLivestockSummary.isNotEmpty
          ? _assessmentLivestockSummary
          : null,
      // Fitra becomes due in Ramadan; outside Ramadan, the next Fitra must
      // not be recorded as an unpaid obligation.
      fitraDue: _isRamadan ? _fitraTotal : 0,
      fitraPaid: paidFor('fitra'),
      cropsDue: _cropsZakatDue,
      cropsPaid: paidFor('crops'),
      mineralsDue: _mineralsZakatDue,
      mineralsPaid: paidFor('minerals'),
      rikazDue: _rikazZakatDue,
      rikazPaid: paidFor('rikaz'),
      payments: yearPayments,
    );
    setState(() {
      if (existing >= 0) {
        _history[existing] = snap;
      } else {
        _history.add(snap);
        _history.sort((a, b) => a.year.compareTo(b.year));
      }
    });
    _savePrefs();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _isDarkMode ? const Color(0xFF2C2C2C) : AppColors.navyBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text('$year snapshot saved',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 12.5)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildHistoryCard(ZakatYearSnapshot s) {
    final paidRatio = s.zakatDue > 0 ? (s.zakatPaid / s.zakatDue).clamp(0.0, 1.0) : 0.0;

    final String statusText;
    final Color statusColor;
    if (s.zakatDue <= 0) {
      statusText = 'No Zakat Due';
      statusColor = Colors.grey;
    } else if (s.zakatPaid >= s.zakatDue - 1.0 || (s.zakatDue - s.zakatPaid) <= 1.0) {
      statusText = 'Fully Paid';
      statusColor = const Color(0xFF2E7D32);
    } else if (s.zakatPaid <= 0) {
      statusText = 'Unpaid';
      statusColor = AppColors.coralOrange;
    } else {
      statusText = 'Partially Paid';
      statusColor = Colors.amber[800]!;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${s.year}',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 15, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(statusText,
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _historyChip('Net Wealth', _formatCompactMoney(s.wealth)),
              const SizedBox(width: 10),
              _historyChip('Total Due', _formatMoney(_yearTotalDue(s))),
              const SizedBox(width: 10),
              _historyChip('Total Paid', _formatMoney(_yearTotalPaid(s))),
            ],
          ),
          // Per-type breakdown: Haul, Ushr, Minerals, Rikaz, Fitra
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _historyBreakdownRow('Type', dueLabel: 'Due', paidLabel: 'Paid', isHeader: true),
                _historyBreakdownRow('Haul',
                    due: s.zakatDue, paid: s.zakatPaid,
                    livestockSummary: (s.livestockZakat != null && s.livestockZakat!.isNotEmpty) ? s.livestockZakat : null),
                _historyBreakdownRow('Ushr', due: s.cropsDue, paid: s.cropsPaid),
                _historyBreakdownRow('Minerals', due: s.mineralsDue, paid: s.mineralsPaid),
                _historyBreakdownRow('Rikaz', due: s.rikazDue, paid: s.rikazPaid),
                if (s.fitraDue > 0 || s.fitraPaid > 0)
                  _historyBreakdownRow('Fitra', due: s.fitraDue, paid: s.fitraPaid),
              ],
            ),
          ),
          if (s.payments.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${s.payments.length} payment record${s.payments.length == 1 ? '' : 's'} in ${s.year}',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: _isDarkMode ? Colors.white60 : AppColors.navyBlue.withValues(alpha: 0.65),
              ),
            ),
          ],
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: paidRatio,
              minHeight: 5,
              backgroundColor: const Color(0xFFEEEEEE),
              valueColor: AlwaysStoppedAnimation<Color>(
                  paidRatio >= 1.0 ? const Color(0xFF2E7D32) : AppColors.midTeal),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => _exportYearRecordPdf(s),
                child: Text('Export PDF',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.midTeal,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 18),
              GestureDetector(
                onTap: () async {
                  final confirm = await _confirmDeletion(
                      'Are you sure you want to delete the snapshot record for ${s.year}?');
                  if (confirm) {
                    setState(() => _history.removeWhere((x) => x.year == s.year));
                    _savePrefs();
                  }
                },
                child: Text('Delete',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.coralOrange.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _historyChip(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 9.5, color: _isDarkMode ? Colors.white70 : AppColors.navyBlue.withValues(alpha: 0.5))),
            const SizedBox(height: 2),
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
          ],
        ),
      ),
    );
  }

  double _yearTotalDue(ZakatYearSnapshot s) =>
      s.zakatDue +
      s.fitraDue +
      s.cropsDue +
      s.mineralsDue +
      s.rikazDue;

  double _yearTotalPaid(ZakatYearSnapshot s) =>
      s.zakatPaid +
      s.fitraPaid +
      s.cropsPaid +
      s.mineralsPaid +
      s.rikazPaid;

  Widget _historyBreakdownRow(
    String label, {
    double due = 0,
    double paid = 0,
    String? livestockSummary,
    String? dueLabel,
    String? paidLabel,
    bool isHeader = false,
  }) {
    final textColor = _isDarkMode ? Colors.white : AppColors.navyBlue;
    final mutedColor = _isDarkMode ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.55);
    if (isHeader) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(dueLabel ?? 'Type',
                  style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: mutedColor)),
            ),
            Expanded(
              child: Text(dueLabel ?? 'Due',
                  textAlign: TextAlign.end,
                  style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: mutedColor)),
            ),
            Expanded(
              child: Text(paidLabel ?? 'Paid',
                  textAlign: TextAlign.end,
                  style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: mutedColor)),
            ),
          ],
        ),
      );
    }
    final hasLivestock = livestockSummary != null && livestockSummary.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: textColor)),
              ),
              Expanded(
                child: Text(_formatMoney(due),
                    textAlign: TextAlign.end,
                    style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: textColor)),
              ),
              Expanded(
                child: Text(_formatMoney(paid),
                    textAlign: TextAlign.end,
                    style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32))),
              ),
            ],
          ),
          if (hasLivestock)
            Text('  + $livestockSummary',
                style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontStyle: FontStyle.italic,
                    color: mutedColor)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // CHARITY DIRECTORY SHEET
  // ═══════════════════════════════════════════════════════════════

  void _showCharityDirectory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 430),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (ctx, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: _isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF5F7FA),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: _isDarkMode ? Colors.white24 : const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(2))),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.handshake_rounded, color: AppColors.coralOrange, size: 20),
                        const SizedBox(width: 10),
                        Text('Verified Charity Directory',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                        'Zakat-eligible organizations mapped to Surah At-Tawbah 9:60 categories. Tap "Go to Donation Page" to pay securely online.',
                        style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: _isDarkMode ? Colors.white70 : AppColors.navyBlue.withValues(alpha: 0.55),
                            height: 1.4)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: _charityDirectory.length,
                  itemBuilder: (_, i) => _buildCharityCard(_charityDirectory[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCharityCard(_CharityOrg org) {
    final color = _categoryColor(org.category);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(org.name,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 13, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(org.country,
                    style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: _isDarkMode ? Colors.white.withValues(alpha: 0.5) : AppColors.navyBlue.withValues(alpha: 0.5))),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(org.category,
                style: GoogleFonts.inter(
                    fontSize: 9.5, fontWeight: FontWeight.bold, color: color)),
          ),
          const SizedBox(height: 8),
          Text(org.description,
              style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: _isDarkMode ? Colors.white.withValues(alpha: 0.6) : AppColors.navyBlue.withValues(alpha: 0.6),
                  height: 1.5)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showDonateRedirectDialog(org),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _isDarkMode ? AppColors.midTeal : AppColors.navyBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.open_in_new_rounded, size: 13, color: Colors.white),
                          const SizedBox(width: 5),
                          Text('Go to Donation Page',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    // Log payment directly in app
                    Navigator.pop(context); // close directory sheet
                    _showAddPaymentDialog(
                      isFitra: false,
                      prefilledRecipient: org.name,
                      prefilledCategory: org.category,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _isDarkMode ? Colors.white.withValues(alpha: 0.07) : AppColors.navyBlue.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bookmark_add_rounded, size: 13, color: _isDarkMode ? Colors.white : AppColors.navyBlue),
                          const SizedBox(width: 5),
                          Text('Log Local Payment',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDonateRedirectDialog(_CharityOrg org) {
    final amountCtrl = TextEditingController(text: _stillOwed.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: AlertDialog(
              backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Donate to ${org.name}',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: _isDarkMode ? Colors.white : AppColors.navyBlue,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'We will redirect you to the official donation page for ${org.name}. Enter the amount you wish to pay, and it will be saved in your DeenMate logs.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _isDarkMode ? Colors.white.withValues(alpha: 0.65) : AppColors.navyBlue.withValues(alpha: 0.65),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Amount (${_currency.code})',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _isDarkMode ? Colors.white : AppColors.navyBlue,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _isDarkMode ? Colors.white : AppColors.navyBlue,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      filled: true,
                      fillColor: _isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF5F7FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _isDarkMode ? Colors.white.withValues(alpha: 0.5) : AppColors.navyBlue.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isDarkMode ? AppColors.midTeal : AppColors.navyBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final amount = double.tryParse(amountCtrl.text) ?? 0.0;
                    if (amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.coralOrange,
                          behavior: SnackBarBehavior.floating,
                          content: Text('Enter an amount greater than 0.',
                              style: GoogleFonts.inter(fontSize: 12.5)),
                        ),
                      );
                      return;
                    }
                    final amountBDT = amount * _toBDT;
                    if (amountBDT > _stillOwed + 0.01) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.coralOrange,
                          behavior: SnackBarBehavior.floating,
                          content: Text(
                              'Amount exceeds remaining Haul Zakat to pay (max ${_formatMoney(_stillOwed)}).',
                              style: GoogleFonts.inter(fontSize: 12.5)),
                        ),
                      );
                      return;
                    }
                    // Log payment directly
                    final payment = ZakatPayment(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      amount: amount,
                      currency: _currency.code,
                      recipient: org.name,
                      category: org.category,
                      date: DateTime.now(),
                      note: 'Paid via official charity donation page.',
                    );
                    setState(() {
                      _payments.add(payment);
                    });
                    _savePrefs();
                    Navigator.pop(ctx);
                    _visitCharityWebsite(org);
                  },
                  child: Text(
                    'Proceed to Pay',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _visitCharityWebsite(_CharityOrg org) async {
    final Uri url = Uri.parse(org.website);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.coralOrange,
            behavior: SnackBarBehavior.floating,
            content: Text('Could not open external web page for this charity.'),
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // STYLING HELPERS
  // ─────────────────────────────────────────────────────────────

  BoxDecoration _cardDeco() => BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      );

  Widget _navyButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.navyBlue,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 5),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 6 — GUIDE
  // ═══════════════════════════════════════════════════════════════

  Widget _buildGuideTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF14243B), Color(0xFF1B4D3E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: AppColors.navyBlue.withValues(alpha: 0.28), blurRadius: 14, offset: const Offset(0, 6))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.help_outline_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('How Zakat Manager Works', style: GoogleFonts.poppins(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  Text('دَلِيلُ مُدِيرِ الزَّكَاة', style: GoogleFonts.amiri(color: const Color(0xFFA5D6A7), fontSize: 13, fontWeight: FontWeight.bold)),
                ])),
              ]),
              const SizedBox(height: 12),
              Text('Follow these 5 steps to calculate, track, and pay your Zakat correctly — in sha Allah.', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.9), fontSize: 11.5, height: 1.45)),
            ]),
          ),
          const SizedBox(height: 20),
          _buildGuideStep(1, 'Enter Your Wealth', Icons.calculate_rounded, AppColors.navyBlue,
            'Open the Calculator tab and enter all your zakatable assets:\n\n'
            '• Cash & bank savings\n'
            '• Gold (by karat — 24k, 22k, 21k, 18k)\n'
            '• Silver (in grams)\n'
            '• Stocks & investments\n'
            '• Business inventory & trade goods\n'
            '• Money owed to you (receivables)\n'
            '• Net rental income\n'
            '• Agricultural harvest (Ushr)\n'
            '• Mined minerals or found treasure (Rikaz)\n\n'
            'Subtract immediate liabilities (debts due now). Net zakatable wealth is calculated automatically.'),
          _buildGuideStep(2, 'Set Your Haul Start Date', Icons.hourglass_bottom_rounded, const Color(0xFF6A1B9A),
            'The Haul is the full Islamic lunar year (354 days) your wealth must be held before standard Zakat becomes obligatory.\n\n'
            '• Go to the Haul tab\n'
            '• Set the date your wealth first reached Nisab\n'
            '• The app tracks the Hijri anniversary automatically and notifies you\n\n'
            'Note: Agricultural Zakat (Ushr), Mineral Zakat, and Rikaz (Buried Treasure) do NOT need a Haul — they are due the moment of harvest, extraction, or discovery.'),
          _buildGuideStep(3, 'Zakat Becomes Due', Icons.notifications_active_rounded, AppColors.coralOrange,
            'Two types of obligation — both tracked in the Calculator tab:\n\n'
            'Haul-Based (Standard Wealth — 2.5%)\n'
            'Covers gold, silver, cash, stocks, business assets, and rental income. Due after Haul completes.\n\n'
            'Event-Based (Immediate — No Haul Required)\n'
            '• Crops: 10% if rain-fed / 5% if irrigated — due on harvest day (Quran 6:141)\n'
            '• Minerals: 2.5% if value >= Nisab — due on extraction (scholarly consensus)\n'
            '• Rikaz: 20% flat — due on discovery, no Nisab required (Bukhari 1499)\n\n'
            'You will receive an app notification when your Haul year completes.'),
          _buildGuideStep(4, 'Log Your Payments', Icons.receipt_long_rounded, const Color(0xFF2E7D32),
            'Once Zakat is due, go to the Payments tab:\n\n'
            '• Tap "Log Payment" to record each payment\n'
            '• Assign it to one of the 8 Asnaf categories (Surah 9:60)\n'
            '• Supports BDT, USD, EUR and all major currencies — auto-converted at live rates\n'
            '• Use the Verified Charity Directory to find Zakat-eligible organizations\n\n'
            'Smart Overpayment:\nIf you pay more than your remaining Zakat, the app automatically splits the entry into a Zakat portion and a Sadaqah (voluntary) portion — both are recorded.'),
          _buildGuideStep(5, 'Track Your History', Icons.bar_chart_rounded, Colors.teal,
            'The History tab shows your complete year-by-year Zakat record:\n\n'
            '• Bar chart: Zakat Due vs. Paid for each year\n'
            '• Each year\'s wealth snapshot is locked permanently when the Haul completes\n'
            '• Export a full PDF financial statement from the Payments tab\n\n'
            'All data is stored securely on your device and persists across app restarts.'),
          const SizedBox(height: 8),
          _buildRuleSectionCard(
            title: 'Quick Reference — All Zakat Types',
            subtitle: 'Rates, Nisab, and timing at a glance',
            icon: Icons.table_chart_rounded,
            iconColor: AppColors.navyBlue,
            child: Column(children: [
              _buildGuideRefRow('Cash, Gold, Silver, Stocks', '2.5%', 'After Haul', const Color(0xFF1565C0)),
              _buildGuideRefRow('Business Inventory', '2.5%', 'After Haul', const Color(0xFF1565C0)),
              _buildGuideRefRow('Net Rental Income', '2.5%', 'After Haul', const Color(0xFF1565C0)),
              _buildGuideRefRow('Camels (>= 5)', 'Animal', 'After Haul', const Color(0xFF2E7D32)),
              _buildGuideRefRow('Cattle (>= 30)', 'Animal', 'After Haul', const Color(0xFF2E7D32)),
              _buildGuideRefRow('Sheep/Goats (>= 40)', 'Animal', 'After Haul', const Color(0xFF2E7D32)),
              _buildGuideRefRow('Crops (>= 653 kg)', '10% / 5%', 'On harvest day', Colors.teal),
              _buildGuideRefRow('Minerals (>= Nisab)', '2.5%', 'On extraction', Colors.teal),
              _buildGuideRefRow('Rikaz (any amount)', '20%', 'On discovery', AppColors.coralOrange),
              _buildGuideRefRow('Zakat al-Fitr', 'Fixed/person', 'Before Eid prayer', const Color(0xFF6A1B9A)),
            ]),
          ),
          const SizedBox(height: 16),
          _buildRuleSectionCard(
            title: 'Live Nisab Values',
            subtitle: 'Minimum wealth threshold for Zakat',
            icon: Icons.price_check_rounded,
            iconColor: Colors.amber.shade800,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildGuideNisabRow('Gold Nisab (85g × 24k)', _formatMoney(85 * _effectiveGoldPrice)),
              _buildGuideNisabRow('Silver Nisab (595g)', _formatMoney(595 * _effectiveSilverPrice)),
              _buildGuideNisabRow('Crops Nisab (5 Wasaq)', '653 kg minimum'),
              _buildGuideNisabRow('Minerals Nisab', 'Same as currency Nisab'),
              _buildGuideNisabRow('Rikaz Nisab', 'None — any amount triggers 20%'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Text('Your app uses ${_nisabStandard == "gold" ? "Gold" : "Silver"} Nisab standard. Change it in Calculator → Settings.', style: GoogleFonts.inter(fontSize: 11, color: _isDarkMode ? Colors.amber[200] : Colors.amber[900], height: 1.4)),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideStep(int number, String title, IconData icon, Color color, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: _isDarkMode ? 0.15 : 0.07),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Center(child: Text('$number', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))),
            ),
            const SizedBox(width: 10),
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13.5, color: _isDarkMode ? Colors.white : AppColors.navyBlue))),
            GestureDetector(
              onTap: () => setState(() => _tab = (number - 1).clamp(0, 5)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                child: Text('Go →', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(content, style: GoogleFonts.inter(fontSize: 12, color: _isDarkMode ? Colors.white.withValues(alpha: 0.82) : AppColors.navyBlue.withValues(alpha: 0.8), height: 1.65)),
        ),
      ]),
    );
  }

  Widget _buildGuideRefRow(String type, String rate, String timing, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Expanded(child: Text(type, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _isDarkMode ? Colors.white : AppColors.navyBlue))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
          child: Text(rate, style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        const SizedBox(width: 8),
        Text(timing, style: GoogleFonts.inter(fontSize: 9.5, color: _isDarkMode ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.45))),
      ]),
    );
  }

  Widget _buildGuideNisabRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: _isDarkMode ? Colors.white70 : AppColors.navyBlue.withValues(alpha: 0.7)))),
        Text(value, style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // CROPS / MINERALS / RIKAZ SECTION BUILDERS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSectionInputRow({
    required IconData icon,
    required String label,
    required String sub,
    required TextEditingController ctrl,
    required String suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _isDarkMode ? Colors.white70 : AppColors.navyBlue.withValues(alpha: 0.6)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _isDarkMode ? Colors.white : AppColors.navyBlue,
                  ),
                ),
                if (sub.isNotEmpty)
                  Text(
                    sub,
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      color: _isDarkMode ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.45),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 95,
            child: TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _isDarkMode ? Colors.white : AppColors.navyBlue,
              ),
              decoration: InputDecoration(
                suffixText: ' $suffix',
                suffixStyle: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _isDarkMode ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.4),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                filled: true,
                fillColor: _isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF5F7FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => _recalculate(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImmediateBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCropsZakatSection() {
    final harvestKg = double.tryParse(_cropsHarvestKgCtrl.text.replaceAll(',', '')) ?? 0;
    final meetsNisab = harvestKg >= 653;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFF2E7D32).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.grass_rounded, color: Color(0xFF2E7D32), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Agricultural Zakat — Ushr', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
            Text('Due at harvest · No Haul required · Quran 6:141', style: GoogleFonts.inter(fontSize: 10.5, color: _isDarkMode ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.5))),
          ])),
          _buildImmediateBadge('Harvest Day', const Color(0xFF2E7D32)),
        ]),
        const SizedBox(height: 12),
        _buildSectionInputRow(
          icon: Icons.scale_outlined,
          label: 'Harvest Weight',
          sub: 'After threshing (kg)',
          ctrl: _cropsHarvestKgCtrl,
          suffix: 'kg',
        ),
        const Divider(height: 16, color: Color(0xFFEEEEEE)),
        _buildSectionInputRow(
          icon: Icons.sell_outlined,
          label: 'Market Price / kg',
          sub: 'Price per kg in ${_currency.code}',
          ctrl: _cropsPricePerKgCtrl,
          suffix: _currency.symbol,
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: meetsNisab ? const Color(0xFF2E7D32).withValues(alpha: 0.09) : (_isDarkMode ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF5F7FA)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: meetsNisab ? const Color(0xFF2E7D32).withValues(alpha: 0.25) : Colors.transparent),
          ),
          child: Row(children: [
            Icon(meetsNisab ? Icons.check_circle_rounded : Icons.info_outline_rounded, size: 15, color: meetsNisab ? const Color(0xFF2E7D32) : (_isDarkMode ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.4))),
            const SizedBox(width: 8),
            Expanded(child: Text(
              meetsNisab
                ? 'Nisab met (≥ 653 kg) — Zakat is due on this harvest'
                : 'Nisab: 653 kg (5 Wasaq). Your harvest: ${harvestKg.toStringAsFixed(0)} kg — below threshold',
              style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w600, color: meetsNisab ? const Color(0xFF2E7D32) : (_isDarkMode ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.5))),
            )),
          ]),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _isDarkMode ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Irrigation Method', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white70 : AppColors.navyBlue)),
            const SizedBox(height: 8),
            Row(children: [
              _buildCropChip('Rain-fed / Stream', true),
              const SizedBox(width: 8),
              _buildCropChip('Irrigated (pump)', false),
            ]),
            const SizedBox(height: 6),
            Text(
              _cropsRainFed
                ? 'Rate: 10% (Full Ushr) — Sahih al-Bukhari (1483)'
                : 'Rate: 5% (Half Ushr) — Sahih al-Bukhari (1483)',
              style: GoogleFonts.inter(fontSize: 10, color: _isDarkMode ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.5)),
            ),
          ]),
        ),
        if (meetsNisab && _cropsZakatDue > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1B4D3E), Color(0xFF2E7D32)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.agriculture_rounded, color: Colors.white70, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Crops Zakat Due (This Harvest — No Haul)', style: GoogleFonts.inter(color: Colors.white70, fontSize: 10.5)),
                Text(_formatMoney(_cropsZakatDue), style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ])),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _buildCropChip(String label, bool isRainFed) {
    final selected = _cropsRainFed == isRainFed;
    return Expanded(
      child: GestureDetector(
        onTap: () { setState(() => _cropsRainFed = isRainFed); _recalculate(); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected
              ? (isRainFed ? const Color(0xFF2E7D32) : AppColors.navyBlue)
              : (_isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.white),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? Colors.transparent : (_isDarkMode ? Colors.white24 : const Color(0xFFDDDDDD)),
            ),
          ),
          child: Center(child: Text(label, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: selected ? Colors.white : (_isDarkMode ? Colors.white70 : AppColors.navyBlue.withValues(alpha: 0.7))), textAlign: TextAlign.center)),
        ),
      ),
    );
  }

  Widget _buildMineralsRikazSection() {
    final mineralsVal = (double.tryParse(_mineralsValueCtrl.text.replaceAll(',', '')) ?? 0) * _toBDT;
    final rikazVal = (double.tryParse(_rikazValueCtrl.text.replaceAll(',', '')) ?? 0) * _toBDT;
    final mineralsMeetsNisab = mineralsVal >= _nisabBDT && _nisabBDT > 0;
    return Column(children: [
      // Minerals card
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.navyBlue.withValues(alpha: 0.22)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.navyBlue.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.diamond_outlined, color: AppColors.navyBlue, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Mineral Zakat — Ma'adin", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
              Text('2.5% upon extraction · No Haul · Nisab required', style: GoogleFonts.inter(fontSize: 10.5, color: _isDarkMode ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.5))),
            ])),
            _buildImmediateBadge('On Extraction', AppColors.navyBlue),
          ]),
          const SizedBox(height: 12),
          _buildSectionInputRow(
            icon: Icons.hardware_outlined,
            label: 'Extracted Mineral Value',
            sub: 'Market value of total extracted batch',
            ctrl: _mineralsValueCtrl,
            suffix: _currency.symbol,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: mineralsMeetsNisab ? AppColors.navyBlue.withValues(alpha: 0.08) : (_isDarkMode ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF5F7FA)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: mineralsMeetsNisab ? AppColors.navyBlue.withValues(alpha: 0.2) : Colors.transparent),
            ),
            child: Row(children: [
              Icon(mineralsMeetsNisab ? Icons.check_circle_rounded : Icons.info_outline_rounded, size: 15, color: mineralsMeetsNisab ? AppColors.navyBlue : (_isDarkMode ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.4))),
              const SizedBox(width: 8),
              Expanded(child: Text(
                mineralsMeetsNisab
                  ? 'Nisab met — 2.5% due: ${_formatMoney(_mineralsZakatDue)}'
                  : 'Nisab: ${_formatMoney(_nisabBDT)} (85g gold). Extracted: ${_formatMoney(mineralsVal)} — below threshold',
                style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w600, color: mineralsMeetsNisab ? AppColors.navyBlue : (_isDarkMode ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.5))),
              )),
            ]),
          ),
          if (mineralsMeetsNisab && _mineralsZakatDue > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.navyBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.bolt_rounded, color: AppColors.navyBlue, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Mineral Zakat Due (Immediate — No Haul)', style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.navyBlue)),
                  Text(_formatMoney(_mineralsZakatDue), style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
                ])),
              ]),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 12),
      // Rikaz card
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.coralOrange.withValues(alpha: 0.3)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.coralOrange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.auto_awesome_rounded, color: AppColors.coralOrange, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Buried Treasure — Rikaz (رِكَاز)', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: _isDarkMode ? Colors.white : AppColors.navyBlue)),
              Text('20% Khums · No Nisab · Due immediately on discovery', style: GoogleFonts.inter(fontSize: 10.5, color: _isDarkMode ? Colors.white54 : AppColors.navyBlue.withValues(alpha: 0.5))),
            ])),
            _buildImmediateBadge('On Discovery', AppColors.coralOrange),
          ]),
          const SizedBox(height: 12),
          _buildSectionInputRow(
            icon: Icons.savings_outlined,
            label: 'Found Treasure Value',
            sub: 'Total market value of discovered buried wealth',
            ctrl: _rikazValueCtrl,
            suffix: _currency.symbol,
          ),
          if (rikazVal > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF7B3F00), Color(0xFFBF6716)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Rikaz Due (Khums — 20% Immediate)', style: GoogleFonts.inter(color: Colors.white70, fontSize: 10.5)),
                  Text(_formatMoney(_rikazZakatDue), style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ])),
              ]),
            ),
          ],
        ]),
      ),
    ]);
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: _isDarkMode ? Colors.white.withValues(alpha: 0.08) : AppColors.navyBlue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: _isDarkMode ? Colors.white : AppColors.navyBlue, size: 16),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOM PAINTERS
// ─────────────────────────────────────────────────────────────────────────────

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color lineColor;

  const _SparklinePainter({required this.data, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final minV = data.reduce(math.min);
    final maxV = data.reduce(math.max);
    final range = (maxV - minV) == 0 ? 1.0 : (maxV - minV);
    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = size.width * i / (data.length - 1);
      final y = size.height - (size.height * (data[i] - minV) / range);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.data != data || old.lineColor != lineColor;
}

class _BarChartPainter extends CustomPainter {
  final List<ZakatYearSnapshot> snapshots;
  final bool isDarkMode;
  const _BarChartPainter({required this.snapshots, required this.isDarkMode});

  @override
  void paint(Canvas canvas, Size size) {
    if (snapshots.isEmpty) return;
    final maxZakatDue = snapshots.map((s) => s.zakatDue).reduce(math.max);
    final maxPaid = snapshots.map((s) => s.zakatPaid).reduce(math.max);
    final maxVal = math.max(maxZakatDue, maxPaid);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    if (maxVal == 0) {
      textPainter
        ..text = TextSpan(
            text: 'No Zakat amounts recorded yet for chart',
            style: GoogleFonts.inter(
                fontSize: 11,
                color: isDarkMode ? Colors.white38 : const Color(0xFF1A2E40).withValues(alpha: 0.38)))
        ..layout();
      textPainter.paint(
          canvas, Offset(size.width / 2 - textPainter.width / 2, size.height / 2 - textPainter.height / 2));
      return;
    }

    final barWidth = (size.width / snapshots.length) * 0.55;
    final gap = size.width / snapshots.length;

    for (int i = 0; i < snapshots.length; i++) {
      final s = snapshots[i];
      final barH = (s.zakatDue / maxVal) * (size.height - 30);
      final x = gap * i + (gap - barWidth) / 2;
      final y = size.height - 22 - barH;

      if (barH > 0) {
        // Bar background (Zakat Due)
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, y, barWidth, barH), const Radius.circular(5)),
          Paint()..color = isDarkMode ? const Color(0xFF2C3E50) : const Color(0xFF1A2E40),
        );
      }

      // Paid overlay
      if (s.zakatPaid > 0) {
        final paidH = (s.zakatPaid / maxVal).clamp(0.0, 1.0) * (size.height - 30);
        final paidY = barH > 0 ? (y + barH - paidH) : (size.height - 22 - paidH);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x, paidY, barWidth, paidH), const Radius.circular(5)),
          Paint()..color = const Color(0xFF459490),
        );
      }

      // Year label
      textPainter
        ..text = TextSpan(
            text: '${s.year}',
            style: GoogleFonts.inter(
                fontSize: 9, color: isDarkMode ? Colors.white70 : const Color(0xFF1A2E40), fontWeight: FontWeight.w600))
        ..layout();
      textPainter.paint(
          canvas, Offset(x + barWidth / 2 - textPainter.width / 2, size.height - 18));
    }

    // Legend
    final legendPaint = Paint()..style = PaintingStyle.fill;
    legendPaint.color = isDarkMode ? const Color(0xFF2C3E50) : const Color(0xFF1A2E40);
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 12, 6), const Radius.circular(2)),
        legendPaint);
    legendPaint.color = const Color(0xFF459490);
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(18, 0, 12, 6), const Radius.circular(2)),
        legendPaint);
    textPainter
      ..text = TextSpan(
          text: 'Due   Paid',
          style: GoogleFonts.inter(fontSize: 9, color: isDarkMode ? Colors.white70 : const Color(0xFF1A2E40)))
      ..layout();
    textPainter.paint(canvas, const Offset(34, -1));
  }

  @override
  bool shouldRepaint(_BarChartPainter old) => old.snapshots != snapshots || old.isDarkMode != isDarkMode;
}

class CardBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..style = PaintingStyle.fill;

    // Draw stylized leaves in background
    final path = Path();
    path.moveTo(w * 0.85, h * 0.8);
    path.quadraticBezierTo(w * 0.75, h * 0.6, w * 0.85, h * 0.4);
    path.quadraticBezierTo(w * 0.95, h * 0.6, w * 0.85, h * 0.8);

    path.moveTo(w * 0.82, h * 0.65);
    path.quadraticBezierTo(w * 0.68, h * 0.55, w * 0.74, h * 0.45);
    path.quadraticBezierTo(w * 0.85, h * 0.52, w * 0.82, h * 0.65);
    
    canvas.drawPath(path, paint);

    // Draw a coin outline in background
    final coinPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    canvas.drawCircle(Offset(w * 0.15, h * 0.3), 20.0, coinPaint);
    canvas.drawCircle(Offset(w * 0.15, h * 0.3), 15.0, coinPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
