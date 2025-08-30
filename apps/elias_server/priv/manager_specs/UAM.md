---
version: "1.0.0"
updated: "2025-08-28T20:00:00Z"
source: "claude@initial-setup"
checksum: "sha256:uam_initial_spec"
manager_type: "Universal Arts Manager"
priority: 3
---

# Universal Arts Manager (UAM) Rules and Configuration

## Core Purpose
UAM manages creative applications, artistic tools, and multimedia content creation across the ELIAS federation, providing intelligent automation for artistic workflows.

## Core Rules

### Creative Application Management
- **Rule 1**: Monitor and integrate with Photoshop, Logic Pro, Adobe Premiere, and other creative tools
- **Rule 2**: Automate creative workflows through intelligent scripting and automation
- **Rule 3**: Maintain creative project organization and asset management
- **Rule 4**: Handle creative application crashes and recovery gracefully
- **Rule 5**: Optimize creative application performance and resource usage

### Multimedia Content Creation
- **Rule 6**: Coordinate face and voice swap operations with appropriate AI models
- **Rule 7**: Generate and manipulate multimedia content (video, audio, images)
- **Rule 8**: Handle real-time creative content processing and streaming
- **Rule 9**: Manage creative content versioning and collaborative workflows
- **Rule 10**: Ensure creative content quality and consistency standards

### Web and Interactive Media
- **Rule 11**: Generate and optimize CSS styling for web projects
- **Rule 12**: Create and manage WebGL and interactive 3D content
- **Rule 13**: Handle responsive design and cross-platform compatibility
- **Rule 14**: Optimize web assets for performance and accessibility
- **Rule 15**: Manage creative web frameworks and tooling integration

## Behaviors

### On Creative Application Launch
1. Detect creative application startup and initialize monitoring
2. Load appropriate creative workflow templates and automations
3. Establish integration points for scripting and automation
4. Monitor application resource usage and performance
5. Prepare creative asset pipelines and project management

### On Creative Workflow Request
1. Analyze requested creative workflow and resource requirements
2. Coordinate with appropriate creative applications and AI models
3. Execute automated creative processes with progress tracking
4. Handle creative content generation and manipulation tasks
5. Deliver completed creative assets with quality verification

### On Face/Voice Swap Request
1. Validate source and target media for compatibility and quality
2. Coordinate with AI models for face detection and voice analysis
3. Process swap operations with real-time preview capabilities
4. Apply quality enhancements and seamless blending
5. Output final media with metadata and processing history

### On Web Content Creation
1. Analyze design requirements and target platform specifications
2. Generate responsive CSS styling with cross-browser compatibility
3. Create WebGL and interactive content with performance optimization
4. Test generated content across different devices and browsers
5. Deploy web assets with proper optimization and accessibility features

## Parameters

```yaml
# Creative Applications Configuration
creative_apps_path: "/Applications"
creative_projects_path: "/data/creative_projects"
workflow_templates_path: "/data/workflows"
automation_scripts_path: "/data/automation"

# Supported Creative Applications
creative_applications:
  photoshop:
    executable: "Adobe Photoshop"
    scripting_support: true
    automation_language: "javascript"
    file_formats: ["psd", "jpg", "png", "tiff", "pdf"]
  logic_pro:
    executable: "Logic Pro"
    scripting_support: true
    automation_language: "applescript"
    file_formats: ["logicx", "wav", "aiff", "mp3", "midi"]
  premiere_pro:
    executable: "Adobe Premiere Pro"
    scripting_support: true
    automation_language: "javascript"
    file_formats: ["prproj", "mp4", "mov", "avi"]
  after_effects:
    executable: "Adobe After Effects"
    scripting_support: true
    automation_language: "javascript"
    file_formats: ["aep", "mp4", "mov", "gif"]

# AI Models for Creative Tasks
creative_ai_models:
  face_swap:
    model_path: "/data/models/faceswap"
    input_formats: ["jpg", "png", "mp4", "mov"]
    processing_time_estimate: 30  # seconds per face
  voice_clone:
    model_path: "/data/models/voice_clone"
    input_formats: ["wav", "mp3", "m4a"]
    min_sample_duration: 10  # seconds
  style_transfer:
    model_path: "/data/models/style_transfer"
    input_formats: ["jpg", "png"]
    output_resolution: [1920, 1080]

# Web Content Creation
web_frameworks:
  css_preprocessors: ["sass", "less", "stylus"]
  js_frameworks: ["three.js", "babylon.js", "p5.js"]
  build_tools: ["webpack", "vite", "parcel"]
responsive_breakpoints:
  mobile: 480
  tablet: 768
  desktop: 1024
  wide: 1440

# Performance Monitoring
application_monitoring_interval: 15000  # milliseconds
performance_thresholds:
  app_response_time_ms: 2000
  memory_usage_mb: 8192
  cpu_usage_percent: 80
  render_time_ms: 100

# Creative Workflow Management
max_concurrent_workflows: 5
workflow_timeout_minutes: 60
auto_save_interval: 300  # seconds
version_control_enabled: true
collaborative_mode: true
```

## State Management

### Persistent State
- Complete model and asset inventory with metadata
- Usage statistics and access patterns
- Performance metrics history
- Cleanup schedules and retention policies

### Ephemeral State
- Active download progress and temporary files
- Current performance monitoring data
- Pending cleanup operations
- Cache optimization calculations

## Integration Points

### With Geppetto (ML Interface)
- Provides model availability and capability information
- Handles model loading and unloading for inference
- Monitors model performance during inference operations

### With URM (Universal Resource Manager) 
- Coordinates storage allocation and optimization
- Shares resource usage metrics and predictions
- Collaborates on system-wide resource planning

### With APE HARMONY Blockchain
- Logs all significant asset management events
- Records model download and usage metrics
- Stores asset metadata for distributed search

## Monitoring and Observability

### Key Metrics
- Model download success rate and completion times
- Asset storage utilization and growth trends
- Model inference performance and accuracy metrics
- Asset access patterns and cache hit rates

### Health Indicators
- All critical models available and functional
- Storage usage within acceptable limits
- Asset retrieval response time < 100ms
- No failed model downloads in last 24 hours

## Always On Behavior

### On Daemon Startup
1. Scan all storage paths and rebuild asset inventory
2. Verify critical model integrity and availability
3. Resume any interrupted downloads or operations
4. Initialize performance monitoring and metrics collection

### On Rule File Update
1. Parse new model and asset management policies
2. Update download priorities and retention policies
3. Reconfigure storage thresholds and cleanup schedules
4. Apply new performance monitoring parameters

### On System Shutdown
1. Complete any active downloads or save progress
2. Persist current asset inventory and metrics
3. Clean up temporary files and operations
4. Ensure all critical models are properly stored

## Error Handling

### Model Download Failures
1. Retry download with exponential backoff
2. Try alternative download sources if available
3. Verify network connectivity and storage space
4. Alert administrators of persistent download failures

### Storage Space Management
1. Monitor available space continuously
2. Trigger cleanup operations before reaching limits
3. Prioritize critical models and recent assets
4. Generate alerts for storage capacity issues

### Asset Corruption Detection
1. Verify asset integrity using checksums
2. Quarantine corrupted assets and attempt recovery
3. Restore from backups when available
4. Log corruption events for pattern analysis

UAM ensures optimal management of AI models and creative assets through intelligent automation, performance monitoring, and resource optimization while maintaining always-on availability for critical system operations.