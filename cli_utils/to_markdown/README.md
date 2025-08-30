# ELIAS Universal To-Markdown Converter

**Format Support**: RTF, RTFD, PDF, DOCX, HTML, TXT, and more → Markdown  
**Philosophy**: One tool to rule them all - everything becomes Markdown

## Overview

The Universal To-Markdown Converter handles multiple input formats and outputs clean, standardized Markdown. It's the essential tool for converting documents, papers, notes, and content into ELIAS's preferred Markdown format.

## Supported Formats

### Input Formats
- **RTF/RTFD** - Rich Text Format (with embedded media)
- **PDF** - Portable Document Format (text extraction)
- **DOCX** - Microsoft Word documents  
- **HTML** - Web pages and HTML files
- **TXT** - Plain text (with formatting detection)
- **DOC** - Legacy Microsoft Word
- **ODT** - OpenDocument Text
- **EPUB** - E-book format

### Output Format
- **Markdown (.md)** - GitHub Flavored Markdown with metadata frontmatter

## Usage

### As Mix Task
```bash
# Basic conversion
mix elias.to_markdown --input document.rtf
mix elias.to_markdown --input paper.pdf --output paper.md

# Specify input format (auto-detection by default)
mix elias.to_markdown --input document.rtfd --format rtfd --output doc.md

# Batch conversion
mix elias.to_markdown --input "papers/*.pdf" --output-dir "./markdown/"

# With metadata extraction
mix elias.to_markdown --input paper.pdf --extract-meta --output paper.md
```

### Command Line Options
```bash
Options:
  -i, --input PATH          Input file path (required)
  -o, --output PATH         Output file path (defaults to input.md)
  -f, --format FORMAT       Force input format (rtf|pdf|docx|html|txt|doc|odt|epub)
  -d, --output-dir DIR      Batch output directory
  -m, --extract-meta        Extract metadata (title, author, date) to frontmatter
  -c, --clean               Clean output (remove extra whitespace, normalize)
  -v, --verbose             Verbose output
  -h, --help                Show this help message

Examples:
  mix elias.to_markdown -i research.pdf -o research.md -m
  mix elias.to_markdown -i "docs/*.rtf" -d "./converted/" -c
  mix elias.to_markdown -i webpage.html -f html -v
```

## Features

### Smart Format Detection
- Automatic format detection from file extension and content
- Override with `--format` when needed
- Graceful fallback to text extraction

### Metadata Extraction
```yaml
---
title: "Document Title"
author: "Author Name" 
date: "2025-08-29"
source_file: "original.pdf"
converted_at: "2025-08-29T12:00:00Z"
format: "pdf"
pages: 15
---

# Document Content Starts Here...
```

### Content Cleaning
- Remove excessive whitespace and line breaks
- Normalize heading levels and structure
- Clean up formatting artifacts from conversion
- Preserve important formatting (bold, italic, lists, links)

### Batch Processing
- Convert multiple files with glob patterns
- Maintain directory structure in output
- Progress indicators for large batches
- Error handling and reporting per file

## Implementation Details

### Dependencies
- **Pandoc** - Universal document converter (primary engine)
- **pdftotext** (Poppler) - PDF text extraction
- **textutil** (macOS) - RTF/RTFD conversion
- **unrtf** (Linux/Windows) - RTF conversion fallback

### Conversion Pipeline
1. **Format Detection** - File extension + content sniffing
2. **Pre-processing** - Format-specific preparation
3. **Conversion** - Route to appropriate converter
4. **Post-processing** - Clean and normalize output
5. **Metadata** - Extract and format frontmatter
6. **Output** - Write final Markdown file

### Error Handling
- Graceful degradation (if Pandoc fails, try direct extraction)
- Detailed error messages with suggested fixes
- Partial conversion success (extract what's possible)
- Dependency checking with installation hints

## Installation Dependencies

### macOS (Homebrew)
```bash
brew install pandoc poppler
# textutil comes with macOS
```

### Ubuntu/Debian
```bash
sudo apt update
sudo apt install pandoc poppler-utils unrtf
```

### Windows (Chocolatey)
```bash
choco install pandoc poppler unrtf
```

## Testing

```bash
# Run all tests
mix test cli_utils/to_markdown/test/

# Test specific format
mix test cli_utils/to_markdown/test/ --only pdf_conversion

# Integration tests with sample files
mix test cli_utils/to_markdown/test/integration_test.exs
```

## Examples

### RTF Conversion
```bash
# Convert RTF with formatting
mix elias.to_markdown -i resume.rtf -o resume.md -c

# Result: Clean Markdown with preserved formatting
```

### PDF Academic Paper
```bash
# Convert PDF with metadata extraction  
mix elias.to_markdown -i research_paper.pdf -o paper.md -m -v

# Result: Markdown with extracted title, authors, and clean text
```

### Batch HTML Conversion
```bash
# Convert all HTML files in directory
mix elias.to_markdown -i "web_exports/*.html" -d "./markdown/" -c

# Result: Directory of clean Markdown files
```

## Integration with ELIAS

- **Learning Sandbox**: Perfect for ingesting papers and documents
- **UIM Management**: Supervised as utility sub-daemon
- **Tiki Validation**: Full specification and testing coverage
- **Cross-Platform**: Works on all ELIAS federation nodes

---

*Converting the world to Markdown, one document at a time* 📄➡️📝