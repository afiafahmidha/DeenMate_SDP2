import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/auth_header.dart'; // AppColors

/// ===== ASSISTANT TAB =====
/// Used inline inside DashboardScreen's bottom-nav switch, e.g.:
///   case 3:
///     return const AssistantTab();
class AssistantTab extends StatefulWidget {
  const AssistantTab({super.key});

  @override
  State<AssistantTab> createState() => _AssistantTabState();
}

class _ChatMessage {
  final String text;
  final bool isUser;
  _ChatMessage({required this.text, required this.isUser});
}

class _AssistantTabState extends State<AssistantTab> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<_ChatMessage> _messages = [];

  final List<String> _suggestedPrompts = [
    'What are the 5 pillars of Islam?',
    'How do I perform Wudu?',
    'What is the Nisab for Zakat?',
    'How many Rak\'ahs in each prayer?',
    'What breaks the fast?',
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
    _messages.add(_ChatMessage(
      text: 'Assalamu Alaikum! Ask me about prayer, fasting, Zakat, Hajj, or other Islamic topics — I\'ll do my best to help.',
      isUser: false,
    ));
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
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

@override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('AssistantTab'),
      color: const Color(0xFFF3F6F6), // soft teal-tinted background matching app theme
      child: Column(
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
          _buildInputBar(),
          const SizedBox(height: 70), // clearance for bottom nav bar
        ],
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
              color: AppColors.navyBlue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Islamic Assistant',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
              Text('Ask about prayer, fasting, Zakat & more',
                  style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.navyBlue.withValues(alpha: 0.55))),
            ],
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
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final prompt = _suggestedPrompts[index];
          return GestureDetector(
            onTap: () => _handleSend(prompt),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.midTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.midTeal.withValues(alpha: 0.3)),
              ),
              alignment: Alignment.center,
              child: Text(prompt,
                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.midTeal)),
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
          color: isUser ? AppColors.navyBlue : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser
              ? null
              : Border.all(color: AppColors.navyBlue.withValues(alpha: 0.15), width: 1.2),
          boxShadow: [
            BoxShadow(color: AppColors.navyBlue.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Text(
          message.text,
          style: GoogleFonts.inter(
            fontSize: 13,
            height: 1.5,
            color: isUser ? Colors.white : AppColors.navyBlue.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: AppColors.navyBlue.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.navyBlue),
                decoration: InputDecoration(
                  hintText: 'Ask a question...',
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.placeholder),
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
                decoration: const BoxDecoration(color: AppColors.navyBlue, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}