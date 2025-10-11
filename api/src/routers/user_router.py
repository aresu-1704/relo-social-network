from fastapi import APIRouter, Depends, HTTPException
from typing import List
from ..services import UserService
from ..schemas import FriendRequestCreate, FriendRequestResponse, UserPublic
from ..models import User
from ..security import get_current_user

router = APIRouter(tags=["User"])

# Lấy hồ sơ của người dùng hiện tại
@router.get("/api/users/me", response_model=UserPublic)
async def read_users_me(current_user: User = Depends(get_current_user)):
    """
    Lấy hồ sơ của người dùng hiện được xác thực.
    """
    return UserPublic(
        id=str(current_user._id),
        username=current_user.username,
        email=current_user.email,
        displayName=current_user.displayName
    )

# Gửi yêu cầu kết bạn
@router.post("/api/users/friend-request", status_code=201)
async def send_friend_request(
    request_data: FriendRequestCreate,
    current_user: User = Depends(get_current_user)
):
    try:
        to_user_id = request_data.to_user_id
        await UserService.send_friend_request(from_user_id=current_user._id, to_user_id=to_user_id)
        return {"message": "Gửi yêu cầu kết bạn thành công."}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

# Phản hồi yêu cầu kết bạn
@router.post("/api/users/friend-request/{request_id}", status_code=200)
async def respond_to_friend_request(
    request_id: str,
    response_data: FriendRequestResponse,
    current_user: User = Depends(get_current_user)
):
    try:
        await UserService.respond_to_friend_request(
            request_id=request_id,
            user_id=current_user._id,
            response=response_data.response
        )
        return {"message": f"Yêu cầu kết bạn đã được {response_data.response}."}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

# Lấy danh sách bạn bè
@router.get("/api/users/friends", response_model=List[UserPublic])
async def get_friends(current_user: User = Depends(get_current_user)):
    """
    Lấy danh sách bạn bè cho người dùng hiện được xác thực.
    """
    try:
        friends = await UserService.get_friends(user_id=current_user._id)
        # Chuyển đổi đối tượng User model thành UserPublic schema
        return [
            UserPublic(
                id=str(friend._id),
                username=friend.username,
                email=friend.email,
                displayName=friend.displayName
            ) for friend in friends
        ]
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))

# Lấy hồ sơ công khai của người dùng
@router.get("/api/users/{user_id}", response_model=UserPublic)
async def get_user_profile(user_id: str):
    """
    Lấy hồ sơ công khai của bất kỳ người dùng nào.
    """
    try:
        user = await UserService.get_user_profile(user_id)
        return UserPublic(
            id=str(user._id),
            username=user.username,
            email=user.email,
            displayName=user.displayName
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))