import asyncio
from ..models.conversation import Conversation
from ..models.message import Message
from ..websocket import manager
from ..schemas.message_schema import ConversationPublic, LastMessagePublic, MessagePublic

# Các hàm trợ giúp để chuyển đổi các đối tượng mô hình thành từ điển để phát sóng
def map_conversation_to_public_dict(convo: Conversation) -> dict:
    """Chuyển đổi một mô hình Conversation thành một từ điển có thể tuần tự hóa JSON."""
    # Phương thức .dict() của Pydantic không được dùng nữa, .model_dump() là cách mới trong v2
    # Hiện tại giả định một phiên bản Pydantic cũ hơn dựa trên mã gốc.
    public_convo = ConversationPublic(
        id=str(convo._id),
        participantIds=convo.participantIds,
        lastMessage=LastMessagePublic(**convo.lastMessage) if convo.lastMessage else None,
        updatedAt=convo.updatedAt
    )
    return public_convo.dict()

def map_message_to_public_dict(msg: Message) -> dict:
    """Chuyển đổi một mô hình Message thành một từ điển có thể tuần tự hóa JSON."""
    public_msg = MessagePublic(
        id=str(msg._id),
        conversationId=msg.conversationId,
        senderId=msg.senderId,
        content=msg.content,
        createdAt=msg.createdAt
    )
    return public_msg.dict()


class MessageService:

    @staticmethod
    def get_or_create_conversation(participant_ids):
        """
        Tìm một cuộc trò chuyện hiện có hoặc tạo một cuộc trò chuyện mới.
        Đảm bảo không có cuộc trò chuyện trùng lặp nào được tạo cho cùng một nhóm người dùng.
        """
        # Đảm bảo các ID là duy nhất và được sắp xếp để tạo ra một biểu diễn chính tắc
        # của danh sách người tham gia, ngăn chặn các cuộc trò chuyện trùng lặp.
        canonical_participants = sorted(list(set(str(p_id) for p_id in participant_ids)))

        if len(canonical_participants) < 2:
            raise ValueError("Một cuộc trò chuyện yêu cầu ít nhất hai người tham gia.")

        conversation = Conversation.find_by_participants(canonical_participants)

        if not conversation:
            conversation = Conversation(participantIds=canonical_participants)
            conversation.save()
        
        return conversation

    @staticmethod
    async def send_message(sender_id, conversation_id, content):
        """
        Gửi một tin nhắn, lưu nó và phát nó đến những người tham gia được kết nối.
        """
        conversation = Conversation.find_by_id(conversation_id)
        if not conversation:
            raise ValueError("Không tìm thấy cuộc trò chuyện.")

        if str(sender_id) not in conversation.participantIds:
            raise PermissionError("Người gửi không phải là người tham gia cuộc trò chuyện này.")

        # Tạo và lưu tin nhắn. Phương thức .save() cũng cập nhật cuộc trò chuyện.
        message = Message(
            conversationId=conversation_id,
            senderId=sender_id,
            content=content
        )
        message.save()

        # lastMessage của cuộc trò chuyện hiện đã được cập nhật. Tìm nạp lại để có được trạng thái mới nhất.
        updated_conversation = Conversation.find_by_id(conversation_id)

        # Chuẩn bị dữ liệu để phát sóng
        message_data = map_message_to_public_dict(message)
        conversation_data = map_conversation_to_public_dict(updated_conversation)

        # Phát tin nhắn mới và cuộc trò chuyện đã cập nhật cho tất cả những người tham gia
        broadcast_tasks = []
        for user_id in updated_conversation.participantIds:
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
    def get_messages_for_conversation(conversation_id, user_id, limit=50, skip=0):
        """
        Lấy tất cả các tin nhắn cho một cuộc trò chuyện, xác minh người dùng là người tham gia.
        """
        conversation = Conversation.find_by_id(conversation_id)
        if not conversation or str(user_id) not in conversation.participantIds:
            raise PermissionError("Bạn không được phép xem cuộc trò chuyện này.")

        return Message.find_for_conversation(conversation_id, limit=limit, skip=skip)

    @staticmethod
    def get_conversations_for_user(user_id, limit=30, skip=0):
        """
        Lấy tất cả các cuộc trò chuyện cho một người dùng cụ thể.
        """
        return Conversation.find_for_user(user_id, limit=limit, skip=skip)