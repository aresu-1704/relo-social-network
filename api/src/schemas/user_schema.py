from pydantic import BaseModel, EmailStr
from datetime import datetime

class FriendRequestCreate(BaseModel):
    to_user_id: str

class FriendRequestResponse(BaseModel):
    response: str # 'accept' or 'reject'

class UserPublic(BaseModel):
    id: str
    username: str
    email: EmailStr
    displayName: str

class FriendRequestPublic(BaseModel):
    id: str
    fromUserId: str
    toUserId: str
    status: str
    createdAt: datetime

    class Config:
        allow_population_by_field_name = True
        json_encoders = {
            datetime: lambda dt: dt.isoformat()
        }