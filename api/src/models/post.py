# Cấu trúc của collection Posts:
# {
#   "_id": "postId_abcde", // ID bài đăng duy nhất (có thể là ObjectId)
#   "authorId": "userId_12345", // ID của tác giả, liên kết đến collection 'users'
#   "authorInfo": { // Thông tin tác giả được phi chuẩn hóa để hiển thị nhanh
#     "displayName": "Nguyễn Văn A",
#     "avatarUrl": "https://example.com/path/to/avatar.jpg"
#   },
#   "content": "Đây là bài đăng đầu tiên của tôi!", // Nội dung bài đăng (văn bản)
#   "mediaUrls": [ // Mảng các URL hình ảnh/video
#     "https://example.com/path/to/image1.jpg"
#   ],
#   "reactions": [ // Mảng thông tin về các phản ứng
#     {
#       "userId": "userId_678",
#       "type": "like" // hoặc "heart"
#     }
#   ],
#   "reactionCounts": { // Tổng số lượng cho các truy vấn nhanh
#       "like": 1,
#       "heart": 1
#   },
#   "commentCount": 5, // Số lượng bình luận
#   "createdAt": "2025-10-28T09:00:00Z" // Chuỗi ngày tháng ISO 8601
# }

from bson import ObjectId
from datetime import datetime
from .database import Database

class Post:
    def __init__(self, authorId, authorInfo, content, mediaUrls=None, reactions=None, reactionCounts=None, commentCount=0, _id=None, createdAt=None):
        self._id = ObjectId(_id) if _id else ObjectId()
        self.authorId = authorId
        self.authorInfo = authorInfo
        self.content = content
        self.mediaUrls = mediaUrls if mediaUrls is not None else []
        self.reactions = reactions if reactions is not None else []
        self.reactionCounts = reactionCounts if reactionCounts is not None else {}
        self.commentCount = commentCount
        self.createdAt = createdAt if createdAt else datetime.utcnow()

    def to_dict(self):
        """Chuyển đổi đối tượng Post thành một từ điển cho MongoDB."""
        return {
            "authorId": self.authorId,
            "authorInfo": self.authorInfo,
            "content": self.content,
            "mediaUrls": self.mediaUrls,
            "reactions": self.reactions,
            "reactionCounts": self.reactionCounts,
            "commentCount": self.commentCount,
            "createdAt": self.createdAt,
        }

    def save(self):
        """Chèn hoặc cập nhật bài đăng trong cơ sở dữ liệu."""
        posts_collection = Post.get_collection()
        posts_collection.update_one(
            {'_id': self._id},
            {'$set': self.to_dict()},
            upsert=True
        )

    @staticmethod
    def get_collection():
        """Lấy collection posts từ cơ sở dữ liệu."""
        db = Database.get_database()
        if db is None:
            Database.connect()
            db = Database.get_database()
        return db['posts']

    @staticmethod
    def find_by_id(post_id):
        """Tìm một bài đăng bằng ID của nó."""
        try:
            pid = ObjectId(post_id)
        except Exception:
            return None
        posts_collection = Post.get_collection()
        post_data = posts_collection.find_one({'_id': pid})
        return Post(**post_data) if post_data else None

    @staticmethod
    def find_by_author(author_id, limit=20, skip=0):
        """Tìm tất cả các bài đăng của một tác giả cụ thể, với phân trang."""
        posts_collection = Post.get_collection()
        posts_cursor = posts_collection.find({'authorId': str(author_id)}).sort('createdAt', -1).skip(skip).limit(limit)
        return [Post(**post_data) for post_data in posts_cursor]

    def delete(self):
        """Xóa bài đăng khỏi cơ sở dữ liệu."""
        posts_collection = Post.get_collection()
        posts_collection.delete_one({'_id': self._id})

    def add_reaction(self, user_id, reaction_type):
        """Thêm hoặc cập nhật một phản ứng từ một người dùng."""
        str_user_id = str(user_id)
        # Đầu tiên, xóa mọi phản ứng hiện có của người dùng này để cho phép thay đổi phản ứng
        self.remove_reaction(str_user_id, update_db=False)

        # Thêm phản ứng mới
        self.reactions.append({'userId': str_user_id, 'type': reaction_type})
        self.reactionCounts[reaction_type] = self.reactionCounts.get(reaction_type, 0) + 1
        self.save()

    def remove_reaction(self, user_id, update_db=True):
        """Xóa một phản ứng từ một người dùng."""
        str_user_id = str(user_id)
        reaction_to_remove = None
        for reaction in self.reactions:
            if reaction.get('userId') == str_user_id:
                reaction_to_remove = reaction
                break
        
        if reaction_to_remove:
            reaction_type = reaction_to_remove['type']
            self.reactions.remove(reaction_to_remove)
            
            if reaction_type in self.reactionCounts:
                self.reactionCounts[reaction_type] -= 1
                if self.reactionCounts[reaction_type] == 0:
                    del self.reactionCounts[reaction_type]
            
            if update_db:
                self.save()