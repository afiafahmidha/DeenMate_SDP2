import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/notification_service.dart';
import '../services/zakat_storage_service.dart';
import '../widgets/auth_header.dart'; // To access AppColors and AppLogo
import 'calendar_tab.dart' show HijriConverter;

class ZakatManagerScreen extends StatefulWidget {
  const ZakatManagerScreen({super.key});

  @override
  State<ZakatManagerScreen> createState() => _ZakatManagerScreenState();
}

class _ZakatManagerScreenState extends State<ZakatManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- Exchange Rates & Metal Prices ---
  Map<String, double> _currencyRatesToUSD = {
    'USD': 1.0,
    'BDT': 110.0,
    'SAR': 3.75,
    'EUR': 0.92,
    'GBP': 0.78,
  };
  double _goldSpotUSD = 3280.0; // fallback per troy oz
  double _silverSpotUSD = 33.0; // fallback per troy oz
  bool _pricesLoading = true;
  String _pricesLastUpdated = '--:-- --';

  // --- Active State Settings ---
  String _baseCurrency = 'BDT';
  String _nisabStandard = 'silver'; // 'silver' or 'gold'
  String _schoolOfOpinion = 'hanafi'; // 'hanafi' (jewelry zakatable) or 'others' (exempt)
  String _stockTradingIntent = 'holding'; // 'holding' (purify dividends) or 'trading' (100% value zakatable)
  DateTime? _zakatStartCrossingDate;

  // --- Controllers for Assets & Liabilities (in their chosen currencies) ---
  final TextEditingController _cashCtrl = TextEditingController(text: '0');
  String _cashCurr = 'BDT';

  final TextEditingController _goldGramsCtrl = TextEditingController(text: '0');
  final TextEditingController _goldJewelryCtrl = TextEditingController(text: '0');

  final TextEditingController _silverGramsCtrl = TextEditingController(text: '0');
  final TextEditingController _silverJewelryCtrl = TextEditingController(text: '0');

  final TextEditingController _stocksCtrl = TextEditingController(text: '0');
  String _stocksCurr = 'BDT';

  final TextEditingController _businessCtrl = TextEditingController(text: '0');
  String _businessCurr = 'BDT';

  final TextEditingController _receivableCtrl = TextEditingController(text: '0');
  String _receivableCurr = 'BDT';

  final TextEditingController _liabilitiesCtrl = TextEditingController(text: '0');
  String _liabilitiesCurr = 'BDT';

  // Calculated Values (in Base Currency)
  double _totalZakatableWealth = 0.0;
  double _zakatDue = 0.0;

  // --- Zakat al-Fitr (Fitra) State ---
  final TextEditingController _fitraFamilySizeCtrl = TextEditingController(text: '1');
  String _fitraStaple = 'Flour';
  double _fitraCustomRate = 115.0; // in BDT
  double _fitraTotal = 0.0;

  // Commodity Rates mapping in BDT (fallback)
  final Map<String, double> _fitraStapleRates = {
    'Flour': 115.0,
    'Barley': 300.0,
    'Dates': 450.0,
    'Raisins': 600.0,
    'Custom': 115.0,
  };

  // --- Stock & Crypto Purification Helper State ---
  final TextEditingController _purStockSymbolCtrl = TextEditingController();
  final TextEditingController _purStockSharesCtrl = TextEditingController(text: '0');
  final TextEditingController _purStockDividendsCtrl = TextEditingController(text: '0');
  final TextEditingController _purStockNonHalalPctCtrl = TextEditingController(text: '5.0');

  final TextEditingController _purCryptoSymbolCtrl = TextEditingController();
  final TextEditingController _purCryptoHoldingsCtrl = TextEditingController(text: '0');
  final TextEditingController _purCryptoRewardsValueCtrl = TextEditingController(text: '0');
  final TextEditingController _purCryptoRatioCtrl = TextEditingController(text: '100.0');

  List<Map<String, dynamic>> _purificationLogs = [];

  // --- Payments Log ---
  List<Map<String, dynamic>> _payments = [];

  // --- Historical YoY Trends ---
  List<Map<String, dynamic>> _history = [];
  final TextEditingController _archiveYearCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAllStoredData().then((_) {
      _fetchLiveRatesAndPrices();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cashCtrl.dispose();
    _goldGramsCtrl.dispose();
    _goldJewelryCtrl.dispose();
    _silverGramsCtrl.dispose();
    _silverJewelryCtrl.dispose();
    _stocksCtrl.dispose();
    _businessCtrl.dispose();
    _receivableCtrl.dispose();
    _liabilitiesCtrl.dispose();
    _fitraFamilySizeCtrl.dispose();
    _purStockSymbolCtrl.dispose();
    _purStockSharesCtrl.dispose();
    _purStockDividendsCtrl.dispose();
    _purStockNonHalalPctCtrl.dispose();
    _purCryptoSymbolCtrl.dispose();
    _purCryptoHoldingsCtrl.dispose();
    _purCryptoRewardsValueCtrl.dispose();
    _purCryptoRatioCtrl.dispose();
    _archiveYearCtrl.dispose();
    super.dispose();
  }

  // --- Fetch API Exchange Rates & Spot Metal Prices ---
  Future<void> _fetchLiveRatesAndPrices() async {
    try {
      final metalRes = await http
          .get(Uri.parse('https://api.metals.live/v1/spot'))
          .timeout(const Duration(seconds: 8));
      if (metalRes.statusCode == 200) {
        final List<dynamic> data = json.decode(metalRes.body);
        final Map<String, dynamic> spot = data.first as Map<String, dynamic>;
        _goldSpotUSD = (spot['gold'] as num).toDouble();
        _silverSpotUSD = (spot['silver'] as num).toDouble();
      }
    } catch (e) {
      debugPrint('Error fetching metals: $e');
    }

    try {
      final fxRes = await http
          .get(Uri.parse('https://open.er-api.com/v6/latest/USD'))
          .timeout(const Duration(seconds: 8));
      if (fxRes.statusCode == 200) {
        final Map<String, dynamic> fx = json.decode(fxRes.body);
        final rates = fx['rates'] as Map<String, dynamic>;
        _currencyRatesToUSD = {
          'USD': 1.0,
          'BDT': (rates['BDT'] as num).toDouble(),
          'SAR': (rates['SAR'] as num).toDouble(),
          'EUR': (rates['EUR'] as num).toDouble(),
          'GBP': (rates['GBP'] as num).toDouble(),
        };
      }
    } catch (e) {
      debugPrint('Error fetching forex rates: $e');
    }

    if (mounted) {
      setState(() {
        _pricesLoading = false;
        _pricesLastUpdated = DateFormat('hh:mm a').format(DateTime.now());
        _recalculateZakat(checkNisabAlert: true);
      });
    }
  }

  // --- Save & Load Handlers ---
  Future<void> _loadAllStoredData() async {
    _baseCurrency = await ZakatStorageService.getBaseCurrency();
    _nisabStandard = await ZakatStorageService.getNisabStandard();
    _schoolOfOpinion = await ZakatStorageService.getSchoolOfOpinion();
    _stockTradingIntent = await ZakatStorageService.getStockTradingIntent();
    _zakatStartCrossingDate = await ZakatStorageService.getStartCrossingDate();

    final wInputs = await ZakatStorageService.loadWealthInputs();
    _cashCtrl.text = wInputs['cash'].toString();
    _cashCurr = wInputs['cashCurrency'];
    _goldGramsCtrl.text = wInputs['goldGrams'].toString();
    _silverGramsCtrl.text = wInputs['silverGrams'].toString();
    _stocksCtrl.text = wInputs['stocks'].toString();
    _stocksCurr = wInputs['stocksCurrency'];
    _businessCtrl.text = wInputs['business'].toString();
    _businessCurr = wInputs['businessCurrency'];
    _receivableCtrl.text = wInputs['receivable'].toString();
    _receivableCurr = wInputs['receivableCurrency'];
    _liabilitiesCtrl.text = wInputs['liabilities'].toString();
    _liabilitiesCurr = wInputs['liabilitiesCurrency'];

    // Load Fitra inputs
    final fitraInputs = await ZakatStorageService.loadFitraInputs();
    _fitraFamilySizeCtrl.text = fitraInputs['familySize'].toString();
    _fitraStaple = fitraInputs['staple'];
    _fitraCustomRate = fitraInputs['customRate'];

    // Load payment logs, purification logs, history
    _payments = await ZakatStorageService.loadPayments();
    _purificationLogs = await ZakatStorageService.loadPurificationItems();
    _history = await ZakatStorageService.loadHistory();

    _recalculateZakat(checkNisabAlert: false);
  }

  Future<void> _saveWealthState() async {
    await ZakatStorageService.saveWealthInputs(
      cash: double.tryParse(_cashCtrl.text.replaceAll(',', '')) ?? 0.0,
      cashCurrency: _cashCurr,
      goldGrams: double.tryParse(_goldGramsCtrl.text.replaceAll(',', '')) ?? 0.0,
      silverGrams: double.tryParse(_silverGramsCtrl.text.replaceAll(',', '')) ?? 0.0,
      stocks: double.tryParse(_stocksCtrl.text.replaceAll(',', '')) ?? 0.0,
      stocksCurrency: _stocksCurr,
      business: double.tryParse(_businessCtrl.text.replaceAll(',', '')) ?? 0.0,
      businessCurrency: _businessCurr,
      receivable: double.tryParse(_receivableCtrl.text.replaceAll(',', '')) ?? 0.0,
      receivableCurrency: _receivableCurr,
      liabilities: double.tryParse(_liabilitiesCtrl.text.replaceAll(',', '')) ?? 0.0,
      liabilitiesCurrency: _liabilitiesCurr,
    );
  }

  Future<void> _saveSettingsState() async {
    await ZakatStorageService.setBaseCurrency(_baseCurrency);
    await ZakatStorageService.setNisabStandard(_nisabStandard);
    await ZakatStorageService.setSchoolOfOpinion(_schoolOfOpinion);
    await ZakatStorageService.setStockTradingIntent(_stockTradingIntent);
    await ZakatStorageService.setStartCrossingDate(_zakatStartCrossingDate);
  }

  // --- Zakat Calculation Logic ---
  double get _bdtRate => _currencyRatesToUSD['BDT'] ?? 110.0;
  double get _baseRateToUSD => _currencyRatesToUSD[_baseCurrency] ?? 110.0;

  double get _goldPricePerGramBase => (_goldSpotUSD / 31.1035) * _baseRateToUSD;
  double get _silverPricePerGramBase => (_silverSpotUSD / 31.1035) * _baseRateToUSD;

  // Nisab threshold in Base Currency
  double get _nisabBaseValue => _nisabStandard == 'gold'
      ? 85.0 * _goldPricePerGramBase
      : 595.0 * _silverPricePerGramBase;

  // Helper: Convert any currency amount to Base Currency
  double _convertToBase(double amount, String currency) {
    if (currency == _baseCurrency) return amount;
    final rateToUSD = _currencyRatesToUSD[currency] ?? 1.0;
    final amountUSD = amount / rateToUSD;
    return amountUSD * _baseRateToUSD;
  }

  void _recalculateZakat({bool checkNisabAlert = false}) {
    final cash = double.tryParse(_cashCtrl.text.replaceAll(',', '')) ?? 0.0;
    final cashBase = _convertToBase(cash, _cashCurr);

    final goldGrams = double.tryParse(_goldGramsCtrl.text.replaceAll(',', '')) ?? 0.0;
    final goldJewelry = double.tryParse(_goldJewelryCtrl.text.replaceAll(',', '')) ?? 0.0;
    final goldBase = goldGrams * _goldPricePerGramBase +
        (_schoolOfOpinion == 'hanafi' ? goldJewelry * _goldPricePerGramBase : 0.0);

    final silverGrams = double.tryParse(_silverGramsCtrl.text.replaceAll(',', '')) ?? 0.0;
    final silverJewelry = double.tryParse(_silverJewelryCtrl.text.replaceAll(',', '')) ?? 0.0;
    final silverBase = silverGrams * _silverPricePerGramBase +
        (_schoolOfOpinion == 'hanafi' ? silverJewelry * _silverPricePerGramBase : 0.0);

    final stocks = double.tryParse(_stocksCtrl.text.replaceAll(',', '')) ?? 0.0;
    final stocksBase = _convertToBase(stocks, _stocksCurr);

    final business = double.tryParse(_businessCtrl.text.replaceAll(',', '')) ?? 0.0;
    final businessBase = _convertToBase(business, _businessCurr);

    final receivable = double.tryParse(_receivableCtrl.text.replaceAll(',', '')) ?? 0.0;
    final receivableBase = _convertToBase(receivable, _receivableCurr);

    final liabilities = double.tryParse(_liabilitiesCtrl.text.replaceAll(',', '')) ?? 0.0;
    final liabilitiesBase = _convertToBase(liabilities, _liabilitiesCurr);

    final grossBase = cashBase + goldBase + silverBase + stocksBase + businessBase + receivableBase;
    final netBase = (grossBase - liabilitiesBase).clamp(0.0, double.infinity);

    _totalZakatableWealth = netBase;

    final threshold = _nisabBaseValue;
    _zakatDue = (netBase >= threshold) ? netBase * 0.025 : 0.0;

    // Recalculate Fitra total
    final familySize = int.tryParse(_fitraFamilySizeCtrl.text) ?? 1;
    final rateInBDT = _fitraStaple == 'Custom' ? _fitraCustomRate : (_fitraStapleRates[_fitraStaple] ?? 115.0);
    // Convert staple rate from BDT to Base Currency
    final rateBase = rateInBDT / _bdtRate * _baseRateToUSD;
    _fitraTotal = familySize * rateBase;

    if (checkNisabAlert && mounted) {
      _checkAndAlertNisabCrossing(threshold);
    }
  }

  // --- Nisab Crossing Dialog Alert & Notification ---
  void _checkAndAlertNisabCrossing(double threshold) {
    if (_totalZakatableWealth >= threshold && _zakatStartCrossingDate == null) {
      _zakatStartCrossingDate = DateTime.now();
      _saveSettingsState();

      // Schedule notification for 354 days (lunar year)
      NotificationService.instance.scheduleCustomNotification(
        id: 2001,
        title: '🌙 DeenMate • Zakat Haul Completed',
        body: 'Your wealth has held above the Nisab threshold for one full Hijri year. Your Zakat is now due!',
        scheduledTime: DateTime.now().add(const Duration(days: 354)),
      );

      // Show beautiful overlay alert
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: AppColors.white,
          title: Row(
            children: [
              const Icon(Icons.stars_rounded, color: AppColors.coralOrange, size: 28),
              const SizedBox(width: 10),
              Text(
                'Nisab Crossed! 🎉',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: AppColors.navyBlue,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Alhamdulillah, your tracked net wealth has crossed the Nisab threshold.',
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.navyBlue.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5FB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildNisabAlertRow('Net Wealth', '${_formatCurrency(_totalZakatableWealth)} $_baseCurrency'),
                    const SizedBox(height: 6),
                    _buildNisabAlertRow('Nisab Limit', '${_formatCurrency(threshold)} $_baseCurrency'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your Hijri year (Haul) clock has officially started today. We will alert you in 354 days when Zakat becomes due.',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.navyBlue.withValues(alpha: 0.6)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Subhan Allah',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.midTeal),
              ),
            ),
          ],
        ),
      );
    } else if (_totalZakatableWealth < threshold && _zakatStartCrossingDate != null) {
      // Wealth fell below Nisab
      _zakatStartCrossingDate = null;
      _saveSettingsState();
      // Inform the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Your wealth has dropped below the Nisab threshold. Your Haul clock has been reset.',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: AppColors.coralOrange,
        ),
      );
    }
  }

  Widget _buildNisabAlertRow(String label, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.placeholder)),
        Text(val, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
      ],
    );
  }

  // --- PDF Receipt Generation using 'pdf' & 'printing' ---
  Future<void> _generateReceiptPdf(Map<String, dynamic> payment) async {
    final pdf = pw.Document();
    final dateStr = payment['date'] as String;
    final amountStr = payment['amount'].toString();
    final amountBaseStr = payment['amountInBase'].toString();
    final recipient = payment['recipient'] as String;
    final category = payment['category'] as String;
    final notes = payment['notes'] as String? ?? '';
    final id = payment['id'] as String;
    final currency = payment['currency'] as String;

    DateTime? gDate = DateTime.tryParse(dateStr);
    String formattedGDate = gDate != null ? DateFormat('dd MMM yyyy').format(gDate) : dateStr;
    String formattedHDate = gDate != null ? HijriConverter.fromGregorian(gDate).format(false) : '';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(32),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColor.fromHex('#1A2E40'), width: 3),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('DEENMATE', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1A2E40'))),
                        pw.Text('Your Islamic Wealth Companion', style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: PdfColor.fromHex('#459490'))),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('OFFICIAL ZAKAT RECEIPT', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#EB8A6C'))),
                        pw.Text('Receipt ID: #$id', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#6B8A88'))),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 30),
                pw.Divider(color: PdfColor.fromHex('#1A2E40'), thickness: 1.5),
                pw.SizedBox(height: 20),

                pw.Text('Receipt Details', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1A2E40'))),
                pw.SizedBox(height: 14),

                _buildPdfReceiptRow('Transaction Date:', formattedGDate),
                if (formattedHDate.isNotEmpty) ...[
                  pw.SizedBox(height: 8),
                  _buildPdfReceiptRow('Hijri Date:', formattedHDate),
                ],
                pw.SizedBox(height: 8),
                _buildPdfReceiptRow('Payment Category:', category),
                pw.SizedBox(height: 8),
                _buildPdfReceiptRow('Recipient Org / Individual:', recipient),
                if (notes.isNotEmpty) ...[
                  pw.SizedBox(height: 8),
                  _buildPdfReceiptRow('Payment Notes:', notes),
                ],

                pw.SizedBox(height: 24),
                pw.Divider(color: PdfColor.fromHex('#EEEEEE'), thickness: 1),
                pw.SizedBox(height: 24),

                pw.Container(
                  color: PdfColor.fromHex('#F1F5FB'),
                  padding: const pw.EdgeInsets.all(16),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('TOTAL AMOUNT PAID', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1A2E40'))),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('$currency $amountStr', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#459490'))),
                          if (currency != _baseCurrency)
                            pw.Text('Equivalent to $_baseCurrency $amountBaseStr', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#6B8A88'))),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.Spacer(),

                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text('بَارَكَ اللهُ لَكَ فِي أَهْلِكَ وَمَالِكَ', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1A2E40'))),
                      pw.SizedBox(height: 4),
                      pw.Text('"May Allah bless you in your family and your wealth."', style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: PdfColor.fromHex('#6B8A88'))),
                      pw.SizedBox(height: 24),
                      pw.Text('This is a private receipt recorded and issued locally via DeenMate.', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#6B8A88'))),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'DeenMate_Zakat_Receipt_$id.pdf');
  }

  pw.Widget _buildPdfReceiptRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColor.fromHex('#6B8A88'))),
        pw.Text(value, style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#1A2E40'))),
      ],
    );
  }

  // --- Payment Log Handlers ---
  Future<void> _logPayment({
    required double amount,
    required String currency,
    required String recipient,
    required String category,
    String notes = '',
  }) async {
    final amountBase = _convertToBase(amount, currency);
    final id = math.Random().nextInt(900000) + 100000;

    final newPayment = {
      'id': id.toString(),
      'date': DateTime.now().toIso8601String(),
      'amount': amount,
      'currency': currency,
      'amountInBase': double.parse(amountBase.toStringAsFixed(2)),
      'recipient': recipient,
      'category': category,
      'notes': notes,
    };

    setState(() {
      _payments.insert(0, newPayment);
      _recalculateZakat();
    });

    await ZakatStorageService.savePayments(_payments);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment of $currency $amount logged successfully!'),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  Future<void> _deletePayment(String id) async {
    setState(() {
      _payments.removeWhere((element) => element['id'] == id);
      _recalculateZakat();
    });
    await ZakatStorageService.savePayments(_payments);
  }

  // --- History YoY Handler ---
  Future<void> _archiveYear() async {
    final yearName = _archiveYearCtrl.text.trim();
    if (yearName.isEmpty) return;

    // Calculate total payments of category 'Zakat al-Maal' for current session/year
    final maalPaid = _payments
        .where((e) => e['category'] == 'Zakat al-Maal')
        .fold(0.0, (sum, e) => sum + (e['amountInBase'] as num).toDouble());

    final newHistory = {
      'year': yearName,
      'date': DateTime.now().toIso8601String(),
      'netWealth': double.parse(_totalZakatableWealth.toStringAsFixed(2)),
      'zakatDue': double.parse(_zakatDue.toStringAsFixed(2)),
      'zakatPaid': double.parse(maalPaid.toStringAsFixed(2)),
    };

    setState(() {
      _history.removeWhere((e) => e['year'] == yearName); // overwrite if exists
      _history.add(newHistory);
      _archiveYearCtrl.clear();
    });

    await ZakatStorageService.saveHistory(_history);
    if (!mounted) return;
    Navigator.pop(context); // close archiving dialog
  }

  // --- Format Utilities ---
  String _formatCurrency(double val) {
    if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(2)}M';
    if (val >= 100000) return '${(val / 100000).toStringAsFixed(1)}L';
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(1)}K';
    return val.toStringAsFixed(0);
  }

  String _formatFullCurrency(double val) {
    final formatter = NumberFormat('#,##,###.##');
    return formatter.format(val);
  }

  // --- MAIN BUILD WIDGET ---
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
                  _buildTabBar(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildZakatTab(),
                        _buildHaulTab(),
                        _buildFitraAndPurificationTab(),
                        _buildHistoryTab(),
                        _buildCharityTab(),
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

  // ── THEMED HEADER ──────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.navyBlue, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.navyBlue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.volunteer_activism_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Zakat Manager',
                    style: GoogleFonts.poppins(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navyBlue)),
                Text('Calculate, track & purify your wealth',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.navyBlue.withValues(alpha: 0.55))),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined,
                color: AppColors.navyBlue, size: 20),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
    );
  }

  // ── THEMED TAB BAR ─────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: AppColors.navyBlue.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.navyBlue,
        unselectedLabelColor: AppColors.placeholder,
        indicatorColor: AppColors.midTeal,
        indicatorWeight: 3,
        labelPadding: EdgeInsets.zero,
        labelStyle:
            GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w500),
        tabs: const [
          Tab(icon: Icon(Icons.calculate_rounded, size: 18), text: 'Maal'),
          Tab(icon: Icon(Icons.calendar_month_rounded, size: 18), text: 'Haul'),
          Tab(icon: Icon(Icons.mosque_rounded, size: 18), text: 'Fitra'),
          Tab(icon: Icon(Icons.history_edu_rounded, size: 18), text: 'History'),
          Tab(icon: Icon(Icons.storefront_rounded, size: 18), text: 'Charity'),
        ],
      ),
    );
  }

  // ── IMAGE PLACEHOLDER BANNER ───────────────────────────────────────────────
  /// Displays an asset image if the file exists at [assetPath], otherwise
  /// shows a styled placeholder with [label]. Drop your image into
  /// `assets/images/` and add it to pubspec.yaml assets to replace.
  Widget _buildImagePlaceholder({
    required String assetPath,
    required String label,
    required IconData icon,
    double height = 140,
  }) {
    return Container(
      height: height,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.navyBlue.withValues(alpha: 0.06),
        border: Border.all(
            color: AppColors.navyBlue.withValues(alpha: 0.13), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Try loading asset; show placeholder on error
            Image.asset(
              assetPath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.navyBlue.withValues(alpha: 0.08),
                      AppColors.midTeal.withValues(alpha: 0.12),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon,
                        size: 38,
                        color: AppColors.navyBlue.withValues(alpha: 0.3)),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navyBlue.withValues(alpha: 0.45)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add image → assets/images/${assetPath.split('/').last}',
                      style: GoogleFonts.inter(
                          fontSize: 9.5,
                          color: AppColors.placeholder.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // ──────────────────────────────────────────────────────────────────────────
  // ── TAB 1: ZAKAT AL-MAAL CALCULATOR (MULTI-CURRENCY)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildZakatTab() {
    final bool isEligible = _totalZakatableWealth >= _nisabBaseValue;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Image Placeholder ──────────────────────────────────────────────
          _buildImagePlaceholder(
            assetPath: 'assets/images/zakat_maal_banner.jpg',
            label: 'Zakat al-Maal Banner',
            icon: Icons.calculate_rounded,
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          // Zakat summary card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isEligible
                    ? [AppColors.navyBlue, const Color(0xFF1C3A27)]
                    : [AppColors.navyBlue, const Color(0xFF22364A)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navyBlue.withValues(alpha: 0.20),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEligible ? 'Zakat Due (2.5%)' : 'Below Nisab Threshold',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isEligible
                            ? const Color(0xFF4CAF50).withValues(alpha: 0.22)
                            : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isEligible ? 'Eligible' : 'Not Eligible',
                        style: GoogleFonts.inter(
                          color: isEligible ? const Color(0xFF81C784) : Colors.white60,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '$_baseCurrency ${_formatFullCurrency(_zakatDue)}',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryChip(
                        'Net Wealth',
                        '${_formatCurrency(_totalZakatableWealth)} $_baseCurrency',
                        Icons.account_balance_wallet_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryChip(
                        'Nisab Standard',
                        '${_formatCurrency(_nisabBaseValue)} $_baseCurrency',
                        Icons.stars_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Price ticker bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Live Gold/Silver Prices',
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.placeholder, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    _pricesLoading
                        ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5))
                        : Text('Last updated: $_pricesLastUpdated', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
                  ],
                ),
                Row(
                  children: [
                    _buildPriceBadge('Au', '${_formatCurrency(_goldPricePerGramBase)} /g', AppColors.coralOrange),
                    const SizedBox(width: 8),
                    _buildPriceBadge('Ag', '${_formatCurrency(_silverPricePerGramBase)} /g', AppColors.dustyBlueTeal),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Zakatable Wealth Inputs Header
          _buildSectionHeader('Zakatable Wealth Assets', AppColors.navyBlue),
          const SizedBox(height: 12),

          _buildMultiCurrencyWealthRow(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Cash & Bank Balances',
            controller: _cashCtrl,
            currency: _cashCurr,
            onCurrencyChanged: (val) {
              setState(() {
                _cashCurr = val!;
                _recalculateZakat();
                _saveWealthState();
              });
            },
          ),
          const SizedBox(height: 12),

          // Gold Section with School of Opinion details
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.brightness_high_outlined, color: AppColors.coralOrange, size: 20),
                    const SizedBox(width: 8),
                    Text('Gold Grams', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.navyBlue, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildCleanTextField(
                        controller: _goldGramsCtrl,
                        label: 'Investment Gold (g)',
                        suffix: 'g',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCleanTextField(
                        controller: _goldJewelryCtrl,
                        label: 'Personal Jewelry (g)',
                        suffix: 'g',
                        enabled: true,
                      ),
                    ),
                  ],
                ),
                if (_schoolOfOpinion == 'others') ...[
                  const SizedBox(height: 8),
                  Text(
                    '* Under non-Hanafi schools, personal jewelry is exempt from Zakat.',
                    style: GoogleFonts.inter(fontSize: 10, color: AppColors.coralOrange, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Silver Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.blur_on_outlined, color: AppColors.dustyBlueTeal, size: 20),
                    const SizedBox(width: 8),
                    Text('Silver Grams', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.navyBlue, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildCleanTextField(
                        controller: _silverGramsCtrl,
                        label: 'Investment Silver (g)',
                        suffix: 'g',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCleanTextField(
                        controller: _silverJewelryCtrl,
                        label: 'Personal Jewelry (g)',
                        suffix: 'g',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          _buildMultiCurrencyWealthRow(
            icon: Icons.trending_up_outlined,
            label: 'Stocks & Portfolios',
            controller: _stocksCtrl,
            currency: _stocksCurr,
            onCurrencyChanged: (val) {
              setState(() {
                _stocksCurr = val!;
                _recalculateZakat();
                _saveWealthState();
              });
            },
          ),
          const SizedBox(height: 12),

          _buildMultiCurrencyWealthRow(
            icon: Icons.store_outlined,
            label: 'Business Assets / Stock',
            controller: _businessCtrl,
            currency: _businessCurr,
            onCurrencyChanged: (val) {
              setState(() {
                _businessCurr = val!;
                _recalculateZakat();
                _saveWealthState();
              });
            },
          ),
          const SizedBox(height: 12),

          _buildMultiCurrencyWealthRow(
            icon: Icons.receipt_long_outlined,
            label: 'Receivables / Monies Owed',
            controller: _receivableCtrl,
            currency: _receivableCurr,
            onCurrencyChanged: (val) {
              setState(() {
                _receivableCurr = val!;
                _recalculateZakat();
                _saveWealthState();
              });
            },
          ),
          const SizedBox(height: 24),

          // Liabilities Header
          _buildSectionHeader('Liabilities & Debts', AppColors.coralOrange),
          const SizedBox(height: 12),

          _buildMultiCurrencyWealthRow(
            icon: Icons.money_off_outlined,
            label: 'Immediate Liabilities / Debts',
            controller: _liabilitiesCtrl,
            currency: _liabilitiesCurr,
            onCurrencyChanged: (val) {
              setState(() {
                _liabilitiesCurr = val!;
                _recalculateZakat();
                _saveWealthState();
              });
            },
          ),
          const SizedBox(height: 24),

          // Wealth Breakdown Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navyBlue.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Statement Breakdown summary',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppColors.navyBlue),
                ),
                const SizedBox(height: 14),
                _buildBreakdownRow('Cash Assets', _cashCtrl.text, _cashCurr),
                _buildBreakdownRow(
                  'Gold (Gold standard)',
                  '${(double.tryParse(_goldGramsCtrl.text) ?? 0.0) + (_schoolOfOpinion == 'hanafi' ? (double.tryParse(_goldJewelryCtrl.text) ?? 0.0) : 0.0)} g',
                  _baseCurrency,
                  customValue: (double.tryParse(_goldGramsCtrl.text) ?? 0.0) * _goldPricePerGramBase +
                      (_schoolOfOpinion == 'hanafi'
                          ? (double.tryParse(_goldJewelryCtrl.text) ?? 0.0) * _goldPricePerGramBase
                          : 0.0),
                ),
                _buildBreakdownRow(
                  'Silver (Silver standard)',
                  '${(double.tryParse(_silverGramsCtrl.text) ?? 0.0) + (double.tryParse(_silverJewelryCtrl.text) ?? 0.0)} g',
                  _baseCurrency,
                  customValue: ((double.tryParse(_silverGramsCtrl.text) ?? 0.0) +
                          (double.tryParse(_silverJewelryCtrl.text) ?? 0.0)) *
                      _silverPricePerGramBase,
                ),
                _buildBreakdownRow('Stocks Assets', _stocksCtrl.text, _stocksCurr),
                _buildBreakdownRow('Business Inventory', _businessCtrl.text, _businessCurr),
                _buildBreakdownRow('Receivables', _receivableCtrl.text, _receivableCurr),
                const Divider(height: 20, color: Colors.black12),
                _buildBreakdownRow('Less: Liabilities', _liabilitiesCtrl.text, _liabilitiesCurr, isDeduction: true),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5FB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Net Zakatable Wealth',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navyBlue)),
                      Text(
                        '$_baseCurrency ${_formatCurrency(_totalZakatableWealth)}',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.navyBlue),
                      ),
                    ],
                  ),
                ),
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

  Widget _buildSummaryChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.coralOrange, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(color: Colors.white60, fontSize: 9.5, fontWeight: FontWeight.w500)),
                Text(value,
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPriceBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 4),
          Text(value, style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.navyBlue)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color barColor) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(color: barColor, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 10),
        Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
      ],
    );
  }

  Widget _buildMultiCurrencyWealthRow({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required String currency,
    required void Function(String?) onCurrencyChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.midTeal, size: 20),
              const SizedBox(width: 8),
              Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.navyBlue, fontSize: 13.5)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navyBlue),
                  onChanged: (_) {
                    _recalculateZakat();
                    _saveWealthState();
                  },
                ),
              ),
              const SizedBox(width: 10),
              DropdownButton<String>(
                value: currency,
                underline: const SizedBox(),
                items: ['BDT', 'USD', 'SAR', 'EUR', 'GBP'].map((String val) {
                  return DropdownMenuItem<String>(
                    value: val,
                    child: Text(val, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold)),
                  );
                }).toList(),
                onChanged: onCurrencyChanged,
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCleanTextField({
    required TextEditingController controller,
    required String label,
    required String suffix,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.placeholder),
        suffixText: suffix,
        suffixStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.navyBlue),
        border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.midTeal)),
      ),
      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navyBlue),
      onChanged: (_) {
        _recalculateZakat();
        _saveWealthState();
      },
    );
  }

  Widget _buildBreakdownRow(String label, String rawValue, String currency, {double? customValue, bool isDeduction = false}) {
    double valueBase = 0.0;
    if (customValue != null) {
      valueBase = customValue;
    } else {
      final doubleParsed = double.tryParse(rawValue.replaceAll(',', '')) ?? 0.0;
      valueBase = _convertToBase(doubleParsed, currency);
    }

    if (valueBase == 0.0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
          Text(
            '${isDeduction ? "-" : ""} $_baseCurrency ${_formatCurrency(valueBase)}',
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isDeduction ? AppColors.coralOrange : AppColors.navyBlue,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ── TAB 2: HIJRI HAUL TIMELINE
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildHaulTab() {
    final hasActiveHaul = _zakatStartCrossingDate != null;
    int daysElapsed = 0;
    int daysRemaining = 354;
    double progress = 0.0;
    String startHijri = '';
    String endHijri = '';

    if (hasActiveHaul) {
      daysElapsed = DateTime.now().difference(_zakatStartCrossingDate!).inDays;
      daysRemaining = (354 - daysElapsed).clamp(0, 354);
      progress = (daysElapsed / 354.0).clamp(0.0, 1.0);
      startHijri = HijriConverter.fromGregorian(_zakatStartCrossingDate!).format(false);
      endHijri = HijriConverter.fromGregorian(_zakatStartCrossingDate!.add(const Duration(days: 354))).format(false);
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Image Placeholder ──────────────────────────────────────────────
          _buildImagePlaceholder(
            assetPath: 'assets/images/zakat_haul_banner.jpg',
            label: 'Haul Calendar Banner',
            icon: Icons.calendar_month_rounded,
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: hasActiveHaul ? AppColors.navyBlue : const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(24),
              border: hasActiveHaul ? null : Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Haul Tracking Status',
                      style: GoogleFonts.poppins(
                        color: hasActiveHaul ? Colors.white70 : AppColors.placeholder,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                    Icon(
                      hasActiveHaul ? Icons.hourglass_top_rounded : Icons.hourglass_disabled_rounded,
                      color: hasActiveHaul ? AppColors.coralOrange : AppColors.placeholder,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (hasActiveHaul) ...[
                  Text(
                    '$daysRemaining Days Left',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Haul Cycle: $daysElapsed of 354 Hijri Days completed',
                    style: GoogleFonts.inter(color: Colors.white60, fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.coralOrange),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildHaulDateColumn('Start Date', startHijri, DateFormat('dd MMM yyyy').format(_zakatStartCrossingDate!)),
                      _buildHaulDateColumn('Target Due Date', endHijri, DateFormat('dd MMM yyyy').format(_zakatStartCrossingDate!.add(const Duration(days: 354)))),
                    ],
                  ),
                ] else ...[
                  Text(
                    'No Active Haul Clock',
                    style: GoogleFonts.poppins(color: AppColors.navyBlue, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your tracked wealth is currently below Nisab. Once it crosses, the 354-day lunar year timer will begin automatically.',
                    style: GoogleFonts.inter(color: AppColors.placeholder, fontSize: 12.5, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildSectionHeader('Calendar Management', AppColors.midTeal),
          const SizedBox(height: 14),

          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            tileColor: const Color(0xFFF1F5FB),
            leading: const Icon(Icons.edit_calendar_rounded, color: AppColors.midTeal),
            title: Text(
              hasActiveHaul ? 'Adjust Start Crossing Date' : 'Set Manual Start Date',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.navyBlue),
            ),
            subtitle: Text(
              hasActiveHaul ? 'Manually edit when your wealth crossed Nisab' : 'Manually override to begin your Haul clock',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.placeholder),
            ),
            onTap: _showHaulDatePicker,
          ),
          if (hasActiveHaul) ...[
            const SizedBox(height: 12),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              tileColor: AppColors.coralOrange.withValues(alpha: 0.1),
              leading: const Icon(Icons.restart_alt_rounded, color: AppColors.coralOrange),
              title: Text(
                'Reset Haul Timer',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.coralOrange),
              ),
              subtitle: Text(
                'Clear the start crossing date to stop the clock',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.placeholder),
              ),
              onTap: () {
                setState(() {
                  _zakatStartCrossingDate = null;
                  _recalculateZakat();
                  _saveSettingsState();
                });
              },
            ),
          ],

          const SizedBox(height: 24),
          _buildInfoBox(
            title: 'What is the Haul (Hawl)?',
            content: 'The Haul represents one full lunar year (approx. 354 days). An individual must hold wealth exceeding the Nisab threshold continuously for one complete lunar year before the payment of Zakat becomes obligatory on that wealth.',
          ),
        ],
      ),
    ),
  ],
),
    );
  }

  Widget _buildHaulDateColumn(String title, String hijri, String greg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.inter(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(hijri, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(greg, style: GoogleFonts.inter(fontSize: 10, color: Colors.white70)),
      ],
    );
  }

  Future<void> _showHaulDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _zakatStartCrossingDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 730)),
      lastDate: DateTime.now(),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.navyBlue,
              onPrimary: Colors.white,
              onSurface: AppColors.navyBlue,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _zakatStartCrossingDate = picked;
        _recalculateZakat();
        _saveSettingsState();
      });
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ── TAB 3: FITRA & PURIFICATION HELPER
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildFitraAndPurificationTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navyBlue.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              indicatorColor: AppColors.midTeal,
              labelColor: AppColors.navyBlue,
              unselectedLabelColor: AppColors.placeholder,
              tabs: [
                Tab(
                  child: Text('Zakat al-Fitr', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                Tab(
                  child: Text('Purification Helper', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildFitraSection(),
                _buildPurificationSection(),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFitraSection() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Image Placeholder ──────────────────────────────────────────────
          _buildImagePlaceholder(
            assetPath: 'assets/images/zakat_fitra_banner.jpg',
            label: 'Zakat al-Fitr Banner',
            icon: Icons.mosque_rounded,
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          // Fitra Due Card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF84B5B4), Color(0xFF459490)],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppColors.midTeal.withValues(alpha: 0.15),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Zakat al-Fitr (Fitra) Due',
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_baseCurrency ${_formatFullCurrency(_fitraTotal)}',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Calculated for ${_fitraFamilySizeCtrl.text} family members',
                  style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.9), fontSize: 11.5),
                )
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildSectionHeader('Fitra Parameters', AppColors.navyBlue),
          const SizedBox(height: 14),

          // Family Size
          _buildCleanTextField(
            controller: _fitraFamilySizeCtrl,
            label: 'Family Size (including dependents & self)',
            suffix: 'heads',
          ),
          const SizedBox(height: 16),

          // Staples Dropdown
          DropdownButtonFormField<String>(
            initialValue: _fitraStaple,
            decoration: InputDecoration(
              labelText: 'Select Staple Commodity',
              labelStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.placeholder),
              border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
            items: _fitraStapleRates.keys.map((String staple) {
              final rateVal = _fitraStapleRates[staple]!;
              // Convert rate to Base Currency
              final rateBase = rateVal / _bdtRate * _baseRateToUSD;
              final rateStr = staple == 'Custom' ? 'Custom price' : '${_formatCurrency(rateBase)} $_baseCurrency/head';

              return DropdownMenuItem<String>(
                value: staple,
                child: Text('$staple ($rateStr)', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.navyBlue)),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _fitraStaple = val!;
                _recalculateZakat();
                ZakatStorageService.saveFitraInputs(
                  familySize: int.tryParse(_fitraFamilySizeCtrl.text) ?? 1,
                  staple: _fitraStaple,
                  customRate: _fitraCustomRate,
                );
              });
            },
          ),

          if (_fitraStaple == 'Custom') ...[
            const SizedBox(height: 16),
            TextField(
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Enter Custom Rate (BDT per head)',
                suffixText: '৳',
                suffixStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold),
              onChanged: (val) {
                setState(() {
                  _fitraCustomRate = double.tryParse(val) ?? 115.0;
                  _recalculateZakat();
                  ZakatStorageService.saveFitraInputs(
                    familySize: int.tryParse(_fitraFamilySizeCtrl.text) ?? 1,
                    staple: _fitraStaple,
                    customRate: _fitraCustomRate,
                  );
                });
              },
            ),
          ],
          const SizedBox(height: 24),

          // Log payment button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navyBlue,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            label: Text(
              'Log Fitra Payment',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            onPressed: () {
              _showLogPaymentDialog(defaultCategory: 'Zakat al-Fitr', defaultAmount: _fitraTotal);
            },
          ),

          _buildInfoBox(
            title: 'Zakat al-Fitr (Fitra)',
            content: 'Zakat al-Fitr is an obligatory charity paid before the Eid al-Fitr prayer by the head of the household on behalf of themselves and all family members they support. Its purpose is to cleanse the fasting person from minor mistakes made during Ramadan and to ensure the poor have food on Eid day.',
          ),
        ],
      ),
    ),
  ],
),
    );
  }

  Widget _buildPurificationSection() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Image Placeholder ──────────────────────────────────────────────
          _buildImagePlaceholder(
            assetPath: 'assets/images/zakat_purification_banner.jpg',
            label: 'Wealth Purification Banner',
            icon: Icons.clean_hands_rounded,
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          // Stock purification header
          _buildSectionHeader('Stocks Purification Cleansing', AppColors.navyBlue),
          const SizedBox(height: 12),
          Text(
            'Calculate charity needed to purify dividend income derived from companies with small levels of non-permissible (non-halal) revenue (e.g. interest).',
            style: GoogleFonts.inter(color: AppColors.placeholder, fontSize: 11.5, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildCleanTextField(
                  controller: _purStockSymbolCtrl,
                  label: 'Ticker Symbol (e.g. AAPL)',
                  suffix: '',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCleanTextField(
                  controller: _purStockDividendsCtrl,
                  label: 'Dividends (BDT)',
                  suffix: '৳',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCleanTextField(
                  controller: _purStockNonHalalPctCtrl,
                  label: 'Non-Halal Revenue %',
                  suffix: '%',
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.midTeal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _calculateAndLogStockPurification,
                child: Text('Purify', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),

          const SizedBox(height: 30),
          // Crypto Staking purification
          _buildSectionHeader('Crypto Rewards Purification', AppColors.coralOrange),
          const SizedBox(height: 12),
          Text(
            'Purify staking/interest rewards received from crypto protocols. Staking rewards typically require a 100% purification donation of the reward value.',
            style: GoogleFonts.inter(color: AppColors.placeholder, fontSize: 11.5, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildCleanTextField(
                  controller: _purCryptoSymbolCtrl,
                  label: 'Crypto Coin (e.g. ETH)',
                  suffix: '',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCleanTextField(
                  controller: _purCryptoRewardsValueCtrl,
                  label: 'Rewards (BDT)',
                  suffix: '৳',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCleanTextField(
                  controller: _purCryptoRatioCtrl,
                  label: 'Purification Ratio %',
                  suffix: '%',
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.coralOrange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _calculateAndLogCryptoPurification,
                child: Text('Purify', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),

          if (_purificationLogs.isNotEmpty) ...[
            const SizedBox(height: 28),
            _buildSectionHeader('Purification Logs', AppColors.navyBlue),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _purificationLogs.length,
                separatorBuilder: (ctx, idx) => const Divider(height: 1),
                itemBuilder: (ctx, idx) {
                  final log = _purificationLogs[idx];
                  return ListTile(
                    title: Text(
                      '${log['symbol']} Cleansing',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navyBlue),
                    ),
                    subtitle: Text(
                      'Type: ${log['type']} • Amount: ৳${log['purifiedAmount']}',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.placeholder),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.coralOrange, size: 20),
                      onPressed: () => _deletePurificationLog(idx),
                    ),
                  );
                },
              ),
            ),
          ]
        ],
      ),
    ),
  ],
),
    );
  }

  void _calculateAndLogStockPurification() {
    final symbol = _purStockSymbolCtrl.text.toUpperCase().trim();
    final dividends = double.tryParse(_purStockDividendsCtrl.text) ?? 0.0;
    final nonHalalPct = double.tryParse(_purStockNonHalalPctCtrl.text) ?? 5.0;

    if (symbol.isEmpty || dividends <= 0) return;

    final purifiedAmountBDT = dividends * (nonHalalPct / 100);
    // Convert to Base Currency
    final purifiedAmountBase = purifiedAmountBDT / _bdtRate * _baseRateToUSD;

    setState(() {
      _purificationLogs.insert(0, {
        'symbol': symbol,
        'type': 'Stock Dividend',
        'purifiedAmount': purifiedAmountBDT.toStringAsFixed(2),
      });
      _purStockSymbolCtrl.clear();
      _purStockDividendsCtrl.clear();
    });

    ZakatStorageService.savePurificationItems(_purificationLogs);

    // Direct pay logging popup option
    _logPayment(
      amount: purifiedAmountBase,
      currency: _baseCurrency,
      recipient: 'Purification Charity',
      category: 'Purification',
      notes: 'Dividend purification of $symbol ($nonHalalPct%)',
    );
  }

  void _calculateAndLogCryptoPurification() {
    final symbol = _purCryptoSymbolCtrl.text.toUpperCase().trim();
    final rewardVal = double.tryParse(_purCryptoRewardsValueCtrl.text) ?? 0.0;
    final ratio = double.tryParse(_purCryptoRatioCtrl.text) ?? 100.0;

    if (symbol.isEmpty || rewardVal <= 0) return;

    final purifiedAmountBDT = rewardVal * (ratio / 100);
    final purifiedAmountBase = purifiedAmountBDT / _bdtRate * _baseRateToUSD;

    setState(() {
      _purificationLogs.insert(0, {
        'symbol': symbol,
        'type': 'Crypto Staking',
        'purifiedAmount': purifiedAmountBDT.toStringAsFixed(2),
      });
      _purCryptoSymbolCtrl.clear();
      _purCryptoRewardsValueCtrl.clear();
    });

    ZakatStorageService.savePurificationItems(_purificationLogs);

    _logPayment(
      amount: purifiedAmountBase,
      currency: _baseCurrency,
      recipient: 'Purification Charity',
      category: 'Purification',
      notes: 'Crypto rewards purification of $symbol ($ratio%)',
    );
  }

  void _deletePurificationLog(int index) {
    setState(() {
      _purificationLogs.removeAt(index);
    });
    ZakatStorageService.savePurificationItems(_purificationLogs);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ── TAB 4: PAYMENTS & HISTORY
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildHistoryTab() {
    // Summarize payments
    final double maalPaid = _payments
        .where((e) => e['category'] == 'Zakat al-Maal')
        .fold(0.0, (sum, e) => sum + (e['amountInBase'] as num).toDouble());

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Image Placeholder ──────────────────────────────────────────────
          _buildImagePlaceholder(
            assetPath: 'assets/images/zakat_history_banner.jpg',
            label: 'Zakat & Purification History',
            icon: Icons.history_edu_rounded,
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          // Zakat progress ring card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navyBlue.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Zakat al-Maal Payments',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navyBlue),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Paid: $_baseCurrency ${_formatCurrency(maalPaid)}',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.placeholder, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Remaining: $_baseCurrency ${_formatCurrency((_zakatDue - maalPaid).clamp(0.0, double.infinity))}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _zakatDue - maalPaid > 0 ? AppColors.coralOrange : Colors.green.shade600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  child: Stack(
                    children: [
                      CircularProgressIndicator(
                        value: _zakatDue > 0 ? (maalPaid / _zakatDue).clamp(0.0, 1.0) : 0.0,
                        backgroundColor: Colors.grey.shade100,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.midTeal),
                        strokeWidth: 6,
                      ),
                      Center(
                        child: Text(
                          _zakatDue > 0 ? '${((maalPaid / _zakatDue) * 100).toStringAsFixed(0)}%' : '0%',
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navyBlue),
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Year-over-Year Sparkline Section
          _buildSectionHeader('Year-over-Year wealth trend', AppColors.navyBlue),
          const SizedBox(height: 12),
          Container(
            height: 180,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.navyBlue,
              borderRadius: BorderRadius.circular(22),
            ),
            child: _history.isEmpty
                ? Center(
                    child: Text(
                      'Archive a year to see your wealth trendline!',
                      style: GoogleFonts.inter(color: Colors.white54, fontSize: 12.5),
                    ),
                  )
                : CustomPaint(
                    painter: _HistoryTrendlinePainter(history: _history),
                    child: Container(),
                  ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.midTeal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.archive_outlined, size: 18, color: Colors.white),
              label: Text('Archive Current Year', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
              onPressed: _showArchiveYearDialog,
            ),
          ),
          const SizedBox(height: 24),

          // Payment log list
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader('Payments Logs', AppColors.navyBlue),
              TextButton.icon(
                icon: const Icon(Icons.add_rounded, size: 18, color: AppColors.midTeal),
                label: Text('Add Log', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                onPressed: () => _showLogPaymentDialog(defaultCategory: 'Zakat al-Maal'),
              ),
            ],
          ),
          const SizedBox(height: 10),

          _payments.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Center(
                    child: Text('No payments logged yet.', style: GoogleFonts.inter(color: AppColors.placeholder, fontSize: 13)),
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _payments.length,
                    separatorBuilder: (ctx, idx) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final item = _payments[idx];
                      final date = DateTime.tryParse(item['date']) ?? DateTime.now();
                      return ListTile(
                        dense: true,
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item['recipient'],
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.navyBlue, fontSize: 13),
                            ),
                            Text(
                              '${item['currency']} ${item['amount']}',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.midTeal, fontSize: 13),
                            ),
                          ],
                        ),
                        subtitle: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${item['category']} • ${DateFormat('dd MMM yy').format(date)}',
                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.placeholder),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.share_outlined, color: AppColors.placeholder, size: 18),
                                  onPressed: () => _generateReceiptPdf(item),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.delete_outline, color: AppColors.coralOrange, size: 18),
                                  onPressed: () => _deletePayment(item['id']),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ],
      ),
    ),
  ],
),
    );
  }

  void _showArchiveYearDialog() {
    _archiveYearCtrl.text = '${HijriConverter.fromGregorian(DateTime.now()).year} AH';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Archive Zakat Record',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.navyBlue),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will save your current Zakat calculations to your history ledger.',
              style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.navyBlue.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 16),
            _buildCleanTextField(
              controller: _archiveYearCtrl,
              label: 'Year Name / Label',
              suffix: '',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.placeholder)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.navyBlue),
            onPressed: _archiveYear,
            child: Text('Archive', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showLogPaymentDialog({required String defaultCategory, double? defaultAmount}) {
    final TextEditingController amountC = TextEditingController(text: defaultAmount?.toStringAsFixed(2) ?? '0');
    final TextEditingController recipientC = TextEditingController();
    final TextEditingController notesC = TextEditingController();
    String curr = _baseCurrency;
    String cat = defaultCategory;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(
                'Log Zakat Payment',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.navyBlue),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: cat,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: ['Zakat al-Maal', 'Zakat al-Fitr', 'Purification'].map((e) {
                        return DropdownMenuItem(value: e, child: Text(e));
                      }).toList(),
                      onChanged: (val) => setDialogState(() => cat = val!),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: amountC,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Amount'),
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        DropdownButton<String>(
                          value: curr,
                          items: ['BDT', 'USD', 'SAR', 'EUR', 'GBP'].map((e) {
                            return DropdownMenuItem(value: e, child: Text(e));
                          }).toList(),
                          onChanged: (val) => setDialogState(() => curr = val!),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: recipientC,
                      decoration: const InputDecoration(labelText: 'Recipient / Charity Name', hintText: 'e.g. As-Sunnah Foundation'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesC,
                      decoration: const InputDecoration(labelText: 'Additional Notes (Optional)'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.placeholder)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.navyBlue),
                  onPressed: () {
                    final amt = double.tryParse(amountC.text) ?? 0.0;
                    final recipient = recipientC.text.trim();
                    if (amt <= 0 || recipient.isEmpty) return;

                    _logPayment(
                      amount: amt,
                      currency: curr,
                      recipient: recipient,
                      category: cat,
                      notes: notesC.text.trim(),
                    );
                    Navigator.pop(ctx);
                  },
                  child: Text('Log', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ── TAB 5: CHARITY DIRECTORY
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildCharityTab() {
    final List<Map<String, String>> charities = [
      {
        'name': 'As-Sunnah Foundation',
        'desc': 'A vetted Islamic charity organization in Bangladesh focusing on poverty alleviation, disaster response, and Zakat distribution.',
        'url': 'https://assunnahfoundation.org/',
      },
      {
        'name': 'Mastul Foundation',
        'desc': 'Operates schools, orphanages, and projects for poor people. Zakat eligible projects certified by local scholars.',
        'url': 'https://www.mastul.net/',
      },
      {
        'name': 'JAAGO Foundation Zakat Fund',
        'desc': 'Empower children through quality English-medium education. Zakat is spent on student expenses, meals, and uniforms.',
        'url': 'https://jaago.com.bd/zakat/',
      },
      {
        'name': 'Islamic Relief Global',
        'desc': 'One of the largest international Muslim NGOs providing Zakat-driven sustainable development and emergency aid.',
        'url': 'https://www.islamic-relief.org/',
      },
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Image Placeholder ──────────────────────────────────────────────
          _buildImagePlaceholder(
            assetPath: 'assets/images/zakat_charity_banner.jpg',
            label: 'Verified Charities Banner',
            icon: Icons.storefront_rounded,
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          // Surah Tawbah info
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.navyBlue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The 8 Quranic Categories',
                  style: GoogleFonts.poppins(color: AppColors.coralOrange, fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                const SizedBox(height: 6),
                Text(
                  '“Zakat expenditures are only for the poor and for the needy and for those employed to collect [zakat] and for bringing hearts together [for Islam] and for freeing captives [or slaves] and for those in debt and for the cause of Allah and for the [stranded] traveler...”',
                  style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.85), fontSize: 11, fontStyle: FontStyle.italic, height: 1.45),
                ),
                const SizedBox(height: 6),
                Text(
                  '— Surah At-Tawbah 9:60',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildSectionHeader('Vetted Organizations Directory', AppColors.navyBlue),
          const SizedBox(height: 14),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: charities.length,
            separatorBuilder: (ctx, idx) => const SizedBox(height: 14),
            itemBuilder: (ctx, idx) {
              final c = charities[idx];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c['name']!,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.navyBlue, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      c['desc']!,
                      style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.placeholder, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.midTeal),
                          label: Text('Donate Online', style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.midTeal)),
                          onPressed: () => _launchURL(c['url']!),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.navyBlue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                          label: Text('Log donation', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                          onPressed: () {
                            _showLogPaymentDialog(defaultCategory: 'Zakat al-Maal', defaultAmount: 0);
                          },
                        ),
                      ],
                    )
                  ],
                ),
              );
            },
          ),
        ],
      ),
    ),
  ],
),
    );
  }

  Future<void> _launchURL(String urlStr) async {
    final uri = Uri.parse(urlStr);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch $urlStr');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ── SETTINGS DIALOG
  // ──────────────────────────────────────────────────────────────────────────
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(
                'Zakat configurations',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.navyBlue),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Base Currency
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Base Currency', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                      DropdownButton<String>(
                        value: _baseCurrency,
                        items: ['BDT', 'USD', 'SAR', 'EUR', 'GBP'].map((e) {
                          return DropdownMenuItem(value: e, child: Text(e));
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() => _baseCurrency = val!);
                          setState(() {
                            _baseCurrency = val!;
                            _recalculateZakat();
                            _saveSettingsState();
                          });
                        },
                      ),
                    ],
                  ),
                  const Divider(),
                  // Nisab Standard
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Nisab Standard', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                      DropdownButton<String>(
                        value: _nisabStandard,
                        items: const [
                          DropdownMenuItem(value: 'silver', child: Text('Silver (595g)')),
                          DropdownMenuItem(value: 'gold', child: Text('Gold (85g)')),
                        ],
                        onChanged: (val) {
                          setDialogState(() => _nisabStandard = val!);
                          setState(() {
                            _nisabStandard = val!;
                            _recalculateZakat();
                            _saveSettingsState();
                          });
                        },
                      ),
                    ],
                  ),
                  const Divider(),
                  // School of Opinion
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'School of Opinion\n(Jewelry Zakat)',
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      DropdownButton<String>(
                        value: _schoolOfOpinion,
                        items: const [
                          DropdownMenuItem(value: 'hanafi', child: Text('Hanafi (Obligatory)')),
                          DropdownMenuItem(value: 'others', child: Text('Others (Exempt)')),
                        ],
                        onChanged: (val) {
                          setDialogState(() => _schoolOfOpinion = val!);
                          setState(() {
                            _schoolOfOpinion = val!;
                            _recalculateZakat();
                            _saveSettingsState();
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Done', style: GoogleFonts.poppins(color: AppColors.midTeal, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Common Helper Widgets ---
  Widget _buildInfoBox({required String title, required String content}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.navyBlue, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navyBlue),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.placeholder, height: 1.45),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// ── CUSTOM SPARKLINE/HISTORY CHART PAINTER (YoY TREND GRAPH)
// ──────────────────────────────────────────────────────────────────────────
class _HistoryTrendlinePainter extends CustomPainter {
  final List<Map<String, dynamic>> history;

  _HistoryTrendlinePainter({required this.history});

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;

    final paintLine = Paint()
      ..color = AppColors.coralOrange
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintDueLine = Paint()
      ..color = AppColors.dustyBlueTeal
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintPoints = Paint()
      ..color = Colors.white
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);

    // Calculate maximum wealth to scale vertical height
    double maxWealth = 0.0;
    for (var item in history) {
      final w = (item['netWealth'] as num).toDouble();
      if (w > maxWealth) maxWealth = w;
    }
    if (maxWealth == 0.0) maxWealth = 1000.0;

    final double width = size.width - 40;
    final double height = size.height - 50;
    final int pointsCount = history.length;
    final double stepX = pointsCount > 1 ? width / (pointsCount - 1) : width;

    // Draw grid
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1;
    canvas.drawLine(const Offset(20, 10), Offset(size.width - 20, 10), gridPaint);
    canvas.drawLine(Offset(20, size.height - 40), Offset(size.width - 20, size.height - 40), gridPaint);

    final Path wealthPath = Path();
    final Path duePath = Path();

    final List<Offset> pointsWealth = [];
    final List<Offset> pointsDue = [];

    for (int i = 0; i < pointsCount; i++) {
      final double x = 20 + i * stepX;
      final double netWealth = (history[i]['netWealth'] as num).toDouble();
      final double zakatDue = (history[i]['zakatDue'] as num).toDouble();

      final double yWealth = (size.height - 40) - (netWealth / maxWealth) * height;
      final double yDue = (size.height - 40) - (zakatDue / maxWealth) * height;

      final offsetWealth = Offset(x, yWealth);
      final offsetDue = Offset(x, yDue);

      pointsWealth.add(offsetWealth);
      pointsDue.add(offsetDue);

      if (i == 0) {
        wealthPath.moveTo(x, yWealth);
        duePath.moveTo(x, yDue);
      } else {
        wealthPath.lineTo(x, yWealth);
        duePath.lineTo(x, yDue);
      }

      // Draw year labels under the axis
      final yearStr = history[i]['year'] as String;
      textPainter.text = TextSpan(
        text: yearStr,
        style: GoogleFonts.poppins(fontSize: 8.5, color: Colors.white70, fontWeight: FontWeight.bold),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, size.height - 30));

      // Draw wealth values above the wealth points
      String wealthStr = netWealth >= 1000 ? '${(netWealth / 1000).toStringAsFixed(0)}K' : netWealth.toStringAsFixed(0);
      textPainter.text = TextSpan(
        text: wealthStr,
        style: GoogleFonts.poppins(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, yWealth - 14));
    }

    if (pointsCount > 1) {
      canvas.drawPath(wealthPath, paintLine);
      canvas.drawPath(duePath, paintDueLine);
    }

    // Draw individual points on top
    for (int i = 0; i < pointsCount; i++) {
      canvas.drawPoints(ui.PointMode.points, [pointsWealth[i]], paintPoints);
      canvas.drawPoints(ui.PointMode.points, [pointsDue[i]], paintPoints..color = AppColors.midTeal);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
