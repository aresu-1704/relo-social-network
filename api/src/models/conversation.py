from beanie import Document
from pydantic import Field, BaseModel
from typing import Optional, List
from datetime import datetime

class LastMessage(BaseModel):
    """Lưu trữ thông tin xem trước của tin nhắn cuối cùng trong cuộc trò chuyện."""
    text: str
    senderId: str
    timestamp: datetime

class Conversation(Document):
    """
    Đại diện cho một cuộc trò chuyện trong collection 'conversations'.
    """
    participantIds: List[str] = Field(..., description="Danh sách ID của những người tham gia.")
    lastMessage: Optional[LastMessage] = Field(default=None, description="Tin nhắn cuối cùng để xem trước.")
    createdAt: datetime = Field(default_factory=datetime.utcnow, description="Thời điểm cuộc trò chuyện được tạo.")
    updatedAt: datetime = Field(default_factory=datetime.utcnow, description="Thời điểm có tin nhắn mới.")

    class Settings:
        name = "conversations"
        indexes = [
            "participantIds",
            "updatedAt",
        ]
