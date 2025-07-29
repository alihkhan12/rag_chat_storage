"""API endpoints for document and RAG operations"""
import os
import shutil
from typing import List
from fastapi import APIRouter, Depends, HTTPException, Request, UploadFile, File, Form
from sqlalchemy.orm import Session
from datetime import datetime
from ..schemas import documents as schemas
from ..models import documents as models
from ..core.limiter import limiter
from ..core.logging import logger
from ..core.rag.chunker import DocumentProcessor
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
    """Ingest documents from folder (supports PDF, TXT, JSON, XML, CSV, MD, HTML, LOG, YAML)"""
    start_time = datetime.utcnow()
    
    try:
        processor = DocumentProcessor(ingest_request.chunk_size, ingest_request.chunk_overlap)
        vector_store = get_vector_store()
        
        results = processor.process_folder(ingest_request.folder_path)
        
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

@router.post("/upload", response_model=schemas.DocumentIngestionResponse)
@limiter.limit("10/minute")
async def upload_documents(
    request: Request,
    files: List[UploadFile] = File(...),
    chunk_size: int = Form(500),
    chunk_overlap: int = Form(50),
    db: Session = Depends(get_db)
):
    """Upload and ingest documents directly"""
    start_time = datetime.utcnow()
    
    # Ensure input_docs directory exists
    upload_dir = "/Volumes/Personal/rag_chat_storage/input_docs"
    os.makedirs(upload_dir, exist_ok=True)
    
    uploaded_files = []
    failed_uploads = []
    
    try:
        # Save uploaded files
        for file in files:
            if file.filename:
                file_path = os.path.join(upload_dir, file.filename)
                try:
                    with open(file_path, "wb") as buffer:
                        shutil.copyfileobj(file.file, buffer)
                    uploaded_files.append(file.filename)
                    logger.info(f"Uploaded file: {file.filename}")
                except Exception as e:
                    logger.error(f"Failed to upload {file.filename}: {e}")
                    failed_uploads.append(file.filename)
        
        # Process uploaded files
        processor = DocumentProcessor(chunk_size, chunk_overlap)
        vector_store = get_vector_store()
        
        results = processor.process_folder(upload_dir)
        
        processed_count = 0
        total_chunks = 0
        failed_documents = []
        
        for document, chunks in results:
            # Only process files that were just uploaded
            if document.filename in uploaded_files:
                try:
                    document_id = vector_store.store_document(document, db)
                    stored_count = vector_store.store_embeddings(chunks, document_id, db)
                    processed_count += 1
                    total_chunks += stored_count
                    logger.info(f"Processed {document.filename}: {stored_count} chunks")
                except Exception as e:
                    logger.error(f"Failed to process {document.filename}: {e}")
                    failed_documents.append(document.filename)
        
        processing_time = (datetime.utcnow() - start_time).total_seconds()
        
        # Combine failed uploads and failed processing
        all_failed = failed_uploads + failed_documents
        
        return schemas.DocumentIngestionResponse(
            processed_documents=processed_count,
            total_chunks=total_chunks,
            failed_documents=all_failed,
            processing_time_seconds=processing_time
        )
    except Exception as e:
        logger.error(f"Document upload failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))
