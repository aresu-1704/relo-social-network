from pydantic import BaseModel, EmailStr
from typing import List

class FriendRequestCreate(BaseModel):
    to_user_id: str

class FriendRequestResponse(BaseModel):
    response: str # 'accept' or 'reject'

class UserPublic(BaseModel):
    id: str
    username: str
    email: EmailStr
    displayName: str
