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
                    (id, document_id, chunk_text, chunk_index, embedding, chunk_metadata)
                    VALUES (:id, :document_id, :chunk_text, :chunk_index, :embedding, :chunk_metadata)
                """),
                {
                    "id": embedding_id,
                    "document_id": document_id,
                    "chunk_text": chunk.text,
                    "chunk_index": chunk.index,
                    "embedding": str(embedding.tolist()),
                    "chunk_metadata": json.dumps(chunk.metadata)
                }
            )
            stored_count += 1
        
        db.commit()
        return stored_count
    
    def search_similar(self, query: str, top_k: int = 5, threshold: float = 0.1) -> List[Dict[str, Any]]:
        """Enhanced search with multiple strategies"""
        try:
            # Get query embedding
            query_embedding = self.embedding_service.generate_embeddings_batch([query])[0]
            logger.info(f"Generated embedding for query: {query}")
            
            # Strategy 1: Try vector similarity search first
            db = SessionLocal()
            try:
                vector_results = db.execute(
                    text("""
                        SELECT 
                            e.id as chunk_id,
                            e.document_id,
                            e.chunk_text,
                            e.chunk_index,
                            d.filename,
1 - (e.embedding <-> :query_embedding) as similarity
                        FROM embeddings e
                        JOIN documents d ON e.document_id = d.id
                        WHERE e.embedding IS NOT NULL
ORDER BY e.embedding <-> :query_embedding
                        LIMIT :limit
                    """),
                    {
                        "query_embedding": str(query_embedding.tolist()),
                        "limit": top_k
                    }
                ).fetchall()
                
                if vector_results:
                    logger.info(f"Found {len(vector_results)} vector similarity results")
                    search_results = []
                    for row in vector_results:
                        if row.similarity >= threshold:
                            search_results.append({
                                "chunk_id": str(row.chunk_id),
                                "document_id": str(row.document_id),
                                "chunk_text": row.chunk_text,
                                "chunk_index": row.chunk_index,
                                "filename": row.filename,
                                "similarity": float(row.similarity)
                            })
                    
                    if search_results:
                        db.close()
                        return search_results
                    else:
                        logger.info(f"Vector search found {len(vector_results)} results but none above threshold {threshold}")
                        
            except Exception as e:
                logger.warning(f"Vector search failed, falling back to text search: {e}")
            finally:
                db.close()
            
            # Strategy 2: Simplified text search fallback with fresh session
            query_words = query.lower().split()
            if not query_words:
                logger.info("No query words found")
                return []
            
            db = SessionLocal()
            try:
                # Use simple text search with OR conditions
                text_conditions = []
                params = {"limit": top_k}
                
                for i, word in enumerate(query_words[:3]):  # Limit to 3 words to avoid complexity
                    text_conditions.append(f"LOWER(e.chunk_text) LIKE :word_{i}")
                    params[f"word_{i}"] = f"%{word}%"
                
                if text_conditions:
                    where_clause = " OR ".join(text_conditions)
                    logger.info(f"Text search with conditions: {where_clause}")
                    
                    results = db.execute(
                        text(f"""
                            SELECT 
                                e.id as chunk_id,
                                e.document_id,
                                e.chunk_text,
                                e.chunk_index,
                                d.filename,
                                0.7 as similarity
                            FROM embeddings e
                            JOIN documents d ON e.document_id = d.id
                            WHERE ({where_clause})
                            ORDER BY e.chunk_index
                            LIMIT :limit
                        """),
                        params
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
                    
                    logger.info(f"Found {len(search_results)} text search results for query: {query}")
                    return search_results
                else:
                    logger.info("No text conditions generated")
                    return []
            except Exception as e:
                logger.error(f"Text search failed: {e}")
                db.rollback()
                return []
            finally:
                db.close()
                
        except Exception as e:
            logger.error(f"Search completely failed: {e}")
            return []

def get_vector_store() -> VectorStore:
    return VectorStore()
