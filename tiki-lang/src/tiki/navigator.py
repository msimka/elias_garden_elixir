# CONCEPT: Interactive TUI navigator using Textual framework
# Provides keyboard-driven navigation through Tiki specification trees
# Supports expand/collapse, search, jump-to-ID, and concept detail display
# Implements Architect's recommended navigation patterns for spec exploration
from typing import Optional, Set, List
from textual.app import App, ComposeResult
from textual.containers import Horizontal, Vertical
from textual.widgets import Tree, Static, Input, Footer
from textual.binding import Binding
from anytree import find
from .core import TikiNode
from .parser import TikiParser
from .renderer import TikiRenderer


# CONCEPT: Custom tree widget for TikiNode display
# Extends Textual's Tree widget with Tiki-specific functionality
# Handles TikiNode structure and maintains expand/collapse state
class TikiTreeWidget(Tree[TikiNode]):
    def __init__(self, root_node: TikiNode):
        # CONCEPT: Initialize tree with root concept
        # Set up Textual tree widget with TikiNode as data type
        # Root node becomes the tree's foundation
        super().__init__(root_node.title, data=root_node)
        self.root_node = root_node
        self.expanded_nodes: Set[str] = set()
        
        # CONCEPT: Build initial tree structure
        # Populate tree widget with all TikiNode children
        # Respects initial expand/collapse state
        self._build_tree()
    
    # CONCEPT: Build tree widget structure from TikiNode hierarchy
    # Recursively creates Textual tree nodes from TikiNode structure
    # Maintains parent-child relationships and expand state
    def _build_tree(self):
        def add_children(tree_node, tiki_node: TikiNode):
            for child in tiki_node.tiki_children:
                # CONCEPT: Create tree node with concept information
                # Display format shows ID and title for identification
                # Associates TikiNode data with tree widget node
                label = f"{child.node_id} {child.title}"
                child_tree_node = tree_node.add(label, data=child)
                
                # CONCEPT: Track expanded state for UI consistency
                # Maintain expand/collapse state across refreshes
                # Allow user navigation state to persist
                if child.expanded:
                    self.expanded_nodes.add(child.node_id)
                    child_tree_node.expand()
                
                # CONCEPT: Recursively add grandchildren
                # Build complete tree structure respecting hierarchy
                # Enable deep navigation through specification
                if child.tiki_children:
                    add_children(child_tree_node, child)
        
        # CONCEPT: Start recursive tree building from root
        # Build complete widget tree from TikiNode structure
        # Root is automatically expanded for immediate access
        self.root.expand()
        add_children(self.root, self.root_node)


# CONCEPT: Main navigation application using Textual
# Provides full-featured TUI for exploring Tiki specifications
# Implements keyboard shortcuts and interactive panels
class TikiNavigator(App):
    CSS = """
    /* CONCEPT: TUI styling for professional appearance */
    /* Dark theme with syntax highlighting colors for developer focus */
    /* Layout optimized for tree navigation and concept reading */
    
    Screen {
        background: $surface;
    }
    
    #tree_panel {
        width: 50%;
        border: solid $primary;
        margin: 1;
    }
    
    #details_panel {
        width: 50%;
        border: solid $secondary;
        margin: 1;
        padding: 1;
    }
    
    #search_input {
        height: 3;
        margin: 1;
    }
    
    TikiTreeWidget {
        background: $surface;
    }
    """
    
    # CONCEPT: Define keyboard bindings for navigation
    # Standard shortcuts for tree navigation and interaction
    # Follows common TUI patterns for intuitive use
    BINDINGS = [
        Binding("q", "quit", "Quit"),
        Binding("space", "show_details", "Show Details"),
        Binding("enter", "show_details", "Show Details"),
        Binding("/", "search", "Search"),
        Binding("j", "jump_to_id", "Jump to ID"),
        Binding("e", "toggle_expand", "Toggle Expand"),
        Binding("r", "refresh", "Refresh"),
        Binding("?", "help", "Help"),
    ]
    
    def __init__(self, root_node: TikiNode):
        # CONCEPT: Initialize navigation app with parsed Tiki tree
        # Set up application state and components
        # Prepare tree widget and detail panels
        super().__init__()
        self.root_node = root_node
        self.tree_widget: Optional[TikiTreeWidget] = None
        self.details_widget: Optional[Static] = None
        self.search_input: Optional[Input] = None
        self.renderer = TikiRenderer()
    
    # CONCEPT: Compose TUI layout with tree and details panels
    # Creates split-pane interface for navigation and reading
    # Horizontal layout maximizes screen real estate usage
    def compose(self) -> ComposeResult:
        with Horizontal():
            # CONCEPT: Left panel for tree navigation
            # Tree widget shows hierarchical concept structure
            # Allows keyboard navigation through specification
            with Vertical(id="tree_panel"):
                yield Static("Tiki Specification Navigator", id="tree_title")
                self.tree_widget = TikiTreeWidget(self.root_node)
                yield self.tree_widget
            
            # CONCEPT: Right panel for concept details
            # Shows full concept content when selected
            # Provides reading area for specification text
            with Vertical(id="details_panel"):
                yield Static("Concept Details", id="details_title")
                self.details_widget = Static("Select a concept to view details")
                yield self.details_widget
        
        # CONCEPT: Search input and footer for user guidance
        # Hidden search input activated by '/' key
        # Footer shows available keyboard shortcuts
        self.search_input = Input(placeholder="Search concepts...", id="search_input")
        self.search_input.display = False
        yield self.search_input
        yield Footer()
    
    # CONCEPT: Handle tree selection changes
    # Update details panel when user navigates to different concept
    # Provides immediate feedback for tree navigation
    def on_tree_select(self, event: Tree.NodeSelected):
        if event.node and event.node.data:
            # CONCEPT: Display full concept information
            # Show title, description, and metadata
            # Formatted for easy reading in details panel
            tiki_node: TikiNode = event.node.data
            details = self.renderer.render_concept_details(tiki_node)
            if self.details_widget:
                self.details_widget.update(details)
    
    # CONCEPT: Show concept details action (Space/Enter)
    # Alternative way to view concept information
    # Ensures selected concept details are displayed
    def action_show_details(self):
        if self.tree_widget and self.tree_widget.cursor_node:
            if self.tree_widget.cursor_node.data:
                tiki_node: TikiNode = self.tree_widget.cursor_node.data
                details = self.renderer.render_concept_details(tiki_node)
                if self.details_widget:
                    self.details_widget.update(details)
    
    # CONCEPT: Toggle expand/collapse for selected node
    # Allows users to control tree visibility and focus
    # Maintains navigation state for better UX
    def action_toggle_expand(self):
        if self.tree_widget and self.tree_widget.cursor_node:
            # CONCEPT: Toggle expansion state in both tree widget and TikiNode
            # Keep UI and data model synchronized
            # Provide visual feedback for expand/collapse actions
            node = self.tree_widget.cursor_node
            if node.is_expanded:
                node.collapse()
                if node.data:
                    node.data.expanded = False
                    if node.data.node_id in self.tree_widget.expanded_nodes:
                        self.tree_widget.expanded_nodes.remove(node.data.node_id)
            else:
                node.expand()
                if node.data:
                    node.data.expanded = True
                    self.tree_widget.expanded_nodes.add(node.data.node_id)
    
    # CONCEPT: Search functionality activation
    # Show search input and focus for user query
    # Enable finding concepts by title or ID
    def action_search(self):
        if self.search_input:
            # CONCEPT: Show search input and capture focus
            # Clear previous search terms for fresh query
            # Provide immediate search capability
            self.search_input.display = True
            self.search_input.focus()
            self.search_input.value = ""
    
    # CONCEPT: Handle search input submission
    # Find and navigate to matching concepts
    # Provide search results feedback to user
    def on_input_submitted(self, event: Input.Submitted):
        if event.input == self.search_input:
            # CONCEPT: Search tree for matching concepts
            # Support search by title or node ID
            # Navigate to first match automatically
            query = event.value.lower()
            matches = self._search_tree(query)
            
            if matches:
                # CONCEPT: Navigate to first search result
                # Update tree selection to matched concept
                # Show concept details immediately
                first_match = matches[0]
                self._navigate_to_node(first_match)
                
                # CONCEPT: Update details with search result count
                # Provide feedback on search effectiveness
                # Show matched concept information
                result_text = f"Found {len(matches)} matches. Showing: {first_match.title}"
                if self.details_widget:
                    details = self.renderer.render_concept_details(first_match)
                    details = f"[green]{result_text}[/green]\n\n{details}"
                    self.details_widget.update(details)
            else:
                # CONCEPT: Show no results message
                # Provide clear feedback for unsuccessful searches
                # Suggest alternative search terms
                if self.details_widget:
                    self.details_widget.update(f"[red]No matches found for: '{query}'[/red]")
            
            # CONCEPT: Hide search input after processing
            # Return focus to tree navigation
            # Clean up search interface state
            self.search_input.display = False
            if self.tree_widget:
                self.tree_widget.focus()
    
    # CONCEPT: Search tree nodes by title or ID
    # Implement flexible search across all concepts
    # Return list of matching TikiNode objects
    def _search_tree(self, query: str) -> List[TikiNode]:
        matches = []
        
        # CONCEPT: Traverse entire tree for matches
        # Check both title and node ID for search term
        # Case-insensitive matching for user convenience
        def search_recursive(node: TikiNode):
            if (query in node.title.lower() or 
                query in node.node_id.lower()):
                matches.append(node)
            
            for child in node.tiki_children:
                search_recursive(child)
        
        search_recursive(self.root_node)
        return matches
    
    # CONCEPT: Navigate tree widget to specific TikiNode
    # Programmatically select and scroll to target node
    # Ensure node is visible and selected in tree
    def _navigate_to_node(self, target_node: TikiNode):
        if not self.tree_widget:
            return
        
        # CONCEPT: Find tree widget node for TikiNode
        # Search tree widget for matching data object
        # Handle tree widget and TikiNode synchronization
        def find_tree_node(tree_node, target):
            if tree_node.data == target:
                return tree_node
            for child in tree_node.children:
                result = find_tree_node(child, target)
                if result:
                    return result
            return None
        
        tree_node = find_tree_node(self.tree_widget.root, target_node)
        if tree_node:
            # CONCEPT: Select and scroll to found node
            # Ensure node is visible and focused
            # Provide immediate visual feedback
            self.tree_widget.cursor_node = tree_node
            self.tree_widget.scroll_to_node(tree_node)
    
    # CONCEPT: Jump to concept by ID input
    # Allow direct navigation to specific concept IDs
    # Useful for referencing specific sections
    def action_jump_to_id(self):
        # CONCEPT: Prompt for node ID input
        # Create temporary input for ID specification
        # Navigate directly to matching concept
        def jump_dialog():
            # For now, use search functionality
            # Future: implement dedicated ID input dialog
            self.action_search()
        
        jump_dialog()
    
    # CONCEPT: Refresh tree display
    # Reload tree structure and update display
    # Useful for dynamic content or state changes
    def action_refresh(self):
        if self.tree_widget:
            # CONCEPT: Rebuild tree widget from current TikiNode state
            # Preserve expand/collapse state where possible
            # Update display to reflect any data changes
            current_expanded = self.tree_widget.expanded_nodes.copy()
            
            # Clear and rebuild tree
            self.tree_widget.clear()
            self.tree_widget._build_tree()
            
            # Restore expansion state
            self.tree_widget.expanded_nodes = current_expanded
    
    # CONCEPT: Show help information
    # Display keyboard shortcuts and usage instructions
    # Provide user guidance for navigation features
    def action_help(self):
        help_text = """
[bold]Tiki Navigator Help[/bold]

[yellow]Navigation:[/yellow]
• Arrow keys: Navigate tree
• Space/Enter: Show concept details
• e: Expand/collapse selected node

[yellow]Search & Jump:[/yellow]  
• /: Search concepts by title or ID
• j: Jump to specific concept ID
• r: Refresh tree display

[yellow]General:[/yellow]
• q: Quit navigator
• ?: Show this help

[dim]Navigate with arrow keys, search with '/', expand/collapse with 'e'[/dim]
"""
        if self.details_widget:
            self.details_widget.update(help_text)


# CONCEPT: Standalone function to launch navigator for .tiki file
# Convenience function for command-line usage
# Handles file parsing and navigation app startup
def navigate_file(file_path: str):
    """Launch Tiki navigator for a .tiki file"""
    # CONCEPT: Parse file and launch navigation interface
    # Handle errors gracefully with user feedback
    # Provide complete file-to-navigation workflow
    try:
        from pathlib import Path
        parser = TikiParser()
        root_node = parser.parse_file(Path(file_path))
        
        # CONCEPT: Launch navigation application
        # Start Textual app with parsed tree structure
        # Provide interactive exploration interface
        app = TikiNavigator(root_node)
        app.run()
        
    except Exception as e:
        print(f"Error loading Tiki file: {e}")
        return False
    
    return True