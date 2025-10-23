import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:relo/screen/review_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isRearCamera = true;
  bool _flashOn = false;
  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _timer;
  String _mode = "photo"; // 'photo' hoặc 'video'
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _showAlertDialog(String message) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (mounted) Navigator.pop(context);
  }

  Future<void> _initCamera() async {
    try {
      final cameraStatus = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();

      if (!cameraStatus.isGranted || !micStatus.isGranted) {
        await _showAlertDialog("Cần quyền camera và micro để chụp/quay.");
        return;
      }

      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        await _showAlertDialog("Không tìm thấy camera nào trên thiết bị này.");
        return;
      }

      _controller = CameraController(
        _isRearCamera ? _cameras!.first : _cameras!.last,
        ResolutionPreset.high,
        enableAudio: true,
      );

      await _controller!.initialize();
      await _controller!.setFlashMode(FlashMode.off);
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      await _showAlertDialog("Không thể khởi tạo camera: $e");
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    // Nếu đang bật flash, tắt trước khi đổi
    if (_flashOn) {
      await _controller?.setFlashMode(FlashMode.off);
      _flashOn = false;
    }

    _isRearCamera = !_isRearCamera;
    await _controller?.dispose();
    await _initCamera();

    // Cập nhật UI
    if (mounted) setState(() {});
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    _flashOn = !_flashOn;
    await _controller!.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
    setState(() {});
  }

  Future<void> _capturePhoto() async {
    if (_isCapturing || !_controller!.value.isInitialized) return;

    setState(() => _isCapturing = true); // ✅ cập nhật UI ngay

    try {
      // 🔥 Tắt flash trước khi rời màn hình
      if (_flashOn) {
        await _controller!.setFlashMode(FlashMode.off);
        _flashOn = false;
        setState(() {}); // cập nhật lại icon flash
      }

      final XFile file = await _controller!.takePicture();
      if (!mounted) return;

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReviewScreen(file: File(file.path), isVideo: false),
        ),
      );

      if (result != null && result is File) {
        Navigator.pop(context, result);
      }
    } catch (e) {
      debugPrint("Error capturing photo: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Lỗi chụp ảnh: $e")));
    } finally {
      if (mounted) setState(() => _isCapturing = false); // ✅ reset UI
    }
  }

  Future<void> _toggleVideoRecording() async {
    if (!_controller!.value.isInitialized) return;

    if (_isRecording) {
      final XFile file = await _controller!.stopVideoRecording();
      _timer?.cancel();
      setState(() {
        _isRecording = false;
        _recordDuration = 0;
      });

      // 🔥 Tắt flash khi dừng quay trước khi rời màn hình
      if (_flashOn) {
        await _controller!.setFlashMode(FlashMode.off);
        _flashOn = false;
        setState(() {});
      }

      if (!mounted) return;
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReviewScreen(file: File(file.path), isVideo: true),
        ),
      );

      if (result != null && result is File) {
        Navigator.pop(context, result);
      }
    } else {
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordDuration = 0;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _recordDuration++);
      });
    }
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  void dispose() {
    _controller?.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: CameraPreview(_controller!)),

          // Mũi tên quay lại
          Positioned(
            top: 40,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),

          // Hiển thị thời gian khi quay
          if (_isRecording)
            Positioned(
              top: 40,
              right: 20,
              child: Row(
                children: [
                  const Icon(
                    Icons.fiber_manual_record,
                    color: Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatDuration(_recordDuration),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),

          // Nút điều khiển
          Positioned(
            bottom: 130,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _toggleFlash,
                  icon: Icon(
                    _flashOn ? Icons.flash_on : Icons.flash_off,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 40),
                GestureDetector(
                  onTap: _isCapturing
                      ? null
                      : (_mode == "photo"
                            ? _capturePhoto
                            : _toggleVideoRecording),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _isRecording
                          ? Colors.red
                          : (_mode == "photo"
                                ? Colors.white
                                : Colors.redAccent),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white70, width: 3),
                    ),
                    child: Center(
                      child: _isCapturing
                          ? const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.black87,
                              ),
                            )
                          : Icon(
                              _mode == "photo"
                                  ? Icons.camera_alt
                                  : (_isRecording
                                        ? Icons.stop
                                        : Icons.videocam),
                              color: _isRecording
                                  ? Colors.white
                                  : (_mode == "photo"
                                        ? Colors.black
                                        : Colors.white),
                              size: 32,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 40),
                IconButton(
                  onPressed: _toggleCamera,
                  icon: const Icon(
                    Icons.cameraswitch,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ],
            ),
          ),

          // Thanh chọn chế độ
          Positioned(
            bottom: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildModeButton("photo", "Ảnh"),
                const SizedBox(width: 30),
                _buildModeButton("video", "Video"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(String mode, String label) {
    final bool active = _mode == mode;
    return GestureDetector(
      onTap: () {
        if (_isRecording) return;
        setState(() => _mode = mode);
      },
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : Colors.white70,
          fontSize: 18,
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
          decoration: active ? TextDecoration.underline : TextDecoration.none,
        ),
      ),
    );
  }
}
