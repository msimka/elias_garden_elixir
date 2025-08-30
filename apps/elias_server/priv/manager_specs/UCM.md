---
version: "1.0.0"
updated: "2025-08-28T20:00:00Z"
source: "claude@initial-setup"
checksum: "sha256:ucm_initial_spec"
manager_type: "Universal Communication Manager"
priority: 2
---

# Universal Communication Manager (UCM) Rules and Configuration

## Core Purpose
UCM orchestrates AI communications, request routing, and distributed processing coordination across the ELIAS federation.

## Core Rules

### AI Request Orchestration
- **Rule 1**: Route AI requests to optimal nodes based on capabilities and load
- **Rule 2**: Maintain request lifecycle tracking from submission to completion  
- **Rule 3**: Handle request failures with automatic retry and fallback strategies
- **Rule 4**: Load balance AI processing across available full nodes
- **Rule 5**: Prioritize user-facing requests over background processing

### Claude API Coordination
- **Rule 6**: Never proxy Claude API calls - clients communicate directly
- **Rule 7**: Monitor Claude API usage patterns for optimization insights
- **Rule 8**: Coordinate Claude-generated manager rule updates across federation
- **Rule 9**: Log significant Claude interactions for audit and improvement

### Inter-Manager Communication
- **Rule 10**: Facilitate communication between all manager daemons
- **Rule 11**: Broadcast critical system events to all relevant managers
- **Rule 12**: Maintain message ordering for dependent operations
- **Rule 13**: Handle communication failures with appropriate fallbacks

## Behaviors

### On AI Request Received
1. Determine request type and resource requirements
2. Query UFM for optimal node selection based on capabilities
3. Route request to selected node with appropriate timeout
4. Monitor request progress and handle any failures
5. Return results to requesting client with performance metrics

### On Manager Communication Request
1. Validate sender authority and message integrity
2. Route message to target manager(s) based on addressing
3. Ensure delivery confirmation for critical messages
4. Handle broadcast messages to multiple managers efficiently
5. Log communication patterns for optimization analysis

### On Claude Rule Update Notification
1. Receive rule update notification from Claude integration
2. Validate rule file format and checksum integrity  
3. Coordinate hot-reload across affected manager daemons
4. Verify successful rule application on all target nodes
5. Log rule deployment success/failure to blockchain

### On Request Failure Detection
1. Identify failure type (node down, timeout, processing error)
2. Implement retry logic based on failure type and request criticality
3. Select alternative node if original target unavailable
4. Notify requesting client of delays with estimated completion time
5. Update node health metrics for future routing decisions

## Parameters

```yaml
# Request Routing Configuration
default_request_timeout: 30000      # milliseconds
max_retry_attempts: 3
retry_backoff_multiplier: 2.0
priority_queue_sizes:
  high: 100
  medium: 200  
  low: 500

# Load Balancing
load_balance_algorithm: "least_connections"
health_check_interval: 10000        # milliseconds
circuit_breaker_threshold: 5        # failures before circuit opens
circuit_breaker_timeout: 60000      # milliseconds

# AI Processing Coordination
ai_request_types:
  claude_query: 
    timeout: 45000
    retry_count: 2
    required_capabilities: ["api_access"]
  geppetto_query:
    timeout: 120000
    retry_count: 1
    required_capabilities: ["ml_processing"]
  rule_processing:
    timeout: 15000
    retry_count: 3
    required_capabilities: ["rule_engine"]

# Manager Communication
message_priorities:
  critical: 1    # System failures, security alerts
  high: 2        # Rule updates, topology changes  
  medium: 3      # Status updates, metrics
  low: 4         # Logging, debug info

broadcast_confirmation_timeout: 5000  # milliseconds
```

## State Management

### Persistent State
- Active request registry with status tracking
- Node performance metrics and health history
- Manager communication patterns and reliability scores
- Failed request retry schedules and backoff timers

### Ephemeral State
- Current request routing decisions in progress
- Temporary circuit breaker states
- Active manager communication sessions
- Real-time load balancing metrics

## Integration Points

### With UFM (Universal Federation Manager)
- Queries network topology for request routing decisions
- Receives node health updates for routing optimization
- Coordinates distributed request processing

### With Request Pool System
- Integrates with GenStage request producers and consumers
- Manages request priority queues and backpressure
- Coordinates distributed request processing

### With APE HARMONY Blockchain
- Logs all significant AI request patterns
- Records manager communication events for audit
- Stores performance metrics for system optimization

## Monitoring and Observability

### Key Metrics
- Request routing success rate and latency percentiles
- Manager communication reliability and response times
- AI processing throughput by request type
- Circuit breaker activations and recovery times

### Health Indicators
- All manager daemons responding within SLA
- Request queue depths within acceptable limits
- No critical communication failures in last hour
- AI request success rate > 95%

## Always On Behavior

### On Daemon Startup
1. Initialize request routing tables and priority queues
2. Establish communication channels with all manager daemons
3. Query UFM for current network topology and node capabilities
4. Resume any pending requests from persistent storage

### On Rule File Update
1. Parse new communication rules and routing policies
2. Update request routing algorithms and timeout values
3. Reconfigure priority queues and load balancing parameters
4. Notify other managers of communication policy changes

### On System Shutdown
1. Complete all in-flight requests or gracefully transfer to other nodes
2. Persist pending request state for recovery
3. Notify all managers of planned communication unavailability
4. Clean shutdown with proper request handoff

## Error Handling

### Communication Failure Recovery
1. Detect manager daemon unresponsiveness
2. Activate circuit breakers for failing communication paths
3. Route messages through alternative managers when possible
4. Log communication failures for pattern analysis

### Request Processing Failures
1. Classify failure type (temporary, permanent, node-specific)
2. Implement appropriate retry strategy based on failure classification
3. Update node reliability scores for future routing decisions
4. Escalate persistent failures to system administrators

UCM operates as the central nervous system for ELIAS federation communication, ensuring reliable AI request orchestration and inter-manager coordination through deterministic, rule-driven behavior.