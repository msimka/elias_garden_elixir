# ELIAS Federation Task Manager

## 🖥️ Windows Task Manager Equivalent for ELIAS

The ELIAS Task Manager provides comprehensive real-time monitoring and management of the entire ELIAS federation system across all platforms and components.

## 🚀 Quick Start

Launch the ELIAS Task Manager:
```bash
./start_elias_task_manager.sh
```

Or run directly via Mix:
```bash
mix run -e "EliasServer.TaskManagerCLI.start()" --no-halt
```

## 📊 System Overview Dashboard

### Real-Time Monitoring
- **Process Count**: Total, running, and training processes
- **Manager Status**: Health of all 7 DeepSeek manager models
- **Training Capacity**: Weekly 58h distributed training usage
- **System Resources**: CPU, Memory, GPU, Network utilization

### Monitored Components
1. **7 Manager Models** (UFM, UCM, URM, ULM, UIM, UAM, UDM)
   - Each running DeepSeek 6.7B-FP16 on Griffith server
   - Domain-specific specializations
   - Real-time resource usage tracking

2. **Training Processes**
   - Kaggle P100 GPU jobs (30h/week capacity)
   - SageMaker V100 GPU jobs (28h/week capacity)
   - Training progress and duration monitoring

3. **Federation Nodes**
   - **Gracey** (local MacBook Pro): Coordination and orchestration
   - **Griffith** (remote server): Manager model hosting
   - **Cloud Platforms**: Kaggle and SageMaker training

## 🎮 Interactive Commands

### Process Management
- **[R]efresh**: Update all system data (auto-refreshes every 2 seconds)
- **[K]ill <pid>**: Terminate specific process by PID
- **[Enter]**: Quick refresh

### Manager Control
- **[M]anager <name>**: Show detailed manager information
  - Available managers: `ufm`, `ucm`, `urm`, `ulm`, `uim`, `uam`, `udm`
  - Shows specialization, status, resource usage, active processes

### Training Control
- **[T]raining**: Display training control panel
  - Current weekly schedule (58h distributed)
  - Daily training allocation
  - Cloud training orchestrator commands

### System Help
- **[H]elp**: Display all available commands
- **[Q]uit**: Exit task manager

## 🧠 Manager Model Specializations

| Manager | Domain | Specialization |
|---------|--------|----------------|
| **UFM** | Federation | Orchestration and load balancing |
| **UCM** | Content | Processing and pipeline optimization |
| **URM** | Resource | Management and GPU optimization |
| **ULM** | Learning | Adaptation and methodology refinement |
| **UIM** | Interface | Design and developer experience |
| **UAM** | Arts | Creative generation and brand content |
| **UDM** | Deployment | Universal deployment orchestration and release management |

## 📈 Training Schedule Monitoring

### Weekly Training Distribution
- **Monday-Saturday**: 8 hours daily (Kaggle 4h + SageMaker 4h)
- **Sunday**: 10 hours total (Kaggle 6h + SageMaker 4h)
- **Total**: 58 hours/week distributed training

### Manager Rotation
Each manager gets dedicated training time:
- Monday: UFM (Federation)
- Tuesday: UCM (Content)  
- Wednesday: URM (Resource)
- Thursday: ULM (Learning)
- Friday: UIM (Interface)
- Saturday: UAM (Arts)
- Sunday: UDM (Deployment)

## 🔄 Real-Time Process Display

### Process Information
- **PID**: Process identifier
- **Name**: Component name
- **Type**: manager, training, federation, monitoring
- **Status**: running, idle, training, error, stopped
- **CPU%**: CPU usage percentage
- **MEM(MB)**: Memory usage in megabytes  
- **System**: gracey, griffith, kaggle, sagemaker

### Manager Status Indicators
- ✅ **Healthy**: Manager running normally
- ❌ **Error**: Manager experiencing issues
- Resource usage tracked per manager

## 🎯 System Architecture Integration

### Federation Components
The task manager monitors all ELIAS federation components:

1. **Local Gracey (MacBook Pro)**
   - EliasServer coordination
   - UFF training coordination
   - Session capture system
   - Metrics collection

2. **Remote Griffith (SSH)**
   - 7 DeepSeek manager models
   - 35GB total VRAM allocation (5GB per manager)
   - Model deployment and health monitoring

3. **Cloud Training Platforms**
   - Kaggle P100 GPUs for main UFF training
   - SageMaker V100 GPUs for manager specialization

### Integration with Existing Systems
- **UFF Training System**: Monitors training coordinator and schedulers
- **Manager Models**: Real-time status of all 7 specialized models
- **Assert System**: Tracks code validation and compliance
- **Cloud Orchestration**: Training job status and resource usage

## 📊 Performance Metrics

### System Resources
- **CPU Usage**: Real-time percentage across all systems
- **Memory Usage**: Total memory consumption in MB
- **GPU Usage**: GPU utilization across all platforms
- **Network**: Data transfer rates in MB/s

### Training Analytics
- **Weekly Progress**: Hours used vs. total capacity
- **Platform Distribution**: Kaggle vs. SageMaker usage
- **Manager Training**: Individual specialization progress
- **Quality Metrics**: Tank Building compliance scores

## 🚀 Advanced Features

### Background Monitoring
- Auto-refreshes every 2 seconds
- Persistent monitoring during user interaction
- Real-time status updates

### Cross-Platform Management
- SSH integration for remote Griffith monitoring
- Cloud platform API integration
- Unified view across all systems

### Error Handling
- Process failure detection
- Manager health monitoring
- Training job status tracking
- Network connectivity monitoring

## 📁 File Structure

```
/Users/mikesimka/elias_garden_elixir/
├── apps/elias_server/lib/elias_server/
│   ├── elias_task_manager.ex          # Core monitoring system
│   └── task_manager_cli.ex            # Terminal interface
├── start_elias_task_manager.sh        # Launch script
└── ELIAS_TASK_MANAGER.md             # This documentation
```

## 🎯 Use Cases

1. **System Health Monitoring**: Check all federation components
2. **Training Progress Tracking**: Monitor 58h/week training schedule
3. **Resource Optimization**: Identify bottlenecks and high usage
4. **Manager Status Verification**: Ensure all 7 models are healthy
5. **Process Management**: Kill stuck processes or restart components
6. **Performance Analysis**: Track system metrics over time

---

**Total Implementation**: Complete Windows Task Manager equivalent for ELIAS Federation
**Real-time Monitoring**: All 7 managers + training + federation components  
**Cross-Platform**: Gracey + Griffith + Kaggle + SageMaker integration