# Cấu trúc của collection Friend Requests:
# {
#   "_id": "requestId_zyxw", // ID yêu cầu duy nhất (có thể là ObjectId)
#   "fromUserId": "userId_910", // ID của người gửi
#   "toUserId": "userId_12345", // ID của người nhận
#   "status": "pending", // Trạng thái: 'pending' (đang chờ), 'accepted' (đã chấp nhận), 'rejected' (đã từ chối)
#   "createdAt": "2025-10-28T11:00:00Z" // Chuỗi ngày tháng ISO 8601
# }

from bson import ObjectId
from datetime import datetime
from .database import Database
from .user import User

class FriendRequest:
    def __init__(self, fromUserId, toUserId, status='pending', _id=None, createdAt=None):
        self._id = ObjectId(_id) if _id else ObjectId()
        self.fromUserId = str(fromUserId)
        self.toUserId = str(toUserId)
        self.status = status
        self.createdAt = createdAt if createdAt else datetime.utcnow()

    def to_dict(self):
        """Chuyển đổi đối tượng FriendRequest thành một từ điển cho MongoDB."""
        return {
            "fromUserId": self.fromUserId,
            "toUserId": self.toUserId,
            "status": self.status,
            "createdAt": self.createdAt,
        }

    def save(self):
        """Chèn hoặc cập nhật yêu cầu kết bạn trong cơ sở dữ liệu."""
        requests_collection = FriendRequest.get_collection()
        requests_collection.update_one(
            {'_id': self._id},
            {'$set': self.to_dict()},
            upsert=True
        )

    @staticmethod
    def get_collection():
        """Lấy collection friendRequests từ cơ sở dữ liệu."""
        db = Database.get_database()
        if db is None:
            Database.connect()
            db = Database.get_database()
        return db['friendRequests']

    @staticmethod
    def find_by_id(request_id):
        """Tìm một yêu cầu kết bạn bằng ID của nó."""
        try:
            rid = ObjectId(request_id)
        except Exception:
            return None
        requests_collection = FriendRequest.get_collection()
        request_data = requests_collection.find_one({'_id': rid})
        return FriendRequest(**request_data) if request_data else None

    @staticmethod
    def find_pending_for_user(user_id):
        """Tìm tất cả các yêu cầu kết bạn đang chờ xử lý cho một người dùng nhất định."""
        requests_collection = FriendRequest.get_collection()
        requests_cursor = requests_collection.find({
            'toUserId': str(user_id),
            'status': 'pending'
        }).sort('createdAt', -1)
        return [FriendRequest(**req) for req in requests_cursor]

    def accept(self):
        """Chấp nhận yêu cầu kết bạn và cập nhật danh sách bạn bè của người dùng."""
        if self.status == 'pending':
            from_user = User.find_by_id(self.fromUserId)
            to_user = User.find_by_id(self.toUserId)

            if from_user and to_user:
                from_user.add_friend(self.toUserId)
                to_user.add_friend(self.fromUserId)
                
                self.status = 'accepted'
                self.save()
                return True
        return False

    def reject(self):
        """Từ chối yêu cầu kết bạn."""
        if self.status == 'pending':
            self.status = 'rejected'
            self.save()
            return True
        return False