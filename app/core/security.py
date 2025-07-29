from fastapi import Security, HTTPException, status, Depends
from fastapi.security import APIKeyHeader
from sqlalchemy.orm import Session
import os
from ..models.chat import User
from .database import SessionLocal

api_key_header = APIKeyHeader(name="X-API-KEY")

# Hardcoded users for demo
HARDCODED_USERS = {
    "z9pD3bE7qR#sW8vY!mK2uN4x": {"id": "user-1", "name": "Dr. Sarah Johnson"},
    "K8mN5pQ2wX@tZ7vB#nC4uA1s": {"id": "user-2", "name": "Prof. Michael Chen"}
}

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

async def get_current_user(api_key_header: str = Security(api_key_header), db: Session = Depends(get_db)):
    if api_key_header not in HARDCODED_USERS:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid or missing API Key")
    
    user_info = HARDCODED_USERS[api_key_header]
    
    # Check if user exists in database, create if not
    user = db.query(User).filter(User.api_key == api_key_header).first()
    if not user:
        user = User(
            name=user_info["name"],
            api_key=api_key_header
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    
    return user

# Backward compatibility
async def get_api_key(api_key_header: str = Security(api_key_header)):
    if api_key_header not in HARDCODED_USERS:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid or missing API Key")
    return api_key_header
