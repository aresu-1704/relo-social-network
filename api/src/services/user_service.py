import asyncio
from ..models import User
from ..models import FriendRequest
from ..schemas import UserUpdate
from ..websocket import manager
from bson import ObjectId
import base64
import tempfile
from cloudinary.uploader import upload as cloudinary_upload, destroy

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

        # Gửi thông báo real-time đến người nhận yêu cầu
        notification_payload = {
            "type": "friend_request_received",
            "payload": {
                "request_id": str(new_request.id),
                "from_user_id": str(from_user.id),
                "displayName": from_user.displayName,
                "avatar": from_user.avatar
            }
        }
        asyncio.create_task(
            manager.broadcast_to_user(to_user_id, notification_payload)
        )

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
            
            # Gửi thông báo real-time đến người gửi yêu cầu
            notification_payload = {
                "type": "friend_request_accepted",
                "payload": {
                    "user_id": str(to_user.id),
                    "displayName": to_user.displayName
                }
            }
            asyncio.create_task(
                manager.broadcast_to_user(friend_request.fromUserId, notification_payload)
            )

        elif response == 'reject':
            # Từ chối yêu cầu
            friend_request.status = 'rejected'
            await friend_request.save()
        else:
            raise ValueError("Phản hồi không hợp lệ. Phải là 'accept' hoặc 'reject'.")
        
        return friend_request

    @staticmethod
    async def get_friend_requests(user_id: str):
        """
        Lấy danh sách các lời mời kết bạn đang chờ xử lý cho một người dùng.
        """
        # Tìm tất cả các yêu cầu kết bạn đang chờ xử lý gửi đến người dùng
        pending_requests = await FriendRequest.find(
            {
                "toUserId": user_id,
                "status": "pending"
            }
        ).to_list()
        
        return pending_requests

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
        friends = await User.find({"_id": {"$in": [ObjectId(fid) for fid in user.friendIds]}}).to_list()
        
        return friends

    @staticmethod
    async def get_user_profile(user_id: str, current_user_id: str):
        """
        Lấy hồ sơ công khai của bất kỳ người dùng nào, trừ khi bị chặn.
        """
        user = await User.get(user_id)
        if not user:
            raise ValueError("Không tìm thấy người dùng")

        current_user = await User.get(current_user_id)
        if not current_user:
            raise ValueError("Không tìm thấy người dùng hiện tại")

        # Kiểm tra xem người dùng hiện tại có bị người dùng kia chặn không
        if current_user_id in user.blockedUserIds:
            raise ValueError("Bạn đã bị người dùng này chặn.")

        # Kiểm tra xem người dùng hiện tại có chặn người dùng kia không
        if user_id in current_user.blockedUserIds:
            raise ValueError("Bạn đã chặn người dùng này.")

        return user

    @staticmethod
    async def block_user(user_id: str, block_user_id: str):
        """
        Chặn một người dùng.
        """
        if user_id == block_user_id:
            raise ValueError("Không thể tự chặn chính mình.")

        user = await User.get(user_id)
        if not user:
            raise ValueError("Không tìm thấy người dùng.")

        if block_user_id not in user.blockedUserIds:
            user.blockedUserIds.append(block_user_id)
            await user.save()

        return {"message": "Người dùng đã bị chặn thành công."}

    @staticmethod
    async def unblock_user(user_id: str, block_user_id: str):
        """
        Bỏ chặn một người dùng.
        """
        user = await User.get(user_id)
        if not user:
            raise ValueError("Không tìm thấy người dùng.")

        if block_user_id in user.blockedUserIds:
            user.blockedUserIds.remove(block_user_id)
            await user.save()

        return {"message": "Người dùng đã được bỏ chặn thành công."}

    @staticmethod
    async def search_users(query: str, current_user_id: str):
        """
        Tìm kiếm người dùng theo username hoặc displayName, loại trừ những người dùng bị chặn.
        """
        current_user = await User.get(current_user_id)
        if not current_user:
            raise ValueError("Không tìm thấy người dùng hiện tại.")

        # Lấy danh sách những người dùng đã chặn người dùng hiện tại
        users_blocking_me = await User.find({"blockedUserIds": current_user_id}).to_list()
        ids_blocking_me = [str(u.id) for u in users_blocking_me]

        # Tổng hợp danh sách ID bị chặn
        excluded_ids = current_user.blockedUserIds + ids_blocking_me

        # Tìm kiếm người dùng
        users = await User.find(
            {
                "$or": [
                    {"username": {"$regex": query, "$options": "i"}},
                    {"displayName": {"$regex": query, "$options": "i"}}
                ],
                "_id": {"$nin": [ObjectId(uid) for uid in excluded_ids]}
            }
        ).to_list()

        return users

    @staticmethod
    async def get_users_by_ids(user_ids: list[str]):
        """
        Lấy danh sách người dùng bằng ID của họ.
        """
        if not user_ids:
            return []
        
        # Chuyển đổi chuỗi ID thành ObjectId
        object_ids = [ObjectId(uid) for uid in user_ids]
        
        # Tìm tất cả người dùng có ID trong danh sách
        users = await User.find({"_id": {"$in": object_ids}}).to_list()
        return users

    @staticmethod
    async def update_user(user_id: str, user_update: UserUpdate):
        """
        Cập nhật thông tin người dùng, bao gồm cả upload avatar lên Cloudinary.
        """
        user = await User.get(user_id)
        if not user:
            raise ValueError("Không tìm thấy người dùng.")

        update_data = user_update.dict(exclude_unset=True)

        # 1️⃣ Nếu client gửi ảnh base64 → upload Cloudinary
        if "avatarBase64" in update_data and update_data["avatarBase64"]:
            try:
                header, data = update_data["avatarBase64"].split(",") if "," in update_data["avatarBase64"] else (None, update_data["avatarBase64"])
                image_bytes = base64.b64decode(data)

                with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as tmp:
                    tmp.write(image_bytes)
                    tmp_path = tmp.name

                # Xóa ảnh cũ nếu có (tùy chọn)
                if getattr(user, "avatarPublicId", None):
                    destroy(user.avatarPublicId)

                result = cloudinary_upload(tmp_path, folder="avatars")
                user.avatarUrl = result["secure_url"]
                user.avatarPublicId = result["public_id"]

            except Exception as e:
                raise ValueError(f"Lỗi xử lý ảnh: {e}")

        # 2️⃣ Cập nhật các trường text
        if "displayName" in update_data:
            user.displayName = update_data["displayName"]
        if "bio" in update_data:
            user.bio = update_data["bio"]

        # 3️⃣ Lưu lại
        await user.save()
        return user