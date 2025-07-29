#!/bin/bash

echo "📊 System Monitoring Dashboard"
echo "============================="

while true; do
    clear
    echo "📊 RAG Chat Storage - Live Status"
    echo "================================="
    echo ""
    
    # Container status
    echo "🐳 Container Status:"
    docker-compose ps | grep -E "rag_chat_app|rag_chat_db" | awk '{print $1, $6, $7}'
    echo ""
    
    # API Health
    echo "🏥 API Health:"
    curl -s http://localhost:8000/health/ | python3 -c "import sys, json; data=json.load(sys.stdin); print(f'  Status: {data.get(\"status\", \"unknown\")}'); print(f'  Database: {data.get(\"database\", {}).get(\"status\", \"unknown\")}')" 2>/dev/null || echo "  Status: Not responding"
    echo ""
    
    # Resource usage
    echo "💻 Resource Usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep -E "CONTAINER|rag_chat"
    echo ""
    
    # Recent logs
    echo "📋 Recent Activity:"
    docker-compose logs --tail=5 app 2>/dev/null | grep -E "INFO|ERROR" | tail -5
    
    echo ""
    echo "Press Ctrl+C to exit"
    sleep 5
done
