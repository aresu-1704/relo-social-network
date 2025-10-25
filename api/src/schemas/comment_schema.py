from pydantic import BaseModel
from typing import Optional

class CommentCreate(BaseModel):
    content: str

class CommentPublic(BaseModel):
    id: str
    postId: str
    userId: str
    userDisplayName: str
    userAvatarUrl: Optional[str] = ""
    content: str
    createdAt: str

    class Config:
        from_attributes = True
