import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:relo/utils/show_notification.dart';
import 'package:relo/utils/permision_util.dart';

class VoiceRecorderWidget extends StatefulWidget {
  final void Function(String path) onSend;
  const VoiceRecorderWidget({super.key, required this.onSend});

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();

  bool _isRecording = false;
  bool _isRecorded = false;
  bool _isPlaying = false;

  String? _path;
  Timer? _timer;
  int _seconds = 0;
  double _amplitude = 0.0;

  @override
  void initState() {
    super.initState();
    _initRecorder();
    _player.openPlayer();
  }

  Future<void> _initRecorder() async {
    await Permission.microphone.request();
    await _recorder.openRecorder();
  }

  Future<void> _startRecording() async {
    try {
      final micAllowed = await PermissionUtils.ensureMicroPermission(context);
      if (!micAllowed) return;

      final dir = await getTemporaryDirectory();
      _path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';

      await _recorder.startRecorder(toFile: _path!, codec: Codec.aacADTS);

      // Timer cập nhật biên độ sóng
      _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        setState(() {
          _amplitude =
              (0.3 + (0.7 * (DateTime.now().millisecond % 1000) / 1000));
        });
      });

      // Timer đếm thời gian
      Timer.periodic(const Duration(seconds: 1), (t) {
        if (!_isRecording) {
          t.cancel();
        } else {
          setState(() => _seconds++);
        }
      });

      setState(() {
        _isRecording = true;
        _isRecorded = false;
      });
    } catch (e) {
      await ShowNotification.showCustomAlertDialog(
        context,
        message: "Không thể bắt đầu ghi âm: $e",
      );
      if (context.mounted) Navigator.pop(context);
    }
  }

  Future<void> _stopRecording() async {
    await _recorder.stopRecorder();
    _timer?.cancel();
    setState(() {
      _isRecording = false;
      _isRecorded = true;
      _amplitude = 0;
    });
  }

  Future<void> _togglePlay() async {
    if (_path == null) return;
    if (_seconds < 1) {
      await ShowNotification.showCustomAlertDialog(
        context,
        message: "Ghi âm quá ngắn, vui lòng thử lại",
      );
      return;
    }

    if (_isPlaying) {
      await _player.stopPlayer();
      setState(() => _isPlaying = false);
    } else {
      await _player.startPlayer(
        fromURI: _path!,
        codec: Codec.aacADTS,
        whenFinished: () {
          setState(() => _isPlaying = false);
        },
      );
      setState(() => _isPlaying = true);
    }
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _player.closePlayer();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isRecorded) {
          final result = await ShowNotification.showConfirmDialog(
            context,
            title: 'Hủy bỏ bản ghi ?',
            cancelText: 'Quay lại',
            confirmText: 'Xác nhận',
            confirmColor: Color(0xFF7A2FC0),
          );
          ;
          if (result == true) {
            setState(() {
              _isRecorded = false;
              _path = null;
              _seconds = 0;
            });
            return true;
          }
          return false;
        }
        return true;
      },
      child: Container(
        width: double.infinity,
        height: 240,
        padding: const EdgeInsets.all(25),
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Nhấn để bắt đầu ghi âm',
                style: TextStyle(
                  color: Color(0xFF7A2FC0),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 18),

              // 🔊 Nếu đang ghi thì hiển thị sóng âm, ngược lại hiển thị nút mic
              if (_isRecording)
                _buildWaveform()
              else
                CircleAvatar(
                  radius: 40,
                  backgroundColor: _isRecording
                      ? const Color(0xFF7A2FC0)
                      : Colors.grey[300],
                  child: IconButton(
                    iconSize: 36,
                    icon: const Icon(Icons.mic, color: Colors.white),
                    onPressed: _startRecording,
                  ),
                ),

              const SizedBox(height: 12),

              if (_isRecording)
                Text(
                  _formatDuration(_seconds),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7A2FC0),
                  ),
                ),

              if (_isRecorded) _buildRecordedControls(context),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ Widget hiển thị sóng âm ngang màn hình
  Widget _buildWaveform() {
    return GestureDetector(
      onTap: _stopRecording,
      child: Container(
        height: 70,
        width: 220,
        decoration: BoxDecoration(
          color: const Color(0xFF7A2FC0).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              20,
              (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  width: 4,
                  height: (10 + (_amplitude * 40 * (i.isEven ? 1.5 : 0.8))),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7A2FC0),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordedControls(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Phát / Tạm dừng
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isPlaying
                  ? const Color(0xFF7A2FC0)
                  : Colors.grey[300],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: _isPlaying ? Colors.white : const Color(0xFF7A2FC0),
            ),
            label: Text(
              _isPlaying ? "Dừng" : "Phát",
              style: TextStyle(
                color: _isPlaying ? Colors.white : const Color(0xFF7A2FC0),
              ),
            ),
            onPressed: _togglePlay,
          ),
        ),
        const SizedBox(width: 8),

        // Gửi
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7A2FC0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.send, color: Colors.white),
            label: const Text("Gửi", style: TextStyle(color: Colors.white)),
            onPressed: () async {
              if (_seconds < 1) {
                await ShowNotification.showCustomAlertDialog(
                  context,
                  message: "Ghi âm quá ngắn, vui lòng thử lại",
                );
                return;
              }
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

        // Hủy
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[300],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.cancel, color: Color(0xFF7A2FC0)),
            label: const Text(
              "Hủy",
              style: TextStyle(color: Color(0xFF7A2FC0)),
            ),
            onPressed: () async {
              final result = await ShowNotification.showConfirmDialog(context);
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
    );
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
