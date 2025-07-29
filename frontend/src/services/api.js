import axios from 'axios';

const API_BASE_URL = process.env.REACT_APP_API_BASE_URL || 'http://localhost:8000';

// Multiple users configuration
const USERS = {
  'user1': {
    name: 'Dr. Sarah Johnson',
    apiKey: 'z9pD3bE7qR#sW8vY!mK2uN4x'
  },
  'user2': {
    name: 'Prof. Michael Chen',
    apiKey: 'K8mN5pQ2wX@tZ7vB#nC4uA1s'
  }
};

// Current user management
let currentUser = localStorage.getItem('currentUser') || 'user1';
const getCurrentUserConfig = () => USERS[currentUser];
const API_KEY = getCurrentUserConfig().apiKey;

// Create axios instance with default config
const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
    'X-API-KEY': API_KEY,
  },
});

// Request interceptor for logging
api.interceptors.request.use((config) => {
  console.log(`API Request: ${config.method?.toUpperCase()} ${config.url}`);
  return config;
});

// Response interceptor for error handling
api.interceptors.response.use(
  (response) => response,
  (error) => {
    console.error('API Error:', error.response?.data || error.message);
    return Promise.reject(error);
  }
);

// Chat Sessions API
export const chatSessionsAPI = {
  // Get all chat sessions
  getAll: () => api.get('/sessions/'),
  
  // Create new chat session
  create: (sessionData) => api.post('/sessions/', sessionData),
  
  // Get specific chat session with messages
  getById: (sessionId) => api.get(`/sessions/${sessionId}`),
  
  // Update chat session (rename, favorite)
  update: (sessionId, updateData) => api.patch(`/sessions/${sessionId}`, updateData),
  
  // Delete chat session
  delete: (sessionId) => api.delete(`/sessions/${sessionId}`),
};

// Messages API
export const messagesAPI = {
  // Get messages for a session
  getForSession: (sessionId, skip = 0, limit = 100) => 
    api.get(`/sessions/${sessionId}/messages?skip=${skip}&limit=${limit}`),
  
  // Add message to session
  addToSession: (sessionId, messageData) => 
    api.post(`/sessions/${sessionId}/messages/`, messageData),
};

// Documents API
export const documentsAPI = {
  // List all documents
  getAll: () => api.get('/documents/'),
  
  // Ingest documents from folder
  ingest: (ingestData) => api.post('/documents/ingest', ingestData),
  
  // Upload documents directly
  upload: (files) => {
    const formData = new FormData();
    files.forEach(file => {
      formData.append('files', file);
    });
    formData.append('chunk_size', '500');
    formData.append('chunk_overlap', '50');
    
    return api.post('/documents/upload', formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    });
  },
  
  // Search documents
  search: (searchData) => api.post('/documents/search', searchData),
};

// Health check
export const healthAPI = {
  check: () => api.get('/health/'),
};

// RAG Chat functionality - Now using the new backend endpoint
export const ragChatAPI = {
  // Send a message and get RAG-enhanced response
  sendMessage: async (sessionId, userMessage) => {
    try {
      const response = await api.post('/chat/', {
        session_id: sessionId,
        message: userMessage
      });
      return response.data;
    } catch (error) {
      console.error('RAG Chat error:', error);
      throw error;
    }
  }
};

// User management functions
export const userAPI = {
  getCurrentUser: () => {
    const userId = localStorage.getItem('currentUser') || 'user1';
    return {
      id: userId,
      ...USERS[userId]
    };
  },
  
  switchUser: (userId) => {
    if (USERS[userId]) {
      localStorage.setItem('currentUser', userId);
      // Update API key for future requests
      api.defaults.headers['X-API-KEY'] = USERS[userId].apiKey;
      return true;
    }
    return false;
  },
  
  getUsers: () => {
    return Object.keys(USERS).map(id => ({
      id,
      ...USERS[id]
    }));
  }
};

// Initialize API with current user's API key
api.defaults.headers['X-API-KEY'] = getCurrentUserConfig().apiKey;

// Mock AI response generation (replace with actual LLM integration)
const generateAIResponse = async (userMessage, context) => {
  // Simulate API delay
  await new Promise(resolve => setTimeout(resolve, 1500));
  
  const contextInfo = context ? 
    `Based on the available documents, here's what I found:\n\n${context.substring(0, 500)}...\n\n` : 
    'I don\'t have specific information in my knowledge base about this topic, but ';
  
  const responses = [
    `${contextInfo}I can help you understand this better. What specific aspect would you like me to explain?`,
    `${contextInfo}Let me break this down for you based on the available information.`,
    `${contextInfo}Here's my analysis of your question based on the documents I have access to.`,
    `${contextInfo}I can provide more details on this topic. Would you like me to elaborate on any particular aspect?`
  ];
  
  return responses[Math.floor(Math.random() * responses.length)];
};

export default api;
