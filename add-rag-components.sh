#!/bin/bash

# Script to add complete RAG functionality
#cd /home/oracle/aws_projects/rag_chat_storage
cd /Volumes/Personal/rag_chat_storage

echo "🤖 Adding RAG components..."

# 1. Update requirements.txt for RAG
cat >> requirements.txt << 'EOF'

# Additional RAG Requirements
sentence-transformers==2.2.2
PyPDF2==3.0.1
langchain==0.0.350
numpy==1.26.4
torch>=2.0.0
EOF

# 2. Create RAG components
echo "📝 Creating RAG embeddings service..."
cat > app/core/rag/embeddings.py << 'EOF'
"""Embeddings service using sentence-transformers"""
import numpy as np
from typing import List, Optional
from sentence_transformers import SentenceTransformer
import torch
from ..logging import logger

DEFAULT_MODEL = "all-MiniLM-L6-v2"
EMBEDDING_DIMENSION = 384

class EmbeddingService:
    def __init__(self, model_name: str = DEFAULT_MODEL):
        self.model_name = model_name
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        self._model = None
        logger.info(f"Initialized EmbeddingService with model: {model_name}")
    
    @property
    def model(self) -> SentenceTransformer:
        if self._model is None:
            logger.info(f"Loading embedding model: {self.model_name}")
            self._model = SentenceTransformer(self.model_name, device=self.device)
            self._model.max_seq_length = 256
        return self._model
    
    def generate_embedding(self, text: str) -> np.ndarray:
        if not text or not text.strip():
            raise ValueError("Cannot generate embedding for empty text")
        
        embedding = self.model.encode(
            text,
            convert_to_numpy=True,
            normalize_embeddings=True,
            show_progress_bar=False
        )
        return embedding
    
    def generate_embeddings_batch(self, texts: List[str], batch_size: int = 32) -> List[np.ndarray]:
        if not texts:
            return []
        
        valid_texts = [text for text in texts if text and text.strip()]
        embeddings = self.model.encode(
            valid_texts,
            batch_size=batch_size,
            convert_to_numpy=True,
            normalize_embeddings=True,
            show_progress_bar=True
        )
        return embeddings

_embedding_service = None

def get_embedding_service() -> EmbeddingService:
    global _embedding_service
    if _embedding_service is None:
        _embedding_service = EmbeddingService()
    return _embedding_service
EOF

echo "📝 Creating PDF chunker..."
cat > app/core/rag/chunker.py << 'EOF'
"""PDF processing and chunking service"""
import os
from typing import List, Dict, Any, Optional
from dataclasses import dataclass
import PyPDF2
from langchain.text_splitter import RecursiveCharacterTextSplitter
from ..logging import logger

@dataclass
class Document:
    filename: str
    content: str
    page_count: int
    metadata: Dict[str, Any]

@dataclass
class Chunk:
    text: str
    index: int
    page_number: Optional[int]
    metadata: Dict[str, Any]

class PDFChunker:
    def __init__(self, chunk_size: int = 500, chunk_overlap: int = 50):
        self.chunk_size = chunk_size
        self.chunk_overlap = chunk_overlap
        self.text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=chunk_size,
            chunk_overlap=chunk_overlap,
            separators=["\n\n", "\n", ". ", "! ", "? ", "; ", ", ", " ", ""]
        )
        logger.info(f"Initialized PDFChunker with chunk_size={chunk_size}")
    
    def extract_text_from_pdf(self, pdf_path: str) -> Document:
        if not os.path.exists(pdf_path):
            raise FileNotFoundError(f"PDF not found: {pdf_path}")
        
        with open(pdf_path, 'rb') as file:
            pdf_reader = PyPDF2.PdfReader(file)
            page_count = len(pdf_reader.pages)
            
            full_text = ""
            for page_num in range(page_count):
                page = pdf_reader.pages[page_num]
                page_text = page.extract_text()
                full_text += page_text + "\n\n"
            
            metadata = {
                "filename": os.path.basename(pdf_path),
                "file_path": pdf_path,
                "page_count": page_count,
                "file_size": os.path.getsize(pdf_path)
            }
            
            return Document(
                filename=os.path.basename(pdf_path),
                content=full_text.strip(),
                page_count=page_count,
                metadata=metadata
            )
    
    def chunk_document(self, document: Document) -> List[Chunk]:
        texts = self.text_splitter.split_text(document.content)
        chunks = []
        for index, text in enumerate(texts):
            chunk = Chunk(
                text=text,
                index=index,
                page_number=None,
                metadata={
                    "filename": document.filename,
                    "chunk_size": len(text),
                    "total_chunks": len(texts)
                }
            )
            chunks.append(chunk)
        return chunks
    
    def process_pdf_folder(self, folder_path: str) -> List[tuple[Document, List[Chunk]]]:
        if not os.path.exists(folder_path):
            os.makedirs(folder_path)
            logger.info(f"Created folder: {folder_path}")
        
        results = []
        pdf_files = [f for f in os.listdir(folder_path) if f.lower().endswith('.pdf')]
        
        for pdf_file in pdf_files:
            pdf_path = os.path.join(folder_path, pdf_file)
            try:
                document = self.extract_text_from_pdf(pdf_path)
                chunks = self.chunk_document(document)
                results.append((document, chunks))
            except Exception as e:
                logger.error(f"Failed to process {pdf_file}: {e}")
        
        return results

def get_pdf_chunker(chunk_size: int = 500, chunk_overlap: int = 50) -> PDFChunker:
    return PDFChunker(chunk_size, chunk_overlap)
EOF

echo "📝 Creating vector store..."
cat > app/core/rag/vectorstore.py << 'EOF'
"""Vector store service for pgvector operations"""
import uuid
from typing import List, Dict, Any, Optional
import numpy as np
from sqlalchemy import text
from sqlalchemy.orm import Session
import json
from ..database import SessionLocal
from ..logging import logger
from .embeddings import get_embedding_service
from .chunker import Chunk, Document

class VectorStore:
    def __init__(self):
        self.embedding_service = get_embedding_service()
        logger.info("Initialized VectorStore")
    
    def store_document(self, document: Document, db: Session) -> str:
        try:
            existing = db.execute(
                text("SELECT id FROM documents WHERE filename = :filename"),
                {"filename": document.filename}
            ).fetchone()
            
            if existing:
                document_id = existing[0]
                db.execute(
                    text("UPDATE documents SET content = :content, page_count = :page_count WHERE id = :id"),
                    {"id": document_id, "content": document.content, "page_count": document.page_count}
                )
            else:
                document_id = str(uuid.uuid4())
                db.execute(
                    text("INSERT INTO documents (id, filename, content, page_count) VALUES (:id, :filename, :content, :page_count)"),
                    {"id": document_id, "filename": document.filename, "content": document.content, "page_count": document.page_count}
                )
            
            db.commit()
            return document_id
        except Exception as e:
            db.rollback()
            raise e
    
    def store_embeddings(self, chunks: List[Chunk], document_id: str, db: Session) -> int:
        if not chunks:
            return 0
        
        # Delete existing embeddings
        db.execute(
            text("DELETE FROM embeddings WHERE document_id = :document_id"),
            {"document_id": document_id}
        )
        
        # Generate embeddings
        texts = [chunk.text for chunk in chunks]
        embeddings = self.embedding_service.generate_embeddings_batch(texts)
        
        # Store embeddings
        stored_count = 0
        for chunk, embedding in zip(chunks, embeddings):
            embedding_id = str(uuid.uuid4())
            db.execute(
                text("""
                    INSERT INTO embeddings 
                    (id, document_id, chunk_text, chunk_index, embedding, metadata)
                    VALUES (:id, :document_id, :chunk_text, :chunk_index, :embedding, :metadata)
                """),
                {
                    "id": embedding_id,
                    "document_id": document_id,
                    "chunk_text": chunk.text,
                    "chunk_index": chunk.index,
                    "embedding": embedding.tolist(),
                    "metadata": json.dumps(chunk.metadata)
                }
            )
            stored_count += 1
        
        db.commit()
        return stored_count
    
    def search_similar(self, query: str, top_k: int = 5, threshold: float = 0.3) -> List[Dict[str, Any]]:
        db = SessionLocal()
        try:
            # Generate query embedding
            query_embedding = self.embedding_service.generate_embedding(query)
            
            # Search
            results = db.execute(
                text("""
                    SELECT 
                        e.id as chunk_id,
                        e.document_id,
                        e.chunk_text,
                        e.chunk_index,
                        d.filename,
                        1 - (e.embedding <=> :embedding::vector) as similarity
                    FROM embeddings e
                    JOIN documents d ON e.document_id = d.id
                    WHERE 1 - (e.embedding <=> :embedding::vector) >= :threshold
                    ORDER BY e.embedding <=> :embedding::vector
                    LIMIT :limit
                """),
                {
                    "embedding": query_embedding.tolist(),
                    "threshold": threshold,
                    "limit": top_k
                }
            ).fetchall()
            
            search_results = []
            for row in results:
                search_results.append({
                    "chunk_id": str(row.chunk_id),
                    "document_id": str(row.document_id),
                    "chunk_text": row.chunk_text,
                    "chunk_index": row.chunk_index,
                    "filename": row.filename,
                    "similarity": float(row.similarity)
                })
            
            return search_results
        finally:
            db.close()

def get_vector_store() -> VectorStore:
    return VectorStore()
EOF

echo "📝 Updating models for pgvector..."
cat > app/models/documents.py << 'EOF'
import uuid
from sqlalchemy import Column, String, Integer, Text, TIMESTAMP, JSON
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from pgvector.sqlalchemy import Vector
from ..core.database import Base

class Document(Base):
    __tablename__ = "documents"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    filename = Column(String(255), nullable=False, unique=True, index=True)
    content = Column(Text, nullable=False)
    page_count = Column(Integer, nullable=False)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())

class Embedding(Base):
    __tablename__ = "embeddings"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    document_id = Column(UUID(as_uuid=True), nullable=False, index=True)
    chunk_text = Column(Text, nullable=False)
    chunk_index = Column(Integer, nullable=False)
    embedding = Column(Vector(384), nullable=False)
    metadata = Column(JSON, default=dict)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())
EOF

echo "📝 Updating document schemas..."
cat >> app/schemas/documents.py << 'EOF'

import uuid
from pydantic import BaseModel, Field
from typing import List, Dict, Any, Optional
from datetime import datetime

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
EOF

echo "📝 Creating full documents API..."
cat > app/api/documents.py << 'EOF'
"""API endpoints for document and RAG operations"""
import os
from typing import List
from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from datetime import datetime
from ..schemas import documents as schemas
from ..models import documents as models
from ..core.limiter import limiter
from ..core.logging import logger
from ..core.rag.chunker import get_pdf_chunker
from ..core.rag.vectorstore import get_vector_store
from .sessions import get_db

router = APIRouter(prefix="/documents", tags=["Documents & RAG"])

@router.post("/ingest", response_model=schemas.DocumentIngestionResponse)
@limiter.limit("5/minute")
async def ingest_documents(
    request: Request,
    ingest_request: schemas.DocumentIngestionRequest,
    db: Session = Depends(get_db)
):
    """Ingest PDF documents from folder"""
    start_time = datetime.utcnow()
    
    try:
        chunker = get_pdf_chunker(ingest_request.chunk_size, ingest_request.chunk_overlap)
        vector_store = get_vector_store()
        
        results = chunker.process_pdf_folder(ingest_request.folder_path)
        
        processed_count = 0
        total_chunks = 0
        failed_documents = []
        
        for document, chunks in results:
            try:
                document_id = vector_store.store_document(document, db)
                stored_count = vector_store.store_embeddings(chunks, document_id, db)
                processed_count += 1
                total_chunks += stored_count
            except Exception as e:
                logger.error(f"Failed to process {document.filename}: {e}")
                failed_documents.append(document.filename)
        
        processing_time = (datetime.utcnow() - start_time).total_seconds()
        
        return schemas.DocumentIngestionResponse(
            processed_documents=processed_count,
            total_chunks=total_chunks,
            failed_documents=failed_documents,
            processing_time_seconds=processing_time
        )
    except Exception as e:
        logger.error(f"Document ingestion failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/", response_model=List[schemas.DocumentBase])
async def list_documents(request: Request, db: Session = Depends(get_db)):
    """List all documents"""
    documents = db.query(models.Document).all()
    return documents

@router.post("/search", response_model=schemas.RAGSearchResponse)
@limiter.limit("100/minute")
async def search_documents(
    request: Request,
    search_request: schemas.RAGSearchRequest
):
    """Search for relevant document chunks"""
    try:
        vector_store = get_vector_store()
        results = vector_store.search_similar(
            search_request.query,
            search_request.top_k,
            search_request.threshold
        )
        
        search_results = [
            schemas.RAGSearchResult(
                chunk_id=r["chunk_id"],
                document_id=r["document_id"],
                filename=r["filename"],
                chunk_text=r["chunk_text"],
                similarity=r["similarity"]
            )
            for r in results
        ]
        
        return schemas.RAGSearchResponse(
            query=search_request.query,
            results=search_results,
            total_results=len(search_results)
        )
    except Exception as e:
        logger.error(f"Search failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))
EOF

echo "📝 Creating test PDFs..."
mkdir -p input_docs

# Create a simple test PDF using Python
cat > create_test_pdf.py << 'EOF'
from fpdf import FPDF
import os

# Create test PDF 1
pdf = FPDF()
pdf.add_page()
pdf.set_font("Arial", size=12)
pdf.cell(200, 10, txt="RAG Test Document 1", ln=1, align='C')
pdf.ln(10)
pdf.multi_cell(0, 10, txt="""This is a test document for the RAG system.

Machine learning is a subset of artificial intelligence that focuses on the development of algorithms and statistical models that enable computer systems to improve their performance on a specific task through experience.

Deep learning is a subset of machine learning that uses neural networks with multiple layers. These neural networks attempt to simulate the behavior of the human brain—albeit far from matching its ability—allowing it to "learn" from large amounts of data.

Natural language processing (NLP) is a branch of AI that helps computers understand, interpret and manipulate human language. NLP draws from many disciplines, including computer science and computational linguistics.""")

pdf.output("input_docs/test_document_1.pdf")

# Create test PDF 2
pdf = FPDF()
pdf.add_page()
pdf.set_font("Arial", size=12)
pdf.cell(200, 10, txt="RAG Test Document 2", ln=1, align='C')
pdf.ln(10)
pdf.multi_cell(0, 10, txt="""This is another test document with different content.

Python is a high-level, interpreted programming language with dynamic semantics. Its high-level built-in data structures, combined with dynamic typing and dynamic binding, make it very attractive for Rapid Application Development.

FastAPI is a modern, fast web framework for building APIs with Python based on standard Python type hints. It's designed to be easy to use and learn, while providing high performance.

Docker is a platform that uses OS-level virtualization to deliver software in packages called containers. Containers are isolated from one another and bundle their own software, libraries and configuration files.""")

pdf.output("input_docs/test_document_2.pdf")

print("✅ Created test PDFs in input_docs/")
EOF

# Install fpdf2 temporarily and create PDFs
echo "Installing fpdf2 and creating test PDFs..."
pip3 install fpdf2 --user --quiet || echo "fpdf2 installation failed, but continuing..."
python3 create_test_pdf.py || echo "PDF creation failed, continuing without test PDFs..."
rm create_test_pdf.py

echo "✅ RAG components added successfully!"
echo ""
echo "🔄 Now rebuild the Docker container with new dependencies:"
echo "   docker-compose down"
echo "   docker-compose up --build -d"