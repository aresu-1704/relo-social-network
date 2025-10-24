import 'dart:io';
import 'package:flutter/material.dart';
import 'package:relo/widgets/voice_recorder.dart';
import 'package:relo/widgets/media_picker_sheet.dart';

class MessageComposer extends StatefulWidget {
  final void Function(Map<String, dynamic> content) onSend;

  const MessageComposer({super.key, required this.onSend});

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  String? _activeInput;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _activeInput = null; // ẩn phần dưới khi đang gõ
        });
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_textController.text.trim().isEmpty) return;
    final content = {'type': 'text', 'text': _textController.text.trim()};
    _textController.clear();
    widget.onSend(content);
    _focusNode.unfocus();
  }

  void _toggleInput(String type) {
    if (_activeInput == type) {
      setState(() => _activeInput = null);
    } else {
      // Ẩn bàn phím nếu đang mở
      if (_focusNode.hasFocus) _focusNode.unfocus();
      setState(() => _activeInput = type);
    }
  }

  void _onFilesPicked(List<File> files) {
    final content = {
      'type': 'media',
      'paths': files.map((f) => f.path).toList(),
    };
    widget.onSend(content);
    setState(() {
      _activeInput = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: const [
                BoxShadow(
                  offset: Offset(0, -1),
                  blurRadius: 2,
                  color: Colors.grey,
                ),
              ],
            ),
            child: _activeInput != null
                ? Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _activeInput = null;
                          });
                        },
                        icon: const Icon(Icons.arrow_back, color: Colors.grey),
                      ),
                      const SizedBox(width: 8),
                    ],
                  )
                : Row(
                    children: [
                      const Icon(
                        Icons.emoji_emotions_outlined,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          _activeInput == 'gallery'
                              ? Icons.keyboard
                              : Icons.photo_outlined,
                          color: Colors.grey,
                        ),
                        onPressed: () => _toggleInput('gallery'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          focusNode: _focusNode,
                          autofocus: false,
                          decoration: const InputDecoration.collapsed(
                            hintText: 'Tin nhắn',
                          ),
                          textCapitalization: TextCapitalization.sentences,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _activeInput == 'voice'
                              ? Icons.keyboard
                              : Icons.mic_none_rounded,
                          color: Colors.grey,
                        ),
                        onPressed: () => _toggleInput('voice'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: Colors.grey),
                        onPressed: _sendMessage,
                      ),
                    ],
                  ),
          ),

          // phần dưới cùng (gallery hoặc voice)
          if (_activeInput == 'gallery')
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.45,
              child: MediaPickerSheet(onPicked: _onFilesPicked),
            )
          else if (_activeInput == 'voice')
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.45,
              child: VoiceRecorderWidget(
                onSend: (path) {
                  final content = {'type': 'audio', 'path': path};
                  widget.onSend(content);
                  setState(() => _activeInput = null);
                },
              ),
            ),
        ],
      ),
    );
  }
}
