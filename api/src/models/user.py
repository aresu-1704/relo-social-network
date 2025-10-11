# Cấu trúc của collection Users:
# {
#   "_id": "userId_12345", // ID người dùng duy nhất (có thể là ObjectId)
#   "username": "nguyenvana", // Tên đăng nhập, phải là duy nhất
#   "email": "nguyenvana@email.com", // Email, cũng phải là duy nhất
#   "hashedPassword": "a_very_long_hashed_string", // Mật khẩu đã được băm
#   "salt": "a_random_salt_string", // Salt để băm mật khẩu
#   "displayName": "Nguyễn Văn A", // Tên hiển thị
#   "avatarUrl": "https://example.com/path/to/avatar.jpg", // URL ảnh đại diện
#   "bio": "Thích lập trình và du lịch.", // Tiểu sử ngắn
#   "friendIds": ["userId_678", "userId_910"], // Mảng ID của bạn bè
#   "createdAt": "2025-10-27T10:00:00Z", // Chuỗi ngày tháng ISO 8601
#   "updatedAt": "2025-10-27T12:30:00Z" // Chuỗi ngày tháng ISO 8601
# }

from bson import ObjectId
from datetime import datetime
from .database import Database

class User:
    def __init__(self, username, email, hashedPassword, salt, displayName, avatarUrl="", bio="", friendIds=None, _id=None, createdAt=None, updatedAt=None):
        self._id = ObjectId(_id) if _id else ObjectId()
        self.username = username
        self.email = email
        self.hashedPassword = hashedPassword
        self.salt = salt
        self.displayName = displayName
        self.avatarUrl = avatarUrl
        self.bio = bio
        self.friendIds = friendIds if friendIds is not None else []
        self.createdAt = createdAt if createdAt else datetime.utcnow()
        self.updatedAt = updatedAt if updatedAt else datetime.utcnow()

    def to_dict(self):
        """Chuyển đổi đối tượng User thành một từ điển cho MongoDB."""
        return {
            #'_id': self._id, # Không bao gồm _id trong tập hợp cập nhật, nó là định danh
            "username": self.username,
            "email": self.email,
            "hashedPassword": self.hashedPassword,
            "salt": self.salt,
            "displayName": self.displayName,
            "avatarUrl": self.avatarUrl,
            "bio": self.bio,
            "friendIds": self.friendIds,
            "createdAt": self.createdAt,
            "updatedAt": self.updatedAt
        }

    def save(self):
        """Chèn hoặc cập nhật người dùng trong cơ sở dữ liệu."""
        users_collection = User.get_collection()
        self.updatedAt = datetime.utcnow()
        users_collection.update_one(
            {'_id': self._id},
            {'$set': self.to_dict()},
            upsert=True
        )

    @staticmethod
    def get_collection():
        """Lấy collection users từ cơ sở dữ liệu."""
        db = Database.get_database()
        if db is None:
            Database.connect()
            db = Database.get_database()
        return db['users']

    @staticmethod
    def find_by_id(user_id):
        """Tìm một người dùng bằng ID của họ."""
        try:
            uid = ObjectId(user_id)
        except Exception:
            return None
        users_collection = User.get_collection()
        user_data = users_collection.find_one({'_id': uid})
        return User(**user_data) if user_data else None

    @staticmethod
    def find_by_username(username):
        """Tìm một người dùng bằng tên người dùng của họ."""
        users_collection = User.get_collection()
        user_data = users_collection.find_one({'username': username})
        return User(**user_data) if user_data else None

    @staticmethod
    def find_by_email(email):
        """Tìm một người dùng bằng email của họ."""
        users_collection = User.get_collection()
        user_data = users_collection.find_one({'email': email})
        return User(**user_data) if user_data else None

    def delete(self):
        """Xóa người dùng khỏi cơ sở dữ liệu."""
        users_collection = User.get_collection()
        users_collection.delete_one({'_id': self._id})

    def add_friend(self, friend_id):
        """Thêm một người bạn vào danh sách bạn bè của người dùng."""
        # Đảm bảo friend_id là một chuỗi
        friend_id_str = str(friend_id)
        if friend_id_str not in self.friendIds:
            self.friendIds.append(friend_id_str)
            self.save()

    def remove_friend(self, friend_id):
        """Xóa một người bạn khỏi danh sách bạn bè của người dùng."""
        # Đảm bảo friend_id là một chuỗi
        friend_id_str = str(friend_id)
        if friend_id_str in self.friendIds:
            self.friendIds.remove(friend_id_str)
            self.save()