import 'dart:async';
import 'package:flutter/material.dart';
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

  String _currentChatId = DateTime.now().millisecondsSinceEpoch.toString();



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

  bool _isGenerating = false;

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
    _scrollToBottom();

    try {
      final stream = IslamicAIService().sendMessageStream(text);
      await for (final chunk in stream) {
        if (!mounted) break;
        setState(() {
          aiMsg.isLoading = false;
          aiMsg.text += chunk;
        });
        _scrollToBottom();
      }
      _saveCurrentChatToFirestore();
    } catch (e) {
      if (mounted) {
        setState(() {
          aiMsg.isLoading = false;
          if (aiMsg.text.isEmpty) {
            aiMsg.text = 'No internet connection. Please check your network connection and try again.\n\n*Allahu A\'lam (Allah knows best).*';
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          aiMsg.isLoading = false;
        });
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

    if (loaded.isEmpty) {
      loaded.add(_ChatMessage(text: _greeting, isUser: false));
    }

    setState(() {
      _currentChatId = chatId;
      _messages
        ..clear()
        ..addAll(loaded);
    });

    IslamicAIService().restoreChat(parsedMaps);
    _closeHistory();
    _scrollToBottom();
  }

  /// Starts a fresh conversation.
  void _startNewChat() {
    setState(() {
      _currentChatId = DateTime.now().millisecondsSinceEpoch.toString();
      _messages
        ..clear()
        ..add(_ChatMessage(text: _greeting, isUser: false));
    });

    IslamicAIService().resetChat();
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
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
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
                  const SizedBox(height: 8),
                  _buildInputBar(),
                  Builder(
                    builder: (context) {
                      final navBarHeightWithInset = 70.0 + MediaQuery.of(context).padding.bottom;
                      final double extraBottom = keyboardHeight > navBarHeightWithInset
                          ? (keyboardHeight - navBarHeightWithInset)
                          : 8.0;
                      return SizedBox(height: extraBottom);
                    },
                  ),
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
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: IslamicAIService().getPastChatsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.midTeal,
                      ),
                    );
                  }

                  final chats = snapshot.data ?? [];
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
                              Icon(Icons.chat_bubble_outline_rounded,
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
                                onTap: () => IslamicAIService().deleteChatFromFirestore(chatId),
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
    final bool showLoading = message.isLoading && message.text.isEmpty;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
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
                  SizedBox(
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
                  SelectableText(
                    message.text,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      height: 1.5,
                      color: isUser ? Colors.white : _primaryText(context).withValues(alpha: 0.9),
                    ),
                  ),
                  if (!isUser && message.isLoading) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
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
