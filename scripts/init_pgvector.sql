-- Enable pgvector extension FIRST
CREATE EXTENSION IF NOT EXISTS vector;

-- Grant permissions
--GRANT ALL ON SCHEMA public TO myuser;
GRANT ALL ON SCHEMA public TO raguser;
--GRANT ALL PRIVILEGES ON DATABASE rag_chat_db TO myuser;
GRANT ALL PRIVILEGES ON DATABASE rag_chat_db TO raguser;
