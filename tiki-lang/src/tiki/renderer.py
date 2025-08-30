# CONCEPT: ASCII tree renderer using rich library for beautiful terminal output
# Generates visual tree representations of Tiki specifications
# Supports expand/collapse states and highlighted current selection
# Uses Unicode box drawing characters for professional appearance
from typing import Optional, Set, List
from rich.tree import Tree
from rich.console import Console
from rich.text import Text
from anytree import PreOrderIter
from .core import TikiNode


# CONCEPT: Tree renderer for ASCII and rich terminal output
# Creates visual representations of TikiNode hierarchies
# Supports interactive features like highlighting and expand/collapse
class TikiRenderer:
    def __init__(self, console: Optional[Console] = None):
        # CONCEPT: Initialize rich console for styled output
        # Allows customization of output target (stdout, file, etc.)
        # Provides consistent styling across all tree rendering
        self.console = console or Console()
        
        # CONCEPT: Define styling for different tree elements
        # Consistent color scheme and formatting for tree components
        # Makes tree navigation more intuitive and visually appealing
        self.styles = {
            "root": "bold cyan",
            "concept": "bright_white", 
            "current": "black on bright_yellow",
            "description": "dim white",
            "collapsed": "dim cyan",
        }
    
    # CONCEPT: Render complete tree with rich styling
    # Creates beautiful ASCII tree with Unicode box characters
    # Respects expand/collapse state of nodes
    def render_tree(
        self, 
        root: TikiNode, 
        current_node: Optional[TikiNode] = None,
        expanded_nodes: Optional[Set[str]] = None
    ) -> Tree:
        expanded_nodes = expanded_nodes or set()
        
        # CONCEPT: Create rich Tree with root concept as title
        # Root styling distinguishes top-level concept
        # Tree structure automatically handles indentation
        tree = Tree(
            Text(root.title, style=self.styles["root"]),
            guide_style="bright_blue"
        )
        
        # CONCEPT: Add child nodes recursively
        # Traverse tree and add nodes respecting expand/collapse
        # Skip rendering children of collapsed nodes
        self._add_children_to_tree(
            tree, root, current_node, expanded_nodes
        )
        
        return tree
    
    # CONCEPT: Recursively add child nodes to rich Tree
    # Handles nested concepts with proper styling and state
    # Implements expand/collapse logic for interactive navigation
    def _add_children_to_tree(
        self,
        parent_tree: Tree,
        parent_node: TikiNode,
        current_node: Optional[TikiNode],
        expanded_nodes: Set[str]
    ):
        for child in parent_node.tiki_children:
            # CONCEPT: Determine node styling based on state
            # Current node gets highlight, collapsed nodes get dim style
            # Provides visual feedback for navigation state
            if current_node and child.node_id == current_node.node_id:
                style = self.styles["current"]
            elif child.node_id in expanded_nodes or child.expanded:
                style = self.styles["concept"]
            else:
                style = self.styles["collapsed"]
            
            # CONCEPT: Create tree label with concept information
            # Shows node ID and title for identification
            # Adds collapse indicator for collapsed nodes
            label_text = f"{child.node_id} {child.title}"
            if child.tiki_children and not (child.node_id in expanded_nodes or child.expanded):
                label_text += " [+]"
            
            # CONCEPT: Add child branch to tree
            # Creates new branch for this concept
            # Recursively adds grandchildren if expanded
            child_tree = parent_tree.add(
                Text(label_text, style=style)
            )
            
            # CONCEPT: Recursively add grandchildren if node is expanded
            # Only traverse deeper if node is in expanded state
            # Prevents rendering collapsed subtrees for performance
            if child.node_id in expanded_nodes or child.expanded:
                if child.tiki_children:
                    self._add_children_to_tree(
                        child_tree, child, current_node, expanded_nodes
                    )
    
    # CONCEPT: Print tree to console with optional title
    # Convenience method for immediate terminal output
    # Adds optional title header for context
    def print_tree(
        self, 
        root: TikiNode, 
        current_node: Optional[TikiNode] = None,
        expanded_nodes: Optional[Set[str]] = None,
        title: Optional[str] = None
    ):
        if title:
            self.console.print(f"\n[bold]{title}[/bold]")
        
        tree = self.render_tree(root, current_node, expanded_nodes)
        self.console.print(tree)
    
    # CONCEPT: Render concept details for display panel
    # Shows full concept information when user requests details
    # Formats title and description with consistent styling
    def render_concept_details(self, node: TikiNode) -> str:
        # CONCEPT: Format concept header with ID and title
        # Provides clear identification of selected concept
        # Separates metadata from content description
        details = f"[bold cyan]{node.node_id}[/bold cyan]: [bold]{node.title}[/bold]\n"
        
        # CONCEPT: Add description if present
        # Shows full concept content with preserved formatting
        # Handles empty descriptions gracefully
        if node.description.strip():
            details += f"\n{node.description}"
        else:
            details += "\n[dim]No description provided[/dim]"
        
        return details
    
    # CONCEPT: Export tree as plain ASCII text
    # Creates simple text representation without rich styling
    # Useful for logging, files, or non-terminal output
    def export_ascii_tree(
        self, 
        root: TikiNode, 
        expanded_nodes: Optional[Set[str]] = None
    ) -> str:
        expanded_nodes = expanded_nodes or set()
        lines = []
        
        # CONCEPT: Add root concept without indentation
        # Root level has no tree characters, just the title
        # Starts the ASCII tree structure
        lines.append(root.title)
        
        # CONCEPT: Recursively build ASCII tree lines
        # Uses box drawing characters for tree structure
        # Maintains proper indentation for hierarchy
        self._build_ascii_lines(
            root, lines, "", True, expanded_nodes
        )
        
        return '\n'.join(lines)
    
    # CONCEPT: Recursively build ASCII tree lines with box characters
    # Creates traditional ASCII tree with ├── and └── characters
    # Handles proper indentation and continuation lines
    def _build_ascii_lines(
        self,
        node: TikiNode,
        lines: List[str],
        prefix: str,
        is_last: bool,
        expanded_nodes: Set[str]
    ):
        children = node.tiki_children
        
        for i, child in enumerate(children):
            is_child_last = (i == len(children) - 1)
            
            # CONCEPT: Choose appropriate tree characters
            # ├── for intermediate nodes, └── for last nodes
            # Creates proper ASCII tree structure
            if is_child_last:
                connector = "└── "
                next_prefix = prefix + "    "
            else:
                connector = "├── "
                next_prefix = prefix + "│   "
            
            # CONCEPT: Format child node line
            # Shows ID, title, and collapse indicator
            # Maintains consistent formatting across tree
            child_line = f"{prefix}{connector}{child.node_id} {child.title}"
            if child.tiki_children and not (child.node_id in expanded_nodes or child.expanded):
                child_line += " [+]"
            
            lines.append(child_line)
            
            # CONCEPT: Recursively add grandchildren if expanded
            # Only traverse deeper for expanded nodes
            # Maintains expand/collapse behavior in ASCII output
            if (child.node_id in expanded_nodes or child.expanded) and child.tiki_children:
                self._build_ascii_lines(
                    child, lines, next_prefix, is_child_last, expanded_nodes
                )
    
    # CONCEPT: Export tree structure as JSON
    # Converts TikiNode tree to JSON for data exchange
    # Preserves hierarchy and all node metadata
    def export_json(self, root: TikiNode) -> dict:
        # CONCEPT: Recursively convert tree to dictionary structure
        # Preserves all TikiNode data in JSON-serializable format
        # Includes hierarchy through nested children arrays
        def node_to_dict(node: TikiNode) -> dict:
            return {
                "id": node.node_id,
                "title": node.title,
                "description": node.description,
                "expanded": node.expanded,
                "metadata": node.metadata,
                "children": [node_to_dict(child) for child in node.tiki_children]
            }
        
        return {
            "root": node_to_dict(root),
            "format_version": "1.0"
        }