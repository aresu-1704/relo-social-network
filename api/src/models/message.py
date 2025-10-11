# Cấu trúc của collection Messages:
# {
#   "_id": "messageId_pqrst", // ID tin nhắn duy nhất (có thể là ObjectId)
#   "conversationId": "conversationId_xyz", // Liên kết đến collection 'conversations'
#   "senderId": "userId_12345", // Người gửi
#   "content": {
#     "text": "Xin chào!"
#   },
#   "createdAt": "2025-10-28T15:00:00Z" // Chuỗi ngày tháng ISO 8601
# }

from bson import ObjectId
from datetime import datetime
from .database import Database
from .conversation import Conversation

class Message:
    def __init__(self, conversationId, senderId, content, _id=None, createdAt=None):
        self._id = ObjectId(_id) if _id else ObjectId()
        self.conversationId = str(conversationId)
        self.senderId = str(senderId)
        self.content = content  # ví dụ: {'text': 'Xin chào!'}
        self.createdAt = createdAt if createdAt else datetime.utcnow()

    def to_dict(self):
        """Chuyển đổi đối tượng Message thành một từ điển cho MongoDB."""
        return {
            "conversationId": self.conversationId,
            "senderId": self.senderId,
            "content": self.content,
            "createdAt": self.createdAt,
        }

    def save(self):
        """
        Chèn tin nhắn mới và cập nhật lastMessage của cuộc trò chuyện cha.
        """
        messages_collection = Message.get_collection()
        result = messages_collection.insert_one(self.to_dict())
        self._id = result.inserted_id

        # Cập nhật lastMessage của cuộc trò chuyện
        conversation = Conversation.find_by_id(self.conversationId)
        if conversation:
            text_preview = self.content.get('text', '')
            conversation.update_last_message(self.senderId, text_preview)
        
        return result

    @staticmethod
    def get_collection():
        """Lấy collection messages từ cơ sở dữ liệu."""
        db = Database.get_database()
        if db is None:
            Database.connect()
            db = Database.get_database()
        return db['messages']

    @staticmethod
    def find_for_conversation(conversation_id, limit=50, skip=0):
        """Tìm tất cả các tin nhắn cho một cuộc trò chuyện, với phân trang, được sắp xếp theo thứ tự thời gian."""
        messages_collection = Message.get_collection()
        # Sắp xếp giảm dần để nhận được tin nhắn mới nhất, sau đó đảo ngược để hiển thị theo thứ tự thời gian
        messages_cursor = messages_collection.find(
            {'conversationId': str(conversation_id)}
        ).sort('createdAt', -1).skip(skip).limit(limit)
        
        # Đảo ngược danh sách để có tin nhắn cũ nhất trước tiên
        message_list = list(messages_cursor)
        return [Message(**msg) for msg in reversed(message_list)]