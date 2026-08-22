import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/auth_header.dart'; // AppColors
import '../services/islamic_ai_service.dart';

/// ===== ASSISTANT TAB =====
/// Used inline inside DashboardScreen's bottom-nav switch, e.g.:
///   case 3:
///     return AssistantTab(isDarkMode: _isDarkMode);
class AssistantTab extends StatefulWidget {
  final bool isDarkMode;
  const AssistantTab({super.key, this.isDarkMode = false});

  @override
  State<AssistantTab> createState() => _AssistantTabState();
}

class _ChatMessage {
  String text;
  final bool isUser;
  bool isLoading;
  _ChatMessage({required this.text, required this.isUser, this.isLoading = false});
}

class _AssistantTabState extends State<AssistantTab> with SingleTickerProviderStateMixin {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<_ChatMessage> _messages = [];

  // Future-based history fetch — simple, fast, no stream issues
  late Future<List<Map<String, dynamic>>> _chatsFuture;
  int _historyRefreshKey = 0; // increment to force a reload

  // ===== SIDE PANEL ANIMATION =====
  late final AnimationController _panelCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late final Animation<Offset> _slideAnim = Tween<Offset>(
    begin: const Offset(-1, 0), // fully off-screen to the left
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _panelCtrl, curve: Curves.easeOutCubic));

  bool _historyOpen = false;

  // Sparkling background stars
  final List<_AssistantStarConfig> _stars = [
    _AssistantStarConfig(topFraction: 0.04, leftFraction: 0.85, size: 5, delayMs: 200),
    _AssistantStarConfig(topFraction: 0.10, leftFraction: 0.12, size: 4, delayMs: 600),
    _AssistantStarConfig(topFraction: 0.30, leftFraction: 0.90, size: 4, delayMs: 900),
    _AssistantStarConfig(topFraction: 0.55, leftFraction: 0.06, size: 5, delayMs: 350),
  ];

  // DeepSeek-Style Prompt Cards Configuration
  final List<Map<String, dynamic>> _deepSeekPromptCards = [
    {
      'title': 'Prayer Guidance',
      'prompt': 'How do I perform Wudu step by step according to Sunnah?',
      'subtitle': 'Perform ablution correctly before Salat',
      'icon': Icons.water_drop_rounded,
      'accent': const Color(0xFF0D9488),
    },
    {
      'title': 'Fasting Rules',
      'prompt': 'What actions invalidate the fast during Ramadan?',
      'subtitle': 'Essential rules for Sawm & Ramadan',
      'icon': Icons.nightlight_round,
      'accent': const Color(0xFFF59E0B), // Night Sky Amber Gold (Not red)
    },
    {
      'title': 'Zakat & Nisab',
      'prompt': 'What is the Nisab threshold and rate for calculating Zakat?',
      'subtitle': 'Calculate obligatory Islamic charity',
      'icon': Icons.account_balance_wallet_rounded,
      'accent': const Color(0xFF2563EB),
    },
    {
      'title': '5 Pillars of Islam',
      'prompt': 'What are the 5 pillars of Islam and their significance?',
      'subtitle': 'Core foundation of Muslim faith',
      'icon': Icons.menu_book_rounded,
      'accent': const Color(0xFF7C3AED),
    },
  ];

  String _currentChatId = DateTime.now().millisecondsSinceEpoch.toString();
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _chatsFuture = IslamicAIService().fetchPastChats();
  }

  void _refreshHistory() {
    setState(() {
      _historyRefreshKey++;
      _chatsFuture = IslamicAIService().fetchPastChats();
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _panelCtrl.dispose();
    super.dispose();
  }

  void _handleSend([String? presetText]) async {
    final String text = (presetText ?? _inputCtrl.text).trim();
    if (text.isEmpty || _isGenerating) return;

    final userMsg = _ChatMessage(text: text, isUser: true);
    final aiMsg = _ChatMessage(text: '', isUser: false, isLoading: true);

    setState(() {
      _isGenerating = true;
      _messages.add(userMsg);
      _messages.add(aiMsg);
    });
    _inputCtrl.clear();
    _scrollToBottom(immediate: true);

    try {
      final stream = IslamicAIService().sendMessageStream(text);
      int lastUpdateMs = DateTime.now().millisecondsSinceEpoch;

      await for (final chunk in stream) {
        if (!mounted) break;
        aiMsg.text += chunk;
        final now = DateTime.now().millisecondsSinceEpoch;
        // Throttle UI rebuilds to ~60ms intervals for smooth 60fps streaming text without jitter
        if (now - lastUpdateMs > 60 || aiMsg.isLoading) {
          lastUpdateMs = now;
          setState(() {
            aiMsg.isLoading = false;
          });
          _scrollToBottom(immediate: true);
        }
      }
      if (mounted) {
        setState(() {
          aiMsg.isLoading = false;
        });
        _scrollToBottom(immediate: true);
      }
      _saveCurrentChatToFirestore();
      _refreshHistory();
    } catch (e) {
      if (mounted) {
        setState(() {
          aiMsg.isLoading = false;
          if (aiMsg.text.isEmpty) {
            aiMsg.text =
                'No internet connection. Please check your network connection and try again.\n\n*Allahu A\'lam (Allah knows best).*';
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          aiMsg.isLoading = false;
        });
        _scrollToBottom(immediate: false);
      }
    }
  }

  void _saveCurrentChatToFirestore() {
    final userMsgs = _messages.where((m) => m.isUser).toList();
    if (userMsgs.isEmpty) return;

    final title = userMsgs.first.text.length > 35
        ? '${userMsgs.first.text.substring(0, 35)}…'
        : userMsgs.first.text;

    final msgList = _messages
        .where((m) => !m.isLoading && m.text.isNotEmpty)
        .map((m) => {'text': m.text, 'isUser': m.isUser})
        .toList();

    IslamicAIService().saveChatToFirestore(
      chatId: _currentChatId,
      title: title,
      messages: msgList,
    );
  }

  void _scrollToBottom({bool immediate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        final maxExtent = _scrollCtrl.position.maxScrollExtent;
        if (immediate) {
          _scrollCtrl.jumpTo(maxExtent);
        } else {
          _scrollCtrl.animateTo(
            maxExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
          );
        }
      }
    });
  }

  /// Restores a past chat conversation from Firestore.
  void _openFirestoreChat(Map<String, dynamic> doc) {
    final chatId = doc['id'] as String;
    final rawMsgs = (doc['messages'] as List<dynamic>?) ?? [];
    final List<_ChatMessage> loaded = [];

    final List<Map<String, dynamic>> parsedMaps = [];
    for (final item in rawMsgs) {
      final map = Map<String, dynamic>.from(item as Map);
      parsedMaps.add(map);
      loaded.add(_ChatMessage(
        text: map['text'] as String? ?? '',
        isUser: map['isUser'] as bool? ?? false,
      ));
    }

    setState(() {
      _currentChatId = chatId;
      _messages
        ..clear()
        ..addAll(loaded);
    });

    IslamicAIService().restoreChat(parsedMaps);
    _closeHistory();
    _scrollToBottom(immediate: true);
  }

  /// Starts a fresh conversation.
  void _startNewChat() {
    setState(() {
      _currentChatId = DateTime.now().millisecondsSinceEpoch.toString();
      _messages.clear();
    });

    IslamicAIService().resetChat();
    _closeHistory();
  }

  void _openHistory() {
    _refreshHistory(); // always fetch fresh data when opening
    setState(() => _historyOpen = true);
    _panelCtrl.forward();
  }

  void _closeHistory() {
    _panelCtrl.reverse().whenComplete(() {
      if (mounted) setState(() => _historyOpen = false);
    });
  }

  void _toggleHistory() {
    if (_historyOpen) {
      _closeHistory();
    } else {
      _openHistory();
    }
  }

  /// Confirms before deleting a chat conversation from history
  void _confirmDeleteChat(BuildContext context, String chatId, String title) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = _dark;
        final dialogBg = isDark ? Colors.black : Colors.white;
        final primaryText = isDark ? Colors.white : AppColors.navyBlue;
        final secondaryText =
            isDark ? Colors.white.withValues(alpha: 0.7) : AppColors.navyBlue.withValues(alpha: 0.65);

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: dialogBg,
          elevation: 16,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: isDark ? 0.2 : 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Delete Conversation?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to delete "$title"? This action cannot be undone.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    height: 1.45,
                    color: secondaryText,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.2)
                                : AppColors.navyBlue.withValues(alpha: 0.2),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: primaryText,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await IslamicAIService().deleteChatFromFirestore(chatId);
                          if (_currentChatId == chatId) _startNewChat();
                          _refreshHistory();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Delete',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===== THEME HELPERS =====
  bool get _dark =>
      widget.isDarkMode || Theme.of(context).brightness == Brightness.dark;

  Color _pageBg(BuildContext context) =>
      _dark ? Colors.black : const Color(0xFFF3F6F6);

  Color _bubbleBg(BuildContext context) =>
      _dark ? Colors.black : Colors.white;

  Color _bubbleBorder(BuildContext context) => _dark
      ? Colors.white.withValues(alpha: 0.16)
      : AppColors.navyBlue.withValues(alpha: 0.15);

  Color _primaryText(BuildContext context) =>
      _dark ? Colors.white : AppColors.navyBlue;

  Color _secondaryText(BuildContext context) => _dark
      ? Colors.white.withValues(alpha: 0.6)
      : AppColors.navyBlue.withValues(alpha: 0.55);

  Color _inputBarBg(BuildContext context) =>
      _dark ? Colors.black : Colors.white;

  Color _panelBg(BuildContext context) =>
      _dark ? Colors.black : Colors.white;

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      key: const ValueKey('AssistantTab'),
      color: _pageBg(context),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final panelWidth = (constraints.maxWidth * 0.78).clamp(200.0, 260.0);

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Background sparkling stars
              ..._stars.map((star) {
                return _AssistantTwinklingStar(
                  topFraction: star.topFraction,
                  leftFraction: star.leftFraction,
                  size: star.size,
                  delayMs: star.delayMs,
                );
              }),

              Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: _messages.isEmpty
                        ? _buildDeepSeekEmptyState()
                        : ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) =>
                                _buildMessageBubble(_messages[index]),
                          ),
                  ),
                  const SizedBox(height: 8),
                  _buildInputBar(),
                  Builder(
                    builder: (context) {
                      final navBarHeightWithInset =
                          70.0 + MediaQuery.of(context).padding.bottom;
                      final double extraBottom = keyboardHeight > navBarHeightWithInset
                          ? (keyboardHeight - navBarHeightWithInset)
                          : 8.0;
                      return SizedBox(height: extraBottom);
                    },
                  ),
                ],
              ),

              // ===== BACKDROP =====
              if (_historyOpen || _panelCtrl.isAnimating)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _closeHistory,
                    child: AnimatedBuilder(
                      animation: _panelCtrl,
                      builder: (context, child) => Container(
                        color: Colors.black.withValues(alpha: 0.35 * _panelCtrl.value),
                      ),
                    ),
                  ),
                ),

              // ===== COLLAPSIBLE SIDE PANEL =====
              Positioned(
                top: 0,
                bottom: 0,
                left: 0,
                width: panelWidth,
                child: SlideTransition(
                  position: _slideAnim,
                  child: _buildHistoryPanel(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Professional & Standard AI Empty State for New Conversations
  Widget _buildDeepSeekEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Professional AI Emblem Header
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _dark
                    ? Colors.white.withValues(alpha: 0.06)
                    : AppColors.navyBlue.withValues(alpha: 0.05),
                border: Border.all(
                  color: AppColors.midTeal.withValues(alpha: _dark ? 0.3 : 0.2),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.midTeal.withValues(alpha: 0.1),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const AppLogo(size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              'Assalamu Alaikum!',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _primaryText(context),
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'How can I help you with your Islamic learning today?',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: _secondaryText(context),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            // Trust Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _dark
                    ? Colors.white.withValues(alpha: 0.06)
                    : AppColors.navyBlue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _dark
                      ? Colors.white.withValues(alpha: 0.1)
                      : AppColors.navyBlue.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome_rounded, size: 12, color: AppColors.midTeal),
                  const SizedBox(width: 6),
                  Text(
                    'DeenMate AI • Authentic Quran & Sunnah Guidance',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: _primaryText(context).withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Standard Professional Suggestion List Cards
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: _deepSeekPromptCards.map((card) {
                  final Color accentColor = card['accent'] as Color;
                  final IconData iconData = card['icon'] as IconData;
                  final String title = card['title'] as String;
                  final String prompt = card['prompt'] as String;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => _handleSend(prompt),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: _bubbleBg(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _bubbleBorder(context), width: 1.0),
                          boxShadow: [
                            BoxShadow(
                              color: _dark
                                  ? Colors.black.withValues(alpha: 0.25)
                                  : AppColors.navyBlue.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: _dark ? 0.2 : 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(iconData, color: accentColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: _primaryText(context),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    prompt,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: _secondaryText(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.north_east_rounded,
                              size: 16,
                              color: _secondaryText(context).withValues(alpha: 0.45),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryPanel() {
    return Material(
      color: _panelBg(context),
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Chat History',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _primaryText(context),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _closeHistory,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: _dark
                            ? Colors.white.withValues(alpha: 0.08)
                            : AppColors.navyBlue.withValues(alpha: 0.06),
                      ),
                      child: Icon(Icons.chevron_left_rounded,
                          color: _primaryText(context), size: 20),
                    ),
                  ),
                ],
              ),
            ),
            // ===== NEW CHAT BUTTON =====
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
              child: InkWell(
                onTap: _startNewChat,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _dark ? Colors.black : AppColors.midTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _dark
                          ? Colors.white.withValues(alpha: 0.16)
                          : AppColors.midTeal.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_note_rounded,
                          size: 18, color: AppColors.midTeal),
                      const SizedBox(width: 8),
                      Text(
                        'New chat',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _dark
                              ? AppColors.midTeal.withValues(alpha: 0.95)
                              : AppColors.midTeal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Divider(height: 1, color: _bubbleBorder(context)),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                key: ValueKey(_historyRefreshKey),
                future: _chatsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.midTeal,
                      ),
                    );
                  }

                  if (snapshot.hasError || !snapshot.hasData) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.wifi_off_rounded,
                              size: 28,
                              color: _secondaryText(context).withValues(alpha: 0.5)),
                          const SizedBox(height: 8),
                          Text(
                            'Could not load history.',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: _secondaryText(context)),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _refreshHistory,
                            child: Text('Retry',
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: AppColors.midTeal)),
                          ),
                        ],
                      ),
                    );
                  }

                  final chats = snapshot.data!;
                  if (chats.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No past conversations yet.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _secondaryText(context),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: chats.length,
                    itemBuilder: (context, index) {
                      final item = chats[index];
                      final title = item['title'] as String? ?? 'Islamic Question';
                      final chatId = item['id'] as String;

                      return InkWell(
                        onTap: () => _openFirestoreChat(item),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              const Icon(Icons.chat_bubble_outline_rounded,
                                  color: AppColors.midTeal, size: 16),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: _primaryText(context),
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _confirmDeleteChat(context, chatId, title),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.delete_outline_rounded,
                                    size: 16,
                                    color: Colors.red.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 50, 22, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _dark ? Colors.white.withValues(alpha: 0.15) : AppColors.navyBlue,
              borderRadius: BorderRadius.circular(14),
              border: _dark
                  ? Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1)
                  : null,
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Islamic Assistant',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _primaryText(context),
                  ),
                ),
                Text(
                  'Ask about prayer, fasting, Zakat & more',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: _secondaryText(context),
                  ),
                ),
              ],
            ),
          ),
          // ===== HISTORY TOGGLE ICON =====
          GestureDetector(
            onTap: _toggleHistory,
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: _dark
                    ? Colors.white.withValues(alpha: 0.1)
                    : AppColors.navyBlue.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _dark
                      ? Colors.white.withValues(alpha: 0.14)
                      : AppColors.navyBlue.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Icon(Icons.history_rounded, color: _primaryText(context), size: 19),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    final bool isUser = message.isUser;
    final bool showLoading = message.isLoading && message.text.isEmpty;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: isUser ? 290 : double.infinity),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? AppColors.navyBlue : _bubbleBg(context),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser ? null : Border.all(color: _bubbleBorder(context), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: _dark
                  ? Colors.black.withValues(alpha: 0.4)
                  : AppColors.navyBlue.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: showLoading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.midTeal,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Verifying authentic sources...',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                      color: _secondaryText(context),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarkdownBody(
                    data: message.text,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.5,
                        color: isUser
                            ? Colors.white
                            : _primaryText(context).withValues(alpha: 0.95),
                      ),
                      h1: GoogleFonts.poppins(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: isUser ? Colors.white : _primaryText(context),
                      ),
                      h2: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isUser ? Colors.white : _primaryText(context),
                      ),
                      h3: GoogleFonts.poppins(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: isUser ? Colors.white : _primaryText(context),
                      ),
                      h4: GoogleFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isUser ? Colors.white : _primaryText(context),
                      ),
                      strong: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: isUser ? Colors.white : _primaryText(context),
                      ),
                      em: GoogleFonts.inter(
                        fontStyle: FontStyle.italic,
                        color: isUser ? Colors.white : _primaryText(context),
                      ),
                      listBullet: GoogleFonts.inter(
                        fontSize: 13,
                        color: isUser ? Colors.white : _primaryText(context),
                      ),
                      horizontalRuleDecoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: isUser
                                ? Colors.white.withValues(alpha: 0.3)
                                : _bubbleBorder(context),
                            width: 1,
                          ),
                        ),
                      ),
                      blockquote: GoogleFonts.amiri(
                        fontSize: 15,
                        height: 1.6,
                        color: isUser
                            ? Colors.white.withValues(alpha: 0.95)
                            : AppColors.midTeal,
                      ),
                      blockquoteDecoration: BoxDecoration(
                        color: isUser
                            ? Colors.white.withValues(alpha: 0.1)
                            : AppColors.midTeal.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: const Border(
                          left: BorderSide(color: AppColors.midTeal, width: 3),
                        ),
                      ),
                    ),
                  ),
                  if (!isUser && message.isLoading) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 8,
                          height: 8,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: AppColors.midTeal,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Streaming response...',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: _secondaryText(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _inputBarBg(context),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: _dark
                ? Colors.white.withValues(alpha: 0.14)
                : AppColors.navyBlue.withValues(alpha: 0.18),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: _dark
                  ? Colors.black.withValues(alpha: 0.4)
                  : AppColors.navyBlue.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                style: GoogleFonts.inter(fontSize: 13, color: _primaryText(context)),
                decoration: InputDecoration(
                  hintText: 'Ask a question...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13,
                    color: _dark ? Colors.white.withValues(alpha: 0.4) : AppColors.placeholder,
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onSubmitted: (_) => _handleSend(),
              ),
            ),
            GestureDetector(
              onTap: () => _handleSend(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _dark ? Colors.white.withValues(alpha: 0.15) : AppColors.navyBlue,
                  shape: BoxShape.circle,
                  border: _dark
                      ? Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1)
                      : null,
                ),
                child: const Icon(Icons.arrow_upward_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== SPARKLING STAR BACKGROUND =====

class _AssistantStarConfig {
  final double topFraction;
  final double leftFraction;
  final double size;
  final int delayMs;

  _AssistantStarConfig({
    required this.topFraction,
    required this.leftFraction,
    required this.size,
    required this.delayMs,
  });
}

class _AssistantTwinklingStar extends StatefulWidget {
  final double topFraction;
  final double leftFraction;
  final double size;
  final int delayMs;

  const _AssistantTwinklingStar({
    required this.topFraction,
    required this.leftFraction,
    required this.size,
    required this.delayMs,
  });

  @override
  State<_AssistantTwinklingStar> createState() => _AssistantTwinklingStarState();
}

class _AssistantTwinklingStarState extends State<_AssistantTwinklingStar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _opacity = Tween<double>(begin: 0.25, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _timer = Timer(Duration(milliseconds: widget.delayMs), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: FractionalOffset(widget.leftFraction, widget.topFraction),
      child: AnimatedBuilder(
        animation: _opacity,
        builder: (context, child) {
          return Opacity(
            opacity: _opacity.value,
            child: CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _AssistantStarPainter(),
            ),
          );
        },
      ),
    );
  }
}

class _AssistantStarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFE082).withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rx = size.width / 2;
    final ry = size.height / 2;

    path.moveTo(cx, cy - ry);
    path.quadraticBezierTo(cx, cy, cx + rx, cy);
    path.quadraticBezierTo(cx, cy, cx, cy + ry);
    path.quadraticBezierTo(cx, cy, cx - rx, cy);
    path.quadraticBezierTo(cx, cy, cx, cy - ry);
    path.close();

    canvas.drawPath(path, paint);

    final corePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), size.width * 0.12, corePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
