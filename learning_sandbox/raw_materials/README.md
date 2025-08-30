# Raw Materials - Document Compost

**Purpose**: Staging area for unconverted documents in various formats  
**Philosophy**: Dump everything here, convert to Markdown, then forget about the originals  
**Workflow**: RTF/PDF/DOCX → Convert → Markdown elsewhere in learning sandbox

## Overview

This is the "compost pile" for all your raw document materials. Drop files here in any format, then use ELIAS conversion tools to turn them into clean Markdown files that live in the main learning sandbox areas.

## Supported Raw Formats

- **PDFs** - Research papers, articles, reports
- **RTF/RTFD** - Rich text documents with formatting  
- **DOCX/DOC** - Microsoft Word documents
- **HTML** - Web pages, exported articles
- **EPUB** - E-books and digital publications
- **TXT** - Plain text files
- **ODT** - OpenDocument text files

## Workflow

### 1. Drop Files Here
Just drag and drop any documents into this folder. No organization needed - this is intentionally messy!

### 2. Batch Convert to Markdown
```bash
# Convert all PDFs to markdown in papers/ folder
mix elias.to_markdown -i "learning_sandbox/raw_materials/*.pdf" -d "learning_sandbox/papers/by_date/$(date +%Y-%m)/" -m -c

# Convert all RTF files to notes
mix elias.to_markdown -i "learning_sandbox/raw_materials/*.rtf" -d "learning_sandbox/notes/raw_ideas/" -c

# Convert everything to a staging area first
mix elias.to_markdown -i "learning_sandbox/raw_materials/*" -d "learning_sandbox/converted/" -m -v
```

### 3. Organize Converted Markdown
Once converted, move the clean Markdown files to appropriate locations:
- **Academic papers** → `papers/by_topic/` or `papers/by_date/`
- **Meeting notes** → `notes/raw_ideas/`
- **Transcripts** → `transcripts/by_source/`
- **Research notes** → `notes/synthesized/`

### 4. Archive or Delete Originals
After successful conversion, you can:
- Delete the original files (they're converted to Markdown)
- Move to an archive folder if you want to keep originals
- Keep only if the original format has special value

## File Naming Suggestions

While this folder is intentionally unorganized, some loose naming can help:

- `paper_[topic]_[author].[ext]` - Research papers
- `notes_[date]_[topic].[ext]` - Meeting or research notes  
- `transcript_[source]_[date].[ext]` - Video/audio transcripts
- `article_[title].[ext]` - Articles and blog posts

## Automatic Processing Ideas

You could set up automatic conversion workflows:

```bash
# Watch for new files and auto-convert
# (This would be a ULM supervised process)

# Convert anything older than 1 day
find learning_sandbox/raw_materials/ -type f -mtime +1 -exec mix elias.to_markdown -i {} -d learning_sandbox/converted/ \;

# Batch process weekly
mix elias.to_markdown -i "learning_sandbox/raw_materials/*" -d "learning_sandbox/weekly_batch/$(date +%Y-%U)/"
```

## Integration with Learning Sandbox

This folder connects with the main learning sandbox structure:

```
learning_sandbox/
├── raw_materials/          # ← THIS FOLDER (compost pile)
│   ├── paper1.pdf
│   ├── notes.rtf
│   ├── article.docx
│   └── transcript.html
├── papers/                 # ← Converted academic papers
│   └── by_date/2025-08/
├── notes/                  # ← Converted notes and ideas
│   └── raw_ideas/
├── transcripts/           # ← Converted video/audio content
│   └── by_source/
└── tools/                 # ← Conversion and processing scripts
```

## Cleanup Strategy

- **Weekly**: Review and convert accumulated files
- **Monthly**: Archive or delete successfully converted originals
- **As needed**: Quick batch conversion when working on specific projects

---

*The messier this folder, the more organized your Markdown will be* 📄♻️📝