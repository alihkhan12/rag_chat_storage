from fastapi import FastAPI, Depends, Request
from fastapi.middleware.cors import CORSMiddleware
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
import time
import os
from contextlib import asynccontextmanager

from .core.database import engine, Base
from .core.security import get_api_key
from .core.limiter import limiter, _rate_limit_exceeded_handler
from .core.logging import logger, log_api_request, log_api_response
from .core.exceptions import register_exception_handlers
from .models import chat, documents
from .api import sessions, messages, health, documents as docs_api, rag_chat

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting RAG Chat App...")
    Base.metadata.create_all(bind=engine)
    
    # Auto-ingest documents from input_docs folder
    try:
        from .core.rag.chunker import DocumentProcessor
        from .core.rag.vectorstore import get_vector_store
        from .core.database import SessionLocal
        import os
        
        input_docs_path = "input_docs"
        if os.path.exists(input_docs_path) and os.listdir(input_docs_path):
            logger.info(f"Auto-ingesting documents from {input_docs_path}...")
            
            processor = DocumentProcessor(chunk_size=500, chunk_overlap=50)
            vector_store = get_vector_store()
            db = SessionLocal()
            
            try:
                results = processor.process_folder(input_docs_path)
                processed_count = 0
                total_chunks = 0
                
                for document, chunks in results:
                    try:
                        document_id = vector_store.store_document(document, db)
                        stored_count = vector_store.store_embeddings(chunks, document_id, db)
                        processed_count += 1
                        total_chunks += stored_count
                        logger.info(f"Processed {document.filename}: {stored_count} chunks")
                    except Exception as e:
                        logger.error(f"Failed to process {document.filename}: {e}")
                
                logger.info(f"Auto-ingestion complete: {processed_count} documents, {total_chunks} chunks")
            finally:
                db.close()
        else:
            logger.info(f"No documents found in {input_docs_path} for auto-ingestion")
    except Exception as e:
        logger.error(f"Auto-ingestion failed: {e}")
    
    yield
    logger.info("Shutting down...")

app = FastAPI(title="RAG Chat App", version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)
register_exception_handlers(app)

@app.middleware("http")
async def log_requests(request: Request, call_next):
    if request.url.path.startswith("/health"):
        return await call_next(request)
    start_time = time.time()
    response = await call_next(request)
    duration_ms = (time.time() - start_time) * 1000
    response.headers["X-Process-Time"] = f"{duration_ms:.2f}ms"
    return response

app.include_router(health.router)
app.include_router(sessions.router, dependencies=[Depends(get_api_key)])
app.include_router(messages.router, dependencies=[Depends(get_api_key)])
app.include_router(docs_api.router, dependencies=[Depends(get_api_key)])
app.include_router(rag_chat.router, dependencies=[Depends(get_api_key)])

@app.get("/")
def read_root():
    return {"message": "RAG Chat Storage API", "docs": "/docs"}
