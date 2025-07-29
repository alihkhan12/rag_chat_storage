#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Stopping RAG Chat Storage Backend...${NC}"

cd /Volumes/Personal/rag_chat_storage

# Stop Docker containers
echo -e "${YELLOW}Stopping Docker containers...${NC}"
docker-compose down --remove-orphans 2>/dev/null

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Docker containers stopped${NC}"
else
    echo -e "${YELLOW}No Docker containers to stop${NC}"
fi

# Kill any processes using port 8000
pids=$(lsof -ti:8000)
if [ ! -z "$pids" ]; then
    echo -e "${YELLOW}Stopping processes on port 8000...${NC}"
    kill $pids
    
    # Wait a moment and check if processes are still running
    sleep 2
    remaining_pids=$(lsof -ti:8000)
    if [ ! -z "$remaining_pids" ]; then
        echo -e "${RED}Force killing processes on port 8000...${NC}"
        kill -9 $remaining_pids
    fi
    echo -e "${GREEN}Backend processes stopped${NC}"
else
    echo -e "${YELLOW}No processes found on port 8000${NC}"
fi

# Clean up any backend log files
if [ -f "backend.log" ]; then
    rm backend.log
    echo -e "${GREEN}Removed backend.log${NC}"
fi

echo -e "${GREEN}✅ Backend has been stopped and cleaned up.${NC}"
