import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

class VoiceRecorderWidget extends StatefulWidget {
  final void Function(String path) onSend;
  const VoiceRecorderWidget({super.key, required this.onSend});
  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecording = false;
  bool _isRecorded = false;
  String? _path;
  Timer? _timer;
  int _seconds = 0;
  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    await Permission.microphone.request();
    await _recorder.openRecorder();
  }

  Future<void> _startRecording() async {
    final dir = await getTemporaryDirectory();
    _path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';
    await _recorder.startRecorder(toFile: _path!, codec: Codec.aacADTS);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds++);
    });
    setState(() {
      _isRecording = true;
      _isRecorded = false;
    });
  }

  Future<void> _stopRecording() async {
    await _recorder.stopRecorder();
    _timer?.cancel();
    setState(() {
      _isRecording = false;
      _isRecorded = true;
    });
  }

  Future<void> _playRecording() async {
    if (_path != null) {
      final player = FlutterSoundPlayer();
      await player.openPlayer();
      await player.startPlayer(
        fromURI: _path!,
        codec: Codec.aacADTS,
        whenFinished: () async {
          await player.closePlayer();
        },
      );
    }
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isRecorded) {
          final result = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 50, 0),
              content: const Text(
                "Xác nhận?",
                textAlign: TextAlign.left, // ✅ căn trái
                style: TextStyle(fontSize: 20),
              ),
              actionsPadding: EdgeInsets.zero,
              actions: [
                SizedBox(height: 15),
                const Divider(height: 1, thickness: 1), // ✅ gạch ngang trên nút
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment:
                        MainAxisAlignment.end, // ✅ căn phải 2 nút
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text(
                          "Quay lại",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 3), // khoảng cách giữa 2 nút
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          "Xóa ghi âm",
                          style: TextStyle(
                            color: Color.fromARGB(255, 165, 85, 240),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
          if (result == true) {
            setState(() {
              _isRecorded = false;
              _path = null;
              _seconds = 0;
            });
            return true; // cho phép pop
          }
          return false; // chặn pop
        }
        return true; // nếu chưa ghi âm, cho phép pop
      },
      child: Container(
        width: double.infinity,
        height: 240,
        padding: const EdgeInsets.all(25),
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Nhấn để bắt đầu ghi âm',
              style: TextStyle(
                color: Color.fromARGB(255, 165, 85, 240),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            // Hiển thị thời gian và nút mic tròn
            CircleAvatar(
              radius: 40,
              backgroundColor: _isRecording
                  ? Color.fromARGB(255, 165, 85, 240)
                  : Colors.grey[300],
              child: IconButton(
                iconSize: 36,
                icon: Icon(
                  _isRecording ? Icons.stop : Icons.mic,
                  color: Colors.white,
                ),
                onPressed: _isRecording ? _stopRecording : _startRecording,
              ),
            ),
            const SizedBox(height: 12),
            if (_isRecording)
              Text(
                _formatDuration(_seconds),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 165, 85, 240),
                ),
              ),
            if (_isRecorded)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Phát lại
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(
                        Icons.play_arrow,
                        color: Color.fromARGB(255, 165, 85, 240),
                      ),
                      label: const Text(
                        "Phát lại",
                        style: TextStyle(
                          color: Color.fromARGB(255, 165, 85, 240),
                        ),
                      ),
                      onPressed: _playRecording,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Gửi
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromARGB(255, 165, 85, 240),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.send, color: Colors.white),
                      label: const Text(
                        "Gửi",
                        style: TextStyle(color: Colors.white),
                      ),
                      onPressed: () {
                        if (_path != null) widget.onSend(_path!);
                        setState(() {
                          _isRecorded = false;
                          _path = null;
                          _seconds = 0;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Hủy với dialog xác nhận
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(
                        Icons.cancel,
                        color: Color.fromARGB(255, 165, 85, 240),
                      ),
                      label: const Text(
                        "Hủy",
                        style: TextStyle(
                          color: Color.fromARGB(255, 165, 85, 240),
                        ),
                      ),
                      onPressed: () async {
                        final result = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            contentPadding: const EdgeInsets.fromLTRB(
                              24,
                              20,
                              50,
                              0,
                            ),
                            content: const Text(
                              "Xác nhận?",
                              textAlign: TextAlign.left, // ✅ căn trái
                              style: TextStyle(fontSize: 20),
                            ),
                            actionsPadding: EdgeInsets.zero,
                            actions: [
                              SizedBox(height: 15),
                              const Divider(
                                height: 1,
                                thickness: 1,
                              ), // ✅ gạch ngang trên nút
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment:
                                      MainAxisAlignment.end, // ✅ căn phải 2 nút
                                  children: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text(
                                        "Quay lại",
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 3,
                                    ), // khoảng cách giữa 2 nút
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text(
                                        "Xóa ghi âm",
                                        style: TextStyle(
                                          color: Color.fromARGB(
                                            255,
                                            165,
                                            85,
                                            240,
                                          ),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                        if (result == true) {
                          setState(() {
                            _isRecorded = false;
                            _path = null;
                            _seconds = 0;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
