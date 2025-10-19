import 'package:flutter/material.dart';
import 'package:relo/widgets/voice_recorder.dart';

class MessageComposer extends StatelessWidget {
  final void Function(Map<String, dynamic> content) onSend;

  const MessageComposer({super.key, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final textController = TextEditingController();

    void sendMessage() {
      if (textController.text.trim().isEmpty) return;
      final content = {'type': 'text', 'content': textController.text.trim()};
      textController.clear();
      onSend(content);
    }

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, -1),
              blurRadius: 2,
              color: Colors.grey,
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.emoji_emotions_outlined, color: Color(0xFF7C3AED)),
            const SizedBox(width: 8),
            const Icon(Icons.photo_outlined, color: Color(0xFF7C3AED)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: textController,
                decoration: const InputDecoration.collapsed(
                  hintText: 'Tin nhắn',
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.mic, color: Color(0xFF7C3AED)),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.white,
                  isDismissible: false,
                  enableDrag: false,
                  builder: (_) => VoiceRecorderWidget(
                    onSend: (path) {
                      Navigator.pop(context);
                      final content = {'type': 'audio', 'content': path};
                      onSend(content);
                    },
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Color(0xFF7C3AED)),
              onPressed: sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}
