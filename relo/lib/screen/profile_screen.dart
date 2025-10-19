import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:relo/models/user.dart';
import 'package:relo/services/service_locator.dart';
import 'package:relo/services/user_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';

class ProfileScreen extends StatefulWidget {
  final String? userId; // Null means current user
  
  const ProfileScreen({Key? key, this.userId}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = ServiceLocator.userService;
  User? _user;
  bool _isLoading = true;
  bool _isOwnProfile = false;
  final ImagePicker _imagePicker = ImagePicker();
  
  // Controllers cho edit
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
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
      }
      
      setState(() {
        _user = user;
        _isLoading = false;
        if (user != null) {
          _displayNameController.text = user.displayName;
          _bioController.text = user.bio ?? '';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Không thể tải thông tin người dùng');
    }
  }

  Future<void> _pickAndUpdateAvatar() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    
    if (image != null) {
      try {
        _showLoadingDialog('Đang cập nhật ảnh đại diện...');
        
        // Convert to base64
        final bytes = await File(image.path).readAsBytes();
        final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        
        await _userService.updateAvatar(base64Image);
        
        Navigator.pop(context); // Close loading dialog
        await _loadUserProfile(); // Reload profile
        _showSuccess('Cập nhật ảnh đại diện thành công');
      } catch (e) {
        Navigator.pop(context); // Close loading dialog
        _showError('Không thể cập nhật ảnh đại diện');
      }
    }
  }

  Future<void> _pickAndUpdateBackground() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 600,
      imageQuality: 85,
    );
    
    if (image != null) {
      try {
        _showLoadingDialog('Đang cập nhật ảnh bìa...');
        
        // Convert to base64
        final bytes = await File(image.path).readAsBytes();
        final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        
        await _userService.updateBackground(base64Image);
        
        Navigator.pop(context); // Close loading dialog
        await _loadUserProfile(); // Reload profile
        _showSuccess('Cập nhật ảnh bìa thành công');
      } catch (e) {
        Navigator.pop(context); // Close loading dialog
        _showError('Không thể cập nhật ảnh bìa');
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
            ListTile(
              leading: Icon(Icons.photo_library, color: Color(0xFF7C3AED)),
              title: Text('Chọn từ thư viện'),
              onTap: () {
                Navigator.pop(context);
                if (isAvatar) {
                  _pickAndUpdateAvatar();
                } else {
                  _pickAndUpdateBackground();
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
        ),
      ),
    );
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(imageUrl),
            ),
          ),
        ),
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
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
        ),
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
      body: CustomScrollView(
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
                      height: 200,
                      decoration: BoxDecoration(
                        image: _user!.backgroundUrl != null
                            ? DecorationImage(
                                image: NetworkImage(_user!.backgroundUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                        gradient: _user!.backgroundUrl == null
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
                      child: _isOwnProfile && _user!.backgroundUrl == null
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
                                CircleAvatar(
                                  radius: 45,
                                  backgroundColor: Colors.white,
                                  child: CircleAvatar(
                                    radius: 43,
                                    backgroundImage: _user!.avatarUrl != null
                                        ? NetworkImage(_user!.avatarUrl!)
                                        : null,
                                    child: _user!.avatarUrl == null
                                        ? Icon(
                                            Icons.person,
                                            size: 50,
                                            color: Colors.grey,
                                          )
                                        : null,
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
                            onPressed: () {
                              // TODO: Send message
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
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                await _userService.sendFriendRequest(_user!.id);
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
                          ),
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
