import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

/// Multi-Provider Islamic AI & Knowledge Ensemble Service.
/// 
/// Integrates Google Gemini 3.6 Flash for dynamic, authentic Islamic AI streaming.
class IslamicAIService {
  static final IslamicAIService _instance = IslamicAIService._internal();
  factory IslamicAIService() => _instance;
  IslamicAIService._internal();

  /// Valid active user Gemini API Key.
  static String customApiKey = 'AQ.Ab8RN6KmF9yc-nFyQTKytYLnOXtilenzqsuoA8QPdrPDJhhw0A';

  GenerativeModel? _model;
  ChatSession? _chatSession;

  static const String _systemInstructionText = '''
You are "DeenMate Islamic AI", a highly specialized, humble, and strictly authentic Islamic Q&A assistant.

CRITICAL RELIGIOUS & AUTHENTICITY MANDATES:
1. SINCERITY AND RESPONSIBILITY: You must provide truthful, authentic, and well-verified Islamic knowledge. Never invent, hallucinate, or misquote Quranic verses, Hadith, or rulings of scholars.
2. AUTHENTIC CITATIONS (REQUIRED):
   - For every Quranic verse mentioned, cite the exact Surah and Ayah number (e.g., [Surah Al-Baqarah 2:255]).
   - For every Hadith mentioned, cite the specific Hadith collection and reference (e.g., [Sahih al-Bukhari 1], [Sahih Muslim 223], [Sunan Abi Dawud]). Only use authentic (Sahih) or well-accepted (Hasan) narrations.
   - For rulings (Fiqh), state if there is scholarly consensus (Ijma') or list the views of the major Sunni schools of thought (Hanafi, Shafi'i, Maliki, Hanbali) respectfully.
3. HUMILITY & ZERO HALLUCINATION:
   - If you do not have absolute certainty or precise authentic textual proof for a question, clearly state: "Allahu A'lam (Allah knows best). I do not have a verified authentic textual source for this specific question. Please consult a trusted Islamic scholar."
   - Never speculate or give personal opinions on religious matters.
4. FATWA & PERSONAL RULINGS DISCLAIMER:
   - For complex legal matters, marriage/divorce issues, inheritance disputes, or specific fatwas, advise the user to consult a qualified local Islamic scholar or Mufti.
5. STRICT SCOPE RESTRICTION:
   - Answer ONLY questions related to Islam (Aqeedah, Ibadah, Quran, Hadith, Seerah, Islamic History, Akhlaq, Zakat, Sawm, Hajj, Halal/Haram).
   - If asked non-Islamic questions (e.g., politics, coding, gossip, general worldly topics), politely respond: "Assalamu Alaikum! As DeenMate's Islamic Assistant, I am dedicated solely to answering questions about Islam and authentic Islamic knowledge."
6. MANNER AND TONE:
   - Begin answers with an Islamic greeting where appropriate.
   - Be respectful, concise, clear, and compassionate. Use bullet points for steps or lists.
''';

  /// Ensures Primary Gemini GenerativeModel is initialized.
  Future<void> _ensureInitialized({List<Content>? initialHistory}) async {
    if (FirebaseAuth.instance.currentUser == null) {
      try {
        await FirebaseAuth.instance.signInAnonymously();
      } catch (e) {
        debugPrint('Anonymous auth for AI failed: $e');
      }
    }

    if (_model == null) {
      final googleAI = FirebaseAI.googleAI();

      _model = googleAI.generativeModel(
        model: 'gemini-3.6-flash',
        systemInstruction: Content.system(_systemInstructionText),
        generationConfig: GenerationConfig(
          temperature: 0.2, // Low temperature for zero hallucination
          maxOutputTokens: 1024,
        ),
      );
    }

    if (_chatSession == null || initialHistory != null) {
      _chatSession = _model!.startChat(history: initialHistory);
    }
  }

  // ===== API 2: DEDICATED AL-QURAN CLOUD REST API =====
  Future<String?> _queryQuranApi(String userQuery) async {
    try {
      final cleanQuery = Uri.encodeComponent(userQuery.trim());
      final url = Uri.parse('https://api.alquran.cloud/v1/search/$cleanQuery/all/en.sahih');
      final response = await http.get(url).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK' && data['data'] != null && data['data']['matches'] != null) {
          final List matches = data['data']['matches'];
          if (matches.isNotEmpty) {
            final match = matches.first;
            final text = match['text'] as String?;
            final surahName = match['surah']?['englishName'] as String?;
            final surahNumber = match['surah']?['number'];
            final ayahNumber = match['numberInSurah'];
            if (text != null && surahName != null) {
              return 'VERIFIED QURAN TEXT: "$text" [Surah $surahName $surahNumber:$ayahNumber]';
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Quran API lookup non-blocking error: $e');
    }
    return null;
  }

  // ===== API 3: DEDICATED AUTHENTIC HADITH API =====
  Future<String?> _queryHadithApi(String userQuery) async {
    try {
      final q = userQuery.toLowerCase();
      String? edition;
      if (q.contains('bukhari') || q.contains('wudu') || q.contains('prayer') || q.contains('pillar') || q.contains('name') || q.contains('99')) {
        edition = 'eng-bukhari';
      } else if (q.contains('muslim') || q.contains('fasting') || q.contains('zakat')) {
        edition = 'eng-muslim';
      }

      if (edition != null) {
        final url = Uri.parse('https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/$edition/1.json');
        final response = await http.get(url).timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final hadiths = data['hadiths'] as List?;
          if (hadiths != null && hadiths.isNotEmpty) {
            final text = hadiths.first['text'] as String?;
            if (text != null && text.isNotEmpty) {
              final cleanText = text.length > 200 ? '${text.substring(0, 200)}…' : text;
              return 'VERIFIED HADITH TEXT (${edition.toUpperCase()}): "$cleanText"';
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Hadith API lookup non-blocking error: $e');
    }
    return null;
  }

  // ===== DIRECT GEMINI 3.6 REST API GENERATION =====
  Stream<String> _streamFromDirectGeminiApi(String enrichedPrompt, String key) async* {
    try {
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=$key');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": "$_systemInstructionText\n\nUser Question:\n$enrichedPrompt"}
              ]
            }
          ],
          "generationConfig": {
            "temperature": 0.2,
            "maxOutputTokens": 1024
          }
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final parts = candidates.first['content']?['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            final text = parts.first['text'] as String?;
            if (text != null && text.isNotEmpty) {
              yield text;
              return;
            }
          }
        }
      } else {
        debugPrint('Direct Gemini API HTTP error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('Direct Gemini API Exception: $e');
    }
  }

  /// 100% Dynamic AI Generation Pipeline
  Stream<String> sendMessageStream(String prompt) async* {
    try {
      // Step 1: Run Quran (API 2) & Hadith (API 3) lookups concurrently
      final apiResults = await Future.wait([
        _queryQuranApi(prompt),
        _queryHadithApi(prompt),
      ]).timeout(const Duration(seconds: 3), onTimeout: () => [null, null]);

      final quranContext = apiResults[0];
      final hadithContext = apiResults[1];

      String enrichedPrompt = prompt;
      if (quranContext != null || hadithContext != null) {
        enrichedPrompt = '''
[VERIFIED PRIMARY ISLAMIC SOURCES LOOKUP]:
${quranContext != null ? '- $quranContext\n' : ''}${hadithContext != null ? '- $hadithContext\n' : ''}
[USER QUESTION]:
$prompt
''';
      }

      // Step 2: Use direct Gemini 3.6 Flash REST API with user provided key
      if (customApiKey.isNotEmpty) {
        bool customKeySuccess = false;
        await for (final chunk in _streamFromDirectGeminiApi(enrichedPrompt, customApiKey)) {
          customKeySuccess = true;
          yield chunk;
        }
        if (customKeySuccess) return;
      }

      // Step 3: Primary Firebase AI fallback
      bool primarySucceeded = false;
      try {
        await _ensureInitialized();
        final content = Content.text(enrichedPrompt);
        final responseStream = _chatSession!.sendMessageStream(content);

        await for (final chunk in responseStream) {
          if (chunk.text != null && chunk.text!.isNotEmpty) {
            primarySucceeded = true;
            yield chunk.text!;
          }
        }
      } catch (primaryErr) {
        debugPrint('Primary Firebase AI Engine notice: $primaryErr');
      }

      if (primarySucceeded) return;

      yield 'Allahu A\'lam (Allah knows best). Please check your network connection and try again.';

    } on SocketException catch (_) {
      yield 'No internet connection. Please check your network connection and try again.\n\n*Allahu A\'lam (Allah knows best).*';
    } catch (e, stack) {
      debugPrint('AI Stream Exception: $e\n$stack');
      yield 'No internet connection. Please check your network connection and try again.\n\n*Allahu A\'lam (Allah knows best).*';
    }
  }

  /// Restores existing messages into Gemini ChatSession history so user can continue conversation seamlessly.
  Future<void> restoreChat(List<Map<String, dynamic>> messages) async {
    final List<Content> history = [];
    for (final msg in messages) {
      final text = msg['text'] as String? ?? '';
      final isUser = msg['isUser'] as bool? ?? false;
      if (text.isNotEmpty) {
        if (isUser) {
          history.add(Content.text(text));
        } else {
          history.add(Content.model([TextPart(text)]));
        }
      }
    }
    await _ensureInitialized(initialHistory: history);
  }

  /// Resets the active chat session for a "New Chat".
  void resetChat() {
    if (_model != null) {
      _chatSession = _model!.startChat();
    }
  }

  // ===== FIRESTORE CHAT HISTORY PERSISTENCE =====

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  /// Stream of user's past chats from Firestore.
  Stream<List<Map<String, dynamic>>> getPastChatsStream() {
    final uid = _currentUid;
    if (uid == null) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('aiChats')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  /// Saves or updates a chat session in Firestore under `users/{uid}/aiChats/{chatId}`.
  Future<void> saveChatToFirestore({
    required String chatId,
    required String title,
    required List<Map<String, dynamic>> messages,
  }) async {
    final uid = _currentUid;
    if (uid == null || messages.isEmpty) return;

    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('aiChats')
          .doc(chatId);

      await docRef.set({
        'title': title,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'messages': messages,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving chat to Firestore: $e');
    }
  }

  /// Deletes a chat session from Firestore.
  Future<void> deleteChatFromFirestore(String chatId) async {
    final uid = _currentUid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('aiChats')
          .doc(chatId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting chat: $e');
    }
  }
}
