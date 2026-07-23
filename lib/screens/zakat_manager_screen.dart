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

  ZakatPayment({
    required this.id,
    required this.amount,
    required this.currency,
    required this.recipient,
    required this.category,
    required this.date,
    required this.note,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'currency': currency,
        'recipient': recipient,
        'category': category,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory ZakatPayment.fromJson(Map<String, dynamic> j) => ZakatPayment(
        id: j['id'] as String,
        amount: (j['amount'] as num).toDouble(),
        currency: j['currency'] as String? ?? 'BDT',
        recipient: j['recipient'] as String,
        category: j['category'] as String,
        date: DateTime.parse(j['date'] as String),
        note: j['note'] as String? ?? '',
      );
}

class ZakatYearSnapshot {
  final int year;
  final double wealth;
  final double zakatDue;
  final double zakatPaid;

  ZakatYearSnapshot({
    required this.year,
    required this.wealth,
    required this.zakatDue,
    required this.zakatPaid,
  });

  Map<String, dynamic> toJson() => {
        'year': year,
        'wealth': wealth,
        'zakatDue': zakatDue,
        'zakatPaid': zakatPaid,
      };

  factory ZakatYearSnapshot.fromJson(Map<String, dynamic> j) =>
      ZakatYearSnapshot(
        year: j['year'] as int,
        wealth: (j['wealth'] as num).toDouble(),
        zakatDue: (j['zakatDue'] as num).toDouble(),
        zakatPaid: (j['zakatPaid'] as num).toDouble(),
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
  Timer? _priceRefreshTimer;

  bool _manualOverridePrices = false;
  final _manualGoldPriceCtrl = TextEditingController();
  final _manualSilverPriceCtrl = TextEditingController();

  // Sparkline histories
  final List<double> _goldHistory = [];
  final List<double> _silverHistory = [];

  // ── Currency ─────────────────────────────────────────────────
  String _selectedCurrency = 'BDT';
  _Currency get _currency =>
      _currencies.firstWhere((c) => c.code == _selectedCurrency,
          orElse: () => _currencies.first);
  double get _toBDT => _currency.toBDT;

  // ── Nisab ────────────────────────────────────────────────────
  String _nisabStandard = 'gold'; // 'gold' or 'silver'
  double get _effectiveGoldPrice => _manualOverridePrices
      ? (double.tryParse(_manualGoldPriceCtrl.text) ?? _goldPerGramBDT)
      : _goldPerGramBDT;
  double get _effectiveSilverPrice => _manualOverridePrices
      ? (double.tryParse(_manualSilverPriceCtrl.text) ?? _silverPerGramBDT)
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

  double _totalWealth = 0.0;
  double _zakatDue = 0.0;

  bool get _isEligible => _totalWealth >= _nisabBDT && _nisabBDT > 0;
  bool get _isHaulCompleted => _haulElapsedDays >= 354;
  bool get _isZakatObligated => _isEligible && _isHaulCompleted;
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
  double get _fitraTotal => _fitraMembers * _fitraWeightPerHead * _fitraRatePerKg;

  // ── Payments ─────────────────────────────────────────────────
  List<ZakatPayment> _payments = [];
  double get _totalPaid =>
      _payments.fold(0.0, (s, p) => s + (p.amount * _currencyRate(p.currency)));
  double get _stillOwed => (_zakatDue - _totalPaid).clamp(0.0, double.infinity);

  double get _fitraPaid =>
      _fitraPayments.fold(0.0, (s, p) => s + (p.amount * _currencyRate(p.currency)));
  double get _fitraStillOwed => (_fitraTotal - _fitraPaid).clamp(0.0, double.infinity);

  double _currencyRate(String code) {
    final c = _currencies.firstWhere((x) => x.code == code,
        orElse: () => _currencies.first);
    return c.toBDT;
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

    _manualGoldPriceCtrl.text = _goldPerGramBDT.toStringAsFixed(0);
    _manualSilverPriceCtrl.text = _silverPerGramBDT.toStringAsFixed(0);

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
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onWealthChanged() {
    _recalculate();
    _checkNisabCrossing();
  }

  // ─────────────────────────────────────────────────────────────
  // PREFERENCES STORAGE
  // ─────────────────────────────────────────────────────────────

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();

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
    }

    // Haul start date
    final haulStr = p.getString('zm_haul_start');
    if (haulStr != null) _haulStartDate = DateTime.tryParse(haulStr);

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
      _history =
          list.map((e) => ZakatYearSnapshot.fromJson(e as Map<String, dynamic>)).toList();
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

    setState(() {});
    _recalculate();
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();

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
  }

  // ─────────────────────────────────────────────────────────────
  // METAL PRICES FETCH
  // ─────────────────────────────────────────────────────────────

  Future<void> _fetchLivePrices() async {
    try {
      final metalRes = await http
          .get(Uri.parse('https://api.metals.live/v1/spot'))
          .timeout(const Duration(seconds: 8));
      if (metalRes.statusCode == 200) {
        final List<dynamic> data = json.decode(metalRes.body);
        final spot = data.first as Map<String, dynamic>;
        _goldSpotUSD = (spot['gold'] as num).toDouble();
        _silverSpotUSD = (spot['silver'] as num).toDouble();
      }
    } catch (_) {}

    try {
      final fxRes = await http
          .get(Uri.parse('https://open.er-api.com/v6/latest/USD'))
          .timeout(const Duration(seconds: 8));
      if (fxRes.statusCode == 200) {
        final fx = json.decode(fxRes.body) as Map<String, dynamic>;
        _usdToBDT = (fx['rates']['BDT'] as num).toDouble();
      }
    } catch (_) {}

    final newGold = (_goldSpotUSD / 31.1035) * _usdToBDT;
    final newSilver = (_silverSpotUSD / 31.1035) * _usdToBDT;

    if (_goldHistory.isEmpty) {
      for (int i = 8; i >= 1; i--) {
        _goldHistory.add(newGold * (1 + (math.Random().nextDouble() - 0.5) * 0.006));
        _silverHistory.add(newSilver * (1 + (math.Random().nextDouble() - 0.5) * 0.008));
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
        _pricesLastUpdated = DateFormat('hh:mm a').format(DateTime.now());

        if (!_manualOverridePrices) {
          _manualGoldPriceCtrl.text = _goldPerGramBDT.toStringAsFixed(0);
          _manualSilverPriceCtrl.text = _silverPerGramBDT.toStringAsFixed(0);
        }
      });
      _recalculate();
    }
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

    // Livestock market value (only included if meets its own nisab)
    final livestockVal = _livestockMeetsNisab ? _livestockTotalBDT : 0.0;

    final gross = cash + goldVal + silverVal + stocks + business + receivable
        + livestockVal + _customAssetsTotalBDT;
    final net = (gross - liabilities - _customLiabilitiesTotalBDT).clamp(0.0, double.infinity);

    setState(() {
      _totalWealth = net;
      _zakatDue = (net >= _nisabBDT && _isHaulCompleted) ? net * 0.025 : 0.0;
    });

    _savePrefs();
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
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Text('Confirm Deletion',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
                content: Text(message, style: GoogleFonts.inter()),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text('Cancel',
                        style: GoogleFonts.inter(
                            color: AppColors.navyBlue, fontWeight: FontWeight.bold)),
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
      color: const Color(0xFFE8E8E8), // Outer background for desktop/laptop screens
      child: Center(
        child: Container(
          width: appWidth,
          height: double.infinity,
          color: const Color(0xFFF5F7FA),
          child: Scaffold(
            backgroundColor: const Color(0xFFF5F7FA),
            body: content,
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumHeader() {
    return Container(
      height: 100,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF101B2B), Color(0xFF183B36)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Zakat Manager',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Wealth, Haul & Obligations',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _tabLabels = ['Calculator', 'Haul', 'Al-Fitr', 'Payments', 'History'];
  static const _tabIcons = [
    Icons.calculate_rounded,
    Icons.hourglass_bottom_rounded,
    Icons.people_alt_rounded,
    Icons.receipt_long_rounded,
    Icons.bar_chart_rounded,
  ];

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppColors.navyBlue.withValues(alpha: 0.06),
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
                            : AppColors.navyBlue.withValues(alpha: 0.4)),
                    const SizedBox(height: 2),
                    Text(_tabLabels[i],
                        style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: active
                                ? Colors.white
                                : AppColors.navyBlue.withValues(alpha: 0.4))),
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
        return _buildFitraTab();
      case 3:
        return _buildPaymentsTab();
      case 4:
        return _buildHistoryTab();
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
          const SizedBox(height: 16),
          // ── Custom Assets ──────────────────────────────────────
          _buildCustomFieldsSection(isLiability: false),
          const SizedBox(height: 16),
          // ── Livestock ──────────────────────────────────────────
          _buildLivestockSection(),
          const SizedBox(height: 16),
          // ── Liabilities ────────────────────────────────────────
          _buildSectionHeader('Liabilities', AppColors.coralOrange),
          const SizedBox(height: 10),
          _buildInputCard(Icons.money_off_outlined, 'Immediate Liabilities',
              'Immediate debts & outstanding dues', _liabilitiesCtrl, _currency.symbol),
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
    String fmt(double v) {
      if (v >= 1000000) return 'Tk ${(v / 1000000).toStringAsFixed(2)}M';
      if (v >= 100000) return 'Tk ${(v / 100000).toStringAsFixed(1)}L';
      if (v >= 1000) return 'Tk ${(v / 1000).toStringAsFixed(1)}K';
      return 'Tk ${v.toStringAsFixed(0)}';
    }

    final isCompleted = _zakatDue > 0 && _stillOwed <= 0;
    final hasPaidSome = _totalPaid > 0 && _zakatDue > 0;
    final double displayAmount = _zakatDue > 0 ? _stillOwed : 0.0;

    String cardTitle = 'Zakat Remaining';
    if (_zakatDue == 0) {
      cardTitle = _isEligible ? 'Awaiting Haul Completion' : 'Below Nisab Threshold';
    } else if (isCompleted) {
      cardTitle = 'Zakat Obligation';
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isEligible
              ? (isCompleted
                  ? [const Color(0xFF1B4D3E), const Color(0xFF142E24)]
                  : [const Color(0xFF14243B), const Color(0xFF1C3A27)])
              : [const Color(0xFF14243B), const Color(0xFF22364A)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: AppColors.navyBlue.withValues(alpha: 0.22),
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
                        cardTitle,
                        style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? const Color(0xFF4CAF50).withValues(alpha: 0.22)
                              : (_isZakatObligated
                                  ? const Color(0xFF4CAF50).withValues(alpha: 0.22)
                                  : (_isEligible
                                      ? Colors.amber.withValues(alpha: 0.2)
                                      : Colors.white.withValues(alpha: 0.1))),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isCompleted
                              ? 'Completed'
                              : (_isZakatObligated
                                  ? '2.5% Rate Applied'
                                  : (_isEligible ? 'Incomplete Haul' : 'Not Eligible')),
                          style: GoogleFonts.inter(
                              color: isCompleted
                                  ? const Color(0xFF81C784)
                                  : (_isZakatObligated
                                      ? const Color(0xFF81C784)
                                      : (_isEligible ? Colors.amber[200] : Colors.white60)),
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (isCompleted) ...[
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF81C784), size: 28),
                        const SizedBox(width: 10),
                        Text(
                          'Fully Paid',
                          style: GoogleFonts.poppins(
                              color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tk ${_totalPaid.toStringAsFixed(0)} logged in payments.',
                      style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.65), fontSize: 11.5),
                    ),
                  ] else ...[
                    Text(
                      'Tk ${displayAmount.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
                    ),
                    if (hasPaidSome) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (_totalPaid / _zakatDue).clamp(0.0, 1.0),
                          minHeight: 5,
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF81C784)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Paid: Tk ${_totalPaid.toStringAsFixed(0)} of Tk ${_zakatDue.toStringAsFixed(0)} due',
                        style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                      ),
                    ],
                  ],
                  if (_isEligible && !_isHaulCompleted) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 14),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Zakat is not yet due because your Haul is incomplete (lunar year elapsed: $_haulElapsedDays / 354 days).',
                              style: GoogleFonts.inter(
                                color: Colors.amber[100],
                                fontSize: 10,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.analytics_rounded, color: AppColors.navyBlue, size: 18),
                  const SizedBox(width: 8),
                  Text('Metal Rates (BDT/g)',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: AppColors.navyBlue)),
                ],
              ),
              _pricesLoading
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.navyBlue)))
                  : Text('Updated: $_pricesLastUpdated',
                      style: GoogleFonts.inter(
                          color: const Color(0xFF2E7D32),
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
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
                  _manualGoldPriceCtrl.text = _goldPerGramBDT.toStringAsFixed(0);
                  _manualSilverPriceCtrl.text = _silverPerGramBDT.toStringAsFixed(0);
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
                  color: AppColors.navyBlue,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text('Manual Override Price per Gram',
                    style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navyBlue)),
              ],
            ),
          ),
          if (_manualOverridePrices) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildOverrideField(
                      _manualGoldPriceCtrl, '24K Gold (BDT/g)', () => _recalculate()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOverrideField(_manualSilverPriceCtrl, 'Silver (BDT/g)',
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
          fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.navyBlue),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 11, color: AppColors.placeholder),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        filled: true,
        fillColor: const Color(0xFFF5F7FA),
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
                fontSize: 11, color: AppColors.navyBlue.withValues(alpha: 0.5))),
        const SizedBox(height: 3),
        Text('Tk ${price.toStringAsFixed(1)}',
            style: GoogleFonts.poppins(
                fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
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
              const Icon(Icons.currency_exchange_rounded, color: AppColors.navyBlue, size: 16),
              const SizedBox(width: 8),
              Text('Input Currency',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navyBlue)),
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
                  setState(() => _selectedCurrency = c.code);
                  _recalculate();
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
            Text('1 ${super.widget.key != null ? "" : _currency.symbol} ≈ Tk ${_toBDT.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                    fontSize: 10.5, color: AppColors.navyBlue.withValues(alpha: 0.45))),
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
              const Icon(Icons.settings_rounded, color: AppColors.navyBlue, size: 16),
              const SizedBox(width: 8),
              Text('Configuration',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navyBlue)),
            ],
          ),
          const SizedBox(height: 12),
          Text('Nisab Calculation Standard',
              style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navyBlue.withValues(alpha: 0.7))),
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
                color: AppColors.navyBlue.withValues(alpha: 0.6),
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
                      color: AppColors.navyBlue.withValues(alpha: 0.7))),
              Text('${_pureGoldEquivalentGrams.toStringAsFixed(2)} g',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navyBlue)),
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
                      color: AppColors.navyBlue.withValues(alpha: 0.7))),
              Text(
                'Tk ${(_pureGoldEquivalentGrams * _effectiveGoldPrice).toStringAsFixed(0)}',
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
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.navyBlue)),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                  fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.navyBlue),
              decoration: InputDecoration(
                suffixText: ' g',
                suffixStyle: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navyBlue.withValues(alpha: 0.4)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                filled: true,
                fillColor: const Color(0xFFF5F7FA),
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
                fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
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
                color: AppColors.navyBlue.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: AppColors.navyBlue, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.navyBlue)),
                Text(sub,
                    style: GoogleFonts.inter(
                        fontSize: 9.5,
                        color: AppColors.navyBlue.withValues(alpha: 0.45))),
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
                  fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.navyBlue),
              decoration: InputDecoration(
                suffixText: ' $suffix',
                suffixStyle: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navyBlue.withValues(alpha: 0.4)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                filled: true,
                fillColor: const Color(0xFFF5F7FA),
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
              const Icon(Icons.description_outlined, color: AppColors.navyBlue, size: 18),
              const SizedBox(width: 8),
              Text('Wealth Statement',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.navyBlue)),
            ],
          ),
          const SizedBox(height: 16),
          _stmtLine('Cash & Bank', cash.toStringAsFixed(0)),
          _stmtLine('Gold (${pureGold.toStringAsFixed(1)}g equivalent)', goldVal.toStringAsFixed(0)),
          _stmtLine('Silver (${silverGrams.toStringAsFixed(1)}g)', silverVal.toStringAsFixed(0)),
          _stmtLine('Stocks & Investments', stocks.toStringAsFixed(0)),
          _stmtLine('Business Assets', business.toStringAsFixed(0)),
          _stmtLine('Receivables', receivable.toStringAsFixed(0)),
          const Divider(height: 22, thickness: 1, color: Color(0xFFEEEEEE)),
          _stmtLine('Total Gross Assets', gross.toStringAsFixed(0), bold: true),
          _stmtLine('Less: Liabilities', liabilities.toStringAsFixed(0), isDeduction: true),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
                color: const Color(0xFFF1F5FB), borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Net Zakatable Wealth',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.navyBlue)),
                Text('Tk ${_totalWealth.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navyBlue)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF14243B), Color(0xFF1C3A27)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Zakat Due (2.5%)',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                Text('Tk ${_zakatDue.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stmtLine(String label, String value,
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
                    color: AppColors.navyBlue.withValues(alpha: bold ? 0.85 : 0.6))),
          ),
          Text(
            '${isDeduction ? '- ' : ''}Tk $value',
            style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                color: isDeduction
                    ? AppColors.coralOrange
                    : AppColors.navyBlue.withValues(alpha: 0.75)),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidelinesCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.dustyBlueTeal.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.navyBlue, size: 16),
              const SizedBox(width: 8),
              Text('Obligatory Guidelines',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navyBlue)),
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
                    color: AppColors.navyBlue.withValues(alpha: 0.68),
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
    final color = isLiability ? AppColors.coralOrange : AppColors.navyBlue;
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
    final color = isLiability ? AppColors.coralOrange : AppColors.navyBlue;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.04),
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
                        color: AppColors.navyBlue)),
                Text('${asset.currency} ${asset.value.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.navyBlue.withValues(alpha: 0.5))),
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
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                    fontSize: 11, color: AppColors.navyBlue.withValues(alpha: 0.45)),
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
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.navyBlue),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.navyBlue.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navyBlue.withValues(alpha: 0.04),
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
                            color: AppColors.navyBlue)),
                    Text('Each type has its own Nisab threshold',
                        style: GoogleFonts.inter(
                            fontSize: 10.5,
                            color: AppColors.navyBlue.withValues(alpha: 0.5))),
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
            valueCtrl: _camelValueCtrl,
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
            valueCtrl: _cattleValueCtrl,
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
            valueCtrl: _sheepValueCtrl,
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
                      color: Color(0xFF2E7D32), size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Livestock meeting nisab has been included in your total zakatable wealth. Enter market value per animal to calculate the correct amount.',
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
    required TextEditingController valueCtrl,
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
            Icon(icon, color: AppColors.navyBlue.withValues(alpha: 0.6), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                          color: AppColors.navyBlue)),
                  Text(
                    meetsNisab
                        ? 'Nisab met ($nisab+) · Zakat due'
                        : 'Nisab: $nisab animals minimum (you have $count)',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: meetsNisab
                          ? const Color(0xFF2E7D32)
                          : AppColors.navyBlue.withValues(alpha: 0.4),
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
                          color: AppColors.navyBlue)),
                ),
                _iconBtn(Icons.add_rounded, onIncrement),
              ],
            ),
          ],
        ),
        if (count > 0) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: valueCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.navyBlue),
                  decoration: InputDecoration(
                    hintText: 'Market value per animal (Tk)',
                    hintStyle: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.navyBlue.withValues(alpha: 0.25)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: const Color(0xFFF5F7FA),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
            ],
          ),
          if (meetsNisab && zakatText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '📋 Zakat due: $zakatText',
                style: GoogleFonts.inter(
                    fontSize: 10.5,
                    color: const Color(0xFF2E7D32),
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ],
    );
  }

  /// Camel Zakat calculation per classical Hanafi/Shafi'i fiqh tiers.
  String _computeCamelZakat(int n) {
    if (n < 5) return '';
    if (n <= 9)  return '${(n ~/ 5)} sheep/goat (1 per 5 camels)';
    if (n <= 14) return '2 sheep/goats';
    if (n <= 19) return '3 sheep/goats';
    if (n <= 24) return '4 sheep/goats';
    if (n <= 35) return '1 bint makhad (1-yr she-camel)';
    if (n <= 45) return '1 bint labun (2-yr she-camel)';
    if (n <= 60) return '1 hiqqah (3-yr she-camel)';
    if (n <= 75) return '1 jadha\'ah (4-yr she-camel)';
    if (n <= 90) return '2 bint labun';
    if (n <= 120) return '2 hiqqah';
    // Above 120: for every 40 → 1 bint labun; for every 50 → 1 hiqqah
    final labun = (n ~/ 40);
    final hiqqah = (n ~/ 50);
    return '~$labun bint labun + ~$hiqqah hiqqah (per 40/50 rule)';
  }

  /// Cattle Zakat per classical fiqh tiers.
  String _computeCattleZakat(int n) {
    if (n < 30) return '';
    if (n <= 39) return '1 tabi\' (1-yr calf)';
    if (n <= 59) return '1 musinnah (2-yr cow)';
    if (n <= 69) return '2 tabi\'';
    if (n <= 79) return '1 musinnah + 1 tabi\'';
    if (n <= 89) return '2 musinnah';
    // 90+: per 30 → 1 tabi'; per 40 → 1 musinnah
    final tabi = (n ~/ 30);
    final musinnah = (n ~/ 40);
    return '~$tabi tabi\' + ~$musinnah musinnah (per 30/40 rule)';
  }

  /// Sheep/Goat Zakat per classical fiqh tiers.
  String _computeSheepZakat(int n) {
    if (n < 40) return '';
    if (n <= 120) return '1 sheep/goat';
    if (n <= 200) return '2 sheep/goats';
    if (n <= 300) return '3 sheep/goats';
    // 301+: 1 per every 100
    return '${(n ~/ 100)} sheep/goats';
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 1 — HAUL TRACKER
  // ═══════════════════════════════════════════════════════════════


  Widget _buildHaulTab() {
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
                              color: AppColors.navyBlue)),
                      Text('Get notified when wealth drops below or crosses Nisab',
                          style: GoogleFonts.inter(
                              fontSize: 10.5, color: AppColors.navyBlue.withValues(alpha: 0.5))),
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
                    color: AppColors.navyBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calendar_month_rounded,
                      color: AppColors.navyBlue, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Today (Hijri)',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: AppColors.navyBlue.withValues(alpha: 0.5))),
                    Text(todayHijri.toString(),
                        style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
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
                    color: AppColors.navyBlue.withValues(alpha: 0.22),
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
                    const Icon(Icons.edit_calendar_rounded, color: AppColors.navyBlue, size: 18),
                    const SizedBox(width: 8),
                    Text('Nisab Crossing Date',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: AppColors.navyBlue)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                    'Set the date your wealth first crossed the Nisab threshold. This starts the Haul clock.',
                    style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: AppColors.navyBlue.withValues(alpha: 0.55),
                        height: 1.5)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F7FA),
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
                                  ? AppColors.navyBlue
                                  : AppColors.navyBlue.withValues(alpha: 0.35)),
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
                          fontSize: 10.5, color: AppColors.navyBlue.withValues(alpha: 0.5))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TAB 2 — ZAKAT AL-FITR (Fitra)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildFitraTab() {
    final now = DateTime.now();
    final todayHijri = _Hijri.fromGregorian(now);

    // Ramadan is Month 9. Seasonal gate: Last 10 days of Ramadan (Day 20 to 29/30)
    final bool isRamadan = todayHijri.month == 9;
    final bool isFitraWindowOpen = isRamadan && todayHijri.day >= 20;

    int daysUntilWindow = 0;
    String statusMessage = '';

    if (isRamadan && todayHijri.day < 20) {
      daysUntilWindow = 20 - todayHijri.day;
      statusMessage = 'Starts in the last 10 days of Ramadan';
    } else if (!isRamadan) {
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
                    color: AppColors.navyBlue.withValues(alpha: 0.1),
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
                        ? 'Zakat al-Fitr is only payable during Ramadan, ideally in the last 10 days before the Eid prayer.'
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
                      color: AppColors.navyBlue,
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
                        fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navyBlue)),
                const SizedBox(height: 4),
                Text('Include yourself, spouse, children, and dependants',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.navyBlue.withValues(alpha: 0.5))),
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
                              color: AppColors.navyBlue)),
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
                        fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navyBlue)),
                const SizedBox(height: 6),
                Text(
                    'Staple food prices vary significantly by region and variety. Please check your local market rates and input them below.',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.navyBlue.withValues(alpha: 0.5),
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
                            color: AppColors.navyBlue),
                        decoration: InputDecoration(
                          labelText: 'Weight per person (kg)',
                          labelStyle: GoogleFonts.inter(
                              fontSize: 11, color: AppColors.placeholder),
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          filled: true,
                          fillColor: const Color(0xFFF5F7FA),
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
                            color: AppColors.navyBlue),
                        decoration: InputDecoration(
                          labelText: 'Local Price per kg (BDT)',
                          labelStyle: GoogleFonts.inter(
                              fontSize: 11, color: AppColors.placeholder),
                          suffixText: 'Tk',
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          filled: true,
                          fillColor: const Color(0xFFF5F7FA),
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
                              Text('Tk ${_fitraTotal.toStringAsFixed(0)} Paid',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('May Allah accept this purification of your fasts.',
                              style: GoogleFonts.inter(color: Colors.white60, fontSize: 11)),
                        ] else ...[
                          Text('Tk ${_fitraStillOwed.toStringAsFixed(0)}',
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
                            Text('Paid: Tk ${_fitraPaid.toStringAsFixed(0)} of Tk ${_fitraTotal.toStringAsFixed(0)}',
                                style: GoogleFonts.inter(color: Colors.white54, fontSize: 10.5)),
                          ] else ...[
                            const SizedBox(height: 6),
                            Text(
                                '$_fitraMembers members x ${_fitraWeightPerHead.toStringAsFixed(1)} kg x Tk ${_fitraRatePerKg.toStringAsFixed(0)}/kg',
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
                        fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.navyBlue)),
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
                    color: AppColors.navyBlue.withValues(alpha: 0.2),
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
                      Text('Zakat Due',
                          style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
                      const SizedBox(height: 2),
                      Text('Tk ${_zakatDue.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
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
                        Text('Tk ${_totalPaid.toStringAsFixed(0)}',
                            style: GoogleFonts.poppins(
                                color: const Color(0xFF81C784),
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
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
                        Text('Tk ${_stillOwed.toStringAsFixed(0)}',
                            style: GoogleFonts.poppins(
                                color: _stillOwed > 0
                                    ? AppColors.coralOrange
                                    : const Color(0xFF81C784),
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
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
                        size: 48, color: AppColors.navyBlue.withValues(alpha: 0.18)),
                    const SizedBox(height: 12),
                    Text('No payments logged yet.',
                        style: GoogleFonts.poppins(
                            color: AppColors.navyBlue.withValues(alpha: 0.4), fontSize: 13)),
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
                      color: AppColors.navyBlue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _isPaymentsExpanded ? 'Hide Logs' : 'Show Logs',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navyBlue,
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
                      color: AppColors.navyBlue.withValues(alpha: 0.45),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.coralOrange.withValues(alpha: 0.3)),
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
                                color: AppColors.navyBlue)),
                        Text('Browse Zakat-eligible charity donation pages',
                            style: GoogleFonts.inter(
                                fontSize: 10.5, color: AppColors.navyBlue.withValues(alpha: 0.5))),
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
              Text(DateFormat('d MMM yyyy').format(p.date),
                  style: GoogleFonts.inter(
                      fontSize: 10.5, color: AppColors.navyBlue.withValues(alpha: 0.45))),
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
                            fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navyBlue)),
                    if (p.note.isNotEmpty)
                      Text(p.note,
                          style: GoogleFonts.inter(
                              fontSize: 11, color: AppColors.navyBlue.withValues(alpha: 0.5))),
                  ],
                ),
              ),
              Text(
                  '${p.currency == "BDT" ? "Tk" : p.currency} ${p.amount.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navyBlue)),
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
                    color: AppColors.navyBlue.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.share_rounded, size: 13, color: AppColors.navyBlue),
                      const SizedBox(width: 5),
                      Text('Share Receipt',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.navyBlue)),
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

  void _showAddPaymentDialog({required bool isFitra, String? prefilledRecipient, String? prefilledCategory}) {
    final amountCtrl = TextEditingController();
    final recipientCtrl = TextEditingController(text: prefilledRecipient ?? '');
    final noteCtrl = TextEditingController();
    String currency = _selectedCurrency;
    String category = prefilledCategory ?? _zakatCategories.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 430),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                        fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navyBlue)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _sheetField(amountCtrl, 'Amount',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    ),
                    const SizedBox(width: 10),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: currency,
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.navyBlue),
                        onChanged: (v) => setModalState(() => currency = v!),
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
                const SizedBox(height: 10),
                _sheetField(recipientCtrl, 'Recipient / Organization'),
                const SizedBox(height: 10),
                if (!isFitra) ...[
                  Text('Category (from Surah At-Tawbah 9:60)',
                      style: GoogleFonts.inter(
                          fontSize: 11.5, color: AppColors.navyBlue.withValues(alpha: 0.6))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.navyBlue),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      filled: true,
                      fillColor: const Color(0xFFF5F7FA),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    items: _zakatCategories
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c, style: GoogleFonts.inter(fontSize: 12)),
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
                    if (amount <= 0 || recipientCtrl.text.trim().isEmpty) return;
                    final pay = ZakatPayment(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      amount: amount,
                      currency: currency,
                      recipient: recipientCtrl.text.trim(),
                      category: isFitra ? 'The Poor (Al-Fuqara)' : category,
                      date: DateTime.now(),
                      note: noteCtrl.text.trim(),
                    );
                    setState(() {
                      if (isFitra) {
                        _fitraPayments.insert(0, pay);
                      } else {
                        _payments.insert(0, pay);
                      }
                    });
                    _savePrefs();
                    if (Navigator.canPop(ctx)) {
                      Navigator.pop(ctx);
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.navyBlue,
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
      {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(fontSize: 13, color: AppColors.navyBlue),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            GoogleFonts.inter(fontSize: 12, color: AppColors.navyBlue.withValues(alpha: 0.5)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        filled: true,
        fillColor: const Color(0xFFF5F7FA),
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
                pw.SizedBox(height: 6),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Amount:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
                    pw.Text('$currencySymbol ${p.amount.toStringAsFixed(2)} ${p.currency}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
                  ],
                ),
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
                      pw.Text('Tk ${_totalWealth.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Nisab Standard (${_nisabStandard.toUpperCase()}):'),
                      pw.Text('Tk ${_nisabBDT.toStringAsFixed(2)}'),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Zakat Obligation (2.5%):'),
                      pw.Text('Tk ${_zakatDue.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Paid:'),
                      pw.Text('Tk ${_totalPaid.toStringAsFixed(2)}', style: pw.TextStyle(color: PdfColors.green)),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Remaining Zakat Owed:'),
                      pw.Text('Tk ${_stillOwed.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _stillOwed > 0 ? PdfColors.red : PdfColors.green)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('ZAKAT AL-FITR SUMMARY', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
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
                      pw.Text('Tk ${_fitraTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Fitra Paid:'),
                      pw.Text('Tk ${_fitraPaid.toStringAsFixed(2)}', style: pw.TextStyle(color: PdfColors.green)),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Remaining Fitra Owed:'),
                      pw.Text('Tk ${_fitraStillOwed.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _fitraStillOwed > 0 ? PdfColors.red : PdfColors.green)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            pw.Text('ASSETS BREAKDOWN', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                _pdfTableRow('Asset Category', 'Value (BDT)', isHeader: true),
                _pdfTableRow('Cash & Bank Savings', 'Tk ${cash.toStringAsFixed(0)}'),
                _pdfTableRow('Gold Equivalent Value', 'Tk ${goldVal.toStringAsFixed(0)} (${pureGoldGrams.toStringAsFixed(1)}g pure)'),
                _pdfTableRow('Silver Value', 'Tk ${silverVal.toStringAsFixed(0)} (${silverGrams.toStringAsFixed(1)}g)'),
                _pdfTableRow('Stocks & Investments', 'Tk ${stocks.toStringAsFixed(0)}'),
                _pdfTableRow('Business Assets & Inventory', 'Tk ${business.toStringAsFixed(0)}'),
                _pdfTableRow('Receivables', 'Tk ${receivable.toStringAsFixed(0)}'),
                if (_livestockMeetsNisab)
                  _pdfTableRow('Livestock Market Value', 'Tk ${livestockVal.toStringAsFixed(0)}'),
                for (var ca in _customAssets)
                  _pdfTableRow(ca.name, 'Tk ${(ca.value * _currencyRate(ca.currency)).toStringAsFixed(0)}'),
                _pdfTableRow('Immediate Liabilities (Deduction)', '- Tk ${liabilities.toStringAsFixed(0)}'),
                for (var cl in _customLiabilities)
                  _pdfTableRow('${cl.name} (Deduction)', '- Tk ${(cl.value * _currencyRate(cl.currency)).toStringAsFixed(0)}'),
              ],
            ),
            pw.SizedBox(height: 20),

            if (_payments.isNotEmpty) ...[
              pw.Text('ZAKAT PAYMENT HISTORY', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  _pdfTableRow3('Date', 'Recipient', 'Category', 'Amount', isHeader: true),
                  for (var p in _payments)
                    _pdfTableRow3(
                      DateFormat('dd MMM yyyy').format(p.date),
                      p.recipient,
                      p.category,
                      '${p.currency == "BDT" ? "Tk" : p.currency} ${p.amount.toStringAsFixed(0)}',
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
                      DateFormat('dd MMM yyyy').format(p.date),
                      p.recipient,
                      'Zakat al-Fitr',
                      '${p.currency == "BDT" ? "Tk" : p.currency} ${p.amount.toStringAsFixed(0)}',
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
                            'Wealth: Tk ${_totalWealth.toStringAsFixed(0)} | Zakat: Tk ${_zakatDue.toStringAsFixed(0)}',
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
                        size: 48, color: AppColors.navyBlue.withValues(alpha: 0.15)),
                    const SizedBox(height: 12),
                    Text('Save snapshots to start tracking year-over-year history.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                            color: AppColors.navyBlue.withValues(alpha: 0.4), fontSize: 13)),
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
                child: CustomPaint(painter: _BarChartPainter(snapshots: _history)),
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
    final snap = ZakatYearSnapshot(
      year: year,
      wealth: _totalWealth,
      zakatDue: _zakatDue,
      zakatPaid: _totalPaid,
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
        backgroundColor: AppColors.navyBlue,
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
                      fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navyBlue)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: paidRatio >= 1.0
                      ? const Color(0xFF2E7D32).withValues(alpha: 0.1)
                      : AppColors.coralOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(paidRatio >= 1.0 ? 'Fully Paid' : 'Partially Paid',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: paidRatio >= 1.0 ? const Color(0xFF2E7D32) : AppColors.coralOrange)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _historyChip('Net Wealth', 'Tk ${(s.wealth / 1000).toStringAsFixed(1)}K'),
              const SizedBox(width: 10),
              _historyChip('Zakat Due', 'Tk ${s.zakatDue.toStringAsFixed(0)}'),
              const SizedBox(width: 10),
              _historyChip('Paid', 'Tk ${s.zakatPaid.toStringAsFixed(0)}'),
            ],
          ),
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
          color: const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 9.5, color: AppColors.navyBlue.withValues(alpha: 0.5))),
            const SizedBox(height: 2),
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
          ],
        ),
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
          decoration: const BoxDecoration(
            color: Color(0xFFF5F7FA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E0),
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
                                color: AppColors.navyBlue)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                        'Zakat-eligible organizations mapped to Surah At-Tawbah 9:60 categories. Tap "Go to Donation Page" to pay securely online.',
                        style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: AppColors.navyBlue.withValues(alpha: 0.55),
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
                        fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navyBlue)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(org.country,
                    style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navyBlue.withValues(alpha: 0.5))),
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
                  color: AppColors.navyBlue.withValues(alpha: 0.6),
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
                      color: AppColors.navyBlue,
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
                      color: AppColors.navyBlue.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bookmark_add_rounded,
                              size: 13, color: AppColors.navyBlue),
                          const SizedBox(width: 5),
                          Text('Log Local Payment',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.navyBlue)),
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
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Donate to ${org.name}',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.navyBlue,
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
                      color: AppColors.navyBlue.withValues(alpha: 0.65),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Amount (${_currency.code})',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navyBlue,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navyBlue,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      filled: true,
                      fillColor: const Color(0xFFF5F7FA),
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
                      color: AppColors.navyBlue.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navyBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final amount = double.tryParse(amountCtrl.text) ?? 0.0;
                    if (amount > 0) {
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
                    }
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: AppColors.navyBlue.withValues(alpha: 0.05),
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

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.navyBlue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.navyBlue, size: 16),
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
  const _BarChartPainter({required this.snapshots});

  @override
  void paint(Canvas canvas, Size size) {
    if (snapshots.isEmpty) return;
    final maxZakat = snapshots.map((s) => s.zakatDue).reduce(math.max);
    if (maxZakat == 0) return;
    final barWidth = (size.width / snapshots.length) * 0.55;
    final gap = size.width / snapshots.length;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < snapshots.length; i++) {
      final s = snapshots[i];
      final barH = (s.zakatDue / maxZakat) * (size.height - 30);
      final x = gap * i + (gap - barWidth) / 2;
      final y = size.height - 22 - barH;

      // Bar background
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, barWidth, barH), const Radius.circular(5)),
        Paint()..color = const Color(0xFF1A2E40),
      );

      // Paid overlay
      final paidH = math.min(s.zakatPaid / maxZakat, 1.0) * (size.height - 30);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y + barH - paidH, barWidth, paidH), const Radius.circular(5)),
        Paint()..color = const Color(0xFF459490),
      );

      // Year label
      textPainter
        ..text = TextSpan(
            text: '${s.year}',
            style: GoogleFonts.inter(
                fontSize: 9, color: const Color(0xFF1A2E40), fontWeight: FontWeight.w600))
        ..layout();
      textPainter.paint(
          canvas, Offset(x + barWidth / 2 - textPainter.width / 2, size.height - 18));
    }

    // Legend
    final legendPaint = Paint()..style = PaintingStyle.fill;
    legendPaint.color = const Color(0xFF1A2E40);
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
          style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF1A2E40)))
      ..layout();
    textPainter.paint(canvas, const Offset(34, -1));
  }

  @override
  bool shouldRepaint(_BarChartPainter old) => old.snapshots != snapshots;
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
