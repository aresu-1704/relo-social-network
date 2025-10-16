from pydantic import BaseModel, Field
from typing import List, Optional, Dict
from datetime import datetime
from .user_schema import UserPublic


class ConversationCreate(BaseModel):
    participant_ids: List[str]

class MessageCreate(BaseModel):
    content: dict # e.g. {"text": "Hello"}

# Schema for simplified message response
class SimpleMessagePublic(BaseModel):
    senderId: str
    avatarUrl: Optional[str]
    content: Dict
    createdAt: datetime

class MessagePublic(BaseModel):
    id: str
    conversationId: str
    senderId: str
    content: Dict
    createdAt: datetime

    class Config:
        from_attributes = True
        json_encoders = {
            datetime: lambda dt: dt.isoformat()
        }

class LastMessagePublic(BaseModel):
    text: str
    senderId: str
    timestamp: datetime

    class Config:
        from_attributes = True
        json_encoders = {
            datetime: lambda dt: dt.isoformat()
        }

class ConversationPublic(BaseModel):
    id: str
    participantIds: List[str]
    lastMessage: Optional[LastMessagePublic]
    updatedAt: datetime
    seenIds: List[str] = []

    class Config:
        from_attributes = True
        json_encoders = {
            datetime: lambda dt: dt.isoformat()
        }

class ConversationWithParticipants(BaseModel):
    id: str
    participants: List[UserPublic]
    lastMessage: Optional[LastMessagePublic]
    updatedAt: datetime
    seenIds: List[str] = []

    class Config:
        from_attributes = True
        json_encoders = {
            datetime: lambda dt: dt.isoformat()
        }
