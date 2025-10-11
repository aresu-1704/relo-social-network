# Cấu trúc của collection Conversations:
# {
#   "_id": "conversationId_xyz", // ID cuộc trò chuyện duy nhất (có thể là ObjectId)
#   "participantIds": ["userId_12345", "userId_678"], // Mảng ID của những người tham gia
#   "lastMessage": { // Lưu tin nhắn cuối cùng để xem trước
#     "text": "Xin chào!",
#     "senderId": "userId_12345",
#     "timestamp": "2025-10-28T15:00:00Z"
#   },
#   "createdAt": "2025-10-28T14:55:00Z", // Chuỗi ngày tháng ISO 8601
#   "updatedAt": "2025-10-28T15:00:00Z" // Cập nhật khi có tin nhắn mới
# }

from bson import ObjectId
from datetime import datetime
from .database import Database

class Conversation:
    def __init__(self, participantIds, lastMessage=None, _id=None, createdAt=None, updatedAt=None):
        self._id = ObjectId(_id) if _id else ObjectId()
        self.participantIds = [str(p_id) for p_id in participantIds]
        self.lastMessage = lastMessage
        self.createdAt = createdAt if createdAt else datetime.utcnow()
        self.updatedAt = updatedAt if updatedAt else self.createdAt

    def to_dict(self):
        """Chuyển đổi đối tượng Conversation thành một từ điển cho MongoDB."""
        return {
            "participantIds": self.participantIds,
            "lastMessage": self.lastMessage,
            "createdAt": self.createdAt,
            "updatedAt": self.updatedAt,
        }

    def save(self):
        """Chèn hoặc cập nhật cuộc trò chuyện trong cơ sở dữ liệu."""
        conversations_collection = Conversation.get_collection()
        self.updatedAt = datetime.utcnow()
        conversations_collection.update_one(
            {'_id': self._id},
            {'$set': self.to_dict()},
            upsert=True
        )

    @staticmethod
    def get_collection():
        """Lấy collection conversations từ cơ sở dữ liệu."""
        db = Database.get_database()
        if db is None:
            Database.connect()
            db = Database.get_database()
        return db['conversations']

    @staticmethod
    def find_by_id(conversation_id):
        """Tìm một cuộc trò chuyện bằng ID của nó."""
        try:
            cid = ObjectId(conversation_id)
        except Exception:
            return None
        conversations_collection = Conversation.get_collection()
        convo_data = conversations_collection.find_one({'_id': cid})
        return Conversation(**convo_data) if convo_data else None

    @staticmethod
    def find_by_participants(participant_ids):
        """Tìm một cuộc trò chuyện với một nhóm người tham gia cụ thể."""
        string_ids = [str(p_id) for p_id in participant_ids]
        conversations_collection = Conversation.get_collection()
        convo_data = conversations_collection.find_one({
            'participantIds': {
                '$all': string_ids,
                '$size': len(string_ids)
            }
        })
        return Conversation(**convo_data) if convo_data else None

    @staticmethod
    def find_for_user(user_id, limit=30, skip=0):
        """Tìm tất cả các cuộc trò chuyện mà một người dùng tham gia, được sắp xếp theo hoạt động gần đây."""
        conversations_collection = Conversation.get_collection()
        convos_cursor = conversations_collection.find(
            {'participantIds': str(user_id)}
        ).sort('updatedAt', -1).skip(skip).limit(limit)
        return [Conversation(**convo) for convo in convos_cursor]

    def update_last_message(self, sender_id, text):
        """Cập nhật tin nhắn cuối cùng và dấu thời gian."""
        self.lastMessage = {
            "text": text,
            "senderId": str(sender_id),
            "timestamp": datetime.utcnow()
        }
        self.updatedAt = self.lastMessage["timestamp"]
        self.save()