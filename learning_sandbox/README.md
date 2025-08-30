# ELIAS Learning Sandbox

**Owner**: ULM (Universal Learning Manager)  
**Philosophy**: "Loosey-goosey" exploration with systematic organization  
**Integration**: Tiki Language Methodology for managed areas, freedom for raw exploration

## Overview

The Learning Sandbox is ELIAS's collaborative research and knowledge synthesis environment. It provides a flexible space for:

- 📚 **Academic Papers** - Research papers with AI-generated summaries
- 🎥 **Video Transcripts** - YouTube, podcasts, lectures with searchable metadata  
- 💭 **Collaborative Notes** - Raw ideas, synthesis, and structured knowledge graphs
- 🔬 **Research Tools** - Scripts for content ingestion and knowledge processing

## Structure

```
learning_sandbox/
├── README.md              # This file - overview and guidelines
├── metadata.json          # Global searchable index with tags and sources
├── raw_materials/         # COMPOST: Original files (PDF, RTF, DOCX, etc.) - staging area
├── papers/                # Academic papers (converted to Markdown)
│   ├── by_topic/         # Symlinks to topic-based views (ai/, distributed_systems/)
│   └── by_date/          # Chronological organization (2025-08/)
├── transcripts/          # YouTube/video content (converted to Markdown)
│   ├── by_source/        # youtube/, podcasts/, lectures/
│   └── by_topic/         # Topic-based symlinks
├── notes/                # Collaborative ideas and synthesis (Markdown)
│   ├── raw_ideas/        # Loose drafts and brainstorming
│   └── synthesized/      # Structured outputs, knowledge graphs (YAML)
└── tools/                # Ingestion and processing scripts
```

## Usage Guidelines

### Adding Content

**Raw Materials**: Drop ANY format (PDF, RTF, DOCX, HTML, etc.) into `raw_materials/` folder - this is your compost pile!

**Conversion Workflow**:
```bash
# Convert everything from raw materials to Markdown
mix elias.to_markdown -i "learning_sandbox/raw_materials/*.pdf" -d "learning_sandbox/papers/by_date/$(date +%Y-%m)/" -m -c

# Batch convert all formats
mix elias.to_markdown -i "learning_sandbox/raw_materials/*" -d "learning_sandbox/converted/" -m -v
```

**Organization**: After conversion, move Markdown files to appropriate locations:
- **Papers** → `papers/by_date/YYYY-MM/` or `papers/by_topic/`
- **Transcripts** → `transcripts/by_source/` with topic symlinks
- **Notes** → `notes/raw_ideas/` for exploration, `notes/synthesized/` when structured

### Metadata Format

Each piece of content should have corresponding metadata in `metadata.json`:

```json
{
  "content_id": "unique_identifier",
  "title": "Content Title",
  "type": "paper|transcript|note",
  "source": "URL or reference",
  "date_added": "2025-08-29",
  "tags": ["ai", "distributed_systems", "elixir"],
  "authors": ["Author Name"],
  "summary": "Brief description",
  "file_path": "relative/path/to/file"
}
```

### Search and Discovery

- **Browse by topic**: Use `by_topic/` symlinks for thematic exploration
- **Browse by time**: Use `by_date/` for chronological discovery  
- **Search metadata**: Use learning sandbox tools or `grep` on `metadata.json`
- **Full-text search**: Use `ripgrep` or built-in ELIAS search tools

## Integration with ELIAS

- **ULM Management**: ULM supervises ingestion, synthesis, and collaboration tools
- **UCM Coordination**: Multi-user notes and collaboration via federation
- **Tiki Validation**: Managed areas have `.tiki` specs for systematic organization
- **UFM Synchronization**: Content syncs across ELIAS federation nodes
- **Claude Integration**: AI-powered synthesis and summarization tools

## Development Workflow

1. **Exploration Phase**: Add content to appropriate directories, tag in metadata
2. **Synthesis Phase**: Use AI tools to generate summaries and connections
3. **Collaboration Phase**: Share insights via structured notes and knowledge graphs  
4. **Integration Phase**: Connect insights to ELIAS development and capabilities

## Tools and Scripts

See `tools/` directory for:
- YouTube transcript extractors
- Paper metadata extractors  
- AI summarization scripts
- Knowledge graph generators
- Search and discovery utilities

---

*Part of the ELIAS Distributed AI Operating System - where knowledge meets innovation* 🧠✨