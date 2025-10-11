from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect, Query
from typing import List
from ..services import MessageService, jwt_service
from ..schemas import (
    ConversationCreate,
    MessageCreate,
    ConversationPublic,
    MessagePublic,
    LastMessagePublic
)
from ..models import User
from ..security import get_current_user
from ..websocket import manager

router = APIRouter(tags=["Chat"])

def map_conversation_to_public(convo):
    """Hàm hỗ trợ để ánh xạ một mô hình Conversation sang lược đồ ConversationPublic."""
    return ConversationPublic(
        id=str(convo._id),
        participantIds=convo.participantIds,
        lastMessage=LastMessagePublic(**convo.lastMessage) if convo.lastMessage else None,
        updatedAt=convo.updatedAt
    )

def map_message_to_public(msg):
    """Hàm hỗ trợ để ánh xạ một mô hình Message sang lược đồ MessagePublic."""
    return MessagePublic(
        id=str(msg._id),
        conversationId=msg.conversationId,
        senderId=msg.senderId,
        content=msg.content,
        createdAt=msg.createdAt
    )

@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket, token: str = Query(...)):
    """
    Điểm cuối WebSocket chính cho người dùng.
    Xác thực người dùng thông qua mã thông báo JWT trong tham số truy vấn.
    """
    token_data = jwt_service.decode_access_token(token)
    if token_data is None or token_data.username is None:
        await websocket.close(code=1008)
        return
    
    user = User.find_by_username(token_data.username)
    if user is None:
        await websocket.close(code=1008)
        return

    user_id = str(user._id)
    await manager.connect(user_id, websocket)
    
    try:
        while True:
            # Vòng lặp này giữ cho kết nối tồn tại.
            # Nó có thể được mở rộng để xử lý các tin nhắn đến từ máy khách.
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(user_id, websocket)


@router.post("/api/messages/conversations", response_model=ConversationPublic, status_code=201)
def get_or_create_conversation(
    convo_data: ConversationCreate,
    current_user: User = Depends(get_current_user)
):
    """
    Lấy một cuộc trò chuyện hiện có giữa một nhóm người tham gia hoặc tạo một cuộc trò chuyện mới.
    Người dùng hiện tại được tự động bao gồm.
    """
    participant_ids = set(convo_data.participant_ids)
    participant_ids.add(str(current_user._id))
    
    try:
        conversation = MessageService.get_or_create_conversation(list(participant_ids))
        return map_conversation_to_public(conversation)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/api/messages/conversations", response_model=List[ConversationPublic])
def get_user_conversations(
    current_user: User = Depends(get_current_user),
    skip: int = 0,
    limit: int = 30
):
    """
    Lấy tất cả các cuộc trò chuyện cho người dùng hiện được xác thực.
    """
    convos = MessageService.get_conversations_for_user(
        user_id=current_user._id,
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
    Gửi tin nhắn đến một cuộc trò chuyện cụ thể.
    Đây hiện là một điểm cuối không đồng bộ để cho phép phát sóng.
    """
    try:
        message = await MessageService.send_message(
            sender_id=current_user._id,
            conversation_id=conversation_id,
            content=message_data.content
        )
        return map_message_to_public(message)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))

@router.get("/api/messages/conversations/{conversation_id}/messages", response_model=List[MessagePublic])
def get_conversation_messages(
    conversation_id: str,
    current_user: User = Depends(get_current_user),
    skip: int = 0,
    limit: int = 50
):
    """
    Lấy tất cả các tin nhắn cho một cuộc trò chuyện cụ thể.
    """
    try:
        messages = MessageService.get_messages_for_conversation(
            conversation_id=conversation_id,
            user_id=current_user._id,
            skip=skip,
            limit=limit
        )
        return [map_message_to_public(msg) for msg in messages]
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))