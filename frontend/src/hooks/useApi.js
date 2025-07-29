import { useState, useEffect, useCallback } from 'react';
import { chatSessionsAPI, messagesAPI, documentsAPI, ragChatAPI, userAPI } from '../services/api';

// Hook for managing chat sessions
export const useChatSessions = () => {
  const [sessions, setSessions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const fetchSessions = useCallback(async () => {
    try {
      setLoading(true);
      const response = await chatSessionsAPI.getAll();
      setSessions(response.data);
      setError(null);
    } catch (err) {
      setError(err.message);
      console.error('Failed to fetch sessions:', err);
    } finally {
      setLoading(false);
    }
  }, []);

  const createSession = useCallback(async (sessionData) => {
    try {
      const response = await chatSessionsAPI.create(sessionData);
      setSessions(prev => [response.data, ...prev]);
      return response.data;
    } catch (err) {
      setError(err.message);
      throw err;
    }
  }, []);

  const updateSession = useCallback(async (sessionId, updateData) => {
    try {
      const response = await chatSessionsAPI.update(sessionId, updateData);
      setSessions(prev => prev.map(session => 
        session.id === sessionId ? response.data : session
      ));
      return response.data;
    } catch (err) {
      setError(err.message);
      throw err;
    }
  }, []);

  const deleteSession = useCallback(async (sessionId) => {
    try {
      await chatSessionsAPI.delete(sessionId);
      setSessions(prev => prev.filter(session => session.id !== sessionId));
    } catch (err) {
      setError(err.message);
      throw err;
    }
  }, []);

  useEffect(() => {
    fetchSessions();
  }, [fetchSessions]);

  return {
    sessions,
    loading,
    error,
    fetchSessions,
    createSession,
    updateSession,
    deleteSession,
  };
};

// Hook for managing messages in a chat session
export const useMessages = (sessionId) => {
  const [messages, setMessages] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [sending, setSending] = useState(false);

  const fetchMessages = useCallback(async () => {
    if (!sessionId) return;
    
    try {
      setLoading(true);
      const response = await messagesAPI.getForSession(sessionId);
      setMessages(response.data);
      setError(null);
    } catch (err) {
      setError(err.message);
      console.error('Failed to fetch messages:', err);
    } finally {
      setLoading(false);
    }
  }, [sessionId]);

  const sendMessage = useCallback(async (messageContent) => {
    if (!messageContent.trim() || sending) return;

    try {
      setSending(true);
      
      // Add user message to UI immediately
      const userMessage = {
        id: Date.now().toString(),
        sender: 'user',
        content: messageContent,
        created_at: new Date().toISOString(),
        session_id: sessionId
      };
      setMessages(prev => [...prev, userMessage]);

      // Send message through RAG system
      const aiResponse = await ragChatAPI.sendMessage(sessionId, messageContent);
      
      // Refresh messages to get the complete conversation
      await fetchMessages();
      
    } catch (err) {
      setError(err.message);
      console.error('Failed to send message:', err);
      // Remove the optimistic user message on error
      setMessages(prev => prev.filter(msg => msg.id !== Date.now().toString()));
    } finally {
      setSending(false);
    }
  }, [sessionId, sending, fetchMessages]);

  useEffect(() => {
    fetchMessages();
  }, [fetchMessages]);

  return {
    messages,
    loading,
    error,
    sending,
    fetchMessages,
    sendMessage,
  };
};

// Hook for managing documents
export const useDocuments = () => {
  const [documents, setDocuments] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [ingesting, setIngesting] = useState(false);

  const fetchDocuments = useCallback(async () => {
    try {
      setLoading(true);
      const response = await documentsAPI.getAll();
      setDocuments(response.data);
      setError(null);
    } catch (err) {
      setError(err.message);
      console.error('Failed to fetch documents:', err);
    } finally {
      setLoading(false);
    }
  }, []);

  const ingestDocuments = useCallback(async (ingestData) => {
    try {
      setIngesting(true);
      const response = await documentsAPI.ingest(ingestData);
      await fetchDocuments(); // Refresh document list
      return response.data;
    } catch (err) {
      setError(err.message);
      throw err;
    } finally {
      setIngesting(false);
    }
  }, [fetchDocuments]);

  const uploadDocuments = useCallback(async (files) => {
    try {
      setIngesting(true);
      const response = await documentsAPI.upload(files);
      await fetchDocuments(); // Refresh document list
      return response.data;
    } catch (err) {
      setError(err.message);
      throw err;
    } finally {
      setIngesting(false);
    }
  }, [fetchDocuments]);

  const searchDocuments = useCallback(async (searchData) => {
    try {
      const response = await documentsAPI.search(searchData);
      return response.data;
    } catch (err) {
      setError(err.message);
      throw err;
    }
  }, []);

  useEffect(() => {
    fetchDocuments();
  }, [fetchDocuments]);

  return {
    documents,
    loading,
    error,
    ingesting,
    fetchDocuments,
    ingestDocuments,
    uploadDocuments,
    searchDocuments,
  };
};

// Hook for application health status
export const useHealthCheck = () => {
  const [status, setStatus] = useState('checking');
  const [error, setError] = useState(null);

  const checkHealth = useCallback(async () => {
    try {
      const response = await fetch('http://localhost:8000/health/');
      const data = await response.json();
      setStatus(data.status);
      setError(null);
    } catch (err) {
      setStatus('error');
      setError(err.message);
    }
  }, []);

  useEffect(() => {
    checkHealth();
    const interval = setInterval(checkHealth, 30000); // Check every 30 seconds
    return () => clearInterval(interval);
  }, [checkHealth]);

  return { status, error, checkHealth };
};
