from beanie import Document
from pydantic import Field
from datetime import datetime, timedelta

class Comment(Document):
    """
    Đại diện cho một bình luận trong một bài đăng.
    """
    postId: str = Field(..., description="ID của bài đăng chứa bình luận này.")
    userId: str = Field(..., description="ID của người bình luận.")
    content: str = Field(..., description="Nội dung bình luận.")
    createdAt: datetime = Field(default_factory=lambda: datetime.utcnow() + timedelta(hours=7), description="Thời điểm bình luận được tạo.")

    class Settings:
        name = "comments"
        indexes = [
            "postId",
            "createdAt",
        ]
