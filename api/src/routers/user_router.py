from fastapi import APIRouter, Depends, HTTPException
from typing import List
from ..services import UserService
from ..schemas import FriendRequestCreate, FriendRequestResponse, UserPublic
from ..models import User
from ..security import get_current_user

router = APIRouter(tags=["User"])

@router.get("/api/users/me", response_model=UserPublic)
def read_users_me(current_user: User = Depends(get_current_user)):
    """
    Lấy hồ sơ của người dùng hiện được xác thực.
    """
    return UserPublic(
        id=str(current_user._id),
        username=current_user.username,
        email=current_user.email,
        displayName=current_user.displayName
    )

@router.post("/api/users/friend-request", status_code=201)
def send_friend_request(
    request_data: FriendRequestCreate,
    current_user: User = Depends(get_current_user)
):
    try:
        to_user_id = request_data.to_user_id
        UserService.send_friend_request(from_user_id=current_user._id, to_user_id=to_user_id)
        return {"message": "Friend request sent successfully."}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/api/users/friend-request/{request_id}", status_code=200)
def respond_to_friend_request(
    request_id: str,
    response_data: FriendRequestResponse,
    current_user: User = Depends(get_current_user)
):
    try:
        UserService.respond_to_friend_request(
            request_id=request_id,
            user_id=current_user._id,
            response=response_data.response
        )
        return {"message": f"Friend request {response_data.response}ed."}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/api/users/friends", response_model=List[UserPublic])
def get_friends(current_user: User = Depends(get_current_user)):
    """
    Lấy danh sách bạn bè cho người dùng hiện được xác thực.
    """
    try:
        friends = UserService.get_friends(user_id=current_user._id)
        # Convert User model objects to UserPublic schema
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

@router.get("/api/users/{user_id}", response_model=UserPublic)
def get_user_profile(user_id: str):
    """
    Lấy hồ sơ công khai của bất kỳ người dùng nào.
    """
    user = User.find_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return UserPublic(
        id=str(user._id),
        username=user.username,
        email=user.email,
        displayName=user.displayName
    )