import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:relo/models/message.dart';
import 'package:relo/screen/media_fullscreen_viewer.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:relo/widgets/message_status.dart';

/// =================== GLOBAL CACHES ===================
class VideoThumbnailCache {
  VideoThumbnailCache._privateConstructor();
  static final VideoThumbnailCache instance =
      VideoThumbnailCache._privateConstructor();
  final Map<String, Uint8List> _cache = {};

  Uint8List? get(String url) => _cache[url];
  void set(String url, Uint8List bytes) => _cache[url] = bytes;
}

class ImageCacheGlobal {
  ImageCacheGlobal._private();
  static final ImageCacheGlobal instance = ImageCacheGlobal._private();
  final Map<String, ImageProvider> _cache = {};

  ImageProvider? get(String url) => _cache[url];
  void set(String url, ImageProvider provider) => _cache[url] = provider;
}

class ImageSizeCache {
  ImageSizeCache._private();
  static final ImageSizeCache instance = ImageSizeCache._private();
  final Map<String, Size> _cache = {};

  Size? get(String url) => _cache[url];
  void set(String url, Size size) => _cache[url] = size;
}

/// =================== MAIN WIDGET ===================
class MediaMessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool isLastFromMe;

  const MediaMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.isLastFromMe,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> mediaUrls = List<String>.from(
      message.content['urls'] ?? message.content['paths'] ?? [],
    );

    final timeString =
        "${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}";

    return Column(
      crossAxisAlignment: isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage:
                      (message.avatarUrl != null &&
                          message.avatarUrl!.isNotEmpty)
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 197, 197, 197),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      timeString,
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        if (isMe && isLastFromMe)
          Padding(
            padding: const EdgeInsets.only(top: 1, right: 0),
            child: MessageStatusWidget(message: message),
          ),
      ],
    );
  }

  Widget _buildMediaLayout(BuildContext context, List<String> mediaUrls) {
    if (mediaUrls.isEmpty) return const SizedBox();

    if (mediaUrls.length == 1) {
      final url = mediaUrls.first;
      final isVideo = _isVideo(url);
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              opaque: false,
              pageBuilder: (_, __, ___) =>
                  MediaFullScreenViewer(mediaUrls: mediaUrls, initialIndex: 0),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
            ),
          );
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            _SingleMediaView(url: url, isVideo: isVideo),
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
                  initialIndex: index,
                ),
                transitionsBuilder: (_, anim, __, child) =>
                    FadeTransition(opacity: anim, child: child),
              ),
            );
          },
          child: isVideo
              ? CachedVideoThumbnail(url: url)
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

/// =================== SINGLE MEDIA VIEW ===================
class _SingleMediaView extends StatelessWidget {
  final String url;
  final bool isVideo;

  const _SingleMediaView({required this.url, required this.isVideo});

  @override
  Widget build(BuildContext context) {
    const maxWidth = 280.0;

    if (isVideo) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: CachedVideoThumbnail(url: url),
        ),
      );
    }

    final cachedSize = ImageSizeCache.instance.get(url);
    if (cachedSize != null) {
      return _buildImageWithSize(cachedSize);
    }

    return FutureBuilder<Size>(
      future: _getImageSize(url),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          ImageSizeCache.instance.set(url, snapshot.data!);
          return _buildImageWithSize(snapshot.data!);
        }
        return _shimmerBox(width: maxWidth, height: 200);
      },
    );
  }

  Widget _buildImageWithSize(Size size) {
    const maxWidth = 280.0;
    const maxHeight = 400.0;
    double displayWidth, displayHeight;

    final aspectRatio = size.width / size.height;
    if (aspectRatio < 0.8) {
      displayHeight = maxHeight;
      displayWidth = maxHeight * aspectRatio;
    } else {
      displayWidth = maxWidth;
      displayHeight = maxWidth / aspectRatio;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: displayWidth,
      height: displayHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: _ImageThumbnail(url: url),
      ),
    );
  }

  Future<Size> _getImageSize(String url) async {
    final completer = Completer<Size>();
    final image = url.startsWith('http')
        ? Image.network(url)
        : Image.file(File(url));

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

/// =================== IMAGE THUMBNAIL ===================
class _ImageThumbnail extends StatelessWidget {
  final String url;

  const _ImageThumbnail({required this.url});

  @override
  Widget build(BuildContext context) {
    final isNetwork = url.startsWith('http');
    final cachedProvider = isNetwork
        ? ImageCacheGlobal.instance.get(url)
        : null;

    final ImageProvider imageProvider =
        cachedProvider ??
        (isNetwork ? NetworkImage(url) : FileImage(File(url)));

    if (isNetwork && cachedProvider == null) {
      ImageCacheGlobal.instance.set(url, imageProvider);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image(
        image: imageProvider,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(color: Colors.grey[300]),
          );
        },
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.error, color: Colors.redAccent),
      ),
    );
  }
}

/// =================== VIDEO THUMBNAIL ===================
class CachedVideoThumbnail extends StatefulWidget {
  final String url;

  const CachedVideoThumbnail({super.key, required this.url});

  @override
  State<CachedVideoThumbnail> createState() => _CachedVideoThumbnailState();
}

class _CachedVideoThumbnailState extends State<CachedVideoThumbnail>
    with AutomaticKeepAliveClientMixin {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    final cached = VideoThumbnailCache.instance.get(widget.url);
    if (cached != null) {
      setState(() => _bytes = cached);
      return;
    }

    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: widget.url,
        imageFormat: ImageFormat.PNG,
        maxWidth: 280,
        quality: 75,
      );
      if (!mounted) return;

      if (bytes != null) {
        VideoThumbnailCache.instance.set(widget.url, bytes);
      }

      setState(() => _bytes = bytes);
    } catch (_) {
      // ignore lỗi thumbnail
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_bytes == null) {
      return Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            _bytes!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.black38,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.play_arrow, color: Colors.white, size: 30),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
