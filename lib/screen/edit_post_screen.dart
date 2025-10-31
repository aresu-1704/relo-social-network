import 'package:flutter/material.dart';
import 'package:relo/models/post.dart';
import 'package:relo/services/post_service.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/widgets/media_picker_sheet.dart';
import 'package:relo/utils/show_notification.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:io';

class EditPostScreen extends StatefulWidget {
  final Post post;

  const EditPostScreen({
    super.key,
    required this.post,
  });

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  final PostService _postService = ServiceLocator.postService;
  late final TextEditingController _contentController;
  final List<dynamic> _images = []; // Mix of String (URL) and File (new image)
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.post.content);
    _images.addAll(widget.post.mediaUrls); // Add existing URLs
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MediaPickerSheet(
        onPicked: (files) {
          setState(() {
            _images.addAll(files);
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  bool _isVideoFile(dynamic file) {
    String path;
    if (file is File) {
      path = file.path.toLowerCase();
    } else if (file is String) {
      path = file.toLowerCase();
    } else {
      return false;
    }
    return path.endsWith('.mp4') || 
           path.endsWith('.mov') || 
           path.endsWith('.avi') || 
           path.endsWith('.mkv') ||
           path.endsWith('.m4v');
  }

  Future<int> _calculateTotalSize() async {
    int totalSize = 0;
    for (var image in _images) {
      if (image is File) {
        totalSize += await image.length();
      }
      // For existing URLs, we can't easily get the size without downloading,
      // so we'll skip validation for those
    }
    return totalSize;
  }

  Future<void> _updatePost() async {
    final content = _contentController.text.trim();

    if (content.isEmpty && _images.isEmpty) {
      await ShowNotification.showCustomAlertDialog(
        context,
        message: 'Vui lòng nhập nội dung hoặc chọn ảnh',
        buttonText: 'Ok',
        buttonColor: Color(0xFF7A2FC0),
      );
      return;
    }

    // Validate max 30 media items
    if (_images.length > 30) {
      await ShowNotification.showCustomAlertDialog(
        context,
        message: 'Chỉ được đăng tối đa 30 ảnh/video',
        buttonText: 'Ok',
        buttonColor: Color(0xFF7A2FC0),
      );
      return;
    }

    // Validate max 150MB total size for new files
    final totalSize = await _calculateTotalSize();
    const maxSize = 150 * 1024 * 1024; // 150MB in bytes
    if (totalSize > maxSize) {
      await ShowNotification.showCustomAlertDialog(
        context,
        message: 'Tổng dung lượng không được vượt quá 150MB',
        buttonText: 'Ok',
        buttonColor: Color(0xFF7A2FC0),
      );
      return;
    }

    setState(() => _isUpdating = true);

    try {
      // Separate existing URLs and new files
      final List<String> existingUrls = [];
      final List<String> newFilePaths = [];
      
      for (var image in _images) {
        if (image is String) {
          existingUrls.add(image); // Existing URL
        } else if (image is File) {
          newFilePaths.add(image.path); // New file
        }
      }
      
      await _postService.updatePost(
        postId: widget.post.id,
        content: content,
        existingImageUrls: existingUrls,
        newFilePaths: newFilePaths.isEmpty ? null : newFilePaths,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        await ShowNotification.showCustomAlertDialog(
          context,
          message: 'Lỗi cập nhật: $e',
          buttonText: 'Ok',
          buttonColor: Colors.red,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF7A2FC0),
        leading: IconButton(
          icon: const Icon(LucideIcons.x, color: Colors.white, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Chỉnh sửa bài viết',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _isUpdating ? null : _updatePost,
            child: _isUpdating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Lưu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text input
            TextField(
              controller: _contentController,
              maxLines: null,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Bạn đang nghĩ gì?',
                border: InputBorder.none,
                hintStyle: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              style: const TextStyle(fontSize: 18, height: 1.5),
            ),

            const SizedBox(height: 16),

            // Display all images (existing + new)
            if (_images.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ảnh:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${_images.length} ảnh',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _images.length,
                itemBuilder: (context, index) {
                  final image = _images[index];
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: image is String
                            ? Image.network(
                                image,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.videocam, size: 48),
                                  );
                                },
                              )
                            : Image.file(
                                image as File,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.videocam, size: 48),
                                  );
                                },
                              ),
                      ),
                      // Video indicator
                      if (_isVideoFile(image))
                        const Positioned(
                          bottom: 4,
                          left: 4,
                          child: Icon(
                            Icons.videocam,
                            color: Colors.white,
                            size: 24,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 4),
                            ],
                          ),
                        ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
            ],

            // Add media button
            ElevatedButton.icon(
              onPressed: _pickMedia,
              icon: const Icon(LucideIcons.image, size: 20),
              label: const Text('Thêm ảnh/video', style: TextStyle(fontSize: 15)),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: const Color(0xFF7A2FC0).withOpacity(0.1),
                foregroundColor: const Color(0xFF7A2FC0),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: const Color(0xFF7A2FC0).withOpacity(0.3)),
                ),
              ),
            ),
          ],
        ),
      ),
          ),
        ],
      ),
    );
  }
}
