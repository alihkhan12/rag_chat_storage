import uuid
from pydantic import BaseModel, ConfigDict
from datetime import datetime

class UserBase(BaseModel):
    name: str
    api_key: str

class UserCreate(UserBase):
    pass

class User(UserBase):
    id: uuid.UUID
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

class ChatMessageBase(BaseModel):
    sender: str
    content: str
    retrieved_context: str | None = None

class ChatMessageCreate(ChatMessageBase):
    pass

class ChatMessage(ChatMessageBase):
    id: uuid.UUID
    session_id: uuid.UUID
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

class ChatSessionBase(BaseModel):
    session_name: str = "New Chat"
    is_favorite: bool = False

class ChatSessionCreate(ChatSessionBase):
    pass

class ChatSessionUpdate(BaseModel):
    session_name: str | None = None
    is_favorite: bool | None = None

class ChatSession(ChatSessionBase):
    id: uuid.UUID
    created_at: datetime
    updated_at: datetime
    messages: list[ChatMessage] = []
    model_config = ConfigDict(from_attributes=True)
