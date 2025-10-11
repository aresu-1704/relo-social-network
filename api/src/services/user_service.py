from ..models.user import User
from ..models.friend_request import FriendRequest
from bson import ObjectId

class UserService:

    @staticmethod
    async def send_friend_request(from_user_id: str, to_user_id: str):
        """
        Gửi một yêu cầu kết bạn từ người dùng này đến người dùng khác.
        """
        if from_user_id == to_user_id:
            raise ValueError("Không thể gửi yêu cầu kết bạn cho chính mình.")

        # Lấy thông tin người gửi để kiểm tra danh sách bạn bè
        from_user = await User.get(from_user_id)
        if not from_user:
            raise ValueError("Không tìm thấy người dùng gửi.")

        # Kiểm tra xem họ đã là bạn bè chưa
        if to_user_id in from_user.friendIds:
            raise ValueError("Người dùng đã là bạn bè.")

        # Kiểm tra xem một yêu cầu đang chờ xử lý hoặc đã được chấp nhận có tồn tại không
        existing_request = await FriendRequest.find_one(
            {
                "$or": [
                    {"fromUserId": from_user_id, "toUserId": to_user_id},
                    {"fromUserId": to_user_id, "toUserId": from_user_id}
                ],
                "status": {"$in": ["pending", "accepted"]}
            }
        )
        if existing_request:
            raise ValueError("Một yêu cầu kết bạn đã tồn tại hoặc đang chờ xử lý.")

        # Tạo và lưu yêu cầu mới
        new_request = FriendRequest(fromUserId=from_user_id, toUserId=to_user_id)
        await new_request.save()
        return new_request

    @staticmethod
    async def respond_to_friend_request(request_id: str, user_id: str, response: str):
        """
        Phản hồi một yêu cầu kết bạn ('accept' hoặc 'reject').
        """
        # Lấy yêu cầu kết bạn bằng ID
        friend_request = await FriendRequest.get(request_id)
        if not friend_request or friend_request.toUserId != user_id:
            raise ValueError("Không tìm thấy yêu cầu kết bạn hoặc bạn không phải là người nhận.")

        if friend_request.status != 'pending':
            raise ValueError("Yêu cầu kết bạn này đã được phản hồi.")

        if response == 'accept':
            # Chấp nhận yêu cầu
            friend_request.status = 'accepted'
            
            # Lấy cả hai người dùng để cập nhật danh sách bạn bè của họ
            from_user = await User.get(friend_request.fromUserId)
            to_user = await User.get(friend_request.toUserId)

            if not from_user or not to_user:
                raise ValueError("Không tìm thấy một trong hai người dùng.")

            # Thêm ID bạn bè vào danh sách của nhau
            from_user.friendIds.append(to_user.id)
            to_user.friendIds.append(from_user.id)

            # Lưu các thay đổi vào cơ sở dữ liệu
            await friend_request.save()
            await from_user.save()
            await to_user.save()

        elif response == 'reject':
            # Từ chối yêu cầu
            friend_request.status = 'rejected'
            await friend_request.save()
        else:
            raise ValueError("Phản hồi không hợp lệ. Phải là 'accept' hoặc 'reject'.")
        
        return friend_request

    @staticmethod
    async def get_friends(user_id: str):
        """
        Lấy danh sách bạn bè đầy đủ của người dùng với chi tiết người dùng.
        """
        # Lấy thông tin người dùng
        user = await User.get(user_id)
        if not user:
            raise ValueError("Không tìm thấy người dùng.")
        
        # Lấy tất cả bạn bè trong một truy vấn
        friends = await User.find(User.id.in_([ObjectId(fid) for fid in user.friendIds])).to_list()
        
        return friends

    @staticmethod
    async def get_user_profile(user_id: str):
        """
        Lấy hồ sơ công khai của bất kỳ người dùng nào.
        """
        user = await User.get(user_id)
        if not user:
            raise ValueError("Không tìm thấy người dùng")
        return user