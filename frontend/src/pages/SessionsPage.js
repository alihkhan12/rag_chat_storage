import React, { useState } from 'react';
import { useChatSessions } from '../hooks/useApi';
import { Link } from 'react-router-dom';
import { MessageSquare, Star, Plus, Edit2, Trash2, Heart } from 'lucide-react';

// Session Card Component
function SessionCard({
  session,
  editingId,
  editName,
  onEditStart,
  onEditSave,
  onEditCancel,
  onToggleFavorite,
  onDelete,
  setEditName
}) {
  return (
    <div key={session.id} className="bg-white rounded-lg shadow-sm border border-secondary-200 p-4 hover:shadow-md transition-shadow duration-200">
      <div className="flex items-center justify-between">
        <div className="flex-1">
          {editingId === session.id ? (
            <div className="flex items-center gap-2">
              <input
                type="text"
                value={editName}
                onChange={(e) => setEditName(e.target.value)}
                className="input flex-1"
                onKeyPress={(e) => e.key === 'Enter' && onEditSave(session.id)}
                autoFocus
              />
              <button 
                onClick={() => onEditSave(session.id)}
                className="btn-primary text-sm px-3 py-1"
              >
                Save
              </button>
              <button 
                onClick={onEditCancel}
                className="btn-secondary text-sm px-3 py-1"
              >
                Cancel
              </button>
            </div>
          ) : (
            <Link 
              to={`/sessions/${session.id}`} 
              className="block hover:text-primary-600 transition-colors duration-200"
            >
              <h3 className="text-lg font-semibold text-secondary-800 flex items-center gap-2">
                {session.session_name}
                {session.is_favorite && (
                  <Star className="w-4 h-4 text-yellow-500 fill-current" />
                )}
              </h3>
              <p className="text-sm text-secondary-500 mt-1">
                Created: {new Date(session.created_at).toLocaleDateString()}
                {session.messages?.length > 0 && (
                  <span className="ml-2">• {session.messages.length} messages</span>
                )}
              </p>
            </Link>
          )}
        </div>
        
        <div className="flex items-center gap-2 ml-4">
          <button
            onClick={() => onToggleFavorite(session)}
            className={`p-2 rounded-lg transition-colors ${
              session.is_favorite 
                ? 'text-yellow-500 hover:bg-yellow-50' 
                : 'text-secondary-400 hover:bg-secondary-50'
            }`}
            title={session.is_favorite ? 'Remove from favorites' : 'Add to favorites'}
          >
            <Heart className={`w-4 h-4 ${session.is_favorite ? 'fill-current' : ''}`} />
          </button>
          <button
            onClick={() => onEditStart(session)}
            className="p-2 rounded-lg text-secondary-400 hover:bg-secondary-50 hover:text-secondary-600"
            title="Rename session"
          >
            <Edit2 className="w-4 h-4" />
          </button>
          <button
            onClick={() => onDelete(session.id)}
            className="p-2 rounded-lg text-red-400 hover:bg-red-50 hover:text-red-600"
            title="Delete session"
          >
            <Trash2 className="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
  );
}

function SessionsPage() {
  const { sessions, loading, error, createSession, updateSession, deleteSession } = useChatSessions();
  const [editingId, setEditingId] = useState(null);
  const [editName, setEditName] = useState('');
  const favoriteSessions = sessions.filter(session => session.is_favorite);

  if (loading) return <div className="text-center mt-8 text-secondary-600">Loading sessions...</div>;
  if (error) return <div className="text-center mt-8 text-red-600">Error: {error}</div>;

  const handleCreateSession = async () => {
    try {
      await createSession({
        session_name: `New Chat ${new Date().toLocaleTimeString()}`,
        is_favorite: false,
      });
    } catch (e) {
      console.error('Failed to create session:', e);
    }
  };

  const handleEditStart = (session) => {
    setEditingId(session.id);
    setEditName(session.session_name);
  };

  const handleEditSave = async (sessionId) => {
    try {
      await updateSession(sessionId, { session_name: editName });
      setEditingId(null);
      setEditName('');
    } catch (e) {
      console.error('Failed to update session:', e);
    }
  };

  const handleToggleFavorite = async (session) => {
    try {
      await updateSession(session.id, { is_favorite: !session.is_favorite });
    } catch (e) {
      console.error('Failed to toggle favorite:', e);
    }
  };

  const handleDelete = async (sessionId) => {
    if (window.confirm('Are you sure you want to delete this session?')) {
      try {
        await deleteSession(sessionId);
      } catch (e) {
        console.error('Failed to delete session:', e);
      }
    }
  };

  return (
    <div className="max-w-4xl mx-auto">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-3xl font-bold text-secondary-800 flex items-center gap-2">
          <MessageSquare className="w-8 h-8 text-primary-600" />
          Chat Sessions
        </h1>
        <button 
          onClick={handleCreateSession} 
          className="btn-primary flex items-center gap-2"
        >
          <Plus className="w-4 h-4" />
          New Chat
        </button>
      </div>

      {sessions.length === 0 ? (
        <div className="text-center py-12">
          <MessageSquare className="w-16 h-16 text-secondary-300 mx-auto mb-4" />
          <p className="text-secondary-600">No chat sessions yet. Create your first one!</p>
        </div>
      ) : (
        <div className="space-y-8">
          {/* Favorite Chats Section */}
          {favoriteSessions.length > 0 && (
            <div>
              <h2 className="text-xl font-semibold text-secondary-800 mb-4 flex items-center gap-2">
                <Star className="w-5 h-5 text-yellow-500 fill-current" />
                Favorite Chats ({favoriteSessions.length})
              </h2>
              <div className="grid gap-4">
                {favoriteSessions.map((session) => (
                  <SessionCard
                    key={session.id}
                    session={session}
                    editingId={editingId}
                    editName={editName}
                    onEditStart={handleEditStart}
                    onEditSave={handleEditSave}
                    onEditCancel={() => setEditingId(null)}
                    onToggleFavorite={handleToggleFavorite}
                    onDelete={handleDelete}
                    setEditName={setEditName}
                  />
                ))}
              </div>
            </div>
          )}

          {/* All Chats Section */}
          <div>
            <h2 className="text-xl font-semibold text-secondary-800 mb-4 flex items-center gap-2">
              <MessageSquare className="w-5 h-5 text-primary-600" />
              All Chats ({sessions.length})
            </h2>
            <div className="grid gap-4">
              {sessions.map((session) => (
                <SessionCard
                  key={session.id}
                  session={session}
                  editingId={editingId}
                  editName={editName}
                  onEditStart={handleEditStart}
                  onEditSave={handleEditSave}
                  onEditCancel={() => setEditingId(null)}
                  onToggleFavorite={handleToggleFavorite}
                  onDelete={handleDelete}
                  setEditName={setEditName}
                />
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default SessionsPage;
