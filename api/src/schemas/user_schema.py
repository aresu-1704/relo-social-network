from pydantic import BaseModel
from typing import List

class FriendRequestCreate(BaseModel):
    to_user_id: str

class FriendRequestResponse(BaseModel):
    response: str # 'accept' or 'reject'
