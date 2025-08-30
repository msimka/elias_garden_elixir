---
version: "1.0.0"
updated: "2025-08-28T20:00:00Z"
source: "claude@initial-setup"
checksum: "sha256:uim_initial_spec"
manager_type: "Universal Interface Manager"
priority: 4
---

# Universal Interface Manager (UIM) Rules and Configuration

## Core Purpose
UIM manages the MacGyver interface generation system and application integrations, providing automated interface creation and cross-application coordination.

## Core Rules

### MacGyver Interface Generation
- **Rule 1**: Generate interfaces dynamically based on application analysis
- **Rule 2**: Maintain interface templates for common application patterns
- **Rule 3**: Learn from user interactions to improve interface generation
- **Rule 4**: Handle interface updates when applications change
- **Rule 5**: Ensure generated interfaces follow accessibility standards

### Application Integration
- **Rule 6**: Discover and catalog available applications on system
- **Rule 7**: Analyze application capabilities and integration points
- **Rule 8**: Create automation scripts for repetitive tasks
- **Rule 9**: Monitor application state changes for interface updates
- **Rule 10**: Handle cross-application workflow coordination

### User Experience Optimization
- **Rule 11**: Track user interaction patterns and preferences
- **Rule 12**: Optimize interface layouts based on usage data
- **Rule 13**: Provide contextual help and guidance
- **Rule 14**: Minimize cognitive load through intelligent defaults
- **Rule 15**: Adapt interfaces to user skill level and experience

## Behaviors

### On New Application Detected
1. Scan application for available interfaces and APIs
2. Analyze application structure and common usage patterns
3. Generate initial interface templates and automation scripts
4. Test generated interfaces for functionality and usability
5. Add application to managed applications registry

### On Interface Generation Request
1. Analyze target application current state and capabilities
2. Select appropriate interface template or create custom solution
3. Generate interface code with proper error handling
4. Validate interface functionality through automated testing
5. Deploy interface and monitor initial user interactions

### On User Interaction Analysis
1. Collect user interaction data and usage patterns
2. Identify inefficiencies and improvement opportunities
3. Generate interface optimizations and workflow enhancements
4. A/B test interface changes with user consent
5. Update interface templates based on successful optimizations

### On Application Update Detection
1. Detect changes in managed application interfaces or capabilities
2. Analyze impact on existing generated interfaces
3. Update affected interfaces to maintain compatibility
4. Test updated interfaces for continued functionality
5. Notify users of interface changes and improvements

## Parameters

```yaml
# MacGyver Configuration
interface_templates_path: "/data/interfaces/templates"
generated_interfaces_path: "/data/interfaces/generated"
learning_data_path: "/data/interfaces/learning"
interface_update_check_interval: 3600000  # 1 hour in milliseconds

# Application Discovery
application_scan_paths:
  - "/Applications"
  - "/usr/local/bin"
  - "/opt/homebrew/bin"
  - "~/Applications"
discovery_scan_interval: 86400000  # 24 hours in milliseconds

# Interface Generation
generation_timeout: 30000  # milliseconds
max_interface_complexity: 10
default_interface_style: "minimal"
accessibility_compliance: "WCAG-AA"

# Supported Application Types
application_categories:
  creative:
    examples: ["photoshop", "final_cut", "logic_pro"]
    templates: ["creative_suite", "media_editor"]
  communication:
    examples: ["messages", "slack", "discord"]
    templates: ["chat_client", "messaging"]
  development:
    examples: ["vscode", "xcode", "terminal"]
    templates: ["ide", "development_tool"]
  productivity:
    examples: ["excel", "word", "notion"]
    templates: ["document_editor", "spreadsheet"]

# Learning and Optimization
interaction_tracking_enabled: true
min_interactions_for_learning: 50
optimization_confidence_threshold: 0.8
a_b_test_duration_days: 7
user_consent_required: true

# Performance Monitoring
interface_response_time_ms: 200
generation_success_rate_threshold: 0.95
user_satisfaction_threshold: 4.0  # out of 5
error_rate_threshold: 0.05
```

## State Management

### Persistent State
- Application registry with capabilities and interfaces
- Interface templates and generation patterns
- User interaction data and learning models
- Performance metrics and optimization history

### Ephemeral State
- Active interface generation processes
- Current application states and monitoring data
- Pending interface updates and deployments
- Real-time user interaction tracking

## Integration Points

### With ApeMacs Client
- Provides interface automation for ApeMacs workflows
- Integrates with terminal and tmux management
- Coordinates with clipboard and system integration features

### With UCM (Universal Communication Manager)
- Requests application integration capabilities
- Coordinates cross-application workflow automation
- Reports interface performance and usage metrics

### With APE HARMONY Blockchain
- Logs interface generation events and success rates
- Records user interaction patterns for system improvement
- Stores interface templates for distributed access

## Monitoring and Observability

### Key Metrics
- Interface generation success rate and completion times
- User interaction frequency and satisfaction scores
- Application integration coverage and reliability
- Interface performance and response times

### Health Indicators
- All managed applications responding to interface requests
- Interface generation completing within SLA
- User satisfaction scores above threshold
- No critical interface failures in last hour

## Always On Behavior

### On Daemon Startup
1. Scan system for available applications and existing interfaces
2. Load interface templates and learning models
3. Restore any interrupted interface generation processes
4. Initialize application monitoring and state tracking

### On Rule File Update
1. Parse new interface generation rules and templates
2. Update application integration patterns and workflows
3. Reconfigure learning algorithms and optimization parameters
4. Apply new accessibility and performance standards

### On System Shutdown
1. Save current application states and interface configurations
2. Persist learning data and optimization models
3. Complete any active interface generation processes
4. Clean shutdown of application monitoring systems

## Error Handling

### Interface Generation Failures
1. Analyze failure cause (application changes, system issues)
2. Attempt generation with fallback templates
3. Provide manual interface options when automation fails
4. Log failures for template improvement

### Application Integration Issues
1. Detect when applications become unresponsive or change
2. Update application registry with new capabilities
3. Regenerate affected interfaces with updated information
4. Maintain backup interface methods for critical applications

### Learning Model Corruption
1. Validate learning data integrity on startup
2. Rebuild models from raw interaction data when needed
3. Maintain backup models for critical interface types
4. Alert administrators of significant learning degradation

UIM provides intelligent interface generation and application integration through the MacGyver system, continuously learning and optimizing user experiences while maintaining always-on availability for interface automation and cross-application coordination.