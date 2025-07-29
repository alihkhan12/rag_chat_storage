#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to kill processes running on a specific port
kill_port() {
    local port=$1
    local service_name=$2
    local pids=$(lsof -ti:$port)
    
    if [ ! -z "$pids" ]; then
        echo -e "${YELLOW}Stopping $service_name on port $port...${NC}"
        kill $pids
        
        # Wait a moment and check if processes are still running
        sleep 2
        local remaining_pids=$(lsof -ti:$port)
        if [ ! -z "$remaining_pids" ]; then
            echo -e "${RED}Force killing $service_name processes...${NC}"
            kill -9 $remaining_pids
        fi
        echo -e "${GREEN}$service_name stopped${NC}"
    else
        echo -e "${YELLOW}No $service_name processes found on port $port${NC}"
    fi
}

# Function to kill processes by name pattern
kill_by_pattern() {
    local pattern=$1
    local service_name=$2
    local pids=$(pgrep -f "$pattern")
    
    if [ ! -z "$pids" ]; then
        echo -e "${YELLOW}Stopping $service_name processes...${NC}"
        kill $pids
        sleep 2
        
        # Force kill if still running
        local remaining_pids=$(pgrep -f "$pattern")
        if [ ! -z "$remaining_pids" ]; then
            echo -e "${RED}Force killing $service_name processes...${NC}"
            kill -9 $remaining_pids
        fi
        echo -e "${GREEN}$service_name stopped${NC}"
    fi
}

echo -e "${YELLOW}Stopping RAG Chat Storage App...${NC}"

# Stop Docker containers first
echo -e "${YELLOW}Stopping Docker containers...${NC}"
docker-compose down --remove-orphans 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Docker containers stopped${NC}"
else
    echo -e "${YELLOW}No Docker containers to stop${NC}"
fi

# Stop by port
kill_port 8000 "Backend"
kill_port 3000 "Frontend"

# Also try to stop by process patterns as backup
kill_by_pattern "npm.*start" "npm processes"
kill_by_pattern "react-scripts.*start" "React development server"
kill_by_pattern "node.*server" "Node server processes"

# Clean up log files
if [ -f "backend.log" ]; then
    rm backend.log
    echo -e "${GREEN}Removed backend.log${NC}"
fi

if [ -f "frontend.log" ]; then
    rm frontend.log
    echo -e "${GREEN}Removed frontend.log${NC}"
fi

echo -e "${GREEN}✅ App has been stopped and cleaned up.${NC}"
