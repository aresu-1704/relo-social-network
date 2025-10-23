import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:extended_image/extended_image.dart';
import 'package:shimmer/shimmer.dart';

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

/// Ảnh có shimmer khi loading
class _ImageViewer extends StatelessWidget {
  final String url;
  const _ImageViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    return ExtendedImage(
      image: url.startsWith('http')
          ? ExtendedNetworkImageProvider(url)
          : ExtendedFileImageProvider(File(url)),
      fit: BoxFit.contain,
      mode: ExtendedImageMode.gesture,
      loadStateChanged: (state) {
        switch (state.extendedImageLoadState) {
          case LoadState.loading:
            return Shimmer.fromColors(
              baseColor: Colors.grey.shade800,
              highlightColor: Colors.grey.shade600,
              child: Container(
                color: Colors.grey.shade900,
                width: double.infinity,
                height: double.infinity,
              ),
            );
          case LoadState.completed:
            return ExtendedRawImage(
              image: state.extendedImageInfo?.image,
              fit: BoxFit.contain,
            );
          case LoadState.failed:
            return const Center(
              child: Icon(Icons.error, color: Colors.redAccent, size: 50),
            );
        }
      },
      initGestureConfigHandler: (state) {
        return GestureConfig(
          minScale: 1.0,
          maxScale: 4.0,
          animationMinScale: 0.8,
          animationMaxScale: 4.5,
          speed: 1.0,
          inertialSpeed: 100.0,
          initialScale: 1.0,
          inPageView: true,
        );
      },
    );
  }
}

/// Video có hiệu ứng điều khiển mượt mà
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
    _controller = isNetwork
        ? VideoPlayerController.network(widget.url)
        : VideoPlayerController.file(File(widget.url));

    _controller.initialize().then((_) {
      setState(() => _isReady = true);
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
            Shimmer.fromColors(
              baseColor: Colors.grey.shade800,
              highlightColor: Colors.grey.shade600,
              child: Container(
                color: Colors.grey.shade900,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _showControls
                ? IconButton(
                    key: ValueKey(_controller.value.isPlaying),
                    icon: Icon(
                      _controller.value.isPlaying
                          ? Icons.pause_circle
                          : Icons.play_circle,
                      color: Colors.white,
                      size: 70,
                    ),
                    onPressed: _togglePlayPause,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
