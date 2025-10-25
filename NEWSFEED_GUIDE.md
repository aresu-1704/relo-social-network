# 📰 NewsFeed Feature - Hướng dẫn sử dụng

## 🎯 Tổng quan

Hệ thống NewsFeed đã được tích hợp đầy đủ với các tính năng:

### ✨ Tính năng chính

1. **Đăng bài viết**
   - Đăng text
   - Đăng hình ảnh (nhiều ảnh)
   - Preview trước khi đăng
   - Upload lên Cloudinary

2. **Xem bài viết**
   - Hiển thị avatar + tên + thời gian
   - Hiển thị nội dung text
   - Hiển thị ảnh (swipe nếu nhiều ảnh)
   - Pagination (load more)
   - Pull to refresh

3. **Thả cảm xúc (Reactions)**
   - 6 loại: 👍 Like, ❤️ Love, 😂 Haha, 😮 Wow, 😢 Sad, 😡 Angry
   - Hiển thị số lượng reactions
   - Bottom sheet chọn reaction

4. **Bình luận (Comments)**
   - Viết bình luận
   - Xem danh sách bình luận
   - Hiển thị avatar + tên người bình luận
   - Thời gian bình luận
   - Số lượng bình luận

---

## 🔧 Cấu trúc Code

### **Backend (API)**

#### Models
```
api/src/models/
├── post.py         # Post, AuthorInfo, Reaction, MediaItem
└── comment.py      # Comment
```

#### Schemas
```
api/src/schemas/
├── post_schema.py     # PostCreate, PostPublic, ReactionCreate
└── comment_schema.py  # CommentCreate, CommentPublic
```

#### Services
```
api/src/services/
└── post_service.py
    ├── create_post()           # Tạo bài viết
    ├── get_post_feed()         # Lấy feed
    ├── react_to_post()         # Thả reaction
    ├── delete_post()           # Xóa bài viết
    ├── create_comment()        # Tạo comment
    └── get_comments()          # Lấy comments
```

#### Endpoints
```
POST   /api/posts                      # Tạo bài viết
GET    /api/posts/feed                 # Lấy feed
POST   /api/posts/{post_id}/react      # Thả reaction
DELETE /api/posts/{post_id}            # Xóa bài viết
POST   /api/posts/{post_id}/comments   # Tạo comment
GET    /api/posts/{post_id}/comments   # Lấy comments
```

### **Frontend (Flutter)**

#### Models
```
lib/models/
├── post.dart       # Post model
├── comment.dart    # Comment model
├── author_info.dart
└── reaction.dart
```

#### Services
```
lib/services/
└── post_service.dart
    ├── getFeed()        # Lấy danh sách bài viết
    ├── createPost()     # Tạo bài viết mới
    ├── reactToPost()    # Thả reaction
    ├── createComment()  # Tạo comment
    ├── getComments()    # Lấy comments
    └── deletePost()     # Xóa bài viết
```

#### Screens
```
lib/screen/
├── newsfeed_screen.dart      # Màn hình chính feed
├── create_post_screen.dart   # Màn hình tạo bài viết
└── comments_screen.dart      # Màn hình bình luận
```

#### Widgets
```
lib/widgets/
├── enhanced_post_card.dart   # Card bài viết đầy đủ tính năng
└── post_card.dart           # Wrapper cho EnhancedPostCard
```

---

## 🚀 Cách sử dụng

### 1. **Truy cập NewsFeed**
- Mở app → Tab "Tường nhà" (icon LayoutGrid)
- Feed sẽ tự động load 20 bài viết đầu tiên

### 2. **Tạo bài viết mới**
- Click nút "+" (FloatingActionButton) ở góc dưới phải
- Hoặc click "Tạo bài viết đầu tiên" nếu chưa có bài viết
- Nhập nội dung
- (Tùy chọn) Click icon ảnh để thêm hình
- Click "Đăng"

### 3. **Thả cảm xúc**
- Click nút "Thích" trên bài viết
- Chọn emoji từ bottom sheet
- Reaction sẽ được cập nhật real-time

### 4. **Bình luận**
- Click nút "Bình luận" trên bài viết
- Nhập nội dung bình luận
- Click icon gửi
- Comment xuất hiện ngay lập tức

### 5. **Xem thêm bài viết**
- Scroll xuống cuối feed
- Hệ thống tự động load thêm 20 bài viết tiếp theo

### 6. **Refresh feed**
- Kéo xuống từ đầu feed (pull to refresh)
- Feed sẽ reload từ đầu

---

## 📊 Database Schema

### Posts Collection
```json
{
  "_id": "ObjectId",
  "authorId": "string",
  "authorInfo": {
    "displayName": "string",
    "avatarUrl": "string"
  },
  "content": "string",
  "media": [
    {
      "url": "string",
      "publicId": "string",
      "type": "image|video"
    }
  ],
  "reactions": [
    {
      "userId": "string",
      "type": "like|love|haha|wow|sad|angry"
    }
  ],
  "reactionCounts": {
    "like": 5,
    "love": 3
  },
  "commentCount": 10,
  "createdAt": "datetime"
}
```

### Comments Collection
```json
{
  "_id": "ObjectId",
  "postId": "string",
  "userId": "string",
  "content": "string",
  "createdAt": "datetime"
}
```

---

## 🎨 UI/UX Features

### PostCard
- **Header**: Avatar tròn (20px) + Tên (bold) + Thời gian
- **Content**: Text với line-height 1.4
- **Media**: Hình ảnh full-width, swipeable nếu nhiều ảnh
- **Stats**: Emoji reactions + số lượng, số comments
- **Actions**: 3 nút - Thích / Bình luận / Chia sẻ

### CreatePostScreen
- TextField đa dòng cho nội dung
- Grid 2 cột hiển thị ảnh đã chọn
- Nút X để xóa từng ảnh
- Bottom toolbar với nút thêm ảnh
- AppBar với nút "Đăng"

### CommentsScreen
- Preview bài viết ở đầu
- Danh sách comments cuộn được
- Input comment cố định ở dưới
- Avatar + bubble comment (giống Messenger)
- Thời gian hiển thị dưới mỗi comment

---

## 🔄 Data Flow

### Tạo bài viết
```
User input → CreatePostScreen
  ↓
Convert images to base64
  ↓
POST /api/posts
  ↓
Backend upload to Cloudinary
  ↓
Save to MongoDB
  ↓
Return PostPublic
  ↓
Refresh feed
```

### Thả reaction
```
User click → Bottom sheet
  ↓
Select emoji
  ↓
POST /api/posts/{id}/react
  ↓
Backend update reactions & counts
  ↓
Return updated Post
  ↓
Update UI (setState)
```

### Bình luận
```
User type → TextField
  ↓
Click send
  ↓
POST /api/posts/{id}/comments
  ↓
Backend save comment
  ↓
Increment post.commentCount
  ↓
Return CommentPublic
  ↓
Insert to comments list
```

---

## 🐛 Troubleshooting

### Lỗi "Failed to fetch feed"
- Kiểm tra backend đang chạy
- Kiểm tra `constants.dart` có đúng IP không
- Kiểm tra token còn valid không

### Ảnh không hiển thị
- Kiểm tra Cloudinary credentials trong `.env`
- Kiểm tra network connectivity
- Xem logs backend để check upload errors

### Comments không load
- Kiểm tra `post_id` có đúng không
- Kiểm tra Comment model đã được thêm vào `init_db`
- Restart backend để apply schema changes

---

## 📝 TODO / Future Enhancements

- [ ] Video upload & playback
- [ ] Share posts
- [ ] Delete comments
- [ ] Edit posts
- [ ] Post visibility (public/friends/private)
- [ ] Hashtags
- [ ] Mention users (@username)
- [ ] Notifications cho comments và reactions
- [ ] Report/Block posts
- [ ] Save posts
- [ ] Stories feature

---

## 🎓 Code Examples

### Sử dụng PostService
```dart
final postService = ServiceLocator.postService;

// Lấy feed
final posts = await postService.getFeed(skip: 0, limit: 20);

// Tạo post
final newPost = await postService.createPost(
  content: 'Hello World!',
  mediaBase64: ['data:image/jpeg;base64,...'],
);

// Thả reaction
final updatedPost = await postService.reactToPost(
  postId: '123',
  reactionType: 'love',
);

// Tạo comment
final comment = await postService.createComment(
  postId: '123',
  content: 'Nice post!',
);
```

### Custom PostCard
```dart
PostCard(
  post: myPost,
  onPostUpdated: () {
    // Callback khi post được update (reaction, comment, etc.)
    _refreshFeed();
  },
)
```

---

## 📚 Dependencies

### Backend
- `cloudinary` - Media storage
- `beanie` - MongoDB ODM
- `fastapi` - Web framework

### Frontend
- `cached_network_image` - Image caching
- `image_picker` - Pick images
- `lucide_icons` - Icons
- `intl` - Date formatting

---

**Tác giả**: Relo Development Team  
**Phiên bản**: 1.0.0  
**Ngày cập nhật**: 23/10/2025
