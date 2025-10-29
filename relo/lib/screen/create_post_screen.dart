import 'package:flutter/material.dart';
import 'package:relo/services/post_service.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/widgets/media_picker_sheet.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:relo/utils/show_notification.dart';
import 'dart:io';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final PostService _postService = ServiceLocator.postService;
  final TextEditingController _contentController = TextEditingController();
  final List<File> _selectedImages = [];
  bool _isPosting = false;

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
            _selectedImages.addAll(files);
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<int> _calculateTotalSize() async {
    int totalSize = 0;
    for (var file in _selectedImages) {
      totalSize += await file.length();
    }
    return totalSize;
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  bool _isVideoFile(File file) {
    final path = file.path.toLowerCase();
    return path.endsWith('.mp4') ||
        path.endsWith('.mov') ||
        path.endsWith('.avi') ||
        path.endsWith('.mkv') ||
        path.endsWith('.m4v');
  }

  Future<void> _createPost() async {
    final content = _contentController.text.trim();

    // Require at least content or images
    if (content.isEmpty && _selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập nội dung hoặc chọn ảnh')),
      );
      return;
    }

    // Validate max 30 media items
    if (_selectedImages.length > 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chỉ được đăng tối đa 30 ảnh/video')),
      );
      return;
    }

    // Validate max 150MB total size
    final totalSize = await _calculateTotalSize();
    const maxSize = 150 * 1024 * 1024; // 150MB in bytes
    if (totalSize > maxSize) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tổng dung lượng không được vượt quá 150MB'),
        ),
      );
      return;
    }

    setState(() => _isPosting = true);

    try {
      // Lấy danh sách đường dẫn file
      final List<String> filePaths = _selectedImages
          .map((file) => file.path)
          .toList();

      await _postService.createPost(
        content: content,
        filePaths: filePaths.isEmpty ? null : filePaths,
      );

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
        await ShowNotification.showToast(
          context,
          'Đã đăng bài viết thành công!',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPosting = false);
        await ShowNotification.showToast(context, 'Lỗi đăng bài: $e');
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
          'Tạo bài viết',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _isPosting ? null : _createPost,
            child: _isPosting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Đăng',
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

                  // Selected images
                  if (_selectedImages.isNotEmpty)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemCount: _selectedImages.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _selectedImages[index],
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
                            if (_isVideoFile(_selectedImages[index]))
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
                ],
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: ElevatedButton.icon(
              onPressed: _pickMedia,
              icon: const Icon(LucideIcons.image, size: 20),
              label: const Text(
                'Thêm ảnh/video',
                style: TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: const Color(0xFF7A2FC0),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
