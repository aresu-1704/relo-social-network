from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect, Query
from typing import List
from ..services import MessageService, UserService
from ..schemas import (
    ConversationCreate,
    MessageCreate,
    ConversationPublic,
    MessagePublic,
    SimpleMessagePublic,
    LastMessagePublic,
    ConversationWithParticipants,
)
from ..schemas.user_schema import UserPublic
from ..models import User, Conversation, Message
from ..security import get_current_user, get_user_from_token
from ..websocket import manager

def map_conversation_to_public(convo: Conversation) -> ConversationPublic:
    return ConversationPublic(
        id=str(convo.id),
        participantIds=convo.participantIds,
        lastMessage=LastMessagePublic(**convo.lastMessage.model_dump()) if convo.lastMessage else None,
        updatedAt=convo.updatedAt
    )

def map_message_to_public(msg: Message) -> MessagePublic:
    return MessagePublic(
        id=str(msg.id),
        conversationId=msg.conversationId,
        senderId=msg.senderId,
        content=msg.content,
        createdAt=msg.createdAt
    )

router = APIRouter(tags=["Chat"])

@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket, token: str = Query(...)):
    """Điểm cuối WebSocket để quản lý kết nối thời gian thực của người dùng."""
    import logging
    logger = logging.getLogger(__name__)
    
    try:
        user = await get_user_from_token(token)
        logger.info(f"✅ WebSocket: User {user.id} connected")
    except HTTPException as e:
        logger.error(f"❌ WebSocket auth failed: {e.detail}")
        await websocket.close(code=1008)
        return
    except Exception as e:
        logger.error(f"❌ WebSocket unexpected error: {e}")
        await websocket.close(code=1011)
        return

    user_id = str(user.id)
    await manager.connect(user_id, websocket)
    
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        logger.info(f"🔌 User {user_id} disconnected")
        manager.disconnect(user_id, websocket)

@router.post("/api/messages/conversations", response_model=ConversationPublic, status_code=201)
async def get_or_create_conversation(
    convo_data: ConversationCreate,
    current_user: User = Depends(get_current_user)
):
    """Lấy hoặc tạo một cuộc trò chuyện mới giữa những người tham gia."""
    participant_ids = set(convo_data.participant_ids)
    participant_ids.add(str(current_user.id))
    
    try:
        conversation = await MessageService.get_or_create_conversation(list(participant_ids))
        return map_conversation_to_public(conversation)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/api/messages/conversations", response_model=List[ConversationWithParticipants])
async def get_user_conversations(
    current_user: User = Depends(get_current_user),
    skip: int = 0,
    limit: int = 30
):
    """Lấy danh sách các cuộc trò chuyện của người dùng đã được xác thực."""
    convos = await MessageService.get_conversations_for_user(
        user_id=str(current_user.id),
        skip=skip,
        limit=limit
    )
    
    result = []
    
    for convo in convos:
        # Lấy thông tin chi tiết của những người tham gia
        participants = await UserService.get_users_by_ids(convo.participantIds)
        
        # Chuyển đổi sang UserPublic
        participant_publics = [
            UserPublic(
                id=str(p.id),
                username=p.username,
                email=p.email,
                displayName=p.displayName
            ) for p in participants
        ]
        
        # Tạo đối tượng ConversationWithParticipants
        convo_with_participants = ConversationWithParticipants(
            id=str(convo.id),
            participants=participant_publics,  # ✅ Dùng list đã convert
            lastMessage=LastMessagePublic(**convo.lastMessage.model_dump()) if convo.lastMessage else None,
            updatedAt=convo.updatedAt
        )
        result.append(convo_with_participants)
        
    return result


@router.post("/api/messages/conversations/{conversation_id}/messages", response_model=MessagePublic, status_code=201)
async def send_message(
    conversation_id: str,
    message_data: MessageCreate,
    current_user: User = Depends(get_current_user)
):
    """Gửi một tin nhắn đến một cuộc trò chuyện cụ thể."""
    try:
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

@router.get("/api/messages/conversations/{conversation_id}/messages", response_model=List[SimpleMessagePublic])
async def get_conversation_messages(
    conversation_id: str,
    current_user: User = Depends(get_current_user),
    skip: int = 0,
    limit: int = 50
):
    """Lấy danh sách các tin nhắn trong một cuộc trò chuyện với thông tin đơn giản."""
    try:
        messages = await MessageService.get_messages_for_conversation(
            conversation_id=conversation_id,
            user_id=str(current_user.id),
            skip=skip,
            limit=limit
        )
        return messages
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))