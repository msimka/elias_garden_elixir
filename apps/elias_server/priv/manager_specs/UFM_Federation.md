# UFM Federation Daemon - AI/Model Interaction Rules

**Purpose**: This file contains rules that Claude and other AI models MUST follow when interacting with the UFM Federation Daemon. This is separate from the .tiki specification (formal spec) and the .ex code (implementation).

## AI Interaction Protocol

### When to Call Federation Functions

**Network Topology Queries**
- Use `UFM.get_network_topology()` when you need current federation status
- Call `UFM.get_node_status(node_name)` for specific node health checks  
- Use `UFM.get_federation_metrics()` for performance analysis

**Request Routing Decisions**
- Call `UFM.route_request(request_type, requirements)` for optimal node selection
- Always specify capability requirements (e.g., `%{capabilities: ["ml_processing"]}`)
- Handle `{:error, :no_eligible_nodes}` gracefully with fallback strategies

### Decision Rules for AI Models

**Rule 1: Capability-Based Routing**
```
IF request requires ML processing 
  THEN requirements = %{capabilities: ["ml_processing"]}
IF request is lightweight (ApeMacs, basic communication)
  THEN requirements = %{capabilities: ["light_requests"]}
IF request involves blockchain operations  
  THEN requirements = %{capabilities: ["blockchain_mining"]}
```

**Rule 2: Load Balancing Awareness**
- Always use UFM routing instead of hardcoding node selections
- Trust UFM's load balancing decisions over manual node preferences
- Only override routing in emergency scenarios with explicit user permission

**Rule 3: Failure Handling**
```
IF UFM.route_request returns {:error, :no_eligible_nodes}
  THEN suggest user check node health with UFM.get_network_topology()
IF federation metrics show high failure rates
  THEN recommend network topology investigation
```

### Federation Event Interpretation

**Healthy Federation Indicators**
- All known nodes respond to heartbeat within 30 seconds
- Request routing success rate > 99%
- No network partitions detected
- Node types properly distributed (at least 1 full node available)

**Warning Conditions**  
- Node failure rate > 5% in last hour
- Average heartbeat response time > 100ms
- Only client nodes available (no full nodes for heavy processing)
- Network topology changes > 10 times per hour

**Critical Conditions**
- All nodes of specific type unavailable (e.g., no full nodes)
- Network partition detected lasting > 5 minutes
- Federation daemon restart loop (>3 restarts in 10 minutes)
- Request routing failure rate > 50%

## Always-On Behavior Rules

**Rule 4: Never Disable Federation**
- Federation daemon must NEVER be stopped manually
- If federation issues arise, debug and fix rather than disable
- Use `UFM.restart_subdaemon(:federation_daemon)` for recovery, not termination

**Rule 5: Hot-Reload Protocol**
- Changes to federation rules trigger automatic hot-reload
- Never restart entire UFM for federation configuration changes
- Validate federation rules before applying via `UFM.reload_rules()`

**Rule 6: Distributed Consistency**
- Federation state changes must be coordinated across all nodes
- Use APE HARMONY blockchain logging for critical federation events
- Resolve conflicts using timestamp precedence and node consensus

## Error Handling Protocols

**Network Partition Recovery**
```
1. Detect partition via node majority consensus
2. Identify which partition contains majority of nodes  
3. Merge topology maps when partition heals
4. Resolve conflicting node states using latest timestamp
5. Validate merged topology with all participating nodes
```

**Node Authentication Failures**
```
1. Log authentication failure with node details
2. Blacklist failing node for 5-minute cooldown period
3. Retry authentication after cooldown
4. If repeated failures, flag for manual investigation
5. Never permanently ban nodes without user approval
```

**Performance Degradation Response**
```
IF average response time > 200ms for 5 minutes:
  1. Check for network congestion via system metrics
  2. Analyze node load distribution
  3. Suggest load rebalancing if needed
  4. Recommend network infrastructure investigation
```

## Integration Guidelines  

**With Other Managers**
- Route UCM messages through federation for optimal node placement
- Coordinate with URM for resource-aware node selection
- Support UAM creative workflows by routing ML tasks to appropriate nodes
- Enable ULM training coordination across distributed nodes

**With APE HARMONY Blockchain**
- Log all federation join/leave events to blockchain
- Record node performance metrics for reputation scoring
- Use blockchain consensus for network partition resolution
- Store topology changes for audit trail and recovery

**With External Systems**
- Federation provides network abstraction layer for external integrations
- Route external API requests through optimal nodes based on capabilities  
- Handle external authentication via federation node validation
- Coordinate cross-federation communication through UFM

## Performance Expectations

**Response Time Targets**
- Node heartbeat: < 50ms for healthy nodes
- Topology queries: < 100ms for full topology map
- Request routing: < 10ms for route selection
- Node discovery: < 5 seconds for full network scan

**Scalability Assumptions**  
- Support 2-50 nodes in typical ELIAS federation
- Handle 1000+ concurrent requests across federation
- Maintain <1% overhead for federation coordination
- Scale linearly with number of nodes (O(n) complexity)

## Debugging and Troubleshooting

**Common Issues and Solutions**

*Issue: Nodes not discovering each other*
- Check Erlang cookie synchronization across nodes
- Verify network connectivity and firewall rules  
- Ensure EPMD is running on all nodes
- Validate hostname resolution between nodes

*Issue: Request routing failures*
- Check node capability registration
- Verify load balancing algorithm configuration  
- Ensure target nodes are healthy and responsive
- Review capability requirements matching

*Issue: Network partition detection false positives*  
- Adjust heartbeat timeout thresholds
- Check for network latency spikes  
- Validate partition detection logic
- Review consensus algorithm parameters

This file ensures AI models interact correctly with UFM Federation while maintaining the always-on, distributed nature of ELIAS.