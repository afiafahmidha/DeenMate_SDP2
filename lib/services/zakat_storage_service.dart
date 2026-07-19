import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ZakatStorageService {
  static const String _keyBaseCurrency = 'zakat_base_currency';
  static const String _keyNisabStandard = 'zakat_nisab_standard';
  static const String _keySchoolOfOpinion = 'zakat_school_of_opinion';
  static const String _keyStockTradingIntent = 'zakat_stock_trading_intent';
  static const String _keyStartCrossingDate = 'zakat_start_crossing_date';

  static const String _keyCash = 'zakat_val_cash';
  static const String _keyCashCurr = 'zakat_curr_cash';
  static const String _keyGoldGrams = 'zakat_val_gold';
  static const String _keySilverGrams = 'zakat_val_silver';
  static const String _keyStocks = 'zakat_val_stocks';
  static const String _keyStocksCurr = 'zakat_curr_stocks';
  static const String _keyBusiness = 'zakat_val_business';
  static const String _keyBusinessCurr = 'zakat_curr_business';
  static const String _keyReceivable = 'zakat_val_receivable';
  static const String _keyReceivableCurr = 'zakat_curr_receivable';
  static const String _keyLiabilities = 'zakat_val_liabilities';
  static const String _keyLiabilitiesCurr = 'zakat_curr_liabilities';

  static const String _keyFitraFamilySize = 'zakat_fitra_family_size';
  static const String _keyFitraStaple = 'zakat_fitra_staple';
  static const String _keyFitraCustomRate = 'zakat_fitra_custom_rate';

  static const String _keyPayments = 'zakat_payments_json';
  static const String _keyPurificationItems = 'zakat_purification_items_json';
  static const String _keyHistory = 'zakat_history_json';

  // --- Settings ---
  static Future<String> getBaseCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyBaseCurrency) ?? 'BDT';
  }

  static Future<void> setBaseCurrency(String val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBaseCurrency, val);
  }

  static Future<String> getNisabStandard() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyNisabStandard) ?? 'silver';
  }

  static Future<void> setNisabStandard(String val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNisabStandard, val);
  }

  static Future<String> getSchoolOfOpinion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySchoolOfOpinion) ?? 'hanafi';
  }

  static Future<void> setSchoolOfOpinion(String val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySchoolOfOpinion, val);
  }

  static Future<String> getStockTradingIntent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyStockTradingIntent) ?? 'holding';
  }

  static Future<void> setStockTradingIntent(String val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStockTradingIntent, val);
  }

  static Future<DateTime?> getStartCrossingDate() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyStartCrossingDate);
    if (str == null || str.isEmpty) return null;
    return DateTime.tryParse(str);
  }

  static Future<void> setStartCrossingDate(DateTime? date) async {
    final prefs = await SharedPreferences.getInstance();
    if (date == null) {
      await prefs.remove(_keyStartCrossingDate);
    } else {
      await prefs.setString(_keyStartCrossingDate, date.toIso8601String());
    }
  }

  // --- Wealth Inputs ---
  static Future<Map<String, dynamic>> loadWealthInputs() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'cash': prefs.getDouble(_keyCash) ?? 0.0,
      'cashCurrency': prefs.getString(_keyCashCurr) ?? 'BDT',
      'goldGrams': prefs.getDouble(_keyGoldGrams) ?? 0.0,
      'silverGrams': prefs.getDouble(_keySilverGrams) ?? 0.0,
      'stocks': prefs.getDouble(_keyStocks) ?? 0.0,
      'stocksCurrency': prefs.getString(_keyStocksCurr) ?? 'BDT',
      'business': prefs.getDouble(_keyBusiness) ?? 0.0,
      'businessCurrency': prefs.getString(_keyBusinessCurr) ?? 'BDT',
      'receivable': prefs.getDouble(_keyReceivable) ?? 0.0,
      'receivableCurrency': prefs.getString(_keyReceivableCurr) ?? 'BDT',
      'liabilities': prefs.getDouble(_keyLiabilities) ?? 0.0,
      'liabilitiesCurrency': prefs.getString(_keyLiabilitiesCurr) ?? 'BDT',
    };
  }

  static Future<void> saveWealthInputs({
    required double cash,
    required String cashCurrency,
    required double goldGrams,
    required double silverGrams,
    required double stocks,
    required String stocksCurrency,
    required double business,
    required String businessCurrency,
    required double receivable,
    required String receivableCurrency,
    required double liabilities,
    required String liabilitiesCurrency,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyCash, cash);
    await prefs.setString(_keyCashCurr, cashCurrency);
    await prefs.setDouble(_keyGoldGrams, goldGrams);
    await prefs.setDouble(_keySilverGrams, silverGrams);
    await prefs.setDouble(_keyStocks, stocks);
    await prefs.setString(_keyStocksCurr, stocksCurrency);
    await prefs.setDouble(_keyBusiness, business);
    await prefs.setString(_keyBusinessCurr, businessCurrency);
    await prefs.setDouble(_keyReceivable, receivable);
    await prefs.setString(_keyReceivableCurr, receivableCurrency);
    await prefs.setDouble(_keyLiabilities, liabilities);
    await prefs.setString(_keyLiabilitiesCurr, liabilitiesCurrency);
  }

  // --- Zakat al-Fitr ---
  static Future<Map<String, dynamic>> loadFitraInputs() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'familySize': prefs.getInt(_keyFitraFamilySize) ?? 1,
      'staple': prefs.getString(_keyFitraStaple) ?? 'Flour',
      'customRate': prefs.getDouble(_keyFitraCustomRate) ?? 115.0,
    };
  }

  static Future<void> saveFitraInputs({
    required int familySize,
    required String staple,
    required double customRate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFitraFamilySize, familySize);
    await prefs.setString(_keyFitraStaple, staple);
    await prefs.setDouble(_keyFitraCustomRate, customRate);
  }

  // --- Payments Log ---
  static Future<List<Map<String, dynamic>>> loadPayments() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyPayments);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> decoded = json.decode(jsonStr);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      debugPrint('Error loading payments: $e');
      return [];
    }
  }

  static Future<void> savePayments(List<Map<String, dynamic>> payments) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPayments, json.encode(payments));
  }

  // --- Purification Items ---
  static Future<List<Map<String, dynamic>>> loadPurificationItems() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyPurificationItems);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> decoded = json.decode(jsonStr);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      debugPrint('Error loading purification items: $e');
      return [];
    }
  }

  static Future<void> savePurificationItems(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPurificationItems, json.encode(items));
  }

  // --- Yearly History ---
  static Future<List<Map<String, dynamic>>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyHistory);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> decoded = json.decode(jsonStr);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      debugPrint('Error loading history: $e');
      return [];
    }
  }

  static Future<void> saveHistory(List<Map<String, dynamic>> history) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHistory, json.encode(history));
  }
}
