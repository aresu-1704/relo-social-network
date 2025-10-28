import asyncio
import os
import re
from datetime import datetime
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
                "avatarUrl": from_user.avatarUrl
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

            # Thêm ID bạn bè vào danh sách của nhau (convert ObjectId to string)
            from_user.friendIds.append(str(to_user.id))
            to_user.friendIds.append(str(from_user.id))

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
    def _remove_diacritics(text: str) -> str:
        """
        Loại bỏ dấu tiếng Việt để tìm kiếm không dấu.
        """
        vietnamese_map = {
            'à': 'a', 'á': 'a', 'ả': 'a', 'ã': 'a', 'ạ': 'a',
            'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'ặ': 'a',
            'ầ': 'a', 'ấ': 'a', 'ẩ': 'a', 'ẫ': 'a', 'ậ': 'a',
            'è': 'e', 'é': 'e', 'ẻ': 'e', 'ẽ': 'e', 'ẹ': 'e',
            'ề': 'e', 'ế': 'e', 'ể': 'e', 'ễ': 'e', 'ệ': 'e',
            'ì': 'i', 'í': 'i', 'ỉ': 'i', 'ĩ': 'i', 'ị': 'i',
            'ò': 'o', 'ó': 'o', 'ỏ': 'o', 'õ': 'o', 'ọ': 'o',
            'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ổ': 'o', 'ỗ': 'o', 'ộ': 'o',
            'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ở': 'o', 'ỡ': 'o', 'ợ': 'o',
            'ù': 'u', 'ú': 'u', 'ủ': 'u', 'ũ': 'u', 'ụ': 'u',
            'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ử': 'u', 'ữ': 'u', 'ự': 'u',
            'ỳ': 'y', 'ý': 'y', 'ỷ': 'y', 'ỹ': 'y', 'ỵ': 'y',
            'đ': 'd',
            'À': 'A', 'Á': 'A', 'Ả': 'A', 'Ã': 'A', 'Ạ': 'A',
            'Ă': 'A', 'Ằ': 'A', 'Ắ': 'A', 'Ẳ': 'A', 'Ẵ': 'A', 'Ặ': 'A',
            'Ầ': 'A', 'Ấ': 'A', 'Ẩ': 'A', 'Ẫ': 'A', 'Ậ': 'A',
            'È': 'E', 'É': 'E', 'Ẻ': 'E', 'Ẽ': 'E', 'Ẹ': 'E',
            'Ề': 'E', 'Ế': 'E', 'Ể': 'E', 'Ễ': 'E', 'Ệ': 'E',
            'Ì': 'I', 'Í': 'I', 'Ỉ': 'I', 'Ĩ': 'I', 'Ị': 'I',
            'Ò': 'O', 'Ó': 'O', 'Ỏ': 'O', 'Õ': 'O', 'Ọ': 'O',
            'Ô': 'O', 'Ồ': 'O', 'Ố': 'O', 'Ổ': 'O', 'Ỗ': 'O', 'Ộ': 'O',
            'Ơ': 'O', 'Ờ': 'O', 'Ớ': 'O', 'Ở': 'O', 'Ỡ': 'O', 'Ợ': 'O',
            'Ù': 'U', 'Ú': 'U', 'Ủ': 'U', 'Ũ': 'U', 'Ụ': 'U',
            'Ư': 'U', 'Ừ': 'U', 'Ứ': 'U', 'Ử': 'U', 'Ữ': 'U', 'Ự': 'U',
            'Ỳ': 'Y', 'Ý': 'Y', 'Ỷ': 'Y', 'Ỹ': 'Y', 'Ỵ': 'Y',
            'Đ': 'D'
        }
        
        result = text
        for vietnamese, replacement in vietnamese_map.items():
            result = result.replace(vietnamese, replacement)
        return result

    @staticmethod
    async def search_users(query: str, current_user_id: str):
        """
        Tìm kiếm người dùng theo username, displayName hoặc bio.
        Hỗ trợ tìm kiếm không dấu - nếu tìm "Thuan An" sẽ tìm được "Thuận An".
        """
        current_user = await User.get(current_user_id)
        if not current_user:
            raise ValueError("Không tìm thấy người dùng hiện tại.")

        # Lấy danh sách những người dùng đã chặn người dùng hiện tại
        users_blocking_me = await User.find({"blockedUserIds": current_user_id}).to_list()
        ids_blocking_me = [str(u.id) for u in users_blocking_me]

        # Tổng hợp danh sách ID bị chặn
        excluded_ids = current_user.blockedUserIds + ids_blocking_me + [current_user_id]  # Exclude self
        
        # Normalize the query to search without diacritics
        query_normalized = UserService._remove_diacritics(query).lower()
        query_lower = query.lower()
        
        # If query is empty, return empty list
        if not query.strip():
            return []
        
        # Get all non-blocked users (excluding self and blocked users)
        all_users = await User.find(
            {"_id": {"$nin": [ObjectId(uid) for uid in excluded_ids]}}
        ).to_list()
        
        # Filter users by matching normalized query
        matched_users = []
        for user in all_users:
            # Get all searchable text fields
            user_texts = [
                (user.username or ""),
                (user.displayName or ""),
                (user.bio or "")
            ]
            
            # Check if query matches in any field (with or without diacritics)
            for text in user_texts:
                if not text:
                    continue
                    
                text_normalized = UserService._remove_diacritics(text).lower()
                text_lower = text.lower()
                
                # Check if query matches exactly or partially
                # Matches with original diacritics
                if query_lower in text_lower or text_lower in query_lower:
                    matched_users.append(user)
                    break
                # Matches without diacritics
                elif query_normalized in text_normalized or text_normalized in query_normalized:
                    matched_users.append(user)
                    break
        
        return matched_users

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
    async def check_friend_status(user_id: str, target_user_id: str):
        """
        Kiểm tra trạng thái kết bạn giữa hai người dùng.
        Trả về: 'friends', 'pending_sent', 'pending_received', 'none'
        """
        if user_id == target_user_id:
            return 'self'
        
        # Lấy thông tin người dùng hiện tại
        current_user = await User.get(user_id)
        if not current_user:
            raise ValueError("Không tìm thấy người dùng hiện tại.")
        
        # Kiểm tra xem đã là bạn bè chưa
        if target_user_id in current_user.friendIds:
            return 'friends'
        
        # Kiểm tra lời mời kết bạn
        # Lời mời do user_id gửi cho target_user_id
        sent_request = await FriendRequest.find_one({
            "fromUserId": user_id,
            "toUserId": target_user_id,
            "status": "pending"
        })
        if sent_request:
            return 'pending_sent'
        
        # Lời mời do target_user_id gửi cho user_id
        received_request = await FriendRequest.find_one({
            "fromUserId": target_user_id,
            "toUserId": user_id,
            "status": "pending"
        })
        if received_request:
            return 'pending_received'
        
        return 'none'

    @staticmethod
    async def unfriend_user(user_id: str, friend_id: str):
        """
        Hủy kết bạn với một người dùng.
        """
        if user_id == friend_id:
            raise ValueError("Không thể hủy kết bạn với chính mình.")
        
        # Lấy thông tin cả hai người dùng
        user = await User.get(user_id)
        friend = await User.get(friend_id)
        
        if not user or not friend:
            raise ValueError("Không tìm thấy người dùng.")
        
        # Kiểm tra xem có phải bạn bè không
        if friend_id not in user.friendIds:
            raise ValueError("Người dùng này không phải là bạn bè của bạn.")
        
        # Xóa khỏi danh sách bạn bè của cả hai
        user.friendIds.remove(friend_id)
        friend.friendIds.remove(user_id)
        
        # Lưu thay đổi
        await user.save()
        await friend.save()
        
        return {"message": "Đã hủy kết bạn thành công."}

    @staticmethod
    async def update_user(user_id: str, user_update: UserUpdate):
        """
        Cập nhật thông tin người dùng, bao gồm cả upload avatar và background lên Cloudinary.
        """
        user = await User.get(user_id)
        if not user:
            raise ValueError("Không tìm thấy người dùng.")

        update_data = user_update.model_dump(exclude_unset=True)
        print(f"DEBUG: Received update data keys: {list(update_data.keys())}")

        tmp_avatar_path = None
        tmp_background_path = None

        try:
            # 1️⃣ Upload Avatar lên Cloudinary
            if "avatarBase64" in update_data and update_data["avatarBase64"]:
                print("DEBUG: Processing avatar upload...")
                avatar_data = update_data["avatarBase64"]
                
                # Giải mã base64
                if "," in avatar_data:
                    header, data = avatar_data.split(",", 1)
                    image_bytes = base64.b64decode(data)
                else:
                    image_bytes = base64.b64decode(avatar_data)

                print(f"DEBUG: Avatar decoded, size: {len(image_bytes)} bytes")

                # Lưu tạm file
                with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as tmp:
                    tmp.write(image_bytes)
                    tmp_avatar_path = tmp.name

                print(f"DEBUG: Temp avatar file created at: {tmp_avatar_path}")

                # Xóa ảnh cũ nếu có
                if user.avatarPublicId:
                    print(f"DEBUG: Deleting old avatar: {user.avatarPublicId}")
                    try:
                        destroy(user.avatarPublicId)
                    except Exception as e:
                        print(f"WARNING: Could not delete old avatar: {e}")

                # Upload lên Cloudinary
                print("DEBUG: Uploading avatar to Cloudinary...")
                result = cloudinary_upload(tmp_avatar_path, folder="avatars")
                user.avatarUrl = result["secure_url"]
                user.avatarPublicId = result["public_id"]
                print(f"✅ Avatar uploaded successfully! URL: {user.avatarUrl}")
                
                # Clean up temp file
                os.unlink(tmp_avatar_path)
                tmp_avatar_path = None

            # 2️⃣ Upload Background lên Cloudinary
            if "backgroundBase64" in update_data and update_data["backgroundBase64"]:
                print("DEBUG: Processing background upload...")
                background_data = update_data["backgroundBase64"]
                
                # Giải mã base64
                if "," in background_data:
                    header, data = background_data.split(",", 1)
                    image_bytes = base64.b64decode(data)
                else:
                    image_bytes = base64.b64decode(background_data)

                print(f"DEBUG: Background decoded, size: {len(image_bytes)} bytes")

                # Lưu tạm file
                with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as tmp:
                    tmp.write(image_bytes)
                    tmp_background_path = tmp.name

                print(f"DEBUG: Temp background file created at: {tmp_background_path}")

                # Xóa ảnh cũ nếu có
                if user.backgroundPublicId:
                    print(f"DEBUG: Deleting old background: {user.backgroundPublicId}")
                    try:
                        destroy(user.backgroundPublicId)
                    except Exception as e:
                        print(f"WARNING: Could not delete old background: {e}")

                # Upload lên Cloudinary
                print("DEBUG: Uploading background to Cloudinary...")
                result = cloudinary_upload(tmp_background_path, folder="backgrounds")
                user.backgroundUrl = result["secure_url"]
                user.backgroundPublicId = result["public_id"]
                print(f"✅ Background uploaded successfully! URL: {user.backgroundUrl}")
                
                # Clean up temp file
                os.unlink(tmp_background_path)
                tmp_background_path = None

            # 3️⃣ Cập nhật các trường text
            if "displayName" in update_data and update_data["displayName"]:
                user.displayName = update_data["displayName"]
                print(f"DEBUG: Updated displayName to: {user.displayName}")
                
            if "bio" in update_data:
                user.bio = update_data["bio"] if update_data["bio"] else ""
                print(f"DEBUG: Updated bio to: {user.bio}")

            # 4️⃣ Lưu vào database
            await user.save()
            print(f"✅ User saved successfully!")
            print(f"   - DisplayName: {user.displayName}")
            print(f"   - Bio: {user.bio}")
            print(f"   - AvatarURL: {user.avatarUrl}")
            print(f"   - BackgroundURL: {user.backgroundUrl}")
            
            return user

        except Exception as e:
            print(f"❌ ERROR in update_user: {e}")
            import traceback
            traceback.print_exc()
            
            # Clean up temp files on error
            if tmp_avatar_path and os.path.exists(tmp_avatar_path):
                try:
                    os.unlink(tmp_avatar_path)
                except:
                    pass
            if tmp_background_path and os.path.exists(tmp_background_path):
                try:
                    os.unlink(tmp_background_path)
                except:
                    pass
            
            raise ValueError(f"Lỗi cập nhật thông tin: {str(e)}")

    @staticmethod
    async def delete_account(user_id: str):
        """
        Xóa tài khoản người dùng (soft delete) bằng cách đổi status thành 'deleted'.
        Không xóa khỏi database.
        """
        user = await User.get(user_id)
        if not user:
            raise ValueError("Không tìm thấy người dùng.")
        
        # Kiểm tra xem tài khoản đã bị xóa chưa
        if user.status == 'deleted':
            raise ValueError("Tài khoản này đã bị xóa trước đó.")
        
        # Đổi status thành deleted
        user.status = 'deleted'
        user.updatedAt = datetime.utcnow()
        await user.save()
        
        return {"message": "Tài khoản đã được xóa thành công."}