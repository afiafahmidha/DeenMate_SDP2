import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/auth_header.dart'; // AppColors

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
  final String text;
  final bool isUser;
  _ChatMessage({required this.text, required this.isUser});
}

/// A saved past conversation. `messages` holds the full Q&A thread so that
/// tapping this entry in the side panel can restore it into the chat, the
/// same way opening a past chat works in Claude's sidebar.
class _ChatHistoryItem {
  final String title;
  final String time;
  final List<_ChatMessage> messages;
  _ChatHistoryItem({required this.title, required this.time, required this.messages});
}

class _AssistantTabState extends State<AssistantTab> with SingleTickerProviderStateMixin {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<_ChatMessage> _messages = [];

  static const String _greeting =
      'Assalamu Alaikum! Ask me about prayer, fasting, Zakat, Hajj, or other Islamic topics — I\'ll do my best to help.';

  // ===== SIDE PANEL ANIMATION =====
  // Using an explicit AnimationController (rather than AnimatedPositioned)
  // guarantees the slide-in/out animation always plays, regardless of how
  // this widget is constrained by its parent (IndexedStack / tab switcher).
  late final AnimationController _panelCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late final Animation<Offset> _slideAnim = Tween<Offset>(
    begin: const Offset(-1, 0), // fully off-screen to the left
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _panelCtrl, curve: Curves.easeOutCubic));

  bool _historyOpen = false;

  // A few sparkling stars, same look as the dashboard background — kept
  // sparse here so they read as a subtle touch rather than a busy sky.
  final List<_AssistantStarConfig> _stars = [
    _AssistantStarConfig(topFraction: 0.04, leftFraction: 0.85, size: 5, delayMs: 200),
    _AssistantStarConfig(topFraction: 0.10, leftFraction: 0.12, size: 4, delayMs: 600),
    _AssistantStarConfig(topFraction: 0.30, leftFraction: 0.90, size: 4, delayMs: 900),
    _AssistantStarConfig(topFraction: 0.55, leftFraction: 0.06, size: 5, delayMs: 350),
  ];

  final List<String> _suggestedPrompts = [
    'What are the 5 pillars of Islam?',
    'How do I perform Wudu?',
    'What is the Nisab for Zakat?',
    'How many Rak\'ahs in each prayer?',
    'What breaks the fast?',
  ];

  // ===== DEMO CHAT HISTORY (placeholder — wire up to real storage later) =====
  // Each entry stores the full past thread (question + answer) so tapping it
  // can restore that exact conversation into the chat view.
  late final List<_ChatHistoryItem> _history = [
    _ChatHistoryItem(
      title: 'Steps of Wudu',
      time: 'Today',
      messages: [
        _ChatMessage(text: 'How do I perform Wudu?', isUser: true),
        _ChatMessage(text: _answerFor('wudu'), isUser: false),
      ],
    ),
    _ChatHistoryItem(
      title: 'Zakat Nisab threshold',
      time: 'Yesterday',
      messages: [
        _ChatMessage(text: 'What is the Nisab for Zakat?', isUser: true),
        _ChatMessage(text: _answerFor('nisab'), isUser: false),
      ],
    ),
    _ChatHistoryItem(
      title: 'Rak\'ahs in each prayer',
      time: '2 days ago',
      messages: [
        _ChatMessage(text: 'How many Rak\'ahs in each prayer?', isUser: true),
        _ChatMessage(text: _answerFor('rakah'), isUser: false),
      ],
    ),
  ];

  // ===== SIMPLE KEYWORD-BASED FAQ ENGINE =====
  final List<Map<String, dynamic>> _faq = [
    {
      'keywords': ['pillar', 'pillars', 'five pillars', 'arkan'],
      'answer':
          'The Five Pillars of Islam are:\n\n1. Shahada — declaration of faith\n2. Salah — five daily prayers\n3. Zakat — obligatory charity\n4. Sawm — fasting in Ramadan\n5. Hajj — pilgrimage to Makkah (once in a lifetime, if able)',
    },
    {
      'keywords': ['wudu', 'ablution', 'wuzu'],
      'answer':
          'Steps of Wudu:\n\n1. Intention (Niyyah)\n2. Say "Bismillah"\n3. Wash hands 3 times\n4. Rinse mouth 3 times\n5. Rinse nose 3 times\n6. Wash face 3 times\n7. Wash arms up to elbows (right then left) 3 times\n8. Wipe head once\n9. Wipe ears once\n10. Wash feet up to ankles (right then left) 3 times',
    },
    {
      'keywords': ['nisab', 'zakat threshold', 'zakat minimum'],
      'answer':
          'Nisab is the minimum wealth a Muslim must own before Zakat becomes obligatory — equivalent to 85g of gold or 595g of silver. If your zakatable wealth stays above this for one lunar year (Hawl), you owe 2.5% as Zakat. Check the Zakat Calculator on the Home tab for a live calculation.',
    },
    {
      'keywords': ['rakah', 'rakat', 'rakaat', 'raka', 'how many rakah', 'units of prayer'],
      'answer':
          'Rak\'ahs per prayer (Fard/obligatory):\n\nFajr — 2\nDhuhr — 4\nAsr — 4\nMaghrib — 3\nIsha — 4\n\n(Sunnah and Nafl rak\'ahs are additional to these.)',
    },
    {
      'keywords': ['fast', 'fasting', 'ramadan', 'sawm', 'break the fast', 'breaks fast'],
      'answer':
          'Things that break the fast include: eating or drinking intentionally, smoking, intentional vomiting, and marital relations during fasting hours. Forgetfully eating or drinking does not break the fast — you should simply stop once you remember.',
    },
    {
      'keywords': ['hajj', 'pilgrimage'],
      'answer':
          'Hajj is the pilgrimage to Makkah, obligatory once in a lifetime for those who are physically and financially able. Check the Hajj & Umrah Planner on the Home tab for a full step-by-step ritual checklist.',
    },
    {
      'keywords': ['qurbani', 'sacrifice', 'udhiyah', 'eid sacrifice'],
      'answer':
          'Qurbani (Udhiyah) is an animal sacrifice performed during Eid al-Adha, commemorating Prophet Ibrahim\'s (AS) willingness to sacrifice his son. Check the Qurbani Planner on the Home tab for cost-splitting and scheduling help.',
    },
    {
      'keywords': ['prayer time', 'salah time', 'when is', 'next prayer'],
      'answer':
          'You can see today\'s exact prayer times and the live countdown to the next prayer on the Prayer tab — it updates automatically based on your location.',
    },
    {
      'keywords': ['inheritance', 'faraid', 'wealth distribution', 'estate'],
      'answer':
          'Islamic inheritance (Faraid) distributes a deceased person\'s estate according to fixed Quranic shares among the spouse, children, and parents. Check the Inheritance Guide on the Home tab for a simplified calculator covering common family cases.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(_ChatMessage(text: _greeting, isUser: false));
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _panelCtrl.dispose();
    super.dispose();
  }

  void _handleSend([String? presetText]) {
    final String text = (presetText ?? _inputCtrl.text).trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _messages.add(_ChatMessage(text: _generateAnswer(text), isUser: false));
    });
    _inputCtrl.clear();

    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _generateAnswer(String question) {
    final String q = question.toLowerCase();
    Map<String, dynamic>? bestMatch;
    int bestScore = 0;

    for (final entry in _faq) {
      int score = 0;
      for (final kw in (entry['keywords'] as List<String>)) {
        if (q.contains(kw)) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        bestMatch = entry;
      }
    }

    if (bestMatch != null) {
      return bestMatch['answer'] as String;
    }
    return 'I don\'t have a specific answer for that yet. Try asking about prayer, Wudu, Zakat, fasting, Hajj, Qurbani, or inheritance — or consult a local scholar for detailed guidance.';
  }

  /// Loads a past conversation back into the chat view, replacing the
  /// current thread — mirrors "open a past chat" behavior.
  void _openHistoryItem(_ChatHistoryItem item) {
    setState(() {
      _messages
        ..clear()
        ..addAll(item.messages);
    });
    _closeHistory();
    _scrollToBottom();
  }

  /// Starts a fresh conversation — mirrors the "New chat" button in Claude's
  /// sidebar. If the current thread has real content (more than just the
  /// opening greeting), it's saved into history first so it isn't lost.
  void _startNewChat() {
    final bool hasRealContent = _messages.any((m) => m.isUser);
    if (hasRealContent) {
      final firstUserMsg = _messages.firstWhere((m) => m.isUser, orElse: () => _messages.first);
      _history.insert(
        0,
        _ChatHistoryItem(
          title: firstUserMsg.text.length > 40
              ? '${firstUserMsg.text.substring(0, 40)}…'
              : firstUserMsg.text,
          time: 'Just now',
          messages: List<_ChatMessage>.from(_messages),
        ),
      );
    }

    setState(() {
      _messages
        ..clear()
        ..add(_ChatMessage(text: _greeting, isUser: false));
    });
    _closeHistory();
    _scrollToBottom();
  }

  void _openHistory() {
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

  // ===== THEME HELPERS =====
  bool get _dark =>
      widget.isDarkMode || Theme.of(context).brightness == Brightness.dark;

  Color _pageBg(BuildContext context) =>
      _dark ? Colors.black : const Color(0xFFF3F6F6);

  Color _bubbleBg(BuildContext context) =>
      _dark ? const Color(0xFF1A2330) : Colors.white;

  Color _bubbleBorder(BuildContext context) => _dark
      ? Colors.white.withValues(alpha: 0.14)
      : AppColors.navyBlue.withValues(alpha: 0.15);

  Color _primaryText(BuildContext context) =>
      _dark ? Colors.white : AppColors.navyBlue;

  Color _secondaryText(BuildContext context) => _dark
      ? Colors.white.withValues(alpha: 0.6)
      : AppColors.navyBlue.withValues(alpha: 0.55);

  Color _inputBarBg(BuildContext context) =>
      _dark ? const Color(0xFF1A2330) : Colors.white;

  Color _panelBg(BuildContext context) =>
      _dark ? const Color(0xFF10161F) : Colors.white;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      key: const ValueKey('AssistantTab'),
      color: _pageBg(context),
      // LayoutBuilder gives us the ACTUAL bounded width/height this tab has
      // to work with, so the panel width and the Stack below are never
      // guessing at unbounded constraints — this is what makes the slide
      // animation and sizing reliable no matter where this tab is hosted.
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Panel is 78% of the available width, capped at 260 logical px —
          // matches Claude's sidebar proportions instead of a fixed value
          // that could be too wide/narrow depending on the device.
          final panelWidth = (constraints.maxWidth * 0.78).clamp(200.0, 260.0);

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // A few sparkling twinkling stars in the background, matching
              // the dashboard's night-sky touch — shows through wherever the
              // content below doesn't fully cover the page background.
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
                    child: ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
                    ),
                  ),
                  if (_messages.length <= 1) _buildSuggestedPrompts(),
                  const SizedBox(height: 10),
                  _buildInputBar(),
                  SizedBox(height: 12 + bottomInset),
                ],
              ),

              // ===== BACKDROP (tap outside the panel to close it) =====
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

  Widget _buildHistoryPanel() {
    return Material(
      color: _panelBg(context),
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
                    child: Text('Chat History',
                        style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _primaryText(context))),
                  ),
                  // Collapse button — same idea as Claude's sidebar-collapse arrow.
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
                    color: AppColors.midTeal.withValues(alpha: _dark ? 0.18 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.midTeal.withValues(alpha: _dark ? 0.5 : 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.edit_note_rounded, size: 18, color: AppColors.midTeal),
                      const SizedBox(width: 8),
                      Text('New chat',
                          style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: _dark
                                  ? AppColors.midTeal.withValues(alpha: 0.95)
                                  : AppColors.midTeal)),
                    ],
                  ),
                ),
              ),
            ),
            Divider(height: 1, color: _bubbleBorder(context)),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: _history.length,
                itemBuilder: (context, index) {
                  final item = _history[index];
                  return InkWell(
                    onTap: () => _openHistoryItem(item),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded,
                              color: AppColors.midTeal, size: 16),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: _primaryText(context))),
                                const SizedBox(height: 2),
                                Text(item.time,
                                    style: GoogleFonts.inter(
                                        fontSize: 10.5, color: _secondaryText(context))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
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
                Text('Islamic Assistant',
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.bold, color: _primaryText(context))),
                Text('Ask about prayer, fasting, Zakat & more',
                    style: GoogleFonts.inter(fontSize: 11.5, color: _secondaryText(context))),
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

  Widget _buildSuggestedPrompts() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _suggestedPrompts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final prompt = _suggestedPrompts[index];
          return GestureDetector(
            onTap: () => _handleSend(prompt),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _dark
                    ? AppColors.midTeal.withValues(alpha: 0.18)
                    : AppColors.midTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.midTeal.withValues(alpha: _dark ? 0.5 : 0.3)),
              ),
              alignment: Alignment.center,
              child: Text(
                prompt,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: _dark ? AppColors.midTeal.withValues(alpha: 0.95) : AppColors.midTeal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    final bool isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
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
        child: Text(
          message.text,
          style: GoogleFonts.inter(
            fontSize: 13,
            height: 1.5,
            color: isUser ? Colors.white : _primaryText(context).withValues(alpha: 0.9),
          ),
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
          // Border applies in BOTH themes so the input bar is always visible
          // against the page background, light or dark.
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                  border: _dark ? Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1) : null,
                ),
                child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== SPARKLING STAR BACKGROUND (same idea as the dashboard's night sky) =====

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
    // Align + FractionalOffset (rather than Positioned inside a
    // LayoutBuilder) since a non-Positioned child is what a Stack expects.
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

/// Pulls a canned answer straight from the FAQ text so the demo history
/// entries above show the same wording the assistant would actually give.
String _answerFor(String key) {
  switch (key) {
    case 'wudu':
      return 'Steps of Wudu:\n\n1. Intention (Niyyah)\n2. Say "Bismillah"\n3. Wash hands 3 times\n4. Rinse mouth 3 times\n5. Rinse nose 3 times\n6. Wash face 3 times\n7. Wash arms up to elbows (right then left) 3 times\n8. Wipe head once\n9. Wipe ears once\n10. Wash feet up to ankles (right then left) 3 times';
    case 'nisab':
      return 'Nisab is the minimum wealth a Muslim must own before Zakat becomes obligatory — equivalent to 85g of gold or 595g of silver. If your zakatable wealth stays above this for one lunar year (Hawl), you owe 2.5% as Zakat. Check the Zakat Calculator on the Home tab for a live calculation.';
    case 'rakah':
      return 'Rak\'ahs per prayer (Fard/obligatory):\n\nFajr — 2\nDhuhr — 4\nAsr — 4\nMaghrib — 3\nIsha — 4\n\n(Sunnah and Nafl rak\'ahs are additional to these.)';
    default:
      return '';
  }
}