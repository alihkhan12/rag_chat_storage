"""Multi-format document processing and chunking service"""
import os
import json
import xml.etree.ElementTree as ET
import csv
import io
from typing import List, Dict, Any, Optional, Union
from dataclasses import dataclass
import PyPDF2
from langchain.text_splitter import RecursiveCharacterTextSplitter
from ..logging import logger

@dataclass
class Document:
    filename: str
    content: str
    page_count: int
    metadata: Dict[str, Any]

@dataclass
class Chunk:
    text: str
    index: int
    page_number: Optional[int]
    metadata: Dict[str, Any]

class DocumentProcessor:
    """Enhanced multi-format document processor"""
    
    SUPPORTED_FORMATS = {
        '.pdf': 'PDF Document',
        '.txt': 'Text File', 
        '.json': 'JSON Document',
        '.xml': 'XML Document',
        '.csv': 'CSV Data File',
        '.md': 'Markdown Document',
        '.html': 'HTML Document',
        '.log': 'Log File',
        '.yaml': 'YAML Configuration',
        '.yml': 'YAML Configuration'
    }
    
    def __init__(self, chunk_size: int = 500, chunk_overlap: int = 50):
        self.chunk_size = chunk_size
        self.chunk_overlap = chunk_overlap
        self.text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=chunk_size,
            chunk_overlap=chunk_overlap,
            separators=["\n\n", "\n", ". ", "! ", "? ", "; ", ", ", " ", ""]
        )
        logger.info(f"Initialized DocumentProcessor with chunk_size={chunk_size}")
        logger.info(f"Supported formats: {list(self.SUPPORTED_FORMATS.keys())}")
    
    def get_file_extension(self, file_path: str) -> str:
        """Get file extension in lowercase"""
        return os.path.splitext(file_path.lower())[1]
    
    def is_supported_format(self, file_path: str) -> bool:
        """Check if file format is supported"""
        ext = self.get_file_extension(file_path)
        return ext in self.SUPPORTED_FORMATS
    
    def extract_text_from_pdf(self, pdf_path: str) -> Document:
        """Extract text from PDF files"""
        if not os.path.exists(pdf_path):
            raise FileNotFoundError(f"PDF not found: {pdf_path}")
        
        with open(pdf_path, 'rb') as file:
            pdf_reader = PyPDF2.PdfReader(file)
            page_count = len(pdf_reader.pages)
            
            full_text = ""
            for page_num in range(page_count):
                page = pdf_reader.pages[page_num]
                page_text = page.extract_text()
                full_text += page_text + "\n\n"
            
            metadata = {
                "filename": os.path.basename(pdf_path),
                "file_path": pdf_path,
                "file_type": "PDF",
                "page_count": page_count,
                "file_size": os.path.getsize(pdf_path)
            }
            
            return Document(
                filename=os.path.basename(pdf_path),
                content=full_text.strip(),
                page_count=page_count,
                metadata=metadata
            )
    
    def extract_text_from_txt(self, txt_path: str) -> Document:
        """Extract text from TXT files"""
        if not os.path.exists(txt_path):
            raise FileNotFoundError(f"TXT file not found: {txt_path}")
        
        with open(txt_path, 'r', encoding='utf-8', errors='ignore') as file:
            content = file.read()
        
        metadata = {
            "filename": os.path.basename(txt_path),
            "file_path": txt_path,
            "file_type": "Text",
            "page_count": 1,
            "file_size": os.path.getsize(txt_path),
            "line_count": len(content.splitlines())
        }
        
        return Document(
            filename=os.path.basename(txt_path),
            content=content,
            page_count=1,
            metadata=metadata
        )
    
    def extract_text_from_json(self, json_path: str) -> Document:
        """Extract text from JSON files"""
        if not os.path.exists(json_path):
            raise FileNotFoundError(f"JSON file not found: {json_path}")
        
        with open(json_path, 'r', encoding='utf-8') as file:
            try:
                data = json.load(file)
                # Convert JSON to readable text format
                content = self._json_to_text(data)
            except json.JSONDecodeError as e:
                logger.error(f"Invalid JSON in {json_path}: {e}")
                # Fallback to raw content
                file.seek(0)
                content = file.read()
        
        metadata = {
            "filename": os.path.basename(json_path),
            "file_path": json_path,
            "file_type": "JSON",
            "page_count": 1,
            "file_size": os.path.getsize(json_path)
        }
        
        return Document(
            filename=os.path.basename(json_path),
            content=content,
            page_count=1,
            metadata=metadata
        )
    
    def extract_text_from_xml(self, xml_path: str) -> Document:
        """Extract text from XML files"""
        if not os.path.exists(xml_path):
            raise FileNotFoundError(f"XML file not found: {xml_path}")
        
        try:
            tree = ET.parse(xml_path)
            root = tree.getroot()
            content = self._xml_to_text(root)
        except ET.ParseError as e:
            logger.error(f"Invalid XML in {xml_path}: {e}")
            # Fallback to raw content
            with open(xml_path, 'r', encoding='utf-8', errors='ignore') as file:
                content = file.read()
        
        metadata = {
            "filename": os.path.basename(xml_path),
            "file_path": xml_path,
            "file_type": "XML",
            "page_count": 1,
            "file_size": os.path.getsize(xml_path)
        }
        
        return Document(
            filename=os.path.basename(xml_path),
            content=content,
            page_count=1,
            metadata=metadata
        )
    
    def extract_text_from_csv(self, csv_path: str) -> Document:
        """Extract text from CSV files"""
        if not os.path.exists(csv_path):
            raise FileNotFoundError(f"CSV file not found: {csv_path}")
        
        content_lines = []
        row_count = 0
        
        with open(csv_path, 'r', encoding='utf-8', errors='ignore') as file:
            csv_reader = csv.reader(file)
            headers = next(csv_reader, None)
            
            if headers:
                content_lines.append(f"CSV Headers: {', '.join(headers)}\n")
            
            for row_num, row in enumerate(csv_reader, 1):
                if row:  # Skip empty rows
                    row_text = f"Row {row_num}: {', '.join(row)}"
                    content_lines.append(row_text)
                    row_count += 1
                    
                # Limit to prevent huge CSV files
                if row_count > 1000:
                    content_lines.append(f"\n... (truncated after 1000 rows)")
                    break
        
        content = "\n".join(content_lines)
        
        metadata = {
            "filename": os.path.basename(csv_path),
            "file_path": csv_path,
            "file_type": "CSV",
            "page_count": 1,
            "file_size": os.path.getsize(csv_path),
            "row_count": row_count
        }
        
        return Document(
            filename=os.path.basename(csv_path),
            content=content,
            page_count=1,
            metadata=metadata
        )
    
    def _json_to_text(self, data: Any, indent: int = 0) -> str:
        """Convert JSON data to readable text format"""
        lines = []
        prefix = "  " * indent
        
        if isinstance(data, dict):
            for key, value in data.items():
                if isinstance(value, (dict, list)):
                    lines.append(f"{prefix}{key}:")
                    lines.append(self._json_to_text(value, indent + 1))
                else:
                    lines.append(f"{prefix}{key}: {value}")
        elif isinstance(data, list):
            for i, item in enumerate(data):
                if isinstance(item, (dict, list)):
                    lines.append(f"{prefix}[{i}]:")
                    lines.append(self._json_to_text(item, indent + 1))
                else:
                    lines.append(f"{prefix}[{i}]: {item}")
        else:
            return str(data)
        
        return "\n".join(lines)
    
    def _xml_to_text(self, element: ET.Element, indent: int = 0) -> str:
        """Convert XML element to readable text format"""
        lines = []
        prefix = "  " * indent
        
        # Add element tag and attributes
        tag_info = element.tag
        if element.attrib:
            attrs = ", ".join([f"{k}={v}" for k, v in element.attrib.items()])
            tag_info += f" ({attrs})"
        
        lines.append(f"{prefix}{tag_info}:")
        
        # Add element text
        if element.text and element.text.strip():
            lines.append(f"{prefix}  {element.text.strip()}")
        
        # Process children
        for child in element:
            lines.append(self._xml_to_text(child, indent + 1))
        
        return "\n".join(lines)
    
    def extract_text_from_file(self, file_path: str) -> Document:
        """Main method to extract text from any supported file format"""
        if not os.path.exists(file_path):
            raise FileNotFoundError(f"File not found: {file_path}")
        
        if not self.is_supported_format(file_path):
            ext = self.get_file_extension(file_path)
            raise ValueError(f"Unsupported file format: {ext}. Supported formats: {list(self.SUPPORTED_FORMATS.keys())}")
        
        ext = self.get_file_extension(file_path)
        
        try:
            if ext == '.pdf':
                return self.extract_text_from_pdf(file_path)
            elif ext == '.txt':
                return self.extract_text_from_txt(file_path)
            elif ext == '.json':
                return self.extract_text_from_json(file_path)
            elif ext == '.xml':
                return self.extract_text_from_xml(file_path)
            elif ext == '.csv':
                return self.extract_text_from_csv(file_path)
            elif ext in ['.md', '.html', '.log', '.yaml', '.yml']:
                # These formats can be treated as text files
                doc = self.extract_text_from_txt(file_path)
                doc.metadata['file_type'] = self.SUPPORTED_FORMATS[ext]
                return doc
            else:
                raise ValueError(f"Handler not implemented for {ext}")
        except Exception as e:
            logger.error(f"Failed to extract text from {file_path}: {e}")
            raise
    
    def chunk_document(self, document: Document) -> List[Chunk]:
        texts = self.text_splitter.split_text(document.content)
        chunks = []
        for index, text in enumerate(texts):
            chunk = Chunk(
                text=text,
                index=index,
                page_number=None,
                metadata={
                    "filename": document.filename,
                    "chunk_size": len(text),
                    "total_chunks": len(texts)
                }
            )
            chunks.append(chunk)
        return chunks
    
    def process_folder(self, folder_path: str) -> List[tuple[Document, List[Chunk]]]:
        """
        Process all supported files in a folder, returning each document and its chunks.
        """
        if not os.path.exists(folder_path):
            raise FileNotFoundError(f"Folder not found: {folder_path}")
        
        results = []
        supported_files = [f for f in os.listdir(folder_path) if self.is_supported_format(f)]
        
        for file_name in supported_files:
            file_path = os.path.join(folder_path, file_name)
            try:
                document = self.extract_text_from_file(file_path)
                chunks = self.chunk_document(document)
                results.append((document, chunks))
            except Exception as e:
                logger.error(f"Failed to process {file_name}: {e}")
        
        return results

# Factory functions for backward compatibility and new functionality
def get_pdf_chunker(chunk_size: int = 500, chunk_overlap: int = 50) -> DocumentProcessor:
    """Factory function for backward compatibility - now returns DocumentProcessor"""
    return DocumentProcessor(chunk_size, chunk_overlap)

def get_document_processor(chunk_size: int = 500, chunk_overlap: int = 50) -> DocumentProcessor:
    """Factory function for the enhanced multi-format document processor"""
    return DocumentProcessor(chunk_size, chunk_overlap)
