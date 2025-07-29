import logging
import sys
from pathlib import Path
from datetime import datetime
import json

LOG_DIR = Path("logs")
LOG_DIR.mkdir(exist_ok=True)

class JSONFormatter(logging.Formatter):
    def format(self, record):
        log_obj = {
            "timestamp": datetime.utcnow().isoformat(),
            "level": record.levelname,
            "message": record.getMessage(),
        }
        return json.dumps(log_obj)

def setup_logging(name: str = "rag_chat", level: str = "INFO") -> logging.Logger:
    logger = logging.getLogger(name)
    logger.setLevel(getattr(logging, level.upper()))
    logger.handlers = []
    
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s'))
    logger.addHandler(console_handler)
    
    logger.propagate = False
    return logger

logger = setup_logging(level="INFO")

def log_api_request(endpoint: str, method: str, **kwargs):
    logger.info(f"API Request: {method} {endpoint}")

def log_api_response(endpoint: str, status_code: int, duration_ms: float, **kwargs):
    logger.info(f"API Response: {endpoint} - {status_code} ({duration_ms:.2f}ms)")

def log_error(error: Exception, context: str = "", **kwargs):
    logger.error(f"Error in {context}: {str(error)}", exc_info=True)
