import uuid
from pydantic import BaseModel, Field
from typing import List, Dict, Any, Optional
from datetime import datetime

class DocumentBase(BaseModel):
    filename: str

class DocumentIngestionRequest(BaseModel):
    folder_path: str = Field(default="input_docs")
    chunk_size: int = Field(default=500, ge=100, le=2000)
    chunk_overlap: int = Field(default=50, ge=0, le=200)

class DocumentIngestionResponse(BaseModel):
    processed_documents: int
    total_chunks: int
    failed_documents: List[str] = []
    processing_time_seconds: float

class RAGSearchRequest(BaseModel):
    query: str = Field(..., min_length=1, max_length=1000)
    top_k: int = Field(default=5, ge=1, le=20)
    threshold: float = Field(default=0.3, ge=0.0, le=1.0)

class RAGSearchResult(BaseModel):
    chunk_id: str
    document_id: str
    filename: str
    chunk_text: str
    similarity: float

class RAGSearchResponse(BaseModel):
    query: str
    results: List[RAGSearchResult]
    total_results: int
