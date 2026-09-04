import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../widgets/logout_button.dart';
import '../../widgets/theme_toggle_button.dart';

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  _ChatMessage(this.text, this.isUser, {DateTime? timestamp}) : timestamp = timestamp ?? DateTime.now();
}

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> with TickerProviderStateMixin {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  List<dynamic> _suggestions = [];
  bool _sending = false;
  String _lang = 'en';

  @override
  void initState() {
    super.initState();
    _messages.add(_ChatMessage(_welcomeMessage(), false));
    _loadSuggestions();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _welcomeMessage() => _lang == 'en'
      ? "Hello! I'm your VunaFlow AI Assistant. I can help you with agricultural loans, document requirements, interest calculations, or checking your repayment status. What can I help you with today?"
      : 'Habari! Mimi ni Msaidizi wako wa AI wa VunaFlow. Ninaweza kukusaidia kuhusu mikopo ya kilimo na mifugo, mahitaji ya hati, hesabu ya riba, au kuangalia hali ya marejesho yako. Nawezaje kukusaidia leo?';

  void _toggleLanguage() {
    setState(() {
      _lang = _lang == 'en' ? 'sw' : 'en';
      _messages.add(_ChatMessage(_welcomeMessage(), false));
    });
    _loadSuggestions();
    _scrollToBottom();
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _messages.add(_ChatMessage(_welcomeMessage(), false));
    });
  }

  Future<void> _loadSuggestions() async {
    try {
      final res = await ApiService.get('/api/assistant/faqs', query: {'lang': _lang});
      if (mounted) {
        setState(() => _suggestions = (res as List<dynamic>).take(5).toList());
      }
    } catch (_) {}
  }

  Future<void> _send(String text) async {
    final query = text.trim();
    if (query.isEmpty || _sending) return;

    setState(() {
      _messages.add(_ChatMessage(query, true));
      _sending = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final res = await ApiService.post('/api/assistant/ask', body: {'message': query, 'lang': _lang});
      if (mounted) {
        setState(() => _messages.add(_ChatMessage(res['answer']?.toString() ?? '', false)));
      }
    } catch (_) {
      if (mounted) {
        final errText = _lang == 'en'
            ? "I'm having trouble connecting to the server. Please check your connection and try again."
            : 'Samahani, kuna tatizo la kuunganisha na seva. Tafadhali jaribu tena baadae.';
        setState(() => _messages.add(_ChatMessage(errText, false)));
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C1610) : const Color(0xFFF9F8F5);
    final cardBg = isDark ? const Color(0xFF14241B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF223C2D) : const Color(0xFFE5E7EB);
    final textTitle = isDark ? const Color(0xFFF4F6F0) : const Color(0xFF1F2937);
    final textSub = isDark ? const Color(0xFF9EBAA9) : const Color(0xFF6B7280);
    final userBubbleBg = isDark ? const Color(0xFF19442C) : const Color(0xFF133826);
    final aiBubbleBg = isDark ? const Color(0xFF14231A) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F1B14) : const Color(0xFF133826),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 17),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'VunaFlow AI',
                    style: GoogleFonts.publicSans(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF34D399))),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Online · Agrifinance Advisor',
                          style: GoogleFonts.publicSans(fontSize: 10.5, color: const Color(0xFFD1FAE5)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Compact Language switcher button
          IconButton(
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.translate, size: 14, color: Color(0xFFD4AF37)),
                const SizedBox(width: 2),
                Text(_lang == 'en' ? 'EN' : 'SW', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            ),
            tooltip: 'Switch Language',
            onPressed: _toggleLanguage,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (val) {
              if (val == 'clear') _clearChat();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18),
                    SizedBox(width: 8),
                    Text('Clear Conversation'),
                  ],
                ),
              ),
            ],
          ),
          const ThemeToggleButton(),
          const LogoutButton(),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            children: [
              // Message Stream
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  itemCount: _messages.length + (_sending ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == _messages.length && _sending) {
                      return _buildTypingIndicator(isDark, aiBubbleBg, borderCol, textSub);
                    }
                    final m = _messages[i];
                    return _buildMessageRow(m, isDark, userBubbleBg, aiBubbleBg, borderCol, textTitle);
                  },
                ),
              ),

              // Suggestion Pills
              if (_suggestions.isNotEmpty && !_sending)
                Container(
                  height: 40,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final q = _suggestions[i]['question']?.toString() ?? '';
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _send(q),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF162B20) : const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isDark ? const Color(0xFF234B36) : const Color(0xFFC8E6C9)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF10B981)),
                                const SizedBox(width: 6),
                                Text(
                                  q,
                                  style: GoogleFonts.publicSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFFD1FAE5) : const Color(0xFF133826),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // Modern ChatGPT-Style Input Bar
              Container(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                decoration: BoxDecoration(
                  color: bg,
                ),
                child: SafeArea(
                  top: false,
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: borderCol, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            maxLines: 4,
                            minLines: 1,
                            textCapitalization: TextCapitalization.sentences,
                            style: GoogleFonts.publicSans(fontSize: 14.5, color: textTitle),
                            decoration: InputDecoration(
                              hintText: _lang == 'en' ? 'Ask anything about loans, repayment...' : 'Uliza chochote kuhusu mikopo, marejesho...',
                              hintStyle: GoogleFonts.publicSans(fontSize: 13.5, color: textSub),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                            ),
                            onSubmitted: _sending ? null : _send,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            onPressed: _sending ? null : () => _send(_controller.text),
                            icon: _sending
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageRow(
    _ChatMessage m,
    bool isDark,
    Color userBubbleBg,
    Color aiBubbleBg,
    Color borderCol,
    Color textTitle,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: m.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!m.isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 10, top: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
            ),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: m.text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
                );
              },
              child: Container(
                constraints: const BoxConstraints(maxWidth: 580),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: m.isUser ? userBubbleBg : aiBubbleBg,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(m.isUser ? 18 : 4),
                    bottomRight: Radius.circular(m.isUser ? 4 : 18),
                  ),
                  border: m.isUser ? null : Border.all(color: borderCol),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      m.text,
                      style: GoogleFonts.publicSans(
                        fontSize: 14,
                        height: 1.45,
                        color: m.isUser ? Colors.white : textTitle,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (m.isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(left: 10, top: 2),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF223C2D) : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.person_rounded,
                color: isDark ? const Color(0xFF9EBAA9) : const Color(0xFF4B5563),
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(bool isDark, Color aiBubbleBg, Color borderCol, Color textSub) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: aiBubbleBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: borderCol),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(isDark ? const Color(0xFF34D399) : const Color(0xFF10B981)),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _lang == 'en' ? 'Thinking...' : 'Inafikiri...',
                  style: GoogleFonts.publicSans(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: textSub,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
