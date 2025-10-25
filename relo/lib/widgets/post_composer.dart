import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:relo/services/post_service.dart';
import 'package:relo/services/service_locator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:relo/models/user.dart';
import 'package:relo/services/user_service.dart';

class PostComposer extends StatefulWidget {
  final VoidCallback? onPostCreated;
  
  const PostComposer({super.key, this.onPostCreated});

  @override
  State<PostComposer> createState() => _PostComposerState();
}

class _PostComposerState extends State<PostComposer> {
  final TextEditingController _contentController = TextEditingController();
  final List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  final PostService _postService = ServiceLocator.postService;
  final UserService _userService = ServiceLocator.userService;
  
  bool _isPosting = false;
  User? _currentUser;
  
  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }
  
  Future<void> _loadCurrentUser() async {
    try {
      final user = await _userService.getMe();
      setState(() {
        _currentUser = user;
      });
    } catch (e) {
      print('Error loading user: $e');
    }
  }
  
  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  // Chọn ảnh từ thư viện (giống Zalo)
  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 90,
      );
      
      if (pickedFiles.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(
            pickedFiles.map((xfile) => File(xfile.path)).toList()
          );
        });
      }
    } catch (e) {
      print('Error picking images: $e');
    }
  }
  
  // Chụp ảnh từ camera
  Future<void> _takePicture() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 90,
      );
      
      if (photo != null) {
        setState(() {
          _selectedImages.add(File(photo.path));
        });
      }
    } catch (e) {
      print('Error taking picture: $e');
    }
  }
  
  // Xóa ảnh đã chọn
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  // Đăng bài
  Future<void> _createPost() async {
    if (_contentController.text.isEmpty && _selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vui lòng nhập nội dung hoặc chọn ảnh'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    setState(() {
      _isPosting = true;
    });
    
    try {
      final post = await _postService.createPost(
        content: _contentController.text,
        mediaFiles: _selectedImages.isNotEmpty ? _selectedImages : null,
      );
      
      if (post != null) {
        // Clear form
        _contentController.clear();
        _selectedImages.clear();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã đăng bài thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Call callback if provided
        widget.onPostCreated?.call();
        
        // Close composer
        Navigator.of(context).pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi đăng bài: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isPosting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Tạo bài viết',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: ElevatedButton(
              onPressed: _isPosting ? null : _createPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF7C3AED),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20),
              ),
              child: _isPosting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'ĐĂNG',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // User info header (like Zalo)
          if (_currentUser != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: _currentUser!.avatarUrl != null
                        ? CachedNetworkImageProvider(_currentUser!.avatarUrl!)
                        : null,
                    child: _currentUser!.avatarUrl == null
                        ? Text(
                            _currentUser!.displayName[0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  SizedBox(width: 12),
                  // Name and privacy
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentUser!.displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.public,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Công khai',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          
          Divider(height: 1),
          
          // Content input
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Text input
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: TextField(
                      controller: _contentController,
                      maxLines: null,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Bạn đang nghĩ gì?',
                        hintStyle: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 18,
                        ),
                        border: InputBorder.none,
                      ),
                      style: TextStyle(
                        fontSize: 18,
                        height: 1.4,
                      ),
                    ),
                  ),
                  
                  // Selected images grid (like Zalo)
                  if (_selectedImages.isNotEmpty)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _selectedImages.length == 1 ? 1 : 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                        itemCount: _selectedImages.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              // Image
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  _selectedImages[index],
                                  fit: BoxFit.cover,
                                ),
                              ),
                              // Remove button
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () => _removeImage(index),
                                  child: Container(
                                    padding: EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Bottom toolbar (like Zalo)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Gallery button
                _buildToolButton(
                  icon: Icons.photo_library_outlined,
                  label: 'Ảnh/Video',
                  onTap: _pickImages,
                  color: Colors.green,
                ),
                SizedBox(width: 20),
                // Camera button
                _buildToolButton(
                  icon: Icons.camera_alt_outlined,
                  label: 'Chụp ảnh',
                  onTap: _takePicture,
                  color: Colors.blue,
                ),
                SizedBox(width: 20),
                // Feeling button
                _buildToolButton(
                  icon: Icons.mood_outlined,
                  label: 'Cảm xúc',
                  onTap: () {
                    // TODO: Implement feeling picker
                  },
                  color: Colors.orange,
                ),
                SizedBox(width: 20),
                // Check-in button
                _buildToolButton(
                  icon: Icons.location_on_outlined,
                  label: 'Check in',
                  onTap: () {
                    // TODO: Implement location picker
                  },
                  color: Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
