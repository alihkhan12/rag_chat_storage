from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text
from datetime import datetime
from typing import Dict, Any
from ..core.logging import logger
from .sessions import get_db

router = APIRouter(prefix="/health", tags=["Health Check"])

@router.get("/", response_model=Dict[str, Any])
async def health_check(db: Session = Depends(get_db)):
    try:
        db.execute(text("SELECT 1"))
        db_status = "healthy"
    except:
        db_status = "unhealthy"
    
    return {
        "service": "RAG Chat Storage",
        "status": "healthy" if db_status == "healthy" else "unhealthy",
        "timestamp": datetime.utcnow().isoformat(),
        "database": {"status": db_status}
    }
