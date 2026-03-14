import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/wavy_theme.dart';
import '../../chat/providers/chat_provider.dart';
import '../../auth/providers/auth_provider.dart';

class ChatPanel extends StatefulWidget {
  final String waveId;
  final VoidCallback onClose;

  const ChatPanel({super.key, required this.waveId, required this.onClose});

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    context.read<ChatProvider>().initialize(widget.waveId, auth.userId!);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    context.read<ChatProvider>().sendPublicMessage(text);
    _controller.clear();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().userId;

    return Container(
      color: WavyTheme.cardBackground,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            height: 56,
            decoration: const BoxDecoration(
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 3)],
            ),
            child: Row(
              children: [
                const Icon(Icons.send, color: WavyTheme.textPrimary, size: 18),
                const SizedBox(width: 8),
                Consumer<ChatProvider>(
                  builder: (_, chat, __) => Text(
                    '${chat.publicMessages.length} Mensajes',
                    style: const TextStyle(color: WavyTheme.textPrimary, fontWeight: FontWeight.w700),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.cancel, color: WavyTheme.textPrimary),
                ),
              ],
            ),
          ),
          // Messages
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (_, chat, __) {
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  itemCount: chat.publicMessages.length,
                  itemBuilder: (_, i) {
                    final msg = chat.publicMessages[i];
                    final isSelf = msg.userId == userId;
                    return _ChatBubble(message: msg, isSelf: isSelf);
                  },
                );
              },
            ),
          ),
          // Input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 3)],
            ),
            child: Row(
              children: [
                const Icon(Icons.emoji_emotions_outlined, color: WavyTheme.textSecondary, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: WavyTheme.textPrimary, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Escribe...',
                      hintStyle: TextStyle(color: WavyTheme.textSecondary),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _send,
                  icon: const Icon(Icons.send, size: 14),
                  label: const Text('ENVIAR', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
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

class _ChatBubble extends StatelessWidget {
  final Message message;
  final bool isSelf;

  const _ChatBubble({required this.message, required this.isSelf});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isSelf) _avatar(),
          const SizedBox(width: 6),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelf ? WavyTheme.accentRed : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(33),
                  topRight: const Radius.circular(33),
                  bottomLeft: Radius.circular(isSelf ? 33 : 0),
                  bottomRight: Radius.circular(isSelf ? 0 : 33),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.message,
                    style: TextStyle(
                      color: isSelf ? Colors.white : const Color(0xFF777777),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      color: isSelf ? Colors.white54 : const Color(0xFFCCCCCC),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          if (isSelf) _avatar(),
        ],
      ),
    );
  }

  Widget _avatar() {
    return Container(
      width: 30,
      height: 30,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xE6FFFFFF)),
      child: const ClipOval(child: Icon(Icons.person, size: 20, color: WavyTheme.textSecondary)),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
