import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:relo/models/message.dart';
import 'package:video_player/video_player.dart';
import 'package:extended_image/extended_image.dart';
import 'package:relo/screen/media_fullscreen_viewer.dart';

class MediaMessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;

  const MediaMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> mediaUrls = List<String>.from(
      message.content['urls'] ?? message.content['paths'] ?? [],
    );

    final timeString =
        "${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}";

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!isMe)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: CircleAvatar(
              radius: 16,
              backgroundImage:
                  (message.avatarUrl != null && message.avatarUrl!.isNotEmpty)
                  ? NetworkImage(message.avatarUrl!)
                  : const NetworkImage(
                      'https://images.squarespace-cdn.com/content/v1/54b7b93ce4b0a3e130d5d232/1519987020970-8IQ7F6Z61LLBCX85A65S/icon.png?format=1000w',
                    ),
            ),
          ),
        Flexible(
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: _buildMediaLayout(context, mediaUrls),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeString,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black87,
                      ),
                    ),
                    if (isMe &&
                        (message.status == 'pending' ||
                            message.status == 'failed')) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.status == 'pending'
                            ? Icons.access_time
                            : Icons.error_outline,
                        size: 13,
                        color: Colors.black54,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 5),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMediaLayout(BuildContext context, List<String> mediaUrls) {
    if (mediaUrls.isEmpty) return const SizedBox();

    // 🖼 Một ảnh hoặc video
    if (mediaUrls.length == 1) {
      final url = mediaUrls.first;
      final isVideo = _isVideo(url);

      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              opaque: false,
              pageBuilder: (_, __, ___) => MediaFullScreenViewer(
                mediaUrls: mediaUrls,
                initialIndex: mediaUrls.indexOf(url),
              ),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
            ),
          );
        },

        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: message.status == 'pending'
                  ? 0.5
                  : message.status == 'failed'
                  ? 0.7
                  : 1.0,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: _SingleMediaView(url: url, isVideo: isVideo),
              ),
            ),
            if (message.status == 'pending')
              const Positioned.fill(
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            if (message.status == 'failed')
              const Positioned.fill(
                child: Center(
                  child: Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: 30,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // 🧱 Nhiều ảnh
    return GridView.builder(
      itemCount: mediaUrls.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemBuilder: (context, index) {
        final url = mediaUrls[index];
        final isVideo = _isVideo(url);
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                opaque: false,
                pageBuilder: (_, __, ___) => MediaFullScreenViewer(
                  mediaUrls: mediaUrls,
                  initialIndex: mediaUrls.indexOf(url),
                ),
                transitionsBuilder: (_, anim, __, child) =>
                    FadeTransition(opacity: anim, child: child),
              ),
            );
          },

          child: isVideo
              ? _VideoThumbnail(url: url)
              : _ImageThumbnail(url: url),
        );
      },
    );
  }

  bool _isVideo(String url) {
    final ext = url.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv'].contains(ext);
  }
}

class _SingleMediaView extends StatelessWidget {
  final String url;
  final bool isVideo;

  const _SingleMediaView({required this.url, required this.isVideo});

  @override
  Widget build(BuildContext context) {
    final isNetwork = url.startsWith('http');
    const maxWidth = 280.0;
    const maxHeight = 400.0;

    return FutureBuilder<Size>(
      future: _getImageSize(url, isNetwork),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _shimmerBox(width: maxWidth, height: 200);
        }

        final imageSize = snapshot.data!;
        final aspectRatio = imageSize.width / imageSize.height;

        double displayWidth;
        double displayHeight;

        if (aspectRatio < 0.8) {
          displayHeight = maxHeight;
          displayWidth = maxHeight * aspectRatio;
        } else {
          displayWidth = maxWidth;
          displayHeight = maxWidth / aspectRatio;
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: displayWidth,
            height: displayHeight,
            child: isVideo
                ? _VideoThumbnail(url: url)
                : _ImageThumbnail(url: url),
          ),
        );
      },
    );
  }

  Future<Size> _getImageSize(String url, bool isNetwork) async {
    final completer = Completer<Size>();
    final image = isNetwork ? Image.network(url) : Image.file(File(url));

    image.image
        .resolve(const ImageConfiguration())
        .addListener(
          ImageStreamListener((info, _) {
            completer.complete(
              Size(info.image.width.toDouble(), info.image.height.toDouble()),
            );
          }),
        );
    return completer.future;
  }

  Widget _shimmerBox({required double width, required double height}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _ImageThumbnail extends StatelessWidget {
  final String url;

  const _ImageThumbnail({required this.url});

  @override
  Widget build(BuildContext context) {
    final isNetworkImage = url.startsWith('http');

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: isNetworkImage
          ? ExtendedImage.network(
              url,
              fit: BoxFit.cover,
              cache: true,
              loadStateChanged: (state) {
                if (state.extendedImageLoadState == LoadState.loading) {
                  return Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Container(color: Colors.grey[300]),
                  );
                }
                return null; // default display
              },
            )
          : Image.file(
              File(url),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.error, color: Colors.redAccent),
            ),
    );
  }
}

class _VideoThumbnail extends StatefulWidget {
  final String url;

  const _VideoThumbnail({required this.url});

  @override
  State<_VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<_VideoThumbnail> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    final isNetworkVideo = widget.url.startsWith('http');

    _controller = isNetworkVideo
        ? VideoPlayerController.network(widget.url)
        : VideoPlayerController.file(File(widget.url));

    _controller.initialize().then((_) => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_controller.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            )
          else
            Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(color: Colors.grey[300]),
            ),
          Container(color: Colors.black.withOpacity(0.3)),
          const Center(
            child: Icon(Icons.play_circle_fill, color: Colors.white, size: 40),
          ),
        ],
      ),
    );
  }
}
