import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:relo/models/user.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/services/user_service.dart';
import 'package:relo/services/message_service.dart';
import 'package:relo/screen/chat_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:shimmer/shimmer.dart';
import 'package:photo_view/photo_view.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:io';

class ProfileScreen extends StatefulWidget {
  final String? userId; // Null means current user
  
  const ProfileScreen({Key? key, this.userId}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  final UserService _userService = ServiceLocator.userService;
  final MessageService _messageService = ServiceLocator.messageService;
  User? _user;
  bool _isLoading = true;
  bool _isOwnProfile = false;
  final ImagePicker _imagePicker = ImagePicker();
  final RefreshController _refreshController = RefreshController(initialRefresh: false);
  
  // Controllers cho edit
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  
  // Animation controllers
  late AnimationController _animationController;
  
  // Statistics
  int _friendCount = 0;
  int _postCount = 0;
  bool _isFriend = false;
  bool _isBlocked = false;
  bool _hasPendingRequest = false;
  
  // Temporary image storage for preview
  String? _tempAvatarPath;
  String? _tempBackgroundPath;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _loadUserProfile();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _animationController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      User? user;
      if (widget.userId == null) {
        // Load current user
        user = await _userService.getMe();
        _isOwnProfile = true;
      } else {
        // Load other user profile
        user = await _userService.getUserProfile(widget.userId!);
        // Check if it's own profile by comparing with current user
        User? currentUser = await _userService.getMe();
        _isOwnProfile = currentUser?.id == widget.userId;
        
        // Check friend status if not own profile
        if (!_isOwnProfile && currentUser != null) {
          await _checkFriendStatus(currentUser, user);
        }
      }
      
      // Load statistics
      if (user != null) {
        await _loadStatistics(user);
      }
      
      setState(() {
        _user = user;
        _isLoading = false;
        if (user != null) {
          _displayNameController.text = user.displayName;
          _bioController.text = user.bio ?? '';
        }
      });
      
      _refreshController.refreshCompleted();
      _animationController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _refreshController.refreshFailed();
      _showError('Không thể tải thông tin người dùng');
    }
  }
  
  Future<void> _checkFriendStatus(User currentUser, User profileUser) async {
    try {
      // Check if they are friends
      final friends = await _userService.getFriends();
      _isFriend = friends.any((f) => f.id == profileUser.id);
      
      // Check pending requests
      if (!_isFriend) {
        final pendingRequests = await _userService.getPendingFriendRequests();
        _hasPendingRequest = pendingRequests.any((r) => 
          r['fromUserId'] == currentUser.id && r['toUserId'] == profileUser.id ||
          r['fromUserId'] == profileUser.id && r['toUserId'] == currentUser.id
        );
      }
    } catch (e) {
      print('Error checking friend status: $e');
    }
  }
  
  Future<void> _loadStatistics(User user) async {
    try {
      // Load friend count
      if (_isOwnProfile) {
        final friends = await _userService.getFriends();
        _friendCount = friends.length;
      }
      // TODO: Load post count from API when available
      _postCount = 0;
    } catch (e) {
      print('Error loading statistics: $e');
    }
  }

  Future<void> _pickAndUpdateAvatar({ImageSource source = ImageSource.gallery}) async {
    try {
      // Check permission for camera
      if (source == ImageSource.camera) {
        final status = await Permission.camera.request();
        if (!status.isGranted) {
          _showError('Cần cấp quyền camera để chụp ảnh');
          return;
        }
      }
      
      // Pick image
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (image == null) return;
      
      // Store temp path for preview
      setState(() {
        _tempAvatarPath = image.path;
      });
      
      _showLoadingDialog('Đang tải ảnh lên Cloudinary...');
      
      // Read image bytes
      final bytes = await File(image.path).readAsBytes();
      
      // Create proper base64 string
      final base64String = base64Encode(bytes);
      final base64Image = 'data:image/jpeg;base64,$base64String';
      
      // Clear cache of old image first
      if (_user?.avatarUrl != null) {
        await CachedNetworkImage.evictFromCache(_user!.avatarUrl!);
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      }
      
      // Upload to server and get updated user
      final updatedUser = await _userService.updateAvatar(base64Image);
      
      // Give Cloudinary some time to process
      await Future.delayed(Duration(milliseconds: 1500));
      
      Navigator.pop(context); // Close loading
      
      if (updatedUser != null) {
        // Clear cache of new URL to force reload
        if (updatedUser.avatarUrl != null) {
          await CachedNetworkImage.evictFromCache(updatedUser.avatarUrl!);
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
        }
        
        setState(() {
          _user = updatedUser;
          _tempAvatarPath = null;
        });
        
        // Wait a bit then precache new image
        await Future.delayed(Duration(milliseconds: 300));
        if (updatedUser.avatarUrl != null && mounted) {
          try {
            await precacheImage(
              CachedNetworkImageProvider(updatedUser.avatarUrl!),
              context,
            );
          } catch (e) {
            print('Precache failed: $e');
          }
        }
        
        _showSuccess('Ảnh đại diện đã được cập nhật!');
      } else {
        setState(() {
          _tempAvatarPath = null;
        });
        _showError('Không thể cập nhật ảnh đại diện');
      }
      
    } catch (e) {
      setState(() {
        _tempAvatarPath = null;
      });
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context); // Close loading if still open
      }
      _showError('Lỗi: ${e.toString()}');
    }
  }

  Future<void> _pickAndUpdateBackground({ImageSource source = ImageSource.gallery}) async {
    try {
      // Check permission for camera
      if (source == ImageSource.camera) {
        final status = await Permission.camera.request();
        if (!status.isGranted) {
          _showError('Cần cấp quyền camera để chụp ảnh');
          return;
        }
      }
      
      // Pick image
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 600,
        imageQuality: 85,
      );
      
      if (image == null) return;
      
      // Store temp path for preview
      setState(() {
        _tempBackgroundPath = image.path;
      });
      
      _showLoadingDialog('Đang tải ảnh lên Cloudinary...');
      
      // Read image bytes
      final bytes = await File(image.path).readAsBytes();
      
      // Create proper base64 string
      final base64String = base64Encode(bytes);
      final base64Image = 'data:image/jpeg;base64,$base64String';
      
      // Clear cache of old image first
      if (_user?.backgroundUrl != null) {
        await CachedNetworkImage.evictFromCache(_user!.backgroundUrl!);
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      }
      
      // Upload to server and get updated user
      final updatedUser = await _userService.updateBackground(base64Image);
      
      // Give Cloudinary some time to process
      await Future.delayed(Duration(milliseconds: 1500));
      
      Navigator.pop(context); // Close loading
      
      if (updatedUser != null) {
        // Clear cache of new URL to force reload
        if (updatedUser.backgroundUrl != null) {
          await CachedNetworkImage.evictFromCache(updatedUser.backgroundUrl!);
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
        }
        
        setState(() {
          _user = updatedUser;
          _tempBackgroundPath = null;
        });
        
        // Wait a bit then precache new image
        await Future.delayed(Duration(milliseconds: 300));
        if (updatedUser.backgroundUrl != null && mounted) {
          try {
            await precacheImage(
              CachedNetworkImageProvider(updatedUser.backgroundUrl!),
              context,
            );
          } catch (e) {
            print('Precache failed: $e');
          }
        }
        
        _showSuccess('Ảnh bìa đã được cập nhật!');
      } else {
        setState(() {
          _tempBackgroundPath = null;
        });
        _showError('Không thể cập nhật ảnh bìa');
      }
      
    } catch (e) {
      setState(() {
        _tempBackgroundPath = null;
      });
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context); // Close loading if still open
      }
      _showError('Lỗi: ${e.toString()}');
    }
  }

  void _showEditProfileDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Chỉnh sửa thông tin',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 20),
              TextField(
                controller: _displayNameController,
                decoration: InputDecoration(
                  labelText: 'Tên hiển thị',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: Icon(Icons.person, color: Color(0xFF7C3AED)),
                ),
              ),
              SizedBox(height: 15),
              TextField(
                controller: _bioController,
                maxLines: 3,
                maxLength: 150,
                decoration: InputDecoration(
                  labelText: 'Giới thiệu bản thân',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: Icon(Icons.info_outline, color: Color(0xFF7C3AED)),
                  helperText: 'Tối đa 150 ký tự',
                ),
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text('Hủy'),
                    ),
                  ),
                  SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _updateProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF7C3AED),
                        padding: EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text('Lưu', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateProfile() async {
    try {
      Navigator.pop(context); // Close dialog
      _showLoadingDialog('Đang cập nhật thông tin...');
      
      await _userService.updateProfile(
        displayName: _displayNameController.text.trim(),
        bio: _bioController.text.trim(),
      );
      
      Navigator.pop(context); // Close loading
      await _loadUserProfile();
      _showSuccess('Cập nhật thông tin thành công');
    } catch (e) {
      Navigator.pop(context); // Close loading
      _showError('Không thể cập nhật thông tin');
    }
  }

  void _showImageOptions(bool isAvatar) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isAvatar ? 'Ảnh đại diện' : 'Ảnh bìa',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.photo_library, color: Color(0xFF7C3AED)),
              title: Text('Chọn từ thư viện'),
              onTap: () {
                Navigator.pop(context);
                if (isAvatar) {
                  _pickAndUpdateAvatar(source: ImageSource.gallery);
                } else {
                  _pickAndUpdateBackground(source: ImageSource.gallery);
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: Color(0xFF7C3AED)),
              title: Text('Chụp ảnh mới'),
              onTap: () {
                Navigator.pop(context);
                if (isAvatar) {
                  _pickAndUpdateAvatar(source: ImageSource.camera);
                } else {
                  _pickAndUpdateBackground(source: ImageSource.camera);
                }
              },
            ),
            if (_user?.avatarUrl != null && isAvatar || _user?.backgroundUrl != null && !isAvatar)
              ListTile(
                leading: Icon(Icons.visibility, color: Color(0xFF7C3AED)),
                title: Text('Xem ảnh hiện tại'),
                onTap: () {
                  Navigator.pop(context);
                  _showFullScreenImage(isAvatar ? _user!.avatarUrl! : _user!.backgroundUrl!);
                },
              ),
            ListTile(
              leading: Icon(Icons.cancel, color: Colors.grey),
              title: Text('Hủy'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ).animate().fadeIn(),
      ),
    );
  }
  
  void _showQRCode() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Mã QR của tôi',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Color(0xFF7C3AED), width: 2),
                ),
                child: QrImageView(
                  data: 'relo://profile/${_user!.id}',
                  version: QrVersions.auto,
                  size: 200.0,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF7C3AED),
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF7C3AED),
                  ),
                ),
              ),
              SizedBox(height: 15),
              Text(
                '@${_user!.username}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 5),
              Text(
                'Quét mã để xem trang cá nhân',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Đóng'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Share QR code
                      _showSuccess('Tính năng chia sẻ đang phát triển');
                    },
                    icon: Icon(Icons.share, color: Colors.white),
                    label: Text('Chia sẻ', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF7C3AED),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate().scale(),
      ),
    );
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: Icon(Icons.download),
                onPressed: () {
                  // TODO: Download image
                  _showSuccess('Tính năng tải ảnh đang phát triển');
                },
              ),
            ],
          ),
          body: PhotoView(
            imageProvider: CachedNetworkImageProvider(imageUrl),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3,
            backgroundDecoration: BoxDecoration(color: Colors.black),
            loadingBuilder: (context, event) => Center(
              child: CircularProgressIndicator(
                value: event == null ? 0 : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
                color: Color(0xFF7C3AED),
              ),
            ),
          ),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: Color(0xFF7C3AED)),
            SizedBox(width: 20),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: _buildLoadingSkeleton(),
      );
    }

    if (_user == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Color(0xFF7C3AED),
          title: Text('Trang cá nhân', style: TextStyle(color: Colors.white)),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Text('Không thể tải thông tin người dùng'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SmartRefresher(
        enablePullDown: true,
        header: ClassicHeader(
          completeText: 'Cập nhật thành công',
          refreshingText: 'Đang tải...',
          idleText: 'Kéo xuống để làm mới',
          releaseText: 'Thả để làm mới',
        ),
        controller: _refreshController,
        onRefresh: _loadUserProfile,
        child: CustomScrollView(
          slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: Color(0xFF7C3AED),
            iconTheme: IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Background image
                  GestureDetector(
                    onTap: _isOwnProfile ? () => _showImageOptions(false) : null,
                    child: Container(
                      key: ValueKey('background_${_user!.backgroundUrl}'),
                      height: 200,
                      decoration: BoxDecoration(
                        image: _tempBackgroundPath != null
                            ? DecorationImage(
                                image: FileImage(File(_tempBackgroundPath!)),
                                fit: BoxFit.cover,
                              )
                            : (_user!.backgroundUrl != null && _user!.backgroundUrl!.isNotEmpty
                                ? DecorationImage(
                                    image: CachedNetworkImageProvider(_user!.backgroundUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null),
                        gradient: (_tempBackgroundPath == null && (_user!.backgroundUrl == null || _user!.backgroundUrl!.isEmpty))
                            ? LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0xFF9B59B6),
                                  Color(0xFF7C3AED),
                                ],
                              )
                            : null,
                      ),
                      child: _isOwnProfile && _tempBackgroundPath == null && (_user!.backgroundUrl == null || _user!.backgroundUrl!.isEmpty)
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate,
                                    size: 50,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    'Thêm ảnh bìa',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : null,
                    ),
                  ),
                  // Avatar and info overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          // Avatar
                          GestureDetector(
                            onTap: _isOwnProfile ? () => _showImageOptions(true) : null,
                            child: Stack(
                              children: [
                                Hero(
                                  tag: 'avatar_${_user!.id}',
                                  child: CircleAvatar(
                                    key: ValueKey('avatar_${_user!.avatarUrl}'),
                                    radius: 45,
                                    backgroundColor: Colors.white,
                                    child: CircleAvatar(
                                      radius: 43,
                                      backgroundImage: _tempAvatarPath != null
                                          ? FileImage(File(_tempAvatarPath!))
                                          : (_user!.avatarUrl != null && _user!.avatarUrl!.isNotEmpty
                                              ? CachedNetworkImageProvider(_user!.avatarUrl!)
                                              : null) as ImageProvider?,
                                      child: (_tempAvatarPath == null && (_user!.avatarUrl == null || _user!.avatarUrl!.isEmpty))
                                          ? Icon(
                                              Icons.person,
                                              size: 50,
                                              color: Colors.grey,
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                                if (_isOwnProfile)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Color(0xFF7C3AED),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.camera_alt,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(width: 15),
                          // Name and username
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _user!.displayName,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  '@${_user!.username}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Edit button
                  if (_isOwnProfile)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 10,
                      right: 10,
                      child: IconButton(
                        icon: Icon(Icons.edit, color: Colors.white),
                        onPressed: _showEditProfileDialog,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Profile content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bio section
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.all(15),
                  padding: EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Color(0xFF7C3AED),
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Giới thiệu',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text(
                        _user!.bio?.isNotEmpty == true
                            ? _user!.bio!
                            : (_isOwnProfile
                                ? 'Thêm giới thiệu về bản thân'
                                : 'Chưa có giới thiệu'),
                        style: TextStyle(
                          fontSize: 15,
                          color: _user!.bio?.isNotEmpty == true
                              ? Colors.black87
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Statistics row
                _buildStatisticsRow(),

                // User info section
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 15),
                  padding: EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.account_circle,
                            color: Color(0xFF7C3AED),
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Thông tin tài khoản',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 15),
                      _buildInfoRow(Icons.person, 'Tên đăng nhập', _user!.username),
                      _buildInfoRow(Icons.email, 'Email', _user!.email),
                      _buildInfoRow(Icons.badge, 'Tên hiển thị', _user!.displayName),
                    ],
                  ),
                ),

                // Action buttons (if not own profile)
                if (!_isOwnProfile) ...[
                  SizedBox(height: 20),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                // Create or get conversation with the user
                                final newConversation = await _messageService.getOrCreateConversation([_user!.id]);
                                
                                // Navigate to chat screen
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatScreen(
                                      conversationId: newConversation['_id'] ?? newConversation['id'],
                                      isGroup: false,
                                      friendName: _user!.displayName,
                                    ),
                                  ),
                                );
                              } catch (e) {
                                _showError('Không thể mở cuộc trò chuyện: ${e.toString()}');
                              }
                            },
                            icon: Icon(Icons.message, color: Colors.white),
                            label: Text(
                              'Nhắn tin',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF7C3AED),
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: _buildFriendButton(),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: 100), // Bottom padding
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        children: [
          // Header skeleton
          Container(
            height: 280,
            color: Colors.white,
          ),
          SizedBox(height: 20),
          // Info skeleton
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Container(height: 20, color: Colors.white),
                SizedBox(height: 10),
                Container(height: 20, width: 200, color: Colors.white),
                SizedBox(height: 20),
                Container(height: 100, color: Colors.white),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatisticsRow() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('Bạn bè', _friendCount.toString()),
          Container(
            height: 30,
            width: 1,
            color: Colors.grey[300],
          ),
          _buildStatItem('Bài viết', _postCount.toString()),
          if (_isOwnProfile) ...[
            Container(
              height: 30,
              width: 1,
              color: Colors.grey[300],
            ),
            GestureDetector(
              onTap: _showQRCode,
              child: Column(
                children: [
                  Icon(Icons.qr_code, color: Color(0xFF7C3AED)),
                  SizedBox(height: 5),
                  Text(
                    'Mã QR',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ).animate().fadeIn(duration: Duration(milliseconds: 500)),
    );
  }
  
  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
  
  Widget _buildFriendButton() {
    if (_isFriend) {
      return ElevatedButton.icon(
        onPressed: () {
          _showFriendOptions();
        },
        icon: Icon(Icons.check, color: Color(0xFF7C3AED)),
        label: Text('Bạn bè', style: TextStyle(color: Color(0xFF7C3AED))),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Color(0xFF7C3AED)),
          ),
        ),
      );
    } else if (_hasPendingRequest) {
      return ElevatedButton.icon(
        onPressed: null,
        icon: Icon(Icons.schedule, color: Colors.grey),
        label: Text('Đã gửi lời mời', style: TextStyle(color: Colors.grey)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[200],
          padding: EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } else {
      return ElevatedButton.icon(
        onPressed: () async {
          try {
            await _userService.sendFriendRequest(_user!.id);
            setState(() {
              _hasPendingRequest = true;
            });
            _showSuccess('Đã gửi lời mời kết bạn');
          } catch (e) {
            _showError('Không thể gửi lời mời');
          }
        },
        icon: Icon(Icons.person_add),
        label: Text('Kết bạn'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF7C3AED),
          padding: EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Color(0xFF7C3AED)),
          ),
        ),
      );
    }
  }
  
  void _showFriendOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.block, color: Colors.red),
              title: Text('Chặn người dùng'),
              onTap: () async {
                Navigator.pop(context);
                bool? confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Chặn người dùng'),
                    content: Text('Bạn có chắc muốn chặn ${_user!.displayName}?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('Hủy'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: Text('Chặn'),
                      ),
                    ],
                  ),
                );
                
                if (confirm == true) {
                  try {
                    await _userService.blockUser(_user!.id);
                    _showSuccess('Đã chặn người dùng');
                    Navigator.pop(context);
                  } catch (e) {
                    _showError('Không thể chặn người dùng');
                  }
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.person_remove, color: Colors.orange),
              title: Text('Hủy kết bạn'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement unfriend
                _showSuccess('Tính năng đang phát triển');
              },
            ),
            ListTile(
              leading: Icon(Icons.cancel, color: Colors.grey),
              title: Text('Hủy'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 20),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
