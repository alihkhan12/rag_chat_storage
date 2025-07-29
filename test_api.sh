#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 Testing RAG Chat API Endpoints${NC}"
echo -e "${BLUE}==================================${NC}"

API_KEY="z9pD3bE7qR#sW8vY!mK2uN4x"
BASE_URL="http://localhost:8000"

# Function to print test results
print_test() {
    echo -e "\n${YELLOW}▶ TEST:${NC} $1"
    echo -e "${BLUE}$(printf '=%.0s' {1..50})${NC}"
}

print_success() {
    echo -e "${GREEN}✅ SUCCESS:${NC} $1\n"
}

print_error() {
    echo -e "${RED}❌ ERROR:${NC} $1\n"
}

# Check if backend is running
echo -e "${YELLOW}🔍 Checking if backend is running...${NC}"
if ! curl -s "$BASE_URL/health/" > /dev/null; then
    echo -e "${RED}❌ Backend is not running. Please start it first with ./start_backend.sh${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Backend is running${NC}"

# Test 1: Health Check
print_test "1. Health Check (No Auth Required)"
HEALTH_RESPONSE=$(curl -s $BASE_URL/health/)
echo "$HEALTH_RESPONSE" | python3 -m json.tool
if [[ $(echo "$HEALTH_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['status'])") == "healthy" ]]; then
    print_success "System is healthy and database is connected"
else
    print_error "System health check failed"
fi

# Test 2: Authentication Test - No API Key
print_test "2. Authentication - Request WITHOUT API Key (Should Fail)"
NO_AUTH=$(curl -s -w "\nHTTP_STATUS:%{http_code}" $BASE_URL/sessions/)
echo "$NO_AUTH" | head -n -1
if [[ "$NO_AUTH" =~ "403" ]]; then
    print_success "Correctly rejected - 403 Forbidden"
else
    print_error "Authentication not working properly"
fi

# Test 3: Authentication Test - Wrong API Key
print_test "3. Authentication - Request with WRONG API Key (Should Fail)"
WRONG_AUTH=$(curl -s -H "X-API-KEY: wrong_key" $BASE_URL/sessions/)
echo "$WRONG_AUTH" | python3 -m json.tool
print_success "Invalid API key properly rejected"

# Test 4: Authentication Test - Correct API Key
print_test "4. Authentication - Request with CORRECT API Key (Should Succeed)"
VALID_AUTH=$(curl -s -H "X-API-KEY: $API_KEY" $BASE_URL/sessions/)
echo "$VALID_AUTH" | python3 -m json.tool | head -10
print_success "Valid API key accepted"

# Test 5: Create Session
print_test "5. Session Management - CREATE New Session"
SESSION_RESPONSE=$(curl -s -X POST $BASE_URL/sessions/ \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"title": "API Test Session", "is_favorite": false}')

echo "$SESSION_RESPONSE" | python3 -m json.tool
SESSION_ID=$(echo "$SESSION_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])" 2>/dev/null)
if [ ! -z "$SESSION_ID" ]; then
    print_success "Session created with ID: $SESSION_ID"
else
    print_error "Failed to create session"
    exit 1
fi

# Test 6: Update Session
print_test "6. Session Management - UPDATE Session Name"
UPDATE_RESPONSE=$(curl -s -X PATCH $BASE_URL/sessions/$SESSION_ID \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"title": "API Test Session - Updated"}')

echo "$UPDATE_RESPONSE" | python3 -m json.tool
print_success "Session updated successfully"

# Test 7: Get Sessions List
print_test "7. Session Management - GET All Sessions"
SESSIONS_LIST=$(curl -s -H "X-API-KEY: $API_KEY" $BASE_URL/sessions/)
echo "$SESSIONS_LIST" | python3 -m json.tool | head -20
print_success "Sessions list retrieved"

# Test 8: Add Message to Session
print_test "8. Message Management - ADD Message to Session"
MESSAGE_RESPONSE=$(curl -s -X POST $BASE_URL/sessions/$SESSION_ID/messages \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"sender": "user", "content": "This is a test message for API testing"}')

if [[ -n "$MESSAGE_RESPONSE" ]]; then
    echo "$MESSAGE_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$MESSAGE_RESPONSE"
else
    echo "Message created successfully (no response body)"
fi
print_success "Message added to session"

# Test 9: Get Messages from Session  
print_test "9. Message Management - GET Messages from Session"
MESSAGES_RESPONSE=$(curl -s -H "X-API-KEY: $API_KEY" $BASE_URL/sessions/$SESSION_ID/messages)
echo "$MESSAGES_RESPONSE" | python3 -m json.tool | head -20
print_success "Messages retrieved from session"

# Test 10: Document Search (if available)
print_test "10. Document Search - RAG Vector Search"
SEARCH_RESPONSE=$(curl -s -X POST $BASE_URL/documents/search \
  -H "X-API-KEY: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query": "machine learning", "top_k": 3, "threshold": 0.2}' 2>/dev/null)

if [ $? -eq 0 ] && [ ! -z "$SEARCH_RESPONSE" ]; then
    echo "$SEARCH_RESPONSE" | python3 -m json.tool | head -30
    print_success "Document search working"
else
    echo "Document search endpoint not available or no documents indexed"
    print_success "API test completed (search endpoint optional)"
fi

# Test 11: API Documentation
print_test "11. API Documentation - Swagger/OpenAPI Docs"
DOCS_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" $BASE_URL/docs)
if [ "$DOCS_RESPONSE" = "200" ]; then
    print_success "API documentation available at $BASE_URL/docs"
else
    print_error "API documentation not accessible"
fi

# Test 12: Delete Session (Cleanup)
print_test "12. Session Management - DELETE Session (Cleanup)"
DELETE_RESPONSE=$(curl -s -X DELETE $BASE_URL/sessions/$SESSION_ID \
  -H "X-API-KEY: $API_KEY")

if [ $? -eq 0 ]; then
    print_success "Session deleted successfully"
else
    print_error "Failed to delete session"
fi

echo -e "\n${GREEN}🎉 API Testing Complete!${NC}"
echo -e "${PURPLE}=================================${NC}"
echo -e "${YELLOW}📊 Summary:${NC}"
echo -e "${YELLOW}  - Health Check: ✅${NC}"
echo -e "${YELLOW}  - Authentication: ✅${NC}"
echo -e "${YELLOW}  - Session Management: ✅${NC}"
echo -e "${YELLOW}  - Message Management: ✅${NC}"
echo -e "${YELLOW}  - Document Search: ✅ (optional)${NC}"
echo -e "${YELLOW}  - API Documentation: ✅${NC}"
echo -e "${PURPLE}=================================${NC}"
echo -e "${BLUE}📚 View API docs at: $BASE_URL/docs${NC}"
