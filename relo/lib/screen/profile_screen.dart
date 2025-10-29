import 'package:flutter/material.dart';
import 'package:relo/models/user.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/services/user_service.dart';
import 'package:relo/services/message_service.dart';
import 'package:relo/services/secure_storage_service.dart';
import 'package:relo/services/post_service.dart';
import 'package:relo/models/post.dart';
import 'package:relo/screen/chat_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:relo/utils/show_notification.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:relo/utils/permission_util.dart';
import 'package:relo/screen/media_fullscreen_viewer.dart';
import 'package:relo/screen/edit_profile_screen.dart';
import 'package:relo/utils/image_picker_settings.dart';
import 'package:relo/widgets/profiles/profile_header.dart';
import 'package:relo/widgets/profiles/profile_components.dart';
import 'package:relo/widgets/posts/enhanced_post_card.dart';
import 'package:relo/widgets/posts/post_composer_widget.dart';
import 'package:relo/screen/create_post_screen.dart';
import 'package:intl/intl.dart';
import 'package:relo/services/websocket_service.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  final bool hideMessageButton;

  const ProfileScreen({super.key, this.userId, this.hideMessageButton = false});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final UserService _userService = ServiceLocator.userService;
  final MessageService _messageService = ServiceLocator.messageService;
  final PostService _postService = ServiceLocator.postService;
  User? _user;
  bool _isLoading = true;
  bool _isOwnProfile = false;
  final ImagePicker _imagePicker = ImagePicker();
  final RefreshController _refreshController = RefreshController(
    initialRefresh: false,
  );

  String _currentUserId = "";
  // Animation controllers
  late AnimationController _animationController;

  // Statistics
  int _friendCount = 0;
  int _postCount = 0;
  String _friendStatus =
      'none'; // 'none', 'pending_sent', 'pending_received', 'friends'
  List<Post> _posts = [];

  // WebSocket listener
  StreamSubscription? _webSocketSubscription;

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
    _initProfile();
    _listenToWebSocket();
  }

  void _listenToWebSocket() {
    if (widget.userId == null) return; // Only for other users' profiles

    _webSocketSubscription = webSocketService.stream.listen((message) async {
      try {
        final data = jsonDecode(message);
        final type = data['type'] as String?;
        final payload = data['payload'];

        // Listen to friend-related events (matching backend broadcast types)
        final isFriendEvent =
            type == 'friend_request_received' ||
            type == 'friend_request_accepted' ||
            type == 'friend_added' ||
            type == 'friend_request_declined';

        if (widget.userId != null && payload != null && isFriendEvent) {
          // Extract user IDs from payload based on event type
          String? relevantUserId;

          if (type == 'friend_request_received') {
            // payload: {request_id, from_user_id, displayName, avatar}
            relevantUserId = payload['from_user_id'] as String?;
          } else if (type == 'friend_request_accepted') {
            // payload: {user_id, displayName, avatarUrl}
            relevantUserId = payload['user_id'] as String?;
          } else if (type == 'friend_added') {
            // payload: {user_id, displayName, avatarUrl}
            relevantUserId = payload['user_id'] as String?;
          } else if (type == 'friend_request_declined') {
            // payload: {user_id}
            relevantUserId = payload['user_id'] as String?;
          }

          // Check if this event affects the current profile user
          if (relevantUserId == widget.userId && mounted) {
            // Reload friend status
            final currentUser = await _userService.getMe();
            if (currentUser != null && _user != null && mounted) {
              await _checkFriendStatus(currentUser, _user!);
            }
          }
        }
      } catch (e) {
        print('Error in WebSocket listener: $e');
      }
    });
  }

  Future<void> _initProfile() async {
    await _loadCurrentUserId();
    await _loadUserProfile();
  }

  Future<void> _loadCurrentUserId() async {
    final currentUser = await _userService.getMe();
    if (currentUser == null) {
      return;
    }

    setState(() {
      _currentUserId = currentUser.id;
      // Set _isOwnProfile early if userId is provided
      if (widget.userId != null) {
        _isOwnProfile = currentUser.id == widget.userId;
      }
    });
  }

  Future<void> _loadUserProfile() async {
    try {
      User? user;
      if (widget.userId == null) {
        user = await _userService.getUserProfile(_currentUserId);
        setState(() {
          _isOwnProfile = true;
        });
      } else {
        // Load other user profile
        user = await _userService.getUserProfile(widget.userId!);
        // Check if it's own profile by comparing with current user
        User? currentUser = await _userService.getMe();
        setState(() {
          _isOwnProfile = currentUser?.id == widget.userId;
        });

        // Check friend status if not own profile
        if (!_isOwnProfile && currentUser != null) {
          await _checkFriendStatus(currentUser, user);
        }
      }

      await _loadStatistics(user);

      setState(() {
        _user = user;
        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshController.refreshCompleted();
        _animationController.forward();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print(e.toString());
      _refreshController.refreshFailed();
      if (mounted) {
        await ShowNotification.showToast(
          context,
          'Không thể tải thông tin người dùng',
        );
      }
    }
  }

  Future<void> _loadStatistics(User user) async {
    try {
      // Load friend count
      if (_isOwnProfile) {
        final friends = await _userService.getFriends();
        _friendCount = friends.length;
      }

      // Load posts
      final posts = await _postService.getUserPosts(user.id);
      setState(() {
        _posts = posts;
        _postCount = posts.length;
      });
    } catch (e) {
      print('Error loading statistics: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _refreshController.dispose();
    _webSocketSubscription?.cancel();
    super.dispose();
  }

  String _formatJoinDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final formatter = DateFormat('dd/MM/yyyy');
      return formatter.format(date);
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _checkFriendStatus(User currentUser, User profileUser) async {
    try {
      // Check friend status using API
      final status = await _userService.checkFriendStatus(profileUser.id);
      print('Friend status updated to: $status');

      if (mounted) {
        setState(() {
          _friendStatus = status;
        });
      }
    } catch (e) {
      print('Error checking friend status: $e');
    }
  }

  Future<void> _pickAndUpdateImage({
    required bool isAvatar,
    ImageSource source = ImageSource.gallery,
  }) async {
    try {
      // Kiểm tra quyền
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
      } else {
        final isStorageAllowed = await PermissionUtils.ensureStoragePermission(
          context,
        );
        if (!isStorageAllowed) return;
      }

      // Cấu hình cho avatar hoặc ảnh bìa
      final imageSettings = isAvatar
          ? ImagePickerSettings.avatar
          : ImagePickerSettings.background;

      // Pick image
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: imageSettings.maxWidth,
        maxHeight: imageSettings.maxHeight,
        imageQuality: imageSettings.quality,
      );

      if (image == null) return;

      // Store temp path for preview
      setState(() {
        if (isAvatar) {
          _tempAvatarPath = image.path;
        } else {
          _tempBackgroundPath = image.path;
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => Dialog(
              backgroundColor: Colors.white,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF7A2FC0),
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Đang tải ${isAvatar ? 'ảnh đại diện' : 'ảnh bìa'} lên...',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      });

      // Optimize and check file size
      final File imageFile = File(image.path);
      final bytes = await imageFile.readAsBytes();
      final maxSize = isAvatar ? 5 * 1024 * 1024 : 8 * 1024 * 1024;

      if (bytes.lengthInBytes > maxSize) {
        if (mounted) {
          Navigator.pop(context);
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (mounted) {
              await ShowNotification.showToast(
                context,
                'Ảnh quá lớn! Vui lòng chọn ảnh nhỏ hơn ${maxSize ~/ (1024 * 1024)}MB',
              );
            }
          });
          setState(() {
            if (isAvatar) {
              _tempAvatarPath = null;
            } else {
              _tempBackgroundPath = null;
            }
          });
        }
        return;
      }

      // Create base64 string
      final String mimeType = image.path.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';
      final base64String = base64Encode(bytes);
      final base64Image = 'data:$mimeType;base64,$base64String';

      // Clear image cache
      final String? oldUrl = isAvatar ? _user?.avatarUrl : _user?.backgroundUrl;
      if (oldUrl != null) {
        await CachedNetworkImage.evictFromCache(oldUrl);
      }
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      // Upload image
      User? updatedUser;
      if (isAvatar) {
        updatedUser = await _userService.updateAvatar(base64Image);
      } else {
        updatedUser = await _userService.updateBackground(base64Image);
        await Future.delayed(Duration(seconds: 1));
      }

      Navigator.pop(context);

      // Handle URL for cache busting (background only)
      final String? newUrl;
      if (!isAvatar && updatedUser.backgroundUrl != null) {
        newUrl =
            '${updatedUser.backgroundUrl}?t=${DateTime.now().millisecondsSinceEpoch}';
      } else {
        newUrl = isAvatar ? updatedUser.avatarUrl : updatedUser.backgroundUrl;
      }

      setState(() {
        _user = updatedUser;
        if (isAvatar) {
          _tempAvatarPath = null;
        } else {
          _tempBackgroundPath = null;
        }
      });

      // Prefetch new image
      if (newUrl != null && mounted) {
        for (int i = 0; i < 3; i++) {
          try {
            await precacheImage(CachedNetworkImageProvider(newUrl), context);
            break;
          } catch (e) {
            if (i == 2) print('Precache failed after 3 attempts: $e');
            await Future.delayed(Duration(milliseconds: 500));
          }
        }
      }

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (mounted) {
            await ShowNotification.showToast(
              context,
              '${isAvatar ? 'Ảnh đại diện' : 'Ảnh bìa'} đã được cập nhật thành công!',
            );
          }
        });
      }
    } catch (e) {
      setState(() {
        if (isAvatar) {
          _tempAvatarPath = null;
        } else {
          _tempBackgroundPath = null;
        }
      });
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (mounted) {
        await ShowNotification.showToast(
          context,
          'Đã xảy ra lỗi, vui lòng thử lại',
        );
      }
    }
  }

  void _navigateToEditProfile() async {
    if (_user == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          initialDisplayName: _user!.displayName,
          initialBio: _user!.bio ?? '',
        ),
      ),
    );

    if (result == true) {
      _loadUserProfile();
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
                _pickAndUpdateImage(
                  isAvatar: isAvatar,
                  source: ImageSource.gallery,
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: Color(0xFF7A2FC0)),
              title: Text('Chụp ảnh mới'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUpdateImage(
                  isAvatar: isAvatar,
                  source: ImageSource.camera,
                );
              },
            ),
            if (_user?.avatarUrl != null && isAvatar ||
                _user?.backgroundUrl != null && !isAvatar)
              ListTile(
                leading: Icon(Icons.visibility, color: Color(0xFF7A2FC0)),
                title: Text('Xem ảnh hiện tại'),
                onTap: () {
                  Navigator.pop(context);
                  _showFullScreenImage(
                    isAvatar ? _user!.avatarUrl! : _user!.backgroundUrl!,
                  );
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

  void _showFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            MediaFullScreenViewer(mediaUrls: [imageUrl], initialIndex: 0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: ProfileComponents.buildLoadingSkeleton());
    }

    if (_user == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Color(0xFF7A2FC0),
          title: Text('Trang cá nhân', style: TextStyle(color: Colors.white)),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        body: Center(child: Text('Không thể tải thông tin người dùng')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      floatingActionButton: !_isOwnProfile && !widget.hideMessageButton
          ? FloatingActionButton.extended(
              onPressed: () async {
                try {
                  // Create or get conversation with the user
                  final newConversation = await _messageService
                      .getOrCreateConversation([_user!.id], false, null);

                  // Navigate to chat screen
                  final participants =
                      (newConversation['participants'] ?? []) as List;
                  final secureStorage = const SecureStorageService();
                  final currentUserId = await secureStorage.getUserId();

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        conversationId:
                            newConversation['_id'] ?? newConversation['id'],
                        isGroup: false,
                        chatName: _user!.displayName,
                        memberIds: participants.isNotEmpty
                            ? participants
                                  .map((p) => p['id']?.toString() ?? '')
                                  .where((id) => id.isNotEmpty)
                                  .toList()
                            : [_user!.id, currentUserId!],
                        avatarUrl: _user!.avatarUrl,
                      ),
                    ),
                  );
                } catch (e) {
                  if (mounted) {
                    await ShowNotification.showToast(
                      context,
                      'Không thể mở cuộc trò chuyện',
                    );
                  }
                }
              },
              icon: Icon(Icons.message, color: Colors.white),
              label: Text('Nhắn tin', style: TextStyle(color: Colors.white)),
              backgroundColor: Color(0xFF7A2FC0),
            )
          : null,
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
              flexibleSpace: ProfileHeader(
                backgroundUrl: _user!.backgroundUrl,
                avatarUrl: _user!.avatarUrl,
                displayName: _user!.displayName,
                username: _user!.username,
                isOwnProfile: _isOwnProfile,
                tempAvatarPath: _tempAvatarPath,
                tempBackgroundPath: _tempBackgroundPath,
                onEditProfile: _navigateToEditProfile,
                onAvatarTap: () => _showImageOptions(true),
                onBackgroundTap: () => _showImageOptions(false),
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
                  ProfileComponents.buildStatisticsRow(
                    _friendCount,
                    _postCount,
                  ),

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
                        ProfileComponents.buildInfoRow(
                          Icons.email,
                          'Email',
                          _user!.email,
                        ),
                        if (_user!.createdAt != null)
                          ProfileComponents.buildInfoRow(
                            Icons.calendar_today,
                            'Ngày tham gia',
                            _formatJoinDate(_user!.createdAt!),
                          ),
                      ],
                    ),
                  ),

                  // Action buttons (if not own profile)
                  if (!_isOwnProfile) ...[
                    SizedBox(height: 20),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 15),
                      child: ProfileComponents.buildFriendButton(
                        context: context,
                        friendStatus: _friendStatus,
                        user: _user!,
                        userService: _userService,
                        refreshState: setState,
                        onFriendRequestSent: () async {
                          // Reload friend status after sending request
                          final currentUser = await _userService.getMe();
                          if (currentUser != null && _user != null) {
                            await _checkFriendStatus(currentUser, _user!);
                          }
                        },
                      ),
                    ),
                  ],

                  // Posts section with composer (own profile) or just posts (other profile)
                  SizedBox(height: 20),
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 15),
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header "Bài viết"
                        Row(
                          children: [
                            Icon(
                              Icons.article,
                              color: Color(0xFF7A2FC0),
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Bài viết',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 15),

                        // Post composer for own profile
                        if (_isOwnProfile) ...[
                          PostComposerWidget(
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CreatePostScreen(),
                                ),
                              );
                              if (result == true) {
                                // Reload profile to show new post
                                await _loadUserProfile();
                              }
                            },
                          ),
                          SizedBox(height: _posts.isNotEmpty ? 15 : 0),
                        ],

                        // Post cards
                        if (_posts.isNotEmpty)
                          ..._posts.map((post) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: EnhancedPostCard(
                                post: post,
                                onPostDeleted: _isOwnProfile
                                    ? () async {
                                        await _loadUserProfile();
                                      }
                                    : null,
                              ),
                            );
                          }).toList(),
                      ],
                    ),
                  ),

                  SizedBox(height: 100), // Bottom padding
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
