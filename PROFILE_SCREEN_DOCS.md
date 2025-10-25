# 📱 TRANG CÁ NHÂN NGƯỜI DÙNG - TÀI LIỆU

## 📋 TỔNG QUAN

### File chính
- **Path:** `lib/screen/profile_screen.dart`
- **Lines of code:** 1,395 dòng
- **Pattern:** StatefulWidget với State management

### 2 Chế độ hoạt động

#### A. Own Profile (`_isOwnProfile = true`)
- ✅ Chỉnh sửa thông tin (tên, bio)
- ✅ Đổi ảnh đại diện và ảnh bìa
- ✅ Xem mã QR cá nhân
- ✅ Truy cập Quyền riêng tư
- ✅ Pull-to-refresh

#### B. Other Profile (`_isOwnProfile = false`)
- ✅ Xem thông tin public
- ✅ Gửi lời mời kết bạn
- ✅ Nhắn tin trực tiếp
- ✅ Chặn người dùng
- ❌ Không thể chỉnh sửa

---

## 🏗️ KIẾN TRÚC

### Tech Stack
```
Flutter (Dart) 
    ↓ Dio HTTP
Backend API (Node.js)
    ↓
MongoDB + Cloudinary
```

### Dependencies
```yaml
dio: ^5.4.0                    # HTTP client
cached_network_image: ^3.3.0   # Cache ảnh
image_picker: ^1.0.7           # Chọn ảnh
permission_handler: ^11.2.0    # Quyền
pull_to_refresh: ^2.0.0        # Refresh
shimmer: ^3.0.0                # Loading
qr_flutter: ^4.1.0             # QR code
flutter_animate: ^4.5.0        # Animations
```

---

## 🎯 LUỒNG KHỞI TẠO

```
1. Navigator.push(ProfileScreen(userId: null/id))
        ↓
2. initState() → _loadUserProfile()
        ↓
3. userId == null ? getMe() : getUserById(id)
        ↓
4. _checkFriendStatus() (nếu other profile)
        ↓
5. _loadStatistics()
        ↓
6. setState() → UI rebuild
```

---

## 🧩 CLASS STRUCTURE

### ProfileScreen Widget
```dart
class ProfileScreen extends StatefulWidget {
  final String? userId; // null = own profile
  
  const ProfileScreen({super.key, this.userId});
}
```

### State Variables
```dart
// Services
final UserService _userService;
final MessageService _messageService;

// Data
User? _user;
bool _isLoading = true;
bool _isOwnProfile = false;

// Image handling
String? _tempAvatarPath;
String? _tempBackgroundPath;

// Statistics
int _friendCount = 0;
int _postCount = 0;
bool _isFriend = false;
bool _hasPendingRequest = false;
```

---

## 📸 UPLOAD ẢNH FLOW

```
1. Check permission
    ↓
2. Pick image (gallery/camera)
    ↓
3. Show preview local (_tempPath)
    ↓
4. Validate size (max 5MB avatar, 8MB cover)
    ↓
5. Convert to base64
    ↓
6. POST /users/update-avatar
    ↓
7. Backend upload to Cloudinary
    ↓
8. Get new URL
    ↓
9. Clear cache + Update UI
```

### Code Example
```dart
Future<void> _pickAndUpdateAvatar() async {
  // 1. Check permission
  final hasPermission = await PermissionHandlerUtil
      .requestCameraPermission(context);
  
  // 2. Pick image
  final image = await _imagePicker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 1024,
    imageQuality: 90,
  );
  
  // 3. Preview
  setState(() => _tempAvatarPath = image.path);
  
  // 4. Convert to base64
  final bytes = await File(image.path).readAsBytes();
  final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
  
  // 5. Upload
  final updatedUser = await _userService.updateAvatar(base64Image);
  
  // 6. Update UI
  setState(() {
    _user = updatedUser;
    _tempAvatarPath = null;
  });
}
```

---

## 🎨 UI STRUCTURE

```
Scaffold
└── SmartRefresher
    └── CustomScrollView
        ├── SliverAppBar (Header)
        │   ├── Background Image
        │   ├── Avatar + Name
        │   └── Edit Button
        │
        └── SliverToBoxAdapter
            ├── Bio Card
            ├── Statistics Row
            ├── Account Info Card
            ├── Privacy Button (own)
            └── Action Buttons (other)
```

---

## 🌐 API ENDPOINTS

### GET /users/me
**Purpose:** Lấy thông tin user hiện tại  
**Auth:** JWT token required  
**Response:**
```json
{
  "id": "507f1f77bcf86cd799439011",
  "username": "john_doe",
  "email": "john@example.com",
  "displayName": "John Doe",
  "avatarUrl": "https://res.cloudinary.com/.../avatar.jpg",
  "backgroundUrl": "https://res.cloudinary.com/.../bg.jpg",
  "bio": "Software Developer"
}
```

### GET /users/:userId
**Purpose:** Lấy thông tin user khác  
**Auth:** JWT token required  
**Response:** User object (public info)

### POST /users/update-avatar
**Purpose:** Upload ảnh đại diện  
**Body:**
```json
{
  "avatar": "data:image/jpeg;base64,/9j/4AAQSkZJRg..."
}
```
**Process:**
1. Decode base64
2. Upload to Cloudinary
3. Update MongoDB
4. Return updated user

---

## 🔐 PERMISSION HANDLING

```dart
// Request camera permission
final hasPermission = await PermissionHandlerUtil
    .requestCameraPermission(context);

// If denied → show dialog with "Mở Cài đặt" button
// If permanently denied → direct to app settings
```

---

## 💡 KỸ THUẬT NỔI BẬT

### 1. Optimistic UI
```dart
setState(() {
  _tempAvatarPath = image.path; // Hiện ngay
});
// ... upload ...
setState(() {
  _tempAvatarPath = null; // Load từ server
});
```

### 2. Cache Management
```dart
await CachedNetworkImage.evictFromCache(url);
PaintingBinding.instance.imageCache.clear();
```

### 3. Retry Mechanism
```dart
for (int i = 0; i < 3; i++) {
  try {
    await precacheImage(provider, context);
    break;
  } catch (e) {
    if (i == 2) print('Failed after 3 attempts');
    await Future.delayed(Duration(milliseconds: 500));
  }
}
```

### 4. Loading States
```dart
if (_isLoading) {
  return Shimmer.fromColors(/* skeleton */);
}
```

---

## 📊 USER MODEL

```dart
class User {
  final String id;           // MongoDB ObjectId
  final String username;     // Unique
  final String email;
  final String displayName;
  final String? avatarUrl;   // Cloudinary URL
  final String? backgroundUrl;
  final String? bio;         // Max 150 chars
  
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      displayName: json['displayName'],
      avatarUrl: json['avatarUrl'],
      backgroundUrl: json['backgroundUrl'],
      bio: json['bio'],
    );
  }
}
```

---

## 🔧 SERVICE LOCATOR PATTERN

```dart
class ServiceLocator {
  static final UserService userService = UserService(_dio);
  static final MessageService messageService = MessageService(_dio);
  
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.relo.social/',
      headers: {
        'Authorization': 'Bearer ${token}',
      },
    ),
  );
}
```

---

## ⚡ PERFORMANCE OPTIMIZATIONS

1. **Image caching:** CachedNetworkImageProvider
2. **Lazy loading:** ListView.builder
3. **Debouncing:** TextEditingController với timer
4. **Precaching:** Prefetch images before display
5. **Compression:** maxWidth, maxHeight, imageQuality
6. **Pull-to-refresh:** SmartRefresher với lazy load

---

## 🎓 GIẢI THÍCH CHO THẦY

**Q: Trang cá nhân chạy từ đâu?**  
A: Entry point là Navigator.push() → initState() → _loadUserProfile() → API call → setState() → UI render

**Q: Làm sao phân biệt profile của mình vs người khác?**  
A: Dựa vào parameter `userId`. Nếu null → own profile. Nếu có giá trị → so sánh với current user ID

**Q: Upload ảnh hoạt động thế nào?**  
A: Pick image → Convert base64 → POST to backend → Backend upload Cloudinary → Trả về URL → Clear cache → Update UI

**Q: Hạ tầng như thế nào?**  
A: Flutter (Dio) → Node.js API (Express) → MongoDB (data) + Cloudinary (images)

**Q: Code có gì đặc biệt?**  
A: Optimistic UI, Cache management, Permission handling, Service pattern, Retry mechanism

---

**📅 Ngày tạo:** 25/10/2025  
**👨‍💻 Dự án:** Relo Social Network  
**🎯 Mục đích:** Tài liệu kỹ thuật cho báo cáo và demo
