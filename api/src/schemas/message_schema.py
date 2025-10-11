from pydantic import BaseModel, Field
from typing import List, Optional, Dict
from datetime import datetime

class ConversationCreate(BaseModel):
    participant_ids: List[str]

class MessageCreate(BaseModel):
    content: dict # e.g. {"text": "Hello"}

# New Schemas
class MessagePublic(BaseModel):
    id: str
    conversationId: str
    senderId: str
    content: Dict
    createdAt: datetime

    class Config:
        orm_mode = True
        json_encoders = {
            datetime: lambda dt: dt.isoformat()
        }
        # allow_population_by_field_name = True # not needed if we map manually


class LastMessagePublic(BaseModel):
    text: str
    senderId: str
    timestamp: datetime

    class Config:
        orm_mode = True
        json_encoders = {
            datetime: lambda dt: dt.isoformat()
        }

class ConversationPublic(BaseModel):
    id: str
    participantIds: List[str]
    lastMessage: Optional[LastMessagePublic]
    updatedAt: datetime

    class Config:
        orm_mode = True
        json_encoders = {
            datetime: lambda dt: dt.isoformat()
        }
        # allow_population_by_field_name = True # not needed if we map manually
