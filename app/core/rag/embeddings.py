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
