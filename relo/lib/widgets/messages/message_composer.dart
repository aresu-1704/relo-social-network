import 'dart:io';
import 'package:flutter/material.dart';
import 'package:relo/widgets/messages/voice_recorder.dart';
import 'package:relo/widgets/messages/media_picker_sheet.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:relo/utils/show_notification.dart';
import 'package:relo/utils/permission_util.dart';

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
  bool _hasText = false;

  @override
  void initState() {
    super.initState();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() => _activeInput = null);
      }
    });

    _textController.addListener(() {
      final hasText = _textController.text.trim().isNotEmpty;
      // 🔧 chỉ gọi setState khi trạng thái thay đổi thật sự, tránh rebuild TextField
      if (hasText != _hasText) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _hasText = hasText);
        });
      }
    });
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    widget.onSend({'type': 'text', 'text': text});
    _textController.clear();

    // Giữ focus để người dùng gõ tiếp
    FocusScope.of(context).requestFocus(_focusNode);
  }

  void _toggleInput(String type) {
    if (_activeInput == type) {
      setState(() => _activeInput = null);
    } else {
      if (_focusNode.hasFocus) _focusNode.unfocus();
      setState(() => _activeInput = type);
    }
  }

  Future<void> _pickAndSendFiles() async {
    try {
      final isStorageAllowed = await PermissionUtils.ensureStoragePermission(
        context,
      );
      if (!isStorageAllowed) return;

      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result != null && result.files.isNotEmpty) {
        for (var file in result.files) {
          if (file.path == null) continue;
          final pickedFile = File(file.path!);
          final sizeInMB = pickedFile.lengthSync() / (1024 * 1024);

          if (sizeInMB > 150) {
            ShowNotification.showCustomAlertDialog(
              context,
              message: 'Tệp "${file.name}" vượt quá giới hạn 150MB',
            );
            continue;
          }

          widget.onSend({'type': 'file', 'path': pickedFile.path});
        }
      }
    } catch (e) {
      ShowNotification.showCustomAlertDialog(
        context,
        message: 'Đã xảy ra lỗi khi chọn tệp: $e',
      );
    }
  }

  void _onFilesPicked(List<File> files) {
    widget.onSend({
      'type': 'media',
      'paths': files.map((f) => f.path).toList(),
    });
    setState(() => _activeInput = null);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
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
            child: Row(
              children: [
                if (!_hasText)
                  IconButton(
                    icon: Icon(
                      _activeInput == 'gallery'
                          ? Icons.keyboard
                          : Icons.photo_outlined,
                      color: Colors.grey,
                    ),
                    onPressed: () => _toggleInput('gallery'),
                  ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    autocorrect: true,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                      hintText: 'Tin nhắn',
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: _hasText
                      ? IconButton(
                          key: const ValueKey('send'),
                          icon: const Icon(
                            Icons.send_rounded,
                            color: Color(0xFF7A2FC0),
                          ),
                          onPressed: _sendMessage,
                        )
                      : Row(
                          key: const ValueKey('actions'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                              icon: Icon(
                                LucideIcons.paperclip,
                                color: Colors.grey,
                              ),
                              onPressed: _pickAndSendFiles,
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),

          if (_activeInput == 'gallery')
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.45,
              child: MediaPickerSheet(onPicked: _onFilesPicked),
            ),
          if (_activeInput == 'voice')
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.45,
              child: VoiceRecorderWidget(
                onSend: (path) {
                  widget.onSend({'type': 'audio', 'path': path});
                  setState(() => _activeInput = null);
                },
              ),
            ),
        ],
      ),
    );
  }
}
