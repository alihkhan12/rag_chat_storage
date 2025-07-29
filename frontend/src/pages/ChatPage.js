import React, { useState, useEffect, useRef } from 'react';
import { useParams } from 'react-router-dom';
import { useMessages } from '../hooks/useApi';
import { MessageSquare, Send, Loader } from 'lucide-react';

function ChatPage() {
  const { sessionId } = useParams();
  const { messages, loading, sending, sendMessage, error } = useMessages(sessionId);
  const [newMessage, setNewMessage] = useState('');
  const messagesEndRef = useRef(null);

  const handleSendMessage = () => {
    if (newMessage.trim()) {
      sendMessage(newMessage);
      setNewMessage('');
    }
  };

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, sending]);

  if (loading) return <div className="text-center mt-8 text-secondary-600">Loading chat...</div>;
  if (error) return <div className="text-center mt-8 text-red-600">Error: {error}</div>;

  return (
    <div className="max-w-4xl mx-auto h-full flex flex-col bg-white shadow rounded-lg border border-secondary-200">
      <div className="p-4 flex items-center justify-between bg-primary-100 border-b border-secondary-200">
        <h2 className="text-xl font-semibold text-secondary-800 flex items-center gap-2">
          <MessageSquare className="w-6 h-6 text-primary-600" />
          Chat
        </h2>
      </div>
      <div className="flex-grow overflow-y-auto p-4 space-y-4 scrollbar-thin">
        {messages.map((message) => (
          <div
            key={message.id}
            className={`chat-message ${message.sender === 'user' ? 'user' : 'assistant'}`}
          >
            <p className="text-sm text-secondary-800">{message.content}</p>
            {message.retrieved_context && (
              <blockquote className="text-xs text-gray-500 mt-2 border-l-2 border-gray-200 pl-2">
                {message.retrieved_context}
              </blockquote>
            )}
          </div>
        ))}
        {sending && (
          <div className="text-center text-sm text-secondary-500 py-2">
            <Loader className="w-4 h-4 text-primary-600 animate-spin inline-block mr-2" />
            Sending message...
          </div>
        )}
        <div ref={messagesEndRef} />
      </div>
      <div className="p-4 border-t border-secondary-200 bg-secondary-50">
        <div className="flex items-center">
          <input
            type="text"
            className="input flex-1 mr-2"
            placeholder="Type your message..."
            value={newMessage}
            onChange={(e) => setNewMessage(e.target.value)}
            onKeyPress={(e) => e.key === 'Enter' && handleSendMessage()}
            disabled={sending}
          />
          <button
            className="btn-primary flex items-center gap-1"
            onClick={handleSendMessage}
            disabled={sending}
          >
            <Send className="w-4 h-4" />
            Send
          </button>
        </div>
      </div>
    </div>
  );
}

export default ChatPage;

