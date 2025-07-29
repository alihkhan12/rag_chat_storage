from fastapi import Request, status
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException
from sqlalchemy.exc import SQLAlchemyError
from .logging import logger

def create_error_response(error_id: str, status_code: int, message: str, path: str = None):
    content = {"error": {"id": error_id, "message": message, "status_code": status_code}}
    if path:
        content["error"]["path"] = path
    return JSONResponse(status_code=status_code, content=content)

async def http_exception_handler(request: Request, exc: StarletteHTTPException):
    return create_error_response("http_error", exc.status_code, exc.detail, str(request.url))

async def validation_exception_handler(request: Request, exc: RequestValidationError):
    return create_error_response("validation_error", status.HTTP_422_UNPROCESSABLE_ENTITY, "Request validation failed", str(request.url))

async def general_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return create_error_response("internal_error", status.HTTP_500_INTERNAL_SERVER_ERROR, "Internal server error", str(request.url))

def register_exception_handlers(app):
    app.add_exception_handler(StarletteHTTPException, http_exception_handler)
    app.add_exception_handler(RequestValidationError, validation_exception_handler)
    app.add_exception_handler(Exception, general_exception_handler)
