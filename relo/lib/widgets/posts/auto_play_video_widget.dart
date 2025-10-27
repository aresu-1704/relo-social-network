import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

class AutoPlayVideoWidget extends StatefulWidget {
  final String videoUrl;
  final double height;
  final VoidCallback? onTap;

  const AutoPlayVideoWidget({
    super.key,
    required this.videoUrl,
    this.height = 300,
    this.onTap,
  });

  @override
  State<AutoPlayVideoWidget> createState() => _AutoPlayVideoWidgetState();
}

class _AutoPlayVideoWidgetState extends State<AutoPlayVideoWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showPlayButton = false;
  bool _isDisposed = false;
  double _currentVisibility = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      debugPrint('🎬 Initializing video: ${widget.videoUrl}');
      _controller = VideoPlayerController.network(widget.videoUrl);
      await _controller.initialize();
      _controller.setLooping(true);
      _controller.setVolume(0); // Mute by default for auto-play
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        debugPrint('✅ Video initialized successfully. Current visibility: ${(_currentVisibility * 100).toStringAsFixed(0)}%');
        
        // Auto-play if already visible (>= 50%)
        if (_currentVisibility >= 0.5) {
          debugPrint('🚀 Auto-playing video (already visible)');
          _controller.play();
          setState(() {
            _showPlayButton = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error initializing video: $e');
      if (mounted) {
        setState(() {
          _isInitialized = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller.dispose();
    super.dispose();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    // Always track visibility, even if not initialized yet
    _currentVisibility = info.visibleFraction;
    
    if (_isDisposed || !_isInitialized || !mounted) {
      debugPrint('⚠️ Skipping visibility change - disposed: $_isDisposed, initialized: $_isInitialized, mounted: $mounted');
      return;
    }

    try {
      debugPrint('👁️ Visibility changed: ${(info.visibleFraction * 100).toStringAsFixed(0)}%');
      
      // Auto-play when 50% or more of the video is visible
      if (info.visibleFraction >= 0.5) {
        if (!_controller.value.isPlaying) {
          debugPrint('▶️ Starting video playback');
          _controller.play();
          if (mounted && !_isDisposed) {
            setState(() {
              _showPlayButton = false;
            });
          }
        }
      } else {
        // Pause when not visible
        if (_controller.value.isPlaying) {
          debugPrint('⏸️ Pausing video');
          _controller.pause();
          if (mounted && !_isDisposed) {
            setState(() {
              _showPlayButton = true;
            });
          }
        }
      }
    } catch (e) {
      // Ignore errors from disposed controllers
      debugPrint('❌ Error in visibility change: $e');
    }
  }

  void _togglePlayPause() {
    if (_isDisposed || !mounted || !_isInitialized) return;
    
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _showPlayButton = true;
      } else {
        _controller.play();
        _showPlayButton = false;
      }
    });
  }

  void _toggleMute() {
    if (_isDisposed || !mounted || !_isInitialized) return;
    
    setState(() {
      if (_controller.value.volume > 0) {
        _controller.setVolume(0);
      } else {
        _controller.setVolume(1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('video_${widget.videoUrl}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: GestureDetector(
        onTap: widget.onTap ?? _togglePlayPause,
        child: Container(
          height: widget.height,
          color: Colors.black,
          child: _isInitialized
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: VideoPlayer(_controller),
                      ),
                    ),
                    
                    // Play/Pause button overlay (shows briefly when paused)
                    if (_showPlayButton || !_controller.value.isPlaying)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            _controller.value.isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                            color: Colors.white,
                            size: 50,
                          ),
                          onPressed: _togglePlayPause,
                        ),
                      ),
                    
                    // Mute/Unmute button (bottom right)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          icon: Icon(
                            _controller.value.volume > 0
                                ? Icons.volume_up
                                : Icons.volume_off,
                            color: Colors.white,
                            size: 24,
                          ),
                          onPressed: _toggleMute,
                        ),
                      ),
                    ),
                    
                    // Video indicator (bottom left)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.videocam, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Video',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
        ),
      ),
    );
  }
}
