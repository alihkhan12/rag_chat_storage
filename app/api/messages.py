import uuid
from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.orm import Session
from ..models import chat as models
from ..schemas import chat as schemas
from .sessions import get_db
from ..core.limiter import limiter

router = APIRouter(prefix="/sessions/{session_id}/messages", tags=["Chat Messages"])

@router.post("/", response_model=schemas.ChatMessage, status_code=status.HTTP_201_CREATED)
@limiter.limit("100/minute")
async def add_message_to_session(request: Request, session_id: uuid.UUID, message: schemas.ChatMessageCreate, db: Session = Depends(get_db)):
    db_session = db.query(models.ChatSession).filter(models.ChatSession.id == session_id).first()
    if not db_session:
        raise HTTPException(status_code=404, detail="Chat session not found")
    db_message = models.ChatMessage(**message.model_dump(), session_id=session_id)
    db.add(db_message)
    db.commit()
    db.refresh(db_message)
    return db_message

@router.get("/", response_model=list[schemas.ChatMessage])
async def get_messages_for_session(request: Request, session_id: uuid.UUID, db: Session = Depends(get_db), skip: int = 0, limit: int = 100):
    messages = db.query(models.ChatMessage).filter(models.ChatMessage.session_id == session_id).order_by(models.ChatMessage.created_at).offset(skip).limit(limit).all()
    return messages
