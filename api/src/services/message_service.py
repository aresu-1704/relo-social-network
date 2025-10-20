import asyncio
from typing import List, Optional
from ..models import Conversation, LastMessage, Message, ParticipantInfo
from ..websocket import manager
from ..schemas import SimpleMessagePublic, LastMessagePublic, ConversationWithParticipants
from ..schemas.user_schema import UserPublic
from datetime import datetime
from .user_service import UserService
from ..utils import upload_to_cloudinary
from fastapi import UploadFile
from ..utils import map_message_to_public_dict, map_conversation_to_public_dict

class MessageService:

    async def get_or_create_conversation(
        participant_ids: List[str],
        is_group: bool = False,
        name: Optional[str] = None,
    ):
        """
        Tìm một cuộc trò chuyện hiện có hoặc tạo mới.
        - Nếu là chat 1–1 => tìm chính xác 2 người.
        - Nếu là group => luôn tạo mới (vì có thể có nhiều nhóm trùng thành viên).
        """
        canonical_participants = sorted(list(set(participant_ids)))

        if len(canonical_participants) < 2:
            raise ValueError("Một cuộc trò chuyện yêu cầu ít nhất hai người tham gia.")

        if not is_group:
            # 🔍 Tìm chat 1–1 có đúng 2 user
            conversation = await Conversation.find_one({
                "participants": {"$size": len(canonical_participants)},
                "participants.userId": {"$all": canonical_participants},
                "isGroup": False
            })
        else:
            # 🔍 Group chat luôn tạo mới
            conversation = None

        if not conversation:
            participants = [ParticipantInfo(userId=uid) for uid in canonical_participants]
            conversation = Conversation(
                participants=participants,
                isGroup=is_group,
                name=name,
            )
            await conversation.insert()

        return conversation

    @staticmethod
    async def send_message(sender_id: str, conversation_id: str, content: dict, file: UploadFile = None):
        """
        Gửi tin nhắn, upload file nếu có, lưu DB và phát tới người tham gia.
        """
        conversation = await Conversation.get(conversation_id)
        if not conversation:
            raise ValueError("Không tìm thấy cuộc trò chuyện.")

        if sender_id not in [p.userId for p in conversation.participants]:
            raise PermissionError("Người gửi không thuộc cuộc trò chuyện này.");

        # 🧩 Nếu có file (image, video, voice) thì upload lên Cloudinary
        if file:
            upload_result = await upload_to_cloudinary(file)
            content["url"] = upload_result["url"]

        # 📨 Tạo và lưu tin nhắn
        message = Message(
            conversationId=conversation_id,
            senderId=sender_id,
            content=content,
            createdAt=datetime.utcnow() + datetime.timedelta(hours=7)
        )
        await message.save()

        # 🔁 Cập nhật lastMessage cho conversation
        conversation.lastMessage = LastMessage(
            content=message.content,
            senderId=message.senderId,
            createdAt=message.createdAt
        )
        conversation.updatedAt = datetime.utcnow() + datetime.timedelta(hours=7)
        conversation.seenIds = [sender_id]
        await conversation.save()

        # 📡 Phát broadcast tin nhắn mới
        message_data = map_message_to_public_dict(message)
        conversation_data = map_conversation_to_public_dict(conversation)

        tasks = [
            manager.broadcast_to_user(
                uid,
                {
                    "type": "new_message",
                    "payload": {"message": message_data, "conversation": conversation_data}
                }
            )
            for uid in [p.userId for p in conversation.participants]
        ]
        await asyncio.gather(*tasks)

        return message
    
    @staticmethod
    async def get_messages_for_conversation(
        conversation_id: str,
        user_id: str,
        limit: int = 50,
        skip: int = 0
    ):
        """
        Lấy tin nhắn cho một cuộc trò chuyện, chỉ gồm những tin nhắn sau khi user xóa (nếu có).
        """
        conversation = await Conversation.get(conversation_id)
        if not conversation:
            raise PermissionError("Cuộc trò chuyện không tồn tại.")

        # 🔍 Kiểm tra user có trong participant không
        participant = next((p for p in conversation.participants if p.userId == user_id), None)
        if not participant:
            raise PermissionError("Bạn không được phép xem cuộc trò chuyện này.")

        # 🔸 Thời điểm user này đã xóa tin nhắn (nếu có)
        delete_time = participant.lastMessageDelete

        # 🔎 Tạo điều kiện truy vấn tin nhắn
        query = {"conversationId": conversation_id}
        if delete_time:
            query["createdAt"] = {"$gt": delete_time}

        messages = (
            await Message.find(
                query,
                sort="-createdAt",
                skip=skip,
                limit=limit
            ).to_list()
        )

        # 📋 Lấy người gửi để gắn thêm thông tin hiển thị
        sender_ids = list(set(msg.senderId for msg in messages))
        senders = await UserService.get_users_by_ids(sender_ids)
        senders_map = {str(s.id): s for s in senders}

        simple_messages = []
        for msg in messages:
            sender = senders_map.get(msg.senderId)
            if sender:
                simple_messages.append(
                    SimpleMessagePublic(
                        senderId=msg.senderId,
                        avatarUrl=sender.avatarUrl,
                        content=msg.content,
                        createdAt=msg.createdAt
                    )
                )

        return simple_messages


    @staticmethod
    async def get_conversations_for_user(user_id: str):
        """
        Lấy tất cả các cuộc trò chuyện cho một người dùng cụ thể.
        """
        convos = await Conversation.find(
            {"participants.userId": user_id}
        ).sort("-updatedAt").to_list()

        result = []

        for convo in convos:
            # 🔍 Lấy participant info của current_user trong conversation này
            participant_info = next(
                (p for p in convo.participants if p.userId == str(user_id)),
                None
            )
            delete_time = participant_info.lastMessageDelete if participant_info else None

            # 📦 Lấy thông tin chi tiết của người tham gia
            participants = await UserService.get_users_by_ids([p.userId for p in convo.participants])

            participant_publics = [
                UserPublic(
                    id=str(p.id),
                    username=p.username,
                    email=p.email,
                    displayName=p.displayName,
                    avatarUrl=p.avatarUrl,
                    backgroundUrl=p.backgroundUrl,
                    bio=p.bio
                )
                for p in participants
            ]

            last_message_preview = None

            if convo.lastMessage:
                if delete_time and convo.lastMessage.createdAt <= delete_time:
                    last_message_preview = None
                else:
                    last_message_preview = convo.lastMessage

            convo_with_participants = ConversationWithParticipants(
                id=str(convo.id),
                participantsInfo=convo.participants,
                participants=participant_publics,
                lastMessage=(
                    LastMessagePublic(**last_message_preview.model_dump())
                    if last_message_preview
                    else None
                ),
                updatedAt=convo.updatedAt,
                seenIds=convo.seenIds,
                isGroup=convo.isGroup,
                name=convo.name,
                avatarUrl=convo.avatarUrl,
            )
            result.append(convo_with_participants)

        return result
    
    @staticmethod
    async def mark_conversation_as_seen(conversation_id: str, user_id: str):
        """
        Đánh dấu một cuộc trò chuyện là đã xem bởi người dùng cụ thể.
        """
        conversation = await Conversation.get(conversation_id)
        if not conversation or user_id not in [p.userId for p in conversation.participants]:
            raise PermissionError("Bạn không được phép xem cuộc trò chuyện này.")

        if user_id not in conversation.seenIds:
            conversation.seenIds.append(user_id)
            await conversation.save()

        return conversation