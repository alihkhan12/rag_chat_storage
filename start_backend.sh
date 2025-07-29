#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Starting RAG Chat Storage - Backend Only${NC}"
echo -e "${BLUE}==============================================${NC}"

cd /Volumes/Personal/rag_chat_storage

# Function to check if a port is in use
check_port() {
    local port=$1
    lsof -Pi :$port -sTCP:LISTEN -t >/dev/null
}

# Function to wait for a port to be ready
wait_for_port() {
    local port=$1
    local timeout=60
    local count=0
    
    echo -e "${YELLOW}⏳ Waiting for port $port to be ready...${NC}"
    while ! check_port $port && [ $count -lt $timeout ]; do
        sleep 1
        count=$((count + 1))
        printf "."
    done
    echo ""
    
    if [ $count -eq $timeout ]; then
        echo -e "${RED}❌ Timeout waiting for port $port${NC}"
        return 1
    else
        echo -e "${GREEN}✅ Port $port is ready!${NC}"
        return 0
    fi
}

# Function to cleanup on exit
cleanup() {
    echo ""
    echo -e "${YELLOW}🛑 Shutting down backend services...${NC}"
    docker-compose down 2>/dev/null
    echo -e "${GREEN}✅ Backend stopped${NC}"
    exit 0
}

# Set trap to cleanup on script exit
trap cleanup INT TERM

# Kill any processes using port 8000
if check_port 8000; then
    echo -e "${YELLOW}🔄 Killing process using port 8000...${NC}"
    lsof -ti:8000 | xargs kill -9 2>/dev/null
    sleep 2
fi

# Stop any existing containers
echo -e "${YELLOW}🧹 Cleaning up existing containers...${NC}"
docker-compose down --remove-orphans 2>/dev/null
sleep 2

# Start the backend using Docker
echo -e "${GREEN}🔧 Starting Backend Services with Docker...${NC}"
if docker-compose up --build -d >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Backend services started successfully${NC}"
else
    echo -e "${RED}❌ Failed to start backend services${NC}"
    docker-compose logs app --tail=5
    exit 1
fi

# Wait for backend services to be ready
echo -e "${YELLOW}⏳ Waiting for backend services to initialize...${NC}"
sleep 15

# Check if backend is healthy
if ! wait_for_port 8000; then
    echo -e "${RED}❌ Backend failed to start on port 8000${NC}"
    echo -e "${YELLOW}Container logs:${NC}"
    docker-compose logs app --tail=10
    exit 1
fi

# Test backend health
echo -e "${BLUE}🔍 Testing backend health...${NC}"
if curl -s http://localhost:8000/health/ | grep -q "healthy"; then
    echo -e "${GREEN}✅ Backend API is healthy!${NC}"
else
    echo -e "${RED}❌ Backend API health check failed${NC}"
    echo -e "${YELLOW}Container logs:${NC}"
    docker-compose logs app --tail=10
    exit 1
fi

echo -e ""
echo -e "${GREEN}🎉 Backend Started Successfully!${NC}"
echo -e "${BLUE}=================================${NC}"
echo -e "${YELLOW}🔗 Backend API:       http://localhost:8000${NC}"
echo -e "${YELLOW}📚 API Documentation: http://localhost:8000/docs${NC}"
echo -e "${YELLOW}🗄️  Database Admin:   http://localhost:5050${NC}"
echo -e "${YELLOW}🔑 API Key:           z9pD3bE7qR#sW8vY!mK2uN4x${NC}"
echo -e "${BLUE}=================================${NC}"
echo -e "${YELLOW}📊 To view logs: docker-compose logs -f app${NC}"
echo -e "${YELLOW}🔄 Press Ctrl+C to stop the backend${NC}"
echo -e ""

# Keep script alive and monitor backend
echo -e "${GREEN}🏃 Backend is running... (Press Ctrl+C to stop)${NC}"

# Wait for user interrupt
while true; do
    # Check if backend is still responding
    if ! curl -s http://localhost:8000/health/ >/dev/null 2>&1; then
        echo -e "${RED}❌ Backend stopped responding${NC}"
        cleanup
        exit 1
    fi
    
    sleep 30
done
