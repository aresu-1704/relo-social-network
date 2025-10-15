from fastapi import APIRouter, Depends, HTTPException, Query
from typing import List
from ..services import UserService
from ..schemas import FriendRequestCreate, FriendRequestResponse, UserPublic
from ..schemas.block_schema import BlockUserRequest
from ..schemas import FriendRequestPublic
from ..models import User
from ..security import get_current_user

router = APIRouter(tags=["User"])

# Lấy hồ sơ của người dùng hiện tại
@router.get("/me", response_model=UserPublic)
async def read_users_me(current_user: User = Depends(get_current_user)):
    """
    Lấy hồ sơ của người dùng hiện được xác thực.
    """
    return UserPublic(
        id=str(current_user.id),
        username=current_user.username,
        email=current_user.email,
        displayName=current_user.displayName
    )

# Gửi yêu cầu kết bạn
@router.post("/friend-request", status_code=201)
async def send_friend_request(
    request_data: FriendRequestCreate,
    current_user: User = Depends(get_current_user)
):
    try:
        to_user_id = request_data.to_user_id
        await UserService.send_friend_request(from_user_id=str(current_user.id), to_user_id=to_user_id)
        return {"message": "Gửi yêu cầu kết bạn thành công."}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

# Phản hồi yêu cầu kết bạn
@router.post("/friend-request/{request_id}", status_code=200)
async def respond_to_friend_request(
    request_id: str,
    response_data: FriendRequestResponse,
    current_user: User = Depends(get_current_user)
):
    try:
        await UserService.respond_to_friend_request(
            request_id=request_id,
            user_id=str(current_user.id),
            response=response_data.response
        )
        return {"message": f"Yêu cầu kết bạn đã được {response_data.response}."}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

# Lấy danh sách lời mời kết bạn đang chờ
@router.get("/friend-requests/pending", response_model=List[FriendRequestPublic])
async def get_pending_friend_requests(current_user: User = Depends(get_current_user)):
    """
    Lấy danh sách các lời mời kết bạn đang chờ xử lý cho người dùng hiện tại.
    """
    try:
        pending_requests = await UserService.get_friend_requests(user_id=str(current_user.id))
        
        requests_with_str_id = []
        for req in pending_requests:
            req_dict = req.dict()
            req_dict['id'] = str(req.id)
            requests_with_str_id.append(FriendRequestPublic(**req_dict))

        return requests_with_str_id

    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))

# Lấy danh sách bạn bè
@router.get("/friends", response_model=List[UserPublic])
async def get_friends(current_user: User = Depends(get_current_user)):
    """
    Lấy danh sách bạn bè cho người dùng hiện được xác thực.
    """
    try:
        friends = await UserService.get_friends(user_id=str(current_user.id))
        # Chuyển đổi đối tượng User model thành UserPublic schema
        return [
            UserPublic(
                id=str(friend.id),
                username=friend.username,
                email=friend.email,
                displayName=friend.displayName
            ) for friend in friends
        ]
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))

# Lấy hồ sơ công khai của người dùng
@router.get("/{user_id}", response_model=UserPublic)
async def get_user_profile(user_id: str, current_user: User = Depends(get_current_user)):
    """
    Lấy hồ sơ công khai của bất kỳ người dùng nào.
    """
    try:
        user = await UserService.get_user_profile(user_id, str(current_user.id))
        return UserPublic(
            id=str(user.id),
            username=user.username,
            email=user.email,
            displayName=user.displayName
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))

# Chặn người dùng
@router.post("/block", status_code=200)
async def block_user(request: BlockUserRequest, current_user: User = Depends(get_current_user)):
    try:
        result = await UserService.block_user(str(current_user.id), request.user_id)
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

# Bỏ chặn người dùng
@router.post("/unblock", status_code=200)
async def unblock_user(request: BlockUserRequest, current_user: User = Depends(get_current_user)):
    try:
        result = await UserService.unblock_user(str(current_user.id), request.user_id)
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

# Tìm kiếm người dùng
@router.get("/search", response_model=List[UserPublic])
async def search_users(query: str = Query(..., min_length=1), current_user: User = Depends(get_current_user)):
    """
    Tìm kiếm người dùng theo username hoặc displayName.
    """
    try:
        users = await UserService.search_users(query, str(current_user.id))
        return [
            UserPublic(
                id=str(user.id),
                username=user.username,
                email=user.email,
                displayName=user.displayName
            ) for user in users
        ]
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))