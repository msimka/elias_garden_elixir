# ELIAS CLI Utilities

**Owner**: UIM (Universal Interface Manager)  
**Philosophy**: Rapid development, self-contained utilities, workflow enhancement  
**Integration**: Tiki Language Methodology for validation and testing

## Overview

ELIAS CLI Utilities provide essential workflow tools for developers and users. Each utility is self-contained with documentation, testing, and clear interfaces.

## Available Utilities

### Document Converters
- **rtf_to_md**: Convert RTF/RTFD files to Markdown
- **pdf_to_md**: Convert PDF files to Markdown with text extraction

### Planned Utilities
- **yaml_validator**: Validate and format YAML files
- **json_formatter**: Pretty-print and validate JSON
- **git_helper**: Git workflow automation tools
- **tiki_validator**: Tiki specification validation tools

## Usage

### As Mix Tasks
```bash
# Convert RTF to Markdown
mix elias.rtf_to_md --input document.rtf --output document.md

# Convert PDF to Markdown  
mix elias.pdf_to_md --input paper.pdf --output paper.md

# List all available utilities
mix elias.utils.list
```

### As Standalone Scripts
```bash
# Direct execution (if in PATH)
elias-rtf-to-md document.rtf > document.md
elias-pdf-to-md paper.pdf > paper.md
```

## Structure

```
cli_utils/
├── README.md                   # This file - catalog and usage guide
├── common/                     # Shared libraries and helpers
│   ├── config.ex              # Common configuration
│   ├── helpers.ex             # Shared utility functions
│   └── cli_helpers.ex         # Command-line interface helpers
├── rtf_to_md/                 # RTF/RTFD to Markdown converter
│   ├── rtf_to_md.ex           # Main conversion script
│   ├── README.md              # Detailed docs and examples
│   ├── test/                  # Unit tests
│   └── rtf_to_md.tiki         # Tiki specification
├── pdf_to_md/                 # PDF to Markdown converter
│   ├── pdf_to_md.ex           # Main conversion script
│   ├── README.md              # Detailed docs and examples  
│   ├── test/                  # Unit tests
│   └── pdf_to_md.tiki         # Tiki specification
└── mix.exs                    # Mix project for task discovery
```

## Development Guidelines

### Creating a New Utility

1. **Create Directory**: `mkdir cli_utils/your_utility/`
2. **Main Script**: Create `your_utility.ex` with clear module structure
3. **Documentation**: Add `README.md` with examples and usage
4. **Testing**: Create `test/` directory with comprehensive tests
5. **Tiki Spec**: Add `.tiki` file with function contracts and validation
6. **Mix Task**: Register in main `mix.exs` for `mix elias.your_utility`

### Code Standards

- **Error Handling**: Use `{:ok, result}` / `{:error, reason}` patterns
- **CLI Interface**: Use `OptionParser` for argument parsing
- **Documentation**: Include `@moduledoc` and `@doc` for all public functions
- **Testing**: Aim for >90% test coverage with ExUnit
- **Dependencies**: Minimize external deps, prefer standard library

### Integration with UIM

- **Supervision**: UIM can supervise background utilities as sub-daemons
- **Hot Reload**: UIM monitors utility changes and reloads on updates
- **Validation**: All utilities validated via Tiki specs before deployment
- **Discovery**: UIM provides utility catalog and help system

## Common Patterns

### CLI Argument Parsing
```elixir
defmodule YourUtility.CLI do
  def main(args) do
    {opts, args, _} = OptionParser.parse(args, 
      switches: [input: :string, output: :string, help: :boolean],
      aliases: [i: :input, o: :output, h: :help]
    )
    
    case opts do
      [help: true] -> print_help()
      _ -> process_args(opts, args)
    end
  end
end
```

### Error Handling
```elixir
def convert_file(input_path, output_path) do
  with {:ok, content} <- File.read(input_path),
       {:ok, converted} <- perform_conversion(content),
       :ok <- File.write(output_path, converted) do
    {:ok, "Successfully converted #{input_path} to #{output_path}"}
  else
    {:error, :enoent} -> {:error, "Input file not found: #{input_path}"}
    {:error, reason} -> {:error, "Conversion failed: #{reason}"}
  end
end
```

## Dependencies and External Tools

Common external tools used by utilities:
- **Pandoc**: Document conversion (install via brew/apt)
- **Poppler**: PDF text extraction (`pdftotext`)
- **ImageMagick**: Image processing utilities
- **FFmpeg**: Media file processing

Check utility-specific READMEs for detailed dependency information.

## Integration with ELIAS

- **UIM Management**: UIM supervises utility lifecycle and updates
- **Tiki Validation**: All utilities have specs for testing and validation  
- **UFM Distribution**: Utilities can be distributed across ELIAS federation
- **UCM Integration**: Utilities can be called via manager communication system

---

*Enhancing ELIAS workflows, one utility at a time* 🛠️⚡