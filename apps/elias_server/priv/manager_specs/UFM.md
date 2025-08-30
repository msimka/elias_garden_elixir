---
manager: "UFM"
version: "2.0"
architecture: "supervised_process_tree"
supervision_strategy: "one_for_one"
subdaemons:
  - federation_daemon: "UFM_Federation.md"
  - monitoring_daemon: "UFM_Monitoring.md"  
  - testing_daemon: "UFM_Testing.md"
  - orchestration_daemon: "UFM_Orchestration.md"
  - ape_harmony_daemon: "UFM_ApeHarmony.md"
orchestration:
  lightweight_coordinator: true
  delegate_to_subdaemons: true
  fault_isolation: "independent_restart"
---

# Universal Federation Manager (UFM) - Master Specification

## Architecture Overview

UFM follows the Architect-recommended **supervised process tree pattern** with hierarchical specifications. This master spec coordinates 5 specialized sub-daemons, each with independent fault tolerance and hot-reloadable rules.

## Core Responsibilities

### 1. Lightweight Orchestration
- Coordinate sub-daemon initialization and supervision
- Provide unified API interface for external managers
- Handle rule broadcast and synchronization
- Monitor sub-daemon health and restart failed processes

### 2. Delegation Strategy
All functional responsibilities are delegated to specialized sub-daemons:

- **Federation**: Network topology, P2P coordination → `UFM.FederationDaemon`
- **Monitoring**: Health checks, metrics, alerts → `UFM.MonitoringDaemon`  
- **Testing**: Continuous validation, testing → `UFM.TestingDaemon`
- **Orchestration**: Workflow coordination → `UFM.OrchestrationDaemon`
- **APE HARMONY**: Blockchain operations → `UFM.ApeHarmonyDaemon`

## Supervision Tree Design

```
UFM (Lightweight Orchestrator)
├── UFM.Supervisor (:one_for_one)
    ├── UFM.FederationDaemon (:transient)
    ├── UFM.MonitoringDaemon (:transient)
    ├── UFM.TestingDaemon (:transient)
    ├── UFM.OrchestrationDaemon (:transient)
    └── UFM.ApeHarmonyDaemon (:transient)
```

## Rule Hot-Reloading Protocol

When UFM receives a rule reload request:

1. **Broadcast Phase**: UFM orchestrator broadcasts `:reload_rules` to all sub-daemons
2. **Independent Reload**: Each sub-daemon reloads its specific `.md` spec file
3. **Configuration Apply**: Sub-daemons apply rule changes (timers, thresholds, etc.)
4. **Status Report**: Sub-daemons report back successful rule application

## Fault Tolerance Strategy

- **Independent Failures**: Sub-daemon crashes don't affect siblings
- **Automatic Restart**: Supervisor restarts failed sub-daemons with `:transient` policy
- **Graceful Degradation**: UFM continues operating with partial sub-daemon availability
- **Health Monitoring**: Monitoring sub-daemon tracks overall UFM health

## API Pattern

UFM provides a unified interface but delegates all calls to appropriate sub-daemons:

```elixir
# Federation operations
UFM.get_network_topology() -> UFM.FederationDaemon.get_network_topology()

# Monitoring operations  
UFM.get_health_status() -> UFM.MonitoringDaemon.get_health_status()

# Testing operations
UFM.force_test_run() -> UFM.TestingDaemon.force_test_run()

# Orchestration operations
UFM.orchestrate_workflow() -> UFM.OrchestrationDaemon.orchestrate_workflow()

# Blockchain operations
UFM.record_event() -> UFM.ApeHarmonyDaemon.record_event()
```

## Integration with Other Managers

### UCM (Communication)
- UFM registers for system-wide events via UCM
- Federation topology changes broadcast through UCM
- Cross-node coordination messages routed via UCM

### URM (Resources)
- Resource allocation for workflows coordinated through URM
- System metrics shared with URM for resource planning
- Package management for blockchain dependencies via URM

### UAM (Arts)  
- Creative workflow orchestration through UFM.OrchestrationDaemon
- ML model coordination between UAM and ULM via UFM workflows

## Performance Characteristics

- **Process Isolation**: Independent memory spaces prevent cascading failures
- **Message Passing**: Lightweight Erlang message passing between sub-daemons
- **Hot Code Reloading**: Sub-daemons can be updated independently without system restart
- **Distributed Ready**: Process tree distributes across nodes seamlessly

## Always-On Philosophy Compliance

Every sub-daemon follows "always-on" principles:

- **Never Stop**: Continuous operation with timed cycles
- **Self-Healing**: Automatic restart and recovery
- **Hot-Reload**: Live configuration updates without downtime
- **Graceful Degradation**: Partial functionality during failures

## Development Guidelines

### Adding New Sub-Daemons
1. Create new daemon module in `lib/elias_server/manager/ufm/`
2. Add hierarchical spec in `priv/manager_specs/UFM_NewDaemon.md`
3. Register in `UFM.Supervisor` children list
4. Add delegation methods to main `UFM.ex` orchestrator
5. Update this master spec to document new functionality

### Rule Structure
Each sub-daemon spec should include:
- YAML frontmatter with configuration parameters
- Markdown body with behavioral rules and decision logic
- Hot-reload compatibility with timer rescheduling
- Default fallback values for missing configurations

## Distributed Deployment

- **Gracey (Client)**: Lightweight sub-daemons (federation, monitoring)
- **Griffith (Full Node)**: All sub-daemons with full capabilities
- **Federation Sync**: Sub-daemon state synchronization across nodes
- **Load Balancing**: Orchestration daemon handles cross-node workflow distribution

This architecture ensures UFM scales from development (all sub-daemons) to production (selective deployment) while maintaining the unified API interface and fault tolerance guarantees.