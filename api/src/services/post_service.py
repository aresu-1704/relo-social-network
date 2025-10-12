import asyncio
from ..models.post import Post, AuthorInfo, Reaction
from ..models.user import User
from ..websocket import manager

class PostService:

    @staticmethod
    async def create_post(author_id: str, content: str, media_urls: list = None):
        """
        Tạo một bài đăng mới.
        Nó tìm nạp thông tin của tác giả để khử chuẩn hóa nó vào tài liệu bài đăng.
        """
        # Lấy thông tin tác giả một cách bất đồng bộ
        author = await User.get(author_id)
        if not author:
            raise ValueError("Không tìm thấy tác giả.")

        # Tạo một đối tượng thông tin tác giả được nhúng
        author_info = AuthorInfo(
            displayName=author.displayName,
            avatarUrl=author.avatarUrl
        )

        # Tạo thực thể bài đăng mới
        new_post = Post(
            authorId=author_id,
            authorInfo=author_info,
            content=content,
            mediaUrls=media_urls if media_urls else []
        )
        
        # Lưu bài đăng vào cơ sở dữ liệu
        await new_post.save()

        # Gửi thông báo real-time đến bạn bè của tác giả
        notification_payload = {
            "type": "new_post",
            "payload": {
                "authorId": str(author.id),
                "authorName": author.displayName,
                "postId": str(new_post.id)
            }
        }
        
        broadcast_tasks = []
        for friend_id in author.friendIds:
            task = manager.broadcast_to_user(friend_id, notification_payload)
            broadcast_tasks.append(task)
        
        if broadcast_tasks:
            asyncio.gather(*broadcast_tasks)

        return new_post

    @staticmethod
    async def get_post_feed(limit: int = 20, skip: int = 0):
        """
        Lấy một nguồn cấp dữ liệu chung về các bài đăng gần đây.
        """
        # Truy vấn các bài đăng gần đây nhất, được sắp xếp theo ngày tạo
        posts = await Post.find_all(sort="-createdAt", skip=skip, limit=limit).to_list()
        return posts

    @staticmethod
    async def react_to_post(user_id: str, post_id: str, reaction_type: str):
        """
        Thêm hoặc thay đổi phản ứng của người dùng đối với một bài đăng.
        """
        post = await Post.get(post_id)
        if not post:
            raise ValueError("Không tìm thấy bài đăng.")
        
        # Tìm phản ứng hiện có của người dùng
        existing_reaction_index = -1
        for i, reaction in enumerate(post.reactions):
            if reaction.userId == user_id:
                existing_reaction_index = i
                break

        if existing_reaction_index != -1:
            # Nếu người dùng đã phản ứng
            old_reaction_type = post.reactions[existing_reaction_index].type
            if old_reaction_type == reaction_type:
                # Nếu loại phản ứng giống nhau, không làm gì cả
                return post
            
            # Giảm số lượng của phản ứng cũ
            post.reactionCounts[old_reaction_type] -= 1
            if post.reactionCounts[old_reaction_type] == 0:
                del post.reactionCounts[old_reaction_type]
            
            # Cập nhật phản ứng
            post.reactions[existing_reaction_index].type = reaction_type
        else:
            # Nếu người dùng chưa phản ứng, hãy thêm một phản ứng mới
            post.reactions.append(Reaction(userId=user_id, type=reaction_type))

        # Tăng số lượng của phản ứng mới
        post.reactionCounts[reaction_type] = post.reactionCounts.get(reaction_type, 0) + 1
        
        # Lưu bài đăng đã cập nhật
        await post.save()
        return post

    @staticmethod
    async def delete_post(post_id: str, user_id: str):
        """
        Xóa một bài đăng, đảm bảo người dùng là tác giả.
        """
        # Lấy bài đăng
        post = await Post.get(post_id)
        if not post:
            raise ValueError("Không tìm thấy bài đăng.")

        # Kiểm tra quyền
        if post.authorId != user_id:
            raise PermissionError("Bạn không được phép xóa bài đăng này.")

        # Xóa bài đăng
        await post.delete()
        return {"message": "Bài đăng đã được xóa thành công"}