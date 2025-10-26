from beanie import Document
from pydantic import Field, BaseModel
from typing import Optional, List, Dict
from datetime import datetime

class AuthorInfo(BaseModel):
    """Thông tin tác giả được phi chuẩn hóa để hiển thị nhanh."""
    displayName: str
    avatarUrl: Optional[str] = ""

class Reaction(BaseModel):
    """Đại diện cho một phản ứng từ người dùng."""
    userId: str
    type: str

class Comment(BaseModel):
    """Đại diện cho một bình luận trên bài đăng."""
    userId: str
    content: str
    createdAt: datetime = Field(default_factory=datetime.utcnow)

class Post(Document):
    """
    Đại diện cho một bài đăng trong collection 'posts'.
    """
    authorId: str = Field(..., description="ID của tác giả bài đăng.")
    authorInfo: AuthorInfo = Field(..., description="Thông tin phi chuẩn hóa của tác giả.")
    content: str = Field(..., description="Nội dung văn bản của bài đăng.")
    mediaUrls: List[str] = Field(default_factory=list, description="Danh sách các URL media (hình ảnh/video).")
    reactions: List[Reaction] = Field(default_factory=list, description="Danh sách các phản ứng.")
    reactionCounts: Dict[str, int] = Field(default_factory=dict, description="Số lượng của mỗi loại phản ứng.")
    commentCount: int = Field(default=0, description="Tổng số bình luận.")
    comments: List[Comment] = Field(default_factory=dict, description="Danh sách các bình luận.")
    createdAt: datetime = Field(default_factory=datetime.utcnow, description="Thời điểm bài đăng được tạo.")

    class Settings:
        name = "posts"
        indexes = [
            "authorId",
            "createdAt",
        ]
