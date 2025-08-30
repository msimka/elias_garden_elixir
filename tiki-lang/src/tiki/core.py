# CONCEPT: Core TikiNode data structure using anytree
# This defines the fundamental tree node that represents each concept in a Tiki specification
# Each node has an ID (like *1**2***3), title, description, and can be expanded/collapsed
# Built on anytree for efficient tree operations and traversal
from typing import Optional, Dict, Any
from anytree import Node


# CONCEPT: Enhanced Node class for Tiki specifications
# Extends anytree's Node with Tiki-specific functionality
# Stores the hierarchical concept data with metadata for UI interaction
class TikiNode(Node):
    def __init__(
        self,
        node_id: str,
        title: str,
        description: str = "",
        parent: Optional["TikiNode"] = None,
        expanded: bool = True,
        **kwargs: Any
    ):
        # CONCEPT: Initialize anytree Node with our ID as the name
        # This allows anytree's built-in search and traversal to work with our IDs
        # Parent relationship automatically maintains tree structure
        super().__init__(node_id, parent=parent, **kwargs)
        
        self.node_id = node_id
        self.title = title
        self.description = description
        self.expanded = expanded  # For UI expand/collapse state
        self.metadata: Dict[str, Any] = {}  # For future extensions
    
    # CONCEPT: String representation for debugging and display
    # Shows the node ID and title for easy identification
    # Used in tree visualizations and debugging output
    def __str__(self) -> str:
        return f"{self.node_id}: {self.title}"
    
    def __repr__(self) -> str:
        return f"TikiNode(id='{self.node_id}', title='{self.title}')"
    
    # CONCEPT: Get full concept content for display
    # Combines title and description for complete concept view
    # Used when user requests full concept details in navigator
    def get_full_content(self) -> str:
        content = f"{self.title}\n"
        if self.description.strip():
            content += f"\n{self.description}"
        return content
    
    # CONCEPT: Get concept depth in hierarchy
    # Calculated from node_id structure (count ** separators)
    # Used for indentation and tree visualization
    @property
    def depth(self) -> int:
        if not self.node_id:
            return 0
        return self.node_id.count("**") + (1 if self.node_id.startswith("*") else 0)
    
    # CONCEPT: Check if node is root (top-level concept)
    # Root nodes have no asterisks in their ID
    # Used for tree rendering and navigation logic
    @property
    def is_root(self) -> bool:
        return not self.node_id.startswith("*")
    
    # CONCEPT: Get children as TikiNode list with proper typing
    # Provides type-safe access to child nodes
    # Used in tree traversal and rendering operations
    @property
    def tiki_children(self) -> list["TikiNode"]:
        return list(self.children)
    
    # CONCEPT: Toggle expanded state for UI interaction
    # Allows collapsing/expanding branches in tree navigator
    # Returns new state for UI feedback
    def toggle_expanded(self) -> bool:
        self.expanded = not self.expanded
        return self.expanded