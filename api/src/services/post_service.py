from ..models.post import Post
from ..models.user import User

class PostService:

    @staticmethod
    def create_post(author_id, content, media_urls=None):
        """
        Tạo một bài đăng mới.
        Nó tìm nạp thông tin của tác giả để khử chuẩn hóa nó vào tài liệu bài đăng.
        """
        author = User.find_by_id(author_id)
        if not author:
            raise ValueError("Không tìm thấy tác giả.")

        author_info = {
            "displayName": author.displayName,
            "avatarUrl": author.avatarUrl
        }

        new_post = Post(
            authorId=str(author_id),
            authorInfo=author_info,
            content=content,
            mediaUrls=media_urls if media_urls else []
        )
        new_post.save()
        return new_post

    @staticmethod
    def get_post_feed(limit=20, skip=0):
        """
        Lấy một nguồn cấp dữ liệu chung về các bài đăng gần đây.
        """
        posts_cursor = Post.get_collection().find().sort('createdAt', -1).skip(skip).limit(limit)
        return [Post(**post_data) for post_data in posts_cursor]

    @staticmethod
    def react_to_post(user_id, post_id, reaction_type):
        """
        Thêm hoặc thay đổi phản ứng của người dùng đối với một bài đăng.
        """
        post = Post.find_by_id(post_id)
        if not post:
            raise ValueError("Không tìm thấy bài đăng.")
        
        # Phương thức mô hình xử lý tất cả logic để thêm/cập nhật các phản ứng
        post.add_reaction(user_id, reaction_type)
        return post

    @staticmethod
    def delete_post(post_id, user_id):
        """
        Xóa một bài đăng, đảm bảo người dùng là tác giả.
        """
        post = Post.find_by_id(post_id)
        if not post:
            raise ValueError("Không tìm thấy bài đăng.")

        if str(post.authorId) != str(user_id):
            raise PermissionError("Bạn không được phép xóa bài đăng này.")

        post.delete()
        return {"message": "Bài đăng đã được xóa thành công"}