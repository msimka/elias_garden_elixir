# Tiki Hierarchical Specification Language

A revolutionary spec-first programming approach using hierarchical documentation trees.

## Overview

Tiki (.tiki files) uses a hierarchical markdown-like syntax where software specifications are organized in navigable tree structures. Each concept is defined at different levels using asterisk notation:

- No asterisk = Top level (single root concept, no numbering)  
- `*` = 1st sublevel (`*1`, `*2`, `*3`, etc.)
- `**` = 2nd sublevel (`*1**1`, `*1**2`, `*2**1`, `*2**2`, etc.)
- `***` = 3rd sublevel (`*1**1***1`, `*1**1***2`, etc.)

## Features

- **Tiki Parser**: Parse .tiki files and build hierarchical tree structures
- **ASCII Tree Visualizer**: Generate ASCII art tree representation
- **Interactive Navigator**: Navigate tree with keyboard, expand/collapse, show concepts
- **Export Capabilities**: JSON, YAML, markdown output formats

## Project Structure

```
tiki-lang/
├── src/tiki/           # Core library
├── tests/              # Test files
├── examples/           # Example .tiki files
├── docs/               # Documentation
└── pyproject.toml      # Poetry configuration
```

## Development

```bash
# Install dependencies
poetry install

# Run tests  
poetry run pytest

# Format code
poetry run black src/ tests/

# Type checking
poetry run mypy src/
```