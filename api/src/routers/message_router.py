from fastapi import APIRouter, Depends, HTTPException, Form, File, UploadFile
from typing import List, Optional
from ..services import MessageService
from ..schemas import (
    ConversationCreate,
    ConversationPublic,
    ConversationWithParticipants,
    SimpleMessagePublic
)
from ..models import User
from ..security import get_current_user
from ..utils import map_conversation_to_public_dict, map_message_to_public_dict



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
        conversation = await MessageService.get_or_create_conversation(
            participant_ids=list(participant_ids),
            is_group=convo_data.is_group,
            name=convo_data.name
        )
        return map_conversation_to_public_dict(conversation)
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

    return convos


@router.post("/conversations/{conversation_id}/messages")
async def send_message(
    conversation_id: str,
    current_user: User = Depends(get_current_user),
    type: str = Form(...),
    files: Optional[List[UploadFile]] = None,
    text: str = Form(None)
):
    """
    Nhận tin nhắn (text hoặc media) từ client và giao cho service xử lý.
    """
    if type == "text": #Tin nhắn văn bản
        content = {"type": type, "text": text}
    elif type == "audio": #Tin nhắn thoại
        content = {"type": type, "url": None}
    else: #Tin nhắn hình ảnh, video
        content = {"type": type, "urls": None}

    message = await MessageService.send_message(
        sender_id=str(current_user.id),
        conversation_id=conversation_id,
        content=content,
        files=files
    )
    return map_message_to_public_dict(message)

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