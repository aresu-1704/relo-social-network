// file: review_screen.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:relo/utils/edit_image.dart';
import 'package:video_player/video_player.dart';

class ReviewScreen extends StatefulWidget {
  final File file;
  final bool isVideo;

  const ReviewScreen({super.key, required this.file, required this.isVideo});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final _captureKey = GlobalKey();
  VideoPlayerController? _videoController;
  bool _editing = false;
  bool _isDownloading = false;
  bool _isDrawing = false;
  bool _isAddingText = false;
  final List<DrawnLine> _lines = [];
  DrawnLine? _currentLine;
  final List<TextOverlay> _texts = [];

  Color _selectedColor = Colors.redAccent;
  final double _strokeWidth = 4.0;

  void _downloadFile() async {
    setState(() => _isDownloading = true);
    try {
      final dir =
          await getExternalStorageDirectory(); // Lưu vào thư mục Downloads/Android
      final fileName = widget.file.path.split('/').last;
      final newPath = '${dir!.path}/$fileName';
      final newFile = await widget.file.copy(newPath);

      _showToast(context, 'Đã tải xuống');
    } catch (e) {
      debugPrint("Error saving file: $e");
      _showToast(context, 'Lỗi khi tải xuống');
    } finally {
      setState(() => _isDownloading = false);
    }
  }

  void _showToast(BuildContext context, String msg) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 100, // cách đáy màn hình
        left: 50,
        right: 50,
        child: Material(
          color: Colors.transparent,
          child: AnimatedOpacity(
            opacity: 1.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                msg,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 2), () => overlayEntry.remove());
  }

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _videoController = VideoPlayerController.file(widget.file)
        ..initialize().then((_) {
          setState(() {});
          _videoController!.play();
          _videoController!.setLooping(true);
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    if (widget.isVideo) return; // Tạm thời không cho sửa video
    setState(() => _editing = !_editing);
  }

  void _onSend() async {
    // Nếu là video hoặc không có chỉnh sửa gì, gửi file gốc
    if (widget.isVideo || (_lines.isEmpty && _texts.isEmpty)) {
      Navigator.pop(context, widget.file);
      return;
    }

    // Chụp ảnh đã chỉnh sửa
    try {
      final boundary =
          _captureKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      // Lưu vào file tạm
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/edited_image.png').create();
      await file.writeAsBytes(pngBytes);

      // Quay lại và gửi file mới
      Navigator.pop(context, file);
    } catch (e) {
      debugPrint("Error capturing image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lỗi khi lưu ảnh đã chỉnh sửa.")),
      );
    }
  }

  void _toggleDraw() {
    setState(() {
      _isDrawing = !_isDrawing;
      _isAddingText = false;
    });
  }

  void _toggleText() {
    setState(() {
      _isAddingText = !_isAddingText;
      _isDrawing = false;
    });
  }

  void _onAddTextTap(TapUpDetails details) async {
    if (!_isAddingText) return;

    final text = await _showAddTextDialog();
    if (text != null && text.trim().isNotEmpty) {
      setState(() {
        _texts.add(
          TextOverlay(
            text: text.trim(),
            position: details.localPosition,
            color: _selectedColor,
          ),
        );
      });
    }
  }

  Future<String?> _showAddTextDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Text(
              "Thêm chữ lên ảnh",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: "Nhập nội dung...",
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF7C3AED),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text("Thêm", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _onPanStart(DragStartDetails details) {
    if (!_isDrawing) return;
    setState(() {
      _currentLine = DrawnLine(
        [details.localPosition],
        _selectedColor,
        _strokeWidth,
      );
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDrawing || _currentLine == null) return;
    setState(() => _currentLine!.points.add(details.localPosition));
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDrawing || _currentLine == null) return;
    setState(() {
      _lines.add(_currentLine!);
      _currentLine = null;
    });
  }

  void _clearDrawing() {
    setState(() {
      _lines.clear();
      _texts.clear();
    });
  }

  Future<void> _pickColor() async {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.white,
      Colors.purple,
    ];

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Chọn màu cọ"),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colors
              .map(
                (c) => GestureDetector(
                  onTap: () {
                    setState(() => _selectedColor = c);
                    Navigator.pop(context);
                  },
                  child: CircleAvatar(
                    backgroundColor: c,
                    radius: 20,
                    child: _selectedColor == c
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _toolButton(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: active ? Color(0xFF7C3AED) : Colors.white,
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: active ? Color(0xFF7C3AED) : Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!widget.isVideo)
            IconButton(
              onPressed: _toggleEdit,
              icon: Icon(
                _editing ? Icons.close : Icons.edit,
                color: Colors.white,
              ),
            ),
          IconButton(
            onPressed: _isDownloading
                ? null
                : _downloadFile, // vô hiệu khi loading
            icon: _isDownloading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Icon(Icons.download, color: Colors.white),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Vùng hiển thị media
          Center(
            child: RepaintBoundary(
              key: _captureKey,
              child: GestureDetector(
                onTapUp: _onAddTextTap,
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Hiển thị video hoặc ảnh
                    if (widget.isVideo)
                      _videoController != null &&
                              _videoController!.value.isInitialized
                          ? AspectRatio(
                              aspectRatio: _videoController!.value.aspectRatio,
                              child: VideoPlayer(_videoController!),
                            )
                          : const CircularProgressIndicator()
                    else
                      Image.file(widget.file, fit: BoxFit.contain),

                    // Lớp vẽ (chỉ cho ảnh)
                    if (!widget.isVideo)
                      CustomPaint(
                        painter: DrawingPainter(_lines, _currentLine, _texts),
                        size: Size.infinite,
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Nút Play/Pause cho video
          if (widget.isVideo && _videoController != null)
            GestureDetector(
              onTap: () {
                setState(() {
                  _videoController!.value.isPlaying
                      ? _videoController!.pause()
                      : _videoController!.play();
                });
              },
              child: Icon(
                _videoController!.value.isPlaying
                    ? Icons.pause_circle
                    : Icons.play_circle,
                color: Colors.white.withOpacity(0.7),
                size: 60,
              ),
            ),

          // Các nút điều khiển
          if (_editing)
            Positioned(
              bottom: 35,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _toolButton(
                      Icons.brush,
                      "Vẽ",
                      _toggleDraw,
                      active: _isDrawing,
                    ),
                    _toolButton(
                      Icons.text_fields,
                      "Chữ",
                      _toggleText,
                      active: _isAddingText,
                    ),
                    _toolButton(Icons.color_lens, "Màu", _pickColor),
                    _toolButton(Icons.delete_forever, "Xoá", _clearDrawing),
                  ],
                ),
              ),
            )
          else
            Positioned(
              bottom: 35,
              right: 20,
              child: FloatingActionButton(
                backgroundColor: const Color(0xFF7C3AED),
                onPressed: _onSend,
                child: const Icon(Icons.send, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
