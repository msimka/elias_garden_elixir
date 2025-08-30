# CONCEPT: Main entry point for Tiki command-line interface
# Provides CLI commands for parsing, viewing, and exporting Tiki specifications
# Supports multiple output formats and interactive navigation
import argparse
import sys
from pathlib import Path
from typing import Optional

from .parser import TikiParser, TikiParseError
from .renderer import TikiRenderer
from .navigator import navigate_file
from rich.console import Console


# CONCEPT: Main CLI function with command argument parsing
# Supports view, export, and validate operations on .tiki files
# Provides user-friendly command-line interface for Tiki operations
def main():
    # CONCEPT: Set up argument parser with subcommands
    # Organize functionality into logical command groups
    # Provide help and usage information for users
    parser = argparse.ArgumentParser(
        description="Tiki Hierarchical Specification Language Tools",
        prog="tiki"
    )
    
    subparsers = parser.add_subparsers(dest="command", help="Available commands")
    
    # CONCEPT: View command for interactive navigation
    # Launch TUI navigator for exploring Tiki specifications
    # Primary command for interactive spec exploration
    view_parser = subparsers.add_parser("view", help="View Tiki file interactively")
    view_parser.add_argument("file", help="Path to .tiki file")
    
    # CONCEPT: Export command for format conversion
    # Convert Tiki specifications to other formats
    # Support JSON, ASCII, and other output formats
    export_parser = subparsers.add_parser("export", help="Export Tiki file to other formats")
    export_parser.add_argument("file", help="Path to .tiki file")
    export_parser.add_argument("--format", choices=["json", "ascii", "tree"], 
                              default="tree", help="Output format")
    export_parser.add_argument("--output", "-o", help="Output file (default: stdout)")
    
    # CONCEPT: Validate command for syntax checking
    # Check Tiki file syntax and report errors
    # Useful for CI/CD and development workflows
    validate_parser = subparsers.add_parser("validate", help="Validate Tiki file syntax")
    validate_parser.add_argument("file", help="Path to .tiki file")
    validate_parser.add_argument("--verbose", "-v", action="store_true", 
                                help="Show detailed validation information")
    
    # CONCEPT: Parse command-line arguments
    # Handle missing commands with helpful error message
    # Provide usage information when needed
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        sys.exit(1)
    
    # CONCEPT: Execute requested command
    # Route to appropriate handler function
    # Provide consistent error handling across commands
    try:
        if args.command == "view":
            return handle_view(args)
        elif args.command == "export":
            return handle_export(args)
        elif args.command == "validate":
            return handle_validate(args)
    except TikiParseError as e:
        console = Console()
        console.print(f"[red]Parse Error:[/red] {e}")
        return 1
    except Exception as e:
        console = Console()
        console.print(f"[red]Error:[/red] {e}")
        return 1
    
    return 0


# CONCEPT: Handle interactive view command
# Launch TUI navigator for file exploration
# Provide immersive specification browsing experience
def handle_view(args) -> int:
    file_path = Path(args.file)
    
    # CONCEPT: Validate file exists before attempting navigation
    # Provide clear error message for missing files
    # Prevent confusing navigation startup failures
    if not file_path.exists():
        console = Console()
        console.print(f"[red]Error:[/red] File not found: {file_path}")
        return 1
    
    # CONCEPT: Launch navigation interface
    # Handle navigation errors gracefully
    # Provide success feedback for command completion
    console = Console()
    console.print(f"[green]Loading Tiki file:[/green] {file_path}")
    
    success = navigate_file(str(file_path))
    return 0 if success else 1


# CONCEPT: Handle export command for format conversion
# Convert Tiki specifications to various output formats
# Support both file output and stdout for pipeline usage
def handle_export(args) -> int:
    file_path = Path(args.file)
    console = Console()
    
    # CONCEPT: Parse Tiki file for export processing
    # Handle parsing errors with user-friendly messages
    # Ensure file is valid before attempting export
    try:
        parser = TikiParser()
        root_node = parser.parse_file(file_path)
        console.print(f"[green]Parsed:[/green] {file_path}")
    except Exception as e:
        console.print(f"[red]Parse Error:[/red] {e}")
        return 1
    
    # CONCEPT: Generate output in requested format
    # Support multiple export formats for different use cases
    # Provide consistent output handling across formats
    renderer = TikiRenderer()
    output_content = ""
    
    if args.format == "json":
        # CONCEPT: Export as JSON for data interchange
        # Structured format for programmatic processing
        # Preserves all specification metadata
        import json
        data = renderer.export_json(root_node)
        output_content = json.dumps(data, indent=2)
        
    elif args.format == "ascii":
        # CONCEPT: Export as plain ASCII tree
        # Simple text format for documentation
        # Compatible with any text processing tool
        output_content = renderer.export_ascii_tree(root_node)
        
    elif args.format == "tree":
        # CONCEPT: Export as rich-formatted tree
        # Styled output for terminal display
        # Maintains visual hierarchy and formatting
        from io import StringIO
        string_console = Console(file=StringIO(), width=120)
        renderer.console = string_console
        renderer.print_tree(root_node, title=f"Tiki Specification: {file_path.name}")
        output_content = string_console.file.getvalue()
    
    # CONCEPT: Write output to file or stdout
    # Support both file output and pipeline usage
    # Handle file writing errors gracefully
    if args.output:
        try:
            output_path = Path(args.output)
            output_path.write_text(output_content, encoding='utf-8')
            console.print(f"[green]Exported to:[/green] {output_path}")
        except Exception as e:
            console.print(f"[red]Export Error:[/red] {e}")
            return 1
    else:
        # CONCEPT: Print to stdout for pipeline usage
        # Enable integration with other command-line tools
        # Provide clean output without extra formatting
        print(output_content)
    
    return 0


# CONCEPT: Handle validate command for syntax checking
# Check Tiki file syntax and provide detailed error information
# Useful for development and CI/CD validation
def handle_validate(args) -> int:
    file_path = Path(args.file)
    console = Console()
    
    # CONCEPT: Attempt to parse file and report results
    # Provide detailed feedback for validation success/failure
    # Show parse tree information in verbose mode
    try:
        parser = TikiParser()
        root_node = parser.parse_file(file_path)
        
        # CONCEPT: Report successful validation
        # Count concepts for validation feedback
        # Provide tree structure summary
        concept_count = sum(1 for _ in root_node.descendants) + 1  # +1 for root
        console.print(f"[green]✓ Valid Tiki file:[/green] {file_path}")
        console.print(f"[blue]Concepts:[/blue] {concept_count}")
        
        # CONCEPT: Show detailed information in verbose mode
        # Display tree structure and concept hierarchy
        # Help users understand parsed structure
        if args.verbose:
            console.print(f"[blue]Root concept:[/blue] {root_node.title}")
            console.print(f"[blue]Max depth:[/blue] {max((node.depth for node in root_node.descendants), default=0)}")
            
            # Show tree structure
            renderer = TikiRenderer(console)
            renderer.print_tree(root_node, title="Parsed Structure:")
        
        return 0
        
    except TikiParseError as e:
        # CONCEPT: Report parsing errors with detailed information
        # Show line numbers and context for debugging
        # Provide actionable error messages for fixing syntax
        console.print(f"[red]✗ Invalid Tiki file:[/red] {file_path}")
        console.print(f"[red]Error:[/red] {e}")
        
        if args.verbose:
            console.print(f"[dim]Tip: Check the syntax around line {e.line_number}[/dim]")
        
        return 1
        
    except Exception as e:
        # CONCEPT: Handle unexpected errors during validation
        # Provide generic error handling for robustness
        # Suggest common solutions for file issues
        console.print(f"[red]✗ Validation failed:[/red] {file_path}")
        console.print(f"[red]Error:[/red] {e}")
        return 1


# CONCEPT: Standard Python entry point
# Allow module execution as script
# Support both import and direct execution
if __name__ == "__main__":
    sys.exit(main())