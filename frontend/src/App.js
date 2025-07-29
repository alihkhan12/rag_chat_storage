import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Link } from 'react-router-dom';
import { Users } from 'lucide-react';
import ChatPage from './pages/ChatPage';
import SessionsPage from './pages/SessionsPage';
import DocumentsPage from './pages/DocumentsPage';
import { userAPI } from './services/api';

function App() {
  const [currentUser, setCurrentUser] = useState(userAPI.getCurrentUser());
  const [showUserDropdown, setShowUserDropdown] = useState(false);
  const users = userAPI.getUsers();

  const switchUser = (userId) => {
    if (userAPI.switchUser(userId)) {
      setCurrentUser(userAPI.getCurrentUser());
      setShowUserDropdown(false);
      // Refresh the page to update all API calls with new user context
      window.location.reload();
    }
  };

  return (
    <Router>
      <div className="flex flex-col min-h-screen">
        <header className="p-4 bg-primary-600 text-white flex justify-between items-center">
          <h1 className="text-xl font-bold">RAG Chat Storage</h1>
          <div className="relative">
            <button 
              onClick={() => setShowUserDropdown(!showUserDropdown)} 
              className="btn btn-secondary flex items-center gap-2"
            >
              <Users className="w-4 h-4" />
              {currentUser.name}
            </button>
            {showUserDropdown && (
              <div className="absolute right-0 mt-2 w-64 bg-white rounded-md shadow-lg z-50 border border-gray-200">
                <div className="py-1">
                  {users.map(user => (
                    <button
                      key={user.id}
                      onClick={() => switchUser(user.id)}
                      className={`w-full text-left px-4 py-2 text-sm hover:bg-gray-100 ${
                        currentUser.id === user.id 
                          ? 'bg-primary-50 text-primary-700 font-medium' 
                          : 'text-gray-700'
                      }`}
                    >
                      <div className="flex items-center justify-between">
                        <span>{user.name}</span>
                        {currentUser.id === user.id && (
                          <span className="text-primary-600">✓</span>
                        )}
                      </div>
                    </button>
                  ))}
                </div>
              </div>
            )}
          </div>
        </header>
        <main className="flex-grow container mx-auto p-4">
          <nav className="mb-4 flex justify-around">
            <Link to="/sessions" className="btn btn-primary">Chats</Link>
            <Link to="/documents" className="btn btn-primary">Documents</Link>
          </nav>
          <Routes>
            <Route path="/sessions" element={<SessionsPage />} />
            <Route path="/sessions/:sessionId" element={<ChatPage />} />
            <Route path="/documents" element={<DocumentsPage />} />
            <Route path="/*" element={<SessionsPage />} />
          </Routes>
        </main>
        <footer className="p-4 bg-secondary-200 text-secondary-800 text-center">
          © {new Date().getFullYear()} RAG Chat Storage. All rights reserved.
        </footer>
      </div>
    </Router>
  );
}

export default App;

