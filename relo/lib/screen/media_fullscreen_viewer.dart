import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:extended_image/extended_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:relo/utils/show_notification.dart';
import 'package:relo/utils/permision_util.dart';

class MediaFullScreenViewer extends StatefulWidget {
  final List<String> mediaUrls;
  final int initialIndex;

  const MediaFullScreenViewer({
    super.key,
    required this.mediaUrls,
    required this.initialIndex,
  });

  @override
  State<MediaFullScreenViewer> createState() => _MediaFullScreenViewerState();
}

class _MediaFullScreenViewerState extends State<MediaFullScreenViewer> {
  late PageController _pageController;
  late int _currentIndex;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  bool _isVideo(String url) {
    final ext = url.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv'].contains(ext);
  }

  Future<void> _downloadCurrentMedia() async {
    final url = widget.mediaUrls[_currentIndex];

    // Nếu là file local thì không tải
    if (!url.startsWith('http')) {
      await ShowNotification.showToast(context, 'Tệp này đã nằm trong máy rồi');
      return;
    }

    setState(() => _isDownloading = true);

    try {
      final isStorageAllowed = await PermissionUtils.ensureStoragePermission(
        context,
      );
      if (!isStorageAllowed) return;

      final dir = Platform.isAndroid
          ? Directory('/storage/emulated/0/Download')
          : await getApplicationDocumentsDirectory();

      final fileName = url.split('/').last;
      final filePath = '${dir.path}/$fileName';

      final dio = Dio();
      await dio.download(url, filePath);

      if (!mounted) return;
      setState(() => _isDownloading = false);
      await ShowNotification.showToast(context, 'Đã tải xuống');
    } catch (e) {
      setState(() => _isDownloading = false);
      debugPrint('Download error: $e');
      await ShowNotification.showToast(context, 'Tải xuống thất bại');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.mediaUrls.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) {
              final url = widget.mediaUrls[index];
              final isVideo = _isVideo(url);

              return Center(
                child: Hero(
                  tag: url,
                  child: isVideo
                      ? _VideoViewer(url: url)
                      : _ImageViewer(url: url),
                ),
              );
            },
          ),

          // Nút quay lại
          Positioned(
            top: 40,
            left: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(30),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Nút tải xuống
          Positioned(
            top: 40,
            right: 20,
            child: _isDownloading
                ? const CircularProgressIndicator(color: Colors.white)
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.download,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: _downloadCurrentMedia,
                    ),
                  ),
          ),

          // Hiển thị vị trí ảnh/video
          Positioned(
            bottom: 40,
            child: Text(
              "${_currentIndex + 1}/${widget.mediaUrls.length}",
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ảnh
class _ImageViewer extends StatelessWidget {
  final String url;
  const _ImageViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    final isNetwork = url.startsWith('http');
    final path = url.startsWith('file://')
        ? url.replaceFirst('file://', '')
        : url;

    return ExtendedImage(
      image: isNetwork
          ? ExtendedNetworkImageProvider(url)
          : ExtendedFileImageProvider(File(path)),
      fit: BoxFit.contain,
      mode: ExtendedImageMode.gesture,
    );
  }
}

/// Video
class _VideoViewer extends StatefulWidget {
  final String url;
  const _VideoViewer({required this.url});

  @override
  State<_VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<_VideoViewer> {
  late VideoPlayerController _controller;
  bool _showControls = true;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    final isNetwork = widget.url.startsWith('http');
    final path = widget.url.startsWith('file://')
        ? widget.url.replaceFirst('file://', '')
        : widget.url;

    _controller = isNetwork
        ? VideoPlayerController.network(widget.url)
        : VideoPlayerController.file(File(path));

    _controller.initialize().then((_) {
      if (mounted) setState(() => _isReady = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _showControls = !_showControls),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_isReady)
            AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            )
          else
            Container(
              color: Colors.grey.shade900,
              width: double.infinity,
              height: double.infinity,
            ),
          if (_showControls)
            IconButton(
              icon: Icon(
                _controller.value.isPlaying
                    ? Icons.pause_circle
                    : Icons.play_circle,
                color: Colors.white,
                size: 70,
              ),
              onPressed: _togglePlayPause,
            ),
        ],
      ),
    );
  }
}
