from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect, Query
from typing import List
from ..services import MessageService
from ..schemas import (
    ConversationCreate,
    MessageCreate,
    ConversationPublic,
    MessagePublic,
    LastMessagePublic
)
from ..models import User, Conversation, Message
from ..security import get_current_user, get_user_from_token
from ..websocket import manager

router = APIRouter(tags=["Chat"])

# TODO: Chuyển các hàm map này sang một mô-đun tiện ích hoặc một phần của service layer
# để tuân thủ nguyên tắc Single Responsibility Principle và giữ cho router layer gọn gàng.

def map_conversation_to_public(convo: Conversation) -> ConversationPublic:
    """
    Hàm hỗ trợ để ánh xạ một đối tượng Conversation (mô hình Beanie)
    sang một đối tượng ConversationPublic (lược đồ Pydantic).
    """
    return ConversationPublic(
        id=str(convo.id),
        participantIds=convo.participantIds,
        lastMessage=LastMessagePublic(**convo.lastMessage.model_dump()) if convo.lastMessage else None,
        updatedAt=convo.updatedAt
    )

def map_message_to_public(msg: Message) -> MessagePublic:
    """
    Hàm hỗ trợ để ánh xạ một đối tượng Message (mô hình Beanie)
    sang một đối tượng MessagePublic (lược đồ Pydantic).
    """
    return MessagePublic(
        id=str(msg.id),
        conversationId=msg.conversationId,
        senderId=msg.senderId,
        content=msg.content,
        createdAt=msg.createdAt
    )

@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket, token: str = Query(...)):
    """
    Điểm cuối WebSocket để quản lý kết nối thời gian thực của người dùng.
    - Xác thực người dùng bằng token JWT được cung cấp dưới dạng tham số truy vấn.
    - Quản lý vòng đời kết nối (kết nối, ngắt kết nối).
    """
    try:
        user = await get_user_from_token(token)
    except HTTPException:
        await websocket.close(code=1008)  # Policy Violation
        return

    user_id = str(user.id)
    await manager.connect(user_id, websocket)
    
    try:
        while True:
            # Giữ kết nối mở để nhận các sự kiện trong tương lai từ server.
            # Logic xử lý tin nhắn đến từ client có thể được thêm vào đây nếu cần.
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(user_id, websocket)


@router.post("/api/messages/conversations", response_model=ConversationPublic, status_code=201)
async def get_or_create_conversation(
    convo_data: ConversationCreate,
    current_user: User = Depends(get_current_user)
):
    """
    Lấy một cuộc trò chuyện hiện có hoặc tạo một cuộc trò chuyện mới giữa những người tham gia.
    Người dùng hiện tại sẽ tự động được thêm vào cuộc trò chuyện.
    """
    participant_ids = set(convo_data.participant_ids)
    participant_ids.add(str(current_user.id))
    
    try:
        conversation = await MessageService.get_or_create_conversation(list(participant_ids))
        return map_conversation_to_public(conversation)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/api/messages/conversations", response_model=List[ConversationPublic])
async def get_user_conversations(
    current_user: User = Depends(get_current_user),
    skip: int = 0,
    limit: int = 30
):
    """
    Lấy danh sách các cuộc trò chuyện của người dùng đã được xác thực,
    sắp xếp theo hoạt động gần đây nhất.
    """
    convos = await MessageService.get_conversations_for_user(
        user_id=str(current_user.id),
        skip=skip,
        limit=limit
    )
    return [map_conversation_to_public(convo) for convo in convos]

@router.post("/api/messages/conversations/{conversation_id}/messages", response_model=MessagePublic, status_code=201)
async def send_message(
    conversation_id: str,
    message_data: MessageCreate,
    current_user: User = Depends(get_current_user)
):
    """
    Gửi một tin nhắn đến một cuộc trò chuyện cụ thể.
    Tin nhắn sẽ được lưu và phát tới những người tham gia khác trong thời gian thực.
    """
    try:
        # `sender_id` được lấy từ `current_user` để đảm bảo an toàn
        message = await MessageService.send_message(
            sender_id=str(current_user.id),
            conversation_id=conversation_id,
            content=message_data.content
        )
        return map_message_to_public(message)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))

@router.get("/api/messages/conversations/{conversation_id}/messages", response_model=List[MessagePublic])
async def get_conversation_messages(
    conversation_id: str,
    current_user: User = Depends(get_current_user),
    skip: int = 0,
    limit: int = 50
):
    """
    Lấy danh sách các tin nhắn trong một cuộc trò chuyện cụ thể.
    Chỉ những người tham gia cuộc trò chuyện mới có quyền truy cập.
    """
    try:
        messages = await MessageService.get_messages_for_conversation(
            conversation_id=conversation_id,
            user_id=str(current_user.id),
            skip=skip,
            limit=limit
        )
        return [map_message_to_public(msg) for msg in messages]
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))