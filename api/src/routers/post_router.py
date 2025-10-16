from fastapi import APIRouter, Depends, HTTPException
from typing import List
from ..services import PostService
from ..schemas import PostCreate, PostPublic, ReactionCreate
from ..models import User
from ..security import get_current_user

router = APIRouter(tags=["Post"])

@router.post("/posts", response_model=PostPublic, status_code=201)
async def create_post(
    post_data: PostCreate,
    current_user: User = Depends(get_current_user)
):
    """Tạo một bài đăng mới. Yêu cầu xác thực người dùng."""
    try:
        # Gọi service để tạo bài đăng một cách bất đồng bộ
        new_post = await PostService.create_post(
            author_id=str(current_user.id), # Sử dụng str(current_user.id) thay vì _id
            content=post_data.content,
            media_base_64=post_data.mediaBase64
        )
        # Ánh xạ kết quả trả về sang schema PostPublic
        return PostPublic(
            id=str(new_post.id),
            authorId=str(new_post.authorId),
            authorInfo=new_post.authorInfo,
            content=new_post.content,
            mediaUrls=new_post.mediaUrls,
            reactionCounts=new_post.reactionCounts,
            commentCount=new_post.commentCount,
            createdAt=new_post.createdAt.isoformat()
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/posts/feed", response_model=List[PostPublic])
async def get_post_feed(skip: int = 0, limit: int = 20):
    """Lấy một nguồn cấp dữ liệu (feed) các bài đăng, không yêu cầu xác thực."""
    # Lấy danh sách bài đăng một cách bất đồng bộ
    posts = await PostService.get_post_feed(limit=limit, skip=skip)
    # Ánh xạ danh sách kết quả sang schema PostPublic
    return posts

@router.post("/posts/{post_id}/react", response_model=PostPublic)
async def react_to_post(
    post_id: str,
    reaction_data: ReactionCreate,
    current_user: User = Depends(get_current_user)
):
    """Thêm hoặc thay đổi một phản ứng (reaction) cho một bài đăng. Yêu cầu xác thực."""
    try:
        # Gọi service để cập nhật phản ứng một cách bất đồng bộ
        updated_post = await PostService.react_to_post(
            user_id=str(current_user.id),
            post_id=post_id,
            reaction_type=reaction_data.reaction_type
        )
        # Ánh xạ kết quả trả về sang schema PostPublic
        return PostPublic(
            id=str(updated_post.id),
            authorId=str(updated_post.authorId),
            authorInfo=updated_post.authorInfo,
            content=updated_post.content,
            mediaUrls=updated_post.mediaUrls,
            reactionCounts=updated_post.reactionCounts,
            commentCount=updated_post.commentCount,
            createdAt=updated_post.createdAt.isoformat()
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))

@router.delete("/posts/{post_id}", status_code=200)
async def delete_post(
    post_id: str,
    current_user: User = Depends(get_current_user)
):
    """Xóa một bài đăng. Chỉ tác giả của bài đăng mới có quyền xóa."""
    try:
        # Gọi service để xóa bài đăng một cách bất đồng bộ
        result = await PostService.delete_post(post_id=post_id, user_id=str(current_user.id))
        return result
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))