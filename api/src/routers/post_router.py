from fastapi import APIRouter, Depends, HTTPException
from typing import List
from ..services import PostService
from ..schemas import PostCreate, PostPublic, ReactionCreate
from ..models import User
from ..security import get_current_user

router = APIRouter(tags=["Post"])

@router.post("/api/posts", response_model=PostPublic, status_code=201)
def create_post(
    post_data: PostCreate,
    current_user: User = Depends(get_current_user)
):
    try:
        new_post = PostService.create_post(
            author_id=current_user._id,
            content=post_data.content,
            media_urls=post_data.media_urls
        )
        return PostPublic(
            id=str(new_post._id),
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

@router.get("/api/posts/feed", response_model=List[PostPublic])
def get_post_feed(skip: int = 0, limit: int = 20):
    """
    Lấy một nguồn cấp dữ liệu được phân trang của tất cả các bài đăng.
    """
    posts = PostService.get_post_feed(limit=limit, skip=skip)
    return [
        PostPublic(
            id=str(post._id),
            authorId=str(post.authorId),
            authorInfo=post.authorInfo,
            content=post.content,
            mediaUrls=post.mediaUrls,
            reactionCounts=post.reactionCounts,
            commentCount=post.commentCount,
            createdAt=post.createdAt.isoformat()
        ) for post in posts
    ]

@router.post("/api/posts/{post_id}/react", response_model=PostPublic)
def react_to_post(
    post_id: str,
    reaction_data: ReactionCreate,
    current_user: User = Depends(get_current_user)
):
    try:
        updated_post = PostService.react_to_post(
            user_id=current_user._id,
            post_id=post_id,
            reaction_type=reaction_data.reaction_type
        )
        return PostPublic(
            id=str(updated_post._id),
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

@router.delete("/api/posts/{post_id}", status_code=200)
def delete_post(
    post_id: str,
    current_user: User = Depends(get_current_user)
):
    try:
        result = PostService.delete_post(post_id=post_id, user_id=current_user._id)
        return result
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))