"""RAG Chat API endpoints for intelligent conversation"""
import uuid
from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel
from typing import Optional
from ..models import chat as models
from ..schemas import chat as schemas
from ..core.limiter import limiter
from ..core.security import get_current_user
from ..core.rag.vectorstore import get_vector_store
from ..core.logging import logger
from .sessions import get_db

router = APIRouter(prefix="/chat", tags=["RAG Chat"])

class ChatRequest(BaseModel):
    session_id: uuid.UUID
    message: str

class ChatResponse(BaseModel):
    session_id: uuid.UUID
    user_message: schemas.ChatMessage
    assistant_message: schemas.ChatMessage

@router.post("/", response_model=ChatResponse)
@limiter.limit("30/minute")
async def send_chat_message(
    request: Request,
    chat_request: ChatRequest,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Send a message and get an intelligent RAG-enhanced response"""
    try:
        # Verify session belongs to current user
        session = db.query(models.ChatSession).filter(
            models.ChatSession.id == chat_request.session_id,
            models.ChatSession.user_id == current_user.id
        ).first()
        
        if not session:
            raise HTTPException(status_code=404, detail="Chat session not found")
        
        # Store user message
        user_message = models.ChatMessage(
            session_id=chat_request.session_id,
            sender="user",
            content=chat_request.message,
            retrieved_context=None
        )
        db.add(user_message)
        db.commit()
        db.refresh(user_message)
        
        # Get relevant context from vector store
        vector_store = get_vector_store()
        search_results = vector_store.search_similar(
            chat_request.message,
            top_k=3,
            threshold=0.1
        )
        
        # Generate intelligent response
        context = ""
        if search_results:
            context = "\n\n".join([result["chunk_text"] for result in search_results])
        
        assistant_response = generate_intelligent_response(
            chat_request.message, context, current_user.name
        )
        
        # Store assistant response
        assistant_message = models.ChatMessage(
            session_id=chat_request.session_id,
            sender="assistant",
            content=assistant_response,
            retrieved_context=context if context else None
        )
        db.add(assistant_message)
        db.commit()
        db.refresh(assistant_message)
        
        # Update session timestamp
        session.updated_at = db.execute(text("SELECT NOW()")).scalar()
        db.commit()
        
        return ChatResponse(
            session_id=chat_request.session_id,
            user_message=user_message,
            assistant_message=assistant_message
        )
        
    except Exception as e:
        logger.error(f"Chat error: {e}")
        raise HTTPException(status_code=500, detail="Failed to process chat message")

def generate_intelligent_response(user_message: str, context: str, user_name: str) -> str:
    """Generate an intelligent response based on user message and context"""
    user_message_lower = user_message.lower().strip()
    
    # Only handle very specific greetings (standalone greetings, not questions)
    standalone_greetings = ["hello", "hi", "hey", "good morning", "good afternoon", "hi there", "hello there"]
    if user_message_lower in standalone_greetings or (len(user_message.split()) <= 3 and any(greeting == user_message_lower for greeting in standalone_greetings)):
        if context:
            return f"Hello {user_name}! I'm here to help you with your questions. Based on the documents I have access to, I can assist you with various topics. What would you like to know more about?"
        else:
            return f"Hello {user_name}! I'm your AI assistant. While I don't have specific documents loaded right now, I'm here to help answer your questions. What can I assist you with today?"
    
    # Handle "how can you help" questions (but not "what is" questions)
    help_phrases = ["how can you help", "what can you do", "help me", "assist me", "what can you help with"]
    if any(phrase in user_message_lower for phrase in help_phrases) and not any(q in user_message_lower for q in ["what is", "what are", "define", "explain"]):
        if context:
            capabilities = analyze_document_capabilities(context)
            return f"I can help you with several things based on the documents in my knowledge base:\n\n{capabilities}\n\nFeel free to ask me specific questions about any of these topics, and I'll provide detailed answers based on the available information."
        else:
            return "I can help you with various tasks including:\n\n- Answering questions based on uploaded documents\n- Providing detailed explanations on topics in my knowledge base\n- Analyzing and summarizing information\n- Helping you understand complex concepts\n\nTo get started, you can upload some documents or ask me specific questions about topics you're interested in."
    
    # Handle questions with context - this should be the main path
    if context:
        return generate_contextual_response(user_message, context)
    else:
        # No relevant context found
        return f"I don't have specific information about '{user_message}' in my current knowledge base. Could you provide more details about what you're looking for, or consider uploading relevant documents that I can reference to give you a more accurate answer?"

def analyze_document_capabilities(context: str) -> str:
    """Analyze context to determine what topics the assistant can help with"""
    context_lower = context.lower()
    capabilities = []
    
    # Look for common topics/domains
    if any(term in context_lower for term in ["performance", "metrics", "analysis", "data"]):
        capabilities.append("• Performance analysis and metrics interpretation")
    
    if any(term in context_lower for term in ["implementation", "guide", "tutorial", "steps"]):
        capabilities.append("• Implementation guidance and step-by-step instructions")
    
    if any(term in context_lower for term in ["use case", "application", "example", "scenario"]):
        capabilities.append("• Use case examples and practical applications")
    
    if any(term in context_lower for term in ["test", "testing", "validation", "verification"]):
        capabilities.append("• Testing strategies and validation approaches")
    
    if any(term in context_lower for term in ["configuration", "setup", "installation", "deployment"]):
        capabilities.append("• Configuration and setup assistance")
    
    if not capabilities:
        capabilities.append("• General questions about the topics covered in the documents")
        capabilities.append("• Detailed explanations and clarifications")
        capabilities.append("• Analysis and insights based on the available information")
    
    return "\n".join(capabilities)

def extract_key_points(context: str) -> list[str]:
    """Extract key points from context for generating responses"""
    # Simple extraction - in a real implementation, you might use NLP techniques
    sentences = context.replace('\n', ' ').split('. ')
    # Return first few meaningful sentences
    key_points = []
    for sentence in sentences[:3]:
        if len(sentence.strip()) > 20:  # Filter out very short sentences
            key_points.append(sentence.strip())
    return key_points

def generate_contextual_response(user_message: str, context: str) -> str:
    """Generate an intelligent contextual response based on user message and retrieved context"""
    if not context or not context.strip():
        return "I don't have specific information about that topic in my current knowledge base. Could you provide more details or try rephrasing your question?"
    
    user_message_lower = user_message.lower().strip()
    
    # Extract key information from context
    context_sentences = [s.strip() for s in context.replace('\n', ' ').split('.') if len(s.strip()) > 15]
    
    # Determine question type and generate appropriate response
    if any(word in user_message_lower for word in ['what is', 'what are', 'define', 'definition of']):
        return generate_definition_response(user_message, context_sentences)
    elif any(word in user_message_lower for word in ['how does', 'how do', 'how can', 'how to']):
        return generate_how_to_response(user_message, context_sentences)
    elif any(word in user_message_lower for word in ['why', 'what makes', 'what causes']):
        return generate_explanation_response(user_message, context_sentences)
    elif any(word in user_message_lower for word in ['features', 'capabilities', 'what can', 'supports']):
        return generate_features_response(user_message, context_sentences)
    elif any(word in user_message_lower for word in ['tell me about', 'explain', 'describe']):
        return generate_general_response(user_message, context_sentences)
    else:
        # Default to general response
        return generate_general_response(user_message, context_sentences)

def generate_definition_response(user_message: str, context_sentences: list[str]) -> str:
    """Generate a definition-style response"""
    relevant_sentences = context_sentences[:2]  # Take first 2 most relevant sentences
    
    if not relevant_sentences:
        return "I found some information but couldn't extract a clear definition from the available context."
    
    response = f"Based on the information I have:\n\n"
    response += f"{relevant_sentences[0]}"
    
    if len(relevant_sentences) > 1:
        response += f"\n\n{relevant_sentences[1]}"
    
    if len(context_sentences) > 2:
        response += "\n\nWould you like me to provide more details about any specific aspect?"
    
    return response

def generate_how_to_response(user_message: str, context_sentences: list[str]) -> str:
    """Generate a how-to or process-oriented response"""
    relevant_sentences = [s for s in context_sentences if any(word in s.lower() for word in ['process', 'step', 'method', 'way', 'how', 'use', 'work'])]
    
    if not relevant_sentences:
        relevant_sentences = context_sentences[:2]
    
    response = f"Based on the available information:\n\n"
    
    for i, sentence in enumerate(relevant_sentences[:3], 1):
        response += f"{sentence}\n\n"
    
    if len(context_sentences) > 3:
        response += "There's additional information available if you'd like me to elaborate on any specific aspect."
    
    return response

def generate_explanation_response(user_message: str, context_sentences: list[str]) -> str:
    """Generate an explanatory response for why/what makes questions"""
    relevant_sentences = context_sentences[:2]
    
    response = f"Here's what I can explain about that:\n\n"
    
    for sentence in relevant_sentences:
        response += f"{sentence}\n\n"
    
    if len(context_sentences) > 2:
        response += "Would you like me to go deeper into any particular aspect of this topic?"
    
    return response

def generate_features_response(user_message: str, context_sentences: list[str]) -> str:
    """Generate a features/capabilities focused response"""
    feature_sentences = [s for s in context_sentences if any(word in s.lower() for word in ['feature', 'support', 'include', 'provide', 'enable', 'allow'])]
    
    if not feature_sentences:
        feature_sentences = context_sentences[:3]
    
    response = f"Based on the information available, here are the key points:\n\n"
    
    for i, sentence in enumerate(feature_sentences[:4], 1):
        response += f"• {sentence}\n\n"
    
    if len(context_sentences) > 4:
        response += "There are additional details available if you need more specific information."
    
    return response

def generate_general_response(user_message: str, context_sentences: list[str]) -> str:
    """Generate a general informative response"""
    relevant_sentences = context_sentences[:3]
    
    response = f"Here's what I can tell you about that:\n\n"
    
    for sentence in relevant_sentences:
        response += f"{sentence}\n\n"
    
    if len(context_sentences) > 3:
        response += "I have more information available if you'd like me to elaborate on any specific aspect."
    
    return response
