import asyncio
from ..models.conversation import Conversation, LastMessage
from ..models.message import Message
from ..models.user import User
from ..websocket import manager
from ..schemas.message_schema import ConversationPublic, LastMessagePublic, MessagePublic, SimpleMessagePublic
from datetime import datetime
from .user_service import UserService

# Các hàm trợ giúp để chuyển đổi các đối tượng mô hình thành từ điển để phát sóng
def map_conversation_to_public_dict(convo: Conversation) -> dict:
    """Chuyển đổi một mô hình Conversation thành một từ điển có thể tuần tự hóa JSON."""
    public_convo = ConversationPublic(
        id=str(convo.id),
        participantIds=convo.participantIds,
        lastMessage=LastMessagePublic(**convo.lastMessage.model_dump()) if convo.lastMessage else None,
        updatedAt=convo.updatedAt,
        seenIds=convo.seenIds
    )
    return public_convo.model_dump()

def map_message_to_public_dict(msg: Message) -> dict:
    """Chuyển đổi một mô hình Message thành một từ điển có thể tuần tự hóa JSON."""
    public_msg = MessagePublic(
        id=str(msg.id),
        conversationId=msg.conversationId,
        senderId=msg.senderId,
        content=msg.content,
        createdAt=msg.createdAt
    )
    return public_msg.model_dump()


class MessageService:

    @staticmethod
    async def get_or_create_conversation(participant_ids: list[str]):
        """
        Tìm một cuộc trò chuyện hiện có hoặc tạo một cuộc trò chuyện mới.
        """
        # Sắp xếp các ID để đảm bảo tính nhất quán cho các truy vấn
        canonical_participants = sorted(list(set(participant_ids)))

        if len(canonical_participants) < 2:
            raise ValueError("Một cuộc trò chuyện yêu cầu ít nhất hai người tham gia.")

        # Tìm kiếm một cuộc trò chuyện với chính xác những người tham gia này
        conversation = await Conversation.find_one({"participantIds": canonical_participants})

        if not conversation:
            # Nếu không tìm thấy, hãy tạo một cuộc trò chuyện mới
            conversation = Conversation(participantIds=canonical_participants)
            await conversation.save()
        
        return conversation

    @staticmethod
    async def send_message(sender_id: str, conversation_id: str, content: dict):
        """
        Gửi một tin nhắn, lưu nó và phát nó đến những người tham gia được kết nối.
        """
        conversation = await Conversation.get(conversation_id)
        if not conversation:
            raise ValueError("Không tìm thấy cuộc trò chuyện.")

        if sender_id not in conversation.participantIds:
            raise PermissionError("Người gửi không phải là người tham gia cuộc trò chuyện này.")

        # Tạo và lưu tin nhắn
        message = Message(
            conversationId=conversation_id,
            senderId=sender_id,
            content=content
        )
        await message.save()

        # Cập nhật tin nhắn cuối cùng và dấu thời gian của cuộc trò chuyện
        conversation.lastMessage = LastMessage(
            text=content.get("text", ""), 
            senderId=sender_id, 
            timestamp=datetime.utcnow()
        )
        conversation.updatedAt = datetime.utcnow()
        await conversation.save()

        # Chuẩn bị dữ liệu để phát sóng
        message_data = map_message_to_public_dict(message)
        conversation_data = map_conversation_to_public_dict(conversation)

        # Phát sự kiện tin nhắn mới tới tất cả những người tham gia
        broadcast_tasks = []
        for user_id in conversation.participantIds:
            event_payload = {
                "type": "new_message",
                "payload": {
                    "message": message_data,
                    "conversation": conversation_data
                }
            }
            task = manager.broadcast_to_user(user_id, event_payload)
            broadcast_tasks.append(task)
        
        await asyncio.gather(*broadcast_tasks)

        return message

    @staticmethod
    async def get_messages_for_conversation(conversation_id: str, user_id: str, limit: int = 50, skip: int = 0):
        """
        Lấy tất cả các tin nhắn cho một cuộc trò chuyện, xác minh người dùng là người tham gia.
        """
        conversation = await Conversation.get(conversation_id)
        if not conversation or user_id not in conversation.participantIds:
            raise PermissionError("Bạn không được phép xem cuộc trò chuyện này.")

        # Lấy các tin nhắn cho cuộc trò chuyện, được sắp xếp theo mới nhất trước tiên
        messages = await Message.find(
            Message.conversationId == conversation_id, 
            sort="-createdAt", 
            skip=skip, 
            limit=limit
        ).to_list()

        # Lấy ID người gửi duy nhất từ các tin nhắn
        sender_ids = list(set(msg.senderId for msg in messages))
        senders = await UserService.get_users_by_ids(sender_ids)
        senders_map = {str(s.id): s for s in senders}

        # Tạo các đối tượng tin nhắn đơn giản
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
        # Lấy các cuộc trò chuyện cho người dùng, được sắp xếp theo hoạt động gần đây nhất
        return await Conversation.find(
            Conversation.participantIds == user_id, 
            sort="-updatedAt", 
        ).to_list()
    
    @staticmethod
    async def mark_conversation_as_seen(conversation_id: str, user_id: str):
        """
        Đánh dấu một cuộc trò chuyện là đã xem bởi người dùng cụ thể.
        """
        conversation = await Conversation.get(conversation_id)
        if not conversation or user_id not in conversation.participantIds:
            raise PermissionError("Bạn không được phép xem cuộc trò chuyện này.")

        if user_id not in conversation.seenIds:
            conversation.seenIds.append(user_id)
            await conversation.save()

        return conversation