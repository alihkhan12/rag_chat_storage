import React, { useState, useCallback } from 'react';
import { useDocuments } from '../hooks/useApi';
import { Inbox, Upload, FileText, X, CheckCircle, AlertCircle } from 'lucide-react';
import { useDropzone } from 'react-dropzone';

function DocumentsPage() {
  const { documents, loading, error, fetchDocuments, ingestDocuments, uploadDocuments } = useDocuments();
  const [ingestPath, setIngestPath] = useState('');
  const [uploading, setUploading] = useState(false);
  const [uploadStatus, setUploadStatus] = useState(null);
  const [selectedFiles, setSelectedFiles] = useState([]);

  const onDrop = useCallback((acceptedFiles) => {
    setSelectedFiles(prev => [...prev, ...acceptedFiles]);
    setUploadStatus(null);
  }, []);

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: {
      'application/pdf': ['.pdf'],
      'text/plain': ['.txt'],
      'application/json': ['.json'],
      'application/xml': ['.xml'],
      'text/xml': ['.xml'],
      'text/csv': ['.csv'],
      'text/markdown': ['.md'],
      'text/html': ['.html'],
      'text/yaml': ['.yaml', '.yml'],
      'application/x-yaml': ['.yaml', '.yml']
    },
    multiple: true
  });

  const removeFile = (index) => {
    setSelectedFiles(prev => prev.filter((_, i) => i !== index));
  };

  const handleFileUpload = async () => {
    if (selectedFiles.length === 0) return;

    setUploading(true);
    setUploadStatus(null);

    try {
      const result = await uploadDocuments(selectedFiles);
      setUploadStatus({
        type: 'success',
        message: `Successfully processed ${result.processed_documents} documents with ${result.total_chunks} chunks.`,
        details: result.failed_documents.length > 0 ? `Failed: ${result.failed_documents.join(', ')}` : null
      });
      setSelectedFiles([]);
      fetchDocuments(); // Refresh document list
    } catch (err) {
      setUploadStatus({
        type: 'error',
        message: 'Upload failed: ' + (err.response?.data?.detail || err.message)
      });
    } finally {
      setUploading(false);
    }
  };

  const handleIngest = async () => {
    if (!ingestPath) return alert('Please enter a valid folder path.');

    try {
      await ingestDocuments({ folder_path: ingestPath, chunk_size: 500, chunk_overlap: 50 });
      setUploadStatus({
        type: 'success',
        message: 'Documents from folder ingested successfully.'
      });
      setIngestPath('');
    } catch (err) {
      setUploadStatus({
        type: 'error',
        message: 'Ingestion failed: ' + (err.response?.data?.detail || err.message)
      });
    }
  };

  return (
    <div className="max-w-6xl mx-auto space-y-8">
      <div className="flex justify-between items-center">
        <h1 className="text-3xl font-bold text-secondary-800 flex items-center gap-2">
          <Inbox className="w-8 h-8 text-primary-600" />
          Documents
        </h1>
      </div>

      {/* Upload Status */}
      {uploadStatus && (
        <div className={`p-4 rounded-lg border ${
          uploadStatus.type === 'success' 
            ? 'bg-green-50 border-green-200 text-green-800' 
            : 'bg-red-50 border-red-200 text-red-800'
        }`}>
          <div className="flex items-center gap-2">
            {uploadStatus.type === 'success' ? (
              <CheckCircle className="w-5 h-5" />
            ) : (
              <AlertCircle className="w-5 h-5" />
            )}
            <span className="font-medium">{uploadStatus.message}</span>
          </div>
          {uploadStatus.details && (
            <p className="text-sm mt-1 ml-7">{uploadStatus.details}</p>
          )}
        </div>
      )}

      {/* File Upload Section */}
      <div className="bg-white rounded-lg shadow-sm border border-secondary-200 p-6">
        <h2 className="text-xl font-semibold text-secondary-800 mb-4 flex items-center gap-2">
          <Upload className="w-5 h-5" />
          Upload Documents
        </h2>
        
        {/* Drag and Drop Zone */}
        <div
          {...getRootProps()}
          className={`border-2 border-dashed rounded-lg p-8 text-center cursor-pointer transition-colors ${
            isDragActive 
              ? 'border-primary-400 bg-primary-50' 
              : selectedFiles.length > 0
              ? 'border-green-400 bg-green-50'
              : 'border-secondary-300 hover:border-primary-400 hover:bg-primary-50'
          }`}
        >
          <input {...getInputProps()} />
          <Upload className="w-12 h-12 text-secondary-400 mx-auto mb-4" />
          {isDragActive ? (
            <p className="text-lg text-primary-600">Drop the files here...</p>
          ) : (
            <div>
              <p className="text-lg text-secondary-700 mb-2">
                Drag & drop documents here, or click to select
              </p>
              <p className="text-sm text-secondary-500">
                Supports: PDF, TXT, JSON, XML, CSV, MD, HTML, YAML files
              </p>
            </div>
          )}
        </div>

        {/* Selected Files */}
        {selectedFiles.length > 0 && (
          <div className="mt-6">
            <h3 className="text-sm font-medium text-secondary-700 mb-3">
              Selected Files ({selectedFiles.length})
            </h3>
            <div className="space-y-2 max-h-60 overflow-y-auto">
              {selectedFiles.map((file, index) => (
                <div key={index} className="flex items-center justify-between p-3 bg-secondary-50 rounded-lg">
                  <div className="flex items-center gap-3">
                    <FileText className="w-4 h-4 text-secondary-500" />
                    <div>
                      <p className="text-sm font-medium text-secondary-800">{file.name}</p>
                      <p className="text-xs text-secondary-500">
                        {(file.size / 1024 / 1024).toFixed(2)} MB
                      </p>
                    </div>
                  </div>
                  <button
                    onClick={() => removeFile(index)}
                    className="p-1 hover:bg-secondary-200 rounded-full transition-colors"
                  >
                    <X className="w-4 h-4 text-secondary-500" />
                  </button>
                </div>
              ))}
            </div>
            
            <div className="flex gap-3 mt-4">
              <button
                onClick={handleFileUpload}
                disabled={uploading || selectedFiles.length === 0}
                className="btn-primary flex items-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {uploading ? (
                  <>
                    <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                    Processing...
                  </>
                ) : (
                  <>
                    <Upload className="w-4 h-4" />
                    Upload & Process ({selectedFiles.length} files)
                  </>
                )}
              </button>
              <button
                onClick={() => setSelectedFiles([])}
                className="btn-secondary"
                disabled={uploading}
              >
                Clear All
              </button>
            </div>
          </div>
        )}
      </div>

      {/* Folder Ingestion Section */}
      <div className="bg-white rounded-lg shadow-sm border border-secondary-200 p-6">
        <h2 className="text-xl font-semibold text-secondary-800 mb-4">
          Ingest from Folder
        </h2>
        <div className="flex gap-4">
          <input
            type="text"
            className="input flex-1"
            placeholder="Enter folder path (e.g., /Volumes/Personal/rag_chat_storage/input_docs)"
            value={ingestPath}
            onChange={(e) => setIngestPath(e.target.value)}
          />
          <button 
            onClick={handleIngest} 
            className="btn-primary flex items-center gap-2 disabled:opacity-50" 
            disabled={!ingestPath}
          >
            <Inbox className="w-4 h-4" />
            Ingest Folder
          </button>
        </div>
        <p className="text-sm text-secondary-500 mt-2">
          This will process all supported documents in the specified folder.
        </p>
      </div>

      {loading ? (
        <div className="text-center mt-8 text-secondary-600">Loading documents...</div>
      ) : error ? (
        <div className="text-center mt-8 text-red-600">Error: {error}</div>
      ) : documents.length === 0 ? (
        <div className="text-center py-12">
          <Inbox className="w-16 h-16 text-secondary-300 mx-auto mb-4" />
          <p className="text-secondary-600">No documents ingested yet.</p>
        </div>
      ) : (
        <div className="grid gap-4">
          {documents.map((doc) => (
            <div key={doc.id} className="bg-white rounded-lg shadow-sm border border-secondary-200 p-4">
              <h3 className="text-lg font-semibold text-secondary-800">{doc.filename}</h3>
              <p className="text-sm text-secondary-500 mt-1">{doc.page_count} pages</p>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

export default DocumentsPage;

