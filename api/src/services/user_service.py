from ..models.user import User
from ..models.friend_request import FriendRequest
from bson import ObjectId

class UserService:

    @staticmethod
    def send_friend_request(from_user_id, to_user_id):
        """
        Gửi một yêu cầu kết bạn từ người dùng này đến người dùng khác.
        """
        if from_user_id == to_user_id:
            raise ValueError("Không thể gửi yêu cầu kết bạn cho chính mình.")

        # Kiểm tra xem người dùng đã là bạn bè chưa
        from_user = User.find_by_id(from_user_id)
        if str(to_user_id) in from_user.friendIds:
            raise ValueError("Người dùng đã là bạn bè.")

        # Kiểm tra xem một yêu cầu đã tồn tại chưa
        existing_request = FriendRequest.find_one({
            '$or': [
                {'fromUserId': str(from_user_id), 'toUserId': str(to_user_id)},
                {'fromUserId': str(to_user_id), 'toUserId': str(from_user_id)}
            ]
        })
        if existing_request and existing_request.status != 'rejected':
            raise ValueError("Một yêu cầu kết bạn đã tồn tại giữa những người dùng này.")

        # Tạo và lưu yêu cầu mới
        new_request = FriendRequest(fromUserId=from_user_id, toUserId=to_user_id)
        new_request.save()
        return new_request

    @staticmethod
    def respond_to_friend_request(request_id, user_id, response):
        """
        Phản hồi một yêu cầu kết bạn ('chấp nhận' hoặc 'từ chối').
        """
        friend_request = FriendRequest.find_by_id(request_id)
        if not friend_request or str(friend_request.toUserId) != str(user_id):
            raise ValueError("Không tìm thấy yêu cầu kết bạn hoặc bạn không phải là người nhận.")

        if friend_request.status != 'pending':
            raise ValueError("Yêu cầu kết bạn này đã được phản hồi.")

        if response == 'accept':
            friend_request.accept()
        elif response == 'reject':
            friend_request.reject()
        else:
            raise ValueError("Phản hồi không hợp lệ. Phải là 'chấp nhận' hoặc 'từ chối'.")
        
        return friend_request

    @staticmethod
    def get_friends(user_id):
        """
        Lấy danh sách bạn bè đầy đủ của người dùng với chi tiết người dùng.
        """
        user = User.find_by_id(user_id)
        if not user:
            raise ValueError("Không tìm thấy người dùng.")
        
        friend_ids_obj = [ObjectId(fid) for fid in user.friendIds]
        
        friends_cursor = User.get_collection().find({
            '_id': {'$in': friend_ids_obj}
        })
        
        return [User(**friend_data) for friend_data in friends_cursor]