import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/logout_button.dart';

import '../../widgets/theme_toggle_button.dart';

class _ChatMessage {
  final String text;
  final bool isUser;
  _ChatMessage(this.text, this.isUser);
}

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
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

  String _welcomeMessage() => _lang == 'en'
      ? "Hi! I'm the VunaFlow Assistant. Ask me about applying for a loan, required documents, interest rates, or tracking your application."
      : 'Habari! Mimi ni Msaidizi wa VunaFlow. Niulize kuhusu kuomba mkopo, hati zinazohitajika, viwango vya riba, au ufuatiliaji wa maombi yako.';

  void _toggleLanguage() {
    setState(() {
      _lang = _lang == 'en' ? 'sw' : 'en';
      _messages.add(_ChatMessage(_welcomeMessage(), false));
    });
    _loadSuggestions();
    _scrollToBottom();
  }

  Future<void> _loadSuggestions() async {
    try {
      final res = await ApiService.get('/api/assistant/faqs', query: {'lang': _lang});
      setState(() => _suggestions = (res as List<dynamic>).take(5).toList());
    } catch (_) {}
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(text, true));
      _sending = true;
    });
    _controller.clear();
    _scrollToBottom();
    try {
      final res = await ApiService.post('/api/assistant/ask', body: {'message': text, 'lang': _lang});
      setState(() => _messages.add(_ChatMessage(res['answer'], false)));
    } catch (_) {
      final errText = _lang == 'en' ? "Sorry, I couldn't process that right now." : 'Samahani, sikuweza kuchakata hilo kwa sasa.';
      setState(() => _messages.add(_ChatMessage(errText, false)));
    } finally {
      setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VunaFlow Assistant'),
        actions: [
          const ThemeToggleButton(),
          TextButton.icon(
            onPressed: _toggleLanguage,
            icon: const Icon(Icons.language, size: 18, color: AppColors.textSecondary),
            label: Text(_lang == 'en' ? 'English' : 'Kiswahili', style: const TextStyle(color: AppColors.textSecondary)),
          ),
          const LogoutButton(),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, i) {
                    final m = _messages[i];
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    return Align(
                      alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        constraints: const BoxConstraints(maxWidth: 480),
                        decoration: BoxDecoration(
                          color: m.isUser
                              ? (isDark ? const Color(0xFF1B4D33) : AppColors.primary)
                              : (isDark ? const Color(0xFF14241B) : Colors.white),
                          borderRadius: BorderRadius.circular(16),
                          border: m.isUser ? null : Border.all(color: isDark ? const Color(0xFF223C2D) : AppColors.border),
                        ),
                        child: Text(
                          m.text,
                          style: TextStyle(
                            color: m.isUser ? Colors.white : (isDark ? const Color(0xFFF4F6F0) : AppColors.textPrimary),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_suggestions.isNotEmpty)
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => ActionChip(
                      label: Text(_suggestions[i]['question']),
                      onPressed: () => _send(_suggestions[i]['question']),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(hintText: _lang == 'en' ? 'Type your question...' : 'Andika swali lako...'),
                        onSubmitted: _sending ? null : _send,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _sending ? null : () => _send(_controller.text),
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
