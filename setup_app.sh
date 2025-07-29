#!/bin/bash

# RAG Chat Storage - Complete Application Setup Script
# This script sets up the entire project including backend and frontend dependencies

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}========================================${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check system requirements
check_system_requirements() {
    print_header "CHECKING SYSTEM REQUIREMENTS"
    
    local requirements_met=true
    
    # Check Python
    if command_exists python3; then
        python_version=$(python3 --version 2>&1 | awk '{print $2}')
        print_success "Python found: $python_version"
    else
        print_error "Python 3 is not installed"
        requirements_met=false
    fi
    
    # Check pip
    if command_exists pip3; then
        print_success "pip3 found"
    else
        print_error "pip3 is not installed"
        requirements_met=false
    fi
    
    # Check Node.js
    if command_exists node; then
        node_version=$(node --version)
        print_success "Node.js found: $node_version"
    else
        print_error "Node.js is not installed"
        requirements_met=false
    fi
    
    # Check npm
    if command_exists npm; then
        npm_version=$(npm --version)
        print_success "npm found: $npm_version"
    else
        print_error "npm is not installed"
        requirements_met=false
    fi
    
    # Check Docker (optional)
    if command_exists docker; then
        docker_version=$(docker --version)
        print_success "Docker found: $docker_version"
    else
        print_warning "Docker not found (optional - needed for containerized deployment)"
    fi
    
    # Check Docker Compose (optional)
    if command_exists docker-compose; then
        compose_version=$(docker-compose --version)
        print_success "Docker Compose found: $compose_version"
    else
        print_warning "Docker Compose not found (optional - needed for containerized deployment)"
    fi
    
    if [ "$requirements_met" = false ]; then
        print_error "Some required dependencies are missing. Please install them first."
        echo ""
        echo "Installation guides:"
        echo "- Python 3: https://www.python.org/downloads/"
        echo "- Node.js: https://nodejs.org/en/download/"
        echo "- Docker: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    print_success "All required dependencies are installed!"
    echo ""
}

# Function to setup Python virtual environment
setup_python_environment() {
    print_header "SETTING UP PYTHON VIRTUAL ENVIRONMENT"
    
    # Check if virtual environment exists
    if [ -d "venv" ]; then
        print_warning "Virtual environment already exists"
        read -p "Do you want to recreate it? (y/N): " recreate_venv
        if [[ $recreate_venv =~ ^[Yy]$ ]]; then
            print_status "Removing existing virtual environment..."
            rm -rf venv
        else
            print_status "Using existing virtual environment"
        fi
    fi
    
    # Create virtual environment if it doesn't exist
    if [ ! -d "venv" ]; then
        print_status "Creating virtual environment..."
        python3 -m venv venv
        print_success "Virtual environment created"
    fi
    
    # Activate virtual environment
    print_status "Activating virtual environment..."
    source venv/bin/activate
    
    # Upgrade pip
    print_status "Upgrading pip..."
    pip install --upgrade pip
    
    print_success "Python virtual environment is ready"
    echo ""
}

# Function to install backend dependencies
install_backend_dependencies() {
    print_header "INSTALLING BACKEND DEPENDENCIES"
    
    # Ensure virtual environment is activated
    if [ -z "$VIRTUAL_ENV" ]; then
        print_status "Activating virtual environment..."
        source venv/bin/activate
    fi
    
    print_status "Installing Python packages from requirements.txt..."
    pip install -r requirements.txt
    
    print_success "Backend dependencies installed successfully"
    echo ""
}

# Function to setup frontend dependencies
setup_frontend() {
    print_header "SETTING UP FRONTEND DEPENDENCIES"
    
    if [ ! -d "frontend" ]; then
        print_error "Frontend directory not found!"
        exit 1
    fi
    
    cd frontend
    
    # Check if node_modules exists
    if [ -d "node_modules" ]; then
        print_warning "node_modules already exists"
        read -p "Do you want to reinstall dependencies? (y/N): " reinstall_deps
        if [[ $reinstall_deps =~ ^[Yy]$ ]]; then
            print_status "Removing existing node_modules..."
            rm -rf node_modules package-lock.json
        fi
    fi
    
    print_status "Installing Node.js dependencies..."
    npm install
    
    print_success "Frontend dependencies installed successfully"
    cd ..
    echo ""
}

# Function to create environment file
setup_environment_file() {
    print_header "SETTING UP ENVIRONMENT CONFIGURATION"
    
    if [ -f ".env" ]; then
        print_warning ".env file already exists"
        read -p "Do you want to recreate it? (y/N): " recreate_env
        if [[ ! $recreate_env =~ ^[Yy]$ ]]; then
            print_status "Using existing .env file"
            return
        fi
    fi
    
    print_status "Creating .env file with default values..."
    
    cat > .env << 'EOF'
# Database Configuration
DATABASE_URL=postgresql://user:password@localhost:5432/rag_chat_db
POSTGRES_USER=user
POSTGRES_PASSWORD=password
POSTGRES_DB=rag_chat_db

# API Configuration
API_KEY=your-secret-api-key-here
SECRET_KEY=your-super-secret-jwt-key-here
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# Application Settings
DEBUG=true
LOG_LEVEL=INFO
HOST=0.0.0.0
PORT=8000

# RAG Configuration
EMBEDDING_MODEL=sentence-transformers/all-MiniLM-L6-v2
CHUNK_SIZE=500
CHUNK_OVERLAP=50
MAX_DOCUMENTS=1000

# Rate Limiting
RATE_LIMIT_PER_MINUTE=60

# CORS Settings
ALLOWED_ORIGINS=["http://localhost:3000", "http://127.0.0.1:3000"]
EOF
    
    print_success ".env file created with default values"
    print_warning "Please review and update the .env file with your specific configuration"
    echo ""
}

# Function to setup database
setup_database() {
    print_header "DATABASE SETUP"
    
    print_status "Checking if Docker is available for database setup..."
    
    if command_exists docker && command_exists docker-compose; then
        print_status "Docker found. You can use docker-compose to start the database:"
        print_status "Run: docker-compose up -d postgres pgadmin"
        echo ""
        print_status "Or use the provided script: ./start_backend.sh"
    else
        print_warning "Docker not available. Please ensure PostgreSQL with pgvector extension is installed and configured."
        print_status "Database connection string should be updated in .env file"
    fi
    
    echo ""
}

# Function to create necessary directories
create_directories() {
    print_header "CREATING PROJECT DIRECTORIES"
    
    directories=("logs" "input_docs" "tests")
    
    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            print_success "Created directory: $dir"
        else
            print_status "Directory already exists: $dir"
        fi
    done
    
    echo ""
}

# Function to make scripts executable
make_scripts_executable() {
    print_header "MAKING SCRIPTS EXECUTABLE"
    
    scripts=(
        "start_app.sh"
        "stop_app.sh" 
        "start_backend.sh"
        "stop_backend.sh"
        "test_api.sh"
        "test_search.sh"
        "monitor.sh"
        "add_rag.sh"
        "add-rag-components.sh"
        "create_corpus.sh"
        "setup_app.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            chmod +x "$script"
            print_success "Made executable: $script"
        fi
    done
    
    echo ""
}

# Function to run basic tests
run_basic_tests() {
    print_header "RUNNING BASIC SETUP VALIDATION"
    
    # Test Python imports
    print_status "Testing Python imports..."
    source venv/bin/activate
    
    python3 -c "
import fastapi
import sqlalchemy
import sentence_transformers
print('✓ All core Python packages can be imported')
" 2>/dev/null && print_success "Python imports successful" || print_error "Python import test failed"
    
    # Test frontend build
    print_status "Testing frontend build..."
    cd frontend
    npm run build > /dev/null 2>&1 && print_success "Frontend build test successful" || print_warning "Frontend build test failed (this is okay for development)"
    cd ..
    
    echo ""
}

# Function to display setup summary
display_setup_summary() {
    print_header "SETUP COMPLETE!"
    
    echo -e "${GREEN}✓ Python virtual environment created and activated${NC}"
    echo -e "${GREEN}✓ Backend dependencies installed${NC}"
    echo -e "${GREEN}✓ Frontend dependencies installed${NC}"
    echo -e "${GREEN}✓ Environment configuration file created${NC}"
    echo -e "${GREEN}✓ Project directories created${NC}"
    echo -e "${GREEN}✓ Scripts made executable${NC}"
    echo ""
    
    print_header "NEXT STEPS"
    echo "1. Review and update the .env file with your configuration"
    echo "2. Start the database (if using Docker): docker-compose up -d postgres"
    echo "3. Start the full application: ./start_app.sh"
    echo "4. Or start backend only: ./start_backend.sh"
    echo "5. Access the application:"
    echo "   - Frontend: http://localhost:3000"
    echo "   - Backend API: http://localhost:8000"
    echo "   - API Documentation: http://localhost:8000/docs"
    echo "   - PgAdmin: http://localhost:5050 (if using Docker)"
    echo ""
    
    print_header "USEFUL COMMANDS"
    echo "• Full stack start: ./start_app.sh"
    echo "• Full stack stop: ./stop_app.sh"
    echo "• Backend only: ./start_backend.sh"
    echo "• Test API: ./test_api.sh"
    echo "• View logs: tail -f logs/app.log"
    echo ""
    
    print_success "Setup completed successfully! 🎉"
}

# Main execution
main() {
    clear
    print_header "RAG CHAT STORAGE - APPLICATION SETUP"
    echo "This script will set up the complete RAG Chat Storage application"
    echo "including backend (FastAPI + PostgreSQL) and frontend (React)"
    echo ""
    
    read -p "Do you want to proceed with the setup? (Y/n): " confirm_setup
    if [[ $confirm_setup =~ ^[Nn]$ ]]; then
        print_status "Setup cancelled by user"
        exit 0
    fi
    
    # Run setup steps
    check_system_requirements
    create_directories
    setup_python_environment
    install_backend_dependencies
    setup_frontend
    setup_environment_file
    setup_database
    make_scripts_executable
    run_basic_tests
    display_setup_summary
    
    echo "To activate the Python virtual environment in the future, run:"
    echo "source venv/bin/activate"
}

# Run main function
main "$@"
