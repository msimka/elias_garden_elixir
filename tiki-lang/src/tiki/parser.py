# CONCEPT: Tiki file parser implementing Architect's line-by-line algorithm
# Parses .tiki files into TikiNode tree structures using stack-based hierarchy tracking
# Handles asterisk notation: *, **, *** with automatic numbering and validation
# Supports description text following concept titles
import re
from typing import List, Optional, TextIO, Dict, Any
from pathlib import Path
import yaml
from .core import TikiNode


# CONCEPT: Exception for parsing errors with line number context
# Provides detailed error messages for malformed .tiki files
# Helps users fix syntax issues with specific line references
class TikiParseError(Exception):
    def __init__(self, message: str, line_number: int = 0, line_content: str = ""):
        self.line_number = line_number
        self.line_content = line_content
        super().__init__(f"Line {line_number}: {message}\n  > {line_content}")


# CONCEPT: Main parser class for .tiki file format
# Implements stack-based parsing algorithm recommended by Architect
# Maintains parent stack and auto-numbering for hierarchical concepts
class TikiParser:
    def __init__(self):
        # CONCEPT: Regex pattern for matching concept lines
        # Captures any asterisk pattern (with or without numbers) and title
        # More flexible pattern that handles various asterisk combinations
        self.concept_pattern = re.compile(r'^(\*+[^\s]*)\s+(.*)')
        
        # CONCEPT: Enhanced patterns for metadata and cross-references
        # Support inline metadata: [key: value, key2: value2]
        # Support cross-references: [cross_reference: *1**2***3]
        self.metadata_pattern = re.compile(r'\[([^\]]+)\]')
        self.frontmatter_pattern = re.compile(r'^---\s*$')
        self.code_block_pattern = re.compile(r'^```(\w+)?')
        
        self.reset()
    
    # CONCEPT: Reset parser state for new file
    # Clears internal tracking variables for fresh parse
    # Allows reusing parser instance for multiple files
    def reset(self):
        self.root: Optional[TikiNode] = None
        self.parent_stack: List[TikiNode] = []
        self.current_id_parts: List[int] = [0] * 10  # Support up to 10 levels deep
        self.line_number = 0
        self.frontmatter: Dict[str, Any] = {}
        self.in_frontmatter = False
        self.in_code_block = False
        self.code_block_lang = None
    
    # CONCEPT: Parse .tiki file from file path
    # Convenience method that handles file opening and reading
    # Returns root TikiNode of parsed tree structure
    def parse_file(self, file_path: Path) -> TikiNode:
        try:
            with open(file_path, 'r', encoding='utf-8') as file:
                return self.parse(file)
        except FileNotFoundError:
            raise TikiParseError(f"File not found: {file_path}")
        except UnicodeDecodeError as e:
            raise TikiParseError(f"File encoding error: {e}")
    
    # CONCEPT: Parse .tiki content from file handle or string list
    # Main parsing method implementing Architect's algorithm
    # Processes line by line maintaining hierarchy with parent stack
    def parse(self, content) -> TikiNode:
        self.reset()
        
        # CONCEPT: Handle both file handles and string lists
        # Provides flexibility for testing and different input sources
        # Normalizes input to list of lines for consistent processing
        if hasattr(content, 'readlines'):
            lines = content.readlines()
        elif isinstance(content, str):
            lines = content.split('\n')
        else:
            lines = list(content)
        
        # CONCEPT: Two-pass parsing for robustness
        # First pass: collect concepts and validate structure
        # Second pass: collect descriptions between concepts
        current_concept = None
        pending_description_lines = []
        
        for line in lines:
            self.line_number += 1
            line = line.rstrip()  # Remove trailing whitespace
            
            # CONCEPT: Handle YAML frontmatter
            # Support metadata at the beginning of files
            # Parse YAML between --- delimiters
            if self.frontmatter_pattern.match(line):
                if not self.in_frontmatter and self.line_number <= 10:  # Only allow at start
                    self.in_frontmatter = True
                    continue
                elif self.in_frontmatter:
                    self.in_frontmatter = False
                    continue
            
            if self.in_frontmatter:
                # Accumulate frontmatter lines for YAML parsing
                if not hasattr(self, '_frontmatter_lines'):
                    self._frontmatter_lines = []
                self._frontmatter_lines.append(line)
                continue
            
            # CONCEPT: Handle code blocks
            # Preserve code formatting and language information
            # Support executable code snippets in descriptions
            code_match = self.code_block_pattern.match(line)
            if code_match:
                if not self.in_code_block:
                    self.in_code_block = True
                    self.code_block_lang = code_match.group(1) if code_match.group(1) else "text"
                    if current_concept:
                        pending_description_lines.append(line)
                else:
                    self.in_code_block = False
                    self.code_block_lang = None
                    if current_concept:
                        pending_description_lines.append(line)
                continue
            
            # CONCEPT: Skip empty lines
            # Empty lines don't affect hierarchy or content
            # Allows formatting flexibility in .tiki files
            if not line.strip():
                if current_concept and pending_description_lines:
                    pending_description_lines.append("")  # Preserve blank lines in descriptions
                continue
            
            # CONCEPT: Check if line is a concept definition
            # Uses regex to identify asterisk-prefixed concept lines
            # Non-matching lines become description content
            match = self.concept_pattern.match(line)
            if match:
                # CONCEPT: Finalize previous concept's description
                # Attach accumulated description lines to previous concept
                # Trims trailing empty lines for clean formatting
                if current_concept and pending_description_lines:
                    description = '\n'.join(pending_description_lines).strip()
                    current_concept.description = description
                
                # CONCEPT: Parse new concept and determine hierarchy level
                # Count asterisk groups (**) to determine nesting depth
                # Create new TikiNode and update hierarchy tracking
                asterisk_part = match.group(1)
                title_with_metadata = match.group(2).strip()
                
                # CONCEPT: Extract inline metadata from title
                # Parse [key: value, key2: value2] patterns
                # Support priority, status, mastery, cross-references, etc.
                metadata = {}
                title = title_with_metadata
                
                # Find all metadata blocks in the title
                metadata_matches = self.metadata_pattern.findall(title_with_metadata)
                for metadata_str in metadata_matches:
                    # Remove metadata from title
                    title = title.replace(f"[{metadata_str}]", "").strip()
                    
                    # Parse metadata key-value pairs
                    parsed_metadata = self._parse_metadata_string(metadata_str)
                    metadata.update(parsed_metadata)
                
                # CONCEPT: Calculate level from asterisk pattern
                # Count consecutive asterisk groups to determine nesting depth
                # Examples: *1=1, *1**1=2, *1**1***1=3, *1**2***1****1=4
                if asterisk_part.startswith('*'):
                    # Count consecutive asterisk groups
                    # Split on numbers/letters to isolate asterisk patterns
                    clean_pattern = re.sub(r'[0-9a-zA-Z]', '', asterisk_part)
                    
                    # Count depth by counting asterisk groups
                    level = 0
                    i = 0
                    while i < len(clean_pattern):
                        if clean_pattern[i] == '*':
                            level += 1
                            # Skip consecutive asterisks in same group
                            while i < len(clean_pattern) and clean_pattern[i] == '*':
                                i += 1
                        else:
                            i += 1
                else:
                    level = 0
                
                try:
                    current_concept = self._create_concept_node(level, title, metadata)
                    pending_description_lines = []
                except TikiParseError as e:
                    e.line_number = self.line_number
                    e.line_content = line
                    raise e
            else:
                # CONCEPT: Accumulate description lines
                # Lines that don't match concept pattern become description
                # Supports multi-line descriptions with preserved formatting
                if current_concept is None:
                    # First line should be root concept (no asterisks)
                    if not line.startswith('*'):
                        current_concept = self._create_concept_node(0, line.strip())
                        pending_description_lines = []
                    else:
                        raise TikiParseError(
                            "File must start with root concept (no asterisks)", 
                            self.line_number, 
                            line
                        )
                else:
                    pending_description_lines.append(line)
        
        # CONCEPT: Finalize last concept's description
        # Ensure final concept gets its description attached
        # Handles case where file ends with description lines
        if current_concept and pending_description_lines:
            description = '\n'.join(pending_description_lines).strip()
            current_concept.description = description
        
        # CONCEPT: Validate successful parse
        # Ensure we created a root node during parsing
        # Provide helpful error for empty or invalid files
        if self.root is None:
            raise TikiParseError("No valid concepts found in file")
        
        return self.root
    
    # CONCEPT: Create concept node with automatic ID generation
    # Implements Architect's ID numbering scheme (*1, *1**2, *1**2***3)
    # Maintains parent-child relationships using stack-based tracking
    def _create_concept_node(self, level: int, title: str, metadata: Dict[str, Any] = None) -> TikiNode:
        # CONCEPT: Validate concept title
        # Ensure titles are not empty after stripping whitespace
        # Provide clear error messages for malformed concepts
        if not title:
            raise TikiParseError("Concept title cannot be empty")
        
        # CONCEPT: Handle root concept (level 0)
        # Root concepts have no asterisks and become tree root
        # Can only have one root concept per file
        if level == 0:
            if self.root is not None:
                raise TikiParseError("Multiple root concepts not allowed")
            
            node_id = ""  # Root has empty ID
            self.root = TikiNode(node_id, title)
            self.parent_stack = [self.root]
            return self.root
        
        # CONCEPT: Validate hierarchy level jumps
        # Prevent skipping levels (e.g., * directly to ***)
        # Ensures consistent tree structure per Tiki specification
        if self.parent_stack:
            current_depth = len(self.parent_stack) - 1
            if level > current_depth + 1:
                raise TikiParseError(
                    f"Invalid level jump: found level {level}, expected max {current_depth + 1}"
                )
        
        # CONCEPT: Auto-increment numbering at current level
        # Increment counter for current level, reset deeper levels
        # Implements Architect's numbering algorithm
        self.current_id_parts[level - 1] += 1
        for i in range(level, len(self.current_id_parts)):
            self.current_id_parts[i] = 0
        
        # CONCEPT: Generate node ID from numbering parts
        # Build ID string like *1**2***3****4 from number array
        # Use increasing asterisks for each level
        id_parts = []
        for i in range(level):
            asterisks = "*" * (i + 1)
            id_parts.append(f"{asterisks}{self.current_id_parts[i]}")
        node_id = "".join(id_parts)
        
        # CONCEPT: Adjust parent stack to current level
        # Pop stack until we reach the correct parent level
        # Maintains proper parent-child relationships
        while len(self.parent_stack) > level:
            self.parent_stack.pop()
        
        # CONCEPT: Create node with proper parent relationship
        # Parent is current top of stack (previous level)
        # Add new node to stack for potential children
        parent = self.parent_stack[-1] if self.parent_stack else None
        node = TikiNode(node_id, title, parent=parent)
        
        # CONCEPT: Add metadata to node
        # Store parsed metadata for enhanced functionality
        # Support priority, status, cross-references, etc.
        if metadata:
            node.metadata.update(metadata)
        
        self.parent_stack.append(node)
        
        return node
    
    # CONCEPT: Parse metadata string into key-value pairs
    # Support various metadata formats: key: value, key=value, key value
    # Handle lists, booleans, numbers, and cross-references
    def _parse_metadata_string(self, metadata_str: str) -> Dict[str, Any]:
        """Parse metadata string like 'priority: high, status: active, mastery: 85%'"""
        metadata = {}
        
        # Split by commas and parse each key-value pair
        pairs = [pair.strip() for pair in metadata_str.split(',')]
        
        for pair in pairs:
            # Support both : and = as separators
            if ':' in pair:
                key, value = pair.split(':', 1)
            elif '=' in pair:
                key, value = pair.split('=', 1)
            else:
                # Single word metadata (flags)
                key, value = pair.strip(), True
            
            key = key.strip()
            value = value.strip() if isinstance(value, str) else value
            
            # CONCEPT: Type conversion for common metadata types
            # Convert strings to appropriate types
            # Support percentages, numbers, booleans, references
            if isinstance(value, str):
                # Handle percentages
                if value.endswith('%'):
                    try:
                        metadata[key] = float(value[:-1]) / 100.0
                        continue
                    except ValueError:
                        pass
                
                # Handle numbers
                try:
                    if '.' in value:
                        metadata[key] = float(value)
                    else:
                        metadata[key] = int(value)
                    continue
                except ValueError:
                    pass
                
                # Handle booleans
                if value.lower() in ('true', 'yes', 'on'):
                    metadata[key] = True
                    continue
                elif value.lower() in ('false', 'no', 'off'):
                    metadata[key] = False
                    continue
                
                # Handle cross-references (starts with *)
                if value.startswith('*'):
                    metadata[key] = value  # Store as reference string
                    continue
            
            # Default: store as string
            metadata[key] = value
        
        return metadata
    
    # CONCEPT: Parse .tiki content from string
    # Convenience method for testing and string input
    # Splits string into lines and calls main parse method
    def parse_string(self, content: str) -> TikiNode:
        lines = content.split('\n')
        return self.parse(lines)