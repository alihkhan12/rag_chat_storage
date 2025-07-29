import uuid
from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.orm import Session, joinedload
from ..models import chat as models
from ..schemas import chat as schemas
from ..core.database import SessionLocal
from ..core.limiter import limiter
from ..core.security import get_current_user

router = APIRouter(prefix="/sessions", tags=["Chat Sessions"])

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@router.get("/", response_model=list[schemas.ChatSession])
@limiter.limit("60/minute")
async def get_all_chat_sessions(request: Request, current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    sessions = db.query(models.ChatSession).filter(models.ChatSession.user_id == current_user.id).order_by(models.ChatSession.updated_at.desc()).all()
    return sessions

@router.post("/", response_model=schemas.ChatSession, status_code=status.HTTP_201_CREATED)
@limiter.limit("20/minute")
async def create_chat_session(request: Request, session: schemas.ChatSessionCreate, current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    db_session = models.ChatSession(**session.model_dump(), user_id=current_user.id)
    db.add(db_session)
    db.commit()
    db.refresh(db_session)
    return db_session

@router.get("/{session_id}", response_model=schemas.ChatSession)
async def get_chat_session(session_id: uuid.UUID, db: Session = Depends(get_db)):
    db_session = db.query(models.ChatSession).options(joinedload(models.ChatSession.messages)).filter(models.ChatSession.id == session_id).first()
    if not db_session:
        raise HTTPException(status_code=404, detail="Chat session not found")
    return db_session

@router.patch("/{session_id}", response_model=schemas.ChatSession)
async def update_chat_session(request: Request, session_id: uuid.UUID, update: schemas.ChatSessionUpdate, db: Session = Depends(get_db)):
    db_session = db.query(models.ChatSession).filter(models.ChatSession.id == session_id).first()
    if not db_session:
        raise HTTPException(status_code=404, detail="Chat session not found")
    update_data = update.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(db_session, key, value)
    db.commit()
    db.refresh(db_session)
    return db_session

@router.delete("/{session_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_chat_session(request: Request, session_id: uuid.UUID, db: Session = Depends(get_db)):
    db_session = db.query(models.ChatSession).filter(models.ChatSession.id == session_id).first()
    if not db_session:
        raise HTTPException(status_code=404, detail="Chat session not found")
    db.delete(db_session)
    db.commit()
    return None
