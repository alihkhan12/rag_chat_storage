#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 RAG Chat APP - Full Stack Application${NC}"
echo -e "${BLUE}====================================================${NC}"

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

# Function to cleanup background processes
cleanup() {
    echo ""
    echo -e "${YELLOW}🛑 Shutting down servers...${NC}"
    
    # Kill frontend process if it exists
    if [ ! -z "$FRONTEND_PID" ]; then
        kill $FRONTEND_PID 2>/dev/null
    fi
    
    # Kill any npm processes
    pkill -f "react-scripts start" 2>/dev/null
    pkill -f "npm start" 2>/dev/null
    
    # Stop Docker containers
    echo -e "${YELLOW}Stopping Docker containers...${NC}"
    docker-compose down 2>/dev/null
    
    echo -e "${GREEN}✅ Cleanup completed${NC}"
    exit 0
}

# Set trap to cleanup on script exit (but not on normal completion)
trap cleanup INT TERM

# Change to project directory
cd /Volumes/Personal/rag_chat_storage

# Stop any existing processes
echo -e "${YELLOW}🧹 Cleaning up existing processes...${NC}"
pkill -f "react-scripts start" 2>/dev/null
pkill -f "npm start" 2>/dev/null

# Kill any processes using port 3000
if check_port 3000; then
    echo -e "${YELLOW}🔄 Killing process using port 3000...${NC}"
    lsof -ti:3000 | xargs kill -9 2>/dev/null
    sleep 2
fi

# Kill any processes using port 8000
if check_port 8000; then
    echo -e "${YELLOW}🔄 Killing process using port 8000...${NC}"
    lsof -ti:8000 | xargs kill -9 2>/dev/null
    sleep 2
fi

docker-compose down --remove-orphans 2>/dev/null
sleep 3

# Start the backend using Docker
echo -e "${GREEN}🔧 Starting Backend Services...${NC}"
echo -e "${YELLOW}🧽 Cleaning up existing containers and volumes...${NC}"
docker-compose down --remove-orphans --volumes 2>/dev/null
docker volume prune -f 2>/dev/null >/dev/null

echo -e "${BLUE}🆕 Starting fresh containers...${NC}"
if docker-compose up --build -d >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Backend services started successfully${NC}"
else
    echo -e "${RED}❌ Failed to start backend services${NC}"
    docker-compose logs app --tail=5
    exit 1
fi

# Wait for backend services to be ready
echo -e "${YELLOW}⏳ Waiting 20 seconds for backend services to initialize...${NC}"
sleep 20

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

# Start the frontend server
echo -e "${GREEN}🌐 Starting Frontend Server...${NC}"
cd /Volumes/Personal/rag_chat_storage/frontend

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo -e "${BLUE}📦 Installing frontend dependencies...${NC}"
    npm install >/dev/null 2>&1
fi

# Start frontend in background
echo -e "${BLUE}🚀 Starting React development server...${NC}"
npm start > ../frontend.log 2>&1 &
FRONTEND_PID=$!

# Wait for frontend to be ready
if wait_for_port 3000; then
    echo -e "${GREEN}✅ Frontend is ready!${NC}"
    echo -e ""
    echo -e "${GREEN}🎉 Full Stack Application Started Successfully!${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo -e "${YELLOW}📱 Frontend UI:      http://localhost:3000${NC}"
    echo -e "${YELLOW}🔗 Backend API:      http://localhost:8000${NC}"
    echo -e "${YELLOW}📚 API Documentation: http://localhost:8000/docs${NC}"
    echo -e "${YELLOW}🗄️  Database Admin:   http://localhost:5050${NC}"
    echo -e "${YELLOW}🔑 API Key:          z9pD3bE7qR#sW8vY!mK2uN4x${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo -e "${YELLOW}📋 Frontend logs: frontend.log${NC}"
    echo -e "${YELLOW}🔄 Press Ctrl+C to stop all servers${NC}"
    echo -e ""
    
    # Show a brief test of the system
    echo -e "${BLUE}🧪 Running quick system test...${NC}"
    if curl -s -H "X-API-KEY: z9pD3bE7qR#sW8vY!mK2uN4x" http://localhost:8000/sessions/ >/dev/null 2>&1; then
        echo -e "${GREEN}✅ API authentication test passed${NC}"
    else
        echo -e "${YELLOW}⚠️  API authentication test failed (but services are running)${NC}"
    fi
    echo -e ""
else
    echo -e "${RED}❌ Failed to start frontend. Check frontend.log for details.${NC}"
    if [ -f "../frontend.log" ]; then
        echo -e "${YELLOW}Frontend log contents:${NC}"
        tail -20 ../frontend.log
    fi
    exit 1
fi

# Keep script alive and wait for user interrupt
echo -e "${GREEN}🏃 Application is running... (Press Ctrl+C to stop)${NC}"
echo -e "${YELLOW}📝 Monitoring services...${NC}"

# Function to monitor services
monitor_services() {
    while true; do
        # Check if frontend process is still running
        if ! kill -0 $FRONTEND_PID 2>/dev/null; then
            echo -e "${RED}❌ Frontend process stopped unexpectedly${NC}"
            cleanup
            exit 1
        fi
        
        # Check if backend is still responding
        if ! curl -s http://localhost:8000/health/ >/dev/null 2>&1; then
            echo -e "${RED}❌ Backend stopped responding${NC}"
            cleanup
            exit 1
        fi
        
        sleep 10
    done
}

# Start monitoring in background
monitor_services &
MONITOR_PID=$!

# Wait for user interrupt (don't wait for frontend PID to complete)
echo -e "${GREEN}📝 Services are running. Press Ctrl+C to stop all servers${NC}"
echo -e "${YELLOW}📊 To view frontend logs: tail -f frontend.log${NC}"
echo -e "${YELLOW}📊 To view backend logs: docker-compose logs -f app${NC}"

# Instead of waiting for frontend PID, just keep script alive
while true; do
    # Check if frontend process is still running
    if ! kill -0 $FRONTEND_PID 2>/dev/null; then
        echo -e "${RED}❌ Frontend process stopped unexpectedly${NC}"
        echo -e "${YELLOW}📋 Frontend log contents:${NC}"
        tail -10 frontend.log
        cleanup
        exit 1
    fi
    
    # Check if backend is still responding
    if ! curl -s http://localhost:8000/health/ >/dev/null 2>&1; then
        echo -e "${RED}❌ Backend stopped responding${NC}"
        cleanup
        exit 1
    fi
    
    sleep 30
done
