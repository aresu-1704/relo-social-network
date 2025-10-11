from beanie import Document
from pydantic import Field, EmailStr
from typing import Optional, List
from datetime import datetime

class User(Document):
    """
    Đại diện cho một người dùng trong collection 'users'.
    """
    username: str = Field(..., description="Tên đăng nhập duy nhất của người dùng.")
    email: EmailStr = Field(..., description="Địa chỉ email duy nhất của người dùng.")
    hashedPassword: str = Field(..., description="Mật khẩu đã được băm của người dùng.")
    salt: str = Field(..., description="Salt được sử dụng để băm mật khẩu.")
    displayName: str = Field(..., description="Tên hiển thị của người dùng.")
    avatarUrl: Optional[str] = Field(default="", description="URL ảnh đại diện của người dùng.")
    bio: Optional[str] = Field(default="", description="Tiểu sử ngắn của người dùng.")
    friendIds: List[str] = Field(default_factory=list, description="Danh sách ID của bạn bè.")
    createdAt: datetime = Field(default_factory=datetime.utcnow, description="Thời điểm người dùng được tạo.")
    updatedAt: datetime = Field(default_factory=datetime.utcnow, description="Thời điểm thông tin người dùng được cập nhật lần cuối.")

    class Settings:
        name = "users"
        # Thêm các chỉ mục để tối ưu hóa truy vấn
        indexes = [
            "username",
            "email",
        ]
