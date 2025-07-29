#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 Testing RAG Chat Functionality${NC}"
echo -e "${BLUE}==================================${NC}"

API_KEY="z9pD3bE7qR#sW8vY!mK2uN4x"
BASE_URL="http://localhost:8000"

# Function to create a test session
create_session() {
    local session_response=$(curl -s -X POST "$BASE_URL/sessions/" \
        -H "X-API-KEY: $API_KEY" \
        -H "Content-Type: application/json" \
        -d '{"title": "Test Session"}')
    
    echo "$session_response" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data['id'])
except:
    print('ERROR')
"
}

# Function to test a chat query
test_chat_query() {
    local query="$1"
    local session_id="$2"
    local test_name="$3"
    
    echo -e "\n${YELLOW}$test_name${NC}"
    echo -e "${BLUE}Query: $query${NC}"
    echo -e "${BLUE}$(printf '=%.0s' {1..50})${NC}"
    
    local response=$(curl -s -X POST "$BASE_URL/chat/" \
        -H "X-API-KEY: $API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"session_id\": \"$session_id\", \"message\": \"$query\"}")
    
    echo "$response" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if 'assistant_message' in data:
        print('${GREEN}✅ SUCCESS${NC}')
        print('${YELLOW}Assistant Response:${NC}')
        print(data['assistant_message']['content'])
        if data['assistant_message']['retrieved_context']:
            print('\n${BLUE}📄 Retrieved Context:${NC}')
            print(data['assistant_message']['retrieved_context'][:300] + '...' if len(data['assistant_message']['retrieved_context']) > 300 else data['assistant_message']['retrieved_context'])
    else:
        print('${RED}❌ ERROR: No assistant message found${NC}')
        print(json.dumps(data, indent=2))
except Exception as e:
    print('${RED}❌ ERROR: Failed to parse response${NC}')
    print(f'Error: {e}')
    print('Raw response:', file=sys.stderr)
    print(sys.stdin.read(), file=sys.stderr)
"
    
    echo -e "\n${BLUE}$(printf '=%.0s' {1..50})${NC}"
}

# Check if backend is running
echo -e "${YELLOW}🔍 Checking if backend is running...${NC}"
if ! curl -s "$BASE_URL/health/" > /dev/null; then
    echo -e "${RED}❌ Backend is not running. Please start it first with ./start_app.sh${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Backend is running${NC}"

# Create a test session
echo -e "\n${YELLOW}📝 Creating test session...${NC}"
SESSION_ID=$(create_session)
if [ "$SESSION_ID" = "ERROR" ] || [ -z "$SESSION_ID" ]; then
    echo -e "${RED}❌ Failed to create session${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Session created: $SESSION_ID${NC}"

# Test various types of queries that match our new corpus
test_chat_query "What is machine learning?" "$SESSION_ID" "🤖 1. Knowledge Question - Machine Learning"

test_chat_query "Tell me about natural language processing and NLP tasks" "$SESSION_ID" "🧠 2. Knowledge Question - NLP"

test_chat_query "Explain vector embeddings and similarity search" "$SESSION_ID" "🔍 3. Technical Concept Question"

test_chat_query "What are the features of this RAG system?" "$SESSION_ID" "⚙️ 4. System Features Question"

test_chat_query "What is FastAPI and how is it used?" "$SESSION_ID" "🚀 5. Technology Question - FastAPI"

test_chat_query "What is pgvector and how does it work?" "$SESSION_ID" "🗄️ 6. Database Technology Question"

test_chat_query "What machine learning algorithms are available?" "$SESSION_ID" "📊 7. Algorithms Question"

test_chat_query "What formats does the system support?" "$SESSION_ID" "📄 8. System Capability Question"

test_chat_query "How can you help me?" "$SESSION_ID" "❓ 9. Help/Capability Question"

test_chat_query "Hello" "$SESSION_ID" "👋 10. Simple Greeting"

echo -e "\n${GREEN}🎉 RAG Chat testing complete!${NC}"
echo -e "${YELLOW}📊 Review the responses above to ensure they are contextual and accurate.${NC}"
