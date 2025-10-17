from beanie import Document
from pydantic import Field, BaseModel
from typing import Optional, List
from datetime import datetime

class LastMessage(BaseModel):
    """Lưu trữ thông tin xem trước của tin nhắn cuối cùng trong cuộc trò chuyện."""
    content: dict
    senderId: str
    createdAt: datetime

class Conversation(Document):
    """
    Đại diện cho một cuộc trò chuyện trong collection 'conversations'.
    """
    participantIds: List[str] = Field(..., description="Danh sách ID của những người tham gia.")
    lastMessage: Optional[LastMessage] = Field(default=None, description="Tin nhắn cuối cùng để xem trước.")
    createdAt: datetime = Field(default_factory=datetime.utcnow, description="Thời điểm cuộc trò chuyện được tạo.")
    updatedAt: datetime = Field(default_factory=datetime.utcnow, description="Thời điểm có tin nhắn mới.")
    seenIds: List[str] = Field(default_factory=list, description="Danh sách ID của những người đã xem tin nhắn cuối cùng.")

    class Settings:
        name = "conversations"
        indexes = [
            "participantIds",
            "updatedAt",
            "seenIds",
        ]
