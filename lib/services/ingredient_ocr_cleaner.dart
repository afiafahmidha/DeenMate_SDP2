/// Service responsible for cleaning raw OCR text from packaging photos,
/// stripping out marketing slogans, nutrition tables, manufacturer details,
/// and net weight, and extracting clean ingredient items in any language.
class IngredientOcrCleaner {
  /// Converts Bengali numbers (০-৯) to English numbers (0-9)
  static String convertBengaliNumerals(String text) {
    const bnDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    const enDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

    String result = text;
    for (int i = 0; i < bnDigits.length; i++) {
      result = result.replaceAll(bnDigits[i], enDigits[i]);
    }
    return result;
  }

  /// Extract clean ingredient items from raw OCR text.
  static List<String> cleanAndExtract(String rawText) {
    if (rawText.trim().isEmpty) return [];

    // Convert Bengali digits to ASCII digits first
    String text = convertBengaliNumerals(rawText.replaceAll('\r\n', '\n'));

    // 1. Try to find ingredient header section in various languages
    String? ingredientSection = _extractIngredientSection(text);
    String targetText = ingredientSection ?? text;

    // 2. Filter lines that are clearly noise (net weight, dates, storage, nutrition facts table)
    List<String> cleanLines = [];
    for (String line in targetText.split('\n')) {
      String trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (_isNoiseLine(trimmed) && ingredientSection == null) continue;
      cleanLines.add(trimmed);
    }

    String combinedText = cleanLines.join(' ');

    // 3. Clean unwanted characters and standardize punctuation
    combinedText = combinedText
        .replaceAll(RegExp(r'[*_~`\|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\b(NET\s*WT|NET\s*WEIGHT|WEIGHT|PACKED\s*ON|BEST\s*BEFORE|EXP|MFG|BATCH|LOT)[:\s]*[\w\.\/-]+', caseSensitive: false), '')
        .trim();

    // 4. Split by ingredient separators (commas, semicolons, bullets, colons, newlines, full stops)
    List<String> rawIngredients = _splitIngredients(combinedText);

    // 5. Post-process and sanitize each ingredient
    List<String> finalIngredients = [];
    for (String ing in rawIngredients) {
      String cleanedIng = _sanitizeIngredientToken(ing);
      if (cleanedIng.isNotEmpty && !_isPureNoiseToken(cleanedIng) && !_isGarbageToken(cleanedIng)) {
        finalIngredients.add(cleanedIng);
      }
    }

    // 6. Deduplicate while preserving order
    Set<String> seen = {};
    List<String> deduplicated = [];
    for (String item in finalIngredients) {
      String lower = item.toLowerCase();
      if (!seen.contains(lower)) {
        seen.add(lower);
        deduplicated.add(item);
      }
    }

    return deduplicated;
  }

  /// Locates the ingredient header (e.g., "Ingredients:", "Ingrédients:", "উপাদান:")
  /// and returns the text following it.
  static String? _extractIngredientSection(String text) {
    final headerPatterns = [
      r'\bingredients\s*[:\-\u2013\u2014\=]',
      r'\bingrédients\s*[:\-\u2013\u2014\=]',
      r'\bzutaten\s*[:\-\u2013\u2014\=]',
      r'\bingredientes\s*[:\-\u2013\u2014\=]',
      r'\bingrediente\s*[:\-\u2013\u2014\=]',
      r'(?:^|\s)উপাদান(?:সমূহ)?\s*[:\-\u2013\u2014\=]?',
      r'(?:^|\s)المكونات\s*[:\-\u2013\u2014\=]?',
      r'\bсостав\s*[:\-\u2013\u2014\=]',
      r'\bcomposition\s*[:\-\u2013\u2014\=]',
      r'\bingredients\s+list\b',
    ];

    for (String pattern in headerPatterns) {
      final match = RegExp(pattern, caseSensitive: false).firstMatch(text);
      if (match != null) {
        String afterHeader = text.substring(match.end).trim();
        
        final stopPattern = RegExp(
          r'(allergen|contains\s+allergens|may\s+contain|nutrition\s+facts|manufactured\s+by|distributed\s+by|store\ Hauptstraße|keep\s+in|produced\s+in|এতে\s+আছে)',
          caseSensitive: false,
        );
        final stopMatch = stopPattern.firstMatch(afterHeader);
        if (stopMatch != null && stopMatch.start > 10) {
          afterHeader = afterHeader.substring(0, stopMatch.start).trim();
        }

        return afterHeader;
      }
    }
    return null;
  }

  /// Checks if a line is pure packaging noise.
  static bool _isNoiseLine(String line) {
    final lower = line.toLowerCase();

    if (RegExp(r'^\d+(\.\d+)?\s*(g|mg|ml|oz|kcal|cal|kj|%)\b').hasMatch(lower)) return true;
    if (lower.contains('nutrition facts') || lower.contains('valeur nutritive') || lower.contains('nährwertangaben')) return true;
    if (lower.contains('serving size') || lower.contains('servings per') || lower.contains('daily value')) return true;
    if (lower.contains('energy') || lower.contains('total fat') || lower.contains('saturated fat') || lower.contains('trans fat')) return true;
    if (lower.contains('cholesterol') || lower.contains('sodium') || lower.contains('total carbohydrate') || lower.contains('dietary fiber')) return true;

    if (lower.contains('manufactured by') || lower.contains('distributed by') || lower.contains('made in') || lower.contains('product of')) return true;
    if (lower.contains('best before') || lower.contains('exp date') || lower.contains('mfg date') || lower.contains('expiry')) return true;
    if (lower.contains('store in') || lower.contains('keep cool') || lower.contains('refrigerate after') || lower.contains('dry place')) return true;
    if (lower.contains('net wt') || lower.contains('net weight') || lower.contains('poids net') || lower.contains('nettogewicht')) return true;
    if (lower.contains('www.') || lower.contains('http') || lower.contains('.com') || lower.contains('@')) return true;
    if (RegExp(r'^\d{8,14}$').hasMatch(lower.replaceAll(RegExp(r'\s+'), ''))) return true;

    return false;
  }

  /// Splits combined ingredient string into individual tokens while preserving nested parenthetical descriptors.
  static List<String> _splitIngredients(String text) {
    List<String> results = [];
    StringBuffer current = StringBuffer();
    int parenDepth = 0;

    for (int i = 0; i < text.length; i++) {
      String char = text[i];

      // Reset paren depth on newlines or excessive depth
      if (char == '\n' || parenDepth > 2) {
        parenDepth = 0;
      }

      if (char == '(' || char == '[' || char == '{') {
        parenDepth++;
        current.write(char);
      } else if (char == ')' || char == ']' || char == '}') {
        if (parenDepth > 0) parenDepth--;
        current.write(char);
      } else if ((char == ',' || char == ';' || char == '•' || char == '·' || char == '।' || char == '\n') && parenDepth == 0) {
        String token = current.toString().trim();
        if (token.isNotEmpty) {
          results.add(token);
        }
        current.clear();
      } else {
        current.write(char);
      }
    }

    String remaining = current.toString().trim();
    if (remaining.isNotEmpty) {
      results.add(remaining);
    }

    return results;
  }

  /// Cleans an ingredient token.
  static String _sanitizeIngredientToken(String token) {
    String cleaned = token
        .replaceAll(RegExp(r'^[•·*:\.\|\u0964\s\-]+'), '')
        .replaceAll(RegExp(r'[•·*:\.\|\u0964\s\-]+$'), '')
        .trim();

    cleaned = cleaned.replaceAll(RegExp(r'^\d+(\.\d+)?%\s*'), '');

    return cleaned;
  }

  /// Detects ML Kit OCR Latin corruption tokens (e.g., "fsyt", "bytfrs t 15", "xfs", "iatbfP")
  /// generated when scanning non-Latin text with Latin-only OCR models.
  static bool _isGarbageToken(String token) {
    String lower = token.toLowerCase().trim();

    // If it contains non-ASCII characters (Bengali, Arabic, etc.), it's genuine text, not Latin corruption
    if (RegExp(r'[\u0980-\u09FF\u0600-\u06FF\u4e00-\u9fff]').hasMatch(token)) {
      return false;
    }

    // Single/two-letter gibberish
    if (lower.length <= 2 && !RegExp(r'^(e\d|no|in|oil|fat|soy|pork|milk)$').hasMatch(lower)) {
      return true;
    }

    // Check vowel ratio in pure ASCII words (corrupted ML Kit strings usually lack normal vowels or have random capitalization)
    if (RegExp(r'^[a-zA-Z\s\d\(\),]+$').hasMatch(token)) {
      String lettersOnly = lower.replaceAll(RegExp(r'[^a-z]'), '');
      if (lettersOnly.length >= 3) {
        int vowels = RegExp(r'[aeiouy]').allMatches(lettersOnly).length;
        double ratio = vowels / lettersOnly.length;
        // Words like "fsyt", "xfs", "bytfrs", "iatbfp" have vowel ratio < 0.15 or zero vowels
        if (ratio < 0.12 && !lettersOnly.contains('e')) {
          return true;
        }
      }
    }

    return false;
  }

  /// Checks if a single word or token is non-ingredient noise.
  static bool _isPureNoiseToken(String token) {
    if (token.length < 2 && !RegExp(r'[\u0980-\u09FF\u0600-\u06FF]').hasMatch(token)) return true;
    
    // Only digits, whitespace, or punctuation symbols (do NOT treat non-ASCII letters as noise)
    if (RegExp(r'^[\d\s!@#$%^&*()_+\-=\[\]{};:"\\|,.<>/?•·।\u0964\u0965]+$').hasMatch(token)) return true;

    final noiseTokens = {
      'ingredients', 'ingredient', 'contains', 'may contain', 'product', 'list',
      'keep', 'store', 'cool', 'dry', 'place', 'net', 'wt', 'weight', 'g', 'mg',
      'ml', 'oz', 'kcal', 'cal', 'serving', 'size', 'daily', 'value', 'manufactured',
      'distributed', 'by', 'made', 'in', 'exp', 'mfg', 'date', 'batch', 'lot',
      'best', 'before', 'allergen', 'warning', 'info', 'information', 'label',
      'উপাদান', 'উপাদানসমূহ', 'المكونات', 'zutaten', 'ingrédients', 'ingredientes', 'এতে আছে',
    };

    return noiseTokens.contains(token.toLowerCase());
  }
}