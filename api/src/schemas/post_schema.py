from pydantic import BaseModel
from typing import List, Optional

class PostCreate(BaseModel):
    content: str
    mediaBase64: Optional[List[str]] = []

class PostPublic(BaseModel):
    id: str
    authorId: str
    authorInfo: dict
    content: str
    mediaUrls: List[str]
    reactionCounts: dict
    commentCount: int
    createdAt: str

    class Config:
        from_attributes = True
        json_encoders = {
            'id': lambda v: str(v),
            'authorId': lambda v: str(v),
            'createdAt': lambda v: v.isoformat(),
        }

class ReactionCreate(BaseModel):
    reaction_type: str
