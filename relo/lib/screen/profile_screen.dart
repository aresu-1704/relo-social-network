import 'package:flutter/material.dart';
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
import 'package:relo/utils/show_toast.dart';
import 'package:relo/utils/show_alert_dialog.dart';
import 'package:relo/utils/show_notification.dart';
import 'package:relo/screen/privacy_settings_screen.dart';
import 'dart:convert';
import 'dart:io';

class ProfileScreen extends StatefulWidget {
  final String? userId; // Null means current user
  
  const ProfileScreen({super.key, this.userId});

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
      if (mounted) {
        await showToast(context, 'Không thể tải thông tin người dùng');
      }
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
        final cameraStatus = await Permission.camera.request();
        
        if (!cameraStatus.isGranted) {
          final openSettings = await ShowNotification.showCustomAlertDialog(
            context,
            message: "Cần quyền camera để chụp ảnh",
            buttonText: "Mở cài đặt",
            buttonColor: Color(0xFF7A2FC0),
          );
          
          if (openSettings == true) {
            await openAppSettings();
            await Future.delayed(Duration(seconds: 1));
            
            final cameraAfter = await Permission.camera.status;
            if (!cameraAfter.isGranted) {
              if (mounted) {
                await ShowNotification.showCustomAlertDialog(
                  context,
                  message: "Vẫn chưa có quyền camera, không thể chụp ảnh.",
                );
              }
              return;
            }
          } else {
            return;
          }
        }
      }
      
      // Pick image with optimized settings (như message_service.py)
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,  // Tối ưu size cho avatar
        maxHeight: 1024,
        imageQuality: 90, // Chất lượng cao hơn
      );
      
      if (image == null) return;
      
      // Store temp path for instant preview
      setState(() {
        _tempAvatarPath = image.path;
      });
      
      _showLoadingDialog('Đang tải ảnh lên Cloudinary...');
      
      // Optimize image before upload (giống message_service.py)
      final File imageFile = File(image.path);
      final bytes = await imageFile.readAsBytes();
      
      // Check file size
      if (bytes.lengthInBytes > 5 * 1024 * 1024) { // 5MB limit
        Navigator.pop(context);
        if (mounted) {
          await showToast(context, 'Ảnh quá lớn! Vui lòng chọn ảnh nhỏ hơn 5MB');
        }
        setState(() {
          _tempAvatarPath = null;
        });
        return;
      }
      
      // Create proper base64 string with MIME type
      final String mimeType = image.path.toLowerCase().endsWith('.png') 
          ? 'image/png' 
          : 'image/jpeg';
      final base64String = base64Encode(bytes);
      final base64Image = 'data:$mimeType;base64,$base64String';
      
      // Clear all image caches before upload
      if (_user?.avatarUrl != null) {
        await CachedNetworkImage.evictFromCache(_user!.avatarUrl!);
      }
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      
      // Upload to server using optimized method
      final updatedUser = await _userService.updateAvatar(base64Image);
      
      // Wait for Cloudinary processing
      await Future.delayed(Duration(seconds: 1));
      
      Navigator.pop(context); // Close loading
      
      if (updatedUser != null) {
        // Force refresh cache với timestamp
        final newUrl = '${updatedUser.avatarUrl}?t=${DateTime.now().millisecondsSinceEpoch}';
        
        setState(() {
          _user = updatedUser;
          _tempAvatarPath = null;
        });
        
        // Prefetch new image với retry
        if (updatedUser.avatarUrl != null && mounted) {
          for (int i = 0; i < 3; i++) {
            try {
              await precacheImage(
                CachedNetworkImageProvider(newUrl),
                context,
              );
              break;
            } catch (e) {
              if (i == 2) print('Precache failed after 3 attempts: $e');
              await Future.delayed(Duration(milliseconds: 500));
            }
          }
        }
        
        if (mounted) {
          await showToast(context, 'Ảnh đại diện đã được cập nhật!');
        }
      } else {
        setState(() {
          _tempAvatarPath = null;
        });
        if (mounted) {
          await showToast(context, 'Không thể cập nhật ảnh đại diện');
        }
      }
      
    } catch (e) {
      setState(() {
        _tempAvatarPath = null;
      });
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (mounted) {
        await showToast(context, 'Đã xảy ra lỗi, vui lòng thử lại');
      }
    }
  }

  Future<void> _pickAndUpdateBackground({ImageSource source = ImageSource.gallery}) async {
    try {
      // Check permission for camera
      if (source == ImageSource.camera) {
        final cameraStatus = await Permission.camera.request();
        
        if (!cameraStatus.isGranted) {
          final openSettings = await ShowNotification.showCustomAlertDialog(
            context,
            message: "Cần quyền camera để chụp ảnh",
            buttonText: "Mở cài đặt",
            buttonColor: Color(0xFF7A2FC0),
          );
          
          if (openSettings == true) {
            await openAppSettings();
            await Future.delayed(Duration(seconds: 1));
            
            final cameraAfter = await Permission.camera.status;
            if (!cameraAfter.isGranted) {
              if (mounted) {
                await ShowNotification.showCustomAlertDialog(
                  context,
                  message: "Vẫn chưa có quyền camera, không thể chụp ảnh.",
                );
              }
              return;
            }
          } else {
            return;
          }
        }
      }
      
      // Pick image with optimized settings for cover photo
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,  // HD width for cover
        maxHeight: 1080, // HD height
        imageQuality: 85, // Balance quality and size
      );
      
      if (image == null) return;
      
      // Store temp path for instant preview
      setState(() {
        _tempBackgroundPath = image.path;
      });
      
      _showLoadingDialog('Đang tải ảnh bìa lên Cloudinary...');
      
      // Optimize image before upload
      final File imageFile = File(image.path);
      final bytes = await imageFile.readAsBytes();
      
      // Check file size (larger limit for cover)
      if (bytes.lengthInBytes > 8 * 1024 * 1024) { // 8MB limit for cover
        Navigator.pop(context);
        if (mounted) {
          await showToast(context, 'Ảnh quá lớn! Vui lòng chọn ảnh nhỏ hơn 8MB');
        }
        setState(() {
          _tempBackgroundPath = null;
        });
        return;
      }
      
      // Create proper base64 string with MIME type
      final String mimeType = image.path.toLowerCase().endsWith('.png') 
          ? 'image/png' 
          : 'image/jpeg';
      final base64String = base64Encode(bytes);
      final base64Image = 'data:$mimeType;base64,$base64String';
      
      // Clear all image caches before upload
      if (_user?.backgroundUrl != null) {
        await CachedNetworkImage.evictFromCache(_user!.backgroundUrl!);
      }
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      
      // Upload to server using optimized method
      final updatedUser = await _userService.updateBackground(base64Image);
      
      // Wait for Cloudinary processing
      await Future.delayed(Duration(seconds: 1));
      
      Navigator.pop(context); // Close loading
      
      if (updatedUser != null) {
        // Force refresh cache với timestamp
        final newUrl = updatedUser.backgroundUrl != null
            ? '${updatedUser.backgroundUrl}?t=${DateTime.now().millisecondsSinceEpoch}'
            : null;
        
        setState(() {
          _user = updatedUser;
          _tempBackgroundPath = null;
        });
        
        // Prefetch new image với retry
        if (newUrl != null && mounted) {
          for (int i = 0; i < 3; i++) {
            try {
              await precacheImage(
                CachedNetworkImageProvider(newUrl),
                context,
              );
              break;
            } catch (e) {
              if (i == 2) print('Precache failed after 3 attempts: $e');
              await Future.delayed(Duration(milliseconds: 500));
            }
          }
        }
        
        if (mounted) {
          await showToast(context, 'Ảnh bìa đã được cập nhật thành công!');
        }
      } else {
        setState(() {
          _tempBackgroundPath = null;
        });
        if (mounted) {
          await showToast(context, 'Không thể cập nhật ảnh bìa');
        }
      }
      
    } catch (e) {
      setState(() {
        _tempBackgroundPath = null;
      });
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (mounted) {
        await showToast(context, 'Đã xảy ra lỗi, vui lòng thử lại');
      }
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
                  prefixIcon: Icon(Icons.person, color: Color(0xFF7A2FC0)),
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
                  prefixIcon: Icon(Icons.info_outline, color: Color(0xFF7A2FC0)),
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
                        backgroundColor: Color(0xFF7A2FC0),
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
      if (mounted) {
        await showToast(context, 'Cập nhật thông tin thành công');
      }
    } catch (e) {
      Navigator.pop(context); // Close loading
      if (mounted) {
        await showToast(context, 'Không thể cập nhật thông tin');
      }
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
              leading: Icon(Icons.photo_library, color: Color(0xFF7A2FC0)),
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
              leading: Icon(Icons.camera_alt, color: Color(0xFF7A2FC0)),
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
                leading: Icon(Icons.visibility, color: Color(0xFF7A2FC0)),
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
                  border: Border.all(color: Color(0xFF7A2FC0), width: 2),
                ),
                child: QrImageView(
                  data: 'relo://profile/${_user!.id}',
                  version: QrVersions.auto,
                  size: 200.0,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF7A2FC0),
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF7A2FC0),
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
                    onPressed: () async {
                      // TODO: Share QR code
                      if (mounted) {
                        await showToast(context, 'Tính năng chia sẻ đang phát triển');
                      }
                    },
                    icon: Icon(Icons.share, color: Colors.white),
                    label: Text('Chia sẻ', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF7A2FC0),
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
                onPressed: () async {
                  // TODO: Download image
                  if (mounted) {
                    await showToast(context, 'Tính năng tải ảnh đang phát triển');
                  }
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
                color: Color(0xFF7A2FC0),
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
            CircularProgressIndicator(color: Color(0xFF7A2FC0)),
            SizedBox(width: 20),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    if (mounted) {
      showToast(context, message);
    }
  }

  void _showError(String message) {
    if (mounted) {
      showToast(context, message);
    }
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
          backgroundColor: Color(0xFF7A2FC0),
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
            backgroundColor: Color(0xFF7A2FC0),
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
                                  Color(0xFF7A2FC0),
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
                                        color: Color(0xFF7A2FC0),
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
                            color: Color(0xFF7A2FC0),
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
                            color: Color(0xFF7A2FC0),
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
                                final newConversation = await _messageService.getOrCreateConversation([_user!.id], false, null);
                                
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
                                if (mounted) {
                                  await showToast(context, 'Không thể mở cuộc trò chuyện');
                                }
                              }
                            },
                            icon: Icon(Icons.message, color: Colors.white),
                            label: Text(
                              'Nhắn tin',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF7A2FC0),
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
                  Icon(Icons.qr_code, color: Color(0xFF7A2FC0)),
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
        icon: Icon(Icons.check, color: Color(0xFF7A2FC0)),
        label: Text('Bạn bè', style: TextStyle(color: Color(0xFF7A2FC0))),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Color(0xFF7A2FC0)),
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
            if (mounted) {
              await showToast(context, 'Đã gửi lời mời kết bạn');
            }
          } catch (e) {
            if (mounted) {
              await showToast(context, 'Không thể gửi lời mời');
            }
          }
        },
        icon: Icon(Icons.person_add),
        label: Text('Kết bạn'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF7A2FC0),
          padding: EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Color(0xFF7A2FC0)),
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
                bool? confirm = await showAlertDialog(
                  context,
                  title: 'Chặn người dùng',
                  message: 'Bạn có chắc muốn chặn ${_user!.displayName}?',
                  confirmText: 'Chặn',
                  cancelText: 'Hủy',
                  showCancel: true,
                  confirmColor: Colors.red,
                );
                
                if (confirm == true) {
                  try {
                    await _userService.blockUser(_user!.id);
                    if (mounted) {
                      await showToast(context, 'Đã chặn người dùng');
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    if (mounted) {
                      await showToast(context, 'Không thể chặn người dùng');
                    }
                  }
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.person_remove, color: Colors.orange),
              title: Text('Hủy kết bạn'),
              onTap: () async {
                Navigator.pop(context);
                // TODO: Implement unfriend
                if (mounted) {
                  await showToast(context, 'Tính năng đang phát triển');
                }
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
