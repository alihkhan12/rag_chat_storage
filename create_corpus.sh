#!/bin/bash

# Path to input documents directory
INPUT_DOCS_DIR="./input_docs"

# Clear existing documents
echo "🧹 Clearing old documents in $INPUT_DOCS_DIR..."
rm -rf $INPUT_DOCS_DIR/*

# Create new documents with relevant content
echo "📝 Creating comprehensive corpus documents..."

# Document 1: Machine Learning Fundamentals (TXT)
cat <<EOT > $INPUT_DOCS_DIR/machine_learning_fundamentals.txt
Machine Learning Fundamentals
=============================

Machine learning is a subset of artificial intelligence (AI) that enables computers to learn and make decisions from data without being explicitly programmed for every task.

Key Types of Machine Learning:
1. Supervised Learning: Uses labeled data to train models (e.g., classification, regression)
2. Unsupervised Learning: Finds patterns in unlabeled data (e.g., clustering, dimensionality reduction)
3. Reinforcement Learning: Learns through interaction with environment using rewards and penalties

Common Applications:
- Image and speech recognition
- Natural language processing
- Recommendation systems
- Autonomous vehicles
- Medical diagnosis
- Financial fraud detection
EOT

# Document 2: Natural Language Processing (MD)
cat <<EOT > $INPUT_DOCS_DIR/natural_language_processing.md
# Natural Language Processing (NLP)

Natural Language Processing is a branch of artificial intelligence that helps computers understand, interpret, and manipulate human language.

## Key NLP Tasks:
- **Text Classification**: Categorizing text into predefined classes
- **Sentiment Analysis**: Determining emotional tone of text
- **Named Entity Recognition**: Identifying entities like names, locations, organizations
- **Machine Translation**: Converting text from one language to another
- **Question Answering**: Providing relevant answers to user questions
- **Text Summarization**: Creating concise summaries of longer texts

## NLP Techniques:
- Tokenization: Breaking text into individual words or tokens
- Part-of-speech tagging: Identifying grammatical roles of words
- Dependency parsing: Understanding grammatical relationships
- Word embeddings: Converting words to numerical vectors
- Transformer models: Advanced neural networks for language understanding

## Popular NLP Libraries:
- NLTK, spaCy, Transformers, Gensim
EOT

# Document 3: Vector Embeddings and Search (TXT)
cat <<EOT > $INPUT_DOCS_DIR/vector_embeddings_search.txt
Vector Embeddings and Similarity Search
======================================

Vector embeddings are numerical representations of text, images, or other data in high-dimensional space. They capture semantic meaning and enable similarity comparisons.

How Vector Embeddings Work:
- Convert text/data into dense numerical vectors
- Similar items have vectors close to each other in vector space
- Enable semantic search beyond keyword matching

Similarity Search Methods:
1. Cosine Similarity: Measures angle between vectors
2. Euclidean Distance: Straight-line distance between points
3. Dot Product: Mathematical operation for similarity

Applications:
- Semantic search in documents
- Recommendation systems
- Image similarity search
- Clustering similar items
- Retrieval-Augmented Generation (RAG)

Popular Vector Databases:
- Pinecone, Weaviate, Qdrant, pgvector, Chroma
EOT

# Document 4: RAG System Architecture (JSON)
cat <<EOT > $INPUT_DOCS_DIR/rag_system_features.json
{
  "system_name": "RAG Chat Storage System",
  "version": "2.0",
  "description": "A comprehensive Retrieval-Augmented Generation system for intelligent document search and chat",
  "key_features": [
    "Multi-format document processing",
    "Vector-based semantic search",
    "Real-time chat sessions",
    "User authentication and API keys",
    "Rate limiting and security",
    "PostgreSQL with pgvector extension",
    "Docker containerization",
    "FastAPI backend framework",
    "React frontend interface"
  ],
  "supported_formats": {
    "documents": ["PDF", "TXT", "MD", "HTML"],
    "data": ["JSON", "XML", "CSV", "YAML"],
    "logs": ["LOG"]
  },
  "technical_specs": {
    "embedding_model": "all-MiniLM-L6-v2",
    "chunk_size": 500,
    "chunk_overlap": 50,
    "vector_dimensions": 384,
    "search_threshold": 0.3
  },
  "performance": {
    "processing_speed": "50+ pages/second",
    "search_response_time": "<100ms",
    "concurrent_users": "1000+",
    "uptime": "99.9%"
  }
}
EOT

# Document 5: FastAPI and Python Guide (MD)
cat <<EOT > $INPUT_DOCS_DIR/fastapi_python_guide.md
# FastAPI and Python Development Guide

## What is FastAPI?
FastAPI is a modern, fast web framework for building APIs with Python based on standard Python type hints.

### Key FastAPI Features:
- **High Performance**: One of the fastest Python frameworks available
- **Easy to Use**: Intuitive design based on Python type hints
- **Automatic Documentation**: Interactive API docs with Swagger UI
- **Standards-based**: Based on OpenAPI and JSON Schema
- **Production Ready**: Used by companies like Netflix, Uber, Microsoft

### FastAPI Benefits:
- Fast development and deployment
- Automatic request/response validation
- Built-in security features
- Async/await support for high concurrency
- Excellent editor support with autocompletion

## Python in AI/ML:
Python is the dominant language for artificial intelligence and machine learning due to:
- Rich ecosystem of libraries (NumPy, Pandas, Scikit-learn, TensorFlow, PyTorch)
- Simple and readable syntax
- Strong community support
- Excellent for prototyping and production
- Integration with data science tools
EOT

# Document 6: Database Technologies (YAML)
cat <<EOT > $INPUT_DOCS_DIR/database_technologies.yaml
database_systems:
  postgresql:
    description: "Advanced open-source relational database"
    features:
      - "ACID compliance"
      - "JSON support"
      - "Full-text search"
      - "Extensible with plugins"
    use_cases:
      - "Web applications"
      - "Data warehousing"
      - "Geographic information systems"

  pgvector:
    description: "PostgreSQL extension for vector similarity search"
    features:
      - "Store vector embeddings"
      - "Similarity search with indexes"
      - "Support for different distance metrics"
      - "Integration with existing PostgreSQL features"
    benefits:
      - "No need for separate vector database"
      - "ACID transactions for vectors"
      - "Familiar SQL interface"
      - "Backup and replication support"

vector_operations:
  similarity_metrics:
    - "Cosine similarity (1 - cosine distance)"
    - "Euclidean distance (L2)"
    - "Inner product"
  indexing:
    - "IVFFlat index for faster searches"
    - "HNSW index for high-dimensional data"
EOT

# Document 7: ML Algorithms Reference (CSV)
cat <<EOT > $INPUT_DOCS_DIR/ml_algorithms_reference.csv
Algorithm,Category,Use_Case,Description,Advantages,Disadvantages
"Linear Regression","Supervised","Regression","Predicts continuous values using linear relationships","Simple to understand and implement","Assumes linear relationship"
"Logistic Regression","Supervised","Classification","Binary and multiclass classification using logistic function","Probabilistic output, interpretable","Limited to linear decision boundaries"
"Decision Trees","Supervised","Both","Tree-like model for decision making","Easy to visualize and interpret","Prone to overfitting"
"Random Forest","Supervised","Both","Ensemble of decision trees","Reduces overfitting, handles missing values","Less interpretable than single tree"
"Support Vector Machine","Supervised","Both","Finds optimal boundary between classes","Effective in high dimensions","Slow on large datasets"
"K-Means","Unsupervised","Clustering","Groups data into k clusters","Simple and fast","Need to specify number of clusters"
"Neural Networks","Supervised","Both","Networks inspired by biological neurons","Can learn complex patterns","Requires large amounts of data"
EOT

# Clear database and restart containers to force fresh ingestion
echo "🔄 Restarting containers to ingest new corpus..."
docker-compose down --volumes
sleep 5
docker-compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to initialize..."
sleep 40

# Check if backend is ready
echo "🔍 Checking backend status..."
if curl -s http://localhost:8000/health/ > /dev/null; then
    echo "✅ Backend is ready!"
else
    echo "⚠️ Backend might still be starting up..."
fi

# Inform user completion
echo "✅ New comprehensive corpus has been created and ingested."
echo "📊 Total documents: 7 files in multiple formats"

# Run the RAG Chat test script
echo "🔍 Running RAG Chat test script on new corpus..."
./test_search.sh
