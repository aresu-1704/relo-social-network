from fastapi import APIRouter, Depends, HTTPException, Form, File, UploadFile
from typing import List
from ..services import MessageService, UserService
from ..schemas import (
    ConversationCreate,
    ConversationPublic,
    MessagePublic,
    LastMessagePublic,
    ConversationWithParticipants,
    SimpleMessagePublic
)
from ..schemas.user_schema import UserPublic
from ..models import User, Conversation, Message
from ..security import get_current_user

def map_conversation_to_public(convo: Conversation) -> ConversationPublic:
    return ConversationPublic(
        id=str(convo.id),
        participantIds=convo.participantIds,
        lastMessage=LastMessagePublic(**convo.lastMessage.model_dump()) if convo.lastMessage else None,
        updatedAt=convo.updatedAt,
        seenIds=convo.seenIds
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

@router.post("/conversations", response_model=ConversationPublic, status_code=201)
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

@router.get("/conversations", response_model=List[ConversationWithParticipants])
async def get_user_conversations(
    current_user: User = Depends(get_current_user),
):
    """Lấy danh sách các cuộc trò chuyện của người dùng đã được xác thực."""
    convos = await MessageService.get_conversations_for_user(
        user_id=str(current_user.id),
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
            updatedAt=convo.updatedAt,
            seenIds=convo.seenIds
        )
        result.append(convo_with_participants)
        
    return result


@router.post("/conversations/{conversation_id}/messages")
async def send_message(
    conversation_id: str,
    current_user: User = Depends(get_current_user),
    type: str = Form(...),
    file: UploadFile = File(None),
    text: str = Form(None)
):
    """
    Nhận tin nhắn (text hoặc media) từ client và giao cho service xử lý.
    """
    content = {"type": type, "content": text}

    message = await MessageService.send_message(
        sender_id=str(current_user.id),
        conversation_id=conversation_id,
        content=content,
        file=file  # chuyển file xuống Service
    )
    return map_message_to_public(message)

@router.get("/conversations/{conversation_id}/messages", response_model=List[SimpleMessagePublic])
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
    
@router.post("/conversations/{conversation_id}/seen", status_code=204)
async def mark_conversation_as_seen(
    conversation_id: str,
    current_user: User = Depends(get_current_user)
):
    """Đánh dấu cuộc trò chuyện là đã xem bởi người dùng hiện tại."""
    try:
        await MessageService.mark_conversation_as_seen(
            conversation_id=conversation_id,
            user_id=str(current_user.id)
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))