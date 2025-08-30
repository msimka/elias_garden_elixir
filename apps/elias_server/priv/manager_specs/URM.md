---
version: "1.0.0"
updated: "2025-08-28T20:00:00Z"
source: "claude@initial-setup"
checksum: "sha256:urm_initial_spec"
manager_type: "Universal Resource Manager"
priority: 5
---

# Universal Resource Manager (URM) Rules and Configuration

## Core Purpose
URM manages system resources, intelligent downloading, and dependency management across the ELIAS federation with predictive optimization.

## Core Rules

### System Resource Management
- **Rule 1**: Monitor CPU, memory, storage, and network usage across all nodes
- **Rule 2**: Predict resource needs based on historical patterns and current trends
- **Rule 3**: Optimize resource allocation for maximum system efficiency
- **Rule 4**: Prevent resource exhaustion through proactive management
- **Rule 5**: Balance resource usage across federation nodes

### Intelligent Downloading
- **Rule 6**: Prioritize downloads based on system needs and user requests
- **Rule 7**: Resume interrupted downloads automatically with retry logic
- **Rule 8**: Optimize download scheduling to minimize system impact
- **Rule 9**: Validate downloaded content integrity and authenticity
- **Rule 10**: Clean up temporary files and manage download storage

### Dependency Management
- **Rule 11**: Track all system dependencies and their relationships
- **Rule 12**: Ensure dependency compatibility across different components
- **Rule 13**: Handle dependency updates without breaking system functionality
- **Rule 14**: Resolve dependency conflicts through intelligent versioning
- **Rule 15**: Maintain dependency security through vulnerability monitoring

## Behaviors

### On Resource Monitoring Cycle
1. Collect current resource usage metrics from all monitored systems
2. Compare against historical patterns and predicted needs
3. Identify potential resource bottlenecks or exhaustion risks
4. Generate resource optimization recommendations
5. Trigger proactive resource management actions when needed

### On Download Request
1. Validate download request authenticity and priority level
2. Check available bandwidth and storage capacity
3. Schedule download based on system load and priority
4. Monitor download progress and handle interruptions
5. Verify download integrity and move to appropriate location

### On Dependency Update Available
1. Analyze dependency update for compatibility and security
2. Test update in isolated environment to prevent conflicts
3. Calculate impact on dependent systems and components
4. Schedule update during optimal maintenance window
5. Deploy update with rollback capability and monitoring

### On Resource Alert Triggered
1. Identify specific resource constraint and affected systems
2. Implement immediate mitigation strategies to prevent service disruption
3. Analyze root cause and generate longer-term optimization plan
4. Notify relevant managers and administrators of resource issues
5. Log resource events for pattern analysis and prediction improvement

## Parameters

```yaml
# Resource Monitoring Configuration
monitoring_interval: 30000  # milliseconds
resource_alert_thresholds:
  cpu_usage_percent: 80
  memory_usage_percent: 85
  storage_usage_percent: 90
  network_utilization_percent: 75
  inode_usage_percent: 90

# Predictive Analytics
history_retention_days: 90
prediction_window_hours: 24
resource_trend_analysis_interval: 3600000  # 1 hour
anomaly_detection_sensitivity: 0.8

# Download Management
max_concurrent_downloads: 5
download_retry_attempts: 3
download_timeout: 1800000  # 30 minutes
bandwidth_limit_mbps: 100  # 0 for unlimited
download_storage_path: "/tmp/downloads"
completed_downloads_retention_days: 7

# Download Priorities
priority_levels:
  critical: 1    # System updates, security patches
  high: 2        # User-requested content, AI models
  medium: 3      # Background updates, caching
  low: 4         # Optional content, preemptive downloads

# Dependency Management
dependency_check_interval: 86400000  # 24 hours
vulnerability_scan_interval: 3600000  # 1 hour
update_window_hours: [2, 4]  # 2 AM to 4 AM
rollback_timeout: 300000  # 5 minutes

# Supported Package Managers
package_managers:
  system:
    homebrew:
      enabled: true
      update_policy: "security_only"
    apt:
      enabled: true
      update_policy: "security_only"
  language:
    pip:
      enabled: true
      update_policy: "manual"
    npm:
      enabled: true
      update_policy: "manual"
    hex:
      enabled: true
      update_policy: "manual"

# Storage Management
cleanup_thresholds:
  temp_files_age_days: 7
  log_files_age_days: 30
  cache_files_age_days: 14
  download_cache_size_gb: 10
```

## State Management

### Persistent State
- Historical resource usage data and trends
- Download queue with priorities and progress tracking
- Dependency inventory with versions and relationships
- Resource optimization models and prediction algorithms

### Ephemeral State
- Current resource usage metrics and alerts
- Active download sessions and temporary files
- Pending dependency updates and rollback states
- Real-time resource allocation decisions

## Integration Points

### With UAM (Universal Asset Manager)
- Coordinates storage allocation for AI models and assets
- Shares resource usage predictions for capacity planning
- Collaborates on cleanup operations and storage optimization

### With UFM (Universal Federation Manager)
- Reports node resource availability for load balancing
- Coordinates resource sharing across federation nodes
- Provides resource health data for routing decisions

### With APE HARMONY Blockchain
- Logs all significant resource management events
- Records dependency updates and system changes
- Stores resource usage patterns for federation-wide optimization

## Monitoring and Observability

### Key Metrics
- Resource utilization trends and prediction accuracy
- Download success rates and completion times  
- Dependency update success and rollback frequency
- Storage optimization effectiveness and cleanup volumes

### Health Indicators
- All monitored resources within acceptable thresholds
- Download queue processing within SLA
- No critical dependencies with known vulnerabilities
- Resource predictions accurate within 10% variance

## Always On Behavior

### On Daemon Startup
1. Initialize resource monitoring for all configured systems
2. Load historical data and rebuild prediction models
3. Resume interrupted downloads and dependency operations
4. Perform system resource health check and optimization

### On Rule File Update
1. Parse new resource management policies and thresholds
2. Update download priorities and dependency policies  
3. Reconfigure monitoring intervals and alert parameters
4. Apply new storage management and cleanup rules

### On System Shutdown
1. Complete all critical downloads and dependency operations
2. Persist current resource state and prediction models
3. Clean up temporary files and incomplete operations
4. Ensure proper shutdown of all monitoring processes

## Error Handling

### Resource Exhaustion Prevention
1. Monitor resource trends and predict exhaustion points
2. Implement automatic cleanup and optimization procedures
3. Alert administrators before critical thresholds are reached
4. Coordinate with other managers to reduce resource usage

### Download and Dependency Failures
1. Analyze failure causes (network, storage, corruption)
2. Implement appropriate retry strategies with backoff
3. Use alternative sources or mirrors when available
4. Maintain system stability during dependency conflicts

### Monitoring System Failures
1. Detect when monitoring systems become unresponsive
2. Switch to backup monitoring methods when possible
3. Alert administrators of monitoring system issues
4. Maintain resource management capabilities during outages

URM ensures optimal system resource utilization through intelligent monitoring, predictive management, and automated optimization while maintaining always-on availability for critical resource management operations across the ELIAS federation.